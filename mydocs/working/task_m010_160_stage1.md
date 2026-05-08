# Task #160 Stage 1 보고서

## 단계 목적

WKWebView 첫 출시 기준 브랜치와 native renderer 실험 브랜치를 분리하는 현재 정책이 실제 remote branch 상태와 문서 표현에 어떻게 반영되어 있는지 재조사한다. Stage 2 이후 작성할 tech 문서와 운영 문서 보정 범위를 확정하는 것이 목적이다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m010_160_impl.md` | Stage 1-4 구현 단계, 검증, 커밋 단위 확정 |
| `mydocs/working/task_m010_160_stage1.md` | 브랜치 현황, 문서 불일치, 수정 분류 결과 정리 |
| `mydocs/orders/20260506.md` | Task #160 상태를 Stage 1 보고 승인 대기로 갱신 |

## 조사 범위

| 대상 | 확인 내용 |
|------|----------|
| `origin/main` | release/tag 기준 브랜치와 `origin/devel-webview` 대비 전용 commit |
| `origin/devel-webview` | WKWebView 첫 출시 작업과 배포 준비 기준 브랜치 상태 |
| `origin/devel` | native renderer 관련 전용 commit과 실험/장기 개발 브랜치 상태 |
| `README.md` | 공개 요약의 branch/PR base 안내 |
| `CONTRIBUTING.md` | 외부 기여 PR base 안내 |
| `.github/copilot-instructions.md` | review instruction의 PR target 안내 |
| `mydocs/manual` | git/pr/release/document/task workflow branch 표현 |
| `mydocs/tech` | core dependency, architecture, roadmap의 branch 표현 |

## 브랜치 현황

최신 `git fetch origin` 이후 remote-tracking 기준은 다음과 같다.

| 비교 | left 전용 | right 전용 | 판단 |
|------|-----------|------------|------|
| `origin/main...origin/devel-webview` | 6 | 232 | `main`에는 README/banner 계열 전용 commit이 있고, `devel-webview`는 첫 출시 작업이 크게 앞서 있다. 출시 승격은 PR에서 main 전용 변경 보존/대체를 확인해야 한다. |
| `origin/devel...origin/devel-webview` | 22 | 69 | 두 통합 브랜치는 분기 상태다. `devel`은 native renderer 작업을 보유하고, `devel-webview`는 WKWebView/출시 준비 작업을 보유한다. |

`origin/HEAD`는 현재 `origin/main`을 가리킨다. GitHub 기본 브랜치가 `main`이어도 외부 기여 PR은 `main`으로 보내지 않는다는 CONTRIBUTING 정책과 일치한다.

### `origin/main` 전용 commit

```text
359ce0f Change home banner image in README
b0d250f Add files via upload
723c1a0 Update README formatting and title alignment
7478b45 Update README with improved structure and content
c697dbf Update README formatting and content for clarity
b84f9b1 Merge pull request #75 from postmelee/devel
```

출시 전 `devel-webview -> main` PR에서는 이 README/banner 변경이 의도적으로 보존되는지 확인해야 한다.

### `origin/devel` 전용 commit 성격

`origin/devel` 전용 non-merge commit은 Task #119 font fallback과 Task #123 native renderer/body overflow replay/clip 정책 중심이다. 이는 `devel`을 native renderer와 장기 viewer 실험 브랜치로 두려는 정책과 맞다.

대표 commit:

```text
00e37ac Potential fix for pull request finding
86994d2 Task #123 Stage 6 + 최종 보고서: 양쪽 브랜치 적용 검증
ed3c101 Task #123 Stage 5: devel 렌더러 통합 검증
0a14b41 Task #123 Stage 4: TableCell clip 정책 보강
3596703 Task #119: devel font resource 배치 보강
```

### `origin/devel-webview` 전용 commit 성격

`origin/devel-webview` 전용 non-merge commit은 Task #134 WKWebView viewer MVP, Task #142/#144/#153 HostApp viewer 문서 동작과 drag/drop, Task #154 Alhangeul identity 정리 중심이다. 이는 v0.1.x 첫 출시 기준 브랜치 역할과 맞다.

대표 commit:

```text
6c6bd38 Task #154 Stage 5 + 최종 보고서: Alhangeul identity 통일 완료
fc345eb Task #153: 최종 보고서 작성과 오늘할일 완료 처리
2d134d3 Task #154 Stage 4: 문서와 smoke 기준을 Alhangeul로 갱신
7e3d5c2 Task #134: WKWebView viewer MVP progress
58af4a8 Task #134: WKWebView MVP 문서와 브랜치 정책 갱신
```

## 문서 표현 분류

### 수정 필수

| 파일 | 현재 표현 | 판단 |
|------|-----------|------|
| `.github/copilot-instructions.md` | `PRs normally target devel` | 현재 정책과 충돌한다. 기본 target은 `devel-webview`, native renderer만 `devel`로 수정해야 한다. |
| `mydocs/manual/release_distribution_guide.md` | rollback 수정 PR을 `devel`로 merge | 같은 문서 앞부분은 v0.1.x 배포 기준을 `devel-webview`로 정하고 있으므로 충돌한다. "출시 대상 통합 브랜치, 현재 v0.1.x는 `devel-webview`" 기준으로 수정해야 한다. |
| `mydocs/manual/document_structure_guide.md` | 관련 매뉴얼 설명이 `devel` 브랜치 운용만 언급 | `devel-webview`/`devel` 분리 운용으로 수정해야 한다. |

### 요약 보정

| 파일 | 현재 상태 | Stage 3 보정 방향 |
|------|-----------|------------------|
| `README.md` | branch 역할과 PR base가 대체로 맞다. | 새 tech 문서 링크와 "첫 출시 기준은 `devel-webview`" 요약을 더 선명하게 둔다. |
| `CONTRIBUTING.md` | 외부 기여 PR base 안내가 맞다. | native renderer가 아닌 일반 작업의 기본 base가 `devel-webview`임을 유지하고 tech 문서 링크를 보강한다. |
| `mydocs/manual/git_workflow_guide.md` | 통합 브랜치 정의와 예시가 맞다. | Stage 2 tech 문서가 생기면 관련 문서 링크를 추가할지 검토한다. |
| `mydocs/manual/pr_process_guide.md` | 내부 PR base 기준과 예시가 맞다. | Stage 2 tech 문서가 생기면 관련 문서 링크를 추가할지 검토한다. |

### 참고 유지

| 파일 | 표현 | 유지 이유 |
|------|------|----------|
| `mydocs/manual/core_dependency_operation_guide.md` | `main`, `devel` 같은 branch는 dependency 안정 기준이 아님 | 저장소 통합 브랜치 정책이 아니라 Rust core dependency pinning 정책이다. |
| `mydocs/tech/core_release_compatibility.md` | branch/floating ref, `origin/devel` 예시 | dependency 안정성 문맥의 예시이므로 수정 대상이 아니다. |
| `mydocs/tech/product_roadmap_notes.md` | upstream `edwardkim/rhwp`의 `devel-webview` branch 언급 | upstream rhwp-studio 기준 기록이라 유지한다. |
| `mydocs/manual/build_run_guide.md` | branch/floating ref 금지 | core dependency 검증 문맥이라 유지한다. |

## 결정 사항

- 첫 출시 전에는 branch rename을 하지 않는 방향으로 Stage 2 tech 문서에 정리한다.
- `devel-webview`는 v0.1.x 출시 우선 통합 브랜치로 설명한다.
- `devel`은 native viewer renderer와 장기 native viewer 실험/통합 브랜치로 설명한다.
- `devel`이라는 이름이 일반적인 주 개발 브랜치처럼 읽히는 리스크는 tech 문서에 별도로 남긴다.
- 출시 후 rename 후보는 후속 판단으로 남긴다. 후보 예시는 `devel-webview -> devel/develop`, 기존 `devel -> native-renderer/native-devel`이다.

## 검증 결과

실행 명령:

```bash
git fetch origin
git rev-list --left-right --count origin/main...origin/devel-webview
git rev-list --left-right --count origin/devel...origin/devel-webview
git log --oneline --decorate origin/devel-webview..origin/main
git log --oneline --decorate --no-merges origin/devel-webview..origin/devel
git log --oneline --decorate --no-merges origin/devel..origin/devel-webview --max-count 80
rg -n 'devel-webview|devel|main|PR base|base branch|통합 브랜치|릴리즈 기준|출시 대상|branch|브랜치' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
rg -n 'PRs normally target|수정 PR을 `devel`|devel 브랜치 운용|origin/devel|BASE_BRANCH=devel|base devel|--base devel|target `devel`' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
git branch -r -vv
git symbolic-ref refs/remotes/origin/HEAD
```

결과:

- branch count와 전용 commit 목록 확인 완료
- 수정 필수 문구 3곳 확인
- README/CONTRIBUTING/git/pr workflow의 기본 분리 정책은 대체로 일치
- core dependency branch/floating ref 문맥은 이번 task의 수정 대상이 아님

Stage 보고서 작성 후 검증:

```bash
git diff --check -- mydocs/orders/20260506.md mydocs/plans/task_m010_160_impl.md mydocs/working/task_m010_160_stage1.md
```

결과는 커밋 전 확인한다.

결과:

```text
통과. 출력 없음.
```

## 잔여 위험

- `devel-webview` 이름은 계속 임시 WebView 전환 브랜치처럼 보일 수 있다.
- `devel` 이름은 일반 개발 브랜치처럼 보일 수 있어 외부 기여자가 잘못된 PR base를 고를 수 있다.
- release PR 시 `main` 전용 README/banner commit 처리 방향이 명확하지 않으면 `main`의 현재 표시가 의도치 않게 바뀔 수 있다.
- 운영 문서가 여러 곳에 branch 기준을 반복하므로 Stage 3에서 한 곳이라도 빠지면 다시 불일치가 생길 수 있다.

## 다음 단계 영향

Stage 2에서는 `mydocs/tech/branch_strategy_webview_native.md`를 새 진실 원천으로 작성한다. Stage 3에서는 이 문서를 기준으로 README, CONTRIBUTING, `.github/copilot-instructions.md`, release/document workflow 문서를 보정한다.

## 승인 요청

Stage 1 조사는 완료했다. 이 보고서 기준으로 Stage 2 tech 문서 작성에 진입할지 승인 요청한다.
