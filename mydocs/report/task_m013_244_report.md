# Task M013 #244 최종 보고서

## 개요

| 항목 | 값 |
|------|----|
| 이슈 | [#244 devel을 제품 기여 기본 브랜치로 승격하고 native 라인을 분리](https://github.com/postmelee/alhangeul-macos/issues/244) |
| 마일스톤 | M013 `하이퍼-워터폴 작업환경 조성` |
| 작업 브랜치 | `local/task244` |
| 대상 브랜치 | `devel` |
| 제품 개발 브랜치 | `devel` |
| native 장기 브랜치 | `native-viewer-editor` |
| legacy alias | `devel-webview` |

## 최종 결과

`devel-webview`에 누적된 제품/배포 라인을 `devel`로 승격했고, 기존 `devel`의 Swift native viewer/editor 장기 라인은 `native-viewer-editor`로 보존했다.

원격 전환 후 `origin/devel`과 `origin/devel-webview`는 같은 제품 후보 commit을 가리킨다. `devel-webview`는 기존 링크와 자동화 호환을 위한 legacy alias로 유지했다.

| 브랜치 | 최종 head | 역할 |
|--------|-----------|------|
| `origin/devel` | `ae3f6da95447d87689766285f328bb9689f228c8` | 제품 개발과 일반 기여 기본 브랜치 |
| `origin/devel-webview` | `ae3f6da95447d87689766285f328bb9689f228c8` | 전환 기간 legacy alias |
| `origin/native-viewer-editor` | `d51ad1647db281b2a8be3175eec5a723d340d8fd` | 기존 `devel` native viewer/editor 장기 라인 |
| `origin/main` | `ccc3806a9315c89747b3c1d33a596751dfb0d048` | release/tag 기준 브랜치 |

## 주요 결정

| 항목 | 결정 |
|------|------|
| 기존 `devel` 처리 | 제품 라인에 직접 merge하지 않고 `native-viewer-editor`로 보존 |
| 새 제품 `devel` 기준 | `origin/devel-webview`를 first parent로 두고 `origin/main` release 후속 기록을 merge |
| `devel-webview` 처리 | 삭제하지 않고 `origin/devel`과 같은 commit을 가리키는 legacy alias로 유지 |
| PR base 안내 | 제품/배포/문서는 `devel`, Swift native viewer/editor는 `native-viewer-editor` |
| release publish 기준 | `main` tag 기준 유지 |

## 변경 요약

- `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `.github/copilot-instructions.md`에서 일반 제품 기여 기본 브랜치를 `devel`로 정렬했다.
- `.github/pull_request_template.md`에 PR base 선택 기준을 추가했다.
- `.github/workflows/pr-ci.yml`에 `native-viewer-editor` pull request trigger를 추가하고 `devel-webview`는 legacy alias 호환 trigger로 유지했다.
- `mydocs/manual/*`의 git/task/PR/release/CI 안내를 `devel`/`native-viewer-editor` 기준으로 수정했다.
- `mydocs/tech/branch_strategy_webview_native.md`에 Task #244 전환 정책, runbook, gate, 실행 결과 기준을 정리했다.
- README 상단과 CONTRIBUTING에 전환 전 fork/오래된 clone 사용자는 새 fork/clone 또는 최신 `origin/devel` 기준 새 작업 브랜치를 만들라는 안내를 추가했다.
- Stage 5에서 원격 branch migration을 `--atomic` push로 실행했다.
- 원격 전환 후 #244 작업 브랜치를 새 `origin/devel` 기준으로 병합했다.

## 단계별 요약

| 단계 | 보고서 | 요약 |
|------|--------|------|
| Stage 1 | [`task_m013_244_stage1.md`](../working/task_m013_244_stage1.md) | branch topology, 충돌 범위, 문서/workflow 참조 inventory 정리 |
| Stage 2 | [`task_m013_244_stage2.md`](../working/task_m013_244_stage2.md) | `native-viewer-editor` 보존 브랜치명 확정, 제품 `devel` 후보 원칙과 runbook 작성 |
| Stage 3 | [`task_m013_244_stage3.md`](../working/task_m013_244_stage3.md) | README, CONTRIBUTING, AGENTS, manual/tech 문서 정렬 |
| Stage 4 | [`task_m013_244_stage4.md`](../working/task_m013_244_stage4.md) | PR template과 PR CI branch filter 정렬 |
| Stage 5 | [`task_m013_244_stage5.md`](../working/task_m013_244_stage5.md) | 원격 전환 실행, 원격 ref 검증, 로컬 작업 브랜치 정렬 |
| Stage 6 | 본 보고서 | 최종 보고, 오늘할일 완료 처리, PR 게시 준비 |

## 원격 전환 명령

부분 전환을 남기지 않기 위해 다음 atomic push를 사용했다.

```bash
git push --atomic \
  --force-with-lease=refs/heads/native-viewer-editor: \
  --force-with-lease=refs/heads/devel-webview:69bcd486034d4c29d08436151f253d89980b543e \
  --force-with-lease=refs/heads/devel:d51ad1647db281b2a8be3175eec5a723d340d8fd \
  origin \
  origin/devel:refs/heads/native-viewer-editor \
  task244/product-devel-candidate:refs/heads/devel-webview \
  task244/product-devel-candidate:refs/heads/devel
```

## 검증

| 검증 | 결과 |
|------|------|
| `git fetch --prune origin` | 통과 |
| `git ls-remote --heads origin main devel devel-webview native-viewer-editor` | 네 원격 브랜치 head 확인 |
| `gh pr list --state open --base devel` | 열린 PR 없음 |
| `gh pr list --state open --base devel-webview` | 열린 PR 없음 |
| `git merge-base --is-ancestor origin/devel-webview origin/devel` | 통과 |
| `git merge-base --is-ancestor origin/main origin/devel` | 통과 |
| `git merge-base --is-ancestor origin/native-viewer-editor origin/devel` | 실패가 기대값. native 라인은 제품 라인에 직접 포함하지 않음 |
| `ruby -e 'ARGV.each { \|path\| require "psych"; Psych.parse_file(path); puts path }' .github/workflows/*.yml` | 통과. 로컬 Ruby `ffi-1.13.1` extension warning은 출력됐지만 YAML parse는 성공 |
| `for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done` | 통과 |
| `scripts/ci/classify-pr-changes.sh origin/devel HEAD` | `run_release_checks=true`, macOS/Rust/render smoke false |
| `git diff --check origin/devel...HEAD` | 통과 |
| 정책 참조 검색 | `devel`, `native-viewer-editor`, `devel-webview` legacy alias 참조 확인 |

## #243 영향 확인

별도 worktree의 `local/task243`은 새 `origin/devel`에 대한 가상 병합이 충돌 없이 통과했다. 기능 코드 충돌은 예상되지 않는다.

단, #243과 #244가 모두 `mydocs/orders/20260514.md`를 변경하므로 두 PR의 merge 순서에 따라 해당 문서에서만 충돌이 날 수 있다.

## 남은 수동 설정

| 항목 | 상태 |
|------|------|
| `native-viewer-editor` branch protection | 아직 unprotected. native 장기 라인 보호 규칙 적용 필요 |
| `devel-webview` legacy alias 삭제 여부 | 유지 중. 삭제 여부와 시점은 별도 승인 필요 |
| GitHub default branch | `main` 유지. 외부 기여 PR 기본 base를 더 강하게 유도하려면 `devel` 전환 여부 별도 판단 필요 |
| 전환 전 fork/clone | README와 CONTRIBUTING에 새 fork/clone 또는 최신 `origin/devel` 기준 새 작업 브랜치 생성 권장 안내 추가 |

## 미수행 범위

- Swift/Rust 제품 기능 구현
- WKWebView viewer/editor 기능 변경
- public release, tag 생성, GitHub Release 게시
- branch protection/default branch repository setting 변경
- `devel-webview` 삭제

## 다음 절차

작업지시자 승인 후 `publish/task244`를 원격에 push하고, `devel` 대상 PR을 생성한다.
