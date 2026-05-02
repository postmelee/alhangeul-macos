# Task M010 #134 최종 보고서

## 작업 요약

- 이슈: #134 MVP Viewer를 rhwp-studio WKWebView 기반으로 전환
- 마일스톤: M010 (`v0.1.0 Viewer 기반`)
- 브랜치: `devel-webview`
- 단계 수: 7
- 핵심 변경: HostApp MVP viewer를 native AppKit page renderer 경로에서 bundled `rhwp-studio` WKWebView 경로로 전환

## 단계별 진행

| Stage | Commit | 핵심 내용 |
|-------|--------|-----------|
| 시작 | `cc04cfc` | 수행계획서와 오늘할일 등록 |
| 구현 계획 | `b13faa2` | 5단계 구현계획서 작성 |
| 1 | `275e80e` | HostApp native viewer 연결점과 upstream `rhwp-studio` loader 조사, `WKURLSchemeHandler + ?url=` 방식 확정 |
| 문서 보정 | `58af4a8` | WKWebView MVP 문서와 브랜치 정책 보정 |
| 2 | `4fe722d` | `rhwp-studio` static asset bundle 구성, provenance manifest와 검증 script 추가 |
| 3 | `823e8e2` | `RhwpStudioWebView`, resource locator, internal document scheme handler 구현 |
| 4 | `59999ae` | HostApp viewer UI/store를 WKWebView 경로로 전환, native page view 제거 |
| 5 | `a25c685` | MVP smoke 검증, README/빌드 가이드/최종 보고서 정리 |
| 6 | `79bbeff` | 수동 테스트에서 확인된 `rhwp-studio` CSS/JS 미적용 문제 보정 |
| 7 | 본 커밋 | WKWebView file URL WASM fetch 문제를 custom resource scheme으로 보정 |

## 완료 내용

HostApp viewer의 기본 경로가 `rhwp-studio` WKWebView 기반으로 바뀌었다.

