# Task M020 #259 Stage 1 보고서 - Skia readiness 입력과 backend 정책 inventory

## 단계 개요

- 이슈: #259 Skia backend visual/performance/package regression gate 정리
- 단계: Stage 1. 입력 산출물과 현재 backend 정책 inventory
- 기준 브랜치: `local/task259`
- 목표: #255/#256/#257/#278 산출물과 현재 코드 정책을 수집해 #259가 #258보다 먼저 진행되는 이유와 Stage 2 측정 대상을 고정한다.

Stage 1에서는 Swift source를 변경하지 않는다. 현재 제품 surface가 실제로 어느 backend를 기본으로 사용하는지와, release gate 판단에 필요한 입력이 어디까지 확보됐는지를 문서화한다.

## 선행 산출물 inventory

### #255 native-skia ABI와 package 입력

| 항목 | 확인 내용 | #259 영향 |
|---|---|---|
| 새 ABI | `rhwp_render_page_png` 추가 | Skia PNG backend는 RustBridge C ABI로 호출 가능하다. |
| render status | `RhwpRenderStatus` 6개 값 추가 | #256 fallback taxonomy 입력이 된다. |
| FFI symbol 수 | 10개에서 11개로 증가 | ABI surface가 확장됐다. |
| generated header | 1,349 bytes에서 1,978 bytes로 증가 | Swift wrapper가 새 ABI를 소비할 수 있다. |
| staticlib size | 108,417,040 bytes에서 190,410,384 bytes로 증가 | `native-skia` 포함만으로 81,993,344 bytes 증가했다. |
| `du -sh` | `librhwp.a` / `Rhwp.xcframework` 모두 `182M` | release package size gate에서 반드시 해석해야 한다. |
| 제품 동작 | Quick Look/Thumbnail 제품 동작 변경 없음 | #255는 backend capability 추가이지 default 전환 근거가 아니다. |

판단: #255는 Skia를 호출할 수 있게 만든 작업이지만, package size 증가는 크다. 따라서 사용자-facing 개선이 충분하지 않으면 Quick Look 기본 backend로 배포하기 어렵다.

### #256 Shared renderer contract

| 항목 | 확인 내용 | #259 영향 |
|---|---|---|
| 정책 | `HwpPageRenderPolicy.coreGraphicsOnly`, `.skiaOptIn` | default와 opt-in을 분리할 수 있다. |
| 기본값 | `renderPage`, `renderFirstPage` 기본값은 `.coreGraphicsOnly` | Shared renderer 자체는 Skia 기본 전환을 하지 않았다. |
| Skia 동작 | `.skiaOptIn`에서 Skia PNG render를 먼저 시도 | 호출부가 명시한 경우에만 Skia 우선이다. |
| fallback | status failure, empty bytes, PNG decode failure 시 CoreGraphics fallback | Quick Look에서 Skia 실패가 곧바로 text fallback으로 내려가지는 않는다. |
| diagnostics | `backendUsed`, `fallbackReason`, `pageSize`, `pixelSize`, `pngBytes`, `durationMs` | Stage 2 smoke와 Stage 3 정책 판단의 관측 필드다. |
| embedded thumbnail | `.embeddedThumbnail` backend로 분리 | Finder thumbnail smoke에서 CoreGraphics render와 혼동하지 않게 됐다. |

판단: #256은 Skia를 안전하게 실험할 수 있는 contract를 제공했다. 다만 #256 보고서 자체도 visual diff, latency, memory, package size를 보지 않았으므로 default 전환 결론은 내리지 않았다.

### #257 Quick Look Skia 연결과 smoke

