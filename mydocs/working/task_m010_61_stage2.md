# Issue #61 Stage 2 완료 보고서

## 단계명

기준 SHA와 PR 본문 보정안 확정

## 작업 요약

Stage 1에서 보정 대상으로 확정한 PR #59, PR #60의 문서 섹션을 대상으로 기준 SHA와 수정 후 Markdown을 확정했다. 이번 단계에서는 보정안만 작성했으며, GitHub PR 본문 원격 수정은 수행하지 않았다.

## 기준 SHA 결정

| PR | 현재 상태 | 기준 SHA | 결정 근거 |
|----|-----------|----------|-----------|
| #59 | 문서 링크 7개가 존재하지 않는 SHA 사용 | `6f57ccc178438bb45ba7df85f6e278af4b428af0` | PR #59의 마지막 head commit이며, 7개 문서 경로가 모두 이 commit에서 조회됨 |
| #60 | 문서 링크 9개가 raw URL로 표시됨 | `c39e479b131804f7c2c123cc71a30f70216402a3` | PR #60의 마지막 head commit이며, 기존 URL 대상 문서 경로가 모두 이 commit에서 조회됨 |

PR #59의 잘못된 SHA `6f57cccda6110abe999a54eec159aa91efa3b646`는 GitHub API에서 `No commit found for SHA`로 확인된다.

## 경로 검증 결과

### PR #59

기준 SHA: `6f57ccc178438bb45ba7df85f6e278af4b428af0`

| 문서 | 경로 | 결과 |
|------|------|------|
| 수행 계획서 | `mydocs/plans/task_m010_52.md` | OK |
| 구현 계획서 | `mydocs/plans/task_m010_52_impl.md` | OK |
| Stage 1 보고서 | `mydocs/working/task_m010_52_stage1.md` | OK |
| Stage 1 보정 보고서 | `mydocs/working/task_m010_52_stage1_followup.md` | OK |
| Stage 2 보고서 | `mydocs/working/task_m010_52_stage2.md` | OK |
| Stage 3 보고서 | `mydocs/working/task_m010_52_stage3.md` | OK |
| 최종 보고서 | `mydocs/report/task_m010_52_report.md` | OK |

### PR #60

기준 SHA: `c39e479b131804f7c2c123cc71a30f70216402a3`

| 문서 | 경로 | 결과 |
|------|------|------|
| 수행 계획서 | `mydocs/plans/task_m010_55.md` | OK |
| 구현 계획서 | `mydocs/plans/task_m010_55_impl.md` | OK |
| compatibility 기준 | `mydocs/tech/core_release_compatibility.md` | OK |
| Stage 1 보고서 | `mydocs/working/task_m010_55_stage1.md` | OK |
| Stage 2 보고서 | `mydocs/working/task_m010_55_stage2.md` | OK |
| Stage 3 보고서 | `mydocs/working/task_m010_55_stage3.md` | OK |
| Stage 4 보고서 | `mydocs/working/task_m010_55_stage4.md` | OK |
| Stage 5 보고서 | `mydocs/working/task_m010_55_stage5.md` | OK |
| 최종 보고서 | `mydocs/report/task_m010_55_report.md` | OK |

각 경로는 `git cat-file -e {sha}:{path}`와 `gh api repos/postmelee/alhangeul-macos/contents/{path}?ref={sha}`로 확인했다.

## PR #59 보정안

수정 범위는 `## 문서` 섹션의 7개 링크만이다. 본문의 검증 결과 설명에 있는 `blob/publish/task`, `](mydocs/`, `github.com/postmelee/alhangeul-macos/blob/{40자 SHA}/mydocs/...` 패턴명은 설명 문구이므로 수정하지 않는다.

현재 문서 섹션:

```markdown
- 수행 계획서: [task_m010_52.md](https://github.com/postmelee/alhangeul-macos/blob/6f57cccda6110abe999a54eec159aa91efa3b646/mydocs/plans/task_m010_52.md)
- 구현 계획서: [task_m010_52_impl.md](https://github.com/postmelee/alhangeul-macos/blob/6f57cccda6110abe999a54eec159aa91efa3b646/mydocs/plans/task_m010_52_impl.md)
- Stage 1 보고서: [task_m010_52_stage1.md](https://github.com/postmelee/alhangeul-macos/blob/6f57cccda6110abe999a54eec159aa91efa3b646/mydocs/working/task_m010_52_stage1.md)
- Stage 1 보정 보고서: [task_m010_52_stage1_followup.md](https://github.com/postmelee/alhangeul-macos/blob/6f57cccda6110abe999a54eec159aa91efa3b646/mydocs/working/task_m010_52_stage1_followup.md)
- Stage 2 보고서: [task_m010_52_stage2.md](https://github.com/postmelee/alhangeul-macos/blob/6f57cccda6110abe999a54eec159aa91efa3b646/mydocs/working/task_m010_52_stage2.md)
- Stage 3 보고서: [task_m010_52_stage3.md](https://github.com/postmelee/alhangeul-macos/blob/6f57cccda6110abe999a54eec159aa91efa3b646/mydocs/working/task_m010_52_stage3.md)
- 최종 보고서: [task_m010_52_report.md](https://github.com/postmelee/alhangeul-macos/blob/6f57cccda6110abe999a54eec159aa91efa3b646/mydocs/report/task_m010_52_report.md)
```

