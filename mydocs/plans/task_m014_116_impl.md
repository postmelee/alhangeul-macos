# Task M014 #116 구현계획서

## 기준

- 이슈: #116
- 브랜치: `local/task116`
- 기준 브랜치: `origin/devel` `2b852af`
- 선행 작업: #282 PR #297 merge 완료
- core 기준: rhwp `v0.7.13`, resolved commit `b3e16ef212af81ef37d973ddb86d6816d3804642`

## 구현 목표

`samples/복학원서.hwp` 중앙 BehindText watermark가 native CoreGraphics preview에서 rhwp-studio보다 과하게 진하고 gray rectangle이 보이는 문제를 줄인다. 다만 Stage 1 기준에서 중앙 watermark payload가 이미 `bakedWatermark=true`인 PNG로 내려오는 것이 확인됐으므로, 구현은 기존 계획의 "JPEG white background transparency fallback"보다 "baked watermark에 기존 effect/brightness/contrast를 중복 적용하지 않는 gate"를 먼저 검증한다.

## Stage 구성

| Stage | 목표 | 산출물 |
|-------|------|--------|
| Stage 1 | baseline 재현과 current path inventory | `task_m014_116_stage1.md` |
| Stage 2 | baked watermark 중복 보정 방지 설계 | `task_m014_116_stage2.md` |
| Stage 3 | 최소 구현 | `CGTreeRenderer.swift` 중심 변경 |
| Stage 4 | visual diff와 회귀 smoke | `task_m014_116_stage4.md` |
| Stage 5 | 최종 보고와 PR 게시 | `task_m014_116_report.md` |

## Stage 1 결과에 따른 설계 전환

수행계획서 작성 당시의 전제:

- 중앙 watermark는 JPEG 원본에 alpha가 없어 Swift에서 white/near-white transparency fallback이 필요할 수 있다.
- upstream resolved/baked payload는 미래 release에서 내려올 것으로 보고 #296에서 중복 적용 방지를 처리한다.

Stage 1에서 확인한 현재 기준:

- 중앙 watermark overlay metadata는 `mime=image/png`, `bakedWatermark=true`다.
- 같은 image에는 여전히 `effect=grayScale`, `brightness=-50`, `contrast=70`, `watermarkPreset=custom`도 함께 남아 있다.
- `CGTreeRenderer.renderOverlayImage`는 `bakedWatermark`를 `ImageNode`로 전달하지 않고, 기존 `preparedImage` -> `adjustedImage` 경로에서 effect/brightness/contrast를 다시 적용한다.

따라서 Stage 2 설계 우선순위는 다음과 같다.

1. `RhwpPageOverlayImage.bakedWatermark == true`인 overlay image에는 Swift image adjustment를 다시 적용하지 않는 gate를 둔다.
2. `bakedWatermark == false`인 legacy/current fallback payload만 기존 effect/brightness/contrast 또는 제한된 transparency fallback 후보로 남긴다.
3. render tree fallback path에는 `bakedWatermark` 정보가 없으므로 기존 동작을 유지한다.
4. #296은 향후 upstream payload shape가 다시 바뀌거나 core dependency update가 들어올 때의 compatibility follow-up으로 남기되, 현재 v0.7.13 기준의 duplicate adjustment gate는 #116에 포함할지 승인받는다.

## 예상 코드 방향

1. `CGTreeRenderer.renderOverlayImage`에서 overlay-specific image preparation context를 분리한다.
2. `bakedWatermark=true`이면 `effect`, `brightness`, `contrast`를 무시하거나 `preparedImage`에 skip adjustment option을 전달한다.
3. crop, transform, fill/destination rect는 기존과 동일하게 유지한다.
4. 일반 render tree image path와 non-baked overlay path에는 기존 adjustment를 유지한다.

## 검증 계획

Stage 3 이후 최소 검증:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task116-after-baked-gate --page 1 \
  samples/복학원서.hwp

./scripts/preview-visual-diff-harness.sh build.noindex/task116-regression --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp

./scripts/overlay-metadata-smoke.sh build.noindex/task116-overlay-metadata --page 1 \
  samples/복학원서.hwp

xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task116 CODE_SIGNING_ALLOWED=NO build

git diff --check
```

해석 기준:

- `복학원서.hwp`의 `ChangedPercent`, `MeanRGBDelta`, native PNG 시각 결과가 개선되는지 확인한다.
- 기존 image sample에서 일반 image의 ChangedPercent가 의미 있게 악화되지 않아야 한다.
- `bakedWatermark=false`인 overlay가 생길 경우 기존 adjustment path가 유지되는지 별도 fixture가 필요하다.

## 승인 필요 사항

Stage 2로 넘어가기 전 다음 방향을 승인받는다.

1. #116의 첫 구현을 `bakedWatermark=true` overlay에 대한 중복 effect/brightness/contrast 적용 방지로 좁힌다.
2. white/near-white transparency fallback은 `bakedWatermark=false` fixture가 다시 확인될 때까지 보류한다.
3. #296은 upstream release/update compatibility 후속으로 유지하되, 현재 v0.7.13 payload의 duplicate adjustment gate는 #116에서 처리한다.

