# Issue #52 Stage 2 완료 보고서

## 단계명

링크 기준 SHA 결정과 보정안 작성

## 수행 내용

- Stage 1 및 Stage 1 보정 조사에서 확인한 보정 대상 PR을 확정했다.
- 각 PR 문서 링크의 기준 SHA를 PR head SHA로 통일했다.
- PR head SHA에 보정 대상 문서가 존재하는지 확인했다.
- Stage 3에서 PR 본문에 반영할 Markdown 링크 형식을 확정했다.

## 기준 SHA 결정 원칙

문서 링크 기준은 모두 PR head SHA로 정한다.

이유:

- PR 본문의 문서 섹션은 해당 PR 작업 산출물을 설명한다.
- PR head SHA는 PR 작성 시점의 최종 작업 결과를 직접 가리킨다.
- merge commit도 대체로 문서를 포함하지만, merge 결과가 후속 통합 상태를 포함할 수 있어 "PR 작업 산출물" 기준으로는 head SHA가 더 명확하다.
- `publish/taskN` 브랜치나 상대 경로와 달리, commit SHA blob URL은 브랜치 삭제 후에도 조회 가능하다.

URL 형식:

```text
https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/{path}
```

## 보정 대상 확정

| PR | 기준 SHA | 보정 유형 | Stage 3 처리 |
|----|----------|-----------|--------------|
| #46 | `35ee83aea2a09e00a71218b66e25f88de804c6b6` | `blob/publish/task45` 브랜치 링크 | 고정 blob URL 1건으로 교체 |
| #50 | `0df35a92fd476badb2ed27775a48d4ae0ef4ea1e` | `mydocs/` 상대 링크 | 문서 섹션 5줄을 고정 blob URL로 교체 |
| #56 | `99ed78019c32d727fa14e4ef4358a6bd1b2f1783` | 비클릭 코드 경로 | 문서 섹션 4줄을 고정 blob URL로 교체 |
| #51 | `53223924d4ca51c481543888e3f6197234446639` | 비클릭 코드 경로 | 문서 섹션 5줄을 고정 blob URL로 교체 |
| #44 | `e94e09bb92641a3797072be9db979d3a095b42b9` | 비클릭 코드 경로 | 문서 섹션 5개 항목을 고정 blob URL로 교체 |
| #43 | `fc1df58bb5d9b4e8b533550cba17552e52fb36b4` | 비클릭 코드 경로 | 문서 섹션 4개 항목을 고정 blob URL로 교체 |
| #42 | `69361546bc24c0caffbedaca14cea177b7c01059` | 비클릭 코드 경로 | 문서 섹션 5개 항목을 고정 blob URL로 교체 |
| #41 | `8932ae7537b90f5eef5f72286df74cedfb969c57` | 비클릭 코드 경로 | 문서 섹션 5줄을 고정 blob URL로 교체 |
| #39 | `2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619` | 비클릭 코드 경로 | 문서 섹션 4개 항목을 고정 blob URL로 교체 |
| #38 | `7adc116bf97291c5b151c61cf0146408044a1c0e` | 비클릭 코드 경로 | 문서 섹션 4줄을 고정 blob URL로 교체 |
| #36 | `015a2fe50cf6720e198551e54ef3588a5b133302` | 비클릭 코드 경로 | 문서 섹션 4줄을 고정 blob URL로 교체 |
| #34 | `8cf41fbfc3786ffe7c71871eb39235954e6a41d3` | 비클릭 코드 경로 | 문서 섹션 4줄을 고정 blob URL로 교체 |
| #25 | `7c62f6870c842444085cbc04c45dbdcfef9be0e4` | 비클릭 코드 경로 | 문서 섹션 4줄을 고정 blob URL로 교체 |
| #23 | `d5bd5083abc9f04d73e95b152d6ce055c081b4c4` | 비클릭 일반 경로 | 문서 섹션 2줄을 고정 blob URL로 교체 |

