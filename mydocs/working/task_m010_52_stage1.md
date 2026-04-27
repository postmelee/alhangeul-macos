# Issue #52 Stage 1 완료 보고서

## 단계명

대상 PR 링크 조사

## 수행 내용

- PR #46 본문, head SHA, merge commit SHA를 조회했다.
- PR #50 본문, head SHA, merge commit SHA를 조회했다.
- 최근 merge PR 30개 본문에서 `blob/publish/task`, `](mydocs/`, commit SHA 고정 `blob/{sha}/mydocs/` 링크를 검색했다.
- 후보 링크를 다음 유형으로 분류했다.
  - `blob/publish/taskN/...` 링크
  - `mydocs/...` 상대 링크
  - 이미 commit SHA 고정 URL인 링크
  - 보정 대상이 아닌 일반 경로·이슈·PR 링크
- 문서가 실제 commit에 존재하는지 `git cat-file -e`로 확인했다.
- PR #46의 `publish/task45` 원격 브랜치 존재 여부를 `git ls-remote --heads origin publish/task45`로 확인했다.

## 조사 기준 정보

| PR | 제목 | 상태 | head SHA | merge commit |
|----|------|------|----------|--------------|
| #46 | Task #45: AGENTS.md/CLAUDE.md 최적화와 하이퍼-워터폴 절차 skill 분리 | MERGED | `35ee83aea2a09e00a71218b66e25f88de804c6b6` | `e1e61ed5b99b9dd89043c6f47179d536635028b2` |
| #50 | Task #47: Claude Code @AGENTS.md 임포트 실측과 폴백 결정 | MERGED | `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e` | `0a3443d975bd6f635cfe12ab86be356543fa6f13` |
| #53 | Task #49: 신규 매뉴얼 3종 자체 완결성 보강 | MERGED | `bdbc13ad57e08c371afff0fe669fed623f22b03d` | `e3c5c1e27e249402f2f061be870b50f01990cf91` |

## PR #46 링크 조사

| 위치 | 현재 링크 | 유형 | 현재 접근성/보존성 | 보정 필요 |
|------|-----------|------|--------------------|-----------|
| `상세` 문서 링크 | `https://github.com/postmelee/alhangeul-macos/blob/publish/task45/mydocs/report/task_m010_45_report.md` | `blob/publish/taskN` | `git ls-remote --heads origin publish/task45` 결과 없음. PR merge 후 삭제 대상 브랜치에 의존하므로 보존 링크로 부적합 | 필요 |

문서 존재 확인:

- `35ee83aea2a09e00a71218b66e25f88de804c6b6:mydocs/report/task_m010_45_report.md` 존재
- `e1e61ed5b99b9dd89043c6f47179d536635028b2:mydocs/report/task_m010_45_report.md` 존재

Stage 2 기준 SHA 후보:

- 1순위 후보: PR head SHA `35ee83aea2a09e00a71218b66e25f88de804c6b6`
- 대안 후보: merge commit `e1e61ed5b99b9dd89043c6f47179d536635028b2`

## PR #50 링크 조사

| 위치 | 현재 링크 | 유형 | 현재 접근성/보존성 | 보정 필요 |
|------|-----------|------|--------------------|-----------|
| 수행 계획서 | `mydocs/plans/task_m010_47.md` | PR 본문 상대 링크 | commit SHA 고정이 아니며 PR 화면에서 저장소 파일로 바로 식별하기 어렵다 | 필요 |
| 구현 계획서 | `mydocs/plans/task_m010_47_impl.md` | PR 본문 상대 링크 | commit SHA 고정이 아니며 PR 화면에서 저장소 파일로 바로 식별하기 어렵다 | 필요 |
| Stage 1 보고서 | `mydocs/working/task_m010_47_stage1.md` | PR 본문 상대 링크 | commit SHA 고정이 아니며 PR 화면에서 저장소 파일로 바로 식별하기 어렵다 | 필요 |
| Stage 2 보고서 | `mydocs/working/task_m010_47_stage2.md` | PR 본문 상대 링크 | commit SHA 고정이 아니며 PR 화면에서 저장소 파일로 바로 식별하기 어렵다 | 필요 |
| Stage 3 보고서 | `mydocs/working/task_m010_47_stage3.md` | PR 본문 상대 링크 | commit SHA 고정이 아니며 PR 화면에서 저장소 파일로 바로 식별하기 어렵다 | 필요 |
| 최종 보고서 | `mydocs/report/task_m010_47_report.md` | PR 본문 상대 링크 | commit SHA 고정이 아니며 PR 화면에서 저장소 파일로 바로 식별하기 어렵다 | 필요 |
| 실측 기록 | `mydocs/troubleshootings/task_m010_47_claude_agents_import.md` | PR 본문 상대 링크 | commit SHA 고정이 아니며 PR 화면에서 저장소 파일로 바로 식별하기 어렵다 | 필요 |

