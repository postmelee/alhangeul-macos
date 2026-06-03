---
name: external-pr-review
description: |
  외부 기여자 PR 검토 절차를 적용한다. 명시 호출 시에만 사용한다.
  PR 초기 triage 권장값(reviewer/assignee/label/milestone)을 먼저 안내하고,
  작업지시자 수락 후 mydocs/pr/pr_{N}_review.md 작성, 검증, 권고 판단을 수행한다.
  수정 요청/보류/닫기 또는 내부 후속 분리 필요 시 코멘트 초안은 응답으로만 제시한다.
  승인된 GitHub 공개 review/comment는 body-file 검증 후 등록한다.
  외부 기여자 PR 전용 (내부 타스크에는 사용 금지).
allow_implicit_invocation: false
---

# 외부 기여자 PR 검토

## 트리거

- 명시 호출만: 작업지시자가 "PR #N 리뷰" 또는 "외부 PR 검토"를 명시 지시한 경우
- 본 SKILL을 직접 호출한 경우

## 사전 조건

- 검토 대상 PR이 외부 기여자 fork에서 본 저장소 `devel`(또는 합의된 base)로 열린 상태
- 내부 타스크 PR(`publish/task{N}`)에는 본 SKILL 사용 금지 — 내부 타스크는 일반 단계 절차로 검토
- `gh` CLI 인증

## 절차

1. 초기 triage 메타 수집
   ```bash
   gh pr view {N} --json number,title,state,author,baseRefName,headRefName,headRepository,isCrossRepository,assignees,labels,milestone,reviewRequests,body,files,url
   ```
   - base/head, fork 여부, 작성자, 현재 reviewer request/assignee/label/milestone, 연결 이슈 후보, 변경 파일 목록만 확인한다.
   - 연결 이슈가 있으면 이슈의 label/milestone을 추가 조회한다.
     ```bash
     gh issue view {ISSUE} --json number,title,state,labels,milestone,assignees,url
     ```
   - 작성자의 첫 외부 기여 여부는 최근/전체 PR에서 작성자 기존 기여와 merge 이력을 확인해 판단한다.
2. Review 시작 triage gate
   - 현재 상태와 권장 triage 값을 작업지시자에게 먼저 응답으로 안내한다.
     - reviewer: 작업지시자/maintainer가 지정한 reviewer
     - assignee: 작성자 또는 담당 maintainer 중 프로젝트 운영 기준에 맞는 사람
     - label: 변경 성격 기준 (`documentation`, `bug`, `enhancement`, `area:*` 등)
     - milestone: 연결 이슈 milestone 우선. 없거나 애매하면 작업지시자 확인
   - 작업지시자에게 다음 중 하나를 명시 선택하게 하고 여기서 멈춘다.
     - triage 적용 후 리뷰 진행
     - triage 적용 없이 리뷰 진행
     - triage 값 조정
   - 같은 메시지에서 작업지시자가 triage 값과 리뷰 진행을 명시 승인한 경우에만 다음 단계로 이어간다.
   - 승인 전에는 GitHub PR 상태 수정, review 문서 작성, 본격 diff 검토를 하지 않는다.
3. 승인된 triage 적용
   - 작업지시자가 triage 적용을 승인한 경우 필요한 항목만 실행한다.
     ```bash
     gh pr edit {N} --add-reviewer {login}
     gh pr edit {N} --add-assignee {login}
     gh pr edit {N} --add-label "{label}"
     gh pr edit {N} --milestone "{milestone}"
     ```
   - 권한 문제로 reviewer/assignee/label/milestone 적용이 실패하면 실패 항목을 기록하고, 리뷰 진행 여부를 작업지시자에게 확인한다.
