# Task #160 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#160 브랜치 전략 정리 및 README/자동화 기준 업데이트](https://github.com/postmelee/alhangeul-macos/issues/160) |
| 마일스톤 | M010 / v0.1.0 Viewer 기반 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task160` |
| 단계 수 | 4단계 |
| 결론 | WKWebView 첫 출시 기준 브랜치 전략을 tech 문서로 등록하고, README/CONTRIBUTING/GitHub review instruction/운영 매뉴얼의 브랜치 정책 표현을 정합화했다. |

첫 public release 전에는 브랜치 rename을 하지 않고, `devel-webview`를 v0.1.x 출시 준비 기준 브랜치로 유지한다. `devel`은 native viewer renderer와 장기 native viewer 실험/통합 브랜치로 유지한다. 실제 branch protection, default branch, CI/release workflow 설정 변경은 수행하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/tech/branch_strategy_webview_native.md` | 브랜치 역할, 단기 운영안, 출시 후 rename 후보, `devel-webview -> main` 체크리스트, PR base 기준, 자동화 점검 항목을 신규 문서화 |
| `README.md` | `devel-webview`를 v0.1.x 출시 우선 통합 브랜치로 명확히 하고 tech 문서 링크 추가 |
| `CONTRIBUTING.md` | PR base 선택 안내에 tech 문서 링크 추가 |
| `.github/copilot-instructions.md` | `devel` 단일 PR target 문구를 `devel-webview` 기본, native renderer는 `devel` 기준으로 수정 |
| `mydocs/manual/release_distribution_guide.md` | 브랜치 전략 문서 링크 추가, rollback 수정 PR base를 출시 대상 통합 브랜치 기준으로 수정 |
| `mydocs/manual/document_structure_guide.md` | 관련 매뉴얼 설명을 `devel-webview`/`devel` 분리 운용으로 수정 |
| `mydocs/manual/git_workflow_guide.md` | 브랜치 전략 문서 링크 추가 |
| `mydocs/manual/pr_process_guide.md` | 브랜치 전략 문서 링크 추가 |
| `mydocs/plans/task_m010_160.md` | 수행계획서 작성 |
| `mydocs/plans/task_m010_160_impl.md` | 구현계획서 작성 |
| `mydocs/working/task_m010_160_stage{1..4}.md` | 단계별 완료 보고서 작성 |
| `mydocs/orders/20260506.md` | 오늘할일 상태를 완료로 갱신 |

## 핵심 결정

| 항목 | 결정 |
|------|------|
| 첫 출시 기준 | `devel-webview`를 v0.1.x public release 준비 기준으로 사용 |
| release/tag 기준 | 검증된 `devel-webview` commit을 `main`에 반영한 뒤 `main`에서 tag와 GitHub Release 생성 |
| native renderer 라인 | `devel`을 native viewer renderer와 장기 native viewer 실험/통합 브랜치로 유지 |
| 첫 출시 전 rename | 수행하지 않음 |
| 출시 후 rename | 필요 시 후속 이슈에서 `devel-webview -> devel/develop`, 기존 `devel -> native-renderer/native-devel` 후보 검토 |
| 외부 기여 PR base | 일반/WKWebView/배포/문서는 `devel-webview`, native renderer는 `devel` |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `e029f1f` | 수행계획서와 오늘할일 항목을 작성했다. |
| Stage 1 | `ffc1daf` | remote branch 상태와 문서 불일치를 조사했다. 수정 필수 3곳을 분류했다. |
| Stage 2 | `035b967` | `mydocs/tech/branch_strategy_webview_native.md`를 신규 작성했다. |
| Stage 3 | `64c5f8f` | README/CONTRIBUTING/GitHub review instruction/운영 매뉴얼을 tech 문서 기준으로 정합화했다. |
| Stage 4 | 이번 최종 보고 커밋 | 최종 검색, diff 검증, Stage 4 보고서, 최종 보고서, 오늘할일 완료 처리를 정리했다. |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| branch 상태 조사 | OK | `origin/main...origin/devel-webview` = `6 / 232`, `origin/devel...origin/devel-webview` = `22 / 69` 확인 |
| 브랜치 정책 표현 검색 | OK | README, CONTRIBUTING, `.github`, `mydocs/manual`, `mydocs/tech`의 branch/PR base 표현 확인 |
| 충돌 문구 검색 | OK | `PRs normally target devel`, `수정 PR을 devel`, `devel 브랜치 운용` 검색 결과 없음 |
| tech 문서 핵심 용어 검색 | OK | `devel-webview`, `devel`, `main`, PR base, 통합 브랜치, 출시 대상 표현 확인 |
| `git diff --check` | OK | whitespace error 없음 |
| `git status --short --branch` | OK | 최종 검증 시점 기준 Stage 4 보고서/최종 보고서/오늘할일 변경만 미커밋 상태로 표시됨. 해당 변경은 최종 단계 커밋에 포함한다. |

문서 전용 작업이므로 Xcode build, Rust bridge build, Finder/Quick Look smoke test는 수행하지 않았다.

## 잔여 위험과 후속 작업

| 구분 | 내용 |
|------|------|
| GitHub 설정 | branch protection, default branch, CI/release workflow branch filter는 실제 변경하지 않았다. 필요 시 별도 이슈로 점검한다. |
| 브랜치 이름 | `devel-webview`는 장기 주 작업 브랜치로 보이지 않을 수 있고, `devel`은 일반 개발 브랜치로 오해될 수 있다. 첫 public release 후 rename 여부를 별도 판단한다. |
| release PR | `main`에는 `devel-webview`에 없는 README/banner 전용 commit이 있다. 실제 `devel-webview -> main` release PR에서 보존/대체 여부를 확인해야 한다. |
| release-critical 동기화 | `devel-webview`에 들어간 release-critical 수정이 native renderer 장기 브랜치에도 필요하면 별도 PR 또는 cherry-pick으로 `devel`에 반영한다. |

## 작업지시자 승인 요청

Task #160은 브랜치 전략 tech 문서 등록과 README/운영 문서 정합화를 완료했다. 다음 단계는 `publish/task160` 브랜치 push와 `devel-webview` 대상 PR 생성 승인이다.
