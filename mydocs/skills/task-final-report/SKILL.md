---
name: task-final-report
description: |
  하이퍼-워터폴 타스크의 최종 보고와 PR 게시 절차를 적용한다. 명시 호출 시에만 사용한다.
  최종 결과 보고서(`_report.md`) 작성, 오늘할일 완료 처리, 최종 커밋,
  publish/task{N} 원격 push, 통합 브랜치 대상 Open PR 생성을 수행한다.
  모든 단계 완료 후 PR 직전에만 호출.
allow_implicit_invocation: false
---

# 하이퍼-워터폴 최종 보고와 PR 게시

## 트리거

- 명시 호출만: 작업지시자가 "최종 보고서 작성", "PR 준비"를 명시 지시한 경우
- 본 SKILL을 직접 호출한 경우

## 사전 조건

- 구현 계획서의 모든 단계 종료, 각 단계 보고서 커밋 완료
- 통합 검증(전체 수용 기준) 통과 확인
- `local/task{N}`에 commit 안 된 변경 없음 또는 본 절차에서 함께 커밋할 것만 남아 있음

## 절차

1. 통합 검증: 구현 계획서의 "수용 기준" 또는 마지막 단계 "검증" 섹션 명령 실행
2. 최종 보고서 작성: `mydocs/report/task_m{milestone}_{N}_report.md`
   - 표준 섹션:
     - 작업 요약 (이슈 링크, 마일스톤, 단계 수)
     - 변경 파일 목록과 영향 범위
       - 반드시 Markdown table로 작성한다.
       - 기본 컬럼은 `파일 | 내용`으로 한다.
       - 단순 파일 목록만 나열하지 않는다.
     - 변경 전·후 정량 비교 (라인 수, 토큰, 검증 통과 등 적용 시)
     - 검증 결과 (수용 기준별 OK/MISS)
     - 잔여 위험과 후속 작업
     - 작업지시자 승인 요청
3. 오늘할일 갱신: `mydocs/orders/{yyyymmdd}.md`의 #{N} 행
   - 상태 `완료`로 변경, 비고에 `완료: HH:mm` 기록
4. 변경 점검
   ```bash
   git status --short
   git diff --check
   BASE_BRANCH=devel-webview # native viewer renderer 작업이면 devel
   git log --oneline "$BASE_BRANCH"..local/task{N}
   ```
5. 최종 커밋 (Stage 마지막 + 최종 보고서를 묶을 수도, 보고서만 단일 커밋도 가능)
   ```bash
   git add mydocs/report/task_m{milestone}_{N}_report.md mydocs/orders/{yyyymmdd}.md
   git commit -m "Task #{N} Stage {마지막} + 최종 보고서: {요약}"
   # 또는
   git commit -m "Task #{N}: 최종 보고서 작성과 오늘할일 완료 처리"
   ```
6. 원격 게시 브랜치 push
   ```bash
   git push origin local/task{N}:publish/task{N}
   ```
7. 통합 브랜치 대상 Open PR 생성
   ```bash
   BASE_BRANCH=devel-webview # native viewer renderer 작업이면 devel
   HEAD_SHA=$(git rev-parse HEAD)
   PR_BODY=/tmp/task{N}-pr-body.md
   # .github/pull_request_template.md를 출발점으로 삼아 최종 보고서와 단계 보고서 기준으로 "$PR_BODY" 작성
   gh pr create --base "$BASE_BRANCH" --head publish/task{N} \
     --title "Task #{N}: {제목}" \
     --body-file "$PR_BODY"
   ```
   - PR 본문은 최대 4개 요약 bullet, Stage별 1줄 요약, 핵심 리뷰 포인트, 검증 결과, 관련 이슈, 후속 이슈 제안, 남은 리스크를 포함
   - Stage 제목은 단계 보고서 URL로, 옆의 짧은 commit SHA는 commit URL로 링크
   - 작업 문서는 `HEAD_SHA` 기준 `https://github.com/postmelee/alhangeul-macos/blob/{HEAD_SHA}/mydocs/...` URL로 연결
   - 링크 표시는 raw URL이 아니라 `[파일명](URL)` 형식으로 작성
   - 상대 링크(`mydocs/...`)나 `blob/publish/task{N}/...` 링크는 사용하지 않음
   - 시각적 변경사항이 있을 때만 Before/After 표를 유지
   - 관련 이슈에는 대상 타스크가 아니라 선행, 후속, Epic, upstream, 참고 PR/issue만 작성
8. 작업지시자에게 PR URL 전달과 리뷰·merge 승인 요청

## 검증

- 모든 단계 보고서 + 최종 보고서 존재
- `git status --short` 결과 빈 출력
- `gh pr view` 결과에 draft가 아닌 PR이 정확한 base/head로 등록
- PR 본문 `변경 내역`의 Stage별 요약이 단계 보고서 링크와 짧은 commit SHA 링크를 함께 사용
- PR 본문 `변경 내역`의 작업 문서 항목이 commit SHA 고정 URL과 `[파일명](URL)` 표시 형식을 사용
- PR 본문 작업 문서 항목에 raw GitHub blob URL, 상대 링크, `blob/publish/task{N}` 링크 없음
- PR 본문에 `핵심 리뷰 포인트`와 `후속 이슈 제안`을 필요한 경우 유지하고, 해당 없으면 삭제하거나 `없음`으로 정리
- PR 본문에 실행하지 않은 검증 체크리스트가 남아 있지 않음
- 오늘할일 #{N} 상태 `완료` + `완료: HH:mm`

## 절대 하지 말 것

- 통합 검증 실패 상태에서 PR 생성
- `local/task{N}` 브랜치를 원격에 직접 push (반드시 `publish/task{N}`로 명명)
- squash merge 강제 옵션 사용 (단계 커밋 의미 보존)
- 작업지시자 명시 지시 없이 Draft PR로 생성하거나 self-merge

## 호출 방법

- Codex: `$task-final-report` 또는 `/skills` 메뉴
- Claude Code: `/task-final-report`
