# Task M010 #142 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 구현 경계에 따라 HostApp WKWebView viewer의 저장 command를 `Command+S` 즉시 저장과 `Command+Shift+S` 다른 이름으로 저장으로 분리하고, WKWebView 내부 shortcut 표기를 macOS 관례에 맞게 보정한다.

## 변경 내용

- `HostAppCommands`에 `다른 이름으로 저장...` 메뉴를 추가하고 `Command+Shift+S`를 `file:save-as`로 연결했다.
- `RhwpStudioHostBridgeScript`에 `file:save-as` native command를 추가했다.
- WKWebView injected script와 AppKit fallback key handler 모두에서 `Command+S`는 `file:save`, `Command+Shift+S`는 `file:save-as`로 분기하도록 했다.
- 기존 save panel 기반 저장 흐름을 `requestSaveAsDocument`로 분리했다.
- `file:save`는 현재 원본 문서가 `.hwp`인 경우 security-scoped URL을 다시 resolve해 즉시 저장하고, 원본 저장이 불가능하면 save panel 흐름으로 fallback하도록 했다.
- save panel 저장 성공 후 `DocumentViewerStore`의 source document, filename, recent document 목록이 새 URL 기준으로 갱신되도록 callback 경로를 추가했다.
- WKWebView 내부 DOM의 `.md-shortcut`, `.tb-split-shortcut`, shortcut 관련 `title` 표시만 `Ctrl+` -> `Command+`, `Alt+` -> `Option+`로 보정했다.
- bundled `rhwp-studio/index.html`은 직접 수정하지 않고 HostApp 주입 script에서만 override했다.

## 변경 파일

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/HostApp.swift` | `다른 이름으로 저장...` command menu 추가 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | `file:save-as` bridge, shortcut 분기, macOS shortcut label 보정 추가 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | 저장 완료 URL을 source document와 recent document로 기록하는 method 추가 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | source document 전달과 저장 완료 callback 연결 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | 즉시 저장/save-as 저장 흐름 분리, 원본 URL write, fallback 처리 |
| `mydocs/working/task_m010_142_stage2.md` | Stage 2 완료 보고서 |

## 검증 1: Debug build

실행 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task142-stage2/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [13.415 sec]
```

판단:

- HostApp, Quick Look extension, Thumbnail extension을 포함한 Debug build가 성공했다.
- 빌드 중 CoreSimulator 관련 경고가 출력됐지만 macOS app build는 완료됐다.

## 검증 2: Shared Swift AppKit/UIKit 경계

실행 명령:

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

판단:

- 이번 변경은 HostApp 영역에 한정됐고, `Sources/RhwpCoreBridge`의 AppKit/UIKit 금지 규칙을 깨지 않았다.

## 검증 3: command routing 검색

실행 명령:

```bash
rg -n "pendingSaveDestinationURL|pendingSaveDestination|file:save-as|Command\\+Shift\\+S" Sources/HostApp
```

결과:

- `file:save-as`가 HostApp command menu, injected bridge script, WebView coordinator, AppKit fallback key handler에 연결되어 있음을 확인했다.
- 기존 `pendingSaveDestinationURL`은 남아 있지 않고, 저장 대상은 `SaveDestination.source`와 `SaveDestination.selected`로 구분된다.

판단:

- `Command+S`와 `Command+Shift+S`가 서로 다른 native command로 routing되는 코드 경로가 구성됐다.
- 원본 저장 대상과 save panel 저장 대상이 같은 optional URL 하나로 섞이지 않도록 분리됐다.

## 검증 4: shortcut label 보정 범위

실행 명령:

```bash
rg -n "Ctrl\\+|Alt\\+|view:ctrl-mark|icon-ctrl-mark" Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift Sources/HostApp/Resources/rhwp-studio/index.html
```

결과:

- bundled `index.html`의 `Ctrl+`, `Alt+` 문자열은 원본 그대로 유지된다.
- HostApp 주입 script는 `.md-shortcut`, `.tb-split-shortcut`, shortcut 관련 `title`만 보정한다.
- `view:ctrl-mark`, `icon-ctrl-mark` 같은 command id/class는 변경 대상이 아니다.

판단:

- 표시 문자열 보정과 `rhwp-studio` 내부 command identifier 보존 경계가 분리되어 있다.

## 검증 5: whitespace

실행 명령:

```bash
git diff --check
```

결과:

- whitespace 오류 없음.

## 잔여 확인

- 실제 WKWebView에서 메뉴 항목이 `Command` 표기로 보이는지는 앱 실행 후 수동 smoke가 필요하다.
- `.hwp` 원본 문서에서 `Command+S`가 save panel 없이 원본 URL에 저장되는지 수동 smoke가 필요하다.
- source document가 없는 빈 WebView 또는 `.hwpx` 문서에서 `Command+S`가 save panel fallback으로 이어지는지 수동 smoke가 필요하다.

## 결론

Stage 2 구현과 Debug build 검증은 완료됐다. 다음 단계에서는 빌드된 앱을 실행해 저장 shortcut과 WKWebView 메뉴 표기를 수동으로 확인한다.