| 항목 | 확인 내용 | #259 영향 |
|---|---|---|
| 단일 PNG reply | Quick Look PNG path가 `policy: .skiaOptIn` 사용 | 현재 Quick Look 단일 페이지 기본 렌더는 Skia 우선이다. |
| 다중 PDF reply | Quick Look PDF path가 `policy: .skiaOptIn`, `collectDiagnostics: true` 사용 | 다중 페이지도 page별 Skia 우선으로 바뀌었다. |
| smoke helper | `smoke-quicklook-skia-policy.sh` 추가 | Stage 2에서 같은 도구로 재측정한다. |
| `request.hwp` | CG 1.081279s, Skia 0.095356s, fallback 0 | 당시에는 Skia가 빠르게 관측됐다. |
| `KTX.hwp` | CG 0.067094s, Skia 0.073160s, fallback 0 | 단일 문서에서 큰 차이는 아니었다. |
| `복학원서.hwp` | CG 0.412763s, Skia 0.062871s, fallback 0 | Skia가 빠르게 관측됐다. |
| `hwp-multi-001.hwp` | CG 0.404578s, Skia 0.677783s, fallback 0 | 다중 PDF에서는 Skia가 느렸다. |
| `hwpx-01.hwpx` | CG 0.353663s, Skia 0.623360s, fallback 0 | 다중 PDF에서는 Skia가 느렸다. |
| Known limitation | 설치본 Quick Look UI smoke 없음, fallback 강제 fixture 없음, Skia PNG decode 후 재인코딩, 다중 PDF 성능 이슈 | release default 판단을 #259로 넘긴 이유다. |

판단: #257은 Quick Look surface에 Skia를 실제 연결했다. 다만 일부 다중 문서에서 이미 성능 부담이 보였고, 설치본/package 관점 검증은 남아 있었다.

### #278 rhwp v0.7.13 기준 회귀 입력

| 항목 | 확인 내용 | #259 영향 |
|---|---|---|
| upstream | `rhwp v0.7.13`, resolved commit `b3e16ef212af81ef37d973ddb86d6816d3804642` | 현재 release 후보의 core 기준이다. |
| staticlib size | 200,488,800 bytes에서 203,436,808 bytes로 증가 | v0.7.13 반영 후에도 package size가 추가 증가했다. |
| ABI | FFI symbol/header 변경 없음, 12 symbols 유지 | #259에서 Swift ABI 보정은 필요 없어 보인다. |
| `request.hwp` policy smoke | CG 0.990051s, Skia 12.158348s, fallback 0 | Skia first-call 또는 특정 문서 latency 리스크가 크다. |
| `hwpx-01.hwpx` policy smoke | CG 0.358134s, Skia 0.617731s, fallback 0 | 다중 PDF에서 Skia가 계속 느렸다. |
| `request.hwp` visual diff | CG changed 17.8542%, mean RGB 11.0716, 961.7ms / Skia changed 12.8683%, mean RGB 10.1453, 6240.1ms | changed pixel은 개선됐지만 latency 비용이 매우 크다. |
| `hwpx-01.hwpx` visual diff | CG changed 15.0285%, mean RGB 15.2088, 29.8ms / Skia changed 14.6452%, mean RGB 16.0791, 64.4ms | changed pixel 개선 폭이 작고 mean RGB는 악화됐다. |
| #278 결론 | Skia 기본 전환은 아직 이르다 | #259에서 default 유지/복귀를 판정해야 한다. |

판단: v0.7.13 기준 Skia는 visual diff 일부 지표를 개선하지만, diff가 여전히 두 자릿수이고 latency가 문서별로 크게 흔들린다. 현재 입력만 보면 Quick Look 기본을 Skia로 유지하려면 추가 근거가 필요하다.

## 현재 코드 backend 정책