수정 후 문서 섹션:

```markdown
- 수행 계획서: [task_m010_52.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/plans/task_m010_52.md)
- 구현 계획서: [task_m010_52_impl.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/plans/task_m010_52_impl.md)
- Stage 1 보고서: [task_m010_52_stage1.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/working/task_m010_52_stage1.md)
- Stage 1 보정 보고서: [task_m010_52_stage1_followup.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/working/task_m010_52_stage1_followup.md)
- Stage 2 보고서: [task_m010_52_stage2.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/working/task_m010_52_stage2.md)
- Stage 3 보고서: [task_m010_52_stage3.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/working/task_m010_52_stage3.md)
- 최종 보고서: [task_m010_52_report.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/report/task_m010_52_report.md)
```

## PR #60 보정안

수정 범위는 `## 문서` 섹션의 9개 링크만이다. 기존 URL의 기준 SHA와 경로는 유지하고, 표시 텍스트만 파일명으로 바꾼다.

현재 문서 섹션:

```markdown
- 수행 계획서: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/plans/task_m010_55.md
- 구현 계획서: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/plans/task_m010_55_impl.md
- compatibility 기준: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/tech/core_release_compatibility.md
- Stage 1 보고서: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage1.md
- Stage 2 보고서: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage2.md
- Stage 3 보고서: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage3.md
- Stage 4 보고서: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage4.md
- Stage 5 보고서: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage5.md
- 최종 보고서: https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/report/task_m010_55_report.md
```

수정 후 문서 섹션:

```markdown
- 수행 계획서: [task_m010_55.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/plans/task_m010_55.md)
- 구현 계획서: [task_m010_55_impl.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/plans/task_m010_55_impl.md)
- compatibility 기준: [core_release_compatibility.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/tech/core_release_compatibility.md)
- Stage 1 보고서: [task_m010_55_stage1.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage1.md)
- Stage 2 보고서: [task_m010_55_stage2.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage2.md)
- Stage 3 보고서: [task_m010_55_stage3.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage3.md)
- Stage 4 보고서: [task_m010_55_stage4.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage4.md)
- Stage 5 보고서: [task_m010_55_stage5.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/working/task_m010_55_stage5.md)
- 최종 보고서: [task_m010_55_report.md](https://github.com/postmelee/alhangeul-macos/blob/c39e479b131804f7c2c123cc71a30f70216402a3/mydocs/report/task_m010_55_report.md)
```

## Stage 3 수정 범위

Stage 3에서 원격 PR 본문 수정 대상으로 삼을 범위는 다음으로 제한한다.

- PR #59: `## 문서` 섹션의 7개 링크에서 SHA만 교체
- PR #60: `## 문서` 섹션의 9개 raw URL을 Markdown 링크로 교체

수정하지 않을 항목:

- PR 제목, 관련 이슈, 남은 리스크, 검증 결과 문장
- `blob/publish/task`, `](mydocs/` 같은 검증 패턴 설명
- 외부 링크와 일반 이슈/PR 링크

## 실행한 주요 명령

```bash
gh pr view 59 --repo postmelee/alhangeul-macos --json number,title,body,commits,mergeCommit,url,state
gh pr view 60 --repo postmelee/alhangeul-macos --json number,title,body,commits,mergeCommit,url,state
git cat-file -e 6f57ccc178438bb45ba7df85f6e278af4b428af0:mydocs/plans/task_m010_52.md
git cat-file -e c39e479b131804f7c2c123cc71a30f70216402a3:mydocs/plans/task_m010_55.md
gh api repos/postmelee/alhangeul-macos/commits/6f57ccc178438bb45ba7df85f6e278af4b428af0 --jq '.sha'
gh api repos/postmelee/alhangeul-macos/commits/c39e479b131804f7c2c123cc71a30f70216402a3 --jq '.sha'
gh api 'repos/postmelee/alhangeul-macos/contents/mydocs/plans/task_m010_52.md?ref=6f57ccc178438bb45ba7df85f6e278af4b428af0' --jq '.path'
gh api 'repos/postmelee/alhangeul-macos/contents/mydocs/plans/task_m010_55.md?ref=c39e479b131804f7c2c123cc71a30f70216402a3' --jq '.path'
```

## 검증 결과

```bash
git diff --check -- mydocs/working/task_m010_61_stage2.md
```

결과: 통과.

## 완료 조건 확인

| 완료 조건 | 결과 |
|-----------|------|
| 모든 보정 대상 링크의 수정 후 Markdown 확정 | 충족 |
| PR #59 링크의 실제 commit SHA 기준 교체안 확정 | 충족 |
| PR #60 문서 섹션의 `[파일명](URL)` 형식 교체안 확정 | 충족 |
| Stage 3 원격 수정 범위 검토 가능 | 충족 |

## 승인 요청 사항

본 Stage 2 보정안 기준으로 Stage 3: PR 본문 원격 보정과 접근 검증 진행을 승인 요청한다.
