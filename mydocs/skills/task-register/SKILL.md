---
name: task-register
description: |
  하이퍼-워터폴 작업에서 아직 GitHub Issue가 없는 신규 타스크를 등록한다.
  명시 호출 시에만 사용한다. 열린 milestone과 기존 label을 조회해 후보를 고르고,
  이슈 생성 전 작업지시자 확인을 받은 뒤 GitHub Issue 번호를 만든다.
  이슈 생성 후 브랜치/오늘할일/수행계획서는 task-start 절차로 넘긴다.
allow_implicit_invocation: false
---

# 하이퍼-워터폴 이슈 등록

## 트리거

- 명시 호출만: 작업지시자가 "이 작업 이슈 등록", "새 타스크 생성", "이슈부터 만들어줘"처럼 GitHub Issue 생성을 명시한 경우
- 작업지시자가 본 SKILL을 직접 호출한 경우

## 사전 조건

- 아직 이슈 번호가 없는 작업
- 작업 목적, 배경, 범위가 최소한 초안 수준으로 정리됨
- 현재 사용자 자격 증명으로 `gh` CLI 인증 완료
- 이슈 생성 전 제목, 본문, milestone, label 초안을 작업지시자에게 확인받을 수 있음

## 절차

1. 중복 이슈 확인
   ```bash
   gh issue list --repo postmelee/alhangeul-macos --state all \
     --search "{작업 키워드}" \
     --limit 20 \
     --json number,title,state,milestone,labels,url
   ```
   - 실질적으로 같은 열린 이슈가 있으면 새 이슈를 만들지 말고 기존 이슈 사용 여부를 확인한다.
   - 닫힌 이슈가 같은 주제를 다뤘다면 새 이슈 본문 참고 항목에 링크한다.
2. 열린 milestone 목록 확인
   ```bash
   gh api repos/postmelee/alhangeul-macos/milestones \
     --jq '.[] | {number,title,state,description,open_issues,closed_issues}'
   ```
3. 기존 label 목록 확인
   ```bash
   gh api repos/postmelee/alhangeul-macos/labels --paginate \
     --jq '.[] | {name,description,color}'
   ```
4. milestone 후보 선택
   - 운영 문서, Agent Skill, build/run 기반, core dependency 운영: `v0.1.0`
   - 렌더링 지원 범위 확대, 회귀 테스트 기반: `v0.2.0`
   - Quick Look preview, Finder thumbnail 안정화: `v0.3.0`
   - HostApp viewer 문서 열기, 페이지 탐색, zoom, 대용량 UX/성능: `v0.4.0`
   - 읽기 전용 beta 안정화, fallback, smoke test, 배포 전 검증: `v0.5.0`
   - 편집 command/bridge 책임 경계와 FFI 설계: `v0.6.0`
   - 텍스트 선택, 커서, 삽입, 삭제 최소 편집 루프: `v0.7.0`
   - 편집 후 재조판, 렌더링 갱신, undo/redo, dirty state: `v0.8.0`
   - 저장 경로, autosave, 손상 방지, 복구 정책: `v0.9.0`
   - 첫 정식 편집 기반 릴리스: `v1.0.0`
   - `alhangeul-macos 기준 완전 이관`은 독립 저장소 이관 잔여 작업이 명확할 때만 사용한다.
5. label 후보 선택
   - 문서나 Skill 변경: `documentation`
   - 기능, 구조, 운영 절차 개선: `enhancement`
   - 동작 오류, 회귀, 검증 실패 수정: `bug`
   - 정보 확인이 주목적이면 `question`
   - 기존 이슈와 중복이면 새 이슈 생성 대신 `duplicate` 처리 여부를 확인한다.
   - 애매하면 label을 비우거나 작업지시자에게 확인한다. 새 label은 만들지 않는다.
6. 이슈 초안 작성
   - 제목: 작업 단위가 드러나는 한 문장
   - 본문 권장 섹션:
     - 배경
     - 목표
     - 범위
     - 제외
     - 참고
   - milestone: 위 기준으로 고른 기존 milestone 1개
   - label: 기존 label 0개 이상
7. 이슈 생성 전 승인 요청
   - 작업지시자에게 제목, 본문, milestone, label 초안을 보여준다.
   - 작업지시자가 같은 스레드에서 생성 승인을 명시하기 전에는 `gh issue create`를 실행하지 않는다.
8. 승인 후 이슈 생성
   ```bash
   gh issue create --repo postmelee/alhangeul-macos \
     --title "{제목}" \
     --body "{본문}" \
     --milestone "{milestone}" \
     --label "{label}"
   ```
   - label이 여러 개면 `--label documentation --label enhancement`처럼 반복한다.
   - label을 쓰지 않기로 했으면 `--label` 옵션을 생략한다.
9. 생성 결과 확인
   ```bash
   gh issue view {N} --repo postmelee/alhangeul-macos \
     --json number,title,state,milestone,labels,url
   ```
10. 작업지시자에게 생성된 이슈 번호와 URL을 보고하고 `task-start` 진입 승인 요청

## 검증

- 생성된 이슈가 `OPEN` 상태여야 한다.
- milestone이 비어 있지 않아야 한다.
- label은 초안에서 승인된 기존 label만 붙어 있어야 한다.
- 생성 결과 보고에 issue number, URL, milestone, label이 포함되어야 한다.

## 절대 하지 말 것

- 작업지시자 승인 없이 `gh issue create` 실행
- 새 milestone 또는 새 label 생성
- 닫힌 milestone을 임의로 사용
- 이슈 생성 후 승인 없이 `task-start`까지 이어서 실행
- 이 Skill 안에서 브랜치 생성, 오늘할일 갱신, 수행계획서 작성

## 호출 방법

- Codex: `$task-register` 또는 `/skills` 메뉴에서 `task-register` 선택
- Claude Code: `/task-register`
