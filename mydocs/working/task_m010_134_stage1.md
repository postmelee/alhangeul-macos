# Task #134 Stage 1 완료 보고서

## 단계 목적

HostApp의 현재 native viewer 흐름과 upstream `rhwp-studio`의 web viewer 로딩면을 확인하고, Stage 2 이후 구현에서 사용할 WKWebView 연동 방식과 asset pin 기준을 확정한다.

## 산출물

- `mydocs/working/task_m010_134_stage1.md`
  - HostApp native viewer 연결점 조사
  - upstream `rhwp-studio` build/loader 조사
  - 문서 전달 방식 비교와 MVP 기본안 확정
- `mydocs/orders/20260503.md`
  - #134 비고를 Stage 1 완료 보고서 승인 대기 상태로 갱신

이번 단계에서는 HostApp Swift 코드, `project.yml`, `Sources/Shared`, `Sources/RhwpCoreBridge`, upstream source asset을 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 신규 단계 보고서 1개를 추가했다.
- 오늘할일의 #134 비고 1줄만 갱신했다.
- 기존 소스와 설정 파일 본문은 수정하지 않았다.
- upstream 확인은 `/private/tmp/rhwp-upstream-task134` shallow clone으로 수행했다.

## 조사 결과

### 현재 HostApp 문서 열기 흐름

- 앱 root는 `HostApp.swift`에서 `@StateObject private var viewerStore = DocumentViewerStore()`를 만들고 `ContentView(store:)`에 주입한다.
- 앱 실행 후 `.task`에서 `DocumentOpenRouter.bindStore(viewerStore)`와 `openPendingURL()`을 호출한다.
- Finder/Open With 계열 외부 열기는 `application(_:openFile:)`, `application(_:open:)`에서 `DocumentOpenRouter.requestOpen(_:)`로 들어온다.
- `DocumentOpenRouter`는 store가 바인딩되기 전이면 `pendingURL`에 보관하고, 이후 `store.loadDocument(from:)`로 넘긴다.
- `DocumentOpenPanel`은 HWP/HWPX UTType 후보를 구성해 단일 파일 URL을 선택한다.

관련 위치:

- `Sources/HostApp/HostApp.swift:7`
- `Sources/HostApp/HostApp.swift:13`
- `Sources/HostApp/HostApp.swift:54`
- `Sources/HostApp/Services/DocumentOpenRouter.swift:4`
- `Sources/HostApp/Services/DocumentOpenPanel.swift:4`

### 현재 HostApp native render 흐름

- `DocumentViewerStore`는 `RhwpDocument?`, `pageTrees`, `zoomScale`, page cache state를 직접 소유한다.
- `loadDocument(from:)`은 security-scoped URL을 열고 `Data(contentsOf:)`로 전체 bytes를 읽은 뒤 `RhwpDocument(data:filename:)`를 생성한다.
- 초기 2페이지를 preload하고, 페이지가 나타날 때 `document.renderPageTree(at:)`를 호출해 `RenderNode`를 cache한다.
- `DocumentViewerView`는 문서가 있으면 `DocumentPagesView`를 띄우고, 각 페이지가 `DocumentPageView`로 AppKit drawing을 수행한다.
- `ContentView` toolbar와 `HostApp.swift`의 보기 command는 native `zoomScale`을 직접 조작한다.

WKWebView 전환에서 대체할 연결점:

- `DocumentViewerStore.document`, `pageTrees`, `currentPage`, `zoomScale`, page cache logic은 HostApp MVP viewer 경로에서 제거 또는 비활성화한다.
- `DocumentViewerView`의 `DocumentPagesView`/`DocumentPageContainer`는 `RhwpStudioWebView` 표시 영역으로 대체한다.
- Swift toolbar의 zoom slider/buttons와 보기 command zoom은 우선 제거하거나 비활성화하고, zoom/page 조작은 `rhwp-studio` 내부 UI에 맡긴다.
- `DocumentPageView.swift`는 HostApp에서 더 이상 호출하지 않는다. 다만 `Sources/Shared`와 `Sources/RhwpCoreBridge` native render 경로는 Quick Look/Thumbnail에서 계속 쓰므로 유지한다.

관련 위치:

