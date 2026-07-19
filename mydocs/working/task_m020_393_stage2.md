# Task M020 #393 Stage 2 보고서

## 단계 목적

Quick Look 단일 페이지 Skia direct PNG fast path의 적용 조건, fallback shape, diagnostics, smoke output contract를 source 변경 전에 확정했다.

이번 단계는 설계 고정 단계다. 제품 source는 변경하지 않았다.

## 산출물

| 파일/산출물 | 내용 |
|------|------|
| `mydocs/working/task_m020_393_stage2.md` | direct PNG reply contract 설계 |
| `mydocs/orders/20260703.md` | #393 진행 상태를 Stage 2 완료 후 승인 대기로 갱신 |

## 설계 결론

Stage 3 구현은 Quick Look 단일 페이지 PNG reply 전용 helper를 추가하는 방향으로 진행한다. 기존 `HwpPageRenderPolicy`는 `CGImage`를 반환하는 shared renderer 정책으로 유지하고, direct PNG는 Quick Look PNG reply mode로 분리한다.

핵심 결정:

| 항목 | 결정 |
|------|------|
| default | production/default provider는 계속 CoreGraphics PNG reply |
| opt-in 경계 | DEBUG/internal env opt-in에서만 provider direct mode 사용 가능 |
| direct 범위 | Quick Look 단일 페이지 PNG reply만 대상 |
| 비대상 | Thumbnail, Quick Look 다중 PDF, HostApp viewer/editor, upstream `rhwp` |
| direct 성공 | Skia PNG status OK, non-empty bytes, PNG signature/IHDR validation 성공 |
| direct 실패 | Quick Look text fallback이 아니라 CoreGraphics PNG reply로 fallback |
| diagnostics | 기존 `HwpPageRenderDiagnostics`는 유지하고 Quick Look PNG 전용 diagnostics를 추가 |
| smoke | `coreGraphics`, `skiaDecode`, `skiaDirect`를 같은 summary/detail에서 비교 |

## Provider opt-in contract

새 resolver 후보:

```swift
enum HwpQuickLookPNGReplyMode {
    case coreGraphics
    case skiaDecode
    case skiaDirect
}

enum HwpQuickLookPNGReplyModeResolver {
    static let environmentKey = "ALHANGEUL_QUICKLOOK_PNG_REPLY_MODE"
}
```

resolver 동작:

| 입력 | DEBUG 결과 | Release 결과 |
|------|------------|--------------|
| missing/empty/invalid | `.coreGraphics` | `.coreGraphics` |
| `coreGraphics`, `coreGraphicsOnly` | `.coreGraphics` | `.coreGraphics` |
| `skia`, `skiaDecode`, `skiaOptIn` | `.skiaDecode` | `.coreGraphics` |
| `direct`, `skiaDirect` | `.skiaDirect` | `.coreGraphics` |

값 비교는 Thumbnail resolver와 같은 방식으로 trim, lowercase, `-`/`_` 제거 후 수행한다. `resolve(environment:)` 기본 인자는 `nil`로 두고, DEBUG에서만 `ProcessInfo.processInfo.environment`를 평가한다. Release에서는 환경변수 딕셔너리를 읽지 않고 항상 `.coreGraphics`를 반환한다.

Provider 적용:

1. `HwpPreviewProvider.createPreview`는 page count가 1인 경우에만 resolver를 호출한다.
2. missing/invalid env에서는 지금과 동일하게 CoreGraphics PNG reply를 생성한다.
3. `.skiaDecode`는 기존 diagnostic path와 같은 `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn) -> encodePNG` 경로를 provider에서 직접 확인할 수 있게 둔다.
4. `.skiaDirect`는 Skia PNG bytes를 `QLPreviewReply(dataOfContentType: .png)` data block에 그대로 반환한다.
5. page count가 2 이상이면 resolver 결과와 무관하게 기존 PDF reply path를 유지한다.

환경 key를 새로 두는 이유:

- 기존 Thumbnail env key인 `ALHANGEUL_THUMBNAIL_RENDER_POLICY`와 surface를 분리한다.
- `HwpPageRenderPolicy.skiaOptIn`은 `CGImage` 기반 shared renderer policy이고, direct PNG는 reply data mode이므로 같은 enum에 넣지 않는다.
- `skia` 값을 기존 decode path로 해석하고, direct path는 `direct` 또는 `skiaDirect`를 요구해 우발적 direct 활성화를 피한다.

## Direct render helper contract

새 shared helper 후보:

```swift
struct HwpRenderedPreviewPNG {
    let data: Data
    let contentSize: CGSize
    let diagnostics: HwpPreviewPNGDiagnostics
}

struct HwpPreviewPNGDiagnostics {
    let requestedMode: HwpQuickLookPNGReplyMode
    let outputMode: HwpQuickLookPNGReplyMode
    let backendUsed: HwpPageRenderBackend
    let fallbackReason: String?
    let outputBytes: Int
    let skiaPNGBytes: Int?
    let pngPixelSize: CGSize?
    let durationMs: HwpPreviewPNGDuration
}
```

