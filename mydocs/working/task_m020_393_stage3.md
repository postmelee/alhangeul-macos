# Task M020 #393 Stage 3 보고서

## 단계 목적

Quick Look 단일 페이지 Skia direct PNG path를 DEBUG/internal opt-in으로 구현하고, 기존 CoreGraphics PNG reply 및 Skia decode/re-encode path와 같은 smoke summary에서 비교 가능하게 만들었다.

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Sources/Shared/HwpPreviewPNGRenderer.swift` | 신규 Quick Look PNG reply helper. `coreGraphics`, `skiaDecode`, `skiaDirect` mode와 PNG header/IHDR validation, timing diagnostics 추가 |
| `Sources/QLExtension/HwpQuickLookPNGReplyModeResolver.swift` | 신규 DEBUG/internal resolver. `ALHANGEUL_QUICKLOOK_PNG_REPLY_MODE` env를 DEBUG에서만 해석 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | 단일 페이지 PNG reply에서 resolver와 `HwpPreviewPNGRenderer` 사용. 다중 PDF path는 유지 |
| `scripts/smoke-quicklook-skia-policy.sh` | smoke compile list에 신규 helper/resolver 추가, resolver contract 검증을 위해 `-DDEBUG` compile |
| `scripts/quicklook_skia_policy_smoke.swift` | `coreGraphics`, `skiaDecode`, `skiaDirect` 측정과 resolver contract summary/detail 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate`로 신규 Swift source를 target source phase에 반영 |
| `mydocs/orders/20260703.md` | #393 상태를 Stage 3 완료 후 승인 대기로 갱신 |

## 구현 계약

### Reply mode

`HwpPreviewPNGReplyMode`를 Shared에 추가했다.

| mode | 동작 |
|------|------|
| `coreGraphics` | `HwpPageImageRenderer.renderPage(... .coreGraphicsOnly)` 후 PNG encode |
| `skiaDecode` | `HwpPageImageRenderer.renderPage(... .skiaOptIn)` 후 PNG encode |
| `skiaDirect` | `RhwpDocument.renderPagePNG(at: 0, scale: 1, maxDimension: 0)` 결과 PNG bytes를 직접 반환 |

기존 `HwpPageRenderPolicy`는 변경하지 않았다. direct PNG는 `CGImage` 기반 shared renderer policy가 아니라 Quick Look PNG reply data mode로 분리했다.

### Resolver

`ALHANGEUL_QUICKLOOK_PNG_REPLY_MODE` env key를 추가했다.

| 입력 | DEBUG 결과 | Release 결과 |
|------|------------|--------------|
| missing/empty/invalid | `coreGraphics` | `coreGraphics` |
| `coreGraphics`, `coreGraphicsOnly` | `coreGraphics` | `coreGraphics` |
| `skia`, `skiaDecode`, `skiaOptIn` | `skiaDecode` | `coreGraphics` |
| `direct`, `skiaDirect` | `skiaDirect` | `coreGraphics` |

Stage 3 smoke는 DEBUG resolver contract를 검증한다. Release는 source의 `#if DEBUG` 경계로 env opt-in을 차단하며, 별도 Release smoke는 이번 단계에서 수행하지 않았다.

### Direct validation과 fallback

`skiaDirect` 성공 조건:

1. Quick Look 단일 페이지 context.
2. `renderPagePNG` status가 `.ok`.
3. PNG bytes가 non-empty.
4. PNG 8-byte signature가 유효.
5. 첫 chunk가 `IHDR`, length 13, width/height가 1 이상.

ImageIO decode는 direct path 검증에 사용하지 않았다. direct 실패 시 text fallback으로 가지 않고 CoreGraphics PNG reply shape으로 fallback한다. fallback diagnostics는 `HwpPreviewPNGDiagnostics.fallbackReason` 문자열에 남긴다.

## Smoke 결과

