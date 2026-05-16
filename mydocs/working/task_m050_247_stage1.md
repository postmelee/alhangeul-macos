# Task M050 #247 Stage 1 보고서

## 목적

`native-viewer-editor`를 최신 제품 라인에 forward-port하기 전에, 기준 브랜치와 충돌 범위를 읽기 중심으로 고정한다.

이번 단계에서는 실제 merge나 source 충돌 해결을 수행하지 않고, Stage 2에서 다룰 충돌 inventory와 #243 선별 검토 범위를 확정했다.

## 기준 refs

| 항목 | 값 |
|------|----|
| 작업 브랜치 | `local/task247` |
| 작업 HEAD | `835c581ab80c0ab98c7c1da10df4c048e24687fc` |
| 기준 native 브랜치 | `origin/native-viewer-editor` = `d51ad1647db281b2a8be3175eec5a723d340d8fd` |
| 제품 기준 브랜치 | `origin/devel` = `341ad56e8eefb0e9e7e1dd541bccd55fa52c5698` |
| legacy alias | `origin/devel-webview` = `897ac143da04ed040a0e5144c5f6b62aaee1500c` |
| 공통 조상 | `ce6150ff158223ae5f9ed6359742557c6f2a9623` |

## 브랜치 차이

| 비교 | left-only | right-only | 해석 |
|------|-----------|------------|------|
| `origin/native-viewer-editor...origin/devel` | 33 | 493 | native 라인은 #109 계열 장기 renderer 작업을 보존하고, 제품 라인은 WKWebView/배포/운영 변경이 크게 누적됨 |
| `origin/native-viewer-editor...origin/devel-webview` | 33 | 488 | legacy alias도 native 라인과 크게 분기됨 |
| `origin/devel...origin/devel-webview` | 14 | 9 | `devel-webview`에는 #243 작업이 남아 있고, `devel`에는 #244 전환 정리가 들어 있음 |

`origin/native-viewer-editor..origin/devel` first-parent에는 #134 WebView MVP 전환부터 #246 브랜치 전환까지의 제품/배포 라인이 누적되어 있다. 따라서 Stage 2는 단일 cherry-pick보다 `origin/devel` merge 후 충돌 해결로 진행하는 것이 맞다.

## `origin/devel` merge 충돌 inventory

`git merge-tree --write-tree origin/native-viewer-editor origin/devel`은 예상대로 exit code 1을 반환했고, 다음 충돌을 보고했다.

| 파일 | 충돌 유형 | Stage 2/3 처리 방향 |
|------|-----------|---------------------|
| `AlhangeulMac.xcodeproj/project.pbxproj` | modify/delete | `origin/devel`의 `Alhangeul.xcodeproj` 전환을 우선하고 구 `AlhangeulMac.xcodeproj`는 삭제한다. |
| `project.yml` | content | 최신 제품 라인의 XcodeGen 설정을 우선하되 native renderer target/resource 설정 손실 여부를 확인한다. |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | add/add | bundled rhwp-studio font 고지와 native 라인 font 고지를 합친다. |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | content | #109 style parity 의도를 보존하고 제품 라인의 호환 보강만 수동 통합한다. |
| `Sources/RhwpCoreBridge/FontFallback.swift` | content | #119/#109 fallback 정책을 보존하고 최신 fallback 보강을 합친다. |
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | add/add | 양쪽 registry 정의를 비교해 중복 없이 통합한다. |
| `mydocs/orders/20260503.md` | add/add | 과거 작업 기록이므로 필요한 기록을 보존한다. |
| `mydocs/orders/20260505.md` | add/add | 과거 작업 기록이므로 필요한 기록을 보존한다. |
| `mydocs/orders/20260506.md` | add/add | 과거 작업 기록이므로 필요한 기록을 보존한다. |
| `mydocs/report/task_m015_119_report.md` | add/add | #119 renderer/font 관련 결론이 사라지지 않게 통합한다. |
| `mydocs/tech/font_fallback_strategy.md` | add/add | native renderer font 전략과 제품 라인 고지를 비교해 통합한다. |

