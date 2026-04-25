# 문서 구조와 명명 규칙 매뉴얼

본 매뉴얼은 `mydocs/` 하위 폴더 역할, 문서 파일명 규칙, 외부 기여자 PR 검토 폴더 정책, Agent Skills 위치 정책을 정의한다. 모든 문서는 한국어로 작성한다.

## 문서 폴더 구조

`mydocs/` 하위:

- `orders/` - 오늘 할일 문서 (`yyyymmdd.md`)
- `plans/` - 수행 계획서, 구현 계획서
- `plans/archives/` - 완료된 계획서 보관
- `working/` - 단계별 완료 보고서
- `report/` - 최종 보고서와 장기 보관 보고서
- `feedback/` - 작업지시자 피드백, 코드 리뷰 의견
- `tech/` - 기술 조사, 구조 분석, 스펙 정리
- `manual/` - 개발자/사용자 매뉴얼
- `troubleshootings/` - 트러블슈팅과 재발 방지 기록
- `pr/` - 외부 PR 검토 기록
- `pr/archives/` - 처리 완료 PR 검토 기록 보관
- `skills/` - Agent Skills 진실 원천 (Codex/Claude Code 공용)

## 문서 파일명 규칙

신규 문서의 표준 형식은 GitHub Issue 번호와 마일스톤을 함께 사용한다.

- 수행 계획서: `task_{milestone}_{이슈번호}.md` (예: `task_m100_7.md`)
- 구현 계획서: `task_{milestone}_{이슈번호}_impl.md` (예: `task_m100_7_impl.md`)
- 단계별 완료 보고서: `task_{milestone}_{이슈번호}_stage{N}.md` (예: `task_m100_7_stage1.md`)
- 최종 보고서: `task_{milestone}_{이슈번호}_report.md` (예: `task_m100_7_report.md`)

강제 규칙:

- 신규 작성 문서는 반드시 `task_{milestone}_{이슈번호}` 형식을 사용한다.
- 마일스톤은 항상 `m{숫자}` 형식으로 적는다. 예: `m100`, `m200`
- 마일스톤 없이 `task_{이슈번호}` 형식으로 신규 문서를 만들지 않는다.
- 기존 레거시 문서명은 유지할 수 있으나, 신규 이슈부터는 마일스톤 포함 형식을 고정한다.

## 폴더 역할 (엄격 준수)

| 폴더 | 용도 | 비고 |
|------|------|------|
| `orders/` | 오늘 할일 | `yyyymmdd.md`만 허용. 상세 조사/분석은 `tech/` 또는 `troubleshootings/`에 기록. 완료 항목은 비고에 `완료: HH:mm` 형식으로 완료 시각 기록 |
| `plans/` | 수행/구현 계획서 | `_stage{N}`, `_report` 파일은 두지 않는다 |
| `plans/archives/` | 완료된 계획서 보관 | merge 후 정리 시 사용 |
| `working/` | 단계별 완료 보고서 (`_stage{N}.md`) | 최종 보고서는 두지 않는다 |
| `report/` | 최종 결과보고서 (`_report.md`) + 장기 보관 보고서 | 최종 보고서는 반드시 이 폴더 |
| `feedback/` | 작업지시자 피드백, 코드 리뷰 의견 | |
| `tech/` | 기술 조사, 구조/스펙 분석 | |
| `manual/` | 매뉴얼, 가이드 | 사용자/개발자 문서 |
| `troubleshootings/` | 트러블슈팅, 재발 방지 기록 | |
| `pr/` | 외부 기여자 PR 검토 기록 | 내부 타스크와 분리 |
| `pr/archives/` | 처리 완료된 PR 검토 기록 보관 | |
| `skills/` | Agent Skills SKILL.md 진실 원천 | `.agents/skills`와 `.claude/skills` 심볼릭 링크가 이 폴더를 가리킨다 |

## 외부 기여자 PR 처리 (`mydocs/pr/`)

외부 기여 PR 검토 상세 절차는 [`pr_process_guide.md`](pr_process_guide.md)를 따른다.

강제 규칙:

- 외부 기여자 PR은 내부 타스크와 다른 본질을 가지므로 별도 절차와 폴더를 사용한다.
- 이 목차는 외부 기여 PR 검토에만 적용한다.
- 외부 PR 검토 기록은 `mydocs/pr/`에 남긴다.
- 파일명은 `pr_{번호}_review.md`, `pr_{번호}_review_impl.md`(필요 시), `pr_{번호}_report.md`를 사용한다.
- 처리 완료 문서는 `mydocs/pr/archives/`로 이동한다.

내부 타스크의 `수행 -> 구현 -> 단계별 보고 -> 최종 보고` 절차는 외부 기여 PR 검토에 그대로 적용하지 않는다. 상세는 [`pr_process_guide.md`](pr_process_guide.md) 참조.

## Agent Skills 위치 정책

- 진실 원천: `mydocs/skills/{skill-name}/SKILL.md`
- Codex 인식 경로: `.agents/skills/` (저장소 루트 심볼릭 링크 → `mydocs/skills`)
- Claude Code 인식 경로: `.claude/skills/` (저장소 루트 심볼릭 링크 → `mydocs/skills`)
- 두 심볼릭 링크는 git에 mode `120000`으로 커밋된다.
- skill 본문은 도구 비종속(`gh`, `git`, 파일 생성)으로 작성하고, 도구별 호출 차이는 SKILL.md 말미 "호출 방법" 섹션에만 둔다.
- 모든 SKILL.md는 frontmatter에 `allow_implicit_invocation: false`를 명시해 양 도구에서 명시 호출만 허용한다.