## PR별 보정안

### PR #46

기존:

```markdown
상세: [`mydocs/report/task_m010_45_report.md`](https://github.com/postmelee/alhangeul-macos/blob/publish/task45/mydocs/report/task_m010_45_report.md)
```

변경:

```markdown
상세: [task_m010_45_report.md](https://github.com/postmelee/alhangeul-macos/blob/35ee83aea2a09e00a71218b66e25f88de804c6b6/mydocs/report/task_m010_45_report.md)
```

### PR #50

문서 섹션을 다음 형식으로 교체한다.

```markdown
- 수행 계획서: [task_m010_47.md](https://github.com/postmelee/alhangeul-macos/blob/0df35a92fd476badb2ed27775a48d4ae0ef4ea1e/mydocs/plans/task_m010_47.md)
- 구현 계획서: [task_m010_47_impl.md](https://github.com/postmelee/alhangeul-macos/blob/0df35a92fd476badb2ed27775a48d4ae0ef4ea1e/mydocs/plans/task_m010_47_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/0df35a92fd476badb2ed27775a48d4ae0ef4ea1e/mydocs/working/task_m010_47_stage1.md), [stage2](https://github.com/postmelee/alhangeul-macos/blob/0df35a92fd476badb2ed27775a48d4ae0ef4ea1e/mydocs/working/task_m010_47_stage2.md), [stage3](https://github.com/postmelee/alhangeul-macos/blob/0df35a92fd476badb2ed27775a48d4ae0ef4ea1e/mydocs/working/task_m010_47_stage3.md)
- 최종 보고서: [task_m010_47_report.md](https://github.com/postmelee/alhangeul-macos/blob/0df35a92fd476badb2ed27775a48d4ae0ef4ea1e/mydocs/report/task_m010_47_report.md)
- 실측 기록: [task_m010_47_claude_agents_import.md](https://github.com/postmelee/alhangeul-macos/blob/0df35a92fd476badb2ed27775a48d4ae0ef4ea1e/mydocs/troubleshootings/task_m010_47_claude_agents_import.md)
```

### PR #56

```markdown
- 수행 계획서: [task_m010_54.md](https://github.com/postmelee/alhangeul-macos/blob/99ed78019c32d727fa14e4ef4358a6bd1b2f1783/mydocs/plans/task_m010_54.md)
- 구현 계획서: [task_m010_54_impl.md](https://github.com/postmelee/alhangeul-macos/blob/99ed78019c32d727fa14e4ef4358a6bd1b2f1783/mydocs/plans/task_m010_54_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/99ed78019c32d727fa14e4ef4358a6bd1b2f1783/mydocs/working/task_m010_54_stage1.md) ~ [stage7](https://github.com/postmelee/alhangeul-macos/blob/99ed78019c32d727fa14e4ef4358a6bd1b2f1783/mydocs/working/task_m010_54_stage7.md)
- 최종 보고서: [task_m010_54_report.md](https://github.com/postmelee/alhangeul-macos/blob/99ed78019c32d727fa14e4ef4358a6bd1b2f1783/mydocs/report/task_m010_54_report.md)
```

### PR #51

```markdown
- 수행 계획서: [task_m010_48.md](https://github.com/postmelee/alhangeul-macos/blob/53223924d4ca51c481543888e3f6197234446639/mydocs/plans/task_m010_48.md)
- 구현 계획서: [task_m010_48_impl.md](https://github.com/postmelee/alhangeul-macos/blob/53223924d4ca51c481543888e3f6197234446639/mydocs/plans/task_m010_48_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/53223924d4ca51c481543888e3f6197234446639/mydocs/working/task_m010_48_stage1.md) ~ [stage4](https://github.com/postmelee/alhangeul-macos/blob/53223924d4ca51c481543888e3f6197234446639/mydocs/working/task_m010_48_stage4.md)
- 실측 기록: [task_m010_48_skill_exposure.md](https://github.com/postmelee/alhangeul-macos/blob/53223924d4ca51c481543888e3f6197234446639/mydocs/troubleshootings/task_m010_48_skill_exposure.md)
- 최종 보고서: [task_m010_48_report.md](https://github.com/postmelee/alhangeul-macos/blob/53223924d4ca51c481543888e3f6197234446639/mydocs/report/task_m010_48_report.md)
```

