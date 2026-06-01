# Task M014 #122 Stage 3 완료보고서

## 개요

Stage 3에서는 Stage 2 설계에 따라 Swift/CoreGraphics renderer의 image fill mode 처리 경로를 구현했다. 변경 범위는 `CGTreeRenderer.swift` 내부 helper와 image draw 호출부로 제한했고, render tree model, overlay model, Rust bridge ABI, upstream core pin은 변경하지 않았다.

## 기준

| 항목 | 값 |
|------|----|
| 이슈 | #122 Swift native renderer 이미지 fill mode·타일·배치 렌더링 parity 보강 |
| 브랜치 | `local/task122` |
| 선행 단계 | `mydocs/working/task_m014_122_stage2.md` |
| 변경 파일 | `Sources/RhwpCoreBridge/CGTreeRenderer.swift` |

## 구현 내용

### Fill Policy

`fillMode` 문자열을 다음 순서로 정규화해 private policy로 변환한다.

- 앞뒤 whitespace 제거
- `_`, `-`, 공백, tab 제거
- lowercase 비교

정책 매핑:

- `nil`, empty, `fitToSize`, `stretch`, `stretchToFit`, `none`, unknown: bbox 전체 draw
- placement: `leftTop`, `centerTop`, `rightTop`, `leftCenter`, `center`, `rightCenter`, `leftBottom`, `centerBottom`, `rightBottom`
- tile: `tileAll`, `tileHorzTop`, `tileHorzBottom`, `tileVertLeft`, `tileVertRight`
- tile alias: `tileHorizTop`, `tileHorizontalTop`, `tileHorizBottom`, `tileHorizontalBottom`, `tileVerticalLeft`, `tileVerticalRight`

`none`과 unknown은 기존 Swift 동작과 upstream WebCanvas 기준에 맞춰 bbox 전체 draw로 유지했다.

### Natural Size

placement/tile draw size는 다음 순서로 선택한다.

1. `ImageNode.originalSize`가 positive finite 2개 이상이면 사용
2. 아니면 원본 decode 직후 `CGImage.width/height` 사용
3. 아니면 crop/effect 적용 후 prepared image size 사용
4. 실패하면 bbox 전체 draw로 fallback

`originalSizeHU`는 Stage 2 설계대로 draw size 계산에 사용하지 않았다.

### Draw Helper

render tree image와 overlay image 모두 다음 공용 helper 경로를 사용한다.

- decode/cache된 원본 `CGImage`의 size를 보존
- 기존 `preparedImage`로 crop/effect/brightness/contrast 적용
- #116 baked watermark는 기존처럼 adjustment skip 유지
- bbox 전체 draw, placement draw, tile draw를 `drawImage(_:node:bbox:decodedImageSize:in:)`로 분기
- `drawImage(_:inTopLeftRect:in:)` 내부에서만 CGImage Y축 flip 처리

placement/tile mode에서는 bbox clip을 적용한다. tile mode는 upstream CanvasKit과 같은 최대 draw count `4096`에서 중단한다.

## 보존한 동작

- `fillMode == nil`인 기존 sample의 bbox 전체 draw 동작
- crop source rect 계산의 `75 HU/px` 규칙
- effect/brightness/contrast 적용 순서
- overlay image supplement merge와 baked watermark adjustment skip
- `applyTransform` 호출 위치
- public API와 FFI ABI

## 검증

### Build

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task122 CODE_SIGNING_ALLOWED=NO build
```

결과: 통과.

비고:

- 최초 sandbox 실행은 Sparkle package resolve 중 `github.com` DNS 차단으로 실패했다.
- 네트워크 허용 재실행에서 build가 통과했다.
- 최종 incremental sandbox 실행은 SwiftPM/clang cache write 권한 제한으로 실패했다.
- 최종 소스 기준 sandbox 외부 재실행에서 `** BUILD SUCCEEDED ** [5.221 sec]`로 통과했다.

### Render Debug Compare

```bash
./scripts/render-debug-compare.sh build.noindex/task122-stage3-render-debug --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp
```

결과: 두 sample 모두 native PNG 생성 성공.

| Sample | Native PNG | NativeNonWhitePixels | 비고 |
|--------|------------|----------------------|------|
| `pic-crop-01.hwp` | `794x1123` | `39870` | `OK` |
| `tac-img-02.hwp` | `794x1123` | `38410` | `OK` |

`render-debug-compare`의 core SVG raster diff는 `qlmanage rasterize failed`로 생성되지 않았다. Stage 3의 최소 smoke 목적은 native renderer가 기존 nil fill_mode sample을 계속 렌더링하는지 확인하는 것이며, Stage 4에서 visual diff regression을 별도 수행한다.

### Diff Check

```bash
git diff --check
```

결과: 통과.

### Extension Registration Hygiene

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
```

결과: Issues 없음.

경고는 기존 build.noindex/DerivedData 아래 개발용 `Alhangeul.app` bundle 존재와 PlugInKit provider path 미보고뿐이며, development registration은 없었다.

## 리스크와 후속 확인

- 현재 sample set의 first page image node들은 `fill_mode == null`이라 tile/placement mode 자체를 시각 fixture로 직접 증명하지는 못했다.
- 이번 구현은 upstream CanvasKit/WebCanvas 정책과 Swift 기존 fallback 보존을 기준으로 한 코드 경로 보강이다.
- Stage 4에서는 visual diff regression과 추가 smoke를 수행하고, 가능한 경우 non-null fill_mode fixture 확보 여부를 다시 확인한다.

## 다음 단계 요청

Stage 4에서는 구현 후 regression 검증을 수행한다. 기본 대상은 visual diff harness, render debug artifact 확인, Quick Look/Thumbnail hygiene 재확인이다.
