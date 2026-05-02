# Task #112 최종 결과 보고서

## 작업 요약

- **이슈**: [#112 PR 본문 구조와 관련 이슈 작성 규칙 강화](https://github.com/postmelee/alhangeul-macos/issues/112)
- **마일스톤**: 하이퍼-워터폴 작업환경 조성
- **브랜치**: `local/task112`
- **단계 수**: 4단계 + Stage 3.1 보정
- **목적**: PR 본문이 리뷰어에게 `무엇/왜/이슈/테스트/문서/리스크`를 짧고 일관되게 전달하도록 템플릿, 가이드, 최종 보고 절차를 정리하는 것

## 단계별 진행

| Stage | Commit | 핵심 내용 |
|-------|--------|-----------|
| 계획 | `c3bd39b`, `9dd1314`, `022b675` | 수행계획서, 구현계획서 작성과 Stage commit 링크 기준 보강 |
| 1 | `f52f084` | PR 본문 규칙의 중복, 충돌, 제거 대상 정리 |
| 2 | `330ee26` | PR 템플릿을 짧은 대단원 구조로 개편 |
| 3 | `ba3c395` | PR 처리 가이드, `task-final-report`, Git workflow, Copilot 지시 보정 |
| 3.1 | `7124066` | 기본 PR 생성 상태를 Draft가 아니라 Open PR로 보정 |
| 4 | 본 커밋 | 통합 검증, 오늘할일 완료 처리, 최종 보고서와 Stage 4 보고서 작성 |

## 변경 파일과 영향 범위

| 대상 | 영향 |
|------|------|
| `.github/pull_request_template.md` | 질문형 요약, Stage report+commit 링크, 작업 문서 링크, 조건부 Before/After, 관련 이슈/후속 이슈/리스크 구조 반영 |
| `mydocs/manual/pr_process_guide.md` | 내부 task PR 작성 기준을 새 템플릿 구조와 같은 용어로 정리 |
| `mydocs/skills/task-final-report/SKILL.md` | `--body-file` 우선, Open PR 기본 생성, PR 본문 링크/검증 기준 반영 |
| `mydocs/manual/git_workflow_guide.md` | `publish/taskN` 기반 Open PR 생성 예시와 PR 본문 링크 기준 보정 |
| `mydocs/manual/task_workflow_guide.md` | 최종 PR 생성 단계를 Open PR 기준으로 보정 |
| `.github/copilot-instructions.md` | Copilot review가 PR 설명의 대상 타스크/관련 이슈 분리, Stage 링크, 실제 검증 기록을 확인하도록 보정 |
| `README.md` | Hyper-Waterfall Git workflow 다이어그램의 PR 상태를 Open PR 기준으로 보정 |
| `mydocs/plans`, `mydocs/working`, `mydocs/report`, `mydocs/orders` | #112 계획, 단계 보고, 최종 보고, 완료 상태 기록 |

## 확정된 PR 작성 기준

- `요약`은 최대 4개 bullet로 대상 타스크, 변경 이유, 변경 내용, 핵심 리뷰 지점을 답한다.
- 직접 수행 issue는 `대상 타스크`에 적고, `관련 이슈`는 선행, 후속, Epic, upstream, 참고 PR/issue만 적는다.
- `변경 내역` 안에 Stage별 요약, 주요 파일/영역 표, 작업 문서 링크를 둔다.
- Stage별 요약은 `**[Stage 1](stage-url)** ([0cdbae0](commit-url)): 요약`처럼 단계 보고서와 commit 링크를 함께 쓴다.
- 주요 파일/영역 표는 최대 5행, 핵심 리뷰 포인트는 최대 3개, 코드 블록은 각 20줄 이하로 둔다.
- 검증은 실제 실행한 명령만 남기고, 시각적 변경사항이 있을 때만 Before/After 표를 사용한다.
- 최상위 `## 문서` 섹션은 쓰지 않는다. 단계 보고서는 Stage별 요약에서 링크하고, 수행/구현/최종 보고서는 `변경 내역`의 작업 문서 항목으로 묶는다.
- 하이퍼-워터폴 최종 PR은 기본적으로 `devel` 대상 Open PR로 생성한다. Draft PR은 작업지시자가 명시 지시한 경우에만 예외로 사용한다.

## 검증 결과

실행한 명령:

```bash
git diff --check
for pattern in "대상 타스크" "관련 이슈" "후속 이슈 제안" "핵심 리뷰 포인트" "작업 문서" "단계 보고서" "Before" "After"; do
  rg -n "$pattern" .github/pull_request_template.md
done
for pattern in "대상 타스크" "관련 이슈" "후속 이슈 제안" "최대 4" "최대 5행" "20줄 이하" "작업 문서" "단계 보고서" "Before/After"; do
  rg -n "$pattern" mydocs/manual/pr_process_guide.md
done
for pattern in "Open PR" "body-file" "핵심 리뷰 포인트" "후속 이슈 제안" "작업 문서" "단계 보고서" "Before/After"; do
  rg -n "$pattern" mydocs/skills/task-final-report/SKILL.md
done
rg -n "## 문서|Closes #" \
  .github/pull_request_template.md \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md
rg -n "devel 대상 draft|draft PR 생성|--draft|ready for review" \
  README.md \
  mydocs/manual/git_workflow_guide.md \
  mydocs/manual/task_workflow_guide.md \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/plans/task_m010_112_impl.md
rg -n "^\| #112 \|.*\| 완료 \|.*완료: [0-9]{2}:[0-9]{2}" mydocs/orders/20260501.md
test -f mydocs/report/task_m010_112_report.md
```

결과:

- `git diff --check` 통과
- PR 템플릿, PR 처리 가이드, `task-final-report` 각각에서 담당하는 대상 타스크, 관련 이슈, 후속 이슈 제안, 핵심 리뷰 포인트, 작업 문서, Stage report+commit 링크, Before/After 기준 확인
- 제거 대상인 `## 문서`, `Closes #`는 지정 파일에서 출력 없음
- Draft 기본 생성 문구와 `--draft` 옵션은 활성 운영 문서에서 출력 없음
- 오늘할일 #112 행의 `완료` 상태와 `완료: HH:mm` 형식 확인
- 최종 보고서 파일 존재 확인

문서/운영 규격 변경만 수행했으므로 Swift, Rust, Xcode 빌드 검증은 수행하지 않았다.

## 수용 기준 충족 여부

| 기준 | 결과 |
|------|------|
| `대상 타스크`와 맥락용 `관련 이슈` 분리 | OK |
| `변경 내역` 안에 Stage 요약, 파일/영역 요약, 작업 문서 링크 배치 | OK |
| Stage report 링크와 짧은 commit 링크 형식 문서화 | OK |
| `문서` 최상위 섹션 제거 | OK |
| 질문형 프롬프트 반영 | OK |
| Before/After는 시각 변경 시에만 사용 | OK |
| 짧게 강제하는 기준 반영 | OK |
| 최종 PR 기본 상태를 Open PR로 보정 | OK |
| 오늘할일 완료 처리 | OK |

## 남은 리스크

- PR body lint 스크립트는 이번 범위에서 제외했다. 같은 누락이 반복되면 별도 이슈로 자동 검증을 도입하는 편이 좋다.
- Stage report+commit 링크는 PR 작성 시 실제 GitHub URL을 구성해야 한다. 절차와 예시는 정리됐지만 자동 생성기는 아직 없다.
- 기존 과거 계획서와 완료 보고서에는 `draft PR` 표현이 남아 있다. 역사 기록이므로 수정하지 않았고, 앞으로의 운영 기준은 이번에 보정한 매뉴얼과 Skill을 따른다.

## 결론

Issue #112의 목표였던 PR 본문 구조, 관련 이슈 의미, 문서 링크 위치, 짧게 강제하는 기준, 조건부 Before/After, Stage commit 링크, Open PR 기본 생성 기준 정리는 완료됐다. 작업지시자 승인 후 `task-final-report` 절차로 `publish/task112` 원격 브랜치 push와 `devel` 대상 Open PR 생성을 진행할 수 있다.
