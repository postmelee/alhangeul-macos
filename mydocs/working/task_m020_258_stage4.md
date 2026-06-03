# Task #258 Stage 4 완료 보고서

## 단계 목적

대표 HWP/HWPX 샘플과 크기 bucket에서 Thumbnail CoreGraphics/Skia opt-in 결과를 기록하고, 장기 Skia 전환 gate를 반복 가능한 기준으로 정리한다. 이번 단계는 제품 기본값을 바꾸지 않고 문서화와 smoke 기준선 기록만 수행한다.

## 산출물

| 파일 | 내용 |
|---|---|
| `mydocs/working/task_m020_258_stage4.md` | Stage 4 대표 smoke 결과와 gate 판단 기록 |
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | Thumbnail 반복 smoke gate, Stage 4 기준선, PageLayerTree `displayText` 장기 판단 추가 |
| `mydocs/orders/20260603.md` | #258 상태를 Stage 4 완료 보고서 승인 대기로 갱신 |
| `build.noindex/task258-thumbnail-policy-representative/summary.txt` | 대표 샘플 smoke summary 산출물 |

## 대표 smoke 결과

명령:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy-representative \
  samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp
```

요청 preset:

| Request | maximumSize | scale | 의도 |
|---|---:|---:|---|
| `large` | `512x512` | `2` | 첫 render miss |
| `large-repeat` | `512x512` | `2` | 같은 key exact hit |
| `medium-after-large` | `256x256` | `2` | 큰 bucket 재사용 hit |
| `small-after-large` | `128x128` | `1` | 큰 bucket 재사용 hit |

전체 결과:

| 항목 | 결과 |
|---|---|
| 샘플 수 | 5 |
| row 수 | 5 files x 2 policies x 4 requests = 40 |
| 실패 row | 0 |
| fallback | 0 |
| cache event 패턴 | 각 파일/정책에서 `miss -> exactHit -> largerBucketHit(1024x1024) -> largerBucketHit(1024x1024)` |
| Skia opt-in backend | 모든 opt-in row `skia` |
| CoreGraphics backend | 모든 CoreGraphics row `coreGraphics` |

대표 수치:

| File | CoreGraphics first render ms | CoreGraphics output bytes | Skia first render ms | Skia output bytes | Skia PNG bytes |
|---|---:|---:|---:|---:|---:|
| `복학원서.hwp` | 1117.887 | 193700 | 57.548 | 155048 | 150336 |
| `KTX.hwp` | 55.776 | 484340 | 57.876 | 164259 | 151997 |
| `request.hwp` | 26.741 | 126597 | 61.184 | 120977 | 121702 |
| `hwpx-01.hwpx` | 32.436 | 198454 | 60.173 | 171054 | 187773 |
| `hwp-multi-001.hwp` | 28.042 | 196066 | 57.656 | 165485 | 178958 |

stdout에는 일부 샘플의 `LAYOUT_OVERFLOW` 진단 로그가 있었지만 helper 실패는 없었다. `summary.txt` 기준 모든 row의 status는 `OK`이고 fallback은 `-`이다.

## 장기 gate 정리

`mydocs/tech/skia_quicklook_thumbnail_backend.md`의 #258 gate에 다음 반복 기준을 추가했다.

- Thumbnail smoke helper는 `coreGraphicsOnly`와 `skiaOptIn`을 같은 입력/요청 순서로 실행한다.
- 대표군은 HWP 세로, HWP 가로, HWPX, 다중 페이지 HWP를 포함한다.
- 통과 기준은 모든 row `OK`, policy별 첫 요청 `miss`, 반복 요청 `exactHit`, 작은 요청 `largerBucketHit`, fallback 미발생 또는 사유 문서화다.
- render signature가 다른 policy 사이의 cache hit는 허용하지 않는다.
- 1px 수준의 bitmap pixel rounding 차이는 Stage 4 cache 실패가 아니라 #259 visual gate의 비교 입력으로 본다.

Quick Look 단일 PNG, Quick Look 다중 PDF, Finder Thumbnail은 같은 Shared renderer contract를 쓰되 rollout 판단은 분리한다. Thumbnail smoke가 안정적이어도 다중 페이지 Quick Look PDF가 불안정하면 Thumbnail만 opt-in 또는 first 후보가 될 수 있고, 반대도 가능하다.

## PageLayerTree displayText 판단

`U+F012B -> (인)`, `U+F081C -> 숨김` 같은 표시 문자열 계약은 장기적으로 Swift/CoreGraphics mapping을 계속 늘리는 방식보다 upstream `PageLayerTree`의 `displayText`를 소비하는 방향이 맞다.

이번 #258에서는 Swift `PageLayerTree` renderer를 만들지 않는다. 대신 cache signature와 Skia opt-in smoke를 준비해 PageLayerTree/Skia 경로를 Quick Look/Thumbnail surface별로 검증할 수 있게 했다. `복학원서.hwp` 같은 displayText 민감 샘플은 #259 visual readiness에서 계속 확인해야 한다.

## 본문 변경 정도 / 본문 무손실 여부

제품 source는 변경하지 않았다. Finder Thumbnail provider 기본 policy는 계속 `.coreGraphicsOnly`이며, Stage 4는 smoke 실행과 문서 기준선 갱신만 포함한다. GitHub issue 본문도 이번 단계에서 직접 수정하지 않았다.

## 검증 결과

| 검증 | 결과 |
|---|---|
| `./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task258-thumbnail-policy-representative samples/복학원서.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx samples/hwp-multi-001.hwp` | 통과, 40 rows 모두 `OK`, 실패 0, fallback 0 |
| `rg -n "#258|Thumbnail|cache signature|render signature|PageLayerTree|displayText|Quick Look|Finder Thumbnail|skiaOptIn|CoreGraphics" mydocs/working/task_m020_258_stage4.md mydocs/tech/skia_quicklook_thumbnail_backend.md` | 통과 |
| `git diff --check` | 통과 |
| `git status --short --branch` | 통과, Stage 4 문서 변경만 확인 |

## 잔여 위험

| 항목 | 내용 |
|---|---|
| 성능 통계 | Stage 4는 단일 실행 기준선이다. p50/p95, cold/warm 분리, peak RSS는 #259 readiness에서 측정해야 한다. |
| visual parity | smoke는 render 성공과 cache event 검증이다. Skia/CoreGraphics/reference visual diff는 #259 범위다. |
| forced fallback | 이번 대표군에서는 Skia fallback이 발생하지 않았다. fallback 강제 fixture 또는 오류 주입은 별도 follow-up 후보다. |
| pixel rounding | Skia opt-in 결과에서 긴 변이 CoreGraphics보다 1px 큰 row가 있다. Stage 4 cache 실패는 아니지만 #259 visual gate 입력으로 남긴다. |

## 다음 단계 영향

Stage 5에서는 Stage 1-4 산출물과 검증 결과를 최종 보고서로 묶고, #258 완료 기준을 모두 대응시킨다. 최종 검증에는 `check-no-appkit`, ThumbnailExtension build, 축약 smoke를 다시 포함한다.

## 승인 요청

Stage 4 대표 smoke와 장기 gate 문서화를 승인하면 Stage 5 `최종 보고서와 PR 준비`로 진행한다.
