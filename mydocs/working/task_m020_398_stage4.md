# Task M020 #398 Stage 4 완료 보고서

## 단계 목적

`복학원서.hwp`와 대표 sample에서 automation load가 실제로 reference capture contamination을 제거하는지 확인한다.

Stage 4 중간 검증에서 `복학원서.hwp`가 `ui=clean`이지만 `webViewSnapshot` dark PNG로 떨어지는 문제가 드러났다. 원인은 current `rhwp-studio`가 BehindText/InFrontOfText를 `img` DOM overlay가 아니라 sibling canvas layer로 렌더링하는데, harness의 page state probe가 target canvas 외의 canvas layer를 overlay 후보로 세지 않았기 때문이다.

이 단계에서 page state probe를 한 줄 보정해 target canvas와 겹치는 sibling canvas layer도 overlay 후보로 세도록 했다. 기존 `domComposite` exporter는 이미 intersecting canvas/img를 합성하므로 exporter 자체는 변경하지 않았다.

## 산출물

| 파일/경로 | 내용 |
|-----------|------|
| `scripts/preview_visual_diff_harness.swift` | sibling canvas layer overlay counting 보정 |
| `build.noindex/task398-automation-load/` | `복학원서.hwp`, `request.hwp` target smoke 산출물 |
| `build.noindex/task398-automation-load-ktx/` | `KTX.hwp` optional quick-suite smoke 산출물 |
| `mydocs/working/task_m020_398_stage4.md` | Stage 4 완료 보고서 |
| `mydocs/orders/20260629.md` | #398 상태를 Stage 4 승인 대기로 갱신 |

변경량:

```text
scripts/preview_visual_diff_harness.swift | 2 +-
1 file changed, 1 insertion(+), 1 deletion(-)
```

현재 Swift 파일 라인 수:

```text
2634 scripts/preview_visual_diff_harness.swift
```

## 구현 보정

기존 page state probe는 overlay 후보를 셀 때 `canvas` 태그를 제외했다.

```javascript
if (element === target || element.tagName.toLowerCase() === 'canvas') {
  continue;
}
```

현재 bundled `rhwp-studio`는 page background/behind/front layer를 sibling canvas로 만든다. 따라서 target canvas만 보고 non-canvas DOM overlay만 세면 `복학원서.hwp`의 overlay layer를 놓치고, 첫 canvas가 blank일 때 `webViewSnapshot` fallback으로 떨어진다.

보정 후에는 target 자신만 제외하고 겹치는 sibling canvas layer를 overlay 후보로 계산한다.

```javascript
if (element === target) {
  continue;
}
```

이 변경으로 `복학원서.hwp`는 `canvasCount=4`, `overlayCount=3`, `captureMode=domComposite`, `overlayIncluded=true`로 회복됐다.

## 본문 변경 정도 / 본문 무손실 여부

제품 앱 source, renderer source, sample 문서는 변경하지 않았다. 변경 범위는 visual diff harness의 probe 로직과 작업 보고서/오늘할일 문서뿐이다.

## 검증 결과

정적 검증:

```bash
swiftc -parse scripts/preview_visual_diff_harness.swift
git diff --check
```

결과: 둘 다 출력 없이 성공.

공식 target smoke:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task398-automation-load --page 1 \
  samples/복학원서.hwp samples/basic/request.hwp
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
LAYOUT_OVERFLOW: page=0, sec=0, col=0, para=16, type=Shape, first=false, y=1087.2, bottom=1084.7, overflow=2.5px
LAYOUT_OVERFLOW: page=0, sec=0, col=0, para=16, type=Shape, first=false, y=1087.2, bottom=1084.7, overflow=2.5px
OK 복학원서.hwp: studioPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load/studio/복학원서.hwp-page1-studio.png nativePNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load/native/복학원서.hwp-page1-native.png diffPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load/diff/복학원서.hwp-page1-diff.png
OK request.hwp: studioPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load/studio/request.hwp-page1-studio.png nativePNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load/native/request.hwp-page1-native.png diffPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load/diff/request.hwp-page1-diff.png
```

Optional KTX smoke:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task398-automation-load-ktx --page 1 \
  samples/basic/KTX.hwp
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
OK KTX.hwp: studioPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load-ktx/studio/KTX.hwp-page1-studio.png nativePNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load-ktx/native/KTX.hwp-page1-native.png diffPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-automation-load-ktx/diff/KTX.hwp-page1-diff.png
```

