# Task M020 #254 Stage 4 보고서

## 단계 목적

Stage 4의 목적은 #259가 사용할 visual, performance, memory, package readiness gate를 구체화하는 것이다. 이 단계에서는 제품 코드와 GitHub issue 본문을 변경하지 않고, Stage 2-3에서 정한 optional backend/fallback/handoff 기준을 측정 가능한 gate로 연결한다.

## 산출물

| 파일 | 요약 |
|---|---|
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | readiness 샘플군, visual diff triage, latency/memory/package 측정 항목, rollout 판단 기준, release note known limitation 후보 추가. 395 lines |
| `mydocs/working/task_m020_254_stage4.md` | Stage 4 완료 보고서. 159 lines |
| `mydocs/orders/20260518.md` | #254 상태를 Stage 4 완료 및 Stage 5 승인 대기 상태로 갱신. 7 lines |

## 확인한 기존 검증 자산

기존 문서와 스크립트 기준으로 다음 자산을 #259 readiness gate에 연결했다.

| 자산 | 역할 |
|---|---|
| `scripts/validate-stage3-render.sh` | 기본 샘플의 native renderer smoke. 문서 open, render tree, 한글 text/glyph, page size, non-blank PNG 확인 |
| `scripts/render-debug-compare.sh` | 특정 파일의 core SVG, render tree JSON, native PNG, optional pixel diff 생성 |
| `scripts/visual-compare-quicklook-renderers.sh` | Quick Look 관련 visual summary와 pixel diff 생성 형식 참고 |
| `mydocs/manual/render_core_native_compare_guide.md` | smoke와 debug compare의 역할, 산출물, diff 해석 기준 |
| clean Quick Look/Thumbnail smoke script 계열 | extension 등록, thumbnail 생성, 실제 Quick Look/Finder 수동 smoke 기록 |
| `mydocs/manual/release_policy_guide.md` | `Rhwp.xcframework`, staticlib, release artifact provenance/known limitation 공개 기준 |

Stage 4에서는 새 검증 스크립트를 만들지 않았다. #259에서 Skia 산출물이 생기면 기존 summary 형식에 맞춰 확장하거나 report 표로 수집하면 된다.

## 대표 샘플군

기술 문서에 다음 대표군을 고정했다.

| 그룹 | 기본 샘플 |
|---|---|
| 단일 페이지 | `samples/basic/KTX.hwp`, `samples/basic/request.hwp` |
| 다중 페이지 | `samples/hwp-multi-001.hwp`, `samples/basic/exam_math.hwp`, `samples/hwpx/hwpx-01.hwpx` |
| 이미지 포함 | `samples/hwp-img-001.hwp`, `samples/img-start-001.hwp` |
| 수식/도형 | `samples/eq-01.hwp`, `samples/group-drawing-02.hwp`, `samples/draw-group.hwp` |
| form/raw object 후보 | `samples/form-01.hwp`, `samples/hwpx/form-002.hwpx`, `samples/group-box.hwp` |
| text/font 민감 | `samples/footnote-01.hwp`, `samples/basic/shortcut.hwp`, `samples/exam_kor.hwp`, `samples/lseg-02-mixed.hwp` |
| package/smoke 기본 | `samples/basic/KTX.hwp`, `samples/basic/request.hwp`, `samples/exam_kor.hwp` |

외부 개인 경로 샘플은 release readiness 기준으로 삼지 않고 참고로만 기록한다.

## visual diff 기준

visual gate는 pixel diff 숫자 하나로 통과/실패를 결정하지 않도록 정리했다.

Hard fail:

- crash, hang, timeout, empty PNG, decode failure
- page size 또는 aspect ratio 불일치
- 본문, 표, 이미지, 수식, form control 주요 구조 누락
- 전체 page offset, 반전, clipping, 투명 배경
- Skia 실패 뒤 CoreGraphics fallback 실패

Pixel diff triage:

- `0-1%`: 보통 antialias/rasterizer 차이. 통과 후보
- `1-5%`: 눈검증 필요
- `5-10%`: known difference 또는 후속 이슈 분류
- `10%+`: default 전환 차단 후보

단, diff 비율이 낮아도 핵심 object가 누락되면 hard fail이고, text-heavy 문서의 antialias 차이는 수치가 높아도 known difference로 분류할 수 있다.

## latency/memory 기준

Quick Look 측정 항목:

- `inspectMs`
- `renderMs`
- `pngEncodeOrDecodeMs`
- `replyDataMs`
- `pageCount`, `replyType`, `backendUsed`, `fallbackReason`
- peak RSS 또는 `memoryHighWaterMB`

