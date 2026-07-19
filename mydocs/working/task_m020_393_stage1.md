# Task M020 #393 Stage 1 보고서

## 단계 목적

현행 Quick Look 단일 페이지 PNG reply가 production/default에서는 CoreGraphics만 사용하고, `skiaOptIn` 진단 smoke에서는 `Skia PNG bytes -> CGImage decode -> PNG encode` round-trip을 거친다는 사실을 코드와 smoke output으로 고정했다.

이번 단계는 source 변경 없이 inventory와 quick smoke baseline만 수행했다.

## 산출물

| 파일/산출물 | 내용 |
|------|------|
| `Sources/QLExtension/HwpPreviewProvider.swift` | Quick Look 단일 PNG/PDF reply 선택과 production CoreGraphics policy 확인 |
| `Sources/Shared/HwpPageImageRenderer.swift` | `skiaOptIn` render, Skia PNG decode, CoreGraphics fallback, PNG encode helper 확인 |
| `Sources/Shared/HwpPreviewPDFRenderer.swift` | 다중 페이지 PDF가 page별 `HwpRenderedPage`를 `CGContext`에 draw하는 구조 확인 |
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | `renderPagePNG(at:scale:maxDimension:)`가 direct PNG bytes를 이미 반환할 수 있음을 확인 |
| `scripts/quicklook_skia_policy_smoke.swift` | 단일 페이지 smoke가 policy별 `renderPage` 후 `encodePNG`로 output bytes를 측정함을 확인 |
| `scripts/smoke-quicklook-skia-policy.sh` | Swift smoke helper compile/run path 확인 |
| `build.noindex/task393-stage1-quicklook-baseline/summary.txt` | #393 Stage 1 Quick Look baseline smoke summary |

## 본문 변경 정도 / 본문 무손실 여부

제품 source는 변경하지 않았다. 새로 추가한 문서는 이 Stage 1 보고서뿐이고, 오늘할일 상태만 갱신했다.

## Inventory 결과

### Quick Look provider

`HwpPreviewProvider.createPreview`는 `HwpPreviewPDFRenderer.load`로 문서를 읽은 뒤 page count가 1이면 `pngReply`, 2 이상이면 `pdfReply`를 선택한다.

현재 production/default 단일 PNG reply는 다음 순서다.

1. `HwpPageImageRenderer.renderPage(document:pageIndex:policy:)`를 `policy: .coreGraphicsOnly`로 호출한다.
2. `logRenderedPageDiagnostics`로 backend/fallback/pixel/pngBytes/timing을 기록한다.
3. `HwpPageImageRenderer.encodePNG(page.image)`로 `CGImage`를 PNG로 인코딩한다.
4. `QLPreviewReply(dataOfContentType: .png, contentSize: contentSize)`에 encoded PNG data를 반환한다.

따라서 현재 사용자 기본 Quick Look 단일 페이지는 Skia를 호출하지 않는다.

다중 페이지 PDF reply도 `HwpPreviewPDFRenderer.render(context:policy:.coreGraphicsOnly)`를 호출하므로 현재 production/default는 CoreGraphics다.

### Shared renderer

`HwpPageImageRenderer.renderPage`의 policy는 두 가지다.

| policy | 현재 동작 |
|------|------|
| `.coreGraphicsOnly` | `renderCoreGraphicsPage`로 `PageRenderTree`를 Swift/CoreGraphics에서 draw |
| `.skiaOptIn` | `renderSkiaPage`를 먼저 시도하고, 실패하면 CoreGraphics fallback |

`renderSkiaPage`는 `RhwpDocument.renderPagePNG`를 호출해 upstream Skia PNG bytes를 받은 뒤, 성공 상태와 non-empty bytes를 확인한다. 이후 현재 shared contract인 `HwpRenderedPage`를 만들기 위해 `decodePNGImage(png.data)`로 `CGImage`를 생성한다.

즉 현재 `skiaOptIn` 성공 경로는 다음과 같다.

```text
rhwp_render_page_png
-> Swift Data copy
-> CGImageSourceCreateWithData
-> CGImageSourceCreateImageAtIndex
-> HwpRenderedPage(image: CGImage, diagnostics: pngBytes)
```

그리고 단일 Quick Look smoke/helper는 이 `CGImage`를 다시 PNG로 encode한다. 따라서 현재 smoke의 `SkiaPNGBytes`는 upstream Skia 원본 PNG bytes이고, `SkiaBytes`는 decode 후 재인코딩된 Quick Look reply 후보 bytes다.

### RustBridge wrapper

`RhwpDocument.renderPagePNG(at:scale:maxDimension:)`는 이미 Swift에서 PNG bytes를 직접 받을 수 있는 wrapper다.

