# Task M020 #396 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #396 `업스트림 renderer baseline 방식을 Quick Look/Thumbnail Skia 품질 검증에 이식` |
| 추적 이슈 | #387 Preview/Thumbnail Skia readiness 후속 개선 추적 |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 단계 수 | 5 |
| 작업 브랜치 | `local/task396` |

업스트림 renderer baseline의 manifest/report/sweep 구조를 macOS Quick Look/Thumbnail Skia 품질 검증에 맞게 이식했다. 결과물은 Skia default 전환이 아니라, `CoreGraphics default + Skia opt-in` 상태에서 품질 신호를 반복 측정하는 기준 체계다.

제품 renderer 동작, RustBridge ABI, Xcode project, bundled rhwp core는 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m020_396.md` | #396 수행계획서 |
| `mydocs/plans/task_m020_396_impl.md` | Stage 1-5 구현계획서 |
| `scripts/preview_renderer_baseline_manifest.json` | quick/extended 대표 sample manifest, threshold, known risk 정의 |
| `scripts/preview-renderer-baseline.sh` | baseline helper shell entrypoint |
| `scripts/preview_renderer_baseline.py` | manifest 검증, policy별 harness 실행, pair summary 집계 |
| `mydocs/tech/skia_preview_renderer_baseline.md` | suite 정책, triage, 실행 runbook, Stage 4 기준 해석 |
| `mydocs/working/task_m020_396_stage1.md` | 업스트림/local baseline 구조 inventory |
| `mydocs/working/task_m020_396_stage2.md` | manifest와 threshold/triage 설계 보고 |
| `mydocs/working/task_m020_396_stage3.md` | helper 구현과 quick smoke 보고 |
| `mydocs/working/task_m020_396_stage4.md` | quick/extended 실행 결과와 readiness 분리 보고 |
| `mydocs/working/task_m020_396_stage5.md` | Stage 5 최종 정리 보고 |
| `mydocs/report/task_m020_396_report.md` | 본 최종 보고서 |
| `mydocs/orders/20260630.md` | #396 오늘할일 완료 처리 |

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| 계획 | `a90f751` | 수행계획서 작성과 오늘할일 갱신 |
| 구현계획 | `e558e32` | 단계별 구현계획서 작성 |
| Stage 1 | `84f927c` | 업스트림 baseline과 macOS visual harness gap inventory |
| Stage 2 | `37bc7a7` | quick/extended manifest, threshold, known risk 설계 |
| Stage 3 | `6ed6915` | manifest 기반 baseline helper 구현 |
| Stage 4 | `b25cb64` | quick/extended suite 실행과 readiness failure 분리 |
| Stage 5 | 이번 커밋 | 운영 가이드, 최종 보고서, PR 준비 정리 |

## 구현 결과

새 helper:

```bash
./scripts/preview-renderer-baseline.sh <output-dir> \
  --suite quick|extended|all \
  --manifest scripts/preview_renderer_baseline_manifest.json \
  --page-mode first|manifest \
  --policy-pair coreGraphicsOnly,skiaOptIn
