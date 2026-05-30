# Task M014 #116 최종 결과보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#116](https://github.com/postmelee/alhangeul-macos/issues/116) 복학원서.hwp JPEG 워터마크 효과/투명키 렌더링 보강 |
| 마일스톤 | M014 — v0.1.4 Native Preview/Viewer Parity |
| 브랜치 | `local/task116` |
| 기준 브랜치 | `origin/devel` `2b852af` |
| core 기준 | rhwp `v0.7.13`, resolved commit `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| 단계 수 | 5단계 |

이번 작업은 `samples/복학원서.hwp` 중앙 BehindText watermark가 native CoreGraphics preview에서 rhwp-studio보다 과하게 어둡고 gray rectangle이 더 드러나는 문제를 줄였다. 초기 이슈 본문은 `JPEG + bakedWatermark=false` 전제였지만, 최신 `v0.7.13` 기준 smoke에서 실제 payload가 `image/png + bakedWatermark=true`로 확인되어 구현 방향을 바꿨다.

최종 구현은 `bakedWatermark=true`이고 overlay JSON에 resolved bytes가 실제로 포함된 image에 한해 Swift/CoreGraphics `effect/brightness/contrast` 후처리를 생략한다. 일반 render tree image path, `bakedWatermark=false` overlay, binData fallback path는 기존 동작을 유지한다.

결과적으로 `복학원서.hwp` visual diff는 `32.0188%`에서 `7.8441%`로 줄었고, regression sample set 6개는 Stage 1 baseline과 동일한 수치를 유지했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | overlay image drawing path에서 resolved baked watermark bytes에는 image adjustment를 중복 적용하지 않도록 `preparedImage(..., applyingAdjustments:)` gate를 추가했다. |
| `mydocs/plans/task_m014_116.md` | 최초 수행계획서. 현재 일부 전제는 Stage 1에서 최신 정보로 갱신됐다. |
| `mydocs/plans/task_m014_116_impl.md` | Stage 1 결과에 따라 구현 목표를 JPEG transparency fallback에서 baked watermark 중복 보정 방지로 전환했다. |
| `mydocs/working/task_m014_116_stage1.md` | 최신 baseline, overlay metadata, native renderer path inventory를 기록했다. |
| `mydocs/working/task_m014_116_stage2.md` | 관련 이슈 재점검과 `image.source.data != nil` 조건을 포함한 skip 설계를 기록했다. |
| `mydocs/working/task_m014_116_stage3.md` | 최소 구현과 HostApp Debug build 결과를 기록했다. |
| `mydocs/working/task_m014_116_stage4.md` | visual diff 개선 수치, regression smoke, overlay metadata smoke를 기록했다. |
| `mydocs/report/task_m014_116_report.md` | 최종 결과와 handoff를 정리했다. |
| `mydocs/orders/20260530.md` | 오늘할일 진행 상태와 완료 시간을 기록했다. |

## 단계별 결과

| Stage | 커밋 | 결과 |
|-------|------|------|
| 계획 | `d24d48a` | 수행계획서와 구현계획서를 작성하고 오늘할일에 #116을 등록 |
| Stage 1 | `24b8740` | 최신 `v0.7.13` baseline에서 중앙 watermark가 `image/png`, `bakedWatermark=true`임을 확인 |
| Stage 2 | `08cff0a` | #116/#296 본문 전제 갱신 코멘트 작성, resolved baked overlay adjustment skip 조건 설계 |
| Stage 3 | `52c8e81` | `CGTreeRenderer` overlay path에 `applyingAdjustments` gate 구현, HostApp Debug build 통과 |
| Stage 4 | `673c43f` | target visual diff와 regression sample set smoke 완료 |
| Stage 5 | 현재 | 최종 보고서와 PR 게시 |

## 변경 전·후 정량 비교

### `복학원서.hwp` visual diff

| Metric | Stage 1 baseline | Stage 4 after gate | 변화 |
|--------|-----------------:|-------------------:|-----:|
| ChangedPixels | 1140771/3562815 | 279470/3562815 | -861301 |
| ChangedPercent | 32.0188% | 7.8441% | -24.1747%p |
| MeanRGBDelta | 18.2116 | 6.9643 | -11.2473 |
| NativeMs | 1168.1 | 1038.8 | -129.3ms |

해석:

- ChangedPercent 기준 약 75.5%의 changed pixel 감소가 있었다.
- MeanRGBDelta도 크게 줄어 중앙 watermark 중복 보정 제거가 실제 rhwp-studio reference parity에 유효했다.
- NativeMs 변화는 단일 smoke 관찰값이므로 성능 개선 결론으로 보지 않는다.

### Regression sample set

| Sample | Stage 1 ChangedPercent | Stage 4 ChangedPercent | Stage 1 MeanRGBDelta | Stage 4 MeanRGBDelta | 판단 |
|--------|-----------------------:|-----------------------:|---------------------:|---------------------:|------|
| `request.hwp` | 17.8542% | 17.8542% | 11.0716 | 11.0716 | 변화 없음 |
| `hwpx-01.hwpx` | 15.0285% | 15.0285% | 15.2088 | 15.2088 | 변화 없음 |
| `tac-img-02.hwp` | 4.1153% | 4.1153% | 3.6698 | 3.6698 | 변화 없음 |
| `tac-img-02.hwpx` | 4.1153% | 4.1153% | 3.6698 | 3.6698 | 변화 없음 |
| `hwp-img-001.hwp` | 7.8277% | 7.8277% | 8.1872 | 8.1872 | 변화 없음 |
| `img-start-001.hwp` | 13.9805% | 13.9805% | 13.9111 | 13.9111 | 변화 없음 |

해석:

- 변경이 target baked overlay path에만 적용되고 일반 image path에는 영향을 주지 않았다는 설계 의도와 일치한다.

## 최신 판단과 이슈 정리

작업 중 #116과 #296의 오래된 전제를 갱신하는 코멘트를 남겼다.

| 이슈 | 코멘트 | 판단 |
|------|--------|------|
| #116 | https://github.com/postmelee/alhangeul-macos/issues/116#issuecomment-4581800700 | `JPEG + bakedWatermark=false` 전제는 현재 `v0.7.13` 기준에서 맞지 않으며, 즉시 구현 범위는 baked payload 중복 보정 방지 |
| #296 | https://github.com/postmelee/alhangeul-macos/issues/296#issuecomment-4581800594 | 향후 core update compatibility follow-up으로 유지하되, 현재 duplicate adjustment gate는 #116에서 처리 |

관련 upstream 상태:

| 항목 | 판단 |
|------|------|
| edwardkim/rhwp#976 | closed. 현재 baked PNG payload 관찰의 직접 배경 |
| edwardkim/rhwp#1016 | open. resolved visual payload 일반화 이슈이나 현재 target fixture는 이미 baked PNG로 관찰됨 |
| edwardkim/rhwp#1017 | open. z-order/replay policy 축이며 이번 중복 보정 gate와 분리 |
| edwardkim/rhwp#421/#516/#535 | closed. 과거 blocker였지만 현재 직접 blocker로 보지 않음 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `복학원서.hwp` 중앙 watermark gray rectangle 감소 | OK | `ChangedPercent 32.0188% -> 7.8441%`, native PNG 시각 확인 |
| watermark tone이 rhwp-studio에 가까워짐 | OK | Stage 4 native/studio PNG 직접 확인 |
| 좌상단 로고와 하단 우측 도장 회귀 없음 | OK | target native PNG에서 양쪽 image 표시 확인 |
| 기존 image sample 회귀 없음 | OK | 6개 regression sample 수치가 Stage 1과 동일 |
| Quick Look/Thumbnail/HostApp native CoreGraphics path 공유 | OK | 변경이 shared `CGTreeRenderer` overlay path에 적용됨 |
| HostApp Debug build | OK | `** BUILD SUCCEEDED ** [11.865 sec]` |
| extension registration hygiene | OK | `Issues: none`, `Development registrations: none` |
| whitespace 검증 | OK | `git diff --check` 통과 |

실행한 주요 명령:

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
  -derivedDataPath build.noindex/DerivedData-task116-stage3 CODE_SIGNING_ALLOWED=NO build

./scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
```

