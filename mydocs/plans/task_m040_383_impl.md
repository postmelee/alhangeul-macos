# Task #383 구현 계획서

본 문서는 [`task_m040_383.md`](task_m040_383.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- Worktree: `/Users/melee/Documents/projects/rhwp-mac`
- Branch: `local/task383`
- 기준 브랜치: `devel`
- 기준 이슈: [#383](https://github.com/postmelee/alhangeul-macos/issues/383)
- 마일스톤: M040 (`v0.4`)
- 범위: GitHub Pages 랜딩페이지에 문의/제보 섹션과 이메일 제보 경로 추가

## 구현 원칙

- 헤더의 `문의/제보`는 `mailto:`를 즉시 실행하지 않고 페이지 내 문의/제보 섹션으로 이동한다.
- 이메일 제보를 primary action으로 두되, GitHub Issues 경로를 유지해 공개 재현/추적이 필요한 사용자를 지원한다.
- 공식 이메일은 `alhangeul.feedback@gmail.com`으로 고정한다.
- 문서 원본 첨부를 기본 요구하지 않고, 개인정보가 포함될 수 있다는 주의와 스크린샷/재현 설명 중심 제보 안내를 포함한다.
- 서버 기반 문의 폼, 자동응답, GitHub Issue 자동화, GitHub Pages 배포 workflow 변경은 하지 않는다.
- 기존 랜딩페이지의 시각 톤과 CTA 위계를 유지하고, 다운로드 버튼이 primary navigation CTA로 남게 한다.

## Stage 1 — 랜딩페이지 문의/제보 구조 구현

### 목표

- 헤더에서 문의/제보 섹션으로 이동할 수 있게 한다.
- 랜딩페이지 본문에 이메일 제보와 GitHub Issue 제보 선택지를 제공한다.
- FAQ의 오류 제보 문항을 새 제보 경로와 일관되게 갱신한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `docs/index.html` | 헤더 `문의/제보` 링크, 문의/제보 섹션, FAQ 문구 추가/수정 | 핵심 HTML 변경 |
| `docs/styles.css` | 문의/제보 섹션과 CTA 스타일 추가, 헤더 반응형 여백 보정 | 필요한 범위만 수정 |
| `mydocs/working/task_m040_383_stage1.md` | Stage 1 완료보고서 작성 | 변경 내용과 검증 결과 기록 |

### 구현 기준

1. 헤더 링크는 `href="#feedback"`처럼 페이지 내 anchor를 사용한다.
2. 문의/제보 섹션은 FAQ와 가까운 지원 문맥에 배치한다.
3. 이메일 CTA는 `mailto:alhangeul.feedback@gmail.com`에 제목과 본문 템플릿을 포함한다.
4. 메일 본문 템플릿은 앱 버전, macOS 버전, 문서 형식, 증상, 재현 방법, 첨부/스크린샷 여부를 입력할 수 있게 한다.
5. GitHub Issues 링크는 `https://github.com/postmelee/alhangeul-macos/issues`를 유지한다.
6. 개인정보 주의 문구는 이메일 섹션과 FAQ 중 최소 한 곳에 명확히 포함한다.
7. 외부 커뮤니티 링크는 사용자-facing 랜딩페이지에 노출하지 않는다.

### 단계 검증

```bash
git diff --check
rg -n "문의/제보|feedback|alhangeul.feedback@gmail.com|mailto:|GitHub Issues|개인정보" docs/index.html docs/styles.css
```

### 단계 완료 기준

- 헤더에 `문의/제보` 링크가 추가되어 문의/제보 섹션으로 이동한다.
- 문의/제보 섹션에 이메일 primary CTA와 GitHub Issue secondary CTA가 모두 있다.
- FAQ의 오류 제보 안내가 이메일과 GitHub Issue 역할을 함께 설명한다.
- HTML/CSS diff에 trailing whitespace나 conflict marker가 없다.

### 커밋 메시지

```text
Task #383 Stage 1: 랜딩페이지 문의 제보 경로 구현
```

## Stage 2 — 반응형 브라우저 확인과 보정

### 목표

- desktop과 mobile에서 헤더, 문의/제보 섹션, CTA 버튼이 겹치지 않고 자연스럽게 보이는지 확인한다.
- `mailto:` 링크와 anchor 이동이 의도대로 동작하는지 확인한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `docs/index.html` | Stage 1 확인 결과에 따른 문구/구조 보정 | 필요 시 |
| `docs/styles.css` | mobile header, CTA wrapping, section spacing 보정 | 필요 시 |
| `mydocs/working/task_m040_383_stage2.md` | Stage 2 완료보고서 작성 | viewport 확인과 보정 결과 기록 |

### 확인 기준

1. desktop viewport에서 브랜드, `업데이트`, `문의/제보`, `GitHub`, `다운로드`가 한 줄에서 겹치지 않는다.
2. mobile viewport에서 헤더 링크와 다운로드 버튼이 잘리거나 서로 겹치지 않는다.
3. 문의/제보 섹션의 제목, 설명, 두 CTA, 주의 문구가 읽기 쉬운 순서로 배치된다.
4. `문의/제보` anchor 이동 시 sticky header 때문에 섹션 제목이 과도하게 가려지지 않는다.
5. 이메일 버튼의 URL encoding이 subject/body를 깨뜨리지 않는다.

### 단계 검증

```bash
git diff --check
rg -n "feedback-section|feedback-actions|feedback-card|scroll-margin|mailto:" docs/index.html docs/styles.css
```

가능하면 로컬 정적 페이지를 브라우저에서 열어 다음 viewport를 확인한다.

```text
desktop: 1440x1000
tablet: 820x1180
mobile: 390x844
```

### 단계 완료 기준

- desktop/tablet/mobile에서 헤더와 문의/제보 섹션이 겹치지 않는다.
- 이메일 CTA와 GitHub Issue CTA가 시각적으로 구분된다.
- anchor 이동과 `mailto:` 링크가 기대 URL을 가진다.
- 확인 결과와 남은 한계가 stage 보고서에 기록된다.

### 커밋 메시지

```text
Task #383 Stage 2: 문의 제보 섹션 반응형 검증
```

## Stage 3 — 최종 보고와 PR 준비

### 목표

- 변경 내용과 검증 결과를 최종 보고서에 정리한다.
- 오늘할일 상태를 완료로 갱신하고 PR 게시 전 산출물을 정리한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/report/task_m040_383_report.md` | 최종 결과보고서 작성 | 최종 산출물과 검증 결과 |
| `mydocs/orders/20260626.md` | 작업 상태 완료 처리 | 완료 시간 기록 |
| `docs/index.html` | 필요 시 최종 보정 | Stage 2 피드백 한정 |
| `docs/styles.css` | 필요 시 최종 보정 | Stage 2 피드백 한정 |

### 최종 검증

```bash
git status --short --branch
git diff --check
rg -n "문의/제보|feedback|alhangeul.feedback@gmail.com|mailto:|GitHub Issues|개인정보" docs/index.html docs/styles.css mydocs/report/task_m040_383_report.md
```

브라우저 확인이 가능하면 Stage 2와 같은 viewport에서 최종 화면을 다시 확인한다.

### 커밋 메시지

```text
Task #383 Stage 3 + 최종 보고서: 문의 제보 경로 추가 완료
```

## 승인 요청 사항

이 구현계획서 승인 후 Stage 1 랜딩페이지 문의/제보 구조 구현을 시작한다. 승인 전에는 `docs/index.html`과 `docs/styles.css`를 수정하지 않는다.
