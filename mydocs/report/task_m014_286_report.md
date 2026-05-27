# Task M014 #286 최종 보고서 - rhwp-studio preview visual diff harness readiness 안정화

## 작업 개요

- 이슈: #286 rhwp-studio preview visual diff harness readiness 안정화
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task286`
- 목표: #280에서 만든 `rhwp-studio` reference 기반 preview visual diff harness가 후속 #281/#282 작업과 #285 보강에서 반복 가능한 수치 비교 자료를 만들 수 있게 한다.

이번 작업은 harness 안정화와 검증 산출물 정리에 한정했다. native renderer/compositor production 동작, bundled `rhwp-studio` asset, upstream `rhwp`는 수정하지 않았다.

## 최종 결론

#286은 완료 기준을 충족했다.

- `rhwp-studio` reference PNG 생성 성공.
- native preview PNG 생성 성공.
- diff PNG 생성 성공.
- 6개 known sample에서 `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`, `MaxRGBDelta` 기록 성공.
- 실패 시 `navigation/readiness/settle/canvas export/snapshot/native render/diff` phase를 summary에서 구분할 수 있게 됨.
- Codex sandbox 내부 WebKit 실행 실패와 실제 harness readiness 문제를 분리할 수 있게 됨.
- 같은 basename을 가진 HWP/HWPX 쌍이 서로 산출물을 덮어쓰는 문제를 수정함.

핵심 결론은 다음이다.

1. #283에서 metric을 얻지 못한 직접 원인은 native renderer가 아니라 harness의 WebKit readiness 경로와 실행 환경 관측 부족이었다.
2. sandbox 밖 실행에서는 custom scheme 기반 `rhwp-studio` reference capture가 정상 동작한다.
3. sandbox 내부에서 `events=[]`, `scheme={resourceRequests=0, documentRequests=0}`가 나오면 `rhwp-studio` DOM readiness 또는 renderer 문제가 아니라 WebKit navigation 자체가 시작되지 않은 실행 환경 문제로 본다.
4. 후속 #281/#282/#116/#122/#121/#110 작업은 이번 summary format을 before/after metric 기록용으로 사용할 수 있다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `scripts/preview_visual_diff_harness.swift` | `rhwp-studio` reference capture 실패가 renderer 문제인지 WebKit 실행 환경 문제인지 구분되도록 phase-aware error, summary `Phase` column, readiness timeout detail, navigation event, scheme request stats를 추가했다. command-line WebKit harness 안정화를 위해 `NSApplication.finishLaunching()`과 offscreen window 표시를 보정했고, 같은 basename의 HWP/HWPX 입력이 산출물을 덮어쓰지 않도록 output stem에 확장자를 포함했다. |
| `mydocs/working/task_m014_286_stage1.md` | #283에서 관찰한 readiness timeout과 `WKErrorDomain Code=5` unsupported JavaScript result type을 현재 기준에서 재현하고, Stage 2 보정 범위를 정했다. |
| `mydocs/working/task_m014_286_stage2.md` | JavaScript probe와 readiness logging 보강 후 실패 형태가 `navigation=pending`으로 분리된 사실과 남은 한계를 기록했다. |
| `mydocs/working/task_m014_286_stage3.md` | sandbox 내부 WebKit navigation 미시작 문제와 sandbox 밖 정상 capture를 분리하고, 6개 sample visual diff metric을 기록했다. |
| `mydocs/report/task_m014_286_report.md` | #286 최종 결론, 수치 비교 자료, 한계, #281/#285 handoff, merge 순서 리스크를 후속 작업에서 재사용할 수 있게 정리했다. |
| `mydocs/orders/20260527.md` | 하이퍼-워터폴 추적을 위해 #286 상태를 완료로 갱신하고 완료 시각을 남겼다. |

## 단계별 결과

### Stage 1. 실패 재현

#283에서 관찰된 readiness 실패를 재현했다.

실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage1-baseline --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

결과:

| sample | 결과 | 오류 |
|--------|------|------|
| `request.hwp` | FAIL | `WKErrorDomain Code=5`, unsupported JavaScript result type |
| `hwpx-01.hwpx` | FAIL | 동일 |
| `tac-img-02.hwp` | FAIL | 동일 |
| `tac-img-02.hwpx` | FAIL | 동일 |

이 시점에는 reference PNG가 생성되지 않았고, 모든 metric은 `-`였다.

### Stage 2. phase-aware logging

readiness timeout에 다음 관측값을 추가했다.

- 실패 phase
- 마지막 page state
- 마지막 WebKit/JavaScript error
- error count
- navigation 상태
- summary `Phase` column

Stage 2 smoke에서는 `WKErrorDomain Code=5 / unsupported result type` 대신 다음 형태로 정리됐다.

```text
[phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending
```

이 결과로 Stage 1의 unsupported result type은 최종 원인이라기보다 main-frame navigation commit 전에 JS polling을 반복한 증상으로 분리됐다.

### Stage 3. metric smoke

Stage 3에서 WebKit navigation event와 custom scheme request stats를 추가했다.

sandbox 내부 실패:

```text
navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
```

sandbox 밖 실행:

```text
events=[didStartProvisional,didCommit,didFinish]
```

sandbox 밖에서는 6개 sample 모두 PASS했다.

## 최종 smoke 명령

기본 sample:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage3-basic-final --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

image-heavy sample:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage3-images-final --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

검증 산출물:

- `build.noindex/task286-stage3-basic-final/summary.md`
- `build.noindex/task286-stage3-images-final/summary.md`
- 각 directory의 `studio/`, `native/`, `diff/` PNG/JSON

## 수치 비교 자료

### 기본 sample

| sample | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|--------|---------------|----------------|--------------|-------------|---------------|---------------|----------|
| `request.hwp` | `325488/1798071` | `18.1021%` | `11.5796` | `255` | `canvasDataURL` | `coreGraphics` | `1044.8` |
| `hwpx-01.hwpx` | `540973/3562815` | `15.1839%` | `15.6722` | `255` | `canvasDataURL` | `coreGraphics` | `33.0` |

### image-heavy sample

| sample | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|--------|---------------|----------------|--------------|-------------|---------------|---------------|----------|
| `tac-img-02.hwp` | `147412/3562815` | `4.1375%` | `3.7228` | `255` | `canvasDataURL` | `coreGraphics` | `1020.9` |
| `tac-img-02.hwpx` | `129783/3562815` | `3.6427%` | `3.3924` | `255` | `canvasDataURL` | `coreGraphics` | `7.0` |
| `hwp-img-001.hwp` | `279494/3562815` | `7.8448%` | `8.2731` | `255` | `canvasDataURL` | `coreGraphics` | `17.1` |
| `img-start-001.hwp` | `514115/3561228` | `14.4365%` | `15.4773` | `255` | `canvasDataURL` | `coreGraphics` | `33.9` |

## 관찰과 얻은 점

- `WKWebView.evaluateJavaScript` 오류만 보고 있으면 readiness failure와 navigation scheduling failure가 섞인다. `didStartProvisional/didCommit/didFinish`와 scheme request count를 같이 남겨야 원인을 분리할 수 있다.
- command-line AppKit/WebKit harness에서는 `NSApplication.shared.finishLaunching()`을 명시하는 편이 안정적이다.
- hidden/offscreen WebKit capture라도 window를 실제로 front ordering해야 sandbox 밖 실행에서 navigation/capture 경로가 안정적으로 동작한다.
- `tac-img-02.hwp`와 `tac-img-02.hwpx`처럼 확장자만 다른 입력은 `deletingPathExtension().lastPathComponent` 기반 output stem을 쓰면 산출물이 충돌한다. metric artifact에는 확장자를 포함한 input filename을 stem으로 쓰는 것이 맞다.
- `ChangedPercent`가 큰 것은 harness 실패가 아니라 현재 native CoreGraphics preview와 `rhwp-studio` 기준 rendering 차이를 나타내는 측정 결과다. 이 수치가 후속 renderer/compositor 개선의 baseline이 된다.

## 한계

- 이번 metric은 `coreGraphicsOnly` native backend 기준이다. Skia opt-in backend의 수치는 별도 실행이 필요하다.
- WebKit GUI 프로세스가 필요한 harness라 Codex sandbox 내부에서 그대로 재현되지 않을 수 있다. PR/로컬 smoke에서는 sandbox 밖 실행 또는 동등한 GUI 권한이 필요하다.
- `NativeMs`는 warm-up, file format, document cache, local machine 상태에 영향을 받는다. 렌더 정확도 비교의 주 지표는 `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`, `MaxRGBDelta`로 본다.
- `rhwp-studio` reference는 `canvasDataURL` capture 기준이다. canvas 내부 margin/editor guide 같은 reference 특성은 후속 renderer parity 해석에서 별도로 고려해야 한다.
- 이번 작업은 harness 안정화이며 실제 native renderer fidelity 개선은 하지 않았다.

## #281 handoff

#281 이후 renderer/compositor parity PR에서는 다음 순서를 권장한다.

1. 변경 전 baseline으로 `build.noindex/task281-before-*` directory에 summary를 생성한다.
2. 구현 후 `build.noindex/task281-after-*` directory에 같은 sample set을 실행한다.
3. PR 본문에 before/after `ChangedPercent`, `MeanRGBDelta`, `MaxRGBDelta`를 같은 표로 남긴다.
4. sandbox 내부에서 `events=[]`, `scheme={resourceRequests=0, documentRequests=0}`가 나오면 renderer regression으로 판정하지 않고 WebKit 실행 환경 문제로 분리한다.
5. image-heavy sample에는 같은 basename HWP/HWPX 쌍이 있으므로 확장자 포함 output stem을 유지한다.

권장 명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task281-basic-before --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task281-images-before --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

## #285 handoff

#285는 #283 조사 PR이며, 당시 visual diff metric이 readiness 문제로 누락됐다. #286 merge 후 #285 보강에는 다음 내용을 추가할 수 있다.

- #283 당시 실패 원인: reference capture 전에 readiness polling이 실패해 metric 미생성.
- #286에서 분리한 원인: Codex sandbox 내부에서는 WebKit navigation이 시작되지 않아 `navigation=pending`, `events=[]`, `scheme={resourceRequests=0, documentRequests=0}`가 발생.
- #286에서 확보한 수치: 기본 2개 + image-heavy 4개 sample의 PASS metric.
- #285 보강 시 주의: #286의 harness 변경이 먼저 반영되어야 같은 summary format과 output stem을 사용할 수 있다.

merge 순서 리스크:

- #285와 #286 모두 `mydocs/orders/20260527.md` 계열을 건드렸으므로 merge 순서에 따라 문서 충돌이 날 수 있다.
- #285에 metric을 직접 추가하려면 #286 merge 후 #285 branch를 rebase/merge해서 harness 변경을 포함한 뒤 재측정하는 편이 안전하다.
- #285 PR을 먼저 merge하면 누락 metric 보강은 별도 후속 PR로 남기는 것이 낫다.

## 검증 요약

실행한 검증:

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task286-stage3-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task286-stage3-clang-module-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/FontResourceRegistry.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift \
  Sources/Shared/HwpPageImageRenderer.swift \
  scripts/preview_visual_diff_harness.swift \
  Frameworks/universal/librhwp.a \
  -framework AppKit -framework CoreGraphics -framework CoreText \
  -framework Foundation -framework ImageIO -framework UniformTypeIdentifiers \
  -framework Security -framework CoreFoundation -framework WebKit \
  -lc++ -liconv -lz \
  -o build.noindex/task286-stage3-syntax-check
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage3-basic-final --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage3-images-final --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
rg -n "ChangedPixels|ChangedPercent|MeanRGBDelta|FAIL|WKErrorDomain|unsupported|readiness timed out" \
  build.noindex/task286-stage3-basic-final/summary.md \
  build.noindex/task286-stage3-images-final/summary.md
git diff --check
```

결과:

- Swift compile 통과.
- 최종 basic smoke exit code 0.
- 최종 image-heavy smoke exit code 0.
- 최종 summary에 `FAIL`, `WKErrorDomain`, `unsupported`, `readiness timed out` 없음.
- `git diff --check` 통과.