실행:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-stage3-quicklook-direct \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
```

결과:

- resolver contract: `OK`
- 5개 샘플 load/render: 모두 `OK`
- 단일 페이지 3개 샘플: `skiaDirect` fallback 0건
- 다중 페이지 2개 샘플: `skiaDirect`는 `N/A`
- `복학원서.hwp` 처리 중 기존 layout overflow warning 2줄이 stderr에 출력됐지만 render status는 모두 `OK`

요약:

| File | Reply | CGBytes/Sec | SkiaDecodeBytes/Sec | SkiaDirectBytes/Sec | SkiaDirectPNGBytes | DirectPixel | DirectFallback |
|------|------|-------------|---------------------|---------------------|--------------------|-------------|----------------|
| `request.hwp` | png | 90472 / 1.199618 | 84098 / 0.063675 | 87027 / 0.024707 | 87027 | 567x794 | 0 |
| `KTX.hwp` | png | 543472 / 0.075807 | 181314 / 0.056624 | 166247 / 0.047337 | 166247 | 1123x794 | 0 |
| `복학원서.hwp` | png | 223309 / 0.047160 | 196405 / 0.062583 | 198675 / 0.053175 | 198675 | 794x1123 | 0 |
| `hwp-multi-001.hwp` | pdf | 1398731 / 0.413798 | 1102131 / 0.493192 | N/A | N/A | - | - |
| `hwpx-01.hwpx` | pdf | 1377385 / 0.356351 | 1093637 / 0.480660 | N/A | N/A | - | - |

해석:

- direct path는 단일 페이지에서 output bytes와 Skia PNG bytes가 같다.
- direct path는 `PNGDecodeMs`와 `PNGEncodeMs`가 `-`로 남아 decode/re-encode를 생략한다.
- `request.hwp`, `KTX.hwp`, `복학원서.hwp` 모두 direct path가 fallback 없이 성공했다.
- 다중 PDF는 direct mode가 적용되지 않아 Stage 2 범위를 지켰다.

## Build/project 결과

`xcodegen generate`를 실행해 신규 Swift source를 Xcode project에 반영했다.

`project.pbxproj` 반영:

- `HwpPreviewPNGRenderer.swift`: Shared source이므로 HostApp, ThumbnailExtension, QLExtension source phase에 추가됨.
- `HwpQuickLookPNGReplyModeResolver.swift`: QLExtension source phase에만 추가됨.

QLExtension Debug build:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask393Stage3 CODE_SIGNING_ALLOWED=NO build
```

첫 실행은 sandbox 네트워크 제한 때문에 Sparkle package fetch에서 실패했다.

```text
Could not resolve host: github.com
```

동일 명령을 네트워크 허용으로 재실행했고 `BUILD SUCCEEDED`로 완료했다. CoreSimulator version warning은 출력됐지만 macOS build 실패로 이어지지 않았다.

## 검증 결과

실행한 검증:

```bash
./scripts/check-no-appkit.sh
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-stage3-quicklook-direct \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask393Stage3 CODE_SIGNING_ALLOWED=NO build
rg -n "direct|skiaOptIn|coreGraphicsOnly|Reply|Bytes|Fallback|RenderMs|Decode|Encode|OK|FAIL" \
  build.noindex/task393-stage3-quicklook-direct Sources scripts
git diff --check
```

결과:

- `check-no-appkit.sh`: 성공.
- Quick Look Skia policy smoke: 성공. resolver contract `OK`, 5개 샘플 모두 `OK`.
- `xcodegen generate`: 성공.
- `xcodebuild`: sandbox 첫 실행은 network fetch 실패, 네트워크 허용 재실행에서 `BUILD SUCCEEDED`.
- `rg`: direct/decode/CoreGraphics mode, resolver contract, smoke output, fallback/timing field 확인.
- `git diff --check`: 성공.

## 잔여 위험

| 항목 | 상태 | 다음 처리 |
|------|------|------|
| Release resolver smoke | source상 `#if DEBUG`로 차단 | 필요 시 review follow-up 또는 Stage 4에서 별도 Release compile smoke 추가 |
| direct path visual 품질 | 이번 Stage는 bytes/timing/fallback 검증 | Stage 4에서 대표 비교로 정리 |
| PNG header validation | signature/IHDR만 확인 | 의도적으로 ImageIO decode를 피함. invalid PNG fixture는 없음 |
| direct fallback 강제 fixture | 없음 | 정상 샘플 기준 fallback 0 확인. 실패 주입은 별도 이슈 후보 |
| 다중 PDF Skia latency | 여전히 CoreGraphics보다 느림 | direct PNG 범위 밖, #259 readiness 입력으로 유지 |

## 다음 단계 영향

Stage 4에서는 대표 샘플 결과를 재실행하거나 Stage 3 산출물을 기반으로 `coreGraphics`, `skiaDecode`, `skiaDirect`의 latency/bytes/fallback을 비교하고, #259 readiness gate로 넘길 direct path 판단을 정리한다.

## 승인 요청

Stage 3 opt-in direct PNG 구현과 smoke 보강을 완료했다. Stage 4 `대표 샘플 비교 측정`으로 진행 승인해 달라.
