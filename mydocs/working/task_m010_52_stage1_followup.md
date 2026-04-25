# Issue #52 Stage 1 보정 보고서

## 단계명

대상 PR 링크 조사 범위 보강

## 보정 배경

Stage 1 최초 조사에서는 `blob/publish/taskN/...` 링크와 `](mydocs/...)` 형태의 Markdown 상대 링크를 중심으로 보정 대상을 분류했다. 작업지시자가 "나머지 PR의 문서 링크가 연결되어 있지 않거나 수정이 필요한 항목"을 추가 확인하도록 지시해, 전체 merged PR 본문에서 `mydocs/` 언급 전체를 다시 조사했다.

그 결과, PR #46과 PR #50 외에도 문서 섹션에 `mydocs/...` 경로가 코드 표기로만 적혀 있어 클릭 가능한 문서 링크가 아닌 PR들이 있었다. 이는 깨진 링크는 아니지만, "merge 후 조회 가능한 고정 URL"이라는 Task #52의 목적에는 맞지 않으므로 추가 보정 후보로 분류한다.

## 추가 조사 범위

- `gh pr list --state merged --limit 100` 기준 merged PR 24개
- 본문에 `mydocs/`가 포함된 PR
- `blob/publish/taskN/...`, `](mydocs/...)`, 코드 표기 또는 일반 텍스트 `mydocs/...` 경로

## 추가 조사 결과 요약

| 분류 | PR | 판단 |
|------|----|------|
| 필수 보정 | #46 | `blob/publish/task45/...` 링크가 삭제 대상 브랜치에 의존함 |
| 필수 보정 | #50 | 문서 섹션의 `mydocs/...` 상대 링크가 commit SHA 고정 URL이 아님 |
| 추가 보정 후보 | #56, #51, #44, #43, #42, #41, #39, #38, #36, #34, #25, #23 | 문서 섹션이 있으나 링크가 아니라 코드 경로로만 적혀 있어 클릭 불가 |
| 보정 불필요 | #53 | 이미 commit SHA 고정 `blob/{sha}/mydocs/...` URL 사용 |
| 보정 제외 | #19, #18, #14, #12, #10 | 검증 명령, 변경 내역 설명, 문서 이동 설명의 경로 언급이 중심이며 별도 문서 섹션 링크로 보기 어려움 |

## 추가 보정 후보 상세

| PR | head SHA | 비클릭 문서 경로 유형 | Stage 2 처리 방향 |
|----|----------|----------------------|-------------------|
| #56 | `99ed78019c32d727fa14e4ef4358a6bd1b2f1783` | 수행 계획서, 구현 계획서, 단계 보고서 범위, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #51 | `53223924d4ca51c481543888e3f6197234446639` | 수행 계획서, 구현 계획서, 단계 보고서 범위, 실측 기록, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #44 | `e94e09bb92641a3797072be9db979d3a095b42b9` | 수행 계획서, 구현 계획서, provenance 문서, 단계 보고서, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #43 | `fc1df58bb5d9b4e8b533550cba17552e52fb36b4` | 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #42 | `69361546bc24c0caffbedaca14cea177b7c01059` | 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서, 오늘할일 | 문서 섹션을 commit SHA 고정 URL로 보정. 오늘할일 링크 포함 여부는 Stage 2에서 확정 |
| #41 | `8932ae7537b90f5eef5f72286df74cedfb969c57` | 수행 계획서, 구현 계획서, 단계 보고서 범위, 최종 보고서, troubleshooting | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #39 | `2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619` | 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #38 | `7adc116bf97291c5b151c61cf0146408044a1c0e` | 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #36 | `015a2fe50cf6720e198551e54ef3588a5b133302` | 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #34 | `8cf41fbfc3786ffe7c71871eb39235954e6a41d3` | 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #25 | `7c62f6870c842444085cbc04c45dbdcfef9be0e4` | 수행 계획서, 구현 계획서, 단계 보고서, 최종 보고서 | 문서 섹션을 commit SHA 고정 URL로 보정 |
| #23 | `d5bd5083abc9f04d73e95b152d6ce055c081b4c4` | 최종 보고서, Finder Feedback Assistant 제출 문서 | 문서 섹션을 commit SHA 고정 URL로 보정 |

## 문서 존재성 확인

추가 보정 후보의 대표 문서 경로를 각 PR head SHA에서 확인했다.

- #56: `task_m010_54` 계획서, 구현계획서, stage1, stage7, 최종 보고서 존재
- #51: `task_m010_48` 계획서, 구현계획서, stage1, stage4, 실측 기록, 최종 보고서 존재
- #44: `task_m010_28` 계획서, 구현계획서, sample provenance, stage1, stage5, 최종 보고서 존재
- #43: `task_m050_29` 계획서, 구현계획서, stage1, stage6, 최종 보고서 존재
- #42: `task_m030_35` 계획서, 구현계획서, stage1, stage6, 최종 보고서 존재
- #41: `task_m050_40` 계획서, 구현계획서, stage1, stage6, 최종 보고서, troubleshooting 존재
- #39: `task_m050_33` 계획서, 구현계획서, stage1, stage5, 최종 보고서 존재
- #38: `task_m050_37` 계획서, 구현계획서, stage1, 최종 보고서 존재
- #36: `task_m050_26` 계획서, 구현계획서, stage1, 최종 보고서 존재
- #34: `task_m050_27` 계획서, 구현계획서, stage1, stage4, 최종 보고서 존재
- #25: `task_m010_24` 계획서, 구현계획서, stage1, stage4, 최종 보고서 존재
- #23: `task_m050_22_report.md`, Finder Feedback Assistant 제출 문서 존재

## 제외 기준

다음 유형은 이번 PR 본문 보정 대상에서 제외한다.

- 검증 명령 안에 포함된 `mydocs/...` 경로
- 변경 내역 설명에서 파일명을 예시로 언급한 경로
- 문서 이동 또는 구조 설명의 일부로 쓰인 경로
- 이미 commit SHA 고정 URL로 연결된 문서 링크

## 검증

```bash
gh pr list --state merged --limit 100 --json number,title,url,body,headRefOid,mergeCommit --jq '... mydocs/ ...'
gh pr list --state merged --limit 100 --json number,title --jq 'length'
git cat-file -e {head_sha}:mydocs/...
git diff --check -- mydocs/plans/task_m010_52_impl.md mydocs/working/task_m010_52_stage1_followup.md
```

결과:

- merged PR 24개를 대상으로 재조사했다.
- 추가 보정 후보 12건을 확인했다.
- 추가 보정 후보의 대표 문서 경로는 각 PR head SHA에 존재한다.

## 다음 단계 반영

Stage 2에서는 PR #46, #50뿐 아니라 #56, #51, #44, #43, #42, #41, #39, #38, #36, #34, #25, #23의 문서 섹션도 보정안에 포함한다. 단, 검증 명령이나 일반 변경 설명 안의 경로는 제외한다.
