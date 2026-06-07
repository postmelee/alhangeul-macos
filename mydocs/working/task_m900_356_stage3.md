# Task M900 #356 Stage 3 완료보고서

## 단계 요약

`previous_release_ref..candidate_ref` 범위의 merge PR을 수집해 release record의 `포함 PR 분석` 표 초안을 만드는 helper를 추가했다.

이번 단계의 helper는 release owner의 판단을 대체하지 않는다. PR title/body, linked Issue, 최종 보고서 후보, 변경 path hint를 한곳에 모으고, 분류와 사용자-facing 여부는 모두 `확인 필요`로 남긴다.

## 변경 내용

| 파일 | 변경 |
|------|------|
| `scripts/ci/write-release-pr-analysis.sh` | 신규 helper 추가. 입력 ref 범위에서 merge PR 목록, first-parent release transport 후보, Issue 후보, 보고서 후보, path 기반 분류 hint를 Markdown 초안으로 출력 |
| `mydocs/working/task_m900_356_stage3.md` | Stage 3 완료보고서 추가 |

## helper 동작

`scripts/ci/write-release-pr-analysis.sh <previous-release-ref> <candidate-ref> <output-file>` 형식으로 실행한다.

출력 문서는 다음 section을 포함한다.

| section | 목적 |
|---------|------|
| `범위` | previous release ref, candidate ref, commit, repository 기록 |
| `포함 PR 분석` | PR, 제목, 분류 hint, 사용자-facing 확인값, 공개 요약 반영 확인값, 해결된 Issue 후보, 관련 Issue 후보, 근거 문서 후보, 비고 |
| `직접 반영된 PR과 Issue 후보` | GitHub Release body에 옮기기 전 release owner가 확인할 PR/Issue 후보 |
| `PR별 상세 후보` | merge commit, metadata 출처, report 후보, 변경 path preview |
| `release owner 보정 항목` | 사용자-facing 확정, 해결된 Issue 확정, 관련 Issue 분리, delta checklist 보조 사용 원칙 |

## 수집 기준

| 항목 | 기준 |
|------|------|
| 포함 PR | `git log --merges` subject의 `Merge pull request #N` 패턴 |
| release transport 후보 | `git log --first-parent --merges`에서 잡힌 PR 번호를 별도 표시 |
| PR metadata | `gh pr view` 사용 가능 시 title/body/files/merge commit 보강 |
| fallback | `gh` 사용 불가 시 git merge subject와 merge diff path 기반 초안 생성 |
| 해결된 Issue 후보 | PR body의 closing keyword가 붙은 Issue ref만 추출 |
| 관련 Issue 후보 | closing keyword가 없는 Issue ref, branch/task 번호 추론 후보 |
| 보고서 후보 | `mydocs/report/task_*_<issue>_report.md` 패턴 |
| 분류 hint | path/title 기반 후보만 표시하고 최종 분류는 `확인 필요` 유지 |

전역 후보 section에서는 해결된 Issue 후보와 관련 Issue 후보가 겹치지 않도록 관련 Issue 후보에서 해결된 Issue 후보를 한 번 더 제외한다.

## v0.1.5 dry-run 결과

`v0.1.4..v0.1.5` 범위에서 다음 후보가 생성되는 것을 확인했다.

| 확인 항목 | 결과 |
|-----------|------|
| 대표 포함 PR | `#324`, `#326`, `#329`, `#334`, `#349`, `#352`, `#353` 포함 확인 |
| first-parent release transport | `#353`, `#322`, `#321` 등 first-parent 후보 표시 |
| 사용자-facing 후보 hint | `#324`, `#326`, `#329`, `#334`가 사용자-facing 후보로 표시 |
| upstream sync 후보 hint | `#349`, `#353`이 upstream sync 후보로 표시 |
| 관련 Issue 후보 | `#116`, `#121`, `#122`, `#280`, `#282`, `#323`, `#351` 등 추출 |
| 보고서 후보 | `task_m014_110_report.md`, `task_m014_121_report.md`, `task_m014_122_report.md`, `task_m040_323_report.md` 등 확인 |
| 해결된 Issue 후보 | PR body closing keyword 기준으로 `#110`, `#132`, `#302`, `#332`, `#336`, `#348`, `#349` 등 후보 추출 |

