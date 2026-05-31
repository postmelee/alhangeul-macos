# Task M014 #293 최종 결과보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#293](https://github.com/postmelee/alhangeul-macos/issues/293) preview visual diff harness가 rhwp-studio overlay DOM을 포함해 캡처하도록 수정 |
| 마일스톤 | M014 — v0.1.4 Native Preview/Viewer Parity |
| 브랜치 | `local/task293` |
| 단계 수 | 4단계 |
| 최종 기준 | overlay-positive `rhwp-studio` reference는 `domComposite`, overlay 없는 canvas 문서는 `canvasDataURL` |

이번 작업은 `rhwp-studio` 웹 화면에는 보이는 DOM overlay가 visual diff harness의 studio reference PNG에서 누락되는 문제를 수정했다. `복학원서.hwp` 기준으로 좌상단 고려대학교 로고, 중앙 BehindText 워터마크, 하단 우측 붉은 도장이 최종 studio reference PNG에 포함되는 것을 확인했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `scripts/preview_visual_diff_harness.swift` | overlay-positive 문서에서 canvas-only export 대신 DOM drawable composite PNG를 생성하도록 capture decision과 `compositeDataURLScript`를 추가했다. |
| `mydocs/plans/task_m014_293.md` | 수행계획서. 범위, 제외 항목, 검증 계획, 승인 요청 사항을 기록했다. |
| `mydocs/plans/task_m014_293_impl.md` | 구현계획서. Stage 1-4의 산출물과 검증 기준을 정의했다. |
| `mydocs/working/task_m014_293_stage1.md` | 현행 `canvasDataURL` capture decision과 overlay 누락 재현 결과를 기록했다. |
| `mydocs/working/task_m014_293_stage2.md` | `webViewSnapshot` 우선 선택 구현과 smoke 결과, snapshot blank 위험을 기록했다. |
| `mydocs/working/task_m014_293_stage3.md` | WebKit snapshot blank를 확인하고 `domComposite`로 회복한 최종 smoke 결과를 기록했다. |
| `mydocs/report/task_m014_293_report.md` | 최종 결과, 검증, #282/#116 handoff, 잔여 위험을 정리했다. |
| `mydocs/orders/20260529.md` | #293 상태를 완료로 갱신했다. |

## 변경 전·후 정량 비교

`복학원서.hwp` studio reference metadata:

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| `captureMode` | `canvasDataURL` | `domComposite` |
| `overlayIncluded` | `false` | `true` |
| `overlayCount` | `5` | `5` |
| `usedOverlayUnion` | `true` | `true` |
| PNG size | `1587x2245` | `1587x2245` |
| ChangedPixels | `1141965/3562815` | `1140387/3562815` |
| ChangedPercent | `32.0523%` | `32.0080%` |
| MeanRGBDelta | `42.2623` | `37.8073` |

Stage 3 sample set 최종 수치:

| File | Status | StudioCapture | ChangedPercent | MeanRGBDelta |
|------|--------|---------------|----------------|--------------|
| `복학원서.hwp` | OK | `domComposite` | `32.0080%` | `37.8073` |
| `request.hwp` | OK | `domComposite` | `17.8542%` | `11.0716` |
| `hwpx-01.hwpx` | OK | `domComposite` | `15.0285%` | `15.2088` |
| `tac-img-02.hwp` | OK | `canvasDataURL` | `4.1153%` | `3.6698` |
| `tac-img-02.hwpx` | OK | `domComposite` | `4.1153%` | `3.6698` |
| `hwp-img-001.hwp` | OK | `domComposite` | `7.8277%` | `8.1872` |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `복학원서.hwp` 1페이지 studio reference PNG에 좌상단 로고와 중앙 워터마크 포함 | OK | Stage 3 visual check에서 좌상단 로고, 중앙 BehindText 워터마크, 하단 우측 붉은 도장 확인 |
| overlay-positive metadata에서 `overlayIncluded=true` 기록 | OK | `복학원서.hwp`: `captureMode=domComposite`, `overlayIncluded=true`, `overlayCount=5` |
| overlay 없는 canvas-only 문서의 기존 capture 경로 유지 | OK | `tac-img-02.hwp`: `captureMode=canvasDataURL`, `overlayIncluded=false`, `overlayCount=0` |
| v0.1.4 sample set summary 재생성 | OK | `build.noindex/task293-stage3-samples/summary.md`에서 5개 sample 모두 OK |
| #282/#116에서 사용할 handoff 정리 | OK | 본 보고서의 `#282/#116 Handoff` 섹션 참조 |

실행한 주요 검증:

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/build-rust-macos.sh
swiftc -parse-as-library ... -o build.noindex/task293-stage3-syntax-check
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage3-overlay --page 1 samples/복학원서.hwp
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage3-samples --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp
git diff --check
```

Stage 4 보고 검증:

```bash
rg -n "#293|overlay|captureMode|overlayIncluded|webViewSnapshot|canvasDataURL|#282|#116|ChangedPixels|MeanRGBDelta" \
  mydocs/report/task_m014_293_report.md mydocs/orders/20260529.md
git diff --check
git status --short --branch
```

## #282/#116 Handoff

#282 후속 Stage에서 `복학원서.hwp`를 rhwp-studio 기준 reference로 사용할 때는 `captureMode=domComposite`, `overlayIncluded=true`를 기준으로 해석한다. 기존 `canvasDataURL` baseline은 DOM overlay가 빠진 과거 기준이므로 compositor parity 판단에 사용하지 않는다.

#116 watermark parity 작업에서는 중앙 BehindText 워터마크가 이제 studio reference에 포함된다. 따라서 이후 수치 차이는 reference capture 오류가 아니라 native renderer/compositor의 watermark opacity, image effect, z-order, placement 차이로 분리해 볼 수 있다.

권장 명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task282-after-task293 --page 1 \
  samples/복학원서.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

해석 기준:

- `복학원서.hwp`: overlay-positive reference. `domComposite`와 `overlayIncluded=true`가 기대값이다.
- `tac-img-02.hwp`: overlay 없는 canvas-only 회귀 기준. `canvasDataURL`와 `overlayIncluded=false`가 기대값이다.
- `request.hwp` 등 일부 일반 sample은 현행 detector에서 `overlayCount=1`로 잡혀 `domComposite`가 선택된다. 이는 detector 과검출 가능성을 포함하므로 수치 해석 시 capture mode를 함께 확인한다.

## 잔여 위험과 후속 작업

- `domComposite`는 현재 canvas와 `img` element를 DOM order/z-index 기준으로 합성한다. CSS transform, background-image, SVG element, blend mode 같은 복잡한 paint feature는 아직 일반화하지 않았다.
- WebKit `takeSnapshot`은 이 harness 환경에서 단색 배경만 반환하는 한계가 재확인됐다. 향후에도 WebKit snapshot 재시도보다 DOM drawable composite 보강이 현실적인 방향이다.
- 현행 overlay detector는 일부 일반 sample에서 `overlayCount=1`을 기록한다. 필요하면 detector가 실제 image overlay와 wrapper/DOM artifact를 구분하도록 후속 이슈를 등록하는 것이 좋다.
- 이번 작업은 reference capture 보정이다. native renderer/compositor, watermark opacity/effect, Quick Look/Thumbnail runtime은 수정하지 않았다.

## 작업지시자 승인 요청

#293의 구현, Stage 보고, 최종 보고서 작성, 오늘할일 완료 처리를 완료했다. PR 게시 전 최종 승인 요청한다.
