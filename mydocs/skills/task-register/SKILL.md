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
   - 조회 결과의 `title`, `state`, `description`을 기준으로 판단한다.
   - 기억하고 있는 과거 milestone 목록이나 버전 매핑을 기준으로 단정하지 않는다.
3. 기존 label 목록 확인
   ```bash
   gh api repos/postmelee/alhangeul-macos/labels --paginate \
     --jq '.[] | {name,description,color}'
   ```
   - 조회 결과의 `name`, `description`을 기준으로 판단한다.
   - 기억하고 있는 과거 label 목록을 기준으로 단정하지 않는다.
4. milestone 후보 선택
   - 열린 milestone만 후보로 사용한다.
   - 작업 목적, 범위, 대상 컴포넌트, 릴리스 단계가 조회된 milestone의 `title`/`description`과 가장 잘 맞는지 비교한다.
   - 후보가 명확하면 milestone 제목과 선택 이유를 기록한다.
   - 후보가 2개 이상이면 2~3개 후보와 각각의 이유를 작업지시자에게 제시하고 확인받는다.
   - 적합한 열린 milestone이 없거나 설명이 부족하면 임의 선택하지 말고 작업지시자에게 확인한다.
5. label 후보 선택
   - 조회된 기존 label만 후보로 사용한다.
   - 작업 성격이 label의 `name`/`description`과 명확히 대응할 때만 선택한다.
   - label은 기본적으로 `type label 1개 + area label 1~2개 + kind/status label 0~1개`로 제한한다.
   - type label은 `bug`, `documentation`, `enhancement`, `duplicate`, `question` 등 작업 성격을 나타내는 label 중 1개를 우선 고른다.
   - `area:*` label은 영향을 받는 모든 영역이 아니라 주 작업 소유 영역 기준으로 고른다.
   - `kind:*` label은 `kind:architecture`, `kind:automation`, `kind:regression`, `kind:verification`, `kind:follow-up`처럼 처리 방식이나 맥락을 실제로 구분할 때만 붙인다.
   - 일반 이슈는 2~4개 label을 권장한다.
   - 5개 이상 label이 필요하면 이슈 초안에 예외 사유를 적고 작업지시자 확인을 받는다.
   - 후보가 명확하면 label 이름과 선택 이유를 기록한다.
   - 적합한 label이 없거나 애매하면 label 없이 생성하거나 작업지시자에게 확인한다.
   - 새 label은 만들지 않는다.
6. 이슈 초안 작성
   - 제목: 작업 단위가 드러나는 한 문장
   - 본문 권장 섹션:
     - 배경
     - 목표
     - 범위
     - 제외
     - 참고
   - milestone: live 조회 결과에서 고른 열린 milestone 1개와 선택 이유
   - label: live 조회 결과에서 고른 기존 label 0개 이상과 선택 이유
   - label 선택 이유는 type/area/kind 기준으로 나누어 적고, 5개 이상이면 예외 사유를 별도로 적는다.
7. 이슈 생성 전 승인 요청
   - 작업지시자에게 제목, 본문, milestone, label 초안과 선택 이유를 보여준다.
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
- milestone이 비어 있지 않고 live 조회 결과에 있던 열린 milestone이어야 한다.
- label은 초안에서 승인된 기존 label만 붙어 있어야 한다.
- 일반 이슈 label은 2~4개 권장 범위인지 확인한다.
- 5개 이상 label이면 승인된 예외 사유가 생성 결과 보고에 포함되어야 한다.
- `area:*` label은 주 작업 소유 영역 기준으로 선택되어야 한다.
- 생성 결과 보고에 issue number, URL, milestone, label, 선택 이유가 포함되어야 한다.

## 절대 하지 말 것

- 작업지시자 승인 없이 `gh issue create` 실행
- 새 milestone 또는 새 label 생성
- 닫힌 milestone을 임의로 사용
- 이슈 생성 후 승인 없이 `task-start`까지 이어서 실행
- 이 Skill 안에서 브랜치 생성, 오늘할일 갱신, 수행계획서 작성

## 호출 방법

- Codex: `$task-register` 또는 `/skills` 메뉴에서 `task-register` 선택
- Claude Code: `/task-register`
