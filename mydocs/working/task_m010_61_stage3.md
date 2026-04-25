# Issue #61 Stage 3 완료 보고서

## 단계명

PR 본문 원격 보정과 접근 검증

## 작업 요약

Stage 2에서 확정한 보정안 그대로 GitHub 원격 PR 본문을 수정했다. 수정 대상은 PR #59와 PR #60의 `## 문서` 섹션뿐이며, PR 제목, 관련 이슈, 남은 리스크, 검증 설명 문장은 변경하지 않았다.

로컬 소스 파일 변경은 없고, GitHub 원격 PR 본문만 수정했다. 본 단계의 로컬 산출물은 이 보고서다.

## 원격 수정 결과

| PR | 수정 전 | 수정 후 | 결과 |
|----|---------|---------|------|
| #59 | 문서 링크 7개가 존재하지 않는 SHA `6f57cccda6110abe999a54eec159aa91efa3b646` 사용 | 실제 head SHA `6f57ccc178438bb45ba7df85f6e278af4b428af0`로 교체 | 완료 |
| #60 | 문서 링크 9개가 raw URL로 표시 | URL은 유지하고 `[파일명](URL)` 형식으로 교체 | 완료 |

## PR #59 수정 후 문서 섹션

```markdown
- 수행 계획서: [task_m010_52.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/plans/task_m010_52.md)
- 구현 계획서: [task_m010_52_impl.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/plans/task_m010_52_impl.md)
- Stage 1 보고서: [task_m010_52_stage1.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/working/task_m010_52_stage1.md)
- Stage 1 보정 보고서: [task_m010_52_stage1_followup.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/working/task_m010_52_stage1_followup.md)
- Stage 2 보고서: [task_m010_52_stage2.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/working/task_m010_52_stage2.md)
- Stage 3 보고서: [task_m010_52_stage3.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/working/task_m010_52_stage3.md)
- 최종 보고서: [task_m010_52_report.md](https://github.com/postmelee/alhangeul-macos/blob/6f57ccc178438bb45ba7df85f6e278af4b428af0/mydocs/report/task_m010_52_report.md)
```

## PR #60 수정 후 문서 섹션

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

## 검증 결과

### PR #59

수정 후 문서 섹션을 재조회했다.

```bash
gh pr view 59 --repo postmelee/alhangeul-macos --json body --jq '.body | split("## 문서")[1] | split("## 관련 이슈")[0]'
```

결과:

- 7개 문서 링크 모두 `6f57ccc178438bb45ba7df85f6e278af4b428af0` 기준 URL로 표시됨.
- 잘못된 SHA `6f57cccda6110abe999a54eec159aa91efa3b646` 잔존 여부 확인 결과 `false`.

```bash
gh pr view 59 --repo postmelee/alhangeul-macos --json body --jq '.body | contains("6f57cccda6110abe999a54eec159aa91efa3b646")'
```

### PR #60

수정 후 문서 섹션을 재조회했다.

```bash
gh pr view 60 --repo postmelee/alhangeul-macos --json body --jq '.body | split("## 문서")[1] | split("## 관련 이슈")[0]'
```

결과:

- 9개 문서 링크가 모두 `[파일명](URL)` 형식으로 표시됨.
- 문서 섹션 raw URL 노출 검사 결과 출력 없음.

### 전체 merged PR 본문 검사

고정 blob URL의 40자 SHA가 모두 실제 commit인지 확인했다.

```bash
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json body \
  | jq -r '.[].body | scan("https://github\\.com/postmelee/alhangeul-macos/blob/([0-9a-f]{40})/[^\\s)]+") | .[0]' \
  | sort -u \
  | git cat-file --batch-check='%(objectname) %(objecttype)'
```

결과:

- 기존 missing SHA가 사라지고, 모든 SHA가 `commit`으로 확인됨.

문서 섹션 raw URL 노출 검사:

```bash
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json number,title,body \
  | jq -r '.[] as $pr | ($pr.body // "") as $body | ($body | split("## 문서")) as $parts | (if ($parts|length) > 1 then $parts[1] else "" end) as $doc0 | ($doc0 | split("## 관련 이슈") | (.[0] // "") | split("## 남은 리스크") | (.[0] // "") | split("## 스크린샷") | (.[0] // "")) as $doc | ($doc | split("\n")[] | select(test("https://github\\.com/postmelee/alhangeul-macos/blob/[0-9a-f]{40}/mydocs/")) | select(test("\\]\\(https://github\\.com/postmelee/alhangeul-macos/blob/[0-9a-f]{40}/mydocs/") | not) | "#\\($pr.number) \\($pr.title) :: \\(.)")'
```

결과: 출력 없음.

문서 섹션 상대/비클릭 `mydocs/` 경로 검사:

```bash
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json number,title,body \
  | jq -r '.[] as $pr | ($pr.body // "") as $body | ($body | split("## 문서")) as $parts | (if ($parts|length) > 1 then $parts[1] else "" end) as $doc0 | ($doc0 | split("## 관련 이슈") | (.[0] // "") | split("## 남은 리스크") | (.[0] // "") | split("## 스크린샷") | (.[0] // "")) as $doc | ($doc | split("\n")[] | select(test("mydocs/")) | select(test("github\\.com/postmelee/alhangeul-macos/blob/[0-9a-f]{40}/mydocs/") | not) | "#\\($pr.number) \\($pr.title) :: \\(.)")'
```

결과: 출력 없음.

### 링크 대상 접근 검증

PR #59의 7개 문서 경로와 PR #60의 9개 문서 경로를 GitHub Contents API로 확인했다.

```bash
gh api "repos/postmelee/alhangeul-macos/contents/{path}?ref={sha}" --jq '.path'
```

결과:

- PR #59 7개 경로 모두 조회 성공.
- PR #60 9개 경로 모두 조회 성공.

## 수정하지 않은 항목

- PR #59의 검증 결과 문장에 포함된 `blob/publish/task`, `](mydocs/` 패턴명은 설명 텍스트라 수정하지 않았다.
- PR 제목, 관련 이슈, 남은 리스크, 검증 체크리스트는 수정하지 않았다.
- 문서 링크와 무관한 일반 이슈/PR 링크는 수정하지 않았다.

## 완료 조건 확인

| 완료 조건 | 결과 |
|-----------|------|
| 승인된 PR 본문 보정이 GitHub 원격에 반영됨 | 충족 |
| PR #59 문서 링크가 클릭 가능한 실제 commit SHA로 교체됨 | 충족 |
| PR #60 문서 섹션이 raw URL 표시 대신 `[파일명](URL)` 형식임 | 충족 |
| 보정하지 않은 항목과 그 이유 기록 | 충족 |

## 승인 요청 사항

본 Stage 3 결과 기준으로 Stage 4: PR 링크 작성 규격 보강 진행을 승인 요청한다.
