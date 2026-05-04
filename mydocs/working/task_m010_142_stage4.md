# Task M010 #142 Stage 4 완료 보고서

## 단계 목적

`Command+S` 즉시 저장이 성공했을 때 사용자에게 저장 완료 여부를 알려 주는 최소 UI 피드백을 추가한다. 릴리즈 전 변경 범위를 줄이기 위해 native footer 복구는 이번 단계에서 제외하고, 기존 rhwp-studio status bar의 문서명 영역을 3초 동안 임시 메시지로 사용하는 방식으로 구현한다.

## 변경 내용

- 저장 성공 후 WebView status bar에 `저장 완료 HH:mm`을 3초 동안 표시한다.
- 임시 메시지가 사라지면 기존 `파일명 — N페이지` status text로 되돌린다.
- 임시 메시지 표시 중에도 이후 저장/export에서 파일명이 `저장 완료 HH:mm`으로 오염되지 않도록, bridge script가 현재 파일명을 별도 dataset에 기억하도록 했다.
- save-as 성공 후에는 저장된 URL의 `lastPathComponent`를 status 복귀 문구의 파일명으로 반영할 수 있게 했다.

## 변경 파일

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | status bar 임시 메시지 표시, 파일명 기억/복구 helper 추가 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | 저장 완료 시각 생성과 WebView status 표시 호출 추가 |
| `mydocs/working/task_m010_142_stage4.md` | Stage 4 완료 보고서 |
| `mydocs/orders/20260504.md` | #142 진행 상태 갱신 |

## 검증 1: Debug build

실행 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task142-stage4/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [11.711 sec]
```

판단:

- HostApp, Quick Look extension, Thumbnail extension을 포함한 Debug build가 성공했다.
- 빌드 중 CoreSimulator 관련 경고가 출력됐지만 macOS app build는 완료됐다.

## 검증 2: 저장 완료 status smoke

실행 명령:

```bash
cp samples/20250130-hongbo.hwp /private/tmp/task142-save-smoke-stage4.hwp
/usr/bin/open -n -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/task142-stage4/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/task142-save-smoke-stage4.hwp
```

확인 결과:

- 문서 로딩 후 하단 status는 `task142-save-smoke-stage4.hwp — 4페이지`로 표시됐다.
- `Command+S` 입력 직후 하단 status가 `저장 완료 14:54`로 바뀌었다.
- 약 3초 후 하단 status가 다시 `task142-save-smoke-stage4.hwp — 4페이지`로 복귀했다.

## 검증 3: Command+S 저장 대상

초기 stat:

```text
1777873982 643072 /private/tmp/task142-save-smoke-stage4.hwp
1777080928 643072 samples/20250130-hongbo.hwp
```

`Command+S` 후 stat:

```text
1777874040 561664 /private/tmp/task142-save-smoke-stage4.hwp
1777080928 643072 samples/20250130-hongbo.hwp
```

판단:

- `Command+S`는 save panel 없이 source document URL에 바로 저장했다.
- smoke용 임시 파일만 변경됐고 원본 샘플 파일은 변경되지 않았다.

## 검증 4: whitespace

실행 명령:

```bash
git diff --check
```

결과:

- whitespace 오류 없음.

## 검증 5: Shared Swift AppKit/UIKit 경계

실행 명령:

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

판단:

- 변경은 HostApp WebView wrapper와 injected script에 한정됐고, shared Swift code의 AppKit/UIKit 금지 규칙을 깨지 않았다.

## 후속 작업 후보

- native viewer footer를 복구해 전체 파일 경로와 마지막 저장 시각을 앱 shell에서 보여 주는 방안은 별도 이슈로 다루는 것이 좋다.
- footer의 파일 경로 클릭이 Finder reveal을 제공하면 상단 Finder 버튼 제거 여부도 함께 판단할 수 있다.

## 결론

Stage 4에서 저장 성공 피드백을 최소 범위로 추가했고, 실제 Debug app에서 `Command+S` 저장 완료 메시지와 원래 status 복귀를 확인했다. Stage 4 결과를 승인하면 최종 보고서 작성과 PR 게시 단계로 진행한다.
