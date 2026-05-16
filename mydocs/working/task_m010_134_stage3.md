# Task #134 Stage 3 완료 보고서

## 단계 목적

HostApp 전용 `WKWebView` wrapper와 `rhwp-studio` 문서 전달 bridge를 구현한다. Stage 4의 UI 전환 전에 bundle entrypoint, 내부 문서 scheme, revision 기반 reload, navigation 제한 경계를 컴파일 가능한 코드로 준비한다.

## 산출물

- `Sources/HostApp/Views/RhwpStudioWebView.swift`
  - `WKWebView`를 감싸는 최소 `NSViewRepresentable`
  - `WKWebViewConfiguration` 생성 시점에 custom scheme handler 등록
  - bundle/file URL, 내부 document scheme, `about`/`blob`/`data` 범위로 navigation 제한
  - revision 기반 reload와 loading/error callback 노출
- `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift`
  - Swift가 읽은 문서 bytes, 파일명, document revision을 담는 payload
  - 내부 문서 URL route `alhangeul-document://current?revision=...`
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift`
  - bundle의 `rhwp-studio/index.html` 및 read access directory 탐색
  - `index.html?url=alhangeul-document://current...&filename=...` 진입 URL 생성
- `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift`
  - `WKURLSchemeHandler` 기반 문서 bytes 응답
  - `Content-Type: application/octet-stream`, `Access-Control-Allow-Origin: *`, `Cache-Control: no-store` 응답 header
  - revision mismatch/잘못된 URL 요청 실패 처리
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
  - 기존 native 문서 load 성공 시 같은 bytes를 `rhwpStudioDocument` payload로 보존
- `AlhangeulMac.xcodeproj/project.pbxproj`
  - `xcodegen generate`로 새 HostApp source 반영
- `mydocs/working/task_m010_134_stage3.md`
  - Stage 3 완료 보고서
- `mydocs/orders/20260503.md`
  - #134 비고를 Stage 3 승인 대기 상태로 갱신

`DocumentOpenRouter`는 기존 외부 파일 열기 흐름이 이미 `DocumentViewerStore.loadDocument(from:)`으로 모이므로 이번 단계에서 변경하지 않았다. 실제 viewer UI 교체와 toolbar 정리는 Stage 4 범위로 남겼다.

## 본문 변경 정도 / 본문 무손실 여부

- HostApp Swift 파일 4개를 추가하고 store에 WKWebView payload 상태를 추가했다.
- `Sources/RhwpCoreBridge`, `Sources/Shared`, Quick Look/Thumbnail source는 수정하지 않았다.
- 현재 화면은 아직 native `DocumentPagesView` 경로를 사용한다. Stage 3은 Stage 4 전환을 위한 bridge 준비 단계다.
- `Frameworks/Rhwp.xcframework`, `RustBridge/target`, `build.noindex`는 검증을 위해 생성된 ignored 산출물이며 커밋 대상이 아니다.

## 구현 결과

### SwiftUI/AppKit 경계

`WKWebView`는 AppKit view이므로 가장 작은 bridge 형태인 `NSViewRepresentable`을 사용했다. SwiftUI 쪽 source of truth는 `RhwpStudioDocumentPayload?`와 revision이고, AppKit/WebKit 객체는 `RhwpStudioWebView.Coordinator` 내부에만 둔다.

`RhwpStudioWebView`는 다음 callback만 SwiftUI 쪽으로 노출한다.

- `onLoadStateChange(Bool)`
- `onError(String?)`

Stage 4에서는 이 callback을 `DocumentViewerStore`의 loading/error 상태와 연결하거나, web viewer 전용 상태로 분리해 사용할 수 있다.

### 문서 전달 방식

문서 전달 기본 경로는 Stage 1 확정안대로 `WKURLSchemeHandler + rhwp-studio ?url=` 방식이다.

1. Store가 문서 bytes와 파일명, revision을 `RhwpStudioDocumentPayload`로 보존한다.
2. `RhwpStudioResourceLocator`가 bundle `index.html` URL에 다음 query를 붙인다.
   - `url=alhangeul-document://current?revision={revision}`
   - `filename={원본 파일명}`
