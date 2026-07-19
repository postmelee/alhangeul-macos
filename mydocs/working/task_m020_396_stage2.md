# Task M020 #396 Stage 2 완료보고서

## 단계 목적

Quick Look/Thumbnail Skia 품질 검증용 대표 manifest와 sample별 threshold/triage policy를 문서와 JSON 초안으로 고정한다.

이번 단계는 Stage 3 helper가 사용할 입력 계약을 만드는 작업이다. 제품 Swift/Rust renderer source와 기존 harness script는 수정하지 않았다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `scripts/preview_renderer_baseline_manifest.json` | quick/extended suite, surfaces, threshold policy, 20개 대표 sample 정의 |
| `mydocs/tech/skia_preview_renderer_baseline.md` | manifest schema, suite 정책, threshold/triage, known risk 처리 문서화 |
| `mydocs/working/task_m020_396_stage2.md` | Stage 2 완료 보고서 |
| `mydocs/orders/20260629.md` | #396 비고를 Stage 2 완료보고서 승인 대기로 갱신 |

## Manifest 설계 결과

| 항목 | 결정 |
|------|------|
| label | `quicklook-thumbnail-skia-baseline` |
| page index | 1-based |
| policy pair | `coreGraphicsOnly`, `skiaOptIn` |
| quick suite | 5 samples |
| extended suite | 20 samples |
| surfaces | `visual`, `quicklook`, `thumbnail` |
| threshold 성격 | hard gate가 아니라 warning/triage metadata |
| known risk | `regression-sentinel`, `capture-contamination`, `size-drift-watch`, `display-text-sensitive` |

quick suite는 #390에서 실제 visual diff와 readiness 판단에 사용한 핵심 5개 sample로 고정했다.

| id | path | 역할 |
|----|------|------|
| `request-basic-quick` | `samples/basic/request.hwp` | 건강한 단일 page 기준선 |
| `ktx-regression-sentinel` | `samples/basic/KTX.hwp` | Skia visual regression sentinel |
| `bokhakwonseo-capture-sentinel` | `samples/복학원서.hwp` | capture contamination/displayText sentinel |
| `hwp-multi-001-page-loop` | `samples/hwp-multi-001.hwp` | HWP multi-page path |
| `hwpx-01-path` | `samples/hwpx/hwpx-01.hwpx` | HWPX path |

extended suite는 quick 5개에 다음 category를 추가했다.

| category | sample 수 | 목적 |
|----------|-----------|------|
| `image` | 3 | image decode, placement, crop |
| `equation-shape` | 4 | equation, grouped drawing, vector replay |
| `form-field` | 3 | HWP/HWPX form, field |
| `text-font` | 4 | footnote, line segment, font fallback, display text |
| `table` | 1 | complex table layout |
| quick overlap | 5 | single-page, multi-page, HWPX, known sentinel 유지 |

## Threshold / Triage 결정

`ChangedPercent`는 자동 통과/실패 기준으로 쓰지 않는다. 기본 warning band는 다음처럼 문서화했다.

| 구간 | 해석 |
|------|------|
| `0-1%` | antialiasing 또는 작은 rasterizer 차이 가능성 |
| `1-5%` | text edge, 1px rounding, 일부 object 차이 가능성 |
| `5-10%` | 구조 차이 가능성이 있어 눈검증 필요 |
| `10%+` | 큰 구조 차이 가능성이 높아 default 전환 차단 후보 |

hard fail 후보는 crash, hang/timeout, empty output, decode failure, aspect ratio mismatch, 주요 구조 누락, page offset/잘림/반전, fallback failure로 분리했다.

`KTX.hwp`는 `regression-sentinel`로 두고 `maxSkiaMinusCGChangedPercentWarn`을 `10.0`으로 기록했다. #390의 `+15.4874pp` 악화는 warning을 넘으므로 Stage 3-4 summary에서 계속 default blocker로 보여야 한다.

`복학원서.hwp`는 `capture-contamination`으로 두었다. reference capture가 정리되기 전에는 changed percent를 renderer 품질 점수로 쓰지 않는다.

Thumbnail surface가 포함된 quick sample은 #390의 1px dimension 차이를 반영해 `maxAllowedSizeDriftPx: 1`을 둔다. 이 허용은 cache 성공 판정이 아니라 visual triage 용도다.

## Stage 3 입력 계약

Stage 3 helper는 다음 계약을 따르면 된다.

```bash
./scripts/preview-renderer-baseline.sh <out-dir> \
  --suite quick \
  --manifest scripts/preview_renderer_baseline_manifest.json \
  --page-mode first \
  --policy-pair coreGraphicsOnly,skiaOptIn
```

helper는 manifest path 검증, suite/page filtering, CoreGraphics/Skia harness 실행, pair summary 생성을 담당한다. summary에는 sample id, category, policy별 status, `ChangedPercent`, `MeanRGBDelta`, `NativeMs`, size drift, fallback, known risk, artifact path가 들어가야 한다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 신규 manifest/정책 문서/단계 보고서 작성과 오늘할일 비고 갱신만 수행했다. 기존 문서의 본문은 수정하지 않았고 제품 source/script 동작도 변경하지 않았다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `python3 -m json.tool scripts/preview_renderer_baseline_manifest.json` | 통과 |
| manifest sample path 검증 | 통과: `samples=20 quick=5 extended=20` |
| Stage 2 keyword `rg` | 통과: suite, sentinel, threshold, metric keyword 확인 |
| `git diff --check` | 통과 |

## 잔여 위험

- threshold 값은 release hard gate가 아니라 warning metadata다. Stage 4 실행 결과 없이 default 전환 기준으로 해석하면 안 된다.
- `복학원서.hwp`는 여전히 reference capture contamination sample이다. 이 sample의 visual diff 수치는 renderer 품질 점수에서 제외해야 한다.
- multi-page sample은 manifest에 page 2 후보를 포함하지만, Stage 3 quick mode는 page 1만 실행해야 한다. extended mode에서 page count/실행 시간을 다시 확인해야 한다.
- Thumbnail dimension drift는 manifest에 triage metadata로만 반영했다. 실제 `maxDimension` mapping 원인은 #392와 연결해야 한다.

## 다음 단계 영향

Stage 3에서는 `scripts/preview-renderer-baseline.sh`와 필요 시 집계 helper를 구현한다. 기존 `preview-visual-diff-harness.sh`를 정책별로 실행하고, 이번 manifest의 known risk와 threshold metadata를 summary에 연결한다.

## 승인 요청

Stage 2 결과에 따라 Stage 3 `baseline 실행 helper와 report 구조 구현`으로 진행해도 되는지 승인 요청한다.
