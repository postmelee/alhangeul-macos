# Task M014 #286 Stage 2 보고서 - readiness probe logging 보강

## 단계 개요

- 이슈: #286 rhwp-studio preview visual diff harness readiness 안정화
- 단계: Stage 2. JavaScript probe와 readiness logging 보강
- 목표: `WKWebView.evaluateJavaScript` 실패를 phase별로 분리하고, readiness timeout이 단일 메시지로만 남지 않게 한다.

이번 단계는 harness 관측성 보강에 한정했다. native renderer, compositor, bundled `rhwp-studio` asset은 수정하지 않았다.

## 변경 내용

`scripts/preview_visual_diff_harness.swift`에 다음을 반영했다.

| 변경 | 내용 |
|------|------|
| phase error type 추가 | `navigation`, `readiness`, `settle`, `canvas export`, `snapshot`, `native render`, `diff`, `unknown` phase를 `PreviewHarnessPhaseError`로 감싼다. |
| JavaScript error 설명 보강 | WebKit error를 domain/code/message 중심으로 정리하고, 예상하지 못한 JavaScript value는 Swift type과 value description을 남긴다. |
| readiness timeout 보강 | 마지막 page state, 마지막 JavaScript error, error count, navigation 상태를 timeout detail에 포함한다. |
| page state 반환 보정 | page-state probe가 복잡한 객체를 직접 반환하지 않고 `window.__alhangeulPreviewPageStateJSON`에 JSON string을 저장한 뒤 primitive 값을 반환하게 했다. |
| navigation gating 추가 | main-frame commit 전에는 page-state JavaScript를 평가하지 않는다. `didCommit` 전 timeout은 `navigation=pending`으로 분리한다. |
| summary phase column 추가 | `summary.md`에 `Phase` 컬럼을 추가해 sample별 실패 phase를 별도로 볼 수 있게 했다. |

## 검증

컴파일 검증:

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task286-stage2-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task286-stage2-clang-module-cache \
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
  -o build.noindex/task286-stage2-syntax-check
```

결과: 통과.

smoke 검증:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task286-stage2-smoke --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

결과: exit code 1. 두 샘플 모두 reference capture 전에 실패했다.

## smoke 관찰 결과

산출물:

- `build.noindex/task286-stage2-smoke/summary.md`

요약:

| sample | 결과 | phase | Stage 1 대비 변화 |
|--------|------|-------|-------------------|
| `samples/basic/request.hwp` | FAIL | readiness | `WKErrorDomain Code=5` 대신 `navigation=pending`으로 기록됨 |
| `samples/hwpx/hwpx-01.hwpx` | FAIL | readiness | 동일 |

`summary.md`의 핵심 row:

```text
| request.hwp | FAIL: [phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending | readiness | - | ... |
| hwpx-01.hwpx | FAIL: [phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending | readiness | - | ... |
```

`rg` 확인 결과 Stage 2 smoke summary에는 `WKErrorDomain`, `unsupported`가 남지 않았다. 따라서 Stage 1의 unsupported result type은 최종 원인이라기보다 main-frame navigation commit 전에 JavaScript polling을 반복한 증상으로 분리됐다.

## 결론

Stage 2 완료 기준 중 다음은 충족했다.

- Swift harness 컴파일 통과.
- FAIL row에 `Phase` 컬럼과 phase-aware error가 기록됨.
- Stage 1의 `WKErrorDomain Code=5 / unsupported result type` 형태가 summary에서 반복되지 않음.
- 실패 원인이 `readiness` 안의 `navigation=pending`으로 좁혀짐.

아직 충족하지 못한 목표:

- reference PNG 생성 실패.
- native PNG 및 diff PNG 생성 실패.
- `ChangedPixels`, `ChangedPercent`, `MeanRGBDelta`, `MaxRGBDelta` metric 생성 실패.

## 한계와 다음 단계 영향

Stage 3은 원래 known sample metric smoke가 목표였지만, Stage 2 관찰상 먼저 main-frame navigation이 commit되지 않는 이유를 해결해야 한다. 다음 단계에서 우선 조사할 후보는 다음이다.

1. `alhangeul-studio://app/index.html` main resource가 `WKURLSchemeHandler`까지 도달하는지 request count를 계측한다.
2. main resource는 도달하지만 commit되지 않는다면 response header, MIME, custom scheme 제약, WebKit hidden-window 로딩 조건을 분리한다.
3. URL query 기반 `fetch(alhangeul-document://...)` 경로가 commit 전 load를 막는지 확인한다.
4. 필요하면 bundled `rhwp-studio`의 `postMessage` 기반 `hwpctl-load` 경로를 harness capture에 쓰는 방향을 검토한다.

따라서 Stage 3은 기존 metric smoke 전에 navigation unblock 소단계를 먼저 수행하는 편이 안전하다. 이 변경은 renderer/compositor 동작 변경이 아니라 harness 안정화 범위 안에 포함된다.
