# Task #390 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #390 `rhwp v0.7.17` 기준 Skia readiness gate 재측정 |
| 추적 이슈 | #387 Preview/Thumbnail Skia readiness 후속 개선 추적 |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 단계 수 | 5 |
| 작업 브랜치 | `local/task390` |

`rhwp v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` / `native-skia` 기준으로 Quick Look과 Finder Thumbnail의 Skia readiness를 다시 측정했다. 제품 코드와 renderer 정책은 변경하지 않았고, current core/studio provenance, Quick Look/Thumbnail smoke, visual diff, package/build gate를 문서화했다.

최종 판단은 `CoreGraphics default + Skia opt-in diagnostic backend` 유지다. Skia는 fallback 없이 동작하고 일부 단일 PNG/Thumbnail latency가 개선됐지만, `KTX.hwp` visual regression과 다중 PDF latency, Thumbnail dimension 차이 때문에 default 전환 근거가 부족하다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m020_390.md` | #390 수행계획서. 범위, 샘플 세트, 제외 항목, 검증 계획 정리 |
| `mydocs/plans/task_m020_390_impl.md` | 단계별 구현계획서. Stage 1-5 목표, 대상, 검증 명령 고정 |
| `mydocs/working/task_m020_390_stage1.md` | current core/studio provenance, #259 기준값, #388 handoff, 측정 명령 inventory |
| `mydocs/working/task_m020_390_stage2.md` | Quick Look/Thumbnail policy smoke 재측정 결과 |
| `mydocs/working/task_m020_390_stage3.md` | CoreGraphics/Skia opt-in visual diff 재측정 결과 |
| `mydocs/working/task_m020_390_stage4.md` | package/build gate와 surface별 readiness 판단 |
| `mydocs/report/task_m020_390_report.md` | 최종 보고서 |
| `mydocs/orders/20260629.md` | #390 오늘할일 완료 처리 |

제품 Swift/Rust source, `project.yml`, `Alhangeul.xcodeproj`에는 최종 diff가 없다. `xcodegen generate` 실행 후에도 project 파일 변경은 없었다.

## 변경 전·후 정량 비교

### provenance

| 항목 | #259 기준 | #390 기준 |
|------|-----------|-----------|
| core release | `v0.7.13` | `v0.7.17` |
| core commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` | `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| enabled features | `native-skia` | `native-skia` |
| bundled studio | #259 당시 bundle | current `rhwp-studio` manifest가 `v0.7.17` commit과 일치 |

### Quick Look smoke

| 샘플 | #259 CG/Skia sec | #390 CG/Skia sec | #390 fallback | 판단 |
|------|------------------|------------------|---------------|------|
| `request.hwp` | 1.073779 / 0.069324 | 1.188107 / 0.068532 | 0 | Skia latency 우위 유지 |
| `KTX.hwp` | 0.069717 / 0.071174 | 0.072109 / 0.059391 | 0 | latency는 Skia 우위로 개선 |
| `복학원서.hwp` | 0.160401 / 0.065900 | 0.049888 / 0.063096 | 0 | CG가 개선되어 이번 smoke는 CG 우위 |
| `hwp-multi-001.hwp` | 0.390930 / 0.666077 | 0.420672 / 0.482924 | 0 | Skia gap 감소, 여전히 CG 우위 |
| `hwpx-01.hwpx` | 0.376997 / 0.617429 | 0.376054 / 0.514870 | 0 | Skia gap 감소, 여전히 CG 우위 |

### visual diff

| 샘플 | #390 CG changed | #390 Skia changed | Skia-CG delta | 판단 |
|------|-----------------|-------------------|---------------|------|
| `request.hwp` | 17.6908% | 11.6265% | -6.0643pp | Skia visual 우위 |
| `KTX.hwp` | 30.8921% | 46.3795% | +15.4874pp | Skia visual regression 유지 |
| `복학원서.hwp` | 99.5953% | 99.3883% | -0.2070pp | reference capture contamination으로 품질 판단 제외 |
| `hwp-multi-001.hwp` | 14.1976% | 13.9298% | -0.2678pp | visual 유사, Skia latency는 느림 |
| `hwpx-01.hwpx` | 14.0216% | 13.8212% | -0.2004pp | visual 유사, Skia latency는 느림 |

### package/build

| 항목 | #259 `v0.7.13` | #390 `v0.7.17` | 판단 |
|------|---------------|---------------|------|
| `Frameworks/universal/librhwp.a` exact size | 203,436,808 bytes | 202,925,096 bytes | 소폭 감소 |
| `du -sh Frameworks/universal/librhwp.a` | `194M` | `194M` | package cost 변화 없음 |
| `du -sh Frameworks/Rhwp.xcframework` | `194M` | `194M` | package cost 변화 없음 |
| QLExtension Debug build | #259 통과 | 통과 | sandbox 밖 재실행 기준 |
| ThumbnailExtension Debug build | #259 통과 | 통과 | sandbox 밖 재실행 기준 |

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| 계획 | `6df276e` | 수행계획서 작성과 오늘할일 갱신 |
| 구현계획 | `ccb8fe4` | 단계별 구현계획서 작성 |
| Stage 1 | `792df78` | current provenance, #259 baseline, 측정 script inventory 정리 |
| Stage 2 | `b562fda` | Quick Look/Thumbnail smoke 재측정 |
| Stage 3 | `0f92558` | CoreGraphics/Skia visual diff 재측정 |
| Stage 4 | `e2921fc` | package/build gate와 readiness 판단 정리 |
| Stage 5 | 이번 커밋 | 최종 보고서 작성과 오늘할일 완료 처리 |

## 최종 판단

| surface | 판단 | 근거 |
|---------|------|------|
| Quick Look 단일 PNG | CoreGraphics default 유지, Skia opt-in 유지 | `request.hwp`는 Skia 우위지만 `KTX.hwp` visual regression이 blocker |
| Quick Look 다중 PDF | CoreGraphics default 유지 | 2개 다중 page 샘플 모두 Skia가 CG보다 느림 |
| Finder Thumbnail | CoreGraphics default 유지, Skia diagnostic 우선 | fallback은 없지만 Skia output dimension 1px 차이와 `KTX.hwp` visual risk가 남음 |
| Skia default 전환 | 보류 | visual, 다중 PDF latency, package cost를 종합하면 default 전환 기준 미달 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| current core/studio provenance 확인 | OK | `rhwp-core.lock`, `RhwpCoreBuildInfo`, studio manifest가 `v0.7.17` commit과 일치 |
| Quick Look smoke | OK | 5개 샘플 모두 `OK`, fallback 0 |
| Thumbnail smoke | OK | 3개 샘플 모두 `renders=8 failed=0`, signature에 current core metadata 포함 |
| CoreGraphics visual diff | OK | sandbox 내부 첫 실행은 readiness timeout, sandbox 밖 재실행 통과 |
| Skia opt-in visual diff | OK | sandbox 밖 실행 통과 |
| package size 기록 | OK | `librhwp.a`, `Rhwp.xcframework` 둘 다 `194M` |
| Xcode project 생성 | OK | `xcodegen generate` 통과, project diff 없음 |
| QLExtension Debug build | OK | sandbox 밖 재실행에서 `BUILD SUCCEEDED` |
| ThumbnailExtension Debug build | OK | sandbox 밖 재실행에서 `BUILD SUCCEEDED` |
| whitespace 점검 | OK | `git diff --check` 통과 |

## 잔여 위험과 후속 작업

| 항목 | 상태 | 처리 |
|------|------|------|
| Skia visual regression | 잔여 | `KTX.hwp` regression이 default 전환 blocker. #396 visual suite와 upstream renderer 개선 추적 필요 |
| 대표/확장 visual suite 부재 | 후속 | #396 `업스트림 renderer baseline 방식을 Quick Look/Thumbnail Skia 품질 검증에 이식` 우선 |
| Thumbnail Skia dimension 차이 | 후속 | #392 `Thumbnail Skia maxDimension mapping 실험` 우선 |
| Finder 실제 경로 진단 부족 | 후속 | #389 `Thumbnail Skia opt-in diagnostic path와 cache logging 추가` 우선 |
| Quick Look direct PNG fast path | 제한적 후속 | #393은 default 전환이 아니라 opt-in fast path 실험으로 제한 |
| filename/external image context | 후속 | #391에서 ABI와 bridge 설계 조사 |
| strict verify UX | 후속 | #394에서 `--verify-lock strict` 실패 UX와 portable verify 분리 |
| visual reference contamination | 잔여 | `복학원서.hwp` reference overlay 문제는 #396 또는 harness 보정에서 분리 |

## PR 게시 준비 메모

권장 PR 제목:

```text
Task #390: rhwp v0.7.17 기준 Skia readiness gate 재측정
```

권장 리뷰 포인트:

- 제품 코드 변경 없이 측정/판단 문서만 추가한 범위가 맞는지
- `KTX.hwp` visual regression을 Skia default blocker로 보는 결론이 타당한지
- #396, #392, #389를 후속 우선순위로 두는 정렬이 적절한지
- sandbox 내부 실패를 environment failure로 분리한 기록이 충분한지

## 작업지시자 승인 요청

Task #390의 측정과 최종 보고서 작성을 완료했다. PR 게시 단계 진입 여부를 승인해 달라.