- `Sources/HostApp/Stores/DocumentViewerStore.swift:6`
- `Sources/HostApp/Stores/DocumentViewerStore.swift:39`
- `Sources/HostApp/Stores/DocumentViewerStore.swift:76`
- `Sources/HostApp/Stores/DocumentViewerStore.swift:130`
- `Sources/HostApp/Views/DocumentViewerView.swift:12`
- `Sources/HostApp/Views/DocumentViewerView.swift:25`
- `Sources/HostApp/Views/DocumentViewerView.swift:43`
- `Sources/HostApp/Views/ContentView.swift:17`
- `Sources/HostApp/HostApp.swift:32`

### project.yml과 소유 경계

- `HostApp` target은 `Sources/HostApp`, `Sources/Shared`, `Sources/RhwpCoreBridge`를 모두 포함한다.
- `QLExtension`, `ThumbnailExtension`도 `Sources/Shared`, `Sources/RhwpCoreBridge`를 포함한다.
- 따라서 `WKWebView`, `WebKit`, `WKURLSchemeHandler`, navigation delegate는 `Sources/HostApp`에만 추가해야 한다.
- `project.yml`이 Xcode project 원본이므로 Stage 2 resource 추가와 Stage 3/4 source 추가는 `project.yml` 갱신 후 `xcodegen generate`로 반영한다.

관련 위치:

- `project.yml:12`
- `project.yml:15`
- `project.yml:36`
- `project.yml:55`

### upstream rhwp-studio 확인

확인한 upstream 기준:

- clone path: `/private/tmp/rhwp-upstream-task134`
- repository: `https://github.com/edwardkim/rhwp.git`
- branch snapshot: shallow clone default branch
- resolved commit: `0fb3e6758b8ad11d2f3c3849c83b914684e83863`
- commit time: `2026-05-01T08:44:11+09:00`
- commit subject: `Merge pull request #504 from edwardkim/devel`

이 commit은 현재 앱 저장소의 `rhwp-core.lock` 및 `RustBridge/Cargo.lock`이 고정한 `v0.7.9` resolved commit과 일치한다.

`rhwp-studio` build 관련:

- `rhwp-studio/package.json` version은 `0.7.9`다.
- build script는 `tsc && vite build`다.
- dev server script는 `vite`, Vite config의 server port는 `7700`이다.
- `vite.config.ts`는 `@wasm` alias를 `../pkg`로 둔다.
- PWA plugin은 WASM을 precache에서 제외하고 runtime cache로 처리한다.
- shallow clone에는 generated `pkg/`가 없었다. upstream README 기준 WASM build는 `docker compose --env-file .env.docker run --rm wasm`이며 결과는 `pkg/`에 생성된다.

관련 upstream 위치:

- `/private/tmp/rhwp-upstream-task134/rhwp-studio/package.json:3`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/package.json:6`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/vite.config.ts:12`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/vite.config.ts:18`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/vite.config.ts:47`
- `/private/tmp/rhwp-upstream-task134/docker-compose.yml:30`
- `/private/tmp/rhwp-upstream-task134/docker-compose.yml:43`

`rhwp-studio` 문서 로딩면:

- 초기화 시 `loadFromUrlParam()`을 호출한다.
- `loadFromUrlParam()`은 `?url=` query를 읽고 `fetch(fileUrl)`로 bytes를 받아 `wasm.loadDocument(data, fileName)`에 전달한다.
- `filename` query가 있으면 표시 파일명으로 사용한다.
- bytes signature로 HWP CFB, HWPX zip, HTML/error page를 구분한다.
- file input과 drag/drop은 `File.arrayBuffer()`로 bytes를 읽고 같은 `loadBytes` 경로로 들어간다.
- `postMessage` API도 존재한다. `hwpctl-load` 또는 `rhwp-request` `loadFile`로 bytes와 fileName을 전달하면 문서를 로드한다.

관련 upstream 위치:

- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/main.ts:91`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/main.ts:179`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/main.ts:221`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/main.ts:455`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/main.ts:467`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/main.ts:522`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/main.ts:589`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/main.ts:655`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/core/wasm-bridge.ts:53`
- `/private/tmp/rhwp-upstream-task134/rhwp-studio/src/core/wasm-bridge.ts:79`

## 문서 전달 방식 비교

| 후보 | 장점 | 리스크 | 판단 |
|------|------|--------|------|
| `WKURLSchemeHandler` + `?url=` | upstream `rhwp-studio`의 기존 `loadFromUrlParam()`을 거의 그대로 사용한다. Swift가 원본 파일 bytes를 소유하므로 sandbox file URL을 JS에 노출하지 않는다. 대용량 파일도 JS source string으로 직렬화하지 않는다. | custom scheme fetch가 WKWebView 보안 정책/CORS와 충돌할 수 있다. scheme handler response header와 fallback이 필요하다. | MVP 기본안 |
| Swift bytes를 JavaScript/postMessage로 전달 | upstream에 이미 `hwpctl-load`/`rhwp-request loadFile` API가 있다. custom scheme fetch가 실패할 때 fallback으로 좋다. | 큰 파일을 JS로 직렬화하면 memory/latency 비용이 크다. WKWebView `evaluateJavaScript`로 `Uint8Array`를 직접 넘기기 까다롭다. | fallback |
| 임시 sandbox directory copy + file URL | WebKit file loading model에 맞추기 쉽다. | 원본 파일 복사/정리, read access root, 파일명 충돌, 보안 범위 관리가 늘어난다. `fetch(file://...)`가 환경에 따라 제한될 수 있다. | 보류 |

## 확정안

Stage 2-4 기본 구현은 다음 방향으로 진행한다.

1. `rhwp-studio` asset은 현재 `rhwp-core.lock`과 같은 upstream commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863` 기준으로 확보한다.
2. HostApp bundle에는 `Sources/HostApp/Resources/rhwp-studio/` 하위 정적 asset을 포함한다.
3. `RhwpStudioWebView`는 bundle의 `index.html`을 `loadFileURL(_:allowingReadAccessTo:)`로 연다.
4. 문서 선택 시 Swift가 security-scoped URL에서 bytes를 읽고 `DocumentViewerStore`가 `Data`, `filename`, `documentRevision`을 보유한다.
5. WKWebView configuration에 internal scheme handler를 등록한다. scheme 이름은 Stage 3에서 최종 코드로 고정하되 후보는 `alhangeul-document`다.
6. Viewer URL은 `index.html?url=alhangeul-document://current&filename={encoded}` 형태로 구성한다.
7. scheme handler는 현재 revision의 document bytes만 응답하고, `Content-Type: application/octet-stream`, `Access-Control-Allow-Origin: *`를 포함한다.
8. custom scheme fetch가 WKWebView에서 실패하면 upstream postMessage API(`hwpctl-load` 또는 `rhwp-request/loadFile`)를 fallback으로 사용한다.
9. Swift toolbar는 MVP에서 문서 열기만 남긴다. zoom/page/search 같은 조작은 `rhwp-studio` 내부 UI를 우선 사용한다.

이 방식은 upstream `rhwp-studio`의 기존 `?url=` loader를 활용하므로 Stage 2 asset snapshot과 Stage 3 HostApp wrapper 작업을 분리할 수 있다.

## Stage 2 변경 대상 확정

Stage 2는 다음 파일/폴더를 대상으로 한다.

- `Sources/HostApp/Resources/rhwp-studio/`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- `project.yml`
- `scripts/sync-rhwp-studio.sh`
- `scripts/verify-rhwp-studio-assets.sh`
- `mydocs/working/task_m010_134_stage2.md`

Stage 2에서 확인할 핵심은 다음이다.

- `rhwp-studio`와 `pkg/`를 같은 upstream commit에서 생성했는지
- `index.html`, JS/CSS, WASM glue, `.wasm` 파일이 bundle resource로 들어갈 수 있는지
- asset provenance가 `rhwp-core.lock`의 `v0.7.9` commit과 일치하는지
- resource copy가 `project.yml`/XcodeGen 경로로 재현 가능한지

## 검증 결과

```bash
$ git status --short
```

결과: 출력 없음. Stage 1 조사 시작 시 working tree는 clean 상태였다.

```bash
$ gh issue view 134 --repo postmelee/alhangeul-macos --json number,title,state,body,labels,milestone,url
```

결과: Issue #134는 `OPEN`, title은 `MVP Viewer를 rhwp-studio WKWebView 기반으로 전환`, milestone은 `v0.1`로 확인했다.

```bash
$ rg -n "DocumentViewerStore|DocumentViewerView|DocumentPageView|DocumentOpenRouter|RhwpDocument|zoomScale|pageTrees" Sources/HostApp Sources/Shared Sources/RhwpCoreBridge project.yml
```

결과 요약:

- HostApp은 `DocumentViewerStore`, `DocumentViewerView`, `DocumentPageView`가 native viewer 경로를 형성한다.
- `Sources/Shared`와 `Sources/RhwpCoreBridge`는 Quick Look/Thumbnail과 공유되는 `RhwpDocument`/native render 경로를 계속 사용한다.
- `zoomScale`과 `pageTrees`는 HostApp native viewer 전용 연결점이다.

```bash
$ rg -n "WKWebView|WebKit|rhwp-studio|Resources" Sources project.yml mydocs README.md
```

결과 요약:

- 현재 `Sources`와 `project.yml`에는 `WKWebView`/`WebKit` 구현이 없다.
- `rhwp-studio`와 WKWebView 언급은 #134 계획 문서와 과거 계획/보고서에만 존재한다.
- 기존 `Resources` 사용은 InfoPlist localization과 sample resource 중심이다.

```bash
$ git rev-parse HEAD
```

upstream clone 결과:

```text
0fb3e6758b8ad11d2f3c3849c83b914684e83863
```

```bash
$ git log -1 --format='%H %cI %s'
```

upstream clone 결과:

```text
0fb3e6758b8ad11d2f3c3849c83b914684e83863 2026-05-01T08:44:11+09:00 Merge pull request #504 from edwardkim/devel
```

```bash
$ rg -n "edwardkim/rhwp|v0\\.7\\.9|0fb3e675|rhwp" RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
```

결과 요약:

- `RustBridge/Cargo.toml`은 `edwardkim/rhwp.git`, `tag = "v0.7.9"`를 사용한다.
- `RustBridge/Cargo.lock`의 `rhwp` source는 `tag=v0.7.9#0fb3e6758b8ad11d2f3c3849c83b914684e83863`이다.
- `rhwp-core.lock`도 같은 `v0.7.9` release tag와 resolved commit을 기록한다.

## 잔여 위험

- WKWebView에서 file URL origin의 `fetch(alhangeul-document://current)`가 CORS 또는 custom scheme policy로 실패할 수 있다. Stage 3에서 header와 fallback postMessage 경로를 함께 검증해야 한다.
- `rhwp-studio` production build가 file URL 기반 bundle loading에서 Vite asset base 문제를 보일 수 있다. Stage 2에서 `dist/index.html` asset 경로를 실제로 확인해야 한다.
- upstream PWA plugin이 service worker/runtime cache 파일을 생성할 수 있다. macOS bundle 환경에서 service worker가 필요 없거나 방해되면 Stage 2에서 PWA 산출물 포함/제외 정책을 확정해야 한다.
- WASM `pkg/`가 clone에 포함되어 있지 않으므로 Stage 2에서 Docker/wasm-pack build 또는 별도 artifact 확보가 필요하다. 네트워크 또는 Docker 환경 문제는 asset 확보 blocker로 분리해야 한다.
- Swift toolbar zoom 제거는 사용자 조작면을 `rhwp-studio` UI에 맡기는 결정이다. 후속으로 native toolbar와 web command bridge를 연결하려면 별도 단계가 필요하다.

## 다음 단계 영향

Stage 2는 계획대로 진행 가능하다.

- upstream commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863` 기준으로 `rhwp-studio`와 WASM `pkg/`를 확보한다.
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`에 repo, tag, resolved commit, build command, source path, generated file summary를 기록한다.
- `project.yml`의 HostApp resource 포함 방식을 갱신하고 `xcodegen generate`로 확인한다.
- asset 검증 script가 필요한 경우 `index.html`, JS/CSS, WASM glue, `.wasm` 존재를 검사하도록 추가한다.

## 승인 요청

Stage 1 완료를 승인하고 Stage 2 `rhwp-studio` bundle asset 구성으로 진행할지 승인 요청한다. 승인 전에는 `project.yml`, `Sources/HostApp/Resources`, `scripts`를 변경하지 않는다.