helper 위치는 `Sources/Shared/HwpPreviewPNGRenderer.swift`를 우선한다. 이 파일은 QuickLookUI에 의존하지 않고 `Foundation`, `CoreGraphics`만 사용한다. provider는 이 helper 결과를 `QLPreviewReply`로 감싸고, smoke helper도 같은 helper를 호출해 product path와 측정 path의 contract를 맞춘다.

Mode별 동작:

| mode | 동작 | output data |
|------|------|-------------|
| `.coreGraphics` | `HwpPageImageRenderer.renderPage(... .coreGraphicsOnly)` 후 `encodePNG` | CoreGraphics encoded PNG |
| `.skiaDecode` | `HwpPageImageRenderer.renderPage(... .skiaOptIn)` 후 `encodePNG` | Skia decoded CGImage를 재인코딩한 PNG |
| `.skiaDirect` | `RhwpDocument.renderPagePNG(at: 0, scale: 1, maxDimension: 0)` 직접 호출 | upstream Skia PNG bytes |

`.skiaDirect` 성공 조건:

1. page index는 0으로 고정한다.
2. `context.pageCount == 1`에서만 호출한다.
3. `renderPagePNG` 결과가 `status == .ok`여야 한다.
4. PNG bytes가 비어 있지 않아야 한다.
5. PNG 8-byte signature가 유효해야 한다.
6. IHDR chunk를 읽어 width/height가 1 이상인지 확인한다.

PNG validation은 ImageIO decode를 사용하지 않는다. 목적은 direct path가 `CGImageSourceCreateImageAtIndex`와 `CGImageDestinationFinalize` 비용을 피하는지 확인하는 것이므로, direct 성공 검증은 bytes/header 수준에 한정한다.

## Fallback contract

`.skiaDirect` 실패 시 흐름:

```text
Skia direct PNG attempt
-> status/bytes/header 실패
-> CoreGraphics PNG reply fallback
-> fallback도 실패하면 기존 provider catch에서 text fallback 또는 throw
```

fallback reason 문자열 후보:

| reason | 의미 |
|------|------|
| `skiaRenderFailure` | upstream status failure 또는 empty bytes |
| `invalidPNGHeader` | PNG signature 또는 IHDR validation 실패 |
| `coreGraphicsFallbackFailure` | direct 실패 후 CoreGraphics fallback도 실패 |

기존 `HwpPageRenderFallbackReason` enum은 Stage 3에서 확장하지 않는다. 이유는 direct path가 `HwpRenderedPage`를 반환하지 않고 PNG reply data를 직접 반환하기 때문이다. direct path 전용 실패 이유는 `HwpPreviewPNGDiagnostics.fallbackReason` 문자열로 남기고, shared renderer fallback enum은 기존 decode path와 Thumbnail/PDF에서만 사용한다.

CoreGraphics fallback shape:

- reply content type은 `.png` 유지
- content size는 `HwpPreviewDocumentContext.contentSize` 유지
- title은 기존 filename 유지
- fallback output bytes는 CoreGraphics encoded PNG bytes
- diagnostics에는 requested mode `.skiaDirect`, output mode `.coreGraphics`, backend `.coreGraphics`, direct fallback reason을 남김

## Diagnostics contract

`HwpPreviewPNGDuration` 후보:

```swift
struct HwpPreviewPNGDuration {
    let skiaRenderMs: Double?
    let pngHeaderValidateMs: Double?
    let pngDecodeMs: Double?
    let pngEncodeMs: Double?
    let coreGraphicsRenderMs: Double?
    let totalMs: Double
}
```

Mode별 값:

| mode | skiaRenderMs | headerValidateMs | decodeMs | encodeMs | coreGraphicsRenderMs |
|------|--------------|------------------|----------|----------|----------------------|
| `coreGraphics` | nil | nil | nil | PNG encode 별도 측정 | render diagnostics의 coreGraphics render |
| `skiaDecode` | render diagnostics의 skia render | nil | render diagnostics의 decode | PNG encode 별도 측정 | fallback이면 값 존재 |
| `skiaDirect` 성공 | direct `renderPagePNG` 측정 | PNG header/IHDR validation 측정 | nil | nil | nil |
| `skiaDirect` fallback | direct attempt 측정 | 실패 지점까지 측정 | nil | fallback PNG encode 측정 | fallback render 측정 |

Stage 3에서 encode time을 분리하려면 `HwpPageImageRenderer.encodePNG` 호출 주위에서 시간을 잰다. 기존 `HwpPageRenderDiagnostics.durationMs`에는 PNG encode 시간이 포함되지 않으므로, Quick Look PNG reply helper가 별도 측정해야 한다.

로그 후보:

- `mode`: requested/output mode
- `backend`: `coreGraphics` 또는 `skia`
- `fallback`: 없으면 `-`
- `outputBytes`
- `skiaPNGBytes`
- `pngPixelSize`
- `totalMs`
- `skiaRenderMs`
- `decodeMs`
- `encodeMs`

## Smoke output contract

`scripts/quicklook_skia_policy_smoke.swift`는 Stage 3에서 다음 구조로 확장한다.

단일 페이지:

