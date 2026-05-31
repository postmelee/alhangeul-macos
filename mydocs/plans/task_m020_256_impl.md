# Task M020 #256 구현 계획서

수행계획서: `mydocs/plans/task_m020_256.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #256 Shared HwpPageImageRenderer에 Skia optional backend와 CoreGraphics fallback 추가
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 브랜치: `local/task256`
- 작업 위치: `/private/tmp/rhwp-mac-task256`
- 기준 브랜치: `devel`
- 선행 상태: #255에서 `rhwp_render_page_png` ABI와 `RhwpRenderStatus`가 추가되었고, 현재 `devel`의 `RustBridge/Cargo.toml`과 `rhwp-core.lock`은 `rhwp v0.7.12` + `native-skia` feature 기준이다.
- 목표: Swift bridge와 Shared renderer가 `coreGraphicsOnly` 기본 정책을 유지하면서 `skiaOptIn` 선택 시 Skia PNG backend를 먼저 시도하고, 실패하면 기존 CoreGraphics 경로로 fallback하도록 만든다.

## 구현 원칙

- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- Rust FFI에서 반환된 PNG bytes는 Swift `Data`로 복사한 뒤 `rhwp_free_bytes`로 반드시 해제한다.
- 기존 public 호출부의 기본 동작은 CoreGraphics 경로로 유지한다.
- Skia opt-in은 명시 인자를 통해서만 열린다. 이 이슈에서 Quick Look/Thumbnail user-facing 기본 정책을 바꾸지 않는다.
- Skia 실패는 Quick Look text fallback 또는 Thumbnail fallback tile로 바로 가지 않고 CoreGraphics fallback으로 먼저 회복한다.
- 진단 구조는 후속 #257/#258이 그대로 읽을 수 있게 `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs`를 포함한다.
- `HwpRenderedPage` 확장은 기존 호출부가 compile 호환되도록 기본값 또는 non-breaking initializer 형태로 처리한다.
- `Frameworks/`는 생성 산출물이므로 commit하지 않는다. 새 worktree에 산출물이 없으면 검증 단계에서 `./scripts/build-rust-macos.sh`로 생성한다.

## Backend Contract 초안

초기 Swift contract는 다음 의미를 갖도록 고정한다. 실제 타입명은 Stage 1 inventory 후 주변 코드 스타일에 맞춰 확정한다.

| 개념 | 후보 값 | 의미 |
|---|---|---|
| backend | `coreGraphics` | 최종 산출물이 기존 render tree + `CGTreeRenderer` 경로에서 생성됨 |
| backend | `skia` | 최종 산출물이 `rhwp_render_page_png` + PNG decode 경로에서 생성됨 |
| policy | `coreGraphicsOnly` | Skia를 시도하지 않고 기존 경로만 사용 |
| policy | `skiaOptIn` | Skia를 먼저 시도하고 실패 시 CoreGraphics fallback |

fallback reason 후보:

| reason | 조건 |
|---|---|
| `ffiUnavailable` | output pointer contract 실패, ABI 호출 불가에 준하는 상태 |
| `invalidDocumentHandle` | `RHWP_RENDER_INVALID_HANDLE` |
| `invalidPageIndex` | `RHWP_RENDER_INVALID_PAGE_INDEX` 또는 Swift page range guard 실패 |
| `invalidRenderOptions` | `RHWP_RENDER_INVALID_OPTIONS` |
| `invalidPageSize` | page size가 0, 음수, non-finite 등 bitmap 계약에 부적합 |
| `skiaRenderFailure` | `RHWP_RENDER_FAILURE`, 빈 PNG bytes |
| `pngDecodeFailure` | `CGImageSource` 또는 `CGImage` decode 실패 |
| `memoryTimeoutFallback` | timeout/memory pressure taxonomy 예약. 이 이슈에서는 별도 timeout 장치를 새로 만들지 않는다. |

진단 필드:

| 필드 | 정책 |
|---|---|
| `backendUsed` | 최종 반환된 `HwpRenderedPage`의 backend |
| `fallbackReason` | Skia를 시도한 뒤 CoreGraphics로 넘어간 경우에만 값 설정 |
| `pngBytes` | Skia PNG bytes를 성공적으로 받은 경우 byte count. Skia 미사용 또는 bytes 미수신 실패는 nil |
| `durationMs` | backend별 elapsed time. 가능하면 Skia render, PNG decode, CoreGraphics render를 분리 |

## Stage 1. Swift wrapper와 Shared renderer contract inventory

### 목표

#255 ABI handoff와 현재 Swift 호출부를 기준으로 실제 구현할 type/API contract를 확정한다.

### 작업

- `RhwpDocument`의 기존 FFI wrapper 패턴과 `rhwp_free_bytes` 사용 방식을 확인한다.
- `RustBridge/src/lib.rs`, `rhwp-ffi-symbols.txt`, `rhwp-core.lock`에서 현재 `rhwp_render_page_png` ABI와 `v0.7.12` provenance를 확인한다.
- `HwpPageImageRenderer`, `HwpPreviewPDFRenderer`, `HwpPreviewProvider`, `HwpThumbnailRenderCache` 호출부를 확인해 non-breaking API 형태를 정한다.
- `HwpRenderedPage` diagnostics 확장 위치를 정한다.
- `maximumPixelSize`를 `scale`/`max_dimension`으로 넘기는 초기 정책을 정한다. Stage 3 기본 후보는 기존 `renderScale`을 Skia `scale`로 넘기고, `max_dimension`은 후속 #258 cache/scale 정책에서 고정할 수 있도록 보수적으로 둔다.
- Stage 1 보고서에 확정된 type/API, fallback taxonomy, 검증 명령을 기록한다.

### 산출물

- `mydocs/working/task_m020_256_stage1.md`

### 검증

```bash
rg -n "rhwp_render_page_png|RhwpRenderStatus|rhwp_free_bytes|HwpRenderedPage|HwpPageImageRenderer|renderPage\\(" \
  Sources RustBridge rhwp-ffi-symbols.txt rhwp-core.lock
