# Task M020 #398 Stage 2 완료 보고서

## 단계 목적

`preview_visual_diff_harness.swift`의 `StudioReferenceRenderer`가 `rhwp-studio` 일반 `?url=` 문서 로드 URL을 거치지 않고, 앱 shell 로드 후 automation JavaScript로 문서 bytes를 주입하도록 변경한다.

기존 `domComposite` / `webViewSnapshot` / `canvasDataURL` capture decision은 유지한다.

## 산출물

| 파일 | 변경 |
|------|------|
| `scripts/preview_visual_diff_harness.swift` | automation app URL, runtime readiness, document load JS, local font modal 방지용 harness-local snapshot 주입 추가 |

변경량:

```text
scripts/preview_visual_diff_harness.swift | 340 +++++++++++++++++++++++++++++-
1 file changed, 337 insertions(+), 3 deletions(-)
```

현재 파일 라인 수:

```text
2444 scripts/preview_visual_diff_harness.swift
```

## 구현 내용

- `capture`의 reference load URL을 `alhangeul-studio://app/index.html?url=...`에서 `alhangeul-studio://app/index.html`로 변경했다.
- 기존 document bytes 전달은 `StudioDocumentSchemeHandler`를 유지하고, page 안 automation JS가 `alhangeul-document://current?revision=1`을 `fetch`한다.
- `waitForAutomationRuntime(timeout:)`를 추가해 앱 shell load 완료 후 automation readiness를 확인한다.
- `loadDocumentForAutomation(documentURL:filename:timeout:)`를 추가해 문서 load 완료와 page count를 명시적으로 확인한다.
- automation load 실패 시 기존 UI load로 조용히 fallback하지 않고 `.readiness` phase failure로 드러낸다.
- 기존 capture decision은 변경하지 않았다. `overlayCount > 0`이면 `domComposite`, canvas가 비어 있으면 `webViewSnapshot`, 그 외에는 `canvasDataURL` 흐름을 그대로 사용한다.

## 구현 중 확인한 제약과 조정

구현계획서는 upstream source 기준 `window.__wasm.loadDocument(...)`와 `window.__canvasView.loadDocument()` direct path를 우선했다. 그러나 현재 bundled production asset은 source와 달리 이 debug global을 노출하지 않았다.

따라서 Stage 2 구현은 다음 순서로 동작한다.

1. `window.__wasm`와 `window.__canvasView`가 있으면 direct global path를 사용한다.
2. production asset처럼 global이 없으면 bundled asset이 이미 제공하는 `rhwp-request` message API의 `ready` / `loadFile`를 사용한다.

`rhwp-request loadFile`는 앱 내부 `loadBytes/initDoc` 경로를 통과하므로, `복학원서.hwp`에서는 local font modal이 promise를 막았다. 이를 해결하기 위해 하네스 전용 non-persistent WKWebView의 `localStorage`에 다음 의미의 빈 snapshot을 문서 로드 직전에 주입했다.

- key: `rhwp-local-fonts`
- source: `local-font-access`
- families: `[]`

upstream logic상 이 상태는 "로컬 글꼴 전체 확인 완료, 설치 글꼴 없음"으로 해석되어 local font prompt를 띄우지 않는다. 하네스의 WKWebView는 `WKWebsiteDataStore.nonPersistent()`를 사용하므로 이 상태는 smoke 실행 바깥으로 유지되지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

제품 문서나 sample 본문은 변경하지 않았다. 변경 범위는 visual diff harness 코드와 본 보고서뿐이다.

## 검증 결과

정적 검증:

```bash
swiftc -parse scripts/preview_visual_diff_harness.swift
git diff --check
```

결과: 둘 다 출력 없이 성공.

구현 지점 확인:

```bash
rg -n "automation|__wasm|__canvasView|loadDocument|domComposite|overlayIncluded" \
  scripts/preview_visual_diff_harness.swift
```

주요 확인 지점:

