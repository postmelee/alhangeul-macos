# Git 워크플로우 매뉴얼

본 매뉴얼은 본 저장소의 브랜치 정책, Git 워크플로우 다이어그램, 메인테이너/컨트리뷰터 워크플로우 스크립트를 정의한다. 새 타스크 브랜치를 만들거나 PR 게시·merge·정리를 수행하기 전에 읽는다. 문서 파일 위치와 타스크 승인 절차는 각각 `document_structure_guide.md`, `task_workflow_guide.md`에서 다룬다.

제품 기본 브랜치와 native 전환 라인의 판단 근거는 [`branch_strategy_webview_native.md`](../tech/branch_strategy_webview_native.md)를 기준으로 한다.

## 2026-05-14 브랜치 전환 안내

2026-05-14에 제품 개발 기본 브랜치를 `devel`로 승격했다. 전환 전 fork나 오래된 clone을 기준으로 새 작업을 시작하지 말고, 새 fork/clone 또는 최신 `origin/devel`에서 새 작업 브랜치를 만든다.

기존 `devel` head는 `native-viewer-editor`로 보존했다. `devel-webview`에 남아 있던 #243 변경은 2026-05-16에 `devel`로 병합했으며, `devel-webview`는 퇴역한 legacy alias로 신규 PR base나 자동화 기준으로 사용하지 않는다.

## 핵심 용어

- **통합 브랜치**: 작업 범위에 따라 PR이 모이는 기준 브랜치. 첫 공개 배포, WKWebView-backed viewer/editor, Finder/Quick Look, PDF/공유/저장, Spotlight/mdimporter, 변환, 배포, 문서, Skia 공통 기반은 `devel`을 기본으로 쓰고, HostApp native macOS shell, Skia viewport, Swift 편집 UI/오버레이 작업은 `native-viewer-editor`를 쓴다.
- **`devel`**: 일반 제품 개발과 외부 기여 기본 통합 브랜치.
- **`native-viewer-editor`**: HostApp native macOS shell, Rust/rhwp Skia renderer 연동, Swift 편집 UI/오버레이 장기 작업 통합 브랜치.
- **`devel-webview`**: 퇴역한 legacy alias. 신규 PR base나 자동화 기준으로 쓰지 않는다.
- **`local/taskN`**: 이슈 번호 N의 로컬 작업 브랜치. 단계 커밋과 보고서 커밋은 이 브랜치에 쌓는다.
- **`publish/taskN`**: `local/taskN`을 원격에 게시하기 위한 PR용 브랜치. PR merge 후 삭제한다.
- **Open PR**: 검토 가능한 상태의 PR. 하이퍼-워터폴 최종 보고 후 작업 범위에 맞는 통합 브랜치 대상으로 만든다.
- **분리 worktree**: 메인 worktree가 다른 작업에 쓰이고 있을 때 별도 디렉터리에서 같은 저장소의 다른 브랜치를 작업하는 방식.

## 브랜치 관리

| 브랜치 | 용도 |
|--------|------|
| `main` | 최종 릴리즈. 태그로 안정 버전 보존 |
| `devel` | 첫 공개 배포, WKWebView-backed viewer/editor, Finder/Quick Look, PDF/공유/저장, Spotlight/mdimporter, 변환, 배포, Skia 공통 기반 작업 통합 |
| `native-viewer-editor` | HostApp native macOS shell, Rust/rhwp Skia renderer 연동, Swift 편집 UI/오버레이 장기 작업 통합 |
| `devel-webview` | 퇴역한 legacy alias. 신규 작업과 자동화 기준으로 사용하지 않음 |
| `local/task{num}` | 타스크별 작업 |
| `publish/task{num}` | 통합 브랜치 대상 PR 생성을 위한 원격 게시 브랜치. PR merge 후 삭제 |

## Git 워크플로우

