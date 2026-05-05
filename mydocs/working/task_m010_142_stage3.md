# Task M010 #142 Stage 3 완료 보고서

## 단계 목적

Stage 2 구현 결과를 실제 Debug app에서 수동 smoke로 확인한다. 확인 중 발견된 WKWebView 파일 메뉴의 `다른 이름으로 저장...` 비활성 표시와 로딩 지연 회귀를 함께 보정한다.

## 변경 내용

- `RhwpStudioHostBridgeScript`의 `다른 이름으로 저장...` 주입 항목이 기존 `저장` 항목의 `disabled` class를 복사하지 않도록 했다.
- WebView 파일 메뉴 항목은 `mousedown` 단계에서 native command로 가로채도록 했다. rhwp-studio 메뉴는 click보다 mousedown에서 먼저 동작하므로, click만 잡으면 비활성 항목 클릭이 누락될 수 있었다.
- 메뉴를 열 때 다음 animation frame에서 host override를 한 번 다시 적용하도록 했다.
- 전역 `class`/`aria-disabled` attribute 감시는 제거했다. Stage 3 중간 검증에서 해당 감시가 초기 DOM class 변화를 과하게 처리해 WebView 로딩 타임아웃을 유발할 수 있음을 확인했다.

## 변경 파일

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | save-as 주입 항목 class, 메뉴 이벤트 처리, override 재적용 scheduling 보정 |
| `mydocs/working/task_m010_142_stage3.md` | Stage 3 완료 보고서 |
| `mydocs/orders/20260504.md` | #142 진행 상태 갱신 |

## 검증 1: Debug build

최종 검증 빌드 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task142-stage3c/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [12.153 sec]
```

판단:

- HostApp, Quick Look extension, Thumbnail extension을 포함한 Debug build가 성공했다.
- 빌드 중 CoreSimulator 관련 경고가 출력됐지만 macOS app build는 완료됐다.

## 검증 2: WebView 로딩

실행 명령:

```bash
cp samples/20250130-hongbo.hwp /private/tmp/task142-save-smoke-stage3c.hwp
/usr/bin/open -n -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/task142-stage3c/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/task142-save-smoke-stage3c.hwp
```

결과:

- `task142-save-smoke-stage3c.hwp`가 WKWebView viewer에서 정상 로딩됐다.
- accessibility tree에서 `task142-save-smoke-stage3c.hwp — 4페이지`가 확인됐다.
- toolbar/menu tooltip 표기가 `오려두기 (Command+X)`, `복사하기 (Command+C)`, `붙이기 (Command+V)`, `문자표 (Option+F10)`, `찾기 (Command+F)`, `굵게 (Command+B)` 등으로 표시됐다.

## 검증 3: WebView 파일 메뉴

확인 결과:

- WebView 파일 메뉴에 `저장 Command+S`와 `다른 이름으로 저장... Command+Shift+S`가 표시됐다.
- `다른 이름으로 저장...` 항목 클릭 시 native save panel `HWP 문서 저장`이 열렸다.
- `Command+Shift+S` 입력 시에도 같은 save panel이 열렸다.
- save panel은 검증 목적상 `취소`로 닫았다.

판단:

- WebView 내부 메뉴 클릭과 macOS shortcut 양쪽이 `file:save-as`로 연결된다.
- 기존 사용자가 보고한 "save-as 항목이 비활성/잘린 것처럼 보이는" 상태는 주입 항목 class와 메뉴 open 시점 override로 보정됐다.

## 검증 4: Command+S 즉시 저장

초기 stat:

```text
1777871135 643072 /private/tmp/task142-save-smoke-stage3c.hwp
1777080928 643072 samples/20250130-hongbo.hwp
```

Debug app에서 `Command+S`를 입력하고 5초 대기한 뒤 확인한 stat:

```text
1777871215 561664 /private/tmp/task142-save-smoke-stage3c.hwp
1777080928 643072 samples/20250130-hongbo.hwp
```

판단:

- `Command+S`는 save panel 없이 현재 source document URL에 바로 저장했다.
- smoke용 임시 파일만 변경됐고 원본 샘플 파일은 변경되지 않았다.
- rhwp-studio export/write는 즉시 stat에 반영되지 않을 수 있어 검증 시 짧게 대기했다.

## 검증 5: whitespace

실행 명령:

```bash
git diff --check
```

결과:

- whitespace 오류 없음.

## 검증 6: Shared Swift AppKit/UIKit 경계

실행 명령:

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

판단:

- 이번 변경은 HostApp injected script에 한정됐고, shared Swift code의 AppKit/UIKit 금지 규칙을 깨지 않았다.

## 결론

Stage 3 수동 smoke에서 저장 단축키 분리, macOS shortcut 표기, WebView 파일 메뉴 save-as 동작을 확인했다. 중간에 발견된 전역 attribute 감시 기반 로딩 타임아웃은 감시 범위를 제거하고 메뉴 open 시점 scheduling으로 대체해 해소했다.

Stage 3 결과를 승인하면 최종 보고서 작성과 PR 게시 단계로 진행한다.
