# Skia Quick Look/Thumbnail optional backend 설계

## 목적

이 문서는 Quick Look preview와 Finder thumbnail에 upstream `rhwp` native Skia PNG renderer를 optional backend로 도입하기 위한 backend 선택 정책과 fallback contract를 정의한다.

현재 제품 기준선은 `PageRenderTree` JSON을 Swift `CGTreeRenderer`가 CoreGraphics/CoreText로 그리는 경로다. Skia 후보는 upstream `rhwp v0.7.11`의 `native-skia` feature가 제공하는 `PageLayerTree` 기반 PNG export 경로다.

## 범위

- Quick Look preview extension의 단일 페이지 PNG reply와 다중 페이지 bitmap PDF reply
- Finder Thumbnail extension의 첫 페이지 bitmap thumbnail
- Shared renderer 계층의 backend 선택, fallback, 진단 필드
- 후속 이슈 #255-#259가 구현할 정책 기준

## 비범위

- HostApp WKWebView viewer renderer 전환
- browser CanvasKit renderer 도입
- vector PDF export 품질 개선
- Swift `PageLayerTree` renderer 완성
- upstream `rhwp` 자체 수정
- 사용자 설정 UI 노출

## 현재 기준선

현재 Quick Look/Thumbnail 공통 raster path는 `HwpPageImageRenderer`다.

- `RhwpDocument.renderPageTree(at:)`가 `rhwp_render_page_tree` FFI를 호출한다.
- `HwpPageImageRenderer.renderPage`가 render tree와 page size를 읽어 `CGContext`에 그린다.
- Quick Look 단일 페이지는 `CGImage`를 PNG로 인코딩한다.
- Quick Look 다중 페이지는 각 page `CGImage`를 PDF page에 그린다.
- Thumbnail은 `HwpThumbnailRenderCache`를 거쳐 첫 페이지 `CGImage`를 Finder context에 그린다.

따라서 Skia 도입은 Shared renderer 계층의 backend 선택으로 모델링한다. Quick Look/Thumbnail extension이 각각 별도 Skia 호출 규칙을 복제하지 않도록 한다.

## backend 후보

| 후보 | 설명 | 장점 | 단점 | Stage 2 판단 |
|---|---|---|---|---|
| `CoreGraphics only` | 현재 Swift `CGTreeRenderer` 경로만 사용 | 현재 동작과 package size 유지, fallback 단순 | upstream Skia 개선을 사용하지 못함, Swift renderer parity gap 유지 | 현재 기본값으로 유지 |
| `Skia opt-in` | debug flag 또는 internal policy에서만 Skia를 먼저 시도하고 실패 시 CoreGraphics로 fallback | 제품 위험이 낮고 visual/performance 비교 가능, 후속 이슈를 작게 나눌 수 있음 | 사용자 기본 경험은 당장 개선되지 않음, 두 backend 진단과 cache 분기가 필요 | 첫 구현 권장 |
| `Skia first + CoreGraphics fallback` | 일반 경로에서 Skia를 먼저 사용하고 실패 시 CoreGraphics 사용 | native Skia coverage를 넓게 검증 가능, Swift render tree gap을 우회할 수 있음 | package/load time과 font 차이를 충분히 보기 전에는 회귀 위험이 큼 | #259 readiness gate 통과 후 후보 |
| `Skia default` | CoreGraphics fallback을 예외적 backup 또는 제거 후보로 둠 | 장기적으로 renderer path 단순화 가능 | fallback 제거 시 extension 안정성이 떨어지고 upstream 변경 영향이 커짐 | 현재 보류 |

Stage 2 결론은 `CoreGraphics only`를 기본값으로 유지하고, #256 이후 구현은 `Skia opt-in`으로 시작하는 것이다. `Skia first`와 `Skia default`는 visual/performance/package readiness가 통과된 뒤 별도 승인으로 전환한다.

## backend contract 초안

후속 구현의 개념 모델은 다음과 같이 둔다.