| Surface | 파일 | 현재 호출 | 해석 |
|---|---|---|---|
| Quick Look 단일 PNG | `Sources/QLExtension/HwpPreviewProvider.swift:40` | `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)` | 현재 최신 코드 기준 단일 페이지 Quick Look 기본 렌더는 Skia 우선이다. |
| Quick Look 다중 PDF | `Sources/QLExtension/HwpPreviewProvider.swift:73` | `HwpPreviewPDFRenderer.render(context:policy: .skiaOptIn, collectDiagnostics: true)` | 다중 페이지 Quick Look도 Skia 우선이다. |
| PDF renderer public API | `Sources/Shared/HwpPreviewPDFRenderer.swift:52` | `policy: HwpPageRenderPolicy = .coreGraphicsOnly` | 일반 호출 기본값은 CoreGraphics이며, Quick Look provider가 명시적으로 Skia를 선택한다. |
| Shared renderer policy | `Sources/Shared/HwpPageImageRenderer.swift:14` | `.coreGraphicsOnly`, `.skiaOptIn` | backend 정책은 명시 enum으로 분리되어 있다. |
| Shared first page 기본값 | `Sources/Shared/HwpPageImageRenderer.swift:105` | `policy: HwpPageRenderPolicy = .coreGraphicsOnly` | 호출자가 생략하면 CoreGraphics만 사용한다. |
| Shared page 기본값 | `Sources/Shared/HwpPageImageRenderer.swift:144` | `policy: HwpPageRenderPolicy = .coreGraphicsOnly` | 공용 렌더러의 default는 아직 native/CoreGraphics path다. |
| Shared Skia fallback | `Sources/Shared/HwpPageImageRenderer.swift:166` | `.skiaOptIn`에서 Skia 성공 시 반환, 실패 시 CoreGraphics fallback | fallback contract는 유지된다. |
| Finder thumbnail cache | `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:88` | `renderFirstPage(... embeddedThumbnailPolicy: .never)` | policy 인자를 넘기지 않으므로 Thumbnail은 현재 CoreGraphics 기본이다. |

현재 정책을 한 문장으로 정리하면 다음과 같다.

- Quick Look preview: 단일 PNG와 다중 PDF 모두 Skia 우선이다.
- Thumbnail extension: 아직 CoreGraphics 기본이다.
- Shared renderer/PDF renderer API: 기본값은 CoreGraphics이고, Quick Look provider만 Skia를 명시 opt-in한다.

이 상태는 release 설명 관점에서 애매하다. 사용자가 가장 먼저 접하는 Quick Look preview는 Skia를 기본으로 쓰지만, Finder thumbnail은 아직 CoreGraphics를 쓰므로 같은 문서에 대해 Finder surface별 rendering 특성이 달라질 수 있다.

## #259를 #258보다 먼저 진행하는 이유

#258은 Finder thumbnail에 Skia backend를 적용하는 작업이다. 그러나 현재 입력에서는 #258을 먼저 진행하면 Skia 기본 적용 범위가 더 넓어지기 전에 해결해야 할 release gate 질문이 남아 있다.

1. Quick Look은 이미 Skia 우선이다. 따라서 지금 필요한 질문은 "Skia를 더 넓힐 것인가"보다 "이미 바뀐 기본 경로를 release에 실을 수 있는가"이다.
2. #278의 `request.hwp` Skia latency는 Quick Look 기본 유지에 직접적인 위험 신호다. 이 상태에서 Thumbnail까지 Skia를 확장하면 cache key, memory, first-render latency 문제가 함께 커진다.
3. #258의 cache key/backend signature 설계는 release policy에 의존한다. Skia를 기본으로 유지할지, opt-in diagnostic 경로로 낮출지 결정하지 않으면 #258의 cache key 범위와 smoke 기준이 흔들린다.
4. package size 증가는 #255부터 이미 크고, v0.7.13에서 추가 증가했다. Thumbnail 적용은 사용자-facing 개선 근거가 package 비용을 정당화할 때 진행하는 편이 깔끔하다.
5. #257 known limitation과 #278 결론 모두 default 판단을 #259로 넘겼다. 따라서 #259를 먼저 끝내야 #258을 release 필수 작업으로 둘지, 후속 diagnostic/cache 설계 작업으로 재범위화할지 결정할 수 있다.

Stage 1 기준 잠정 판단은 `#259 선행`이다. #258은 Stage 2-3에서 Quick Look default 정책을 확정한 뒤 진행 여부와 범위를 다시 정하는 것이 맞다.

## Stage 2 측정 대상

Stage 2에서는 기존 보고서 수치를 그대로 믿고 끝내지 않고, 현재 `devel` 최신 코드와 `rhwp v0.7.13` 기준으로 같은 gate를 재측정한다.

대표 샘플:

