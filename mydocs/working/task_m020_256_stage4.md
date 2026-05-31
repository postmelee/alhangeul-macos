# Task M020 #256 Stage 4 보고서

## 단계 목표

대표 샘플에서 기존 CoreGraphics 경로 회귀가 없는지 확인하고, `skiaOptIn` 경로의 성공 또는 fallback diagnostics를 기록한다.

## 변경 요약

| 파일 | 내용 |
|---|---|
| `mydocs/working/task_m020_256_stage4.md` | Stage 4 smoke와 Skia/CoreGraphics 비교 결과 기록 |
| `mydocs/orders/20260520.md` | #256 상태를 Stage 4 완료 후 승인 대기로 기록 |

소스 변경은 없다. 비교용 Swift smoke는 `build.noindex/task256_stage4_compare.swift`에 임시로 작성했으며, `build.noindex/`는 git ignored 산출물이다.

## CoreGraphics 기본 smoke

실행 명령:

```bash
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh output/task256-stage4 samples/basic/KTX.hwp samples/basic/request.hwp
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
OK KTX.hwp: page=1 size=1123x794 textRuns=437 hangulRuns=77 hangulScalars=209 nonWhitePixels=453754 png=/private/tmp/rhwp-mac-task256/output/task256-stage4/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=105 hangulRuns=37 hangulScalars=309 nonWhitePixels=69132 png=/private/tmp/rhwp-mac-task256/output/task256-stage4/request-page1.png
```

`KTX.hwp`에서는 기존 Stage 2와 같은 upstream layout overflow diagnostic이 stderr에 출력됐다.

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=28 line=0 y=768.5 col_bottom=755.9 overflow=12.5px
LAYOUT_OVERFLOW: page=0, col=0, para=28, type=PartialParagraph, y=776.5, bottom=755.9, overflow=20.5px
```

smoke 자체는 통과했고 bitmap은 non-blank로 확인됐다.

## Skia/CoreGraphics 비교 smoke

임시 smoke는 같은 문서에서 다음 순서로 실행했다.

1. `HwpPageImageRenderer.renderPage(..., policy: .coreGraphicsOnly)` 호출
2. `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)` 호출
3. 두 결과를 `encodePNG`로 저장
4. `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs`, PNG byte 수, pixel size, non-white pixel 수 비교

compile:

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task256-stage4-compare/swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task256-stage4-compare/clang-module-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/FontResourceRegistry.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift \
  Sources/Shared/HwpPageImageRenderer.swift \
  build.noindex/task256_stage4_compare.swift \
  Frameworks/universal/librhwp.a \
  -framework CoreFoundation \
  -framework CoreText \
  -framework CoreGraphics \
  -framework Foundation \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  -framework Security \
  -framework Metal \
  -framework QuartzCore \
  -framework IOSurface \
  -framework ColorSync \
  -lc++ \
  -liconv \
  -lz \
  -o build.noindex/task256-stage4-compare/task256_stage4_compare
```

run:

```bash
build.noindex/task256-stage4-compare/task256_stage4_compare \
  output/task256-stage4-compare \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp
```

결과:

| 샘플 | CG pixels | CG PNG | CG non-white | Skia backend | fallback | Skia raw PNG | Skia encoded PNG | Skia non-white | byte delta | non-white delta | duration |
|---|---:|---:|---:|---|---|---:|---:|---:|---:|---:|---|
| `KTX.hwp` | 1123x794 | 555392 | 453754 | `skia` | nil | 165799 | 181146 | 237867 | 374246 | 215887 | skia 66.536 ms, decode 1.097 ms, total 67.633 ms |
| `request.hwp` | 567x794 | 82129 | 69132 | `skia` | nil | 88793 | 85981 | 72014 | 3852 | 2882 | skia 60.485 ms, decode 0.076 ms, total 60.561 ms |

두 샘플 모두 `skiaOptIn`이 CoreGraphics fallback 없이 `backendUsed: .skia`, `fallbackReason: nil`로 성공했다.

산출물:

| 파일 | 용도 |
|---|---|
| `output/task256-stage4/KTX-page1.png` | 기존 CoreGraphics smoke 산출 |
| `output/task256-stage4/request-page1.png` | 기존 CoreGraphics smoke 산출 |
| `output/task256-stage4-compare/KTX-coregraphics.png` | 비교용 CoreGraphics 산출 |
| `output/task256-stage4-compare/KTX-skia-opt-in.png` | 비교용 Skia opt-in 산출 |
| `output/task256-stage4-compare/request-coregraphics.png` | 비교용 CoreGraphics 산출 |
| `output/task256-stage4-compare/request-skia-opt-in.png` | 비교용 Skia opt-in 산출 |

`output/`과 `build.noindex/`는 git ignored 산출물이다.

## Xcode build 검증

### HostApp

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask256 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [0.608 sec]
```

### QLExtension

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask256 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [0.410 sec]
```

### ThumbnailExtension

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask256 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [0.468 sec]
```

## 해석

- `coreGraphicsOnly` 기본 경로는 `validate-stage3-render.sh`에서 기존 render tree 기반 smoke를 통과했다.
- `skiaOptIn` 경로는 두 대표 샘플 모두에서 Skia PNG render와 ImageIO decode가 성공했다.
- `KTX.hwp`는 Skia와 CoreGraphics의 non-white pixel 수 차이가 크다. 이는 Stage 1 리스크에 기록한 font fallback, antialiasing, image scaling, renderer parity 차이 검증 대상이다.
- `request.hwp`는 PNG byte와 non-white pixel 차이가 상대적으로 작지만 완전 동일하지 않다.
- 이번 단계는 산출 차이를 pass/fail 기준으로 보지 않고, 후속 #257/#258/#259 판단을 위한 diagnostics와 비교 기준선을 남긴다.

## 변경 파일

- `mydocs/working/task_m020_256_stage4.md`
- `mydocs/orders/20260520.md`

## Stage 5 handoff

Stage 5에서는 Stage 1-4 산출과 검증 결과를 최종 보고서에 정리하고, #257 Quick Look 적용과 #258 Thumbnail 적용이 사용할 contract와 diagnostics를 명확히 남긴다.

## 잔여 리스크

- branch 상태는 `origin/devel` 대비 ahead 5, behind 7이다. Stage 4에서는 현재 `local/task256` 산출물 기준으로 검증했고, 통합 브랜치 재동기화는 별도 승인 범위에서 다룬다.
- fallback 강제 실패 path는 이번 runtime smoke에서 발생하지 않았다. mapping 자체는 Stage 3 source와 Stage 1/3 보고서에 고정되어 있다.
- 산출물 비교는 대표 샘플 2개의 첫 페이지 기준이다. 더 넓은 corpus 비교와 default 전환 판단은 후속 gate 범위다.

## 승인 요청

Stage 4를 완료한다. 승인 후 Stage 5 최종 보고서와 PR 준비로 진행한다.
