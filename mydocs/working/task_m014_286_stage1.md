# Task M014 #286 Stage 1 보고서 - harness readiness 실패 재현

## 단계 개요

- 이슈: #286 rhwp-studio preview visual diff harness readiness 안정화
- 단계: Stage 1. 실패 재현과 readiness phase inventory
- 목표: #283에서 관찰된 readiness 실패가 현재 `devel` 기준에서도 재현되는지 확인하고, Stage 2에서 보정할 최소 범위를 확정한다.

이번 단계는 재현과 문서화만 수행했다. `scripts/preview_visual_diff_harness.swift`, renderer, bundled `rhwp-studio` asset은 수정하지 않았다.

## 실행 환경과 입력

baseline 실행:

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage1-baseline --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

산출물:

- `build.noindex/task286-stage1-baseline/summary.md`

`studio/`, `native/`, `diff/` directory는 생성됐지만 readiness 실패가 reference capture 전에 발생해 PNG/JSON 산출물은 생성되지 않았다.

## 재현 결과

네 샘플 모두 #283과 같은 오류로 실패했다.

| sample | 결과 | phase 판단 | 오류 |
|--------|------|------------|------|
| `samples/basic/request.hwp` | FAIL | readiness / `currentPageState` | `WKErrorDomain Code=5`, JavaScript execution returned unsupported type |
| `samples/hwpx/hwpx-01.hwpx` | FAIL | readiness / `currentPageState` | 동일 |
| `samples/tac-img-02.hwp` | FAIL | readiness / `currentPageState` | 동일 |
| `samples/tac-img-02.hwpx` | FAIL | readiness / `currentPageState` | 동일 |

`summary.md`의 FAIL row는 모두 다음 형태다.

```text
rhwp-studio page 1 readiness timed out: Error Domain=WKErrorDomain Code=5
"JavaScript execution returned a result of an unsupported type"
```

따라서 Stage 1 기준 원인은 native renderer, diff engine, PNG write 실패가 아니라 `rhwp-studio` page state polling 단계에서 발생한다.

## 현재 harness 반환 계약 inventory

| 함수 | 현재 역할 | 반환/오류 처리 | Stage 1 판단 |
|------|-----------|----------------|--------------|
| `capture(...)` | document load 후 `waitForPageReady` -> align/settle -> page state -> canvas/snapshot capture 순서 실행 | readiness를 통과해야 PNG/JSON write로 진행 | 실패는 첫 `waitForPageReady` 안에서 발생한다. |
| `waitForPageReady(...)` | timeout까지 `currentPageState` polling | `currentPageState` 오류를 `lastError`에 저장하고 timeout 후 단일 메시지로 보고 | 반복 오류 횟수, 마지막 성공 state, phase가 summary에 분리되지 않는다. |
| `currentPageState(...)` | `pageStateScript` 실행 후 JSON string decode | `value as? String` 실패 또는 JS 오류를 `PreviewHarnessError`로 보고 | 현재는 WebKit error가 그대로 상위 timeout 메시지로 들어간다. |
| `evaluateJavaScript(...)` | WKWebView `evaluateJavaScript` wrapper | callback error를 원본 `Error`로 보존 | WebKit domain/code/message를 harness phase와 함께 구조화하지 않는다. |
| `pageStateScript(...)` | DOM canvas 상태를 `JSON.stringify(...)`로 반환 | 의도상 string JSON 반환 | 실제 실행에서는 WebKit unsupported result type error가 발생한다. |
| `alignAndHideChrome(...)` | chrome hide/scroll align 후 settle flag 확인 | readiness 후 실행 | 이번 실패에서는 도달하지 않았다. |
| `canvasDataURLScript(...)` | canvas data URL export | readiness/settle 후 실행 | 이번 실패에서는 도달하지 않았다. |

## 관찰된 한계

- `summary.md`는 최종 FAIL message만 남기므로, readiness polling 중 같은 오류가 몇 번 반복됐는지 알 수 없다.
- WebKit error가 `currentPageState`에서 발생했다는 사실은 소스 흐름과 message로 추론 가능하지만, summary row에는 phase가 별도 column으로 남지 않는다.
- page state JSON이 한 번이라도 성공했는지, canvas count가 증가했는지 확인할 artifact가 없다.
- `studio` reference PNG가 생성되지 않아 `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`는 모두 `-`로 남았다.

## Stage 2 최소 보정 범위

Stage 2에서는 다음을 우선 적용한다.

1. JavaScript evaluation 오류를 `phase + domain/code/message` 형태로 감싸 summary에서 구분 가능하게 만든다.
2. `waitForPageReady`가 마지막 state, 마지막 error, error count를 함께 기록하게 한다.
3. `currentPageState`와 `canvasDataURLScript`가 예상 type이 아닐 때 Swift type description을 남긴다.
4. 가능하면 FAIL row 또는 error message에서 `navigation/readiness/settle/canvas export/snapshot/native render/diff` phase를 드러낸다.
5. unsupported result type 자체를 줄이기 위해 JS probe 반환값을 다시 확인하되, renderer/compositor 동작은 건드리지 않는다.

Stage 2의 성공 기준은 최소 기본 샘플 2개에서 PASS metric이 생성되거나, 실패하더라도 지금처럼 단일 timeout message가 아니라 phase와 원인이 분리되어 남는 것이다.

## Stage 1 검증

실행:

```bash
./scripts/verify-rhwp-studio-assets.sh
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage1-baseline --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx
sed -n '1,220p' build.noindex/task286-stage1-baseline/summary.md
rg -n "WKErrorDomain|unsupported|readiness timed out|ChangedPixels|MeanRGBDelta|FAIL|OK" \
  build.noindex/task286-stage1-baseline/summary.md
rg -n "waitForPageReady|currentPageState|evaluateJavaScript|pageStateScript|settleFlagScript|canvasDataURLScript|alignAndHideChrome" \
  scripts/preview_visual_diff_harness.swift
find build.noindex/task286-stage1-baseline -maxdepth 2 -type f \( -name '*.png' -o -name '*.json' -o -name 'summary.md' \) | sort
git diff --check
```

결과:

- `verify-rhwp-studio-assets.sh`는 통과했다.
- baseline harness는 예상대로 exit code 1로 종료됐다.
- 네 샘플 모두 readiness timeout + `WKErrorDomain Code=5` unsupported result type으로 실패했다.
- PNG/JSON 산출물은 없고 `summary.md`만 생성됐다.
- Stage 1에서는 production source 수정이 없어 `git diff --check`는 문서 작성 전 기준으로 통과했다.

## 다음 단계

Stage 2에서는 `scripts/preview_visual_diff_harness.swift`의 JavaScript evaluation error handling과 readiness logging을 보강한다. 우선 목표는 visual metric 생성이지만, sample이 계속 실패하더라도 summary에서 실패 phase와 원인이 충분히 분리되도록 만든다.
