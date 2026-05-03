# Task M010 #134 최종 보고서

## 작업 요약

- 이슈: #134 MVP Viewer를 rhwp-studio WKWebView 기반으로 전환
- 마일스톤: M010 (`v0.1.0 Viewer 기반`)
- 브랜치: `devel-webview`
- 단계 수: 12
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
| 7 | `f0c23ae` | WKWebView file URL WASM fetch 문제를 custom resource scheme으로 보정 |
| 8 | `03667d5` | `rhwp-studio` 파일 메뉴 열기/저장/인쇄를 HostApp 네이티브 기능으로 연결 |
| 9 | `a9c79dc` | 현재 매핑 가능한 파일 단축키를 HostApp 네이티브 브리지로 연결 |
| 10 | `9c23993` | HostApp viewer 하단 중복 footer 제거 |
| 11 | `3adfa70` | HostApp 상단과 File menu의 중복 문서 열기 제거 |
| 12 | 본 커밋 | HostApp toolbar에 공유, Finder에서 보기, PDF로 내보내기, 최근 문서 기능 추가 |

## 완료 내용

HostApp viewer의 기본 경로가 `rhwp-studio` WKWebView 기반으로 바뀌었다.

- 앱 bundle에 `Sources/HostApp/Resources/rhwp-studio` 정적 asset을 포함한다.
- `RhwpStudioWebView`가 `alhangeul-studio://app/index.html` entrypoint를 로드한다.
- `RhwpStudioResourceSchemeHandler`가 bundle의 `rhwp-studio` 정적 asset을 MIME type과 함께 응답한다.
- Swift가 보안 범위 접근 안에서 원본 HWP/HWPX bytes를 읽어 `RhwpStudioDocumentPayload`로 보관한다.
- `RhwpStudioDocumentSchemeHandler`가 `alhangeul-document://current?revision=...` 요청에 현재 문서 bytes를 응답한다.
- `rhwp-studio`의 기존 `?url=` loader가 내부 document URL을 fetch해 문서를 로드한다.
- HostApp titlebar toolbar와 macOS File menu의 중복 문서 열기 항목은 제거하고, zoom/page/open UI는 `rhwp-studio` 내부 UI가 소유한다.
- HostApp 전용 native page view와 native viewer store 상태는 제거했다.
- Quick Look/Thumbnail은 기존 `Sources/Shared`/`Sources/RhwpCoreBridge` native render 경로를 유지한다.
- WKWebView file URL 환경에서 `crossorigin` subresource request가 CSS/JS 로딩을 막지 않도록 bundled `index.html`의 `crossorigin` attribute를 제거하고 sync/verify script에 재발 방지 검증을 추가했다.
- WKWebView file URL 환경에서 WASM fetch 실패가 JS 초기화를 중단하지 않도록 `rhwp-studio` asset 전체를 `alhangeul-studio://app` custom scheme으로 제공한다.
- `rhwp-studio`의 브라우저 전용 파일 명령 중 `열기`, `저장`, `인쇄`를 WKUserScript와 `WKScriptMessageHandler`로 가로채 HostApp 네이티브 open/save/print 경로에 연결했다.
- `Command/Ctrl+O/S/P` 단축키도 같은 HostApp 네이티브 bridge를 타도록 WKWebView keydown capture, AppKit key equivalent fallback, SwiftUI File menu command dispatcher를 추가했다.
- `rhwp-studio` 임베드 페이지와 중복되던 HostApp 하단 footer를 제거해 WKWebView 표시 영역이 창 하단까지 확장되도록 했다.
- `rhwp-studio` 내부 `파일 > 열기`와 중복되던 HostApp titlebar `문서 열기` 버튼과 macOS File menu `문서 열기...` 항목을 제거했다.
- HostApp toolbar에 macOS 공유, Finder에서 보기, PDF로 내보내기, 최근 문서 접근을 추가했다.
- PDF export는 `rhwp-studio` page SVG payload를 WKWebView print operation의 PDF save job으로 저장하고, 저장 완료 후 Finder에서 결과 파일을 표시한다.
- 최근 문서는 security-scoped bookmark와 `NSDocumentController` recent document 기록을 함께 사용한다.

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
| `Sources/HostApp/Services/DocumentSavePanel.swift` | `rhwp-studio` `exportHwp` bytes를 `NSSavePanel`로 저장 |
| `Sources/HostApp/Services/DocumentFileActions.swift` | 공유용 임시 파일 생성, `NSSharingServicePicker`, Finder reveal 처리 |
| `Sources/HostApp/Services/DocumentPDFExportPanel.swift` | PDF 저장 위치 선택 panel |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | 파일 메뉴/단축키 명령 캡처와 `rhwp-request` export/print payload 생성 user script |
| `Sources/HostApp/Services/RhwpStudioPrintController.swift` | 페이지 SVG payload를 AppKit print operation으로 인쇄 |
| `Sources/HostApp/Services/RhwpStudioPDFExportController.swift` | 페이지 SVG payload를 WKWebView PDF save job으로 저장 |
| `Sources/HostApp/Services/RecentDocumentStore.swift` | 최근 문서 security-scoped bookmark 저장과 macOS recent document 기록 |
| `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift` | WKWebView internal resource scheme static asset response |
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | bundle `rhwp-studio/index.html` 검증과 custom scheme entrypoint URL 구성 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `WKWebView` wrapper, resource/document scheme registration, navigation policy, revision 기반 reload, AppKit key equivalent fallback, PDF export bridge |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | HostApp viewer state를 web payload/loading/error/source document/recent document 중심으로 관리 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | 표시 영역을 `RhwpStudioWebView` 중심으로 전환, HostApp 하단 중복 footer 제거 |
| `Sources/HostApp/Views/ContentView.swift` | HostApp titlebar toolbar의 macOS 공유/Finder/PDF/최근 문서 action |
| `Sources/HostApp/HostApp.swift` | native zoom command menu 제거, File menu 중복 열기 제거와 저장/인쇄 command 연결 |
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
| `mydocs/working/task_m010_134_stage8.md` | Stage 8 파일 메뉴 native bridge 보고서 |
| `mydocs/working/task_m010_134_stage9.md` | Stage 9 파일 단축키 native bridge 보고서 |
| `mydocs/working/task_m010_134_stage10.md` | Stage 10 viewer footer 제거 보고서 |
| `mydocs/working/task_m010_134_stage11.md` | Stage 11 HostApp 중복 열기 제거와 macOS 기능 후보 보고서 |
| `mydocs/working/task_m010_134_stage12.md` | Stage 12 HostApp toolbar macOS 문서 동작 추가 보고서 |
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

