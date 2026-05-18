# Task M013 #263 Stage 4 보고서

## 단계 목적

Stage 4의 목적은 Stage 2 전략 문서와 Stage 3 사용자/아키텍처 문서 갱신 내용을 기준으로 브랜치 전략, Git/PR workflow, contributor 안내, PR template, Copilot review instruction, release/CI 문서의 PR base 기준을 정렬하는 것이다.

이번 단계는 문서 갱신만 수행했고, workflow YAML, release script, source code, RustBridge ABI, 원격 브랜치는 변경하지 않았다.

## 변경 파일

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/tech/branch_strategy_webview_native.md` | `native-viewer-editor`의 현재 역할을 HostApp native macOS shell, Rust/rhwp Skia renderer, Swift 편집 UI/오버레이 장기 라인으로 재정의했다. PR base 표에서 Skia 공통 기반은 `devel`, HostApp native shell/overlay는 `native-viewer-editor`로 분리했다. |
| `mydocs/manual/git_workflow_guide.md` | 통합 브랜치 용어, 브랜치 표, maintainer/contributor 예시의 base branch 선택 기준을 새 역할로 갱신했다. |
| `mydocs/manual/pr_process_guide.md` | 내부 task PR 작성 규칙과 `gh pr create` 예시 주석을 HostApp native shell/overlay 기준으로 바꿨다. |
| `CONTRIBUTING.md` | 외부 contributor가 고르는 PR base 표와 Fork workflow 안내를 Skia 공통 기반, HostApp native shell, Swift overlay 기준으로 갱신했다. |
| `.github/pull_request_template.md` | PR base 안내 주석에서 `devel`과 `native-viewer-editor` 기준을 새 역할로 바꿨다. |
| `.github/copilot-instructions.md` | review instruction의 architecture/workflow 기준을 현재 CoreGraphics/CoreText fallback과 future Skia bridge contract, HostApp native shell/overlay PR base 기준으로 조정했다. |
| `mydocs/manual/release_policy_guide.md` | 배포 브랜치 기준과 release note limitation 문구를 Skia renderer + Swift overlay 장기 경로로 정렬했다. |
| `mydocs/manual/release_distribution_guide.md` | rollback 이후 native 장기 브랜치 후속 반영 문구를 HostApp native shell/Skia/overlay 기준으로 바꿨다. |
| `mydocs/manual/ci_workflow_guide.md` | PR CI 대상 브랜치 안내를 제품/Skia 공통 기반과 HostApp native shell/overlay로 분리했다. |
| `mydocs/working/task_m013_263_stage4.md` | Stage 4 보고서 |
| `mydocs/orders/20260518.md` | #263 상태를 Stage 4 완료, Stage 5 승인 대기로 갱신 |

## 핵심 반영 내용

### PR base 기준

- `devel`은 제품 공통 기반, WKWebView viewer/editor, Finder/Quick Look/Thumbnail, PDF/export/share/save, 문서, 배포, Skia FFI/Shared renderer backend/provenance 작업을 받는다.
- `native-viewer-editor`는 HostApp native macOS viewer/editor shell, Rust/rhwp Skia renderer를 쓰는 page/tile viewport, native zoom/cache/sidebar/search/copy, Swift caret/selection/IME/ruler/object overlay, editor command routing 실험을 받는다.
- `main`은 release/tag 기준 브랜치이고 일반 기여 PR base가 아니다.
- `devel-webview`는 퇴역한 legacy alias로 신규 PR base나 자동화 기준이 아니다.

### Contributor 안내

- `CONTRIBUTING.md`의 PR base 표와 Fork workflow 주의사항에서 `native-viewer-editor`를 단순 native renderer 라인이 아니라 HostApp native shell/Skia viewport/Swift overlay 라인으로 설명했다.
- 렌더링 smoke 안내는 특정 branch 전용이 아니라 현재 render tree, Quick Look/Thumbnail/PDF native bitmap 경로, 렌더링 결과 변경 PR에 적용하는 기준으로 바꿨다.

### Review/CI/Release 안내

- Copilot review instruction은 `RhwpCoreBridge`가 UI state를 소유하지 않고 current CoreGraphics/CoreText fallback/diagnostic rendering과 explicit Skia bridge contract 경계를 지켜야 한다고 설명한다.
- CI guide는 제품/배포/문서/Skia 공통 기반 PR은 `devel`, HostApp native shell/Skia viewport/Swift overlay PR은 `native-viewer-editor`로 안내한다.
- release 문서는 `native-viewer-editor`를 배포 직전 기준 브랜치로 쓰지 않으며, 필요한 release-critical fix만 별도 PR 또는 cherry-pick으로 후속 반영한다고 설명한다.

## 검증

Stage 4 작성 후 다음 검증을 수행했고 모두 통과했다.

```bash
git diff --check
rg -n "Swift native viewer|Swift native editor|Swift native viewer/editor|native viewer renderer|native renderer 장기|native viewer/editor work" \
  CONTRIBUTING.md .github/pull_request_template.md .github/copilot-instructions.md \
  mydocs/tech/branch_strategy_webview_native.md \
  mydocs/manual/git_workflow_guide.md mydocs/manual/pr_process_guide.md \
  mydocs/manual/release_policy_guide.md mydocs/manual/release_distribution_guide.md \
  mydocs/manual/ci_workflow_guide.md
rg -n "HostApp native macOS shell|Skia 공통 기반|Rust/rhwp Skia|Swift 편집 UI|Skia viewport" \
  CONTRIBUTING.md .github/pull_request_template.md .github/copilot-instructions.md \
  mydocs/tech/branch_strategy_webview_native.md \
  mydocs/manual/git_workflow_guide.md mydocs/manual/pr_process_guide.md \
  mydocs/manual/release_policy_guide.md mydocs/manual/release_distribution_guide.md \
  mydocs/manual/ci_workflow_guide.md
```

첫 번째 `rg`는 의도대로 결과가 없어서 exit code 1을 반환했다. workflow YAML을 수정하지 않았으므로 YAML 문법 검증은 제외한다. 코드와 RustBridge를 수정하지 않았으므로 Xcode build, render smoke, Rust bridge build는 이번 단계에서 제외한다.

## 리스크

- `branch_strategy_webview_native.md`에는 Task #244 전환 runbook과 첫 출시 전 기록이 함께 남아 있다. 현재 운영 기준은 문서 상단의 현재 결정과 외부 기여 PR base 기준을 우선한다.
- `native-viewer-editor`의 새 역할은 문서 정책이며 실제 HostApp Skia renderer/editor overlay 구현은 아직 별도 이슈가 필요하다.
- CoreGraphics/CoreText renderer는 현행 Quick Look/Thumbnail/PDF fallback/diagnostic 경로이므로 release note와 contributor 안내에서 제거 대상으로 읽히지 않게 유지해야 한다.

## 승인 요청

Stage 4 문서 갱신을 완료했다. 이 보고서 기준으로 Stage 5 문서 일관성 검증, 최종 보고서 작성, PR 게시 준비를 진행하려면 작업지시자 승인이 필요하다.