- 앱 bundle에 `Sources/HostApp/Resources/rhwp-studio` 정적 asset을 포함한다.
- `RhwpStudioWebView`가 `alhangeul-studio://app/index.html` entrypoint를 로드한다.
- `RhwpStudioResourceSchemeHandler`가 bundle의 `rhwp-studio` 정적 asset을 MIME type과 함께 응답한다.
- Swift가 보안 범위 접근 안에서 원본 HWP/HWPX bytes를 읽어 `RhwpStudioDocumentPayload`로 보관한다.
- `RhwpStudioDocumentSchemeHandler`가 `alhangeul-document://current?revision=...` 요청에 현재 문서 bytes를 응답한다.
- `rhwp-studio`의 기존 `?url=` loader가 내부 document URL을 fetch해 문서를 로드한다.
- Swift toolbar/menu는 문서 열기만 남기고, zoom/page UI는 `rhwp-studio` 내부 UI가 소유한다.
- HostApp 전용 native page view와 native viewer store 상태는 제거했다.
- Quick Look/Thumbnail은 기존 `Sources/Shared`/`Sources/RhwpCoreBridge` native render 경로를 유지한다.
- WKWebView file URL 환경에서 `crossorigin` subresource request가 CSS/JS 로딩을 막지 않도록 bundled `index.html`의 `crossorigin` attribute를 제거하고 sync/verify script에 재발 방지 검증을 추가했다.
- WKWebView file URL 환경에서 WASM fetch 실패가 JS 초기화를 중단하지 않도록 `rhwp-studio` asset 전체를 `alhangeul-studio://app` custom scheme으로 제공한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Resources/rhwp-studio/` | `edwardkim/rhwp` `v0.7.9` 기준 `rhwp-studio` production asset bundle |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | upstream repo/tag/resolved commit/build command/file summary provenance |
| `Sources/HostApp/Resources/rhwp-studio/index.html` | WKWebView file URL resource loading을 위해 JS/CSS `crossorigin` 제거 |
| `scripts/sync-rhwp-studio.sh` | upstream checkout에서 `rhwp-studio` asset을 동기화하고 WKWebView용 `crossorigin` 후처리와 manifest 생성 |
| `scripts/verify-rhwp-studio-assets.sh` | `rhwp-studio` entrypoint, JS/CSS/WASM, sample 제외, provenance, `crossorigin` 미포함 검증 |
| `project.yml` | HostApp target에 `Resources/rhwp-studio` folder resource 포함 |
| `AlhangeulMac.xcodeproj/project.pbxproj` | XcodeGen 재생성 결과 |
| `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift` | Swift가 읽은 문서 bytes, filename, revision payload |
| `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift` | WKWebView internal document scheme bytes response |
| `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift` | WKWebView internal resource scheme static asset response |
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | bundle `rhwp-studio/index.html` 검증과 custom scheme entrypoint URL 구성 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `WKWebView` wrapper, resource/document scheme registration, navigation policy, revision 기반 reload |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | HostApp viewer state를 web payload/loading/error 중심으로 축소 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | 표시 영역을 `RhwpStudioWebView` 중심으로 전환 |
| `Sources/HostApp/Views/ContentView.swift` | toolbar를 문서 열기 중심으로 단순화 |
| `Sources/HostApp/HostApp.swift` | native zoom command menu 제거 |
| `Sources/HostApp/Views/DocumentPageView.swift` | HostApp 전용 native page drawing view 삭제 |
| `Sources/README.md` | `Sources/` 소유 경계를 WKWebView HostApp viewer 기준으로 보정 |
| `README.md` | v0.1 체크리스트, Features, Checks, Project Structure 보정 |
| `mydocs/tech/project_architecture.md` | HostApp runtime flow를 WKWebView/internal scheme 기준으로 보정 |
| `mydocs/manual/build_run_guide.md` | HostApp WKWebView viewer smoke test 절차 추가 |
| `mydocs/plans/task_m010_134.md` | 수행계획서 |
| `mydocs/plans/task_m010_134_impl.md` | 구현계획서 |
| `mydocs/working/task_m010_134_stage1.md` | Stage 1 조사/결정 보고서 |
| `mydocs/working/task_m010_134_stage2.md` | Stage 2 asset 구성 보고서 |
| `mydocs/working/task_m010_134_stage3.md` | Stage 3 bridge 구현 보고서 |
| `mydocs/working/task_m010_134_stage4.md` | Stage 4 UI 전환 보고서 |
| `mydocs/working/task_m010_134_stage5.md` | Stage 5 smoke 검증 보고서 |
| `mydocs/orders/20260503.md` | #134 완료 상태 기록 |
| `mydocs/report/task_m010_134_report.md` | 본 최종 보고서 |

## 검증 결과

```bash
xcodegen generate
```

결과: 성공.

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 성공. 마지막 Stage 5 build는 `** BUILD SUCCEEDED ** [0.324 sec]`로 완료됐다.

```bash
./scripts/check-no-appkit.sh
```

결과: 성공. `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 없음.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과: 성공. `rhwp-studio` 필수 asset과 provenance 확인.

```bash
rg -n "crossorigin" Sources/HostApp/Resources/rhwp-studio/index.html
```

결과: 출력 없음. bundled `index.html`에 WKWebView file URL asset loading을 깨는 `crossorigin` attribute가 남아 있지 않음.

```bash
test -f build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/index.html
test -f build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/assets/rhwp_bg-DtQ01XFR.wasm
```

결과: 성공. Debug app bundle에 entrypoint와 WASM asset 포함 확인.

```bash
/usr/bin/open -n -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/basic/KTX.hwp
pgrep -x AlhangeulMacHost
/usr/bin/osascript -e 'tell application "System Events" to tell process "AlhangeulMacHost" to get name of windows'
```

결과: HWP 샘플 open 후 `AlhangeulMacHost` 프로세스와 `알한글` 창 유지 확인.

```bash
/usr/bin/open -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/hwpx/hwpx-01.hwpx
/usr/bin/osascript -e 'tell application "System Events" to tell process "AlhangeulMacHost" to count windows'
/usr/bin/osascript -e 'tell application "System Events" to tell process "AlhangeulMacHost" to get name of windows'
```

결과: HWPX 샘플 open 후 앱 프로세스와 `알한글` 창 유지 확인.