## GitHub API 보강 경로

스크립트에는 `gh pr view` 기반 보강 경로를 넣었다. 이 경로가 동작하면 PR title/body/files/merge commit을 읽고 closing keyword 기반 해결된 Issue 후보를 더 정확히 채운다.

추가 검증에서 `gh auth status`와 대표 PR `#334` metadata 조회가 통과했다. 일반 sandbox에서는 helper의 `/bin/bash` 실행 중 `gh` network connection이 실패해 fallback으로 내려갔고, 승인 경로에서 전체 helper dry-run을 다시 실행해 PR body 기반 보강 경로를 검증했다.

승인 경로 dry-run에서는 `#334` 행이 `Task #110: FormObject 정적 프리뷰 보강` title, `PR body` 근거, 해결된 Issue `#110`, 관련 Issue `#116`, `#121`, `#122`, `#280`, `#282`로 출력되는 것을 확인했다. 이 검증 과정에서 해결된 Issue가 branch/task 번호 추론으로 관련 Issue에 중복 표시되는 문제를 발견했고, helper가 row 단위와 전역 후보 단위 모두에서 해결된 Issue를 관련 Issue에서 제외하도록 보강했다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `gh auth status` | 통과 | `postmelee` 계정 인증 확인 |
| `gh pr view 334 --repo postmelee/alhangeul-macos --json number,title,body,files,mergeCommit` | 통과 | PR body, file list, merge commit 조회 |
| `bash -n scripts/ci/write-release-pr-analysis.sh` | 통과 | shell syntax 오류 없음 |
| `scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5.md` | 통과 | fallback Markdown 초안 생성 |
| 승인 경로 `scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5-gh.md` | 통과 | PR body 기반 Markdown 초안 생성 |
| 핵심 키워드 검색 | 통과 | `포함 PR 분석`, `직접 반영된 PR`, `해결된 Issue`, `관련 Issue`, 대표 PR/report 후보, `PR body` 근거 확인 |
| `scripts/validate-github-body.sh build.noindex/release/pr-analysis-0.1.5-gh.md` | 통과 | PR/Issue ref 뒤 한글 조사 결합 없음 |
| `git diff --check` | 통과 | whitespace 오류 없음 |

검증 명령:

```bash
gh auth status
gh pr view 334 --repo postmelee/alhangeul-macos --json number,title,body,files,mergeCommit
bash -n scripts/ci/write-release-pr-analysis.sh
scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5.md
scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5-gh.md
rg -n "Release PR 분석 초안|포함 PR 분석|직접 반영된 PR|해결된 Issue|관련 Issue|#324|#326|#329|#334|#349|#352|#353|task_m014_110_report|task_m014_121_report|task_m014_122_report|task_m040_323_report|PR body" \
  build.noindex/release/pr-analysis-0.1.5-gh.md
scripts/validate-github-body.sh build.noindex/release/pr-analysis-0.1.5-gh.md
git diff --check
```

## 남은 위험

- helper의 분류는 path/title 기반 hint이므로 release owner가 PR body, linked Issue, 최종 보고서를 읽고 확정해야 한다.
- 해결된 Issue는 PR body closing keyword 또는 release record 완료 확정 항목만 사용할 수 있다. fallback 경로에서는 PR body를 읽지 못하므로 해결된 Issue 후보가 비어 있을 수 있다.
- `write-release-notes.sh`, `check-release-notes-template.sh`, release workflow는 아직 이 helper 결과를 사용하지 않는다. 이 연결은 Stage 4 범위다.
- path 기반 delta checklist는 계속 보조 자료로 남아 있으며, 이번 helper 출력도 delta checklist를 대체하지 않는다.

## 다음 단계 요청

Stage 4에서는 release note generator/checker와 CI/workflow가 포함 PR 분석 결과를 쓰도록 연결한다.

Stage 4 진행 승인을 요청한다.
