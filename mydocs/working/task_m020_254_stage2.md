# Task M020 #254 Stage 2 보고서

## 단계 목적

Stage 2의 목적은 Quick Look/Thumbnail에 Skia를 optional backend로 도입할 때 사용할 backend 선택 정책과 fallback contract를 설계하는 것이다. 이 단계에서도 제품 Swift/Rust source는 변경하지 않고 장기 기술 문서와 단계 보고서만 남긴다.

## 산출물

| 파일 | 요약 |
|---|---|
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | Skia Quick Look/Thumbnail optional backend의 정책, failure taxonomy, surface별 fallback contract 초안. 143 lines |
| `mydocs/working/task_m020_254_stage2.md` | Stage 2 완료 보고서. 126 lines |
| `mydocs/orders/20260518.md` | #254 상태를 Stage 2 완료 및 Stage 3 승인 대기 상태로 갱신. 7 lines |

## backend 후보 비교 결과

Stage 2에서는 네 후보를 비교했다.

| 후보 | 판단 |
|---|---|
| `CoreGraphics only` | 현재 기본값으로 유지한다. 제품 위험, package size, extension load time이 가장 낮다. |
| `Skia opt-in` | 첫 구현 권장안이다. Skia를 먼저 시도하되 실패 시 CoreGraphics fallback을 유지해 visual/performance 비교를 안전하게 쌓을 수 있다. |
| `Skia first + CoreGraphics fallback` | readiness gate 통과 뒤 전환 후보로 둔다. 기본 경로 변경이므로 #259 검증 전에는 열지 않는다. |
| `Skia default` | 현재 보류한다. CoreGraphics fallback을 약화하려면 upstream Skia coverage, package size, font 결과, extension 안정성이 먼저 입증되어야 한다. |

결론은 현재 기본값을 `CoreGraphics only`로 유지하고, #256 이후 구현은 `Skia opt-in`으로 시작하는 것이다.

## fallback contract 초안

backend는 `coreGraphics`와 `skiaPNG`로 나누고, policy는 `coreGraphicsOnly`, `skiaOptIn`, `skiaFirstCoreGraphicsFallback`, `skiaDefault`로 정의했다.

failure taxonomy는 다음 항목을 포함한다.

- `ffiUnavailable`: Skia feature나 ABI symbol이 없으면 CoreGraphics fallback.
- `skiaRenderFailure`: upstream Skia render error 또는 빈 PNG bytes면 CoreGraphics fallback.
- `pngDecodeFailure`: Skia PNG bytes decode 실패면 CoreGraphics fallback.
- `invalidPageSize`: renderer fallback이 아니라 입력 오류로 보고 기존 fallback classifier로 처리.
- `fileSizeFallback`: 기존 50 MB guard를 Skia보다 앞에 둔다.
- `memoryTimeoutFallback`: Skia render/decode 중 timeout 또는 allocation 실패 시 CoreGraphics fallback.
- `coreGraphicsFallbackFailure`: Skia 실패 후 CoreGraphics도 실패하면 현재 Quick Look text fallback 또는 Thumbnail tile fallback.

중요한 경계는 `invalidPageSize`와 `fileSizeFallback`을 Skia 우회 대상으로 보지 않는 것이다. 두 항목은 renderer 품질 문제가 아니라 입력/정책 문제이므로 Skia를 호출하지 않는다.

## Quick Look과 Thumbnail 차이

Quick Look은 큰 preview surface이므로 실패 설명과 내용 표시 안정성을 우선한다.

- 단일 페이지 PNG reply는 `Skia opt-in` 후보로 적합하다.
- 다중 페이지 PDF reply는 현재 bitmap PDF이며 Skia PNG를 다시 decode해야 하므로 초기 opt-in에서는 별도 flag로 분리한다.
- Skia 실패 시 바로 text reply로 가지 않고 CoreGraphics fallback을 먼저 시도한다.

Thumbnail은 작은 bitmap surface이므로 latency, memory, cache 안정성을 우선한다.

- `maximumPixelSize`의 긴 변을 upstream `PngExportOptions.max_dimension`에 매핑할 수 있다.
- Skia PNG bytes는 Finder context에 직접 그릴 수 없어서 decode 비용이 있다.
- cache key에는 backend 또는 render signature를 추가해야 한다.
- Skia 실패 시 바로 fallback tile로 가지 않고 CoreGraphics fallback을 먼저 시도한다.

따라서 Quick Look과 Thumbnail은 같은 Shared backend contract를 사용하되, rollout policy와 readiness 판단은 분리한다.

## 로그/진단 필드

후속 구현에서 수집할 필드 후보는 다음과 같다.

- `surface`
- `replyType`
- `policy`
- `backendRequested`
- `backendUsed`
- `fallbackReason`
- `pageIndex`
- `pageCount`
- `pageSize`
- `pixelSize`
- `fileSize`
- `durationMs`
- `pngBytes`
- `cacheHit`

full path는 기록하지 않고 현재 코드처럼 basename만 public으로 기록한다. fallback reason은 문자열 enum으로 고정해 #259 visual/performance report에서 집계 가능하게 한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드, RustBridge ABI, project 설정은 변경하지 않았다.
- 신규 장기 기술 문서와 신규 Stage 2 보고서만 추가했다.
- 오늘할일은 Stage 2 완료와 Stage 3 승인 대기 상태로 갱신했다.
- 기존 문서를 삭제하거나 본문 재작성하지 않았다.

## 검증 결과

검증 명령은 Stage 2 문서 작성 후 실행한다.

```bash
rg -n "CoreGraphics|Skia|fallback|Quick Look|Thumbnail|failure|decode|memory|timeout" \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage2.md
```

결과: 통과. 문서가 backend 후보, fallback, Quick Look/Thumbnail 차이, failure taxonomy, decode/memory/timeout 항목을 포함하는지 확인했다.

```bash
git diff --check -- mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage2.md
```

결과: 통과. 최종 커밋 전 전체 `git diff --check`와 함께 재확인한다.

## 잔여 위험

- 실제 `native-skia` feature 활성화 시 binary/package 크기와 extension load time은 아직 측정하지 않았다.
- Skia PNG decode 비용이 CoreGraphics 직접 render보다 낮은지 아직 알 수 없다.
- font fallback과 text shaping 차이는 policy 문서만으로 닫히지 않는다.
- timeout과 memory fallback은 아직 구현된 장치가 아니므로 #256-#258에서 구체화해야 한다.
- 다중 페이지 Quick Look PDF에 Skia를 적용할지 여부는 Stage 4 readiness gate 전까지 보류한다.

## 다음 단계 영향

Stage 3에서는 이 contract를 기준으로 #255-#259의 의존 순서와 handoff gate를 정리한다.

- #255는 `skiaPNG` backend가 호출할 RustBridge ABI를 만든다.
- #256은 Shared renderer가 `coreGraphics`와 `skiaPNG`를 선택하고 fallback reason을 보존한다.
- #257은 Quick Look surface의 policy와 reply별 적용 범위를 결정한다.
- #258은 Thumbnail surface의 cache key와 `max_dimension` 매핑을 결정한다.
- #259는 `Skia first` 또는 `Skia default` 전환 가능성을 판단하는 readiness gate를 만든다.

## 승인 요청

Stage 2는 backend 선택 정책과 fallback contract 설계로 마무리한다. Stage 3 `후속 이슈 의존 순서와 handoff gate 정리`로 진행하려면 작업지시자 승인이 필요하다.
