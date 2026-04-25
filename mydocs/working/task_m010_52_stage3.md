# Issue #52 Stage 3 완료 보고서

## 단계명

PR 본문 보정과 접근 검증

## 수행 내용

- Stage 2 보정안 기준으로 GitHub PR 본문을 수정했다.
- `blob/publish/taskN/...` 링크를 commit SHA 고정 blob URL로 교체했다.
- 문서 섹션의 `mydocs/...` 상대 링크를 commit SHA 고정 blob URL로 교체했다.
- 문서 섹션에 코드 경로로만 적힌 비클릭 `mydocs/...` 경로를 클릭 가능한 commit SHA 고정 blob URL로 교체했다.
- 수정 후 대상 PR 본문을 다시 조회해 불안정 문서 링크 패턴이 남아 있지 않은지 확인했다.

## 수정 대상

| PR | 수정 내용 | 기준 SHA |
|----|-----------|----------|
| #46 | `blob/publish/task45` 보고서 링크 1건 교체 | `35ee83aea2a09e00a71218b66e25f88de804c6b6` |
| #50 | 상대 문서 링크 7건 교체 | `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e` |
| #56 | 비클릭 문서 경로 5건 교체 | `99ed78019c32d727fa14e4ef4358a6bd1b2f1783` |
| #51 | 비클릭 문서 경로 6건 교체 | `53223924d4ca51c481543888e3f6197234446639` |
| #44 | 비클릭 문서 경로 9건을 문서 링크 5개 항목으로 정리 | `e94e09bb92641a3797072be9db979d3a095b42b9` |
| #43 | 비클릭 문서 경로 9건을 문서 링크 4개 항목으로 정리 | `fc1df58bb5d9b4e8b533550cba17552e52fb36b4` |
| #42 | 비클릭 문서 경로 10건을 문서 링크 5개 항목으로 정리 | `69361546bc24c0caffbedaca14cea177b7c01059` |
| #41 | 비클릭 문서 경로 5건 교체 | `8932ae7537b90f5eef5f72286df74cedfb969c57` |
| #39 | 비클릭 문서 경로 8건을 문서 링크 4개 항목으로 정리 | `2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619` |
| #38 | 비클릭 문서 경로 4건 교체 | `7adc116bf97291c5b151c61cf0146408044a1c0e` |
| #36 | 비클릭 문서 경로 4건 교체 | `015a2fe50cf6720e198551e54ef3588a5b133302` |
| #34 | 비클릭 문서 경로 6건을 문서 링크 4개 항목으로 정리 | `8cf41fbfc3786ffe7c71871eb39235954e6a41d3` |
| #25 | 비클릭 문서 경로 7건을 문서 링크 4개 항목으로 정리 | `7c62f6870c842444085cbc04c45dbdcfef9be0e4` |
| #23 | 비클릭 문서 경로 2건 교체 | `d5bd5083abc9f04d73e95b152d6ce055c081b4c4` |

## 수정 방식

각 PR은 다음 형식의 파이프라인으로 수정했다.

```bash
gh pr view {PR} --json body --jq .body \
  | perl -0pe 's|기존 문서 경로|고정 blob URL|g' \
  | gh pr edit {PR} --body-file -
```

이 방식은 로컬 저장소 파일을 임시 본문 파일로 만들지 않고, GitHub에서 조회한 최신 본문에 필요한 문서 경로 치환만 적용한다.

## 검증

### 불안정 패턴 잔존 확인

대상 PR 14건을 다시 조회해 다음 패턴이 남아 있지 않은지 확인했다.

- `blob/publish/task`
- `](mydocs/`
- 문서 섹션의 비클릭 `mydocs/...` 경로

검증 명령:

```bash
gh pr list --state merged --limit 100 --json number,title,body --jq '... bad pattern check ...'
```

결과:

```text
#56 bad=[]
#51 bad=[]
#50 bad=[]
#46 bad=[]
#44 bad=[]
#43 bad=[]
#42 bad=[]
#41 bad=[]
#39 bad=[]
#38 bad=[]
#36 bad=[]
#34 bad=[]
#25 bad=[]
#23 bad=[]
```

### 고정 URL 반영 확인

대상 PR 본문에서 `github.com/postmelee/alhangeul-macos/blob/{40자 SHA}/mydocs/` 링크가 반영된 줄을 조회했다.

검증 명령:

```bash
gh pr list --state merged --limit 100 --json number,body --jq '... fixed blob URL lines ...'
```

결과 요약:

- #46, #50, #56, #51, #44, #43, #42, #41, #39, #38, #36, #34, #25, #23 모두 고정 blob URL 문서 링크가 조회됨.
- Stage 2에서 확정한 PR head SHA가 각 URL에 사용됨.

### 문서 존재성

Stage 2에서 모든 보정 대상 문서 경로가 각 PR head SHA에 존재함을 `git cat-file -e {sha}:mydocs/...`로 확인했다. Stage 3에서는 PR 본문이 해당 SHA와 경로를 사용하도록 반영됐는지 재조회로 확인했다.

### 로컬 문서 검증

```bash
git diff --check -- mydocs/working/task_m010_52_stage3.md
```

결과: 통과.

## 변경하지 않은 항목

- PR 제목, 라벨, 마일스톤, 이슈 참조는 변경하지 않았다.
- 검증 명령 안의 `mydocs/...` 경로는 명령 재현성 문맥이므로 수정하지 않았다.
- 변경 내역 설명의 파일 경로 나열은 문서 링크 섹션이 아니므로 수정하지 않았다.
- PR #53은 이미 commit SHA 고정 URL을 사용하고 있어 수정하지 않았다.

## 다음 단계

Stage 4에서 최종 보고서와 오늘할일 상태를 정리한다.
