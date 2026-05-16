# Task M010 #134 Stage 13 보고서

## 목적

공유와 PDF 내보내기에서 web editor의 최신 상태가 반영되지 않을 수 있는 문제를 보정했다. 특히 공유는 기존 HostApp 로드 시점 bytes를 사용하지 않고, `rhwp-studio`의 현재 문서 export 결과를 공유 payload로 사용하도록 변경했다.

## 변경 내용

- `공유` toolbar action을 `DocumentViewerStore`의 원본 bytes 공유 경로에서 `RhwpStudioNativeCommandDispatcher.run("file:share")` 경로로 전환했다.
- Host bridge script에 `file:share` native command를 추가했다.
- `file:share`는 실행 직전에 active editor element의 `change` event와 `blur`를 수행하고, animation frame 2회를 기다린 뒤 `exportHwp`를 호출한다.
- `share-document` message를 추가하고, Swift `WKScriptMessageHandler`에서 export bytes를 받아 `NSSharingServicePicker`로 전달한다.
- 기존 `shareCurrentDocument()` 원본 bytes fallback을 제거해 stale document bytes 공유 경로를 없앴다.
- `file:save`와 `documentPages()` 앞에도 같은 `settleEditorState()`를 적용해 저장, 인쇄, PDF 내보내기 모두 editor focus/입력 상태를 정리한 뒤 export 또는 page snapshot을 만든다.

## 동작 기준

- 공유는 원본 파일이 아니라 `rhwp-studio`의 현재 `exportHwp` 결과를 임시 파일로 만든 뒤 macOS 공유 picker에 전달한다.
- PDF 내보내기는 HWP/HWPX 원본 파일을 먼저 저장하지 않는다. 대신 editor 상태를 settle한 뒤 현재 page SVG snapshot을 받아 PDF save job으로 저장한다.
- Finder에서 보기는 원본 파일 위치 표시 기능이므로 저장/내보내기와 연결하지 않았다.

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

결과: `** BUILD SUCCEEDED ** [2.016 sec]`.

## 잔여 확인 사항

- `settleEditorState()`는 WebKit focus/blur와 animation frame 기준의 최소 동기화다. IME 조합 중인 글자까지 100% 보장하려면 upstream `rhwp-studio`에 explicit commit/flush API를 추가하는 후속 작업이 더 정확하다.
- 공유 파일명은 현재 viewer 상태바의 파일명을 따른다. HWPX 입력에서 `exportHwp`가 허용되는 경우 확장자 정책은 별도 UX 결정이 필요하다.
