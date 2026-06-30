# Task M020 #396 Stage 5 완료 보고서

## 단계 목적

#396 결과를 최종 기준 문서와 최종 보고서로 정리하고 PR 게시 준비 상태로 만든다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/tech/skia_preview_renderer_baseline.md` | baseline suite 실행 runbook과 2026-06-30 기준 해석 추가 |
| `mydocs/report/task_m020_396_report.md` | #396 최종 보고서 |
| `mydocs/working/task_m020_396_stage5.md` | Stage 5 완료 보고서 |
| `mydocs/orders/20260630.md` | #396 완료 처리 |

## 정리 내용

- quick suite는 PR smoke와 renderer 관련 변경의 빠른 재측정 기준으로 고정했다.
- extended suite는 Skia default 판단 전 수동 sweep으로 고정하되, CI hard gate 전 retry/flake 정책이 필요하다고 명시했다.
- `KTX.hwp`는 계속 `warn:skia-delta` regression sentinel로 남겼다.
- `복학원서.hwp`는 #398 이후 `domComposite;ui=clean` known-risk sample로 정리했다.
- `field-01.hwp`는 extended에서 확인된 text/form field 계열 Skia delta 후보로 기록했다.
- `form-002.hwpx`는 CoreGraphics/Skia 공통 persistent readiness failure로 분리했다.
- #387, #389, #392, #393, #394, #398 관계를 최종 보고서에 정리했다.

## 검증

실행 대상:

```bash
rg -n "#396|#387|#389|#392|#393|#394|Skia|CoreGraphics|Quick Look|Thumbnail|baseline|manifest|quick|extended" \
  mydocs/report/task_m020_396_report.md mydocs/orders/20260630.md \
  mydocs/tech/skia_preview_renderer_baseline.md mydocs/working/task_m020_396_stage5.md
git diff --check
git status --short --branch
git log --oneline devel..local/task396
```

결과는 Stage 5 커밋 전 최종 확인으로 남긴다.

## 완료 판단

- 최종 보고서가 존재하고 #396의 검증 체계를 설명한다.
- 운영 가이드가 quick/extended 실행과 triage 해석 기준을 포함한다.
- 오늘할일 #396이 완료 상태로 갱신된다.
- PR 게시 준비에 필요한 summary와 검증 명령이 정리되어 있다.

## 승인 요청

Stage 5는 완료했다. 최종 보고서 검토 후 PR 게시 단계 진행 여부를 승인 요청한다.
