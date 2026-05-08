# Task M010 #134 Stage 9 보고서

## 단계 목표

현재 WKWebView HostApp에서 안정적으로 매핑 가능한 파일 계열 단축키를 네이티브 브리지로 연결한다.

## 적용 범위

이번 단계는 브라우저 API와 macOS 앱 API의 경계에 걸려 WKWebView에서 깨지는 명령만 우선 처리한다.

- `Command/Ctrl+O`: HostApp 문서 열기 panel
- `Command/Ctrl+S`: `rhwp-studio` `exportHwp` bytes 기반 HostApp 저장 panel
- `Command/Ctrl+P`: `rhwp-studio` page SVG 기반 HostApp 인쇄 panel

한국어 입력 상태에서도 물리 키 기준으로 동작하도록 `KeyboardEvent.code`를 우선 사용하고, `event.key`의 영문/한글 값도 fallback으로 처리한다.

## 제외 범위

- disabled command는 단축키만 연결해도 실행할 기능이 없으므로 제외한다.
- 편집/서식/보기 명령 중 `rhwp-studio` 내부 command dispatcher가 이미 처리하는 단축키는 HostApp에서 별도 native override하지 않는다.
- `Command+Shift+S` 같은 저장 변형 명령은 아직 HostApp 정책과 UI가 없으므로 제외한다.

## 변경 내용

- `RhwpStudioHostBridgeScript`에 capture phase `keydown` handler를 추가했다.
- `Command/Ctrl+O/S/P`를 감지하면 `preventDefault`, `stopPropagation`, `stopImmediatePropagation`을 호출해 upstream 브라우저 fallback이 실행되지 않도록 막는다.
- 기존 `handleNativeCommand` 경로를 재사용해 클릭과 단축키가 같은 네이티브 command bridge를 탄다.
- `RhwpStudioNativeCommandWebView`가 AppKit `performKeyEquivalent`/`keyDown` 경로에서도 같은 명령을 실행하도록 했다.
- SwiftUI File menu의 저장/인쇄 command를 `RhwpStudioNativeCommandDispatcher`로 연결해 WKWebView focus 밖에서 들어오는 `Command+S/P`도 처리한다.
- WKWebView download/blob fallback에서 발생할 수 있는 `WebKitErrorDomain` 102, `NSURLErrorCancelled`는 사용자 오류 banner로 표시하지 않도록 필터링했다.

## 검증

```bash
git diff --check
```

결과: 성공. whitespace error 없음.

```bash
./scripts/check-no-appkit.sh
```

결과: 성공. `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 없음.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과: 성공. `rhwp-studio` asset bundle 구성 검증 통과.

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 성공. `** BUILD SUCCEEDED ** [2.313 sec]`.

```bash
/usr/bin/open -n -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/통합재정통계\(2011.10월\).hwp
```

결과: 샘플 HWP 문서를 포함한 Debug app 실행 성공.

```bash
/usr/bin/osascript ... 'key code 31 using command down'
/usr/bin/osascript ... 'key code 1 using command down'
/usr/bin/osascript ... 'key code 35 using command down'
```

결과: `Command+O`는 `HWP 문서 열기`, `Command+S`는 `HWP 문서 저장`, `Command+P`는 `프린트` panel/window를 표시함을 확인.

## 남은 확인 사항

- panel/window 표시는 smoke 확인했다. 실제 저장 파일 내용과 인쇄 출력물의 시각적 검수는 별도 QA가 필요하다.
- 전체 한글 워드프로세서 단축키 parity는 `rhwp-studio` command 구현 상태와 macOS 예약 단축키 정책을 함께 봐야 하므로 별도 작업으로 분리한다.
