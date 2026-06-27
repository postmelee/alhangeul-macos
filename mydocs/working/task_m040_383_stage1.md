# Task M040 #383 Stage 1 완료보고서

## 단계 목적

랜딩페이지에서 비개발자도 공식 이메일로 문의와 제보를 보낼 수 있도록 헤더 anchor, 문의/제보 섹션, FAQ 안내를 구현했다. 이번 단계는 정적 HTML/CSS 구조 반영까지이며, desktop/mobile 브라우저 렌더링 확인과 보정은 Stage 2 범위로 남긴다.

## 산출물

| 파일 | 변경량 | 요약 |
|------|--------|------|
| `docs/index.html` | 292 lines, 일부 변경 | 헤더 `문의/제보` 링크, `#feedback` 섹션, 이메일/GitHub Issue CTA, FAQ 오류 제보 문구 추가 |
| `docs/styles.css` | 1545 lines, 일부 변경 | 문의/제보 섹션 레이아웃, CTA 스타일, 좁은 화면 헤더/섹션 대응 CSS 추가 |
| `mydocs/orders/20260626.md` | 7 lines, 1행 갱신 | #383 상태를 Stage 1 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m040_383_stage1.md` | 신규 | Stage 1 완료보고서 |

핵심 변경 위치:

```text
docs/index.html:44:        <a class="header-link" href="#feedback" aria-label="문의와 제보 안내로 이동">
docs/index.html:180:    <section id="feedback" class="feedback-section" aria-labelledby="feedback-title">
docs/index.html:191:              href="mailto:alhangeul.feedback@gmail.com?...subject...body..."
docs/index.html:199:            <a class="feedback-secondary-link" href="https://github.com/postmelee/alhangeul-macos/issues"
docs/index.html:260:          <p>GitHub을 사용하지 않는다면 <a href="mailto:alhangeul.feedback@gmail.com">alhangeul.feedback@gmail.com</a>으로
docs/styles.css:621:.feedback-section {
docs/styles.css:1321:  .feedback-options {
docs/styles.css:1524:@media (max-width: 380px) {
```

## 본문 변경 정도 / 본문 무손실 여부

- 기존 hero, 앱 소개, 기능 소개, FAQ 구조는 유지했다.
- FAQ의 기존 오류 제보 문항은 이메일 제보 경로를 먼저 안내하도록 문구를 갱신했고, GitHub Issues와 upstream `rhwp` 제보 경로는 유지했다.
- 외부 커뮤니티 링크는 사용자-facing 랜딩페이지에 노출하지 않았다.
- `mailto:`의 `subject`와 `body`는 URL encoded query로 구성했고, HTML 속성 안의 query 구분자는 `&amp;`로 표기했다.

## 검증 결과

```bash
git diff --check
```

- 결과: 통과, 출력 없음.

```bash
rg -n "문의/제보|feedback|alhangeul.feedback@gmail.com|mailto:|GitHub Issues|개인정보" docs/index.html docs/styles.css
```

주요 출력:

```text
docs/index.html:44:        <a class="header-link" href="#feedback" aria-label="문의와 제보 안내로 이동">
docs/index.html:45:          문의/제보
docs/index.html:180:    <section id="feedback" class="feedback-section" aria-labelledby="feedback-title">
docs/index.html:183:          <h2 id="feedback-title">문의/제보</h2>
docs/index.html:189:            <p>앱 버전, macOS 버전, 증상, 가능하면 스크린샷을 함께 보내 주세요. 문서 원본에는 개인정보가 있을 수 있으니 필요한 부분만 공유해 주세요.</p>
docs/index.html:191:              href="mailto:alhangeul.feedback@gmail.com?subject=%5B%EC%95%8C%ED%95%9C%EA%B8%80%20%EB%AC%B8%EC%9D%98%2F%EC%A0%9C%EB%B3%B4%5D&amp;body=..."
docs/index.html:199:            <a class="feedback-secondary-link" href="https://github.com/postmelee/alhangeul-macos/issues"
docs/index.html:260:          <p>GitHub을 사용하지 않는다면 <a href="mailto:alhangeul.feedback@gmail.com">alhangeul.feedback@gmail.com</a>으로
docs/styles.css:621:.feedback-section {
docs/styles.css:639:.feedback-options {
docs/styles.css:678:.feedback-primary-link,
docs/styles.css:679:.feedback-secondary-link {
```

```bash
wc -l docs/index.html docs/styles.css
```

결과:

```text
     292 docs/index.html
    1545 docs/styles.css
    1837 total
```

## 잔여 위험

- Stage 1에서는 브라우저 렌더링 확인을 수행하지 않았다. 실제 desktop/tablet/mobile viewport에서 헤더 항목, CTA 버튼, anchor scroll 위치가 자연스러운지는 Stage 2에서 확인해야 한다.
- `mailto:`는 사용자의 기본 메일 앱 설정에 의존한다. 웹메일 사용자에게는 섹션 안의 직접 이메일 주소 표시가 fallback 역할을 한다.
- 매우 좁은 화면에서 헤더 항목이 늘어난 영향은 CSS로 1차 완화했지만, 실제 화면 검증 전까지는 겹침 가능성이 남아 있다.

## 다음 단계 영향

Stage 2에서는 Browser 또는 Playwright 기반으로 `docs/index.html`을 열어 desktop/tablet/mobile viewport를 확인한다. 특히 `문의/제보` anchor 클릭, 이메일 CTA의 href, 두 카드의 줄바꿈, 380px 이하 헤더 표시를 검증하고 필요한 CSS 보정을 수행한다.

## 승인 요청

Stage 1 산출물 검토와 Stage 2 `문의 제보 섹션 반응형 검증` 단계 진입 승인을 요청한다. 승인 전에는 브라우저 검증 결과에 따른 추가 HTML/CSS 보정을 시작하지 않는다.