```text
582:        let automationLoadInfo = try loadDocumentForAutomation(
614:            captureMode = "domComposite"
615:            overlayIncluded = true
820:                    automationReadyStartScript(),
876:    private func loadDocumentForAutomation(
1190:    private func automationReadyStartScript() -> String
1229:    private func automationLoadStartScript(documentURL: URL, filename: String) -> String
1291:              if (window.__wasm && window.__canvasView) {
1308:                const result = await postRhwpRequest('loadFile', {
```

기본 sample smoke:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task398-stage2-smoke-rpc --page 1 \
  samples/basic/request.hwp
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
OK request.hwp: studioPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage2-smoke-rpc/studio/request.hwp-page1-studio.png nativePNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage2-smoke-rpc/native/request.hwp-page1-native.png diffPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage2-smoke-rpc/diff/request.hwp-page1-diff.png
```

metadata 확인:

```text
loadURL: alhangeul-studio://app/index.html
captureMode: domComposite
overlayIncluded: true
statusText: request.hwp — 1페이지 (automation)
```

target sample smoke:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task398-stage2-smoke-bokhak --page 1 \
  samples/복학원서.hwp
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
LAYOUT_OVERFLOW: page=0, sec=0, col=0, para=16, type=Shape, first=false, y=1087.2, bottom=1084.7, overflow=2.5px
LAYOUT_OVERFLOW: page=0, sec=0, col=0, para=16, type=Shape, first=false, y=1087.2, bottom=1084.7, overflow=2.5px
OK 복학원서.hwp: studioPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage2-smoke-bokhak/studio/복학원서.hwp-page1-studio.png nativePNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage2-smoke-bokhak/native/복학원서.hwp-page1-native.png diffPNG=/Users/melee/Documents/projects/rhwp-mac/build.noindex/task398-stage2-smoke-bokhak/diff/복학원서.hwp-page1-diff.png
```

metadata 확인:

```text
loadURL: alhangeul-studio://app/index.html
captureMode: webViewSnapshot
overlayIncluded: false
statusText: 복학원서.hwp — 1페이지 (automation)
canvasCount: 4
overlayCount: 0
```

중간 실패 기록:

- sandbox 안 smoke는 기존 #390류 WebKit readiness 문제와 같은 계열로 실패했다.
- 첫 production smoke는 `window.__wasm && window.__canvasView`가 false여서 automation runtime timeout이 났다.
- `복학원서.hwp` 첫 `rhwp-request loadFile` smoke는 local font modal이 promise를 막아 document load timeout이 났다.
- 빈 complete local font snapshot 주입 뒤 `복학원서.hwp` smoke가 통과했다.

## 잔여 위험

- current bundled asset은 direct globals를 노출하지 않아 production 경로에서는 `rhwp-request loadFile`를 사용한다. 이 경로는 local font prompt는 막았지만, 앱 내부 `initDoc`의 다른 사용자-facing modal이 있는 문서에서는 추가 metadata나 별도 suppression이 필요할 수 있다.
- `복학원서.hwp` smoke에서 `LAYOUT_OVERFLOW` warning은 여전히 출력된다. 이는 capture contamination이 아니라 기존 layout 이력으로 해석해야 한다.
- Stage 2에서는 metadata field 확장을 아직 하지 않았다. `automationStrategy`, `localFontsSeeded`, `captureContaminated` 같은 값은 Stage 3에서 `studio/*.json`에 기록해야 한다.

## 다음 단계 영향

Stage 3에서는 현재 Stage 2 결과를 metadata로 관측 가능하게 만든다.

- `automationLoad`
- `automationStrategy`
- `localFontsSeeded`
- `modalCount`
- `toastCount`
- `localFontUIVisible`
- `captureContaminated`

이후 Stage 4에서 `복학원서.hwp`와 `request.hwp`를 공식 target smoke로 다시 실행하고, #396 Stage 4에서 `bokhakwonseo-capture-sentinel`을 정상 sample 후보로 돌릴 수 있는지 판단한다.

## 승인 요청

Stage 2는 완료했다. Stage 3 `contamination metadata와 failure 분리`로 진행해도 되는지 승인 요청한다.