3. `rhwp-studio`의 기존 `loadFromUrlParam()`이 `fetch(url)`을 호출한다.
4. `RhwpStudioDocumentSchemeHandler`가 현재 revision의 bytes를 `application/octet-stream`으로 응답한다.

JavaScript/postMessage fallback은 이번 단계에서 기본 경로로 켜지지 않았다. custom scheme fetch가 실제 Stage 4 runtime smoke에서 실패할 경우 upstream의 `hwpctl-load`/`rhwp-request loadFile` API를 fallback으로 연결한다.

### navigation 제한

`WKNavigationDelegate`에서 main navigation은 다음만 허용한다.

- bundle 내부 `file://.../rhwp-studio/...`
- `alhangeul-document://current`
- `about:`
- `blob:`
- `data:`

그 외 URL은 cancel하고 callback error로 전달한다. 이 정책은 rhwp-studio 내부의 외부 도움말 링크를 앱 안에서 열지 않는 보수적 MVP 기준이다.

### revision 기반 reload

`RhwpStudioWebView.Coordinator`는 마지막 load identity를 `.empty` 또는 `.document(revision)`으로 기억한다. 같은 revision으로 SwiftUI update가 반복되면 reload하지 않고, 새 document revision이 들어올 때만 `loadFileURL(_:allowingReadAccessTo:)`를 다시 호출한다.

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

결과: 성공. `WebKit` import는 `Sources/HostApp`에만 존재한다.

```bash
$ xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [2.012 sec]
```

결과: 성공. build 전 이 worktree에 `Frameworks/Rhwp.xcframework`가 없어 `./scripts/build-rust-macos.sh`를 실행해 local generated framework를 만들었다. Xcode가 CoreSimulatorService 관련 경고를 출력했지만 macOS HostApp build 자체는 성공했다.

```bash
$ test -f build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/index.html
```

결과: 성공. Debug app bundle 안에 `rhwp-studio` folder resource가 포함됨을 확인했다.

```bash
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task134/Sources/HostApp/Resources/rhwp-studio
```

결과: 성공.

```bash
$ rg -n "WKWebView|WKWebViewConfiguration|WKURLSchemeHandler|WKNavigationDelegate|WebKit|alhangeul-document|RhwpStudio" Sources/HostApp/Services Sources/HostApp/Views Sources/HostApp/Stores Sources/RhwpCoreBridge Sources/Shared project.yml
```

결과 요약:

- `WKWebView`, `WKURLSchemeHandler`, `WebKit` 사용은 `Sources/HostApp/Views`와 `Sources/HostApp/Services`에만 있다.
- `Sources/RhwpCoreBridge`, `Sources/Shared`에는 WebKit/AppKit 신규 의존이 없다.
- 내부 document scheme은 `alhangeul-document`로 고정했다.

```bash
$ git diff --check -- AlhangeulMac.xcodeproj Sources/HostApp mydocs/working/task_m010_134_stage3.md
```

결과: 출력 없음. whitespace error 없음.

## 잔여 위험

- 이번 단계는 compile/build 검증 중심이다. `RhwpStudioWebView`를 실제 viewer 화면에 붙이는 것은 Stage 4에서 수행한다.
- `WKURLSchemeHandler`를 통한 `fetch(alhangeul-document://...)` runtime 동작은 Stage 4에서 앱 실행 smoke로 확인해야 한다.
- `rhwp-studio`의 service worker/PWA 산출물이 file URL 기반 WKWebView에서 어떤 영향을 주는지는 Stage 4 runtime 확인 대상이다.
- bundled JS에는 CDN font fallback URL이 남아 있다. navigation policy는 main navigation만 제한하므로 resource request 정책이 필요하면 후속 단계에서 별도 조정한다.

## 다음 단계 영향

Stage 4는 `DocumentViewerView`의 native `DocumentPagesView` 대신 `RhwpStudioWebView(document: store.rhwpStudioDocument, ...)`를 표시하면 된다. 동시에 Swift toolbar의 native zoom/page 상태와 `DocumentViewerStore`의 native page cache를 MVP HostApp 경로에서 제거하거나 비활성화한다.

## 승인 요청

Stage 3은 여기서 중단한다. 작업지시자 승인 후 Stage 4 `HostApp Viewer UI를 WKWebView 경로로 전환`으로 진행한다.