입력 guard:

- page index는 0 이상이어야 한다.
- `scale`은 finite이며 0 이상이어야 한다.
- `maxDimension`은 0 이상, `UInt32.max` 이하이어야 한다.

FFI 호출 성공 시 `Data(bytes: pngPtr, count: Int(outLen))`로 Rust-owned buffer를 복사한 뒤 `rhwp_free_bytes`로 해제한다. 따라서 Stage 3의 direct path는 신규 Rust ABI 없이 이 wrapper를 재사용할 수 있다.

### PDF renderer

`HwpPreviewPDFRenderer.render`는 page별로 `HwpPageImageRenderer.renderPage`를 호출하고, 반환된 `CGImage`를 `CGContext` PDF page에 draw한다. 이 구조에서는 Skia PNG bytes를 PDF에 넣기 위해서도 `CGImage` decode가 필요하다.

따라서 이번 task의 direct PNG 실험은 Quick Look 단일 페이지 PNG reply에만 한정하는 것이 맞고, 다중 페이지 PDF는 Stage 3에서 직접 PNG data 반환 대상이 아니다.

### Smoke helper

`quicklook_skia_policy_smoke.swift`는 단일 페이지에서 policy별로 다음 경로를 탄다.

```text
HwpPageImageRenderer.renderPage(document: pageIndex: 0, policy: policy)
-> HwpPageImageRenderer.encodePNG(page.image)
-> outputBytes = encoded PNG bytes
```

다중 페이지에서는 `HwpPreviewPDFRenderer.render(context:policy:collectDiagnostics:true)`를 호출하고 PDF bytes를 측정한다.

결론적으로 Stage 1 smoke는 현행 decode/re-encode 경로의 baseline으로 사용할 수 있지만, Skia direct PNG reply의 latency/bytes는 아직 측정하지 않는다.

## Baseline smoke 결과

실행:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-stage1-quicklook-baseline \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
```

결과: 5개 샘플 모두 load/render `OK`, fallback 0건.

stderr에는 기존 layout overflow warning 2줄이 출력됐지만 smoke 실패로 이어지지 않았다.

| File | Reply | Pages | CGBackend | CGBytes | CGSeconds | SkiaBackend | SkiaBytes | SkiaPNGBytes | SkiaSeconds | Fallback |
|------|------|------:|------|------:|------:|------|------:|------:|------:|------|
| `request.hwp` | png | 1 | `skia:0,cg:1,embedded:0` | 90472 | 1.208144 | `skia:1,cg:0,embedded:0` | 84098 | 87027 | 0.090322 | 0 |
| `KTX.hwp` | png | 1 | `skia:0,cg:1,embedded:0` | 543472 | 0.077545 | `skia:1,cg:0,embedded:0` | 181314 | 166247 | 0.060733 | 0 |
| `복학원서.hwp` | png | 1 | `skia:0,cg:1,embedded:0` | 223309 | 0.055824 | `skia:1,cg:0,embedded:0` | 196405 | 198675 | 0.067626 | 0 |
| `hwp-multi-001.hwp` | pdf | 9 | `skia:0,cg:9,embedded:0` | 1398731 | 0.391512 | `skia:9,cg:0,embedded:0` | 1102131 | 1297323 | 0.474950 | 0 |
| `hwpx-01.hwpx` | pdf | 9 | `skia:0,cg:9,embedded:0` | 1377385 | 0.369959 | `skia:9,cg:0,embedded:0` | 1093637 | 1314854 | 0.498662 | 0 |

해석:

- 단일 페이지 3개 샘플에서 `skiaOptIn`은 fallback 없이 Skia backend로 성공했다.
- 단일 페이지 `SkiaBytes`와 `SkiaPNGBytes`가 서로 다르다. 이 차이가 현재 smoke가 direct PNG bytes가 아니라 decode 후 재인코딩된 bytes를 output으로 삼는다는 증거다.
- `request.hwp`, `KTX.hwp`는 이번 실행에서 Skia path elapsed가 CoreGraphics보다 짧았다.
- `복학원서.hwp`는 이번 실행에서 CoreGraphics path elapsed가 Skia path보다 짧았다.
- 다중 페이지 2개 샘플은 Skia fallback은 없지만 elapsed 기준으로 CoreGraphics가 더 빠르다. direct PNG 실험 대상에서 제외한다.

## #390 기준과의 관계

#390 최종 보고서의 Quick Look smoke와 같은 대표 샘플 세트를 사용했다. 절대 latency는 로컬 실행마다 변동하지만 방향은 유지된다.

| 샘플 | #390 CG/Skia sec | #393 Stage 1 CG/Skia sec | 해석 |
|------|------|------|------|
| `request.hwp` | 1.188107 / 0.068532 | 1.208144 / 0.090322 | Skia latency 우위 유지 |
| `KTX.hwp` | 0.072109 / 0.059391 | 0.077545 / 0.060733 | Skia latency 우위 유지 |
| `복학원서.hwp` | 0.049888 / 0.063096 | 0.055824 / 0.067626 | CoreGraphics latency 우위 유지 |
| `hwp-multi-001.hwp` | 0.420672 / 0.482924 | 0.391512 / 0.474950 | 다중 PDF는 CoreGraphics 우위 유지 |
| `hwpx-01.hwpx` | 0.376054 / 0.514870 | 0.369959 / 0.498662 | 다중 PDF는 CoreGraphics 우위 유지 |

#390의 최종 판단인 `CoreGraphics default + Skia opt-in diagnostic backend`를 바꿀 근거는 Stage 1에 없다. 이번 작업은 default 전환이 아니라 단일 PNG opt-in direct reply 비용 비교로 제한한다.

## Stage 2 입력

Stage 2에서는 다음 contract를 확정해야 한다.

1. direct path 적용 범위는 Quick Look 단일 페이지 PNG reply로 제한한다.
2. production/default `pngReply`는 계속 `.coreGraphicsOnly`로 유지한다.
3. opt-in direct path는 `RhwpDocument.renderPagePNG(at:0, scale:1, maxDimension:0)`를 직접 호출하는 후보를 우선 검토한다.
4. 성공 조건은 `status == .ok`와 non-empty PNG bytes다. PNG header validation을 할지, `CGImageSource` decode validation을 피할지 결정해야 한다.
5. direct path 실패 시 text fallback으로 바로 가지 않고 기존 CoreGraphics PNG reply shape으로 fallback한다.
6. direct diagnostics는 기존 `HwpPageRenderDiagnostics`를 확장할지, Quick Look 전용 측정 구조로 둘지 결정한다.
7. smoke summary에는 최소한 `skiaDecode`와 `skiaDirect`를 분리해 `outputBytes`, 원본 `pngBytes`, render/decode/encode/total seconds, fallback reason을 비교할 수 있어야 한다.
8. 다중 페이지 PDF는 direct PNG data return 대상이 아니며, Stage 3 구현에서도 기존 PDF path를 유지해야 한다.

## 검증 결과

구현계획서 Stage 1 검증:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task393-stage1-quicklook-baseline \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/복학원서.hwp \
  samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
```