비문서 source diff는 177개 파일, 약 27,224 insertions / 1,634 deletions 규모다. 주요 범위는 다음과 같다.

- Xcode project rename: `AlhangeulMac.xcodeproj` -> `Alhangeul.xcodeproj`
- WKWebView HostApp shell과 bundled `rhwp-studio` assets
- Quick Look/Thumbnail extension 보강
- release/CI/helper scripts와 Pages/appcast 문서
- RustBridge/core lock, build helper, visual compare helper
- README/CONTRIBUTING/AGENTS/manual branch policy 문서

## `origin/devel-webview` 전용 #243 범위

`origin/devel..origin/devel-webview` first-parent 추가분은 `897ac14 Merge pull request #245 from postmelee/publish/task243` 하나다.

포함된 non-merge commit은 다음이다.

| commit | 내용 |
|--------|------|
| `e367320` | Task #243 수행 계획서 작성과 오늘할일 갱신 |
| `a986953` | Task #243 구현계획서 작성 |
| `e4e3193` | Stage 1: 종료 저장 확인 경로 조사 |
| `8d4184b` | Stage 2: WebView 편집 상태 추적 추가 |
| `4af671f` | Stage 3: 문서 창 닫기 저장 확인 추가 |
| `af101e8` | Stage 4: 앱 종료 저장 확인 추가 |
| `e1c3e9a` | Stage 5 + 최종 보고서: 종료 저장 확인 완료 |
| `6be3713` | 오늘할일 완료 시각 기록 |

source 차이는 다음 파일에 집중된다.

- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Services/DocumentCloseConfirmationController.swift`
- `Sources/HostApp/Services/DocumentTerminationCoordinator.swift`
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Alhangeul.xcodeproj/project.pbxproj`

문서 차이에는 #243 작업 문서 추가와 #244 작업 문서 삭제가 함께 들어 있다. Stage 5에서는 source 개념만 선별하고, #244 브랜치 정책 문서가 `devel-webview` 기준으로 후퇴하는 변경은 제외한다.

## Stage 2 진입 판단

Stage 2에서는 `origin/devel`을 `local/task247`에 merge하는 방식으로 진행한다. 충돌은 정상 기대값이며, 먼저 프로젝트/운영/문서 충돌을 정리하고 renderer/bridge 충돌은 Stage 3으로 분리한다.

Stage 2에서 우선 처리할 파일군:

1. `project.yml`, `Alhangeul.xcodeproj`, `AlhangeulMac.xcodeproj`
2. CI/release workflow와 helper scripts
3. README/CONTRIBUTING/AGENTS/manual branch policy 문서
4. 과거 `mydocs/orders`와 #119 report/font strategy 문서 충돌

`Sources/RhwpCoreBridge/*` 충돌은 Stage 3에서 별도 커밋으로 다룬다.

## 검증

| 명령 | 결과 |
|------|------|
| `git fetch origin --prune` | 통과 |
| `git rev-parse HEAD origin/native-viewer-editor origin/devel origin/devel-webview` | 통과 |
| `git rev-list --left-right --count origin/native-viewer-editor...origin/devel` | `33 493` |
| `git rev-list --left-right --count origin/native-viewer-editor...origin/devel-webview` | `33 488` |
| `git rev-list --left-right --count origin/devel...origin/devel-webview` | `14 9` |
| `git merge-tree --write-tree origin/native-viewer-editor origin/devel` | exit 1, 충돌 inventory 확보 |
| `git merge-tree --write-tree origin/native-viewer-editor origin/devel-webview` | exit 1, `origin/devel`과 같은 충돌군 확인 |
| `git diff --name-status origin/devel..origin/devel-webview` | #243 전용 파일 범위 확인 |
| `git diff --stat origin/native-viewer-editor..origin/devel -- . ':!mydocs'` | 비문서 source 규모 확인 |

## 다음 단계

Stage 2 진행 승인 후 `origin/devel` merge를 실행하고, 프로젝트/운영/문서 충돌부터 해결한다.