rg -n "backendUsed|fallbackReason|pngBytes|durationMs|coreGraphicsOnly|skiaOptIn" \
  mydocs/plans/task_m020_256.md mydocs/plans/task_m020_256_impl.md mydocs/working/task_m020_256_stage1.md
git diff --check
```

### 완료 기준

- Stage 2-3에서 구현할 Swift 타입과 fallback mapping이 단계 보고서에 고정된다.
- 아직 Swift source를 변경하지 않는다.

### 커밋 메시지

```text
Task #256 Stage 1: Skia Shared renderer contract 확정
```

## Stage 2. `RhwpDocument` Skia PNG wrapper 추가

### 목표

Swift bridge에서 `rhwp_render_page_png`를 안전하게 호출하고, 결과 bytes와 status를 Swift 타입으로 받을 수 있게 한다.

### 작업

- `Sources/RhwpCoreBridge/RhwpDocument.swift`에 Skia PNG render wrapper를 추가한다.
- `RhwpRenderStatus` status 값을 Swift enum/error로 매핑한다.
- wrapper 입력은 page index, scale, maxDimension 후보로 제한한다.
- 성공 시 PNG bytes를 `Data`로 복사하고 Rust buffer를 `rhwp_free_bytes`로 해제한다.
- 실패 시 status와 nil/empty bytes를 구분해 Stage 3 fallback reason으로 넘길 수 있게 한다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit import가 생기지 않았는지 확인한다.
- Stage 2 보고서에 wrapper contract와 status mapping을 기록한다.

### 산출물

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `mydocs/working/task_m020_256_stage2.md`

### 검증

```bash
./scripts/check-no-appkit.sh
rg -n "rhwp_render_page_png|RhwpRenderStatus|rhwp_free_bytes|renderPagePNG|Skia" Sources/RhwpCoreBridge
git diff --check -- Sources/RhwpCoreBridge/RhwpDocument.swift mydocs/working/task_m020_256_stage2.md
```

필요 시 새 worktree 산출물 준비:

```bash
./scripts/build-rust-macos.sh
```

가능하면 compile 확인:

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
```

### 완료 기준

- Swift wrapper가 C ABI status와 PNG buffer 수명을 명확히 다룬다.
- `RhwpCoreBridge` platform-neutral 규칙을 유지한다.
- HostApp Debug build 또는 산출물 준비 실패 원인이 보고서에 명확히 기록된다.

### 커밋 메시지

```text
Task #256 Stage 2: RhwpDocument Skia PNG wrapper 추가
```

## Stage 3. `HwpPageImageRenderer` backend abstraction과 CoreGraphics fallback 구현

### 목표

Shared renderer가 `coreGraphicsOnly`와 `skiaOptIn` 정책을 받고, Skia 실패 시 기존 CoreGraphics 경로로 fallback하도록 만든다.

### 작업

- `Sources/Shared/HwpPageImageRenderer.swift`에 render backend/policy/diagnostics 타입을 추가한다.
- `HwpRenderedPage`에 diagnostics를 non-breaking 방식으로 추가한다.
- 기존 CoreGraphics 렌더 본문을 helper로 분리해 fallback에서 재사용한다.
- `skiaOptIn`에서는 page size와 scale을 계산한 뒤 `RhwpDocument` Skia wrapper를 호출한다.
- Skia PNG bytes는 `ImageIO`로 `CGImage` decode한다.
- status failure, 빈 bytes, decode failure, invalid page size는 CoreGraphics fallback으로 회복하고 reason을 diagnostics에 남긴다.
- 기존 `renderFirstPage`와 `renderPage` 호출부는 default policy로 compile 호환되게 둔다.
- Stage 3 보고서에 변경 API와 fallback matrix를 기록한다.

### 산출물

- `Sources/Shared/HwpPageImageRenderer.swift`
- 필요 시 compile 호환성 보정: `Sources/Shared/HwpPreviewPDFRenderer.swift`, `Sources/QLExtension/HwpPreviewProvider.swift`, `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- `mydocs/working/task_m020_256_stage3.md`

### 검증

```bash
./scripts/check-no-appkit.sh
rg -n "coreGraphicsOnly|skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs|pngDecodeFailure|skiaRenderFailure" Sources
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

