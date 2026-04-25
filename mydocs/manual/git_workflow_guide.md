# Git 워크플로우 매뉴얼

본 매뉴얼은 본 저장소의 브랜치 정책, Git 워크플로우 다이어그램, 메인테이너/컨트리뷰터 워크플로우 스크립트를 정의한다.

## 브랜치 관리

| 브랜치 | 용도 |
|--------|------|
| `main` | 최종 릴리즈. 태그(v0.5.0 등)로 안정 버전 보존 |
| `devel` | 개발 통합 |
| `local/task{num}` | 타스크별 작업 |
| `publish/task{num}` | `devel` 대상 PR 생성을 위한 원격 게시 브랜치. PR merge 후 삭제 |

## Git 워크플로우

```
local/task{N}  ──커밋──커밋──┐
local/task{N+1}──커밋──커밋──┤
                              ├─→ publish/task{N} push
                              │
                              ├─→ devel 대상 PR 생성 + 리뷰 + merge
                              │
                              ├─→ devel 누적
                              │
                              ├─→ main PR 생성 + 리뷰 + merge + 태그 (릴리즈 시점)
```

- **타스크 브랜치**: `local/task{N}`에서 잘게 커밋. 작업 단위마다 커밋.
- **원격 게시 브랜치**: `local/task{N}` 작업이 리뷰 가능한 상태가 되면 `publish/task{N}` 이름으로 원격에 push하고 `devel` 대상 PR을 생성한다.
- **원격 push**: `local/task` 브랜치는 **로컬 유지 (원격 push 금지)**를 원칙으로 한다. 원격에는 `publish/task{N}`와 merge 결과 브랜치만 유지한다.
- **devel 대상 PR**: 작업 단위 PR은 기본적으로 draft로 생성하고, 최종 보고와 검증 결과를 PR 본문에 반영한 뒤 review/merge 한다.
- **merge 전략**: `devel` 대상 PR은 merge commit 유지 또는 `--no-ff` 원칙을 기본으로 한다. squash merge는 단계별 커밋 의미가 사라질 수 있으므로 기본값으로 두지 않는다.
- **main merge (PR 기반)**: 릴리즈 시점에 `devel` → `main` PR 생성 → 리뷰(approve) → merge 후 태그 생성.

## 메인테이너 워크플로우

```bash
# 1. local/taskN → publish/taskN push + devel 대상 draft PR
git checkout local/task17
git push origin local/task17:publish/task17
gh pr create --base devel --head publish/task17 --draft --title "Task #17: 제목" --template .github/pull_request_template.md

# 2. devel 대상 PR 리뷰 + merge
gh pr review --approve
gh pr merge --merge --delete-branch

# 3. devel → main PR (릴리즈 시)
gh pr create --base main --head devel --title "Release: 제목"
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

# 3. 원본 저장소의 devel로 PR 생성
gh pr create --repo postmelee/alhangeul-macos --base devel --head {contributor}:feature/my-task --title "제목"

# 4. 메인테이너가 리뷰 + merge
```
