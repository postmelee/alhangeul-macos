# Task M010 #134 Stage 12 보고서

## 목적

HostApp 상단 toolbar를 macOS viewer에 맞게 재구성하고, 작업지시자가 요청한 공유, Finder에서 보기, PDF로 내보내기, 최근 문서 기능을 추가했다.

## 변경 내용

- `ContentView` titlebar toolbar에 `공유`, `Finder에서 보기`, `PDF로 내보내기`, `최근 문서` 항목을 추가했다.
- `RecentDocumentStore`를 추가해 최근 문서를 security-scoped bookmark와 함께 `UserDefaults`에 최대 8개까지 저장한다.
- 최근 문서 기록 시 `NSDocumentController.shared.noteNewRecentDocumentURL`도 호출해 macOS 최근 문서 흐름과 맞춘다.
- `DocumentFileActions`를 추가해 현재 문서 공유와 Finder reveal을 AppKit 경로로 처리한다.
- 공유는 현재 로드된 문서 bytes를 임시 파일로 쓴 뒤 `NSSharingServicePicker`를 표시한다.
- Finder에서 보기는 원본 파일 URL을 `NSWorkspace.shared.activateFileViewerSelecting`에 전달한다.
- `DocumentPDFExportPanel`과 `RhwpStudioPDFExportController`를 추가해 현재 `rhwp-studio` page SVG payload를 WKWebView print operation의 PDF save job으로 저장한다.
- `RhwpStudioHostBridgeScript`에 `file:export-pdf` native command를 추가하고, 기존 인쇄와 PDF export가 같은 `pageCount/getPageSvg` payload 생성 helper를 사용하도록 정리했다.
- `RhwpStudioPrintHTML`을 공용 HTML renderer로 분리해 인쇄와 PDF 저장이 같은 페이지 HTML을 사용하도록 했다.
- `DocumentViewerStore`가 원본 문서 정보와 최근 문서 목록을 소유하고, toolbar action의 활성/비활성 상태를 제공하도록 확장했다.

## 검증

```bash
xcodegen generate
```

결과: 성공. `AlhangeulMac.xcodeproj`가 새 HostApp service 파일을 포함하도록 재생성됐다.

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

결과: `** BUILD SUCCEEDED ** [0.258 sec]`.

## 잔여 확인 사항

- 공유는 현재 `rhwp-studio`의 편집 중 메모리 상태가 아니라 HostApp이 로드한 문서 bytes 기준이다. 저장되지 않은 web editor 변경분까지 공유하려면 `exportHwp` payload를 공유 경로에도 연결하는 후속 작업이 필요하다.
- PDF export는 `rhwp-studio`가 반환한 page SVG를 WKWebView print operation으로 저장한다. 실제 PDF 페이지 여백과 출력 품질은 수동 QA에서 샘플별로 확인해야 한다.
