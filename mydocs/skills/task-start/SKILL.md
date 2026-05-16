---
name: task-start
description: |
  하이퍼-워터폴 타스크 시작 절차를 적용한다. 명시 호출 시에만 사용한다.
  GitHub 이슈 등록 확인, 통합 브랜치 최신화, local/task{N} 브랜치 생성,
  오늘할일 항목 추가, 수행계획서 템플릿 생성을 수행한다.
  새 코드/문서 변경을 시작하기 전 진행 단계 정렬 용도.
allow_implicit_invocation: false
---

# 하이퍼-워터폴 타스크 시작

## 트리거

- 명시 호출만: 작업지시자가 "이슈 #N 시작", "타스크 #N 진행"처럼 명시 지시한 경우
- 작업지시자가 본 SKILL을 직접 호출한 경우

## 사전 조건

- 작업지시자 승인된 이슈 번호와 마일스톤이 존재
- 작업 대상 저장소 working tree clean (또는 분리된 worktree 사용 결정)
- 현재 사용자 자격 증명으로 `gh` CLI 인증 완료

## 절차

1. 이슈 정보 확인
   ```bash
   gh issue view {N} --json number,title,milestone,state,body
   ```
2. 기준 통합 브랜치 결정 후 최신화
   - 첫 공개 배포, WKWebView-backed viewer/editor, Finder/Quick Look, PDF/공유/저장, Spotlight/mdimporter, 변환, 배포, 문서는 `devel`
   - Swift native viewer/editor 작업은 `native-viewer-editor`
   - 작업지시자가 명시한 base가 있으면 그 지시를 우선
   ```bash
   BASE_BRANCH=devel # Swift native viewer/editor 작업이면 native-viewer-editor
   git fetch origin
   git checkout "$BASE_BRANCH"
   git pull --ff-only
   ```
3. 작업 브랜치 생성. 다른 작업자가 메인 worktree를 점유 중이면 분리 worktree 사용:
   ```bash
   # 단일 worktree
   git checkout -b local/task{N}

   # 분리 worktree (권장: 다른 에이전트 비간섭)
   git worktree add ../{repo}-task{N} -b local/task{N} origin/"$BASE_BRANCH"
   ```
4. 오늘할일 갱신: `mydocs/orders/{yyyymmdd}.md`에 행 추가
   - 형식: `| #{N} | {타스크 제목} | 진행중 | M{milestone}, 수행계획서 작성 후 승인 대기 |`
   - 적절한 마일스톤 섹션에 배치 (운영 작업은 "공통 — 운영 작업")
5. 수행계획서 템플릿 생성: `mydocs/plans/task_m{milestone}_{N}.md`
   - 섹션: 목적 / 배경 / 범위(포함·제외) / 설계 방향 / 예상 변경 파일 / 잠정 단계(3~6단계) / 검증 계획 / 리스크 / 승인 요청 사항
6. 변경 검증
   ```bash
   git status --short
   git diff --check
   ```
7. 단일 커밋
   ```bash
   git add mydocs/plans/task_m{milestone}_{N}.md mydocs/orders/{yyyymmdd}.md
   git commit -m "Task #{N}: 수행 계획서 작성과 오늘할일 갱신"
   ```
8. 작업지시자에게 수행계획서 승인 요청

## 검증

- `git log --oneline -1`이 `Task #{N}: 수행 계획서 작성과 오늘할일 갱신`을 보여야 한다
- `mydocs/orders/{yyyymmdd}.md`에 #{N} 행 존재
- `mydocs/plans/task_m{milestone}_{N}.md` 9개 표준 섹션 모두 채워짐

## 절대 하지 말 것

- 수행계획서 승인 전 구현 계획서 작성
- 수행계획서 승인 전 코드/매뉴얼 변경
- 다른 작업자의 미커밋 변경 또는 다른 task 브랜치 working tree 건드리기

## 호출 방법

- Codex: `$task-start` 또는 `/skills` 메뉴에서 `task-start` 선택
- Claude Code: `/task-start`