| 개념 | 값 | 의미 |
|---|---|---|
| backend | `coreGraphics` | 현재 `PageRenderTree` + `CGTreeRenderer` |
| backend | `skiaPNG` | upstream `PageLayerTree` + native Skia PNG export |
| policy | `coreGraphicsOnly` | Skia를 호출하지 않는다 |
| policy | `skiaOptIn` | opt-in 조건에서 Skia를 먼저 시도하고 실패 시 CoreGraphics |
| policy | `skiaFirstCoreGraphicsFallback` | 일반 경로에서 Skia를 먼저 시도하고 실패 시 CoreGraphics |
| policy | `skiaDefault` | Skia를 기본 성공 경로로 보고 CoreGraphics fallback은 제한적으로만 사용 |

Shared renderer는 결과에 `backendUsed`, `fallbackReason`, `pageSize`, `pixelSize`를 진단 가능하게 남겨야 한다. Thumbnail cache key에는 backend 또는 render signature를 포함해야 하며, fallback으로 생성된 CoreGraphics bitmap을 Skia 결과처럼 재사용하지 않아야 한다.

## failure taxonomy

| reason | 정의 | Quick Look 처리 | Thumbnail 처리 | 로그 수준 |
|---|---|---|---|---|
| `ffiUnavailable` | `native-skia` feature 미포함, C ABI symbol 부재, Swift bridge API 부재 | CoreGraphics fallback. CoreGraphics도 없으면 기존 fallback text reply | CoreGraphics fallback. CoreGraphics도 실패하면 fallback tile | warning |
| `skiaRenderFailure` | upstream Skia 호출이 error를 반환하거나 빈 PNG bytes를 반환 | CoreGraphics fallback | CoreGraphics fallback | warning |
| `pngDecodeFailure` | Skia PNG bytes를 `CGImageSource`/`CGImage`로 decode하지 못함 | CoreGraphics fallback | CoreGraphics fallback | warning |
| `invalidPageSize` | page size가 0 이하, NaN, infinite, 또는 pixel 계산 불가 | backend 전환 없이 기존 fallback classifier로 처리 | backend 전환 없이 fallback tile 후보로 처리 | warning |
| `fileSizeFallback` | 기존 50 MB guard 또는 extension policy상 render를 시도하지 않음 | Skia도 시도하지 않고 기존 text fallback | small thumbnail 정책이 별도로 승인되기 전에는 기존 fallback tile | info 또는 warning |
| `memoryTimeoutFallback` | Skia render/decode가 timeout, memory pressure, allocation 실패로 중단 | CoreGraphics fallback. 동일 실패가 반복되면 text fallback | CoreGraphics fallback. 동일 실패가 반복되면 fallback tile | warning |
| `coreGraphicsFallbackFailure` | Skia 실패 후 CoreGraphics fallback도 실패 | 기존 `HwpDocumentFallbackClassifier` 기준 text reply 또는 throw | 기존 fallback tile 또는 handler error | error |

`invalidPageSize`, `fileSizeFallback`은 Skia와 CoreGraphics 중 어느 renderer가 더 나은지의 문제가 아니라 입력/정책 문제다. 이 경우 Skia를 우회 수단으로 쓰지 않는다.

## Quick Look 정책

Quick Look은 사용자에게 문서 내용을 크게 보여주는 surface이므로 안정성과 실패 설명을 우선한다.

- 기본 policy는 `coreGraphicsOnly`다.
- `skiaOptIn`에서는 단일 페이지 PNG reply에 Skia PNG를 먼저 시도할 수 있다.
- 다중 페이지 PDF reply는 현재 bitmap PDF이므로 Skia PNG를 page별로 decode해서 넣을 수는 있지만, 초기 opt-in에서는 별도 flag로 분리한다.
- file size guard는 Skia보다 앞에서 실행한다.
- Skia 실패는 text fallback으로 바로 가지 않고 CoreGraphics fallback을 먼저 시도한다.
- CoreGraphics fallback까지 실패하면 기존 `HwpDocumentFallbackClassifier`의 text reply 정책을 유지한다.

Quick Look에서 Skia가 직접 PNG bytes를 반환하는 장점은 단일 페이지 PNG reply에서 Swift `CGImage` 생성과 PNG 재인코딩을 줄일 수 있다는 점이다. 반면 다중 페이지 PDF는 `CGImage` decode가 필요하므로 초기 성능 이득을 단정하지 않는다.

