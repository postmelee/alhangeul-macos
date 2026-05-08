# Task M010 #134 Stage 11 보고서

## 단계 목표

HostApp 상단 chrome과 macOS File menu에서 `rhwp-studio` 내부 파일 메뉴와 중복되는 문서 열기 노출을 제거한다.

## 변경 배경

MVP viewer는 `rhwp-studio` WKWebView가 주 UI를 소유한다. 문서가 열린 상태에서는 `rhwp-studio`의 `파일 > 열기`가 HostApp native open panel로 연결되어 있으므로, HostApp titlebar toolbar와 macOS File menu의 별도 `문서 열기...` 항목은 중복이다.

## 변경 내용

- `ContentView`의 titlebar toolbar `문서 열기` 버튼을 제거했다.
- SwiftUI scene command의 `.newItem` group을 빈 group으로 대체해 macOS File menu의 HostApp `문서 열기...` 항목을 제거했다.
- 빈 문서 화면의 본문 `문서 열기` 버튼은 유지했다. 문서가 아직 로드되지 않아 `rhwp-studio` 내부 파일 메뉴가 없는 최초 실행 상태의 최소 진입 경로다.

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

결과: 성공. `** BUILD SUCCEEDED ** [2.152 sec]`.

```bash
/usr/bin/open -n -F -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/통합재정통계\(2011.10월\).hwp
/usr/bin/osascript ... 'name of menu items of menu 1 of menu bar item "파일" of menu bar 1'
```

결과: 실행 앱의 macOS File menu에서 HostApp `문서 열기...` 항목이 제거되고, `저장`, `인쇄...` 항목만 남았음을 확인.

## 후속 UI 제안

- `공유`: macOS `NSSharingServicePicker` 기반 share button. AirDrop, Mail, Messages, Notes 등 시스템 공유 확장을 한 버튼에서 제공한다.
- `Finder에서 보기`: 현재 열린 원본 파일 또는 저장된 export 파일을 Finder에서 선택 상태로 표시한다.
- `Quick Look`: 원본 문서나 export 결과를 `QLPreviewPanel`로 빠르게 확인한다.
- `최근 문서`: macOS Recent Documents와 연동해 최근 연 파일을 File menu 또는 toolbar menu로 노출한다.
- `PDF로 내보내기`: `rhwp-studio` print/export 결과를 PDF로 저장하고 공유/프린트와 이어지게 한다.
