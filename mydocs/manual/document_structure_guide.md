# 문서 구조와 명명 규칙 매뉴얼

본 매뉴얼은 `mydocs/` 하위 폴더 역할, 문서 파일명 규칙, 외부 기여자 PR 검토 폴더 정책, Agent Skills 위치 정책을 정의한다. 새 문서를 만들거나 기존 문서의 위치를 옮기기 전에 읽는다. 코드 작성 방식, Git 브랜치 운용, 타스크 단계 진행 절차는 이 문서가 아니라 관련 매뉴얼에서 다룬다. 모든 문서는 한국어로 작성한다.

## 핵심 용어

- **문서 진실 원천**: 같은 정보를 여러 곳에 복제하지 않고, 최신 기준으로 삼는 단일 문서 또는 폴더.
- **내부 타스크**: GitHub Issue를 기준으로 수행계획서, 구현계획서, 단계 보고서, 최종 보고서를 남기는 저장소 내부 작업.
- **외부 기여 PR**: 외부 기여자가 제출한 Pull Request를 검토하는 작업. 내부 타스크와 다른 폴더와 절차를 사용한다.
- **마일스톤 포함 문서명**: `task_m010_49.md`처럼 마일스톤과 이슈 번호를 함께 넣은 신규 문서명.
- **Agent Skills 진실 원천**: Codex와 Claude Code가 함께 읽는 `mydocs/skills/{skill-name}/SKILL.md`.

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
| `release/` | 릴리즈별 장기 기록 | `v<version>.md` 형식. GitHub Release/Pages/appcast/검증/provenance 기록 |
| `manual/` | 매뉴얼, 가이드 | 사용자/개발자 문서 |
| `troubleshootings/` | 트러블슈팅, 재발 방지 기록 | |
| `pr/` | 외부 기여자 PR 검토 기록 | 내부 타스크와 분리 |
| `pr/archives/` | 처리 완료된 PR 검토 기록 보관 | |
| `skills/` | Agent Skills SKILL.md 진실 원천 | `.agents/skills`와 `.claude/skills` 심볼릭 링크가 이 폴더를 가리킨다 |

## 릴리즈 기록 폴더 정책

`mydocs/release/`는 public release별 장기 기록을 보관한다. GitHub Release 본문은 public 배포 안내, Pages는 사용자용 짧은 릴리즈 노트, README는 최신 공개 릴리즈 1개 요약을 맡고, 내부 검증과 release decision record는 `release/`에 남긴다.

파일명 규칙:

- 릴리즈 인덱스: `mydocs/release/index.md`
- 릴리즈별 기록: `mydocs/release/v<version>.md` (예: `v0.1.1.md`)

릴리즈별 기록에는 다음을 포함한다.

- 사용자용 요약
- 직전 공개 릴리즈 대비 변경점
- 연결된 Issue/PR과 기여자
- 검증 결과와 public release에서 반복할 smoke 항목
- 알려진 제한 사항과 후속 이슈
- `rhwp` core와 viewer asset provenance
- GitHub Release, Pages 릴리즈 노트, Sparkle appcast 링크

`mydocs/tech/release_environment.md`는 비밀이 아닌 운영 환경 식별자만 기록한다. Team ID, signing identity 표시명, notary profile name처럼 절차 실행에 필요한 이름은 이 문서로 분리할 수 있지만, password, private key, exported signing identity, token은 어떤 문서에도 기록하지 않는다.

`mydocs/troubleshootings/`는 실제 실패 사례와 재발 방지 절차가 있는 경우에만 사용한다. 일반 release policy, 버전별 release decision record, 단순 체크리스트는 troubleshooting으로 옮기지 않는다. Gatekeeper, notarization, Finder integration, appcast push 같은 주제라도 실제 실패 증상, 재현 조건, 원인, 예방 절차가 함께 있을 때만 troubleshooting 문서로 분리한다.

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

## FAQ / 흔한 실수

### 마일스톤이 아직 확정되지 않았을 때

신규 하이퍼-워터폴 타스크는 GitHub Issue의 마일스톤을 먼저 확인한다. 이슈가 아직 없으면 [`task-register`](../skills/task-register/SKILL.md) Skill로 열린 milestone을 확인하고 생성 전 작업지시자 승인을 받는다. 마일스톤이 비어 있거나 모호하면 임의로 `m000` 같은 임시명을 만들지 말고 작업지시자에게 확인한다. 기존 레거시 문서는 이름을 유지할 수 있지만, 신규 문서는 마일스톤 포함 형식을 기준으로 한다.

### 외부 PR인지 내부 타스크인지 경계가 모호할 때

외부 기여자가 올린 PR을 검토하는 작업이면 `mydocs/pr/`와 [`pr_process_guide.md`](pr_process_guide.md)를 우선한다. 저장소 내부 Issue를 해결하기 위해 직접 변경하는 작업이면 `plans/`, `working/`, `report/` 흐름을 따른다. 외부 PR 검토 중 내부 후속 수정이 필요해지면 별도 GitHub Issue를 만들고 내부 타스크로 분리하는 편이 추적하기 쉽다.

## 관련 매뉴얼

- [`task_workflow_guide.md`](task_workflow_guide.md): 내부 타스크의 수행계획서, 구현계획서, 단계 보고서, 최종 보고서 진행 순서.
- [`git_workflow_guide.md`](git_workflow_guide.md): `local/taskN`, `publish/taskN`, `devel-webview`/`devel` 통합 브랜치 운용.
- [`pr_process_guide.md`](pr_process_guide.md): 외부 기여자 PR 검토 절차.
