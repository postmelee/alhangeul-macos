# Task M050 #247 구현 계획서

## 작업 정보

- 이슈: #247 `native-viewer-editor를 최신 제품 라인 기준으로 forward-port`
- 마일스톤: M050 (`v0.5.0 Viewer 안정화`)
- 작업 브랜치: `local/task247`
- 대상 통합 브랜치: `native-viewer-editor`
- 기준 커밋:
  - `origin/native-viewer-editor`: `d51ad1647db281b2a8be3175eec5a723d340d8fd`
  - `origin/devel`: `341ad56e8eefb0e9e7e1dd541bccd55fa52c5698`
  - `origin/devel-webview`: `897ac143da04ed040a0e5144c5f6b62aaee1500c`

## 구현 원칙

이번 작업은 `native-viewer-editor`를 최신 제품 라인과 가까운 개발 기반으로 만드는 forward-port 작업이다. 장기 native renderer/editor 구현을 제품 라인에 섞어 없애는 작업이 아니므로, 충돌 해결은 다음 원칙을 따른다.

- 기준 반영 source는 `origin/devel`이다.
- `origin/devel-webview`는 legacy alias로 취급하고, `origin/devel` 이후 추가된 #243만 별도 검토한다.
- 프로젝트 구조, XcodeGen 설정, CI/release workflow, packaging/release helper, README/CONTRIBUTING/AGENTS/manual 문서는 최신 `devel` 기준을 우선한다.
- native renderer parity 작업이 들어간 `Sources/RhwpCoreBridge` 변경은 `native-viewer-editor`의 의도를 먼저 보존하고, `devel`의 안전한 보강만 수동 통합한다.
- WebView fallback은 제거하지 않는다. 다만 #243처럼 WebView bridge에 직접 연결된 변경은 native editor 후속 개발에 재사용 가능한 dirty-state/termination 개념과 WebView 전용 구현을 분리해 판단한다.

## 브랜치 반영 전략

`devel`에 누적된 변경은 커밋 수와 generated/project/script 범위가 크므로 개별 cherry-pick 묶음보다 merge가 안전하다. Stage 3에서 `local/task247`에 `origin/devel`을 merge하고 충돌을 해결한다.

예상 명령:

```bash
git fetch origin --prune
git checkout local/task247
git merge --no-ff origin/devel
```

이 merge는 충돌이 나는 것이 정상이다. 충돌 해결 후에는 generated project와 script 검증을 함께 수행한다.

#243은 `origin/devel..origin/devel-webview`에 남은 유일한 first-parent 추가 merge다. Stage 5에서 다음 중 하나를 선택한다.

- #243 source 변경만 수동 포팅한다.
- 충돌과 정책 후퇴가 작으면 `origin/devel-webview` 또는 #245 merge 범위를 제한적으로 반영한다.
- WebView 전용성이 커서 native 라인에서 즉시 안전하지 않으면 이번 작업에서는 보류하고 후속 이슈로 분리한다.

## 사전 충돌 inventory

`git merge-tree --write-tree origin/native-viewer-editor origin/devel` 결과, 다음 충돌이 확인됐다.

| 파일 | 충돌 유형 | 처리 원칙 |
|------|-----------|-----------|
| `AlhangeulMac.xcodeproj/project.pbxproj` | modify/delete | 최신 제품 라인의 `Alhangeul.xcodeproj`/`project.yml` 구조를 우선하고 구 project는 삭제한다. |
| `project.yml` | content | 최신 제품 라인의 target/resource/script 설정을 우선하되 native renderer target 설정이 손실되지 않는지 확인한다. |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | add/add | 최신 bundled rhwp-studio 고지와 native 라인 font 고지를 비교해 license/provenance 문구를 합친다. |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | content | native renderer style parity 변경을 보존하고 `devel`의 호환 보강만 수동 병합한다. |
| `Sources/RhwpCoreBridge/FontFallback.swift` | content | #119/#109 계열 fallback 의도를 우선 보존하고 최신 제품 라인의 fallback 보강을 합친다. |
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | add/add | registry API와 resource 등록 목록을 합쳐 중복 정의를 제거한다. |
| `mydocs/orders/20260503.md` | add/add | 과거 작업 기록은 한쪽 삭제로 해결하지 않고 필요한 기록을 보존한다. |
| `mydocs/orders/20260505.md` | add/add | 과거 작업 기록은 한쪽 삭제로 해결하지 않고 필요한 기록을 보존한다. |
| `mydocs/orders/20260506.md` | add/add | 과거 작업 기록은 한쪽 삭제로 해결하지 않고 필요한 기록을 보존한다. |
| `mydocs/report/task_m015_119_report.md` | add/add | #119 최종 기록의 양쪽 차이를 확인해 renderer/font 관련 판단을 보존한다. |
| `mydocs/tech/font_fallback_strategy.md` | add/add | native renderer font 전략과 제품 라인 font 고지를 비교해 통합한다. |

`git merge-tree --write-tree origin/native-viewer-editor origin/devel-webview` 결과도 같은 충돌군을 보이며, `origin/devel-webview` 전용 차이는 #243 저장 확인 작업이다.

## #243 선별 검토 범위

`origin/devel..origin/devel-webview`의 비문서 source 차이는 다음 파일에 집중되어 있다.

- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Services/DocumentCloseConfirmationController.swift`
- `Sources/HostApp/Services/DocumentTerminationCoordinator.swift`
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Alhangeul.xcodeproj/project.pbxproj`

판단 기준:

- 문서 dirty state, 앱 종료, 창 닫기 확인처럼 native editor에도 필요한 개념은 가져온다.
- `RhwpStudioWebView`와 JavaScript bridge에만 닫힌 구현은 WebView fallback에만 필요한지 확인한다.
- #244 이후 브랜치 안내 문서가 `devel-webview` 기준으로 되돌아가는 변경은 가져오지 않는다.

## 단계 계획

### Stage 1: 충돌 inventory 고정

- `origin/native-viewer-editor`, `origin/devel`, `origin/devel-webview` 기준 커밋을 기록한다.
- `git merge-tree --write-tree` 결과를 `mydocs/working/task_m050_247_stage1.md`에 정리한다.
- `origin/devel..origin/devel-webview`에서 #243 전용 변경 파일을 확정한다.

완료 커밋:

```text
Task #247 Stage 1: forward-port 충돌 inventory 정리
```

### Stage 2: `devel` merge와 project/운영 충돌 해결

- `origin/devel`을 `local/task247`에 merge한다.
- `project.yml`은 최신 제품 라인 기준을 우선하고 native renderer 관련 설정 손실 여부를 점검한다.
- `AlhangeulMac.xcodeproj`는 삭제하고 `Alhangeul.xcodeproj` 구조로 정리한다.
- CI/release workflow, scripts, README/CONTRIBUTING/AGENTS/manual은 `devel` 기준을 우선한다.
- mydocs 충돌은 과거 기록 보존 원칙으로 정리한다.

완료 커밋:

```text
Task #247 Stage 2: devel 제품 라인 project와 운영 변경 반영
```

### Stage 3: native renderer/bridge 충돌 해결

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`를 수동 통합한다.
- `Sources/RhwpCoreBridge/FontFallback.swift`와 `FontResourceRegistry.swift`를 수동 통합한다.
- font fallback 문서와 rhwp-studio font 고지를 정리한다.
- Swift bridge/AppKit 의존 금지 규칙을 재확인한다.

완료 커밋:

```text
Task #247 Stage 3: native renderer와 font fallback 충돌 해결
```

### Stage 4: build/script 검증과 generated project 정렬

- `xcodegen generate`로 generated project를 정렬한다.
- shell script syntax와 helper interface를 확인한다.
- RustBridge/core 변경 여부에 따라 `build-rust-macos.sh` 검증 범위를 확정한다.
- HostApp Debug build를 수행한다.

완료 커밋:

```text
Task #247 Stage 4: generated project와 기본 검증 정렬
```

### Stage 5: #243 저장 확인 변경 선별 포팅

- #243 source 변경을 WebView fallback과 native editor 공통 개념으로 나눈다.
- 안전하게 포팅 가능한 범위만 반영한다.
- 문서/branch 안내가 `devel-webview` 기준으로 후퇴하는 변경은 제외한다.
- 포팅하지 않는 항목은 후속 이슈 후보로 보고서에 남긴다.

완료 커밋:

```text
Task #247 Stage 5: 종료 저장 확인 변경 선별 포팅
```

### Stage 6: 최종 검증과 보고

- 최종 검증 명령을 실행한다.
- `mydocs/report/task_m050_247_report.md`를 작성한다.
- 오늘할일을 완료 처리한다.
- `publish/task247` push와 `native-viewer-editor` 대상 PR 게시를 준비한다.

완료 커밋:

```text
Task #247 Stage 6 + 최종 보고서: native line forward-port 완료
```

## 검증 계획

문서/계획 단계:

```bash
git diff --check
```

merge/충돌 조사:

```bash
git merge-tree --write-tree origin/native-viewer-editor origin/devel
git merge-tree --write-tree origin/native-viewer-editor origin/devel-webview
git diff --name-status origin/devel..origin/devel-webview -- . ':!mydocs'
```

source 통합 후 기본 검증:

```bash
xcodegen generate
./scripts/check-no-appkit.sh
for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done
```

RustBridge/core 영향이 있으면 다음을 실행한다.

```bash
./scripts/build-rust-macos.sh
```

`rhwp-core.lock`, `RustBridge/Cargo.lock`, generated bridge artifact, FFI symbol 표면이 바뀌면 `--verify-lock` 사용 여부를 stage 보고에서 별도 판단한다.

macOS build:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

renderer 영향이 남으면 native render smoke 또는 기존 render 비교 스크립트 중 현재 브랜치에 존재하는 검증 명령을 선택해 실행한다.

## 중단 기준

- `origin/devel` merge 후 native renderer 핵심 구현이 대량으로 삭제되는 방향으로만 해결 가능한 경우
- `project.yml`과 generated project가 일관되지 않아 XcodeGen 재생성이 안정적으로 끝나지 않는 경우
- #243 포팅이 WebView 전용 bridge를 native 라인에 과도하게 끌어와 저장/종료 동작의 책임 경계를 흐리는 경우
- 검증 실패가 forward-port 범위를 넘어 신규 기능 수정으로 커지는 경우

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다. Stage 1은 읽기 중심의 충돌 inventory 고정과 stage 보고서 작성이며, `origin/devel` 실제 merge와 충돌 해결은 Stage 2 승인 후 진행한다.