핵심 metadata:

| sample | automationLoad | captureMode | overlayIncluded | captureContaminated | modalCount | toastCount | localFontUIVisible | ChangedPercent |
|--------|----------------|-------------|------------------|---------------------|------------|------------|--------------------|----------------|
| `복학원서.hwp` | `true` | `domComposite` | `true` | `false` | `0` | `0` | `false` | `7.2888%` |
| `request.hwp` | `true` | `domComposite` | `true` | `false` | `0` | `0` | `false` | `17.6908%` |
| `KTX.hwp` | `true` | `domComposite` | `true` | `false` | `0` | `0` | `false` | `30.8921%` |

검증 grep:

```bash
rg -n "captureMode|overlayIncluded|automationLoad|captureContaminated|modalCount|toastCount|localFontUIVisible|복학원서|request" \
  build.noindex/task398-automation-load
rg -n "captureMode|overlayIncluded|automationLoad|captureContaminated|modalCount|toastCount|localFontUIVisible|KTX" \
  build.noindex/task398-automation-load-ktx
```

결과: 각 `studio/*.json`에서 `automationLoad=true`, `captureContaminated=false`, `modalCount=0`, `toastCount=0`, `localFontUIVisible=false` 확인.

## 중간 실패와 해결

첫 Stage 4 smoke에서는 `복학원서.hwp`가 `captureContaminated=false`였지만 `captureMode=webViewSnapshot`, `overlayIncluded=false`, PNG가 어두운 빈 snapshot이었다. 이 상태는 local font modal contamination은 제거됐지만 reference capture가 정상 sample로 복구된 상태가 아니었다.

source 확인 결과 current `rhwp-studio`는 overlay를 sibling canvas layer로 만든다.

- `data-rhwp-overlay-page`
- `data-rhwp-layer-kind`
- `background`, `behind`, `front`

따라서 harness가 non-canvas overlay만 세면 #293의 `domComposite` 계약을 놓친다. sibling canvas layer counting 보정 뒤 `복학원서.hwp`는 `domComposite;ui=clean`으로 회복됐다.

## 완료 조건 판정

| 완료 조건 | 판정 | 근거 |
|-----------|------|------|
| `복학원서.hwp` reference capture에 로컬 글꼴 감지 UI가 섞이지 않는다 | OK | `captureContaminated=false`, `modalCount=0`, `toastCount=0`, `localFontUIVisible=false` |
| `복학원서.hwp`의 overlay-positive capture 의미가 유지된다 | OK | `captureMode=domComposite`, `overlayIncluded=true`, `overlayCount=3` |
| 대표 sample이 불필요하게 악화되지 않는다 | OK | `request.hwp`, `KTX.hwp` 모두 `OK`, `ui=clean` |
| 실패 시 renderer failure와 capture/environment failure가 구분된다 | OK | Stage 3 metadata와 Stage 4 중간 dark snapshot 기록으로 분리 가능 |

## 잔여 위험

- `request.hwp`, `KTX.hwp`도 current detector에서 sibling canvas layer 때문에 `overlayIncluded=true`가 된다. 이는 current `rhwp-studio`의 layered canvas rendering을 반영한 결과이며, 과거 문서의 “overlay 없는 sample” 표현은 더 이상 정확하지 않다.
- `복학원서.hwp`의 `LAYOUT_OVERFLOW` warning은 남아 있다. 이는 capture contamination이 아니라 renderer/layout 이력으로 #396에서 별도 해석해야 한다.
- `KTX.hwp` diff 30.8921%는 capture contamination이 아니라 renderer parity 측정값이다. #398에서는 default 전환 판단을 하지 않는다.

## 다음 단계 영향

Stage 5에서는 #398 최종 보고서와 #396 handoff를 정리한다. 핵심 handoff는 다음과 같다.

- `bokhakwonseo-capture-sentinel`은 더 이상 local font modal contamination으로 제외할 필요가 없다.
- 단, `복학원서.hwp`의 layout overflow와 renderer parity 수치는 #396에서 별도 기준으로 해석한다.
- `rhwp-studio` reference metadata의 `automationStrategy=rhwp-request`, `automationLocalFontsSeeded=true`, `captureContaminated=false`를 같이 확인해야 한다.

## 승인 요청

Stage 4는 완료했다. Stage 5 `최종 보고서와 #396 handoff`로 진행해도 되는지 승인 요청한다.