- `coreGraphics`: CoreGraphics PNG reply 후보
- `skiaDecode`: 기존 Skia decode + encode path
- `skiaDirect`: 신규 Skia direct PNG path

다중 페이지:

- 기존처럼 `coreGraphics`와 `skiaDecode` PDF path만 측정한다.
- `skiaDirect`는 `-` 또는 `notApplicable`로 기록한다.

summary column 후보:

| column | 의미 |
|------|------|
| `File` | 입력 파일 basename |
| `Load` | load status |
| `Reply` | `png` 또는 `pdf` |
| `Pages` | page count |
| `CGStatus`, `CGBytes`, `CGSeconds` | CoreGraphics 결과 |
| `SkiaDecodeStatus`, `SkiaDecodeBytes`, `SkiaDecodePNGBytes`, `SkiaDecodeSeconds` | 기존 decode path 결과 |
| `SkiaDirectStatus`, `SkiaDirectBytes`, `SkiaDirectPNGBytes`, `SkiaDirectSeconds` | direct path 결과 |
| `SkiaDirectFallback` | direct fallback reason |
| `SkiaDirectPixel` | PNG IHDR pixel size |

detail file에는 mode별 timing breakdown을 기록한다.

resolver contract 검증:

- smoke script는 `-DDEBUG`로 compile해 resolver DEBUG opt-in behavior를 확인한다.
- 별도 Release resolver 확인은 Stage 3 또는 review follow-up에서 필요 시 추가한다.
- provider env resolver 검증과 smoke mode별 직접 측정은 구분한다. smoke는 env를 바꿔 측정하지 않고 helper를 직접 mode별 호출한다.

## Source 변경 범위

Stage 3 예상 source:

| 파일 | 변경 |
|------|------|
| `Sources/Shared/HwpPreviewPNGRenderer.swift` | 신규 PNG reply renderer/helper, diagnostics, PNG header parser |
| `Sources/QLExtension/HwpQuickLookPNGReplyModeResolver.swift` | 신규 DEBUG/internal resolver |
| `Sources/QLExtension/HwpPreviewProvider.swift` | 단일 페이지 PNG reply에서 resolver와 helper 사용 |
| `scripts/quicklook_skia_policy_smoke.swift` | `coreGraphics`, `skiaDecode`, `skiaDirect` 측정으로 확장 |
| `scripts/smoke-quicklook-skia-policy.sh` | 신규 Swift source compile list와 `-DDEBUG` 반영 |
| `Alhangeul.xcodeproj/project.pbxproj` | 신규 Swift source 반영을 위해 `xcodegen generate` 실행 시 변경 가능 |

`project.yml`은 이미 `Sources/QLExtension`과 `Sources/Shared` directory source를 포함한다. 신규 Swift source가 실제 Xcode project에 반영되도록 Stage 3에서 `xcodegen generate`를 실행한다.

## 비변경 범위

- `RhwpDocument.renderPagePNG` ABI와 Rust wrapper는 변경하지 않는다.
- `HwpPageRenderPolicy` enum은 변경하지 않는다.
- Thumbnail source와 cache signature는 변경하지 않는다.
- Quick Look 다중 페이지 PDF renderer는 direct mode를 적용하지 않는다.
- Skia default 전환 판단은 하지 않는다.

## 검증 결과

구현계획서 Stage 2 검증:

```bash
rg -n "QLPreviewReply|renderPagePNG|HwpPageRenderDiagnostics|HwpPreview|quicklook|direct|skiaOptIn|fallback" \
  Sources/QLExtension/HwpPreviewProvider.swift Sources/Shared/HwpPageImageRenderer.swift \
  Sources/RhwpCoreBridge/RhwpDocument.swift scripts/quicklook_skia_policy_smoke.swift \
  mydocs/working/task_m020_393_stage2.md
git diff --check
```

`rg`는 provider, shared renderer, RustBridge wrapper, smoke helper, Stage 2 문서의 contract 지점을 확인하는 용도로 사용한다. `git diff --check`는 Stage 2 문서 작성 후 통과시킨다.

## 잔여 위험

| 항목 | 상태 | 다음 처리 |
|------|------|------|
| PNG header parser 구현 | 아직 미구현 | Stage 3에서 signature/IHDR parser를 작게 추가 |
| provider direct path 실제 실행 | 아직 미구현 | Stage 3에서 DEBUG env opt-in으로 연결 |
| Release resolver 검증 | 설계상 Release 차단 | Stage 3 이후 필요 시 별도 Release smoke 추가 |
| visual 품질 | direct path가 해결하지 않음 | Stage 4/#259에서 별도 판단 |
| 다중 PDF latency | Skia decode path가 느린 상태 | 이번 task direct 범위 밖 |

## 다음 단계 영향

Stage 3는 source 구현 단계다. 구현 순서는 `HwpPreviewPNGRenderer` 추가, provider resolver 추가, provider 연결, smoke helper 확장, smoke/build 검증 순서가 적절하다.

## 승인 요청

Stage 2 direct PNG reply contract 설계를 완료했다. Stage 3 `opt-in direct PNG 구현과 smoke 보강`으로 진행 승인해 달라.