```

제공 기능:

- manifest JSON 구조와 sample path 검증
- quick/extended suite filtering
- CoreGraphics default와 Skia opt-in policy pair 실행
- policy/page별 output directory 분리
- 기존 `preview-visual-diff-harness.sh` 재사용
- top-level `summary.md` 생성
- sample별 `ChangedPercent`, `MeanRGBDelta`, `NativeMs`, backend, fallback, size drift, known risk, artifact link 집계
- harness run 하나가 실패해도 다른 run을 계속 실행하고 failure phase를 summary에 보존

## Manifest 기준

Quick suite는 다음 5개 sample이다.

| id | sample | 역할 |
|----|--------|------|
| `request-basic-quick` | `samples/basic/request.hwp` | 건강한 단일 page 기준선 |
| `ktx-regression-sentinel` | `samples/basic/KTX.hwp` | #390 Skia visual regression sentinel |
| `bokhakwonseo-capture-sentinel` | `samples/복학원서.hwp` | #398 이후 clean capture/layout known-risk sentinel |
| `hwp-multi-001-page-loop` | `samples/hwp-multi-001.hwp` | multi-page preview loop |
| `hwpx-01-path` | `samples/hwpx/hwpx-01.hwpx` | HWPX path |

Extended suite는 quick 5개에 image, equation/shape, form/field, text/font, table category를 더한 20개 sample, 21개 sample page다.

## Stage 4 측정 결과

Quick suite:

```text
coreGraphicsOnly page-1: exitCode=0, inputs=5
skiaOptIn page-1: exitCode=0, inputs=5
```

대표 triage:

| id | CG changed | Skia changed | Skia-CG delta | triage |
|----|------------|--------------|---------------|--------|
| `request-basic-quick` | `17.6908%` | `11.6265%` | `-6.0643pp` | `warn:skia-changed` |
| `ktx-regression-sentinel` | `30.8921%` | `46.3795%` | `+15.4874pp` | `warn:skia-delta` |
| `bokhakwonseo-capture-sentinel` | `7.2888%` | `6.9406%` | `-0.3482pp` | `known-risk` |
| `hwp-multi-001-page-loop` | `14.1976%` | `13.9298%` | `-0.2678pp` | `warn:skia-changed` |
| `hwpx-01-path` | `14.0216%` | `13.8212%` | `-0.2004pp` | `warn:skia-changed` |

Extended suite:

```text
coreGraphicsOnly page-1: exitCode=1, inputs=20
coreGraphicsOnly page-2: exitCode=0, inputs=1
skiaOptIn page-1: exitCode=1, inputs=20
skiaOptIn page-2: exitCode=0, inputs=1
```

Extended 주요 판단:

| id | 결과 |
|----|------|
| `ktx-regression-sentinel` | `warn:skia-delta`, `+15.4874pp` |
| `bokhakwonseo-capture-sentinel` | `known-risk`, `domComposite;ui=clean`, `-0.3482pp` |
| `field-01-field` | `warn:skia-delta`, `+8.9979pp` |
| `hwp-multi-001-page-loop` page 2 | `ok`, `-0.2265pp` |
| `shortcut-control-mark` | `known-risk`, `display-text-sensitive` |

Readiness failure 분리:

| sample | 판단 |
|--------|------|
| `form-002.hwpx` | CoreGraphics/Skia 양쪽에서 persistent `readiness` document load timeout. renderer 품질 실패로 세지 않음 |
| `table-complex.hwp` | full batch에서는 timeout, 소규모 CoreGraphics 재시도 통과 |
| `pic-crop-01.hwp` | full batch에서는 timeout, 소규모 Skia 재시도 통과 |

## 최종 판단

| 항목 | 판단 |
|------|------|
| Skia default 전환 | 보류. #396은 전환 기준을 만드는 작업이며, 전환 자체는 하지 않음 |
| Quick smoke | 반복 가능. PR review와 renderer 관련 변경 smoke에 사용 가능 |
| Extended sweep | 수동 readiness sweep으로 사용 가능. CI hard gate 전 retry/flake 정책 필요 |
| KTX | `warn:skia-delta` 유지. Skia default blocker 성격 |
| 복학원서 | #398 이후 clean capture로 복구. capture contamination이 아니라 layout/displayText known-risk로 분리 |
| field-01 | extended에서 새 Skia delta 후보로 확인 |
| Thumbnail 판단 | visual suite만으로 완료하지 않음. #392/#389 surface smoke 필요 |

## 후속 이슈 관계

| 이슈 | 관계 |
|------|------|
| #387 | #396 결과를 상위 추적 이슈의 renderer baseline 입력으로 연결 |
| #389 | Finder Thumbnail cache/signature/logging은 visual suite 범위 밖이므로 계속 필요 |
| #392 | Thumbnail maxDimension mapping과 size drift 판단은 별도 surface smoke로 이어감 |
| #393 | direct PNG fast path는 default 전환 수단이 아니라 opt-in 검증 축으로 유지 |
| #394 | `--verify-lock strict` UX 개선/portable verify 분리는 #396 baseline helper와 별도 운영성 작업 |
| #398 | `복학원서.hwp` capture contamination을 clean metadata 기반 known-risk로 재분류하게 한 선행 작업 |

## 검증 결과

| 명령 | 결과 |
|------|------|
| `./scripts/verify-rhwp-core-build-info.sh` | OK |
| `./scripts/verify-rhwp-studio-assets.sh` | OK |
| `./scripts/check-no-appkit.sh` | OK |
| `python3 -m json.tool scripts/preview_renderer_baseline_manifest.json >/dev/null` | OK |
| `./scripts/preview-renderer-baseline.sh --validate-only --suite extended --page-mode manifest` | OK, `samples=20`, `samplePages=21` |
| `./scripts/preview-renderer-baseline.sh build.noindex/task396-baseline-quick --suite quick` | OK |
| `./scripts/preview-renderer-baseline.sh build.noindex/task396-baseline-extended-sample --suite extended` | readiness failure 포함 exit 1. 실패 phase 보존 |
| readiness 실패 샘플 소규모 재시도 | `form-002.hwpx` persistent readiness, 나머지 transient로 분리 |
| `git diff --check` | OK |

## PR 게시 준비 메모

권장 PR 제목:

```text
Task #396: Skia renderer baseline suite 도입
```

권장 PR 본문 요약:

```text
## Summary
- Add a manifest-driven preview renderer baseline suite for CoreGraphics default vs Skia opt-in comparison.
- Add quick and extended sample policy with known-risk/threshold metadata.
- Add a helper that runs the existing visual diff harness for both policies and writes an aggregate summary.
- Document Stage 4 quick/extended results and follow-up issue handoff.

## Verification
- ./scripts/verify-rhwp-core-build-info.sh
- ./scripts/verify-rhwp-studio-assets.sh
- ./scripts/check-no-appkit.sh
- python3 -m json.tool scripts/preview_renderer_baseline_manifest.json >/dev/null
- ./scripts/preview-renderer-baseline.sh --validate-only --suite extended --page-mode manifest
- ./scripts/preview-renderer-baseline.sh build.noindex/task396-baseline-quick --suite quick
- ./scripts/preview-renderer-baseline.sh build.noindex/task396-baseline-extended-sample --suite extended
- git diff --check
```

리뷰 포인트:

- manifest schema와 quick/extended sample 선정이 M020 Skia 판단에 충분한지
- `warn:skia-delta`, `warn:skia-changed`, `known-risk`, `readiness` failure 분리가 이해 가능한지
- extended suite를 아직 CI hard gate로 두지 않는 판단이 적절한지
- #392/#389/#393 후속으로 넘긴 Thumbnail/Finder surface 판단 범위가 적절한지

## 작업지시자 승인 요청

Task #396의 구현, 검증, 최종 보고서 작성을 완료했다. PR 게시 단계 진입 여부를 승인 요청한다.
