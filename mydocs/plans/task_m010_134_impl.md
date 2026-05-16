# Issue #134 구현 계획서

## 작업명

MVP Viewer를 rhwp-studio WKWebView 기반으로 전환

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_134.md`를 기준으로 진행한다.
- 이번 작업은 `postmelee/alhangeul-macos` 저장소의 `devel-webview` 브랜치에서 진행한다.
- HostApp Viewer의 MVP 표시 경로만 WKWebView 기반으로 전환한다.
- Quick Look preview와 Finder Thumbnail extension은 기존 `Shared`/`RhwpCoreBridge` native render 경로를 유지한다.
- `Sources/RhwpCoreBridge`에는 AppKit, WebKit, UIKit 직접 의존을 추가하지 않는다.
- `WKWebView`, `WKNavigationDelegate`, custom scheme handler, AppKit/SwiftUI bridge 코드는 `Sources/HostApp` 소유로 둔다.
- `project.yml`이 Xcode project 원본이며, `AlhangeulMac.xcodeproj`는 `xcodegen generate`로만 재생성한다.
- `rhwp-studio`는 앱 bundle에서 로드되는 정적 asset 경로를 우선한다. 개발 서버 의존은 smoke/debug 용도로만 허용한다.
- 원본 HWP/HWPX 파일은 macOS sandbox와 WKWebView 보안 모델을 고려해 Swift가 읽은 bytes 또는 scoped URL을 명시적으로 web viewer에 전달한다.
- 기존 native renderer 코드는 후속 작업을 위해 보존하고, HostApp MVP 경로에서 충돌하는 UI/store 연결만 정리한다.
- 각 단계 완료 후 단계별 완료보고서를 작성하고 작업지시자 승인 전 다음 단계로 진행하지 않는다.

## 사전 확인 요약

- 현재 HostApp은 `DocumentViewerStore`가 파일 bytes를 읽어 `RhwpDocument`를 만들고, `DocumentViewerView`/`DocumentPageView`가 페이지별 render tree를 AppKit drawing으로 표시한다.
- 현재 toolbar의 zoom control은 native page view의 `zoomScale`에 직접 연결되어 있어 WKWebView 전환 시 제거, 비활성화, 또는 web command routing 중 하나로 정리해야 한다.
- `project.yml`의 `HostApp` target은 `Sources/HostApp`, `Sources/Shared`, `Sources/RhwpCoreBridge`를 모두 포함한다. WKWebView resource 추가는 `project.yml`의 HostApp resource 설정으로 처리해야 한다.
- `edwardkim/rhwp`의 `rhwp-studio`는 Vite app이며 `package.json` 기준 build script는 `tsc && vite build`, dev server 기본 port는 `7700`이다.
- `rhwp-studio/vite.config.ts`는 `@wasm` alias를 `../pkg`로 잡고 있어, asset 확보 단계에서 WASM `pkg/` 산출물 포함 여부를 함께 확인해야 한다.

## Stage 1: HostApp viewer와 rhwp-studio 연동면 확정

대상:

- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Views/ContentView.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Views/DocumentPageView.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Services/DocumentOpenRouter.swift`
- `Sources/HostApp/Services/DocumentOpenPanel.swift`
- `project.yml`
- `Sources/README.md`
- `mydocs/tech/project_architecture.md`
- upstream `edwardkim/rhwp`의 `rhwp-studio`

작업:

- 현재 HostApp document open 흐름과 native render 흐름을 파일 단위로 정리한다.
- `rhwp-studio`의 build output, WASM `pkg/` 의존, URL parameter 로딩, file input 로딩, drag/drop 로딩, production build 차이를 확인한다.
- 문서 전달 후보를 비교한다.
  - `WKURLSchemeHandler` + `rhwp-studio` URL parameter fetch
  - Swift가 읽은 bytes를 JavaScript bridge로 전달
  - 임시 sandbox directory copy + file URL read access