Stage 4 artifact:

| Artifact | 경로 |
|----------|------|
| Studio PNG | `build.noindex/task116-after-baked-gate/studio/복학원서.hwp-page1-studio.png` |
| Native PNG | `build.noindex/task116-after-baked-gate/native/복학원서.hwp-page1-native.png` |
| Diff PNG | `build.noindex/task116-after-baked-gate/diff/복학원서.hwp-page1-diff.png` |

## 잔여 위험과 후속 작업

| 항목 | 내용 |
|------|------|
| render tree fallback | `bakedWatermark` 의미가 없으므로 기존 image adjustment를 유지한다. overlay metadata path가 없는 문서에서는 같은 개선이 적용되지 않을 수 있다. |
| binData fallback | overlay JSON bytes가 없고 `binDataId`로 원본 리소스를 읽는 경우는 baked resolved bytes라고 보장할 수 없어 기존 보정을 유지한다. |
| legacy JPEG watermark | `bakedWatermark=false`인 legacy JPEG watermark transparency fallback은 구현하지 않았다. 양성 fixture 확보 후 별도 설계가 필요하다. |
| text/font/layout parity | `복학원서.hwp` 하단 overflow, 일부 glyph fallback, text/font/layout 차이는 여전히 남아 있으며 #116 범위가 아니다. |
| upstream replay policy | edwardkim/rhwp#1017의 장기 z-order/replay policy 공통화는 별도 축이다. |

## Handoff

다음 순서:

1. #116 PR을 게시하고 review/merge한다.
2. #296은 향후 rhwp core update 시 `bakedWatermark`, MIME, resolved payload shape, z-order contract가 다시 바뀌는지 확인하는 compatibility follow-up으로 유지한다.
3. #122에서 image fill/tile/placement parity를 이어간다.
4. #121/#110은 RawSvg/OLE/chart, Placeholder/FormObject 등 남은 native renderer parity 영역으로 별도 진행한다.

이번 작업에서 알게 된 점:

- `v0.7.13` 현재 release에서도 #116/#296 작성 당시의 `JPEG + bakedWatermark=false` 전제는 이미 바뀌어 있었다.
- downstream Swift renderer는 upstream payload가 이미 visual projection을 끝낸 경우 후처리를 반복하지 않는 gate가 필요하다.
- `bakedWatermark=true`만 보지 않고 실제 resolved bytes 존재 여부까지 조건에 넣어야 binData fallback의 오탐 skip을 피할 수 있다.
- 수치 비교상 중앙 watermark 문제는 opacity/alpha heuristic보다 중복 effect/brightness/contrast 적용 문제가 컸다.

## 작업지시자 승인 요청

최종 보고서 작성과 오늘할일 완료 처리를 끝낸 뒤 `publish/task116` 원격 브랜치를 만들고 `devel` 대상 Open PR로 게시한다. PR merge 후에는 `pr-merge-cleanup` 절차로 이슈 close와 브랜치/worktree 정리를 진행한다.