문서 존재 확인:

- `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/plans/task_m010_47.md` 존재
- `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/plans/task_m010_47_impl.md` 존재
- `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/working/task_m010_47_stage1.md` 존재
- `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/working/task_m010_47_stage2.md` 존재
- `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/working/task_m010_47_stage3.md` 존재
- `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/report/task_m010_47_report.md` 존재
- `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/troubleshootings/task_m010_47_claude_agents_import.md` 존재

Stage 2 기준 SHA 후보:

- 1순위 후보: PR head SHA `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e`
- 대안 후보: merge commit `0a3443d975bd6f635cfe12ab86be356543fa6f13`

## 추가 조사 결과

최근 merge PR 30개 중 같은 검색 패턴에 걸린 PR은 다음 3건이다.

| PR | 분류 | 결과 |
|----|------|------|
| #46 | `blob/publish/taskN` 문서 링크 | 보정 대상 |
| #50 | `mydocs/` 상대 문서 링크 | 보정 대상 |
| #53 | commit SHA 고정 `blob/{sha}/mydocs/` 문서 링크 | 이미 정책에 맞음. 보정 대상 아님 |

PR #53은 Task #49에서 반영한 향후 정책의 정상 사례로 확인했다. 이미 `bdbc13ad57e08c371afff0fe669fed623f22b03d` 고정 blob URL을 사용하므로 이번 타스크에서 수정하지 않는다.

## 검증

```bash
gh pr view 46 --json number,title,state,body,headRefOid,mergeCommit,url
gh pr view 50 --json number,title,state,body,headRefOid,mergeCommit,url
gh pr list --state merged --limit 30 --json number,title,url,body,headRefOid,mergeCommit
gh pr list --state merged --limit 30 --json number,title,url,body,headRefOid,mergeCommit --jq '...'
git cat-file -e 35ee83aea2a09e00a71218b66e25f88de804c6b6:mydocs/report/task_m010_45_report.md
git cat-file -e e1e61ed5b99b9dd89043c6f47179d536635028b2:mydocs/report/task_m010_45_report.md
git cat-file -e 0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/plans/task_m010_47.md
git cat-file -e 0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/plans/task_m010_47_impl.md
git cat-file -e 0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/working/task_m010_47_stage1.md
git cat-file -e 0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/working/task_m010_47_stage2.md
git cat-file -e 0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/working/task_m010_47_stage3.md
git cat-file -e 0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/report/task_m010_47_report.md
git cat-file -e 0df35a92fd476badb2ed27775a48d4ae0ef4ea1e:mydocs/troubleshootings/task_m010_47_claude_agents_import.md
git ls-remote --heads origin publish/task45
git diff --check -- mydocs/working/task_m010_52_stage1.md
```

결과:

- PR #46, #50 본문과 기준 SHA 조회 성공.
- 최근 merge PR 30개 검색 결과 보정 대상은 PR #46, #50으로 제한됨.
- PR #53은 이미 commit SHA 고정 URL을 사용해 보정 대상에서 제외.
- PR #46 보고서는 head SHA와 merge commit 양쪽에 존재.
- PR #50 문서는 head SHA에 모두 존재.
- `publish/task45` 원격 브랜치는 조회 결과 없음.
- `git diff --check -- mydocs/working/task_m010_52_stage1.md` 통과.

## 다음 단계

Stage 2에서 PR #46, #50의 각 링크별 기준 SHA를 확정하고 수정 전후 URL 표를 작성한다.