- MVP 기본안을 하나로 확정한다. 우선순위는 `WKURLSchemeHandler` + URL parameter 방식이며, upstream snapshot에서 URL parameter 로딩이 production에서 불충분하면 JavaScript bridge adapter를 사용한다.
- HostApp Swift toolbar에서 native zoom control을 어떻게 처리할지 확정한다. MVP 기본안은 문서 열기만 Swift toolbar에 남기고 zoom/page UI는 `rhwp-studio` 내부 UI에 맡긴다.
- Stage 2 이후 실제 변경 파일과 검증 순서를 확정한다.

산출물:

- `mydocs/working/task_m010_134_stage1.md`

검증:

```bash
git status --short
gh issue view 134 --repo postmelee/alhangeul-macos --json number,title,state,body,labels,milestone,url
rg -n "DocumentViewerStore|DocumentViewerView|DocumentPageView|DocumentOpenRouter|RhwpDocument|zoomScale|pageTrees" Sources/HostApp Sources/Shared Sources/RhwpCoreBridge project.yml
rg -n "WKWebView|WebKit|rhwp-studio|Resources" Sources project.yml mydocs README.md
git diff --check -- mydocs/working/task_m010_134_stage1.md
```

완료 조건:

- HostApp에서 제거/대체할 native viewer 연결 지점이 단계 보고서에 정리되어 있다.
- `rhwp-studio` asset 구성과 문서 전달 방식이 구현 후보 하나로 좁혀져 있다.
- WKWebView 관련 코드가 `Sources/HostApp`에만 들어가야 한다는 경계가 확인되어 있다.

예상 커밋:

```text
Task #134 Stage 1: WKWebView viewer 연동면 확정
```

## Stage 2: rhwp-studio asset 확보와 bundle resource 파이프라인 구성

대상:

- `project.yml`
- `Sources/HostApp/Resources/rhwp-studio/`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json` 또는 provenance metadata
- 필요 시 `scripts/sync-rhwp-studio.sh`
- 필요 시 `scripts/verify-rhwp-studio-assets.sh`
- `mydocs/tech/project_architecture.md`

작업:

- Stage 1에서 확정한 upstream commit 또는 release 기준으로 `rhwp-studio` 정적 asset을 확보한다.
- Vite build 결과와 WASM `pkg/` 산출물이 앱 bundle 안에서 상대 경로로 로드되는지 확인한다.
- asset provenance metadata에 upstream repository, ref, resolved commit, build command, build time 또는 source version을 기록한다.
- HostApp target이 `rhwp-studio` resource directory를 bundle에 포함하도록 `project.yml`을 갱신한다.
- asset 검증 script를 추가하는 경우, `index.html`, JS/CSS/WASM 필수 파일 존재와 bundle copy 결과를 확인하도록 만든다.
- 개발 서버 의존 경로가 남아 있으면 production bundle 경로와 분리한다.

산출물:

- `Sources/HostApp/Resources/rhwp-studio/...`
- 필요 시 `scripts/sync-rhwp-studio.sh`
- 필요 시 `scripts/verify-rhwp-studio-assets.sh`
- `mydocs/working/task_m010_134_stage2.md`

검증:

```bash
test -f Sources/HostApp/Resources/rhwp-studio/index.html
find Sources/HostApp/Resources/rhwp-studio -maxdepth 3 -type f | sort | head -80
rg -n "rhwp-studio|Resources" project.yml Sources/HostApp scripts mydocs/tech/project_architecture.md
xcodegen generate
git diff --check -- project.yml Sources/HostApp/Resources scripts mydocs/working/task_m010_134_stage2.md
```

완료 조건:

- 앱 bundle에 포함할 `rhwp-studio` 정적 asset이 저장소 안에 존재한다.
- asset provenance와 재생성 방법이 단계 보고서에 기록되어 있다.
- `project.yml` 재생성이 성공한다.

예상 커밋:

```text
Task #134 Stage 2: rhwp-studio bundle asset 구성
```

## Stage 3: WKWebView wrapper와 문서 전달 브리지 구현

대상:

- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift`
- `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Services/DocumentOpenRouter.swift`
- 필요 시 `Sources/HostApp/Support/...`