## Thumbnail 정책

Thumbnail은 작은 bitmap을 빠르게 제공하는 surface이므로 latency, memory, cache 안정성을 우선한다.

- 기본 policy는 `coreGraphicsOnly`다.
- `skiaOptIn`에서는 `HwpThumbnailRenderRequest.maximumPixelSize`의 긴 변을 upstream `PngExportOptions.max_dimension`에 매핑한다.
- Skia PNG bytes는 Finder context에 직접 그릴 수 없으므로 `CGImage` decode가 필요하다.
- cache key에는 file identity, pixel bucket에 더해 backend 또는 render signature를 포함한다.
- Skia 실패는 fallback tile로 바로 가지 않고 CoreGraphics fallback을 먼저 시도한다.
- CoreGraphics fallback까지 실패하면 기존 fallback tile 정책을 유지한다.

Thumbnail은 Quick Look보다 `max_dimension` 매핑이 명확하다. 다만 PNG decode 비용과 cache key 변화가 있으므로 `Skia first` 전환은 Quick Look과 독립적으로 판단한다.

## option mapping

| 입력 | CoreGraphics 현재 처리 | Skia 후보 매핑 |
|---|---|---|
| Quick Look 단일 페이지 | page size 기준 1x bitmap 후 PNG encode | `scale = 1.0`부터 시작. 이후 target size 정책이 생기면 scale 계산 |
| Quick Look 다중 페이지 | page size 기준 page별 bitmap을 PDF에 draw | 초기 opt-in에서는 CoreGraphics 유지. 별도 flag에서 page별 `scale = 1.0` 검증 |
| Thumbnail maximum size/scale | `maximumPixelSize` bucket 계산 후 renderScale 산출 | 긴 변을 `PngExportOptions.max_dimension`에 매핑 |
| file size > 50 MB | render 전 거절 | Skia 호출 전 동일하게 거절 |
| font paths | Swift renderer가 bundled WOFF2/system fallback 사용 | upstream `font_paths` 지원은 별도 검증 후 연결 |

## 로그와 진단 필드

extension-safe `OSLog.Logger` 필드 후보는 다음과 같다.

| 필드 | 예시 | 비고 |
|---|---|---|
| `surface` | `quicklook`, `thumbnail` | 호출 surface |
| `replyType` | `png`, `pdf`, `tile`, `text` | Quick Look/Thumbnail 결과 형식 |
| `policy` | `coreGraphicsOnly`, `skiaOptIn` | 선택 정책 |
| `backendRequested` | `skiaPNG` | 최초 시도 backend |
| `backendUsed` | `coreGraphics` | 실제 성공 backend |
| `fallbackReason` | `pngDecodeFailure` | fallback이 없으면 생략 |
| `pageIndex` | `0` | page별 진단 |
| `pageCount` | `1` | 문서 page count |
| `pageSize` | `595x842` | 문서 좌표계 크기 |
| `pixelSize` | `1024x1448` | 실제 bitmap 크기 |
| `fileSize` | `123456` | byte 단위, path 전체는 기록하지 않음 |
| `durationMs` | `38` | render 또는 decode 구간 |
| `pngBytes` | `456789` | Skia PNG bytes 길이 |
| `cacheHit` | `true` | Thumbnail cache 진단 |

파일명은 현재 코드처럼 basename만 public으로 남기고 full path는 기록하지 않는다. fallback reason은 문자열 enum으로 고정해 후속 visual/performance report에서 집계 가능하게 한다.

## Stage 2 결론

- 지금 기본값은 `CoreGraphics only`로 유지한다.
- 첫 구현은 `Skia opt-in`이며, 실패 시 CoreGraphics fallback을 반드시 유지한다.
- Quick Look과 Thumbnail은 같은 Shared backend contract를 쓰되 rollout 판단은 분리한다.
- `invalidPageSize`와 `fileSizeFallback`은 renderer fallback이 아니라 입력/정책 fallback으로 취급한다.
- Thumbnail cache key에는 backend/render signature를 포함해야 한다.
- `Skia first`와 `Skia default`는 #259 readiness gate 통과 전에는 열지 않는다.