Thumbnail 측정 항목:

- `requestPixelSize`, `pixelBucket`, `backendUsed`
- cache miss render duration
- cache hit response duration
- Skia PNG bytes 길이와 decode duration
- fallback 발생 횟수와 fallback reason
- peak RSS 또는 `memoryHighWaterMB`

Stage 4에서는 numeric threshold를 임의 확정하지 않았다. #259가 같은 machine/session에서 CoreGraphics baseline과 Skia result를 같은 표에 기록한 뒤 default 전환, opt-in 유지, 보류 판단을 내려야 한다.

## package 기준

기술 문서에 다음 측정 항목을 추가했다.

- Rust staticlib size: `Frameworks/universal/librhwp.a`
- `Rhwp.xcframework` size
- generated header size/hash
- Debug app bundle size
- release zip/DMG candidate size
- universal slice 유지 여부

크기 증가 자체는 실패가 아니지만, app/extension load time이나 release artifact 설명이 필요할 정도의 증가라면 rollout 판단과 release note 후보에 반영한다.

## rollout 판단 기준

| 결정 | 조건 |
|---|---|
| `Skia first` 전환 후보 | #255-#258 완료, hard fail 없음, fallback 정상, latency/memory 허용 가능, package delta 설명 가능 |
| `Skia opt-in` 유지 | visual coverage는 유효하지만 특정 sample군의 diff, latency, package delta가 default로 설명하기 어려움 |
| 보류 | crash/hang/timeout, decode failure, major visual regression, fallback failure, extension memory pressure가 남음 |

Quick Look과 Thumbnail은 서로 다른 surface이므로 하나의 결과를 다른 surface에 강제하지 않는다.

## release note known limitation 후보

다음 후보를 기술 문서에 추가했다.

- Skia backend는 초기에는 opt-in 또는 내부 진단 경로일 수 있다.
- Skia와 CoreGraphics는 text antialiasing, font fallback, 수식/도형 rasterization에서 pixel-perfect하게 같지 않을 수 있다.
- 다중 페이지 Quick Look preview는 여전히 bitmap PDF container다.
- Quick Look/Thumbnail smoke 통과는 모든 문서의 visual parity 보장이 아니다.
- `native-skia` feature로 app bundle 또는 download artifact 크기가 증가할 수 있다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드, RustBridge ABI, project 설정은 변경하지 않았다.
- `mydocs/tech/skia_quicklook_thumbnail_backend.md`에 Stage 4 readiness gate 기준만 추가했다.
- 신규 Stage 4 보고서를 추가하고 오늘할일 상태만 갱신했다.
- 기존 Stage 2-3 정책과 handoff gate 내용은 삭제하지 않았다.

## 검증 결과

검증 명령은 Stage 4 문서 작성 후 실행한다.

```bash
rg -n "visual|diff|latency|memory|package|staticlib|Rhwp.xcframework|default|opt-in|보류" \
  mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage4.md
```

결과: 통과. 문서가 visual/diff, latency/memory, package/staticlib/Rhwp.xcframework, default/opt-in/보류 기준을 포함하는지 확인했다.

```bash
git diff --check -- mydocs/tech/skia_quicklook_thumbnail_backend.md mydocs/working/task_m020_254_stage4.md
```

결과: 통과. 최종 커밋 전 전체 `git diff --check`와 함께 재확인한다.

## 잔여 위험

- 실제 측정값은 아직 없다. #259에서 Skia 구현 산출물을 기준으로 실행해야 한다.
- numeric threshold는 Stage 4에서 고정하지 않았다. sample별 baseline/result/delta를 수집한 뒤 #259에서 확정해야 한다.
- Skia용 visual compare summary 형식은 아직 구현되지 않았다. 기존 visual compare 도구 형식을 재사용할지 #259에서 결정해야 한다.
- release note known limitation은 후보이며 최종 문구는 Stage 5와 release 작업에서 정리해야 한다.

## 다음 단계 영향

Stage 5에서는 Stage 1-4 결론을 최종 설계 문서와 최종 보고서로 정리한다. 특히 권장 rollout 순서, 후속 이슈별 시작 조건, 잔여 리스크, GitHub issue 본문 업데이트 승인 후보를 최종 상태로 모아야 한다.

## 승인 요청

Stage 4는 visual/performance/package readiness gate 정리로 마무리한다. Stage 5 `최종 설계 문서와 보고서 정리`로 진행하려면 작업지시자 승인이 필요하다.