### PR #44

```markdown
- 수행 계획서: [task_m010_28.md](https://github.com/postmelee/alhangeul-macos/blob/e94e09bb92641a3797072be9db979d3a095b42b9/mydocs/plans/task_m010_28.md)
- 구현 계획서: [task_m010_28_impl.md](https://github.com/postmelee/alhangeul-macos/blob/e94e09bb92641a3797072be9db979d3a095b42b9/mydocs/plans/task_m010_28_impl.md)
- provenance 문서: [task_m010_28_sample_provenance.md](https://github.com/postmelee/alhangeul-macos/blob/e94e09bb92641a3797072be9db979d3a095b42b9/mydocs/tech/task_m010_28_sample_provenance.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/e94e09bb92641a3797072be9db979d3a095b42b9/mydocs/working/task_m010_28_stage1.md) ~ [stage5](https://github.com/postmelee/alhangeul-macos/blob/e94e09bb92641a3797072be9db979d3a095b42b9/mydocs/working/task_m010_28_stage5.md)
- 최종 보고서: [task_m010_28_report.md](https://github.com/postmelee/alhangeul-macos/blob/e94e09bb92641a3797072be9db979d3a095b42b9/mydocs/report/task_m010_28_report.md)
```

### PR #43

```markdown
- 수행 계획서: [task_m050_29.md](https://github.com/postmelee/alhangeul-macos/blob/fc1df58bb5d9b4e8b533550cba17552e52fb36b4/mydocs/plans/task_m050_29.md)
- 구현 계획서: [task_m050_29_impl.md](https://github.com/postmelee/alhangeul-macos/blob/fc1df58bb5d9b4e8b533550cba17552e52fb36b4/mydocs/plans/task_m050_29_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/fc1df58bb5d9b4e8b533550cba17552e52fb36b4/mydocs/working/task_m050_29_stage1.md) ~ [stage6](https://github.com/postmelee/alhangeul-macos/blob/fc1df58bb5d9b4e8b533550cba17552e52fb36b4/mydocs/working/task_m050_29_stage6.md)
- 최종 보고서: [task_m050_29_report.md](https://github.com/postmelee/alhangeul-macos/blob/fc1df58bb5d9b4e8b533550cba17552e52fb36b4/mydocs/report/task_m050_29_report.md)
```

### PR #42

```markdown
- 수행 계획서: [task_m030_35.md](https://github.com/postmelee/alhangeul-macos/blob/69361546bc24c0caffbedaca14cea177b7c01059/mydocs/plans/task_m030_35.md)
- 구현 계획서: [task_m030_35_impl.md](https://github.com/postmelee/alhangeul-macos/blob/69361546bc24c0caffbedaca14cea177b7c01059/mydocs/plans/task_m030_35_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/69361546bc24c0caffbedaca14cea177b7c01059/mydocs/working/task_m030_35_stage1.md) ~ [stage6](https://github.com/postmelee/alhangeul-macos/blob/69361546bc24c0caffbedaca14cea177b7c01059/mydocs/working/task_m030_35_stage6.md)
- 최종 보고서: [task_m030_35_report.md](https://github.com/postmelee/alhangeul-macos/blob/69361546bc24c0caffbedaca14cea177b7c01059/mydocs/report/task_m030_35_report.md)
- 오늘할일: [20260425.md](https://github.com/postmelee/alhangeul-macos/blob/69361546bc24c0caffbedaca14cea177b7c01059/mydocs/orders/20260425.md)
```

### PR #41

