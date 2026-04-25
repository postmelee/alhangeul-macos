# Issue #57 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 책임 경계를 기준으로 번호 없는 작업을 GitHub Issue로 등록하는 신규 Skill `task-register`를 작성한다.

## 산출물

| 파일 | 요약 | 줄 수 |
|------|------|-------|
| `mydocs/skills/task-register/SKILL.md` | 신규 타스크 이슈 등록 Skill 본문 | 113 |

Stage 2는 Skill 본문 작성에 한정했다. 매뉴얼 보강은 구현계획서에 따라 Stage 3에서 진행한다.

## 작성 내용

`task-register`는 다음 책임만 갖도록 작성했다.

- 번호 없는 작업의 중복 이슈 검색
- 열린 GitHub milestone 목록 조회
- 기존 GitHub label 목록 조회
- milestone과 label 후보 선택
- 이슈 제목/본문/milestone/label 초안 작성
- `gh issue create` 실행 전 작업지시자 승인 요청
- 승인 후 이슈 생성과 생성 결과 확인
- 생성된 이슈 번호를 보고하고 `task-start` 진입 승인 대기

`task-start`와의 경계도 명시했다.

- `task-register`는 브랜치를 만들지 않는다.
- `task-register`는 오늘할일을 갱신하지 않는다.
- `task-register`는 수행계획서를 만들지 않는다.
- 이슈 생성 후에도 승인 없이 `task-start`를 이어서 실행하지 않는다.

## 안전장치

Skill 본문에 다음 금지 사항을 포함했다.

- 작업지시자 승인 없이 `gh issue create` 실행 금지
- 새 milestone 또는 새 label 생성 금지
- 닫힌 milestone 임의 사용 금지
- 이슈 생성 후 승인 없는 `task-start` 실행 금지
- Skill 내부에서 브랜치 생성, 오늘할일 갱신, 수행계획서 작성 금지

## 검증 결과

구현계획서의 Stage 2 검증 명령을 실행했다.

```bash
test -f mydocs/skills/task-register/SKILL.md
test -f .agents/skills/task-register/SKILL.md
test -f .claude/skills/task-register/SKILL.md
rg -n "name: task-register|allow_implicit_invocation: false|gh issue create|milestone|label|task-start|승인" \
  mydocs/skills/task-register/SKILL.md
git diff --check -- mydocs/skills/task-register/SKILL.md mydocs/working/task_m010_57_stage2.md
```

결과:

- `mydocs/skills/task-register/SKILL.md` 존재 확인
- `.agents/skills/task-register/SKILL.md` 심볼릭 링크 경로 노출 확인
- `.claude/skills/task-register/SKILL.md` 심볼릭 링크 경로 노출 확인
- `name: task-register` 확인
- `allow_implicit_invocation: false` 확인
- `gh issue create`, `milestone`, `label`, `task-start`, `승인` 핵심 문구 확인
- Stage 2 변경 파일 공백 검증 통과

추가 확인:

```bash
wc -l mydocs/skills/task-register/SKILL.md
```

결과:

- `mydocs/skills/task-register/SKILL.md`: 113줄

## 잔여 위험

- milestone/label 선택 기준은 현재 GitHub 설정에 의존한다. milestone이나 label 체계가 바뀌면 Skill 본문도 갱신해야 한다.
- Skill 본문만 추가된 상태라 `task_workflow_guide.md`의 기존 "새 타스크 등록" 한 줄 예시는 아직 `task-register`를 가리키지 않는다. Stage 3에서 보강한다.

## 다음 단계 영향

Stage 3에서는 `mydocs/manual/task_workflow_guide.md`를 보강해 이슈가 없는 작업은 `task-register`로 먼저 등록하고, 이미 이슈가 있는 작업은 `task-start`로 시작한다는 경계를 매뉴얼에도 반영한다. 필요할 경우 `mydocs/manual/document_structure_guide.md`의 마일스톤 FAQ도 최소 수정한다.

## 승인 요청

Stage 3 이슈 등록 선행 절차 매뉴얼 보강으로 진행할지 승인 요청한다.