4. 본 리뷰 메타와 diff 수집
   ```bash
   gh pr view {N} --json number,title,state,author,baseRefName,headRefName,headRepository,isCrossRepository,mergeable,mergeStateStatus,reviewDecision,assignees,labels,milestone,reviewRequests,body,comments,reviews,commits,files
   gh pr diff {N} | head -200
   gh pr checks {N}
   ```
   - 이슈 연결, base/head, fork 여부, mergeable, CI 상태, reviewer/assignee/label/milestone, 기존 코멘트/리뷰를 모두 확인한다.
5. 검토 문서 작성: `mydocs/pr/pr_{N}_review.md`
   - 표준 섹션:
     - PR 정보 (번호, 작성자, base/head, 연결 이슈)
     - Review 시작 triage (초기 상태, 권장값, 작업지시자 선택, 적용 결과)
     - 변경 요약
     - 영향 범위와 호환성 (FFI, build, 문서, Quick Look/Thumbnail, core pin)
     - 코드/문서 점검 결과
     - 기여자 피드백 판단
       - 잘 된 점과 유지할 방향
       - 기여자에게 요청할 변경
       - 내부 후속 Issue/타스크로 분리할 항목
       - 이 PR 범위에 포함하지 않을 항목
     - 검증 계획 (필요한 추가 검증)
     - 권고 (merge / cherry-pick 통합 / 수정 요청 / 보류 / 닫기)
     - merge 후 완료 처리 handoff 필요 여부
     - 작업지시자 승인 요청
   - PR/Issue 코멘트 초안 전문은 review 문서에 쓰지 않는다. 문서에는 피드백 필요 여부와 요지만 기록한다.
6. 필요 시 수정·검증 계획 문서 작성: `mydocs/pr/pr_{N}_review_impl.md`
   - 본 저장소에서 추가 검증을 직접 수행할 때 사용한다.
   - 작성 후 작업지시자 승인 요청을 남긴다.
7. 검증 수행 (해당하는 경우만)
   - 빌드/렌더 smoke test 등은 변경 유형에 따라 `build_run_guide.md`와 `swift_macos_code_rules_guide.md` 정책을 적용한다.
   - 자기검증만 있는 저장/렌더/호환성 변경은 실제 origin 샘플, 앱 smoke, 시각 비교, 또는 설치본 기준 검증 필요 여부를 따로 판단한다.
8. 기여자 공개 피드백 초안 정리 (응답 전용)
   - `수정 요청`, `보류`, `닫기`, `분리 재제출` 권고라면 작업지시자가 GitHub에 직접 등록할 코멘트 초안을 최종 응답에 제시한다.
   - `merge 가능` 권고라면 완료 코멘트 초안을 만들지 않는다. merge/cherry-pick 후 `external-pr-complete`에서 처리한다.
   - 첫 기여자라면 환영/감사를 포함하고, 칭찬은 실제 PR에서 확인한 구체적 기여 사실에 붙인다.
   - 문제 안내는 파일/동작/검증 기대값을 포함해 기여자가 바로 수정할 수 있게 쓴다.
   - GitHub PR/Issue 참조 표기는 아래 "GitHub 참조 표기 규칙"을 따른다.
   - 내부 후속 수정은 PR 안에서 몰래 반영하지 않는다. 별도 Issue/내부 타스크 후보와 PR 코멘트 문구를 응답에 분리해 제시하고, 생성/수정은 작업지시자 승인 후에만 진행한다.
9. 작업지시자 승인 후 GitHub review/comment 등록 (필요 시)
   ```bash
   REVIEW_BODY=/tmp/pr_{N}_review_body.md
   # 승인된 공개 review/comment 본문을 "$REVIEW_BODY"에 작성한다.
   scripts/validate-github-body.sh "$REVIEW_BODY"

   # merge 권고를 실제 GitHub review로 남길 때
   gh pr review {N} --approve --body-file "$REVIEW_BODY"

   # 승인 없이 의견만 남길 때
   gh pr review {N} --comment --body-file "$REVIEW_BODY"

   # 수정 요청일 때
   gh pr review {N} --request-changes --body-file "$REVIEW_BODY"
   ```
   - review request가 남아 있는 PR은 단순 PR comment보다 `gh pr review --body-file`로 실제 review를 등록해야 알림과 검토 상태가 정리된다.
   - GitHub 공개 review/comment 본문은 inline `--body`로 넣지 않고 `--body-file`과 `scripts/validate-github-body.sh`를 사용한다.
   - 이 단계는 작업지시자가 공개 등록을 승인한 경우에만 수행한다.