```markdown
- 수행 계획서: [task_m050_40.md](https://github.com/postmelee/alhangeul-macos/blob/8932ae7537b90f5eef5f72286df74cedfb969c57/mydocs/plans/task_m050_40.md)
- 구현 계획서: [task_m050_40_impl.md](https://github.com/postmelee/alhangeul-macos/blob/8932ae7537b90f5eef5f72286df74cedfb969c57/mydocs/plans/task_m050_40_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/8932ae7537b90f5eef5f72286df74cedfb969c57/mydocs/working/task_m050_40_stage1.md) ~ [stage6](https://github.com/postmelee/alhangeul-macos/blob/8932ae7537b90f5eef5f72286df74cedfb969c57/mydocs/working/task_m050_40_stage6.md)
- 최종 보고서: [task_m050_40_report.md](https://github.com/postmelee/alhangeul-macos/blob/8932ae7537b90f5eef5f72286df74cedfb969c57/mydocs/report/task_m050_40_report.md)
- Troubleshooting: [task_m050_40_quicklook_thumbnail_registration_validation.md](https://github.com/postmelee/alhangeul-macos/blob/8932ae7537b90f5eef5f72286df74cedfb969c57/mydocs/troubleshootings/task_m050_40_quicklook_thumbnail_registration_validation.md)
```

### PR #39

```markdown
- 수행 계획서: [task_m050_33.md](https://github.com/postmelee/alhangeul-macos/blob/2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619/mydocs/plans/task_m050_33.md)
- 구현 계획서: [task_m050_33_impl.md](https://github.com/postmelee/alhangeul-macos/blob/2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619/mydocs/plans/task_m050_33_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619/mydocs/working/task_m050_33_stage1.md) ~ [stage5](https://github.com/postmelee/alhangeul-macos/blob/2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619/mydocs/working/task_m050_33_stage5.md)
- 최종 보고서: [task_m050_33_report.md](https://github.com/postmelee/alhangeul-macos/blob/2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619/mydocs/report/task_m050_33_report.md)
```

### PR #38

```markdown
- 수행 계획서: [task_m050_37.md](https://github.com/postmelee/alhangeul-macos/blob/7adc116bf97291c5b151c61cf0146408044a1c0e/mydocs/plans/task_m050_37.md)
- 구현 계획서: [task_m050_37_impl.md](https://github.com/postmelee/alhangeul-macos/blob/7adc116bf97291c5b151c61cf0146408044a1c0e/mydocs/plans/task_m050_37_impl.md)
- 단계 보고서: [task_m050_37_stage1.md](https://github.com/postmelee/alhangeul-macos/blob/7adc116bf97291c5b151c61cf0146408044a1c0e/mydocs/working/task_m050_37_stage1.md)
- 최종 보고서: [task_m050_37_report.md](https://github.com/postmelee/alhangeul-macos/blob/7adc116bf97291c5b151c61cf0146408044a1c0e/mydocs/report/task_m050_37_report.md)
```

### PR #36

```markdown
- 수행 계획서: [task_m050_26.md](https://github.com/postmelee/alhangeul-macos/blob/015a2fe50cf6720e198551e54ef3588a5b133302/mydocs/plans/task_m050_26.md)
- 구현 계획서: [task_m050_26_impl.md](https://github.com/postmelee/alhangeul-macos/blob/015a2fe50cf6720e198551e54ef3588a5b133302/mydocs/plans/task_m050_26_impl.md)
- 단계 보고서: [task_m050_26_stage1.md](https://github.com/postmelee/alhangeul-macos/blob/015a2fe50cf6720e198551e54ef3588a5b133302/mydocs/working/task_m050_26_stage1.md)
- 최종 보고서: [task_m050_26_report.md](https://github.com/postmelee/alhangeul-macos/blob/015a2fe50cf6720e198551e54ef3588a5b133302/mydocs/report/task_m050_26_report.md)
```

