# Task M013 #244 Stage 3 보고서

## 단계 목적

Stage 2에서 확정한 브랜치 전환 정책을 외부 기여자 안내, 에이전트 지침, 내부 운영 매뉴얼에 반영했다.

이번 단계는 문서 정합화만 수행했고, 소스 코드, GitHub Actions workflow, 원격 브랜치, branch protection, default branch 설정은 변경하지 않았다.

## 반영한 기준

| 항목 | Stage 3 문서 기준 |
|------|-------------------|
| 제품 개발 기본 브랜치 | `devel` |
| native viewer/editor 장기 브랜치 | `native-viewer-editor` |
| `devel-webview` | 전환 기간 legacy alias. 신규 PR 기본 대상 아님 |
| release 기준 | 제품 `devel`의 검증 commit을 `main`으로 release PR 반영 |
| 일반 기여 PR base | 제품/배포/문서 작업은 `devel`, native viewer/editor 작업은 `native-viewer-editor` |

## 외부 기여자 문서 정렬

`README.md`와 `CONTRIBUTING.md`에서 다음 안내를 새 정책으로 바꿨다.

- 제품 기능, WKWebView viewer/editor, Finder/Quick Look, Mac 통합, 배포, 문서 작업의 PR base를 `devel`로 안내
- Swift native viewer/editor 관련 PR base를 `native-viewer-editor`로 안내
- `devel-webview`는 legacy alias이며 신규 PR 기본 대상이 아니라고 명시
- release PR은 제품 개발 브랜치에서 `main`으로 반영한다는 설명으로 정리

## 에이전트 지침 정렬

`AGENTS.md`와 `.github/copilot-instructions.md`에서 다음 내용을 반영했다.

- `publish/task{N}` PR 대상 후보를 `devel` 또는 `native-viewer-editor`로 수정
- Codex/Copilot 계열 에이전트가 `devel-webview`를 기본 PR base로 선택하지 않도록 legacy alias 문구 추가
- HostApp MVP 설명에서 upstream branch 이름을 직접 노출하지 않고 bundled `rhwp-studio` 기준으로 정리

## 운영 매뉴얼 정렬

| 파일 | 변경 |
|------|------|
| `mydocs/manual/git_workflow_guide.md` | 통합 브랜치 용어, branch table, maintainer/contributor PR 예시를 `devel`/`native-viewer-editor` 기준으로 수정 |
| `mydocs/manual/pr_process_guide.md` | 내부 task PR base와 `gh pr create` 예시 수정 |
| `mydocs/manual/task_workflow_guide.md` | 최종 PR 대상 통합 브랜치 후보 수정 |
| `mydocs/manual/document_structure_guide.md` | Git workflow 문서 설명의 브랜치 쌍 수정 |
| `mydocs/manual/release_policy_guide.md` | WebView-backed release line을 `devel` 기준으로 수정하고 native 후속 동기화 대상을 `native-viewer-editor`로 수정 |
| `mydocs/manual/release_distribution_guide.md` | `devel -> main` release PR 범위와 native 후속 반영 브랜치 수정 |
| `mydocs/manual/ci_workflow_guide.md` | PR CI 문서상 대상 브랜치 목록에 `native-viewer-editor`를 반영 |

## 브랜치 전략 문서 정리

`mydocs/tech/branch_strategy_webview_native.md`는 Stage 2 runbook을 유지하면서, 오래된 정책 문구가 현재 운영 기준처럼 보이지 않게 정리했다.

- 문서 제목과 목적을 제품 `devel` 승격 정책 중심으로 수정
- 현재 결정 섹션을 `devel`, `native-viewer-editor`, `devel-webview` legacy alias 기준으로 수정
- 2026-05-06 첫 출시 전 판단은 "기록" 섹션으로 분리
- release PR 체크리스트를 `devel -> main` 기준으로 수정
- 외부 기여 PR base 기준을 `devel`/`native-viewer-editor`로 수정
- 자동화와 보호 규칙 점검 항목에 `native-viewer-editor`와 `devel-webview` legacy alias를 반영

## 보류 항목

| 항목 | 보류 사유 |
|------|-----------|
| `.github/workflows/*` branch filter 변경 | Stage 4 범위로 분리 |
| 원격 `native-viewer-editor` 생성 | Stage 5 원격 전환 실행 승인 전에는 수행하지 않음 |
| 원격 `devel` 교체 | Stage 5에서 `--force-with-lease` 필요성을 재확인한 뒤 별도 승인으로만 수행 |
| GitHub branch protection/default branch 설정 | Stage 5 전환 후 수동 확인 항목 |

## 검증 결과

| 검증 | 결과 |
|------|------|
| 낡은 PR base 문구 검색 | 일반 안내와 운영 매뉴얼에서 낡은 `devel-webview` 기본 PR base 문구가 제거됨. 남은 `devel-webview` 직접 확인 예시는 원격 전환 runbook의 legacy/open PR gate 맥락 |
| `git diff --check` | 통과 |
| `git diff --stat` | 문서 변경 범위 확인 |
| `git status --short --branch` | #244 분리 worktree에서 문서 변경만 확인 |

## 다음 단계 제안

Stage 4에서는 GitHub Actions workflow branch filter와 관련 자동화 문구를 새 브랜치 정책에 맞게 정렬한다. Stage 4에서도 원격 브랜치 변경은 수행하지 않는다.

## 승인 요청

Stage 3 문서 정합화를 완료했다. 이 보고서 기준으로 Stage 4 workflow/automation branch filter 정렬을 진행해도 되는지 승인 요청한다.