10. 검토 완료 응답
   - triage 선택/적용 결과, 차단 이슈, 검증 결과, 최종 권고, 작업지시자 승인 요청을 요약한다.
   - merge 가능 권고일 때는 PR 완료 코멘트 초안을 작성하지 않는다.
   - 공개 코멘트 초안이 필요한 경우 review 문서 경로가 아니라 응답 본문에만 제공한다.
   - 작업지시자가 merge/cherry-pick/close를 완료하거나 완료 처리를 지시하면 `external-pr-complete` Skill을 호출하라고 안내한다.
11. 단일 또는 단계별 커밋 (외부 PR 검토는 내부 단계 형식 강제 아님)
   ```bash
   git commit -m "PR #{N} 검토: {요약}"
   ```

## 판단 기준

- PR base가 정책과 다르면 `devel` 또는 합의된 대상 브랜치로 재정렬을 요청한다. 변경이 작고 작업지시자가 승인한 경우에만 maintainer가 대상 브랜치에 직접 반영할 수 있다.
- reviewer request, assignee, label, milestone은 검토 시작 triage로 제안하고, 작업지시자 수락 전에는 본 리뷰로 넘어가지 않는다.
- 작업지시자가 triage 적용 없이 리뷰 진행을 명시하면 GitHub 상태를 바꾸지 않고 본 리뷰를 진행한다.
- label/milestone은 연결 이슈를 우선 따른다. 연결 이슈가 없거나 PR 범위가 이슈와 다르면 임의 지정하지 말고 확인한다.
- 작성자 PR을 그대로 merge할지 cherry-pick할지는 작업지시자 결정이다. merge/cherry-pick 후 공개 완료 코멘트, issue comment/close, `pr_{N}_report.md`, archives 이동은 `external-pr-complete` Skill에서 처리한다.
- 외부 PR 검토 중 발견한 문제는 `기여자가 이 PR에서 고쳐야 할 항목`과 `메인테이너가 별도 Issue/내부 타스크로 처리할 항목`으로 분리한다.
- 외부 PR이 내부 후속 수정을 요구하면 같은 PR에서 몰래 고치지 말고 별도 GitHub Issue 또는 내부 타스크로 분리한다. 기여자에게는 이 PR의 merge 조건인지, 별도 후속으로 추적할 항목인지 구체적으로 안내한다.
- PR 범위를 넘는 내부 보완은 기여자에게 요구하지 않는다. 다만 현재 PR의 안정성·호환성·검증을 막는 항목이면 차단 이유와 필요한 최소 수정 범위를 명확히 적는다.
- Finder/Quick Look/Thumbnail 변경은 Debug 빌드만으로 승인하지 않는다. 설치본 또는 표준 smoke helper 기준의 registration hygiene를 확인한다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존, `Alhangeul.xcodeproj` 직접 수정, floating core ref, 승인 없는 릴리스/서명/공증 변경은 차단 이슈로 기록한다.

## GitHub 참조 표기 규칙

- 리뷰 코멘트 초안과 내부 후속 Issue/타스크 안내 문구에서 GitHub PR/Issue 참조 토큰을 한글 조사와 붙여 쓰지 않는다.
- `#328으로`, `#132를`, `PR #328은`처럼 쓰지 말고 `#328 반영으로`, `#132 이슈를`, `PR #328 반영은`처럼 참조 토큰 뒤를 공백, 문장 부호, 또는 별도 명사로 분리한다.
- 여러 대상을 함께 적을 때는 `PR #328 및 Issue #132`처럼 각 참조 토큰을 독립적으로 둔다.

