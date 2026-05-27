# Task M014 #286 Stage 3 보고서 - harness metric smoke 검증

## 단계 개요

- 이슈: #286 rhwp-studio preview visual diff harness readiness 안정화
- 단계: Stage 3. known sample smoke와 metric 생성 검증
- 목표: `rhwp-studio` reference PNG, native preview PNG, diff PNG와 visual diff metric을 known sample set에서 반복 생성할 수 있는지 확인한다.

Stage 2에서 `navigation=pending`으로 좁혀진 문제를 Stage 3에서 계속 추적했다. 결론부터 말하면 Codex sandbox 내부 실행에서는 WebKit navigation 자체가 시작되지 않았고, sandbox 밖 실행에서는 custom scheme 경로가 정상 동작했다.

## 변경 내용

`scripts/preview_visual_diff_harness.swift`에 다음을 반영했다.

| 변경 | 내용 |
|------|------|
| `NSApplication.finishLaunching()` 호출 | command-line harness에서 AppKit/WebKit 초기화를 명시 완료한다. |
| offscreen window 표시 방식 변경 | `orderBack(nil)` 대신 offscreen 위치에서 `orderFrontRegardless()`를 사용한다. |
| navigation event 기록 | 실패 시 `didStartProvisional`, `didCommit`, `didFinish`, `didFail*` 이벤트를 timeout detail에 남긴다. |
| scheme request stats 기록 | 실패 시 resource/document custom scheme request count와 요청 path/failure를 남긴다. |
| output stem 충돌 방지 | `tac-img-02.hwp`와 `tac-img-02.hwpx`처럼 basename이 같은 파일이 서로 PNG/JSON을 덮어쓰지 않도록 output stem에 확장자를 포함했다. |

## sandbox 분리 관찰

기본 sandbox 실행에서는 다음 형태로 실패했다.

```text
navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
```

동시에 WebKit 관련 sandbox extension 오류가 터미널에 출력됐다. 즉 이 경우는 `rhwp-studio` DOM readiness 문제가 아니라, WebKit navigation/request scheduling이 시작되지 않는 실행 환경 문제로 분류한다.

sandbox 밖 실행에서는 다음이 확인됐다.

- custom scheme top-level navigation 정상 시작
- `didStartProvisional`, `didCommit`, `didFinish` 발생
- `rhwp-studio` reference PNG 생성
- native PNG 생성
- diff PNG와 metric 생성

따라서 Codex/automation 환경에서 이 harness smoke는 WebKit GUI 프로세스 권한을 고려해 sandbox 밖 실행이 필요할 수 있다.

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

산출물:

- `build.noindex/task286-stage3-basic-final/summary.md`
- `build.noindex/task286-stage3-images-final/summary.md`
- 각 directory의 `studio/`, `native/`, `diff/` PNG/JSON

## 수치 결과

기본 sample:

| sample | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|--------|---------------|----------------|--------------|-------------|---------------|---------------|----------|
| `request.hwp` | `325488/1798071` | `18.1021%` | `11.5796` | `255` | `canvasDataURL` | `coreGraphics` | `1044.8` |
| `hwpx-01.hwpx` | `540973/3562815` | `15.1839%` | `15.6722` | `255` | `canvasDataURL` | `coreGraphics` | `33.0` |

image-heavy sample:

| sample | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|--------|---------------|----------------|--------------|-------------|---------------|---------------|----------|
| `tac-img-02.hwp` | `147412/3562815` | `4.1375%` | `3.7228` | `255` | `canvasDataURL` | `coreGraphics` | `1020.9` |
| `tac-img-02.hwpx` | `129783/3562815` | `3.6427%` | `3.3924` | `255` | `canvasDataURL` | `coreGraphics` | `7.0` |
| `hwp-img-001.hwp` | `279494/3562815` | `7.8448%` | `8.2731` | `255` | `canvasDataURL` | `coreGraphics` | `17.1` |
| `img-start-001.hwp` | `514115/3561228` | `14.4365%` | `15.4773` | `255` | `canvasDataURL` | `coreGraphics` | `33.9` |

## 검증 결과

실행:

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
```

결과:

- Swift harness 컴파일 통과.
- 기본 sample 2개 PASS.
- image-heavy sample 4개 PASS.
- 최종 summary에서 `FAIL`, `WKErrorDomain`, `unsupported`, `readiness timed out` 없음.
- 같은 basename의 HWP/HWPX 쌍도 별도 PNG/JSON/diff 산출물로 분리됨.

## 결론

Stage 3 완료 기준을 충족했다.

- 최소 4개 target sample 중 6개가 PASS했고 metric이 기록됐다.
- 실패 sample은 없었다.
- Codex sandbox 내부 실패와 실제 harness readiness 문제를 분리했다.
- #281 이후 PR에서 사용할 smoke command와 output directory convention을 확보했다.

## 다음 단계 영향

#281/#285 handoff에는 다음을 명시해야 한다.

1. visual diff smoke는 WebKit GUI 프로세스가 정상 동작하는 권한에서 실행해야 한다.
2. Codex sandbox 내부에서 `events=[]`, `scheme={resourceRequests=0, documentRequests=0}` 형태가 나오면 renderer 차이가 아니라 실행 환경 문제로 본다.
3. `build.noindex/task286-stage3-basic-final`과 `build.noindex/task286-stage3-images-final`의 summary format을 #281 이후 PR의 before/after metric template으로 재사용한다.
4. 기존 #285 보강 시에는 #283의 누락 metric으로 기본 2개와 image-heavy 4개 수치를 인용할 수 있다.
