# Task #282 Stage 5 완료 보고서

## 작업 개요

- 이슈: #282
- 브랜치: `local/task282`
- 단계: Stage 5. 최종 보고와 후속 작업 handoff 정리
- 목표: Stage 1-4의 구현, smoke 측정, 관찰, 한계, 후속 작업 관계를 최종 보고서와 PR 본문에 넣을 수 있는 형태로 정리한다.

## Stage 5에서 정리한 항목

| 항목 | 내용 |
|------|------|
| 최종 보고서 | `mydocs/report/task_m014_282_report.md` 생성 |
| 오늘할일 | `mydocs/orders/20260527.md`의 #282 상태를 완료로 갱신 |
| 오늘할일 | `mydocs/orders/20260530.md` 생성, #282/#116/#296 실행 순서 기록 |
| compatibility follow-up | #296을 upstream rhwp #1016 release 반영 시 처리할 후속 이슈로 연결 |

## 최종 결론

#282의 구현 범위는 Quick Look/Thumbnail native CoreGraphics compositor가 rhwp-studio flow에 더 가까운 순서로 page content와 overlay image pass를 합성하도록 만드는 것이다. Stage 3에서 overlay image drawing path를 연결했고, Stage 4에서 `복학원서.hwp`를 BehindText positive fixture로 사용해 실제 overlay image 2개가 native path에서 그려지는 것을 확인했다.

Stage 4 기준 `복학원서.hwp` visual diff는 32.0086%로 여전히 크다. 그러나 smoke와 metadata를 함께 보면 남은 차이의 핵심은 compositor pass 연결 자체가 아니라 중앙 워터마크의 effect/brightness/contrast 처리와 upstream resolved watermark payload 여부다. 따라서 #282는 compositor 구조 보강으로 마무리하고, watermark parity는 #116에서 이어가는 것이 맞다.

## 핵심 수치

| Sample | Stage 1 기준 | Stage 4 결과 | 해석 |
|--------|-------------:|-------------:|------|
| `request.hwp` | 18.1021% | 18.0172% | harness/core 기준 변경 후 소폭 개선 |
| `hwpx-01.hwpx` | 15.1839% | 15.0285% | harness/core 기준 변경 후 소폭 개선 |
| `tac-img-02.hwp` | 4.1375% | 4.1335% | 거의 동일 |
| `tac-img-02.hwpx` | 3.6427% | 4.2178% | capture mode가 `domComposite`로 바뀌며 기준이 달라짐 |
| `hwp-img-001.hwp` | 7.8448% | 7.9015% | 거의 동일 |
| `img-start-001.hwp` | 14.4365% | 18.0119% | studio/core 기준 변경 영향이 큼 |
| `복학원서.hwp` | 해당 없음 | 32.0086% | BehindText positive fixture, watermark effect 차이 큼 |

## 관찰과 얻은 점

- 기존 sample set에는 BehindText/InFrontOfText overlay 양성 케이스가 없었다.
- `복학원서.hwp`는 `overlay=2`, `behind=2`, `front=0`, `renderable=2`, `binLinked=2`로 기록되므로 BehindText positive fixture로 쓸 수 있다.
- InFrontOfText positive fixture는 아직 없다. 이후 front overlay 회귀 검증에는 별도 fixture가 필요하다.
- #293 이후 visual diff harness는 overlay DOM이 있는 studio reference를 `domComposite`로 캡처한다. 이 변경 덕분에 `복학원서.hwp`의 좌상단 로고와 중앙 워터마크가 reference에 포함됐다.
- `복학원서.hwp` native output은 두 overlay image를 그리지만 중앙 워터마크가 rhwp-studio보다 훨씬 진하고 gray rectangle이 남는다.
- 현재 v0.7.13 payload는 중앙 워터마크를 `mime=image/jpeg`, `effect=grayScale`, `brightness=-50`, `contrast=70`, `watermarkPreset=custom`, `bakedWatermark=false`로 제공한다.
- Quick Look Skia opt-in 성공 경로는 #282의 CoreGraphics compositor를 우회한다. #282 변경은 Thumbnail 기본 경로와 Quick Look CoreGraphics fallback/coreGraphicsOnly policy에 직접 적용된다.

## 한계

- watermark/effect parity는 #282 범위를 넘긴다. #116에서 brightness/contrast/grayscale fallback을 다뤄야 한다.
- upstream rhwp #1016/#1017이 resolved baked watermark payload를 release하면 Swift fallback을 중복 적용하지 않도록 #296에서 compatibility gate를 넣어야 한다.
- fill/tile/placement 차이는 #122 영역으로 남는다.
- text/layout residual diff는 #121/#110 계열로 분리해서 봐야 한다.
- #282는 InFrontOfText positive fixture를 새로 만들지 않았다.

## 후속 순서

1. #282 PR을 게시하고 review/merge 대상으로 넘긴다.
2. #116에서 `복학원서.hwp` 중앙 watermark effect parity를 먼저 진행한다.
3. #296은 upstream rhwp #1016 release가 내려온 시점에 Swift fallback 중복 적용 방지로 처리한다.
4. #122/#121/#110은 watermark parity 이후 남는 diff를 분리해 진행한다.

## 검증 계획

Stage 5는 문서 정리 단계이므로 다음 검증을 수행한다.

```bash
rg -n "#116|#122|#121|#110|#282|#296|Skia|CoreGraphics|overlay|ChangedPercent" \
  mydocs/working/task_m014_282_stage*.md mydocs/report/task_m014_282_report.md
git diff --check
git status --short --branch
```

