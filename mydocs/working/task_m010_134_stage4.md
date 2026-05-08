# Task #134 Stage 4 완료 보고서

## 단계 목적

HostApp Viewer의 기본 표시 경로를 native render tree/AppKit drawing 기반 화면에서 `rhwp-studio` `WKWebView` 기반 화면으로 전환한다. MVP 출시 우선순위에 맞춰 Swift 쪽은 문서 열기와 web viewer 상태 관리만 담당하고, 페이지 표시/확대/축소/탐색 UI는 bundled `rhwp-studio`가 담당하도록 정리한다.

## 산출물

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
  - HostApp MVP viewer 경로에서 `RhwpDocument`, page cache, `pageTrees`, `currentPage`, `zoomScale` 상태 제거
  - 보안 범위 접근 안에서 원본 file bytes를 읽고 `RhwpStudioDocumentPayload`와 revision만 관리
  - WebView loading/error 상태 추가
- `Sources/HostApp/Views/DocumentViewerView.swift`
  - 문서 표시 영역을 `RhwpStudioWebView` 중심으로 교체
  - 빈 상태, 파일 읽기 loading, web viewer loading overlay, web viewer error banner 정리
  - 상태바를 파일명 + `rhwp-studio`/web loading 상태로 단순화
- `Sources/HostApp/Views/ContentView.swift`
  - Swift toolbar를 문서 열기 버튼만 남기도록 단순화
- `Sources/HostApp/HostApp.swift`
  - native `zoomScale`에 연결된 View menu 확대/축소 command 제거
- `Sources/HostApp/Views/DocumentPageView.swift`
  - HostApp MVP viewer에서 더 이상 사용하지 않아 삭제
- `AlhangeulMac.xcodeproj/project.pbxproj`
  - `xcodegen generate`로 삭제된 `DocumentPageView.swift` source reference 반영
- `Sources/README.md`
  - HostApp 역할을 `rhwp-studio` WKWebView viewer 기준으로 보정
- `mydocs/tech/project_architecture.md`
  - HostApp runtime flow를 WKWebView + internal document scheme 기준으로 갱신
  - Quick Look/Thumbnail native render 경로는 유지된다고 명시
- `mydocs/working/task_m010_134_stage4.md`
  - Stage 4 완료 보고서
- `mydocs/orders/20260503.md`
  - #134 비고를 Stage 4 승인 대기 상태로 갱신

## 본문 변경 정도 / 본문 무손실 여부

- HostApp viewer UI와 store 상태를 WKWebView MVP 경로에 맞춰 축소했다.
- `Sources/RhwpCoreBridge`, `Sources/Shared`, Quick Look/Thumbnail source는 수정하지 않았다.
- `DocumentPageView.swift`는 HostApp 전용 native page drawing view였고, Quick Look/Thumbnail 경로에서 참조하지 않아 삭제했다.
- native render tree 기반 bitmap/PDF 생성 경로는 `Sources/Shared`와 `Sources/RhwpCoreBridge`에 남아 있으며 Quick Look/Thumbnail에서 계속 사용한다.
- `Frameworks/Rhwp.xcframework`, `RustBridge/target`, `build.noindex`는 검증 중 생성된 ignored 산출물이며 커밋 대상이 아니다.

## 구현 결과

### Store 소유 상태 축소

`DocumentViewerStore`는 더 이상 HostApp viewer용 `RhwpDocument`를 만들지 않는다. 파일 열기 시 보안 범위 접근 안에서 `Data(contentsOf:)`로 bytes를 읽고, 파일명과 document revision을 포함한 `RhwpStudioDocumentPayload`를 만든다.

제거된 HostApp viewer 상태는 다음과 같다.

- `RhwpDocument?`
- `currentPage`
- `pageTrees`
- page cache eviction 상태
- `zoomScale`, `minimumZoomScale`, `maximumZoomScale`
- native page preload/render 호출

문서 열기 실패 시에는 기존처럼 SwiftUI 오류 상태를 표시하고, web viewer 내부 navigation/load 실패는 별도의 `webViewErrorMessage`로 표시한다.

### Viewer 표시 전환

`DocumentViewerView`는 문서 payload가 있으면 `RhwpStudioContainerView`를 통해 `RhwpStudioWebView`를 표시한다. `RhwpStudioWebView`의 loading/error callback은 `DocumentViewerStore`의 web viewer 상태로 연결했다.

문서 revision이 바뀌면 Stage 3에서 구현한 `RhwpStudioWebView`의 revision 기반 reload가 동작한다. 따라서 open panel 선택과 외부 파일 열기 흐름은 기존 `DocumentViewerStore.loadDocument(from:)` 진입점을 유지하면서 WKWebView reload로 이어진다.

