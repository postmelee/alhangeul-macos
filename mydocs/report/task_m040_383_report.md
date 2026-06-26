# Task M040 #383 최종 보고서

## 작업 요약

- GitHub Issue: [#383](https://github.com/postmelee/alhangeul-macos/issues/383)
- 마일스톤: M040 (`v0.4`)
- 브랜치: `local/task383`
- 기준 브랜치: `devel`
- 단계 수: 4단계
  - Stage 1: 랜딩페이지 문의/제보 구조 구현
  - Stage 2: 반응형 브라우저 검증
  - Stage 3: 최종 보고와 PR 준비
  - Stage 4: PR 리뷰 피드백 반영

비개발자나 GitHub 계정을 사용하지 않는 사용자가 알한글 사용 중 발견한 오류, 렌더링 차이, 설치 문제, 기능 제안을 공식 이메일로 쉽게 제보할 수 있게 GitHub Pages 랜딩페이지에 문의/제보 경로를 추가했다. PR 리뷰 피드백에 따라 문의/제보 섹션은 FAQ 아래의 흰 배경 전체 viewport 섹션으로 배치했고, 제보 경로는 카드형 CTA 대신 짧은 줄글 링크로 정리했다. GitHub Issues는 공개 재현/추적이 필요한 보조 경로로 유지했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `docs/index.html` | 헤더에 `문의/제보` anchor 추가, FAQ 아래 `#feedback` 섹션 추가, 이메일/GitHub Issue 줄글 링크 추가, FAQ 오류 제보 문구 갱신 |
| `docs/styles.css` | 문의/제보 섹션 흰 배경 full-viewport 레이아웃, 줄글 링크 스타일, 좁은 화면 헤더 겹침 방지 CSS 추가 |
| `mydocs/orders/20260626.md` | #383 오늘할일 항목 추가와 단계별 상태 갱신, 최종 완료 처리 |
| `mydocs/plans/task_m040_383.md` | 수행계획서 작성 |
| `mydocs/plans/task_m040_383_impl.md` | 구현계획서 작성 |
| `mydocs/working/task_m040_383_stage1.md` | Stage 1 구조 구현 결과와 정적 검증 기록 |
| `mydocs/working/task_m040_383_stage2.md` | Stage 2 브라우저 반응형 검증 결과 기록 |
| `mydocs/working/task_m040_383_stage4.md` | Stage 4 PR 리뷰 피드백 반영 결과 기록 |
| `mydocs/report/task_m040_383_report.md` | 최종 결과와 검증 결과 정리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 헤더 문의/제보 링크 | 없음 | `문의/제보` anchor 링크 추가 |
| 공식 이메일 제보 경로 | 랜딩페이지에 없음 | `이메일` 줄글 링크와 `mailto:` 템플릿 추가 |
| GitHub Issue 안내 | FAQ 중심 | `GitHub Issue` 줄글 링크와 FAQ에 유지 |
| 개인정보 주의 문구 | 없음 | 문의/제보 섹션에 문서 원본/민감정보 주의 추가 |
| 문의/제보 섹션 위치 | 없음 | FAQ 아래 흰 배경 full-viewport 섹션 |
| 반응형 검증 viewport | 없음 | `1440x1000`, `820x1180`, `390x844`, `360x844` 확인 |
| 변경 통계 | 기준 `devel` | 9 files changed, 770 insertions, 7 deletions |

주요 파일 line count:

```text
     283 docs/index.html
    1480 docs/styles.css
      98 mydocs/plans/task_m040_383.md
     154 mydocs/plans/task_m040_383_impl.md
      89 mydocs/working/task_m040_383_stage1.md
     150 mydocs/working/task_m040_383_stage2.md
      58 mydocs/working/task_m040_383_stage4.md
```

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 헤더 `문의/제보` 링크가 문의/제보 섹션으로 이동 | OK | Browser desktop/tablet/mobile에서 `#feedback` hash와 섹션 노출 확인 |
| 이메일 링크 제공 | OK | `이메일` 줄글 링크의 `mailto:alhangeul.feedback@gmail.com`과 encoded subject/body href 확인 |
| GitHub Issue 링크 유지 | OK | `GitHub Issue` 줄글 링크의 `https://github.com/postmelee/alhangeul-macos/issues` href 확인 |
| 문의/제보 섹션이 FAQ 아래에 위치 | OK | DOM 순서에서 FAQ 뒤 `#feedback` 확인 |
| 문의/제보 섹션이 흰 배경 full-viewport로 표시 | OK | Browser에서 배경 `rgb(255, 255, 255)`, 섹션 높이 1440x1000=948px, 820x1180=1128px, 390x844=792px 확인 |
| 카드형 CTA 제거 | OK | `feedback-card`, `feedback-options`, `feedback-primary-link`, `feedback-secondary-link` selector 미사용 확인 |
| FAQ 오류 제보 안내 갱신 | OK | FAQ에 이메일 제보와 GitHub Issue 역할 설명 반영 |
| 개인정보 주의 문구 제공 | OK | 문의/제보 섹션에 문서 원본/민감정보 주의 반영 |
| desktop/tablet/mobile layout 확인 | OK | `1440x1000`, `820x1180`, `390x844`에서 overflow/겹침 없음, 기존 `360x844` smoke 유지 |
| console health | OK | in-app Browser error/warn logs 없음 |
| 정적 diff 검증 | OK | `git diff --check` 통과 |

실행한 주요 명령:

```bash
git diff --check
rg -n "문의/제보|feedback|alhangeul.feedback@gmail.com|mailto:|GitHub Issue|개인정보" docs/index.html docs/styles.css
rg -n "feedback-card|feedback-options|feedback-primary-link|feedback-secondary-link" docs/index.html docs/styles.css
rg -n "feedback-copy|feedback-text-link|feedback-section|문의/제보|이메일|GitHub Issue" docs/index.html docs/styles.css
git log --oneline devel..local/task383
git diff --stat devel..local/task383
```

브라우저 검증은 `docs/`를 로컬 정적 서버로 제공한 뒤 in-app Browser에서 수행했다.

```bash
python3 -m http.server 8766 --bind 127.0.0.1 --directory docs
```

검증 URL:

```text
http://127.0.0.1:8766/#feedback
```

## 잔여 위험과 후속 작업

- `mailto:` 클릭은 외부 메일 앱을 열 수 있어 실제 전송 동작은 수행하지 않고 href 값으로 검증했다.
- Browser 검증은 in-app Browser 기준이다. Safari/Chrome 실제 사용자 브라우저별 세부 렌더 차이는 별도 확인하지 않았다.
- PR 리뷰 피드백으로 카드형 CTA를 제거했기 때문에 구현계획의 초기 selector 예시와 최종 selector는 다르다. 실제 검증은 최종 DOM/CSS 기준으로 수행했다.
- 향후 공식 도메인 또는 Google Workspace 전환 시 `alhangeul.feedback@gmail.com` 안내를 도메인 이메일로 바꾸는 후속 작업이 필요할 수 있다.

## 작업지시자 승인 요청

최종 보고서와 PR 게시 산출물 검토를 요청한다. PR merge 전 리뷰에서는 헤더 항목 추가에 따른 작은 화면 표시와 `mailto:` 본문 템플릿 문구를 중점 확인하면 된다.
