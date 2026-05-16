# Task #150 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#150 WKWebView viewer asset loading 실패 fallback 보강](https://github.com/postmelee/alhangeul-macos/issues/150) |
| 마일스톤 | M016 / v0.1 출시 전 보강 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task150` |
| 단계 수 | 5단계 |
| 결론 | HostApp WKWebView viewer의 bundled `rhwp-studio` asset, custom resource scheme, document scheme, WebKit navigation/process/timeout/runtime 실패를 fatal fallback 상태로 분리했다. 정상 Debug app에서는 HWP/HWPX sample smoke가 통과했고, WASM asset 제거 복사본에서는 `웹 viewer 자산을 찾을 수 없습니다` fallback과 retry 복구가 확인됐다. |

## 사용자 영향

| 상황 | 변경 전 | 변경 후 |
|------|---------|---------|
| `rhwp-studio` 필수 asset 누락 | 빈 WebView, timeout, generic banner로 섞일 수 있음 | 문서 영역을 fallback view로 대체하고 누락 asset pattern/count를 진단 정보로 표시 |
| document scheme 전달 실패 | WebKit fetch/runtime failure로 섞일 수 있음 | document scheme domain, requested/current revision, payload byte count, filename을 진단에 포함 |
| WebKit process 종료/timeout/navigation failure | 문자열 banner 중심 | fatal fallback 상태로 승격하고 `다시 시도` 제공 |
| JS/WASM runtime failure | 일부 host command error와 같은 `"error"` 경로 | runtime fatal failure와 command banner error를 분리 |
| 실패 후 복구 | 파일을 다시 열어야 하는 흐름 | `다시 시도`, `다른 파일 열기`, 조건부 `Finder에서 보기` 제공 |

## 구현 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | runtime 필수 asset validator, `RhwpStudioWebViewFailure` model, diagnostic key 추가 |
| `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift` | resource scheme failure에 failing URL, relative path, resolved file path, resource directory, underlying error 기록 |
| `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift` | missing revision failure 처리와 requested/current revision, payload byte count, filename 진단 보강 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | document-start runtime error bridge 추가, `registerSW.js` service worker rejection false positive 제외 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | reload token, fatal failure callback, navigation/process/timeout/runtime failure 연결 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | `webViewFailure`, `webViewReloadToken`, retry API, command 가능 상태 추가 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | fatal fallback UI와 recovery action 추가 |
| `Sources/HostApp/Views/ContentView.swift` | viewer fatal/loading 상태에서 share/export command 비활성화 |
| `Sources/HostApp/HostApp.swift` | AppKit toolbar validation에 viewer command 가능 상태 반영 |
| `mydocs/manual/build_run_guide.md` | WKWebView viewer 정상/negative smoke 절차 보강 |

## failure taxonomy

| category | 사용자 메시지 | 대표 진단 |
|----------|--------------|----------|
| `resourcePreflight` | 웹 viewer 자산을 찾을 수 없습니다 | missing file, asset pattern, count, asset directory |
| `resourceScheme` | 웹 viewer 자산을 읽을 수 없습니다 | `alhangeul-studio` URL, relative path, resolved file path |
| `documentScheme` | 문서 데이터를 viewer에 전달할 수 없습니다 | `alhangeul-document` URL, requested/current revision, payload filename/size |
| `navigation` | 웹 viewer 탐색에 실패했습니다 | WebKit/NSURLError domain/code, failing URL |
| `processTerminated` | 웹 viewer 프로세스가 종료되었습니다 | last URL, document revision, reload token |
| `timeout` | 웹 viewer 로딩이 지연되고 있습니다 | timeout seconds, loading URL, document revision |
| `runtime` | 웹 viewer 실행 중 오류가 발생했습니다 | JS message, source URL, line/column, rejection reason |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `fcb93b5` | 수행계획서와 오늘할일 항목을 작성했다. |
| 구현계획 | `277d194` | 5단계 구현계획서를 작성했다. |
| Stage 1 | `3019ffb` | 현행 WKWebView loading/failure 경로 inventory와 failure matrix를 정리했다. |
| Stage 2 | `2c5e048` | fallback state, diagnostics, recovery action, runtime validator 경계를 설계했다. |
| Stage 3 | `6a5a13c` | runtime validator, failure model, fallback UI, retry path, scheme/runtime diagnostics를 구현했다. |
| Stage 4 | `20d8784` | HWP/HWPX 정상 smoke, WASM 제거 negative smoke, retry 복구를 확인하고 false-positive runtime fallback을 수정했다. |
| Stage 5 | 이번 최종 보고 커밋 | 최종 보고서와 오늘할일 완료 처리를 정리한다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `git diff --check` | OK | Stage 3/4/5 |
| `scripts/verify-rhwp-studio-assets.sh` | OK | source `rhwp-studio` 검증 |
| `scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio` | OK | Debug app bundle resource 검증 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | OK | Stage 3: `** BUILD SUCCEEDED ** [3.863 sec]`, Stage 4: `** BUILD SUCCEEDED ** [0.353 sec]` |
| HWPX 정상 smoke | OK | `samples/hwpx/hwpx-01.hwpx`, `hwpx-01.hwpx — 9페이지`, fallback 없음 |
| HWP 정상 smoke | OK | `samples/basic/KTX.hwp`, `KTX.hwp — 1페이지`, fallback 없음 |
| WASM 제거 negative smoke | OK | `assetPattern=assets/rhwp_bg-*.wasm`, `count=0` fallback 확인 |
| retry recovery smoke | OK | WASM 복구 후 `다시 시도`로 `hwpx-01.hwpx — 9페이지` 재표시 |

Xcode/CoreSimulator 관련 sandbox 경고는 빌드 로그에 출력됐지만 macOS HostApp build 결과는 성공이었다.

## smoke 절차 반영

`mydocs/manual/build_run_guide.md`의 HostApp WKWebView viewer smoke test를 보강했다.

- hash 기반 특정 WASM 파일명 대신 `rhwp_bg-*.wasm` pattern count를 확인한다.
- source resource와 Debug app bundle resource 양쪽에 `scripts/verify-rhwp-studio-assets.sh`를 실행한다.
- Debug app 복사본에서 WASM asset만 rename해 `resourcePreflight` fallback을 확인한다.
- asset 복구 후 fallback의 `다시 시도`로 같은 payload reload를 확인한다.

## 미포함 범위와 handoff

| 후속 이슈 | 넘길 내용 |
|----------|-----------|
| #149 손상·대용량 HWP/HWPX opening fallback | 이번 작업은 WKWebView asset/document delivery failure에 집중했다. parser/opening 실패, 손상 파일, 대용량 파일의 단계별 fallback은 #149에서 다룬다. |
| #151 Quick Look/Thumbnail 설치본 smoke gate | 이번 smoke는 Debug app과 build artifact 복사본 기준이다. signed/sealed 설치본, LaunchServices, PlugInKit, Quick Look/Thumbnail gate는 #151에서 처리한다. |
| #146 렌더 경로 한계 문서화 | WKWebView viewer는 service worker registration 같은 PWA 부산물이 custom scheme에서 실패할 수 있으며, 문서 렌더와 무관한 known benign runtime issue는 fatal fallback에서 제외한다는 한계를 known limitation 후보로 넘긴다. |
| #145/#166 release artifact/public 배포 | public DMG 생성, Developer ID signing, notarization, staple, GitHub Release upload는 이번 작업 범위 밖이다. |

## 잔여 위험

| 구분 | 내용 |
|------|------|
| document scheme negative smoke | 제품 코드에 테스트 훅을 남기지 않는 범위에서 revision mismatch를 자연스럽게 만들기 어려워 직접 negative smoke는 수행하지 않았다. 정상 smoke에서는 `alhangeul-document://current?revision=1` 연결을 확인했다. |
| runtime negative smoke | 별도 JS throw 주입 smoke는 수행하지 않았다. 대신 정상 smoke에서 실제로 발생한 `registerSW.js` rejection false positive를 수정했다. |
| subresource failure surfacing | `WKURLSchemeTask.didFailWithError`가 모든 subresource failure를 navigation delegate로 올린다고 보장할 수 없다. 필수 asset은 preflight에서 먼저 잡도록 설계했다. |
| generated project source list | 새 Swift 파일을 추가하지 않고 기존 HostApp 컴파일 파일 안에 failure model을 배치했다. `project.yml` 원본 규칙을 지키기 위한 선택이며, 추후 xcodegen 재생성 정책이 정리되면 별도 파일로 분리할 수 있다. |

## 완료 판단

#150의 수용 기준은 충족했다.

- 정상 `rhwp-studio` bundle에서 HostApp Debug build와 HWP/HWPX sample open smoke가 통과했다.
- 필수 WASM asset 누락 시 빈 화면 대신 fatal fallback이 표시됐다.
- asset/resource/document/navigation/runtime failure category와 diagnostics가 분리됐다.
- WebKit process termination, timeout, navigation failure가 fatal fallback 경로로 연결된다.
- 사용자가 실패 상태에서 다시 시도하거나 다른 파일을 열 수 있다.
- release provenance/hash 검증은 `scripts/verify-rhwp-studio-assets.sh`에 남기고, runtime validator는 제품 fallback에 필요한 최소 asset만 확인한다.

## 작업지시자 승인 요청

Task #150의 WKWebView viewer asset loading 실패 fallback 보강을 완료했다. 다음 단계는 `publish/task150` 브랜치 push와 `devel-webview` 대상 PR 생성 승인이다.