### Swift toolbar/menu 단순화

Swift toolbar는 문서 열기 버튼만 남겼다. 기존 확대/축소 slider와 command menu는 native page renderer의 `zoomScale`에 직접 연결되어 있었으므로 제거했다. MVP의 확대/축소와 페이지 UI는 `rhwp-studio` 내부 UI가 담당한다.

### native 경로 보존 범위

이번 단계에서 삭제한 `DocumentPageView.swift`는 HostApp 전용 SwiftUI/AppKit page drawing view다. Quick Look preview와 Thumbnail extension은 이 파일을 사용하지 않고 `Sources/Shared`의 `HwpPageImageRenderer`, `HwpPreviewPDFRenderer`와 `Sources/RhwpCoreBridge`를 통해 bitmap/PDF preview를 만든다.

HostApp target은 target 구성상 아직 `Sources/Shared`, `Sources/RhwpCoreBridge`, `Rhwp.xcframework`를 포함하지만, MVP viewer 화면에서는 native render tree 경로를 호출하지 않는다. target 구성 자체 축소는 Quick Look/Thumbnail과 HostApp 공유 범위를 별도로 재검토해야 하므로 이번 단계 범위 밖으로 두었다.

## 검증 결과

```bash
$ xcodegen generate
Created project at /tmp/rhwp-mac-task134/AlhangeulMac.xcodeproj
```

결과: 성공.

```bash
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

결과: 성공. WebKit/AppKit bridge는 `Sources/HostApp`에만 있다.

```bash
$ xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [2.812 sec]
```

결과: 성공. Xcode가 CoreSimulatorService/DVT 관련 경고를 출력했지만 macOS HostApp build 자체는 성공했다.

```bash
$ test -f build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/index.html
```

결과: 성공. Debug app bundle 안에 `rhwp-studio` entrypoint가 포함되어 있다.

```bash
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task134/Sources/HostApp/Resources/rhwp-studio
```

결과: 성공.

```bash
$ rg -n "DocumentPageView|DocumentPagesView|pageTrees|renderPageTree|RhwpDocument|zoomScale|currentPage|pageCount" Sources/HostApp --glob '!**/Resources/rhwp-studio/**'
```

결과: 출력 없음. HostApp source의 native viewer 연결이 제거되었다. bundled upstream JS asset은 검색 범위에서 제외했다.

```bash
$ rg -n "DocumentPageView|DocumentPagesView|pageTrees|zoomScale|currentPage|pageCount" Sources/Shared Sources/RhwpCoreBridge mydocs/tech/project_architecture.md Sources/README.md
```

결과 요약: Quick Look/Thumbnail native 경로에서 필요한 `pageCount`와 bridge 문맥만 남아 있다.

```bash
$ git diff --check -- Sources mydocs/tech/project_architecture.md Sources/README.md mydocs/orders/20260503.md mydocs/working/task_m010_134_stage4.md
```

결과: 출력 없음. whitespace error 없음.

## 잔여 위험

- 이번 단계는 build와 source-level 전환 검증 중심이다. 실제 HWP/HWPX 샘플을 앱에서 열어 custom scheme fetch, service worker/PWA 산출물, WASM runtime 표시까지 확인하는 smoke는 Stage 5에서 수행한다.
- HostApp target은 target 구성상 `Sources/Shared`와 `Sources/RhwpCoreBridge`를 여전히 compile한다. viewer 화면은 호출하지 않지만, target 구성 축소가 필요하면 별도 작업에서 source ownership을 재설계해야 한다.
- bundled `rhwp-studio` JS에는 CDN font fallback URL이 남아 있다. MVP 표시 영향은 Stage 5 smoke에서 확인하고, 완전 offline 정책은 후속 작업으로 분리한다.
- Swift toolbar의 확대/축소 command bridge는 이번 MVP 범위에서 제거했다. 향후 native menu command와 web viewer command를 연결하려면 `rhwp-studio` message contract를 별도로 확정해야 한다.

## 다음 단계 영향

Stage 5는 실제 앱 bundle 기준 smoke 검증과 문서 정리 단계다. HWP/HWPX 샘플 열기 결과, bundle resource 확인, 최종 보고서, README/운영 문서 보정, 오늘할일 완료 처리를 수행한다.

## 승인 요청

Stage 4는 여기서 중단한다. 작업지시자 승인 후 Stage 5 `MVP smoke 검증과 문서 정리`로 진행한다.