작업:

- `WKWebView`를 감싸는 최소 `NSViewRepresentable`을 추가한다.
- SwiftUI가 소유하는 state는 현재 문서 URL, 표시 파일명, loading/error 상태, document revision으로 제한한다.
- `WKWebViewConfiguration`은 wrapper 생성 시점에 구성하고, custom scheme handler가 필요하면 web view 생성 전에 등록한다.
- bundle 내부 `rhwp-studio/index.html`은 `loadFileURL(_:allowingReadAccessTo:)`로 로드한다.
- 문서 bytes 전달은 Stage 1에서 확정한 방식으로 구현한다.
  - custom scheme 방식이면 `alhangeul-document://current` 같은 내부 scheme을 등록하고 Swift가 읽은 Data를 response로 제공한다.
  - JavaScript bridge 방식이면 production `rhwp-studio`가 호출 가능한 좁은 global function 또는 message contract만 사용한다.
- navigation policy는 bundle resource, 내부 document scheme, 필요한 blob/data URL 범위로 제한한다.
- 문서 전환 시 이전 document bytes와 web view load state가 남지 않도록 revision 기반 reload를 적용한다.
- 오류는 SwiftUI error state와 web navigation failure 양쪽에서 사용자에게 표시한다.

산출물:

- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift`
- `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift`
- 변경된 `DocumentViewerStore`/`DocumentOpenRouter`
- `mydocs/working/task_m010_134_stage3.md`

검증:

```bash
rg -n "WKWebView|WKWebViewConfiguration|WKURLSchemeHandler|WKNavigationDelegate|WebKit|alhangeul-document|rhwp-studio" Sources/HostApp
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check -- Sources/HostApp mydocs/working/task_m010_134_stage3.md
```

완료 조건:

- `Sources/RhwpCoreBridge`에 WebKit/AppKit 의존이 추가되지 않는다.
- HostApp Debug build가 성공한다.
- WKWebView wrapper가 bundle의 `rhwp-studio` entrypoint와 문서 전달 bridge를 구성한다.
- 문서 전환/오류 상태의 소유 경계가 단계 보고서에 정리되어 있다.

예상 커밋:

```text
Task #134 Stage 3: WKWebView 문서 전달 브리지 구현
```

## Stage 4: HostApp Viewer UI를 WKWebView 경로로 전환

대상:

- `Sources/HostApp/Views/ContentView.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Views/DocumentPageView.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Services/DocumentOpenPanel.swift`
- `Sources/HostApp/Services/DocumentOpenRouter.swift`
- `mydocs/tech/project_architecture.md`
- 필요 시 `Sources/README.md`

작업:

- `DocumentViewerView`의 문서 표시 영역을 `RhwpStudioWebView` 중심으로 교체한다.
- `DocumentPagesView`, `DocumentPageContainer`, native page cache, `pageTrees`, `RhwpDocument` 보유 상태가 HostApp MVP 경로에서 더 이상 쓰이지 않도록 정리한다.
- Quick Look/Thumbnail과 공유되는 `Sources/Shared`, `Sources/RhwpCoreBridge`, `DocumentPageView`의 보존/삭제 경계를 확인한다.
- Swift toolbar는 문서 열기 중심으로 단순화한다. native `zoomScale`에 연결된 버튼과 slider는 제거하거나 `rhwp-studio` command bridge가 준비될 때까지 비활성화한다.
- 외부 파일 열기(`application(_:openFile:)`, `application(_:open:)`)와 open panel 선택 흐름이 모두 WKWebView reload로 이어지게 한다.
- 빈 문서, 로딩, 오류, 표시 중 상태가 View/Store에서 일관되게 보이도록 정리한다.
- 아키텍처 문서의 HostApp viewer 경로 설명을 WKWebView MVP 기준으로 보정하고, Quick Look/Thumbnail native 경로는 유지된다고 명시한다.

산출물:

- WKWebView 기반 HostApp viewer UI
- Native viewer 경로 보존/제거 판단 결과
- 보정된 아키텍처 문서
- `mydocs/working/task_m010_134_stage4.md`

검증:

```bash
rg -n "DocumentPageView|DocumentPagesView|pageTrees|renderPageTree|RhwpDocument|zoomScale|WKWebView|RhwpStudioWebView" Sources/HostApp Sources/Shared Sources/RhwpCoreBridge mydocs/tech/project_architecture.md
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check -- Sources mydocs/tech/project_architecture.md mydocs/working/task_m010_134_stage4.md
```

완료 조건:

- HostApp의 기본 viewer 화면이 WKWebView 기반 `rhwp-studio`를 사용한다.
- 기존 native render 경로가 Quick Look/Thumbnail에 필요한 범위 안에서만 남아 있다.
- HostApp Debug build가 성공한다.
- 사용자 문서 열기 경로가 WKWebView viewer reload로 이어진다.

예상 커밋:

```text
Task #134 Stage 4: HostApp viewer WKWebView 경로 전환
```

## Stage 5: MVP smoke 검증과 문서 정리

대상:

- `README.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/build_run_guide.md`
- 필요 시 `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/orders/20260503.md`
- `mydocs/report/task_m010_134_report.md`

작업:

- HostApp build와 resource bundle 포함 여부를 확인한다.
- HWP/HWPX 샘플 각각 최소 1개를 열어 WKWebView 기반 viewer 로딩을 확인한다.
- 자동 검증이 가능한 경우 script 또는 launch log를 남기고, 수동 확인이 필요한 부분은 실행 환경과 확인 결과를 단계 보고서에 명확히 기록한다.
- README 또는 운영 문서에서 HostApp MVP viewer 경로가 `rhwp-studio` WKWebView 기반임을 반영한다.
- Quick Look/Thumbnail은 이번 작업에서 전환하지 않았다는 범위 경계를 최종 보고서에 남긴다.
- 미실행 검증, 잔여 리스크, 후속 native renderer/PageLayerTree 작업과의 관계를 정리한다.
- 오늘할일을 완료 상태와 완료 시각으로 갱신한다.

산출물:

- `mydocs/working/task_m010_134_stage5.md`
- `mydocs/report/task_m010_134_report.md`
- 보정된 README/운영 문서
- 완료 상태의 `mydocs/orders/20260503.md`

검증:

```bash
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
find build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources -maxdepth 4 -type f | rg "rhwp-studio|index\\.html|\\.wasm$|\\.js$"
rg -n "WKWebView|rhwp-studio|HostApp viewer|Quick Look|Thumbnail" README.md mydocs/tech mydocs/manual Sources
git diff --check
git status --short
```

완료 조건:

- HostApp Debug build가 성공한다.
- app bundle 안에서 `rhwp-studio` 필수 asset이 확인된다.
- HWP/HWPX 샘플 열기 smoke 결과가 보고서에 기록되어 있다.
- 최종 보고서와 오늘할일 갱신이 완료되어 있다.

예상 커밋:

```text
Task #134 Stage 5: WKWebView viewer smoke 검증과 문서 정리
```

## 전체 완료 기준

- `devel-webview` 브랜치에서 HostApp Viewer가 `rhwp-studio` WKWebView 기반으로 동작한다.
- HostApp Debug build가 성공한다.
- `Sources/RhwpCoreBridge`에는 WebKit/AppKit/UIKit 직접 의존이 없다.
- Quick Look/Thumbnail 기존 native render 경로가 의도치 않게 전환되지 않는다.
- `rhwp-studio` asset provenance와 bundle 포함 방식이 문서화되어 있다.
- HWP/HWPX 샘플 열기 smoke 결과와 잔여 리스크가 최종 보고서에 기록되어 있다.