## 후속 이슈 의존 순서

Skia optional backend는 다음 순서로 진행한다.

```text
#255 ABI gate
-> #256 Shared renderer gate
-> #257 Quick Look integration gate
-> #258 Thumbnail integration gate
-> #259 release readiness gate
```

#257과 #258은 #256의 Shared renderer contract가 고정된 뒤에는 서로 독립적으로 진행할 수 있다. 다만 한 작업자가 순차 진행할 때는 Quick Look의 단일/다중 page path를 먼저 검증한 뒤 Thumbnail cache와 scale 정책을 붙이는 순서가 리뷰하기 쉽다.

## #255 ABI gate

#255는 RustBridge와 binary provenance가 소유한다.

입력 조건:

- `rhwp-core.lock`과 `RustBridge/Cargo.toml`이 `rhwp v0.7.11` release tag 기준으로 정합해야 한다.
- Stage 2 failure taxonomy 중 `ffiUnavailable`, `skiaRenderFailure`, `invalidPageSize`를 ABI 설계 입력으로 사용한다.
- upstream `DocumentCore::render_page_png_native_with_export_options`와 `PngExportOptions`의 `scale`, `max_dimension`, `font_paths` 대응 방식을 확인한다.

완료 조건:

- Swift에서 호출 가능한 Skia PNG C ABI가 존재한다.
- null handle, page out of range, invalid page size, Skia render failure가 안전하게 실패한다.
- Rust가 넘긴 PNG byte buffer는 기존 `rhwp_free_bytes` 규칙과 정합한다.
- `Frameworks/generated_rhwp.h`, `Rhwp.xcframework`, `rhwp-ffi-symbols.txt`, `rhwp-core.lock`이 새 ABI와 일치한다.
- `native-skia` feature 도입 전후 Rust staticlib 또는 `Rhwp.xcframework` 크기 변화가 기록된다.

비책임:

- `RhwpDocument` Swift wrapper와 `HwpPageImageRenderer` backend 선택은 #256에서 처리한다.
- Quick Look/Thumbnail provider 정책은 #257/#258에서 처리한다.

## #256 Shared renderer gate

#256은 Swift bridge wrapper와 Shared renderer backend abstraction이 소유한다.

입력 조건:

- #255의 Skia PNG ABI, generated header, symbol lock, binary provenance가 완료되어 있어야 한다.
- Stage 2의 backend 값 `coreGraphics`/`skiaPNG`와 policy 값 `coreGraphicsOnly`/`skiaOptIn`을 구현 입력으로 사용한다.
- 현재 `HwpRenderedPage` 호출부가 유지되어야 한다.

완료 조건:

- `RhwpDocument`에 Skia PNG bytes Swift wrapper가 존재한다.
- `HwpPageImageRenderer`가 backend를 명시적으로 선택할 수 있다.
- `Skia opt-in`에서 Skia success는 기존 `HwpRenderedPage` 계약으로 반환된다.
- `ffiUnavailable`, `skiaRenderFailure`, `pngDecodeFailure`, `memoryTimeoutFallback`에서 CoreGraphics fallback이 동작한다.
- `backendUsed`, `fallbackReason`, `pageSize`, `pixelSize`, `pngBytes`, `durationMs`를 기록할 수 있다.
- 대표 샘플 1개 이상에서 Skia와 CoreGraphics 산출 차이가 기록된다.

비책임:

- Quick Look reply 선택과 Thumbnail cache key 변경은 #257/#258에서 처리한다.
- `Skia first` 또는 `Skia default` 전환 결정은 #259에서 처리한다.

## #257 Quick Look integration gate

#257은 Quick Look preview extension surface가 소유한다.

입력 조건:

- #256의 Shared renderer가 `coreGraphicsOnly`와 `skiaOptIn`을 모두 지원해야 한다.
- `HwpPreviewPDFRenderer`가 Shared renderer contract를 통해 backend와 fallback result를 받을 수 있어야 한다.
- file size guard, empty document, invalid page size fallback 정책은 기존과 동일하게 유지되어야 한다.