```
local/task{N} ── 커밋 · 커밋 · 커밋 ──→ publish/task{N} push
                                          │
                                          └─→ 통합 브랜치 대상 PR → 리뷰 → merge
                                                                       │
                                                                       └─→ 통합 브랜치 누적
                                                                              │
                                                                              └─→ main PR (릴리즈 시점) → 태그
```

병렬 task는 각각 독립적인 `local/task{N}` 브랜치로 위 흐름을 반복한다.

- **타스크 브랜치**: `local/task{N}`에서 잘게 커밋. 작업 단위마다 커밋.
- **원격 게시 브랜치**: `local/task{N}` 작업이 리뷰 가능한 상태가 되면 `publish/task{N}` 이름으로 원격에 push하고 작업 범위에 맞는 통합 브랜치 대상 PR을 생성한다.
- **원격 push**: `local/task` 브랜치는 **로컬 유지 (원격 push 금지)**를 원칙으로 한다. 원격에는 `publish/task{N}`와 merge 결과 브랜치만 유지한다.
- **통합 브랜치 대상 PR**: 작업 단위 PR은 기본적으로 Open PR로 생성하고, 최종 보고와 검증 결과를 PR 본문에 반영한 상태에서 review/merge 한다.
- **merge 전략**: 통합 브랜치 대상 PR은 merge commit 유지 또는 `--no-ff` 원칙을 기본으로 한다. squash merge는 단계별 커밋 의미가 사라질 수 있으므로 기본값으로 두지 않는다.
- **main merge (PR 기반)**: 릴리즈 시점에 출시 대상 통합 브랜치 → `main` PR 생성 → 리뷰(approve) → merge 후 태그 생성.

## 메인테이너 워크플로우

```bash
# 1. local/taskN → publish/taskN push + 통합 브랜치 대상 Open PR
git checkout local/task17
BASE_BRANCH=devel # HostApp native shell/overlay 작업이면 native-viewer-editor
git push origin local/task17:publish/task17
gh pr create --base "$BASE_BRANCH" --head publish/task17 --title "Task #17: 제목" --body-file /tmp/task17-pr-body.md

# 2. 통합 브랜치 대상 PR 리뷰 + merge
gh pr review --approve
gh pr merge --merge --delete-branch

# 3. 출시 대상 통합 브랜치 → main PR (릴리즈 시)
gh pr create --base main --head "$BASE_BRANCH" --title "Release: 제목"
gh pr review --approve
gh pr merge --merge --delete-branch=false
```

## 컨트리뷰터 워크플로우 (Fork 기반)

```bash
# 1. 원본 저장소 Fork (GitHub에서 1회)
# 2. Fork한 저장소에서 작업
git clone https://github.com/{contributor}/alhangeul-macos.git
git checkout -b feature/my-task
# ... 작업 + 커밋 ...
git push origin feature/my-task

# 3. 원본 저장소의 통합 브랜치로 PR 생성
gh pr create --repo postmelee/alhangeul-macos --base devel --head {contributor}:feature/my-task --title "제목"

# 4. 메인테이너가 리뷰 + merge
```

컨트리뷰터 PR base도 작업 범위에 따라 고른다. 첫 공개 배포, WKWebView-backed viewer/editor, Finder/Quick Look, PDF/공유/저장, Spotlight/mdimporter, 변환, 배포, 문서, Skia 공통 기반은 `devel`, HostApp native macOS shell, Skia viewport, Swift 편집 UI/오버레이는 `native-viewer-editor`이다.

## FAQ / 흔한 실수

### 다른 에이전트와 메인 worktree가 충돌할 때

먼저 `git status --short --branch`로 현재 브랜치와 미커밋 변경을 확인한다. 다른 작업자의 변경이 있으면 되돌리지 말고, 새 작업은 분리 worktree에서 시작하는 쪽을 우선 검토한다. 이미 진행 중인 타스크와 같은 파일을 건드려야 한다면 작업지시자에게 충돌 범위를 공유하고 순서를 정한다.

