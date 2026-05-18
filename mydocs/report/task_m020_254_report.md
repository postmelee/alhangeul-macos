# Task M020 #254 최종 보고서

## 작업 개요

- 이슈: #254 Skia Quick Look/Thumbnail optional backend 설계와 rollout gate 정리
- 마일스톤: M020 `v0.2.x Skia Quick Look/Thumbnail Backend`
- 브랜치: `local/task254`
- 목표: upstream `rhwp v0.7.11` native Skia PNG backend를 Quick Look/Thumbnail에 optional backend로 도입하기 위한 설계, fallback contract, 후속 이슈 handoff, readiness gate를 문서화한다.

## 완료 범위

- 현재 Quick Look/Thumbnail renderer가 `PageRenderTree` JSON + Swift `CGTreeRenderer` + CoreGraphics/CoreText 경로임을 정리했다.
- upstream `rhwp v0.7.11`에 `native-skia`, `render_page_png_native*`, `PngExportOptions`가 존재하지만 현재 앱 ABI에는 노출되지 않았음을 정리했다.
- backend 후보를 비교하고 현재 기본값은 `CoreGraphics only`, 첫 구현은 `Skia opt-in`으로 권장했다.
- Skia 실패 시 Quick Look text fallback 또는 Thumbnail tile fallback으로 바로 가지 않고 CoreGraphics fallback을 먼저 사용하는 contract를 정리했다.
- #255-#259의 의존 순서와 gate별 입력/출력 조건을 정리했다.
- #259가 사용할 대표 샘플군, visual diff triage, latency/memory/package 측정 항목, rollout 판단 기준을 정리했다.

## 단계별 결과

| 단계 | 산출물 | 요약 |
|---|---|---|
| Stage 1 | `mydocs/working/task_m020_254_stage1.md` | 현행 renderer flow, FFI 표면, upstream Skia 적용 후보, #96/#222/#254 경계 정리 |
| Stage 2 | `mydocs/working/task_m020_254_stage2.md` | backend 선택 정책, failure taxonomy, Quick Look/Thumbnail fallback contract 정리 |
| Stage 3 | `mydocs/working/task_m020_254_stage3.md` | #255-#259 handoff gate와 issue 본문 업데이트 후보 정리 |
| Stage 4 | `mydocs/working/task_m020_254_stage4.md` | visual/performance/package readiness gate와 known limitation 후보 정리 |
| Stage 5 | `mydocs/report/task_m020_254_report.md` | 최종 결론과 후속 실행 기준 정리 |

장기 기술 문서는 `mydocs/tech/skia_quicklook_thumbnail_backend.md`에 남겼다.

## 최종 권장 rollout

권장 순서는 다음과 같다.

```text
#255 RustBridge native-skia PNG ABI
-> #256 Shared renderer optional backend
-> #257 Quick Look skiaOptIn integration
-> #258 Thumbnail skiaOptIn integration
-> #259 visual/performance/package readiness
-> 별도 승인 후 Skia first/default 전환 판단
```

현재 시점의 기본값은 `CoreGraphics only`로 유지한다. 후속 구현의 첫 제품 노출은 `Skia opt-in`이며, `Skia first` 또는 `Skia default`는 #259 측정 결과와 별도 승인 없이는 진행하지 않는다.

## 후속 이슈 시작 조건

| 이슈 | 시작 조건 | 완료 조건 핵심 |
|---|---|---|
| #255 | `rhwp v0.7.11` lock과 upstream Skia PNG API 확인 결과 | Swift에서 호출 가능한 PNG C ABI, header/symbol/lock 정합성, staticlib/package size 기록 |
| #256 | #255 ABI와 binary provenance 완료 | `RhwpDocument` wrapper, `HwpPageImageRenderer` backend 선택, CoreGraphics fallback, 진단 필드 |
| #257 | #256 Shared renderer opt-in backend 완료 | 단일 page Quick Look PNG Skia success, 다중 page PDF 검증, fallback/logging 유지 |
| #258 | #256 Shared renderer opt-in backend 완료 | `maximumPixelSize` to `max_dimension`, cache key backend 반영, thumbnail smoke |
| #259 | #255-#258 완료 | visual diff, latency/memory, package delta, default/opt-in/보류 판단 |

## 검증 결과

각 단계 검증은 해당 Stage 보고서에 기록했다. 최종 단계에서는 다음 명령으로 최종 산출물 연결을 확인한다.

```bash
rg -n "#254|#255|#256|#257|#258|#259|Skia|Quick Look|Thumbnail|fallback|readiness" \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/report/task_m020_254_report.md mydocs/orders/20260518.md
git diff --check
```

결과: 통과. 최종 기술 문서, 최종 보고서, 오늘할일에서 #254-#259, Skia, Quick Look/Thumbnail, fallback, readiness 기준이 연결되어 있음을 확인했다.

`git diff --check`도 통과했다.

## 잔여 리스크

- 실제 `native-skia` feature 활성화, RustBridge ABI 추가, Swift wrapper 구현은 #255/#256 범위로 남아 있다.
- Skia PNG decode 비용, extension memory, first-call latency, package size 증가는 아직 실측하지 않았다.
- Skia와 CoreGraphics의 font fallback/text antialiasing 차이는 #259의 sample별 visual triage가 필요하다.
- GitHub issue #255-#259 본문 보강은 후보만 정리했고 직접 수정하지 않았다.
- `mydocs/tech/project_architecture.md`의 일부 `v0.7.10` 설명은 현재 `rhwp-core.lock`의 `v0.7.11`과 불일치하므로 별도 문서 정합성 작업 후보로 남긴다.

## GitHub issue 본문 업데이트 후보

후속 이슈 시작 직전에 작업지시자 승인을 받은 뒤 다음 보강을 검토한다.

- #255: failure taxonomy 명칭과 ABI 오류 결과 표 반영
- #256: `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs` 진단 필드 명시
- #257: 다중 페이지 PDF Skia 적용은 초기 default가 아니라 별도 opt-in 검증임을 명시
- #258: cache key에 backend/render signature 포함 조건 보강
- #259: #255-#258 산출물을 입력으로 받는 release readiness gate임을 명시

## 결론

#254는 Skia를 바로 기본 renderer로 전환하지 않는다. 현재 앱 구조와 upstream 상태를 기준으로 보면 Skia 도입은 가능하지만, 먼저 ABI, Shared renderer, Quick Look/Thumbnail surface, readiness gate를 순서대로 닫아야 한다.

따라서 최종 결론은 `CoreGraphics only` 기본값 유지, `Skia opt-in`부터 구현, #259 측정 이후 default 전환 별도 승인이다.
