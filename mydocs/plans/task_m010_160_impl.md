# Task #160 구현 계획서

본 문서는 [`task_m010_160.md`](task_m010_160.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/private/tmp/rhwp-mac-task160`
- **Branch**: `local/task160`
- **기준 브랜치**: `devel-webview`
- **기준 이슈**: [#160](https://github.com/postmelee/alhangeul-macos/issues/160)
- **범위**: WKWebView 첫 출시 기준 브랜치 전략과 문서/자동화 기준 정합화

## 확정 전제

- v0.1.x 첫 public release 준비 기준 브랜치는 `devel-webview`다.
- `main`은 릴리즈와 tag 기준 브랜치로 유지한다.
- `devel`은 native viewer renderer와 장기 native viewer 실험/통합 브랜치로 유지한다.
- 외부 기여 PR base는 작업 범위에 따라 `devel-webview` 또는 `devel`로 나눈다.
- 첫 출시 전 실제 브랜치 rename, GitHub default branch 변경, branch protection 변경은 수행하지 않는다.
- 출시 후 브랜치 rename 또는 역할 재정의가 필요하면 후속 이슈로 분리한다.

## Stage 1 — 브랜치 현황과 문서 불일치 재조사

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/plans/task_m010_160_impl.md` | 구현 단계, 검증, 커밋 단위 확정 | 구현 계획서 |
| `mydocs/working/task_m010_160_stage1.md` | branch 상태, 문서 불일치, 수정 분류 결과 정리 | 조사 보고서 |
| `mydocs/orders/20260506.md` | Task #160 상태를 Stage 1 보고 승인 대기로 갱신 | 오늘할일 |

### 조사 항목

- `origin/main...origin/devel-webview` ahead/behind
- `origin/devel...origin/devel-webview` ahead/behind
- `origin/main` 전용 commit 목록
- `origin/devel` 전용 native renderer 관련 commit 목록
- `origin/devel-webview` 전용 WKWebView/출시 준비 관련 commit 목록
- README, CONTRIBUTING, `.github`, `mydocs/manual`, `mydocs/tech`의 branch/base 표현

### 분류 기준

| 분류 | 기준 |
|------|------|
| 수정 필수 | 현재 정책과 직접 충돌하거나 잘못된 PR base/rollback base를 안내하는 문구 |
| 요약 보정 | 정책은 맞지만 tech 문서 진실 원천과 연결하거나 출시 기준을 더 선명하게 해야 하는 문구 |
| 참고 유지 | branch/floating ref 금지, core dependency 예시처럼 이번 branch 전략과 다른 문맥의 문구 |

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task160
git fetch origin
git rev-list --left-right --count origin/main...origin/devel-webview
git rev-list --left-right --count origin/devel...origin/devel-webview
rg -n 'devel-webview|devel|main|PR base|base branch|통합 브랜치|릴리즈 기준|출시 대상|branch|브랜치' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
git diff --check -- mydocs/orders/20260506.md mydocs/plans/task_m010_160_impl.md mydocs/working/task_m010_160_stage1.md
```

### 커밋

```text
Task #160 Stage 1: 브랜치 전략 문서 불일치 조사
```

## Stage 2 — tech 문서 작성

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/tech/branch_strategy_webview_native.md` | branch 전략 진실 원천 신규 작성 | 핵심 산출물 |
| `mydocs/working/task_m010_160_stage2.md` | tech 문서 작성 결과와 판단 근거 보고 | 단계 보고서 |

### 문서 목차

- 목적과 현재 결정
- 현재 branch 상태 요약
- branch별 역할
- 첫 출시 전 단기 운영안
- 출시 후 장기 선택지
- `devel-webview -> main` 승격 체크리스트
- 외부 기여 PR base 기준
- 배포 자동화와 branch protection 점검 항목
- 후속 이슈 후보

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task160
rg -n 'devel-webview|devel|main|PR base|통합 브랜치|출시 대상' \
  mydocs/tech/branch_strategy_webview_native.md
git diff --check -- mydocs/tech/branch_strategy_webview_native.md mydocs/working/task_m010_160_stage2.md
```

### 커밋

```text
Task #160 Stage 2: WebView/native 브랜치 전략 문서화
```

## Stage 3 — README/CONTRIBUTING/운영 문서 정합화

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `README.md` | branch 전략 요약과 tech 문서 링크 보정 | 필요 최소 |
| `CONTRIBUTING.md` | PR base 안내와 tech 문서 링크 보정 | 필요 최소 |
| `.github/copilot-instructions.md` | `devel` 단일 target 문구를 범위별 base로 수정 | 수정 필수 |
| `mydocs/manual/release_distribution_guide.md` | rollback 수정 PR base를 출시 대상 통합 브랜치 기준으로 수정 | 수정 필수 |
| `mydocs/manual/document_structure_guide.md` | 관련 매뉴얼의 branch 표현을 `devel-webview`/`devel` 분리로 수정 | 수정 필수 |
| 필요 시 `mydocs/manual/git_workflow_guide.md` | tech 문서 링크 또는 표현 보정 | 조사 결과 기준 |
| 필요 시 `mydocs/manual/pr_process_guide.md` | tech 문서 링크 또는 표현 보정 | 조사 결과 기준 |
| `mydocs/working/task_m010_160_stage3.md` | 문서 정합화 결과 보고 | 단계 보고서 |

### 보정 원칙

- 정책 세부 설명은 `mydocs/tech/branch_strategy_webview_native.md`로 연결한다.
- README/CONTRIBUTING은 외부 독자가 잘못된 PR base를 고르지 않도록 요약만 유지한다.
- release rollback은 "`출시 대상 통합 브랜치`, 현재 v0.1.x는 `devel-webview`" 기준으로 쓴다.
- core dependency 문서의 `main`, `devel`, `origin/devel` branch/floating ref 예시는 이번 branch 운용 정책이 아니라 dependency 안정성 문맥이므로 유지한다.

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task160
rg -n 'PRs normally target `devel`|수정 PR을 `devel`|`devel` 브랜치 운용' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
rg -n 'branch_strategy_webview_native|devel-webview|native viewer renderer|출시 대상 통합 브랜치' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
git diff --check
```

첫 번째 `rg`는 실패 기대 검색이다. 출력이 있으면 같은 단계에서 보정한다.

### 커밋

```text
Task #160 Stage 3: 브랜치 정책 문서 정합화
```

## Stage 4 — 문서 검증과 최종 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m010_160_stage4.md` | 최종 문서 검증 결과 보고 | 단계 보고서 |
| `mydocs/report/task_m010_160_report.md` | 최종 결과보고서 작성 | 최종 보고 |
| `mydocs/orders/20260506.md` | Task #160 완료 처리 | 오늘할일 |

### 최종 검증

```bash
cd /private/tmp/rhwp-mac-task160
rg -n 'devel-webview|devel|main|PR base|base branch|통합 브랜치|릴리즈 기준|출시 대상|branch|브랜치' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
rg -n 'PRs normally target `devel`|수정 PR을 `devel`|`devel` 브랜치 운용' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
git diff --check
git status --short --branch
```

문서 전용 작업이므로 Xcode build, Rust bridge build, Finder/Quick Look smoke test는 수행하지 않는다.

### 커밋

```text
Task #160 Stage 4 + 최종 보고서: 브랜치 전략 문서 정합화 완료
```

## 승인 요청 사항

이 구현 계획과 Stage 1 보고서 기준으로 Stage 2 tech 문서 작성에 진입할지 승인 요청한다.
