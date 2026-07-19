# Task M020 #398 Stage 3 완료 보고서

## 단계 목적

reference capture가 사용자 UI에 오염됐는지 `studio/*.json`과 `summary.md`에서 확인할 수 있게 한다.

Stage 2에서 automation load path는 동작했지만, capture 결과가 깨끗한지 판단할 metadata가 없었다. Stage 3에서는 renderer diff 수치와 capture contamination 상태를 분리해서 기록한다.

## 산출물

| 파일 | 변경 |
|------|------|
| `scripts/preview_visual_diff_harness.swift` | automation metadata, capture 전후 UI probe, contamination aggregate field, summary 힌트 추가 |
| `mydocs/working/task_m020_398_stage3.md` | Stage 3 완료 보고서 |
| `mydocs/orders/20260629.md` | #398 상태를 Stage 3 승인 대기로 갱신 |

변경량:

```text
scripts/preview_visual_diff_harness.swift | 192 +++++++++++++++++++++++++++++-
1 file changed, 191 insertions(+), 1 deletion(-)
```

현재 Swift 파일 라인 수:

```text
2634 scripts/preview_visual_diff_harness.swift
```

## 구현 내용

`StudioCaptureMetadata`에 automation load와 UI contamination 필드를 추가했다.

- `automationLoad`
- `automationStrategy`
- `automationPageCount`
- `automationFileName`
- `automationSourceFormat`
- `automationLocalFontsSeeded`
- `captureContaminated`
- `uiSuppressed`
- `modalCount`
- `toastCount`
- `localFontUIVisible`
- `contaminationText`
- `preCaptureUI`
- `postCaptureUI`

capture 직전과 직후에 DOM probe를 실행한다.

- modal 후보: `dialog`, `[role="dialog"]`, `[aria-modal="true"]`, `.modal-overlay`, `.dialog-wrap`, `.modal`, class/id에 `modal`이 포함된 요소
- toast 후보: `#rhwp-toast-container`, `.toast`, `.snackbar`, `.notification`, 관련 class/id
- local font UI text 후보: `로컬 글꼴`, `로컬 폰트`, `글꼴 감지`, `폰트 감지`, `Local Font`

동일 modal tree 안에서 overlay와 dialog가 동시에 잡히지 않도록 outermost visible element만 count한다.

`summary.md`의 기존 `StudioCapture` column에는 column을 늘리지 않고 UI 상태 힌트만 붙인다.

예:

```text
domComposite;ui=clean
```

## 본문 변경 정도 / 본문 무손실 여부

제품 앱, renderer, sample 문서는 변경하지 않았다. 변경 범위는 visual diff harness와 작업 보고서/오늘할일 문서뿐이다.

## 검증 결과

정적 검증:

```bash
swiftc -parse scripts/preview_visual_diff_harness.swift
git diff --check
```

결과: 둘 다 출력 없이 성공.

Stage 3 필드 확인:

```bash
rg -n "automationLoad|captureContaminated|modalCount|toastCount|localFontUIVisible|uiSuppressed" \
  scripts/preview_visual_diff_harness.swift build.noindex/task398-stage3-smoke/studio/request.hwp-page1-studio.json build.noindex/task398-stage3-smoke/summary.md
```

결과: Swift source와 smoke metadata에서 필드 확인.

metadata smoke:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task398-stage3-smoke --page 1 \
  samples/basic/request.hwp
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
OK request.hwp: studioPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage3-smoke/studio/request.hwp-page1-studio.png nativePNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage3-smoke/native/request.hwp-page1-native.png diffPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage3-smoke/diff/request.hwp-page1-diff.png
```

`studio/request.hwp-page1-studio.json` 핵심 값:

```json
{
  "automationLoad": true,
  "automationStrategy": "rhwp-request",
  "automationPageCount": 1,
  "automationFileName": "request.hwp",
  "automationSourceFormat": null,
  "automationLocalFontsSeeded": true,
  "captureMode": "domComposite",
  "overlayIncluded": true,
  "captureContaminated": false,
  "uiSuppressed": false,
  "modalCount": 0,
  "toastCount": 0,
  "localFontUIVisible": false,
  "contaminationText": []
}
```

`summary.md` row의 `StudioCapture` 값:

```text
domComposite;ui=clean
```

## 잔여 위험

- Stage 3는 metadata와 failure 분리 근거를 추가하는 단계다. `복학원서.hwp`와 대표 sample 전체 target smoke는 Stage 4에서 수행한다.
- `captureContaminated=true`가 되면 해당 visual diff 수치는 renderer failure가 아니라 capture failure로 해석해야 한다. 현재 Stage 3에서는 산출물을 남기기 위해 즉시 fail 처리하지 않고 metadata와 summary에 표시한다.
- `uiSuppressed`는 현재 false만 기록한다. Stage 2의 local font snapshot 주입으로 local font modal을 처음부터 막는 것이 우선이며, 실제 UI 숨김 CSS는 추가하지 않았다.
- production bundled asset은 direct global 대신 `rhwp-request` strategy를 사용한다. 이 값이 metadata에 남으므로 #396 Stage 4에서 sample 해석 시 확인할 수 있다.

## 다음 단계 영향

Stage 4에서는 다음 값을 기준으로 target smoke를 판정한다.

- `automationLoad=true`
- `captureContaminated=false`
- `modalCount=0`
- `toastCount=0`
- `localFontUIVisible=false`
- `captureMode`와 `overlayIncluded` 유지

`복학원서.hwp`의 layout warning은 capture contamination과 별도로 해석한다.

## 승인 요청

Stage 3는 완료했다. Stage 4 `target sample smoke 검증`으로 진행해도 되는지 승인 요청한다.
