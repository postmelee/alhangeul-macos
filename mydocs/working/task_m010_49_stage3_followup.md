# Issue #49 Stage 3 보정 보고서

## 보정 목적

Stage 3 완료 후 검토에서 일부 FAQ가 특정 세션의 일회성 실수 회복에 가까워 매뉴얼 자체 완결성 보강 목적에 비해 지엽적이라는 판단이 있었다. 또한 기존 PR 본문 링크 보정은 별도 Issue #52로 분리하고, 현재 Task #49에는 앞으로의 PR 문서 링크 작성 기준만 반영한다.

## 반영 내용

- `mydocs/manual/document_structure_guide.md`
  - `문서 폴더 구조` bullet 목록 제거. 같은 정보는 `폴더 역할` 표에 더 높은 밀도로 남긴다.
  - `문서를 잘못된 폴더에 만들었을 때` FAQ 제거.
- `mydocs/manual/task_workflow_guide.md`
  - `working/`과 `report/` 위치 혼동 FAQ 제거.
  - SKILL 호출 표시 안내는 유지.
- `mydocs/manual/git_workflow_guide.md`
  - PR 본문 문서 링크는 PR head commit SHA 기반 GitHub blob URL을 우선 사용하도록 안내 추가.
  - 기존 PR #46/#50 본문 수정은 Issue #52로 분리.
- `mydocs/plans/task_m010_49_impl.md`
  - Stage 2와 Stage 4 검증 범위에 PR 문서 링크 안정화 정책과 지엽적 FAQ 정리를 반영.

## 검증 결과

검증 명령:

```bash
! rg -n "문서를 잘못된 폴더|위치를 혼동" mydocs/manual/document_structure_guide.md mydocs/manual/task_workflow_guide.md
rg -n "PR 본문에 문서 링크|blob/\\{sha\\}" mydocs/manual/git_workflow_guide.md
wc -l mydocs/manual/document_structure_guide.md mydocs/manual/git_workflow_guide.md mydocs/manual/task_workflow_guide.md
git diff --check
```

결과:

- 제거 대상 FAQ 문구는 더 이상 매뉴얼에 남아 있지 않음
- PR 문서 링크 안정화 안내 확인
- 3개 매뉴얼 모두 200줄 이하 유지
- `git diff --check` 통과

## 다음 단계 영향

Stage 4에서는 지엽적 FAQ 제거, 폴더 역할 표 유지, PR 문서 링크 안정화 안내 추가를 포함해 3개 매뉴얼 전체를 통합 검증한다.