### 통합 브랜치에 rebase가 필요해 보일 때

기본 흐름은 작업 범위에 맞는 통합 브랜치를 `git pull --ff-only`로 최신화하고, 새 `local/taskN` 브랜치를 최신 `origin/{통합브랜치}`에서 만드는 것이다. 진행 중인 작업 브랜치를 임의로 rebase하지 않는다. PR 충돌이나 오래된 기준 브랜치 문제가 생기면 먼저 `git fetch origin`과 충돌 파일 목록을 확인하고, rebase/merge 중 어떤 방식으로 회복할지 작업지시자 승인 후 진행한다.

### 잘못된 브랜치를 원격에 push했을 때

원격에 `local/taskN`을 직접 올렸거나 잘못된 이름으로 push한 경우 즉시 추가 push를 멈춘다. 아직 PR을 만들지 않았다면 올바른 `publish/taskN` 브랜치를 새로 push하고, 잘못 올라간 원격 브랜치는 작업지시자 확인 후 삭제한다. 이미 PR을 만들었다면 PR base/head와 diff를 확인한 뒤, 새 PR을 만들지 기존 PR head를 보정할지 결정한다.

### PR 본문에 문서 링크를 넣을 때

PR 본문에서 계획서, 최종 보고서, troubleshooting 문서를 링크할 때는 merge 후에도 열리는 commit SHA 고정 GitHub blob URL을 우선 사용한다. PR 생성 직전 `git rev-parse HEAD`로 얻은 PR head commit SHA를 기준으로 `https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/...` 형식을 사용하면 `publish/taskN` 브랜치 삭제 후에도 링크가 유지된다. 단계 보고서는 `작업 문서` 목록에 중복으로 넣지 않고 Stage별 요약의 Stage 제목에서 링크한다.

변경 내역의 작업 문서 항목은 raw URL이 아니라 `[파일명](URL)` 형식으로 작성한다. 예시는 다음과 같다.

```md
- 수행 계획서: [task_m010_61.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/plans/task_m010_61.md)
- 구현 계획서: [task_m010_61_impl.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/plans/task_m010_61_impl.md)
- 최종 보고서: [task_m010_61_report.md](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/report/task_m010_61_report.md)
```

Stage별 요약에서는 Stage 제목을 단계 보고서로 링크하고, 옆의 짧은 commit SHA를 commit URL로 링크한다. 예시는 다음과 같다.

```md
- **[Stage 1](https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/working/task_m010_61_stage1.md)** ([abc1234](https://github.com/postmelee/alhangeul-macos/commit/{stage1_sha})): PR 본문 문서 링크 조사
```

PR 본문 상대 링크, `blob/publish/taskN/...` 링크, URL만 그대로 노출하는 문서 링크는 merge 후 탐색성과 가독성을 떨어뜨리므로 사용하지 않는다.

### merge 후에도 로컬 브랜치가 남아 있을 때

PR이 `MERGED` 상태인지 먼저 확인한다. merge 확인 후 대상 통합 브랜치로 돌아와 최신화하고, 원격 `publish/taskN`과 로컬 `local/taskN`을 정리한다. 이 절차는 [`pr-merge-cleanup`](../skills/pr-merge-cleanup/SKILL.md) SKILL이 문서화한 순서를 따른다.

## 관련 매뉴얼

- [`task_workflow_guide.md`](task_workflow_guide.md): 이슈 기반 타스크 시작, 단계 승인, 최종 보고, PR 게시 순서.
- [`document_structure_guide.md`](document_structure_guide.md): 계획서, 단계 보고서, 최종 보고서의 문서 위치와 파일명.
- [`pr_process_guide.md`](pr_process_guide.md): 외부 기여자 PR 검토 절차.
- [`branch_strategy_webview_native.md`](../tech/branch_strategy_webview_native.md): WKWebView 출시 라인과 native renderer 실험 라인의 브랜치 역할.