완료 조건:

- 단일 페이지 Quick Look PNG reply가 `Skia opt-in`에서 Skia backend로 성공할 수 있다.
- Skia 실패 또는 PNG decode 실패 시 Quick Look text fallback으로 바로 가지 않고 CoreGraphics fallback을 먼저 사용한다.
- 다중 페이지 Quick Look PDF는 초기에는 CoreGraphics 유지 또는 별도 opt-in flag로 검증한다.
- 다중 페이지 PDF에 Skia page image를 넣는 경우 page별 fallback reason이 기록된다.
- Quick Look smoke 결과와 known limitation 후보가 보고서에 남는다.

비책임:

- Finder Thumbnail cache, pixel bucket, scale/max-dimension 정책은 #258에서 처리한다.
- release default 전환은 #259에서 처리한다.

## #258 Thumbnail integration gate

#258은 Finder Thumbnail extension surface가 소유한다.

입력 조건:

- #256의 Shared renderer가 `skiaPNG` backend를 `maximumPixelSize`와 함께 호출할 수 있어야 한다.
- Stage 2의 Thumbnail policy에 따라 긴 변 `maximumPixelSize`를 `PngExportOptions.max_dimension`에 매핑할 수 있어야 한다.
- embedded thumbnail policy와 기존 fallback tile 정책이 유지되어야 한다.

완료 조건:

- Finder thumbnail이 `Skia opt-in`에서 요청 크기에 맞는 Skia bitmap을 생성할 수 있다.
- `HwpThumbnailRenderCache` key가 file identity, pixel bucket, backend 또는 render signature를 반영한다.
- Skia 실패 또는 PNG decode 실패 시 fallback tile로 바로 가지 않고 CoreGraphics fallback을 먼저 사용한다.
- cache hit/miss가 backend 선택과 충돌하지 않는다.
- 대표 크기별 thumbnail smoke 결과가 보고서에 남는다.

비책임:

- Quick Look provider와 다중 페이지 PDF path는 #257에서 처리한다.
- 전체 visual/performance/package readiness 판단은 #259에서 처리한다.

## #259 release readiness gate

#259는 default 전환 또는 release 포함 여부를 판단하는 검증 gate다.

입력 조건:

- #255 ABI gate, #256 Shared renderer gate, #257 Quick Look integration gate, #258 Thumbnail integration gate가 완료되어야 한다.
- 각 이슈가 남긴 binary size, visual diff, smoke, latency, memory, known limitation 결과를 수집한다.

완료 조건:

- 대표 HWP/HWPX 샘플군의 Skia vs CoreGraphics vs reference 결과가 기록된다.
- Quick Look과 Thumbnail 각각의 latency, memory, decode cost가 기록된다.
- `native-skia` feature 전후 staticlib, `Rhwp.xcframework`, app/package size 변화가 기록된다.
- `Skia first` 전환, `Skia opt-in` 유지, 또는 보류 판단이 근거와 함께 남는다.
- release note known limitation 초안이 준비된다.

비책임:

- renderer implementation 자체를 추가하거나 수정하지 않는다.
- signed/notarized public release 실행은 별도 명시 지시 없이는 포함하지 않는다.

## GitHub issue 본문 업데이트 후보

현재 #255-#259 본문은 큰 책임 경계를 이미 포함한다. 다만 후속 이슈 시작 직전에 다음 보강을 검토한다.

- #255: Stage 2 failure taxonomy의 `ffiUnavailable`, `skiaRenderFailure`, `invalidPageSize` 명칭을 ABI 오류 결과 표에 반영.
- #256: `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs` 진단 필드와 Thumbnail cache key 영향이 #258로 넘어간다는 점을 명시.
- #257: 다중 페이지 PDF의 Skia 적용은 초기 default가 아니라 별도 opt-in 검증으로 시작한다고 명시.
- #258: cache key에 backend/render signature를 포함한다는 완료 조건을 명시.
- #259: #255-#258 산출물을 입력으로 받는 release readiness gate임을 명시.