### PR #34

```markdown
- 수행 계획서: [task_m050_27.md](https://github.com/postmelee/alhangeul-macos/blob/8cf41fbfc3786ffe7c71871eb39235954e6a41d3/mydocs/plans/task_m050_27.md)
- 구현 계획서: [task_m050_27_impl.md](https://github.com/postmelee/alhangeul-macos/blob/8cf41fbfc3786ffe7c71871eb39235954e6a41d3/mydocs/plans/task_m050_27_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/8cf41fbfc3786ffe7c71871eb39235954e6a41d3/mydocs/working/task_m050_27_stage1.md) ~ [stage4](https://github.com/postmelee/alhangeul-macos/blob/8cf41fbfc3786ffe7c71871eb39235954e6a41d3/mydocs/working/task_m050_27_stage4.md)
- 최종 보고서: [task_m050_27_report.md](https://github.com/postmelee/alhangeul-macos/blob/8cf41fbfc3786ffe7c71871eb39235954e6a41d3/mydocs/report/task_m050_27_report.md)
```

### PR #25

```markdown
- 수행 계획서: [task_m010_24.md](https://github.com/postmelee/alhangeul-macos/blob/7c62f6870c842444085cbc04c45dbdcfef9be0e4/mydocs/plans/task_m010_24.md)
- 구현 계획서: [task_m010_24_impl.md](https://github.com/postmelee/alhangeul-macos/blob/7c62f6870c842444085cbc04c45dbdcfef9be0e4/mydocs/plans/task_m010_24_impl.md)
- 단계 보고서: [stage1](https://github.com/postmelee/alhangeul-macos/blob/7c62f6870c842444085cbc04c45dbdcfef9be0e4/mydocs/working/task_m010_24_stage1.md) ~ [stage4](https://github.com/postmelee/alhangeul-macos/blob/7c62f6870c842444085cbc04c45dbdcfef9be0e4/mydocs/working/task_m010_24_stage4.md)
- 최종 보고서: [task_m010_24_report.md](https://github.com/postmelee/alhangeul-macos/blob/7c62f6870c842444085cbc04c45dbdcfef9be0e4/mydocs/report/task_m010_24_report.md)
```

### PR #23

```markdown
- 최종 보고서: [task_m050_22_report.md](https://github.com/postmelee/alhangeul-macos/blob/d5bd5083abc9f04d73e95b152d6ce055c081b4c4/mydocs/report/task_m050_22_report.md)
- Finder Feedback Assistant 제출 문서: [finder_icon_view_recent_opened_scroll_feedback_assistant.md](https://github.com/postmelee/alhangeul-macos/blob/d5bd5083abc9f04d73e95b152d6ce055c081b4c4/mydocs/troubleshootings/finder_icon_view_recent_opened_scroll_feedback_assistant.md)
```

## 제외 유지

| PR | 제외 사유 |
|----|-----------|
| #53 | 이미 commit SHA 고정 URL 사용 |
| #19 | `mydocs/` 경로가 검증 명령과 변경 설명 안에 있음 |
| #18 | `mydocs/` 경로가 검증 명령 안에 있음 |
| #14 | 문서 이동 설명이며 별도 문서 링크 섹션이 아님 |
| #12 | 변경 내역 설명의 파일 경로 나열 |
| #10 | 릴리스/배포 문서 분리 설명 |

## 검증

```bash
git cat-file -e {head_sha}:mydocs/...
git diff --check -- mydocs/working/task_m010_52_stage2.md
```

결과:

- 보정 대상 문서 경로가 각 PR head SHA에 모두 존재함을 확인했다.
- `git diff --check -- mydocs/working/task_m010_52_stage2.md` 통과.

## 다음 단계

Stage 3에서 위 보정안에 따라 PR 본문을 수정한다. 수정 직전에는 각 PR 본문을 다시 조회해 본문이 Stage 2 이후 변경되지 않았는지 확인한다.