수동 QA 보정 후 추가 확인:

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED ** [0.413 sec]`.

```bash
/usr/bin/open -n -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/통합재정통계\(2011.10월\).hwp
```

결과: plain HTML로 펼쳐지던 menu bar가 `rhwp-studio` CSS가 적용된 toolbar/menu UI로 표시됨을 화면 캡처로 확인.

버튼 이벤트 보정 후 추가 확인:

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED ** [0.430 sec]`.

```bash
/usr/bin/open -n -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/통합재정통계\(2011.10월\).hwp
```

결과: 단일 Debug app 인스턴스에서 `통합재정통계(2011.10월).hwp`가 `rhwp-studio` UI와 함께 렌더링되고 상태바에 파일명과 페이지 수가 표시됨을 화면 캡처로 확인. `AXRaise` 후 상단 tab click smoke에서 toolbar/menu 상태 변화가 확인되어 WKWebView 내부 event listener 등록 경로에 도달했음을 확인.

```bash
rg -n "DocumentPageView|DocumentPagesView|pageTrees|renderPageTree|RhwpDocument|zoomScale|currentPage|pageCount" Sources/HostApp --glob '!**/Resources/rhwp-studio/**'
```

결과: 출력 없음. HostApp source에서 native viewer 연결 제거 확인.

```bash
git diff --check
```

결과: 성공. whitespace error 없음.

## 수용 기준 충족 여부

| 기준 | 결과 |
|------|------|
| HostApp Viewer가 `rhwp-studio` WKWebView 기반으로 동작 | OK |
| HostApp Debug build 성공 | OK |
| `Sources/RhwpCoreBridge`에 WebKit/AppKit/UIKit 직접 의존 없음 | OK |
| Quick Look/Thumbnail native render 경로 유지 | OK |
| `rhwp-studio` asset provenance와 bundle 포함 방식 문서화 | OK |
| HWP/HWPX 샘플 open smoke 기록 | OK |
| WKWebView file URL에서 `rhwp-studio` CSS/JS asset 로딩 | OK |
| WKWebView에서 `rhwp-studio` WASM 초기화와 toolbar/menu event listener 등록 | OK |
| README/운영 문서/아키텍처 문서 보정 | OK |

## 잔여 위험과 후속 작업

- Stage 5 smoke는 process/window 유지 기준의 최소 검증이다. Stage 7에서 custom resource scheme 기반 렌더링과 toolbar/menu event listener 등록 경로는 확인했지만, WKWebView 내부 렌더링의 픽셀/텍스트 정합성, 페이지 이동, zoom UI 전체 동작은 추가 수동 QA 또는 UI 자동화가 필요하다.
- custom resource scheme fetch가 특정 macOS/WebKit 버전에서 다르게 동작할 가능성은 남아 있다. 실패 시 Stage 1에서 확인한 `postMessage`/`rhwp-request loadFile` fallback을 별도 작업으로 연결한다.
- bundled `rhwp-studio`에는 service worker/PWA 산출물과 CDN font fallback URL이 남아 있다. 완전 offline 정책과 network request 차단 검증은 후속 작업으로 분리한다.
- HostApp target 구성은 여전히 `Sources/Shared`와 `Sources/RhwpCoreBridge`를 포함한다. MVP viewer 화면은 native render tree를 호출하지 않지만 target 구성 축소는 별도 source ownership 재설계가 필요하다.
- Debug build는 signing/sealing이 없으므로 Finder Quick Look/Thumbnail registration 판정에는 사용하지 않는다. 배포 산출물 검증은 release/distribution 작업에서 수행한다.

## 결론

Issue #134의 목표였던 MVP HostApp Viewer의 `rhwp-studio` WKWebView 기반 전환은 완료됐다. `devel-webview` 브랜치에서 build와 최소 HWP/HWPX open smoke가 통과했고, 수동 테스트에서 발견된 `rhwp-studio` CSS/JS 미적용과 버튼 이벤트 미동작 문제도 보정했다. Quick Look/Thumbnail native render 경로는 유지했다.

작업지시자 승인 후 `publish/task134` 원격 브랜치 게시와 `devel-webview` 대상 PR 생성을 진행할 수 있다.