결과: 성공. 5개 샘플 모두 `OK`, fallback 0건.

추가 점검:

```bash
rg -n "pngReply|renderPagePNG|decodePNGImage|encodePNG|skiaOptIn|coreGraphicsOnly|SkiaBytes|SkiaPNGBytes|Reply" \
  Sources/QLExtension/HwpPreviewProvider.swift Sources/Shared/HwpPageImageRenderer.swift \
  scripts/quicklook_skia_policy_smoke.swift build.noindex/task393-stage1-quicklook-baseline \
  mydocs/working/task_m020_393_stage1.md
git diff --check
```

`rg`는 provider, shared renderer, smoke helper, baseline output, Stage 1 문서의 관련 지점을 확인하는 용도로 사용했다. `git diff --check`는 Stage 1 문서 작성 후 통과시킨다.

## 잔여 위험

| 항목 | 상태 | 다음 처리 |
|------|------|------|
| direct PNG validation | 아직 미확정 | Stage 2에서 non-empty/status만 볼지 PNG signature를 볼지 결정 |
| diagnostics 책임 경계 | 아직 미확정 | Stage 2에서 shared diagnostics 확장 또는 Quick Look 전용 구조 결정 |
| visual 품질 | 이번 Stage 범위 밖 | #396/#259 readiness 판단으로 유지 |
| 다중 PDF latency | Skia가 여전히 느림 | 이번 task direct path 범위에서 제외 |
| latency 절대값 | 로컬 실행 변동 가능 | Stage 4에서 대표 샘플 상대 비교 중심으로 해석 |

## 다음 단계 영향

Stage 2는 source 변경 전 설계 단계다. direct path를 provider에 좁게 둘지, Shared renderer에 direct PNG helper를 둘지 결정하고, smoke helper가 `coreGraphics`, 기존 `skiaDecode`, 신규 `skiaDirect`를 한 summary에서 비교할 수 있는 출력 계약을 정한다.

## 승인 요청

Stage 1 inventory와 Quick Look PNG reply baseline 고정을 완료했다. Stage 2 `direct PNG reply contract 설계`로 진행 승인해 달라.
