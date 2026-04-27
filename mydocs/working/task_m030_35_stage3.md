# Task M030 #35 Stage 3 완료보고서

## 단계 목표

Quick Look preview와 큰 Finder thumbnail이 embedded preview를 사용하지 않고 직접 렌더링하도록 정책을 구현한다. 작은 Finder thumbnail에서는 기존 성능 fast path를 유지한다.

## 변경 내용

### 1. embedded preview 정책 타입 추가

`Sources/Shared/HwpPageImageRenderer.swift`에 `HwpEmbeddedThumbnailPolicy`를 추가했다.

- `.never`: embedded preview를 사용하지 않는다.
- `.smallFinderThumbnail(maxPixelDimension:)`: Finder의 작은 thumbnail 요청에서만 embedded preview를 허용한다.

### 2. 기본 렌더 경로를 full render로 고정

`HwpPageImageRenderer.renderFirstPage(fileURL:)`의 기본 정책을 `.never`로 두었다.

이제 Quick Look preview는 `maximumPixelSize == nil`이어도 embedded preview를 우선 사용하지 않는다. 따라서 `group-drawing-02.hwp`의 `177x250` GIF가 Quick Look preview에 확대 표시되는 경로를 차단한다.

### 3. Finder thumbnail만 작은 요청 fast path 허용

`Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`에서 thumbnail 렌더 요청을 보낼 때 다음 정책을 명시했다.

```swift
embeddedThumbnailPolicy: .smallFinderThumbnail(maxPixelDimension: 128)
```

이 정책으로 `128px` 이하 요청은 embedded preview fast path를 사용할 수 있고, 그보다 큰 Finder icon view 요청은 full render fallback으로 전환된다.

## 검증

### Shared bridge 경계

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### 렌더링 smoke test

```bash
./scripts/validate-stage3-render.sh output/task35-stage3-render
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED **
```

## 판단

- Quick Look preview에서 낮은 해상도 embedded GIF를 우선 사용하는 경로는 제거됐다.
- Finder thumbnail은 작은 요청에서만 embedded preview를 사용하고, 큰 요청은 PDF처럼 요청 크기에 맞춰 직접 렌더한다.
- full render 이후에도 `group-drawing-02.hwp`의 도형 품질 문제가 남으면 Stage 4에서 render tree와 Swift renderer를 추가 분석한다.

## 변경 파일

- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `mydocs/plans/task_m030_35_impl.md`
- `mydocs/orders/20260425.md`
- `mydocs/working/task_m030_35_stage2.md`
- `mydocs/working/task_m030_35_stage3.md`

## 승인 요청

Stage 3 완료를 승인하면 Stage 4 render tree와 Swift renderer 추가 분석으로 진행한다.
