# Task M030 #35 Stage 6 완료보고서

## 단계 목표

Finder thumbnail에서 embedded preview fast path를 완전히 제거해, Finder 줌 왕복 시 embedded 결과와 직접 렌더 결과가 번갈아 표시되는 현상을 제거한다.

## 문제 재현

대상 파일:

- `/Users/melee/Documents/samples/tac-img-02.hwp`

관찰:

- Finder 아이콘 보기에서 크기 조절 슬라이더를 키우고 줄이면 서로 다른 두 이미지가 번갈아 보였다.
- 작은 크기에서 큰 크기로 넘어갈 때뿐 아니라 반대로 줄일 때도 발생했다.

분석:

- `tac-img-02.hwp`의 embedded preview는 `724x1024`로 충분히 크다.
- 직접 렌더 결과는 `794x1123`이다.
- 두 이미지는 해상도만 다른 것이 아니라 제목 굵기, 그림자, 배치가 서로 다르다.
- 기존 정책은 작은 thumbnail 요청에서 embedded preview를 쓰고, 큰 요청에서 직접 렌더링을 썼다.
- Finder 줌 왕복과 thumbnail cache 재사용이 겹치면 사용자 눈에는 두 렌더 소스가 교차 표시되는 것으로 보인다.

## 변경 내용

`Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`에서 thumbnail 렌더링 정책을 `.never`로 고정했다.

```swift
embeddedThumbnailPolicy: .never
```

이제 ThumbnailExtension은 Finder thumbnail 요청 크기와 무관하게 직접 렌더링만 사용한다. Quick Look preview도 이미 `.never` 정책을 사용하므로, Quick Look/Thumbnail 양쪽이 같은 직접 렌더 소스를 사용한다.

## 성능 평가

임시 benchmark로 embedded decode와 direct render를 비교했다.

| 파일 | embedded decode | direct render |
|------|----------------:|--------------:|
| `group-drawing-02.hwp` | 0.12 ms | 2.7-3.1 ms |
| `tac-img-02.hwp` | 4.82 ms | 26-43 ms |
| `KTX.hwp` | 0.12 ms | 35-38 ms |
| `exam_kor.hwp` | 1.15 ms | 127-138 ms |

판단:

- cold thumbnail 생성 비용은 증가한다.
- 하지만 Finder/Quick Look 캐시가 생성 이후 비용을 줄인다.
- embedded preview와 direct render가 다른 파일에서는 fast path가 품질 문제가 아니라 일관성 문제를 만든다.
- 이번 이슈의 목표는 Finder/PDF 같은 일관된 preview/thumbnail 동작이므로 직접 렌더링으로 통일하는 쪽을 선택했다.

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
./scripts/validate-stage3-render.sh output/task35-stage6-render
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

### Release package 및 Finder thumbnail 검증

```bash
./scripts/package-release.sh 0.3.0-task35-smoke3
```

결과:

```text
** BUILD SUCCEEDED **
```

설치 후 `qlmanage -t`로 `tac-img-02.hwp`의 32, 48, 64, 80, 96, 112, 128, 160, 192, 256, 512 크기를 생성했다.

수치 비교 결과 모든 크기에서 embedded preview보다 직접 렌더 결과에 더 가까웠다.

```text
32  closer=direct
48  closer=direct
64  closer=direct
80  closer=direct
96  closer=direct
112 closer=direct
128 closer=direct
160 closer=direct
192 closer=direct
256 closer=direct
512 closer=direct
```

## 판단

- ThumbnailExtension의 embedded preview fast path를 제거했다.
- Finder 줌 왕복 시 embedded/direct 렌더 소스가 교차 표시될 여지를 제거했다.
- 성능 손실은 cold thumbnail 생성 시 존재하지만, 결과 일관성과 PDF 유사 동작을 우선했다.

## 변경 파일

- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `mydocs/orders/20260425.md`
- `mydocs/working/task_m030_35_stage6.md`

## 승인 요청

Stage 6 완료를 승인하면 최종 결과 보고서 작성과 PR 준비 단계로 진행한다.