결과: 성공. Stage 8 build는 `** BUILD SUCCEEDED ** [2.262 sec]`로 완료됐다.

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

파일 메뉴 네이티브 브리지 보정 후 추가 확인:

```bash
xcodegen generate
```

결과: 성공.

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED ** [2.262 sec]`.

```bash
./scripts/check-no-appkit.sh
```

결과: 성공. `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 없음.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과: 성공. `rhwp-studio` asset bundle 구성 검증 통과.

파일 단축키 네이티브 브리지 보정 후 추가 확인:

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

결과: `** BUILD SUCCEEDED ** [2.313 sec]`.

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

HostApp viewer footer 제거 후 추가 확인:

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

결과: `** BUILD SUCCEEDED ** [2.546 sec]`.

HostApp 상단 중복 열기 제거 후 추가 확인:

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

결과: `** BUILD SUCCEEDED ** [2.152 sec]`.

```bash
/usr/bin/open -n -F -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/통합재정통계\(2011.10월\).hwp
/usr/bin/osascript ... 'name of menu items of menu 1 of menu bar item "파일" of menu bar 1'
```

결과: 실행 앱의 macOS File menu에서 HostApp `문서 열기...` 항목이 제거되고, `저장`, `인쇄...` 항목만 남았음을 확인.

