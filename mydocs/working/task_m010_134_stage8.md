# Task M010 #134 Stage 8 보고서

## 단계 목표

수동 테스트에서 확인된 `rhwp-studio` 상단 `파일` 메뉴의 `열기`, `저장`, `인쇄` 동작 불능 원인을 분석하고, WKWebView HostApp에서 MVP 배포에 필요한 네이티브 브리지를 연결한다.

## 원인 분석

`rhwp-studio`는 일반 브라우저 환경을 기준으로 파일 명령을 구현한다. WKWebView에 정적 asset을 올려 보여주는 HostApp에서는 다음 브라우저 API가 macOS 앱 동작으로 자동 연결되지 않았다.

- `파일 > 열기`: `showOpenFilePicker` 또는 숨겨진 file input 기반 흐름은 WKWebView 안의 웹 페이지 파일 선택이다. HostApp의 `DocumentOpenPanel`과 `DocumentViewerStore`로 이어지는 네이티브 파일 열기 경로가 없었다.
- `파일 > 저장`: `showSaveFilePicker` 또는 blob download 경로는 WKWebView에서 `NSSavePanel`과 파일 쓰기로 자동 변환되지 않는다. HostApp에 `exportHwp` bytes를 받아 저장하는 브리지가 없었다.
- `파일 > 인쇄`: `window.open("", "_blank")` 후 `print()`하는 브라우저 흐름은 현재 WKWebView 설정에서 새 창 생성이 꺼져 있고, `WKUIDelegate` 새 WebView 생성이나 AppKit print operation 연결도 없었다.

따라서 메뉴 클릭 자체는 `rhwp-studio`까지 도달하더라도, 명령의 마지막 단계가 macOS 앱 기능으로 빠져나오지 못하는 구조였다.

## 변경 내용

- `RhwpStudioHostBridgeScript`를 추가해 `rhwp-studio` 문서 로드 후 `file:open`, `file:save`, `file:print` 메뉴 클릭을 캡처한다.
- `file:open`은 Swift callback으로 전달해 기존 `DocumentOpenPanel` 기반 `store.openDocument()`를 호출한다.
- `file:save`는 `rhwp-request exportHwp`로 현재 문서 bytes를 받은 뒤 `DocumentSavePanel`이 `NSSavePanel`을 띄워 `.hwp` 파일로 저장한다.
- `file:print`는 `rhwp-request pageCount/getPageSvg`로 페이지 SVG를 모은 뒤 `RhwpStudioPrintController`가 별도 WKWebView의 `printOperation`으로 AppKit 인쇄 패널을 표시한다.
- AppKit 의존은 `Sources/HostApp/Services` 안에만 두고, `Sources/RhwpCoreBridge` 경계는 유지했다.

## 검증

```bash
xcodegen generate
```

결과: 성공.

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 성공. `** BUILD SUCCEEDED ** [2.262 sec]`.

```bash
./scripts/check-no-appkit.sh
```

결과: 성공. `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 없음.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과: 성공. `rhwp-studio` asset bundle 구성 검증 통과.

```bash
git diff --check
```

결과: 성공. whitespace error 없음.

## 남은 확인 사항

- 현재 자동 검증은 build와 static asset, source 경계 검증 중심이다. 저장 패널과 인쇄 패널은 사용자가 실행 중인 앱에서 직접 클릭해 확인해야 한다.
- HWPX 문서는 upstream `rhwp-studio`가 직접 저장을 베타 정책으로 비활성화한다. 이번 단계는 그 정책을 우회하지 않는다.