## 리뷰 코멘트 초안 원칙

- 초안은 최종 응답에만 작성한다. `mydocs/pr/pr_{N}_review.md`에는 초안 전문을 넣지 않는다.
- 첫 기여자라면 첫 문단에 환영과 감사를 둔다. "좋은 PR" 같은 포괄 칭찬보다 문제 재현, 작은 범위, 테스트 보강, 문서 정리, maintainer 피드백 반영처럼 확인 가능한 사실을 칭찬한다.
- 개선 안내는 "무엇을", "어디서", "어떤 검증으로" 고치면 되는지 적는다. 단순히 "수정 필요"라고 쓰지 않는다.
- 내부 후속 분리 항목은 기여자의 책임처럼 쓰지 않는다. PR 코멘트에는 "이 PR에서는 요청하지 않고 별도 Issue/내부 타스크로 추적"한다고 명확히 적고, 필요하면 내부 이슈/타스크 초안은 별도 섹션으로 제시한다.
- 닫기 또는 분리 재제출 권고는 기여를 부정하지 않는 문장으로 시작하고, 다시 제출 가능한 최소 범위와 base branch를 함께 안내한다.

### 수정 요청 코멘트 템플릿

~~~md
검토 감사합니다. {첫 기여자라면 환영 문장} {구체적으로 좋았던 점}

merge 판단 전에 아래 항목 보강이 필요합니다.

- {파일/동작}: {필요한 수정}. 확인 기준: `{검증 명령 또는 수동 확인}`
- {파일/동작}: {필요한 수정}. 확인 기준: `{검증 명령 또는 수동 확인}`

{PR 범위를 넘는 내부 후속 항목이 있으면: "{항목}은 이 PR에서 요청하지 않고 별도 Issue/내부 타스크로 추적하겠습니다."}
~~~

## 검증

- `mydocs/pr/pr_{N}_review.md` 표준 섹션 충족
- review 시작 triage의 초기 상태, 권장 값, 작업지시자 선택, 적용 결과가 기록됨
- review 문서에 PR/Issue 완료 코멘트 초안 전문이 포함되지 않음
- 기여자 피드백 판단에 잘 된 점, 요청 변경, 내부 후속 분리 항목, PR 범위 제외 항목이 구분됨
- 권고 결정이 명시됨 (merge / cherry-pick 통합 / 수정 요청 / 보류 / 닫기 중 하나)
- GitHub 공개 review/comment를 등록했다면 body file이 `scripts/validate-github-body.sh`를 통과함
- merge 가능 권고라면 후속 `external-pr-complete` 호출 필요성이 명시됨

## 절대 하지 말 것

- 내부 타스크 PR(`publish/task{N}`)에 본 SKILL 적용
- 외부 PR을 작업지시자 승인 없이 merge 또는 close
- 작업지시자 승인 없이 reviewer request, assignee, label, milestone 수정
- triage gate 수락 없이 본격 diff 검토, 검토 문서 작성, 검증 수행
- 작업지시자 승인 없이 GitHub review/comment 등록
- GitHub 공개 review/comment 본문을 inline `--body`로 등록
- merge 가능 판단만으로 PR/Issue 완료 코멘트 작성 또는 issue close
- 내부 후속 수정을 외부 PR 안에서 몰래 처리하거나 PR 범위를 넓혀 기여자에게 떠넘김
- 작업지시자 승인 없이 내부 후속 Issue/타스크 생성
- 작업지시자 승인, attribution 보존, 검토/보고서 기록 없이 외부 기여자 코드를 cherry-pick
- 내부 단계 절차(`_stage{N}.md`, `_report.md`) 형식을 외부 PR 문서에 강제 적용

## 호출 방법

- Codex: `$external-pr-review` 또는 `/skills` 메뉴
- Claude Code: `/external-pr-review`
