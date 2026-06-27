# Task M040 #383 Stage 2 완료보고서

## 단계 목적

Stage 1에서 추가한 랜딩페이지 문의/제보 섹션을 실제 브라우저에서 확인했다. desktop, tablet, mobile, narrow mobile viewport에서 헤더 겹침, anchor 이동, CTA 노출, horizontal overflow, console 상태를 검증했고 추가 HTML/CSS 보정은 필요하지 않다고 판단했다.

## 산출물

| 파일 | 변경량 | 요약 |
|------|--------|------|
| `mydocs/orders/20260626.md` | 7 lines, 1행 갱신 | #383 상태를 Stage 2 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m040_383_stage2.md` | 신규 | Stage 2 브라우저 검증 결과 보고 |

검증 대상 소스:

| 파일 | 요약 |
|------|------|
| `docs/index.html` | Stage 1의 헤더 anchor, 문의/제보 섹션, FAQ 이메일 안내 |
| `docs/styles.css` | Stage 1의 섹션 레이아웃과 반응형 헤더/CTA CSS |

## 본문 변경 정도 / 본문 무손실 여부

- Stage 2에서는 `docs/index.html`과 `docs/styles.css`를 추가 수정하지 않았다.
- 완료보고서와 오늘할일 상태만 갱신했다.
- 브라우저 확인은 in-app Browser로 수행했다. `file://` 직접 로드는 Browser 보안 정책에 막혀, `docs/`를 `http://127.0.0.1:8765/` 로컬 정적 서버로 제공해 검증했다.

## 검증 결과

### 기본 페이지 확인

대상 URL:

```text
http://127.0.0.1:8765/
```

확인 결과:

```json
{
  "url": "http://127.0.0.1:8765/",
  "title": "알한글 - Mac용 HWP/HWPX 뷰어",
  "snapshotHasContent": true,
  "logs": []
}
```

- 페이지 제목 정상.
- DOM snapshot에 `문의/제보`, `이메일로 제보하기`가 포함되어 빈 화면이 아님.
- framework error overlay나 console error/warn 없음.

### desktop anchor interaction

Viewport: `1440x1000`

헤더 `문의/제보` 클릭 후 결과:

```json
{
  "hash": "#feedback",
  "feedbackTop": 76,
  "titleTop": 162,
  "titleVisibleBelowHeader": true,
  "emailVisible": true,
  "issueVisible": true,
  "emailText": "이메일 보내기",
  "issueText": "Issue 작성하기"
}
```

- `문의/제보` anchor 클릭 시 `#feedback` 섹션으로 이동한다.
- 섹션 제목과 이메일/GitHub CTA가 viewport 안에 보인다.
- 이메일 CTA href는 `mailto:alhangeul.feedback@gmail.com`과 encoded subject/body를 포함한다.
- GitHub CTA href는 `https://github.com/postmelee/alhangeul-macos/issues`다.

### responsive section 확인

Viewport별 결과:

| viewport | no horizontal overflow | anchor hash | title below header | CTA visible | console |
|----------|-------------------------|-------------|--------------------|-------------|---------|
| `820x1180` | pass | `#feedback` | pass | pass | error/warn 없음 |
| `390x844` | pass | `#feedback` | pass | pass | error/warn 없음 |

Mobile `390x844` 결과 일부:

```json
{
  "viewport": {"width": 375, "height": 844},
  "scrollWidth": 375,
  "noHorizontalOverflow": true,
  "titleTop": 148,
  "titleVisibleBelowHeader": true,
  "ctasVisible": true,
  "email": {"x": 35, "width": 305, "right": 340},
  "issue": {"x": 35, "width": 305, "right": 340}
}
```

- tablet에서는 카드가 1열로 전환된다.
- mobile에서는 두 CTA가 full-width로 보이고 좌우 clipping이 없다.
- 안내 문구와 이메일 주소가 viewport 안에서 줄바꿈된다.

### top header 확인

페이지 상단에서 헤더 겹침을 별도로 확인했다.

| viewport | header fits | brand text | horizontal overflow | 링크 |
|----------|-------------|------------|---------------------|------|
| `820x1180` | pass | 표시 | pass | `업데이트`, `문의/제보`, `GitHub`, `다운로드` |
| `390x844` | pass | 표시 | pass | `업데이트`, `문의/제보`, `GitHub`, `다운로드` |
| `360x844` | pass | 숨김 | pass | `업데이트`, `문의/제보`, `GitHub`, `다운로드` |

`360x844`에서는 `@media (max-width: 380px)` 규칙에 따라 브랜드 텍스트가 숨겨지고 로고만 남아 헤더 링크와 겹치지 않았다.

### 계획서 명령

```bash
git diff --check
```

- 결과: 통과, 출력 없음.

```bash
rg -n "feedback-section|feedback-actions|feedback-card|scroll-margin|mailto:" docs/index.html docs/styles.css
```

주요 출력:

```text
docs/styles.css:621:.feedback-section {
docs/styles.css:646:.feedback-card {
docs/index.html:191:              href="mailto:alhangeul.feedback@gmail.com?subject=..."
```

구현계획서의 예시 selector 중 `feedback-actions`는 최종 구현에서 `feedback-options`와 `feedback-primary-link`/`feedback-secondary-link`로 대체되었다. 기능 검증에는 영향이 없고, Stage 2 브라우저 검증에서 실제 class와 CTA 노출을 확인했다.

## 잔여 위험

- in-app Browser 기준 검증이며 Safari/Chrome 실제 사용자 브라우저별 rendering 차이는 별도로 확인하지 않았다.
- `mailto:` 클릭 자체는 외부 메일 앱을 열 수 있어 실제 클릭하지 않고 href 값으로 검증했다.
- 아주 좁은 폭에서는 기존 `body { min-width: 320px; }` 정책의 영향을 받는다. 이번 task는 360px 이상 narrow mobile에서 겹침 없음을 확인했다.

## 다음 단계 영향

Stage 3에서는 최종 결과보고서를 작성하고 오늘할일을 완료 처리한다. Stage 2에서 소스 보정 필요성이 발견되지 않았으므로 Stage 3의 소스 변경은 예상하지 않는다.

## 승인 요청

Stage 2 산출물 검토와 Stage 3 `최종 보고와 PR 준비` 단계 진입 승인을 요청한다. 승인 전에는 최종 보고서 작성과 오늘할일 완료 처리를 시작하지 않는다.