### 완료 기준

- 기존 default 호출은 CoreGraphics 결과를 유지한다.
- `skiaOptIn` 성공과 fallback이 같은 `HwpRenderedPage` 계약으로 반환된다.
- 후속 #257/#258이 읽을 diagnostics가 public/internal Swift 타입으로 노출된다.

### 커밋 메시지

```text
Task #256 Stage 3: Shared renderer Skia opt-in fallback 구현
```

## Stage 4. 렌더 smoke와 Skia/CoreGraphics 산출 비교

### 목표

대표 샘플에서 기본 CoreGraphics 경로 회귀가 없는지 확인하고, Skia opt-in 경로의 성공 또는 fallback diagnostics를 기록한다.

### 작업

- 새 worktree에 `Frameworks/Rhwp.xcframework`가 없으면 `./scripts/build-rust-macos.sh`로 생성한다.
- `./scripts/validate-stage3-render.sh`로 기존 CoreGraphics smoke를 실행한다.
- 대표 샘플 최소 1개(`samples/basic/KTX.hwp` 우선, 필요 시 `samples/basic/request.hwp`)에서 CoreGraphics와 Skia opt-in 렌더 결과를 생성한다.
- 필요한 경우 기존 smoke script를 커밋 대상이 아닌 임시 command 또는 task 전용 보조 경로로 사용한다. 재사용 가치가 분명하면 작은 script 추가를 Stage 4 범위에서 검토한다.
- 산출 비교는 page size, image pixel size, PNG byte count, non-white pixel 또는 파일 byte 차이를 최소 기록한다.
- fallback을 강제하기 어려운 failure path는 status mapping unit 수준 또는 code path 분석으로 남긴다.
- Stage 4 보고서에 명령, 결과, 산출 위치, 잔여 리스크를 기록한다.

### 산출물

- 필요 시 검증 보조 script 또는 임시 산출물 기록
- `mydocs/working/task_m020_256_stage4.md`

### 검증

```bash
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh output/task256-stage4 samples/basic/KTX.hwp samples/basic/request.hwp
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

필요 시 lock 확인:

```bash
./scripts/build-rust-macos.sh --verify-lock
```

### 완료 기준

- 기존 CoreGraphics smoke가 통과한다.
- Skia opt-in path의 `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs`가 보고서에 기록된다.
- 대표 샘플 1개 이상에서 Skia/CoreGraphics 산출 차이 또는 fallback 결과가 남는다.

### 커밋 메시지

```text
Task #256 Stage 4: Skia Shared renderer smoke 검증
```

## Stage 5. 최종 보고서와 PR 준비

### 목표

전체 수용 기준을 다시 확인하고, 최종 결과보고서와 오늘할일 완료 처리를 수행한 뒤 PR 게시 준비 상태로 만든다.

### 작업

- Stage 1-4 산출물과 검증 결과를 최종 보고서에 정리한다.
- #257 Quick Look 적용과 #258 Thumbnail 적용이 사용할 backend contract와 diagnostics를 명확히 남긴다.
- 오늘할일 상태를 완료로 갱신한다.
- 최종 검증 후 작업트리를 clean 상태로 만든다.

### 산출물

- `mydocs/report/task_m020_256_report.md`
- `mydocs/orders/20260519.md`

### 검증

```bash
./scripts/check-no-appkit.sh
rg -n "coreGraphicsOnly|skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs|#257|#258" \
  Sources mydocs/report/task_m020_256_report.md mydocs/orders/20260519.md
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
git diff --check
git status --short --branch
```

### 완료 기준

- 최종 보고서가 API contract, fallback matrix, smoke 결과, 잔여 리스크를 포함한다.
- #257/#258 handoff 조건이 명확하다.
- 작업트리가 clean이고 PR 게시 승인 요청을 할 수 있다.

### 커밋 메시지

```text
Task #256 Stage 5 + 최종 보고서: Shared renderer Skia backend 정리
```

## PR 계획

- 작업 브랜치: `local/task256`
- 게시 브랜치: `publish/task256`
- 대상 브랜치: `devel`
- PR 제목 후보: `Task #256: Shared renderer Skia optional backend 추가`
- PR 본문에는 backend contract, fallback reason mapping, 대표 샘플 smoke 결과, #257/#258 handoff를 포함한다.

## 변경 금지 사항

- `Skia first` 또는 `Skia default` 전환을 하지 않는다.
- Quick Look/Thumbnail provider의 사용자-facing 기본 backend 정책을 바꾸지 않는다.
- Thumbnail cache key 정책은 #258 전에는 변경하지 않는다.
- `Alhangeul.xcodeproj`를 직접 수정하지 않는다. 필요 시 `project.yml` 변경 후 `xcodegen generate`만 사용한다.
- `Frameworks/` 생성 산출물을 commit하지 않는다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존을 추가하지 않는다.
