# Task M020 #254 Stage 3 보고서

## 단계 목적

Stage 3의 목적은 #255-#259 후속 이슈의 의존 순서와 handoff gate를 정리하는 것이다. 이 단계에서는 GitHub issue 본문을 직접 수정하지 않고, 후속 작업자가 시작 조건과 완료 조건을 확인할 수 있도록 장기 기술 문서에 기준을 추가한다.

## 산출물

| 파일 | 요약 |
|---|---|
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | #255-#259 의존 순서, ABI gate, Shared renderer gate, Quick Look/Thumbnail integration gate, release readiness gate 추가. 282 lines |
| `mydocs/working/task_m020_254_stage3.md` | Stage 3 완료 보고서. 160 lines |
| `mydocs/orders/20260518.md` | #254 상태를 Stage 3 완료 및 Stage 4 승인 대기 상태로 갱신. 7 lines |

## 이슈 확인 결과

GitHub issue #255-#259는 모두 `v0.2.x Skia Quick Look/Thumbnail Backend` milestone의 open issue로 확인했다.

| 이슈 | 역할 | 확인한 책임 |
|---|---|---|
| #255 | ABI gate | RustBridge `native-skia` feature, PNG C ABI, generated header, `Rhwp.xcframework`, symbol/provenance 갱신 |
| #256 | Shared renderer gate | `RhwpDocument` Swift wrapper, `HwpPageImageRenderer` backend 선택, Skia PNG decode, CoreGraphics fallback |
| #257 | Quick Look integration gate | 단일 페이지 PNG reply, 다중 페이지 bitmap PDF path, Quick Look fallback/logging |
| #258 | Thumbnail integration gate | `maximumPixelSize` to Skia `max_dimension`, thumbnail cache key, fallback tile/CoreGraphics fallback |
| #259 | release readiness gate | visual diff, latency/memory, package size, default 전환 판단, known limitation |

## 확정한 의존 순서

확정한 기본 순서는 다음과 같다.

```text
#255 ABI gate
-> #256 Shared renderer gate
-> #257 Quick Look integration gate
-> #258 Thumbnail integration gate
-> #259 release readiness gate
```

#257과 #258은 #256의 Shared renderer contract가 고정된 뒤에는 서로 독립적으로 진행 가능하다. 단, 순차 진행 시에는 Quick Look을 먼저 적용해 단일/다중 page path를 확인하고, 이후 Thumbnail cache와 scale policy를 적용하는 편이 리뷰 단위가 명확하다.

## gate별 handoff 기준

### #255 ABI gate

입력:

- `rhwp v0.7.11` lock과 upstream native Skia PNG API 확인 결과
- Stage 2 failure taxonomy 중 FFI와 Skia render failure 관련 항목

출력:

- Swift에서 호출 가능한 Skia PNG C ABI
- generated header, `Rhwp.xcframework`, `rhwp-ffi-symbols.txt`, `rhwp-core.lock` 정합성
- PNG byte buffer 소유권/free 규칙
- staticlib/package size 변화 기록

### #256 Shared renderer gate

입력:

- #255의 ABI와 binary provenance
- Stage 2 backend contract

출력:

- `RhwpDocument` Skia PNG wrapper
- `HwpPageImageRenderer` backend 선택 구조
- Skia success를 기존 `HwpRenderedPage` 계약으로 연결
- Skia failure에서 CoreGraphics fallback
- backend/fallback 진단 필드

### #257 Quick Look integration gate

입력:

- #256의 Shared renderer opt-in backend
- 기존 Quick Look file size, empty document, invalid page size fallback 정책

출력:

- 단일 페이지 PNG reply의 Skia opt-in 성공 경로
- Skia 실패 또는 PNG decode 실패 후 CoreGraphics fallback
- 다중 페이지 PDF path 검증. 초기 default 전환은 보류하고 별도 opt-in 검증으로 시작
- Quick Look smoke 결과와 known limitation 후보

### #258 Thumbnail integration gate

입력:

- #256의 Shared renderer opt-in backend
- Thumbnail `maximumPixelSize`와 Stage 2 `max_dimension` 매핑 정책

출력:

- 요청 크기에 맞는 Skia thumbnail bitmap
- backend/render signature를 포함한 cache key 정책
- Skia 실패 또는 PNG decode 실패 후 CoreGraphics fallback
- 대표 크기별 Finder thumbnail smoke 결과

### #259 release readiness gate

입력:

- #255-#258의 산출물과 검증 결과

출력:

- 대표 샘플군의 visual diff 결과
- Quick Look/Thumbnail latency, memory, PNG decode cost 결과
- staticlib, `Rhwp.xcframework`, app/package size 변화
- `Skia first` 전환, `Skia opt-in` 유지, 또는 보류 판단
- release note known limitation 초안

## GitHub issue 본문 업데이트 후보

이번 단계에서는 GitHub issue 본문을 직접 수정하지 않았다. 후속 이슈 시작 직전에 다음 보강을 검토한다.

- #255: Stage 2 failure taxonomy 명칭을 ABI 오류 결과 표에 반영.
- #256: `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs` 진단 필드를 완료 기준에 추가.
- #257: 다중 페이지 PDF의 Skia 적용은 초기 default가 아니라 별도 opt-in 검증이라고 명시.
- #258: cache key에 backend/render signature를 포함한다는 완료 조건을 보강.
- #259: #255-#258 완료 결과를 입력으로 받는 release readiness gate임을 명시.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드, RustBridge ABI, project 설정은 변경하지 않았다.
- `mydocs/tech/skia_quicklook_thumbnail_backend.md`에 후속 이슈 의존 순서와 gate 기준을 추가했다.
- 신규 Stage 3 보고서를 추가하고 오늘할일 상태만 갱신했다.
- 기존 문서 내용을 삭제하지 않았고, Stage 2 정책 결론도 유지했다.

## 검증 결과

검증 명령은 Stage 3 문서 작성 후 실행한다.

```bash
rg -n "#255|#256|#257|#258|#259|ABI gate|Shared renderer|Quick Look|Thumbnail|release readiness" \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage3.md
```

결과: 통과. 문서가 #255-#259, ABI gate, Shared renderer gate, Quick Look/Thumbnail gate, release readiness gate를 포함하는지 확인했다.

```bash
git diff --check -- mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage3.md
```

결과: 통과. 최종 커밋 전 전체 `git diff --check`와 함께 재확인한다.

## 잔여 위험

- GitHub issue 본문은 아직 직접 업데이트하지 않았다. #254 최종 단계에서 업데이트 승인 여부를 다시 판단해야 한다.
- #257과 #258을 병렬 진행할 경우 Shared renderer API 변경이 다시 생기면 충돌할 수 있다.
- #259 readiness gate는 Stage 4에서 샘플군과 측정 항목이 더 구체화되어야 실행 가능하다.

## 다음 단계 영향

Stage 4에서는 #259가 사용할 visual/performance/package readiness checklist를 구체화한다. 특히 대표 샘플군, visual diff 기준, extension latency/memory, staticlib/package size, default 전환 판단 기준을 문서화해야 한다.

## 승인 요청

Stage 3은 후속 이슈 의존 순서와 handoff gate 정리로 마무리한다. Stage 4 `visual/performance/package readiness gate 정리`로 진행하려면 작업지시자 승인이 필요하다.