| 샘플 | 이유 |
|---|---|
| `samples/basic/request.hwp` | #278에서 Skia latency가 크게 튄 단일 PNG 대표 리스크 |
| `samples/hwpx/hwpx-01.hwpx` | 다중 PDF/HWPX 대표 샘플 |
| `samples/복학원서.hwp` | #257에서 Skia가 빠르게 관측된 단일 문서, 한글 실사용 양식 |
| `samples/basic/KTX.hwp` | #256/#257에서 CoreGraphics와 Skia 차이가 컸던 표/텍스트 문서 |
| `samples/hwp-multi-001.hwp` | 다중 HWP PDF path 성능 확인 후보 |

필수 측정:

- `smoke-quicklook-skia-policy.sh`로 reply type, backend count, fallback count, bytes, latency 비교
- `preview-visual-diff-harness.sh`로 CoreGraphics와 Skia의 reference 대비 visual diff 비교
- `du -sh Frameworks/universal/librhwp.a Frameworks/Rhwp.xcframework`로 staticlib/xcframework 크기 확인
- `build-rust-macos.sh --verify-lock`, `verify-rhwp-studio-assets.sh`, `check-no-appkit.sh`로 provenance와 shared dependency 규칙 확인

Stage 2에서 특히 확인할 질문:

1. #278의 `request.hwp` Skia 12.158348s가 재현되는가, first-call cost인가, 일시적 이상치인가.
2. Skia visual diff 개선이 latency/package cost를 정당화할 정도로 반복되는가.
3. 다중 PDF path에서 Skia가 CoreGraphics보다 느린 경향이 유지되는가.
4. fallback이 0으로 유지될 때도 release default로 설명 가능한 품질과 성능인가.

## Stage 3 판정에 넘길 기준

Stage 2 결과가 다음 중 하나에 가까우면 Stage 3에서 Quick Look 기본 정책을 조정한다.

| 조건 | Stage 3 방향 |
|---|---|
| Skia가 대표 샘플에서 visual diff를 의미 있게 개선하고 latency도 CoreGraphics와 동등하거나 빠름 | Quick Look Skia default 유지 검토 |
| Skia visual 개선 폭이 작거나 문서별로 엇갈리고, latency가 느리거나 first-call 비용이 큼 | Quick Look 기본을 CoreGraphics로 복귀하고 Skia opt-in/diagnostic 유지 |
| Thumbnail까지 같은 정책으로 묶어야 release 설명이 성립함 | #258을 release 전 필수로 유지 |
| Quick Look 기본을 CoreGraphics로 복귀함 | #258은 release 전 필수에서 제외하거나 backend/cache diagnostic 작업으로 재범위화 |

현재 Stage 1 입력만으로는 Skia default 유지 결론을 내리기 어렵다. 특히 `request.hwp` latency와 다중 PDF 성능은 Stage 2에서 재측정한 뒤 Stage 3에서 정책 보정 여부를 결정한다.

## Stage 1 검증

실행할 검증:

```bash
rg -n "#255|#256|#257|#258|#259|#278|skiaOptIn|coreGraphicsOnly|backendUsed|fallbackReason|staticlib|visual diff" \
  mydocs/plans/task_m020_259_impl.md mydocs/working/task_m020_259_stage1.md \
  mydocs/report/task_m020_255_report.md mydocs/report/task_m020_256_report.md \
  mydocs/report/task_m020_257_report.md mydocs/report/task_m020_278_report.md
rg -n "skiaOptIn|coreGraphicsOnly|HwpPageRenderPolicy|renderFirstPage|renderPage" \
  Sources/QLExtension Sources/ThumbnailExtension Sources/Shared --glob '!**/Resources/**'
git diff --check
```

기대 결과:

- 선행 보고서와 Stage 1 보고서에 #259 판단 입력이 연결되어 있다.
- 현재 Quick Look은 Skia 우선, Thumbnail은 CoreGraphics 기본이라는 정책 차이가 source 검색으로 확인된다.
- Stage 1은 문서 추가만 수행했으므로 Swift source 변경은 없다.

## 다음 단계 승인 요청

Stage 2에서는 현재 코드 기준으로 Quick Look Skia/CoreGraphics visual, latency, fallback, package size gate를 재측정한다. Stage 2 완료 후 측정 보고서를 작성하고, Stage 3 정책 판정으로 넘어가기 전에 다시 승인을 요청한다.