HostApp toolbar macOS 문서 동작 추가 후 확인:

```bash
xcodegen generate
```

결과: 성공. 새 HostApp service 파일이 Xcode project source 목록에 포함됨.

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
| `파일 > 열기`가 HostApp open panel 경로로 연결 | OK |
| `파일 > 저장`이 `exportHwp` bytes와 `NSSavePanel` 저장 경로로 연결 | OK |
| `파일 > 인쇄`가 page SVG payload와 AppKit print operation 경로로 연결 | OK |
| `Command/Ctrl+O/S/P`가 HostApp native bridge 경로로 연결 | OK |
| HostApp 하단 중복 footer 제거 | OK |
| HostApp 상단과 File menu의 중복 문서 열기 제거 | OK |
| HostApp toolbar의 공유/Finder/PDF/최근 문서 기능 제공 | OK |
| README/운영 문서/아키텍처 문서 보정 | OK |

## 잔여 위험과 후속 작업

- Stage 5 smoke는 process/window 유지 기준의 최소 검증이다. Stage 7에서 custom resource scheme 기반 렌더링과 toolbar/menu event listener 등록 경로는 확인했고, Stage 8과 Stage 9에서 파일 메뉴와 파일 단축키 native bridge를 build 및 panel/window smoke로 검증했다. 실제 저장 파일, 인쇄 출력물, PDF 출력물의 시각적 검수는 별도 QA가 필요하다.
- Stage 12 공유는 현재 HostApp이 로드한 원본 문서 bytes 기준이다. 저장되지 않은 web editor 변경분까지 공유하려면 `exportHwp` 결과를 공유 payload로 쓰는 후속 보정이 필요하다.
- HWPX 문서의 직접 저장은 upstream `rhwp-studio`가 베타 정책으로 비활성화한다. 이번 단계는 이 정책을 우회하지 않는다.
- custom resource scheme fetch가 특정 macOS/WebKit 버전에서 다르게 동작할 가능성은 남아 있다. 실패 시 Stage 1에서 확인한 `postMessage`/`rhwp-request loadFile` fallback을 별도 작업으로 연결한다.
- bundled `rhwp-studio`에는 service worker/PWA 산출물과 CDN font fallback URL이 남아 있다. 완전 offline 정책과 network request 차단 검증은 후속 작업으로 분리한다.
- HostApp target 구성은 여전히 `Sources/Shared`와 `Sources/RhwpCoreBridge`를 포함한다. MVP viewer 화면은 native render tree를 호출하지 않지만 target 구성 축소는 별도 source ownership 재설계가 필요하다.
- Debug build는 signing/sealing이 없으므로 Finder Quick Look/Thumbnail registration 판정에는 사용하지 않는다. 배포 산출물 검증은 release/distribution 작업에서 수행한다.

## 결론

Issue #134의 목표였던 MVP HostApp Viewer의 `rhwp-studio` WKWebView 기반 전환은 완료됐다. `devel-webview` 브랜치에서 build와 최소 HWP/HWPX open smoke가 통과했고, 수동 테스트에서 발견된 `rhwp-studio` CSS/JS 미적용, WASM fetch 실패, 파일 메뉴 명령과 파일 단축키 미동작, HostApp 하단 중복 footer와 상단 중복 열기 문제도 보정했다. 추가로 HostApp toolbar에 macOS 공유, Finder에서 보기, PDF로 내보내기, 최근 문서 기능을 연결했다. Quick Look/Thumbnail native render 경로는 유지했다.

작업지시자 승인 후 `publish/task134` 원격 브랜치 게시와 `devel-webview` 대상 PR 생성을 진행할 수 있다.
