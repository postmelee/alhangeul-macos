# Task M040 #383 Stage 4 보고서

## 단계 목표

PR 리뷰 과정에서 확인된 문의/제보 섹션의 배치와 표현 방식을 조정한다.

- 문의/제보 섹션을 FAQ 아래로 이동
- FAQ와 같은 흰 배경 유지
- `#feedback` 이동 시 헤더를 제외한 viewport 높이를 채우도록 구성
- 이메일/GitHub Issue 경로를 카드형 CTA가 아닌 짧은 줄글 링크로 제공

## 변경 내용

### `docs/index.html`

- 기존 문의/제보 섹션을 FAQ 앞에서 제거하고 FAQ 섹션 뒤로 이동했다.
- `feedback-options`, `feedback-card` 기반의 2열 카드 구조를 제거했다.
- 제보 경로는 본문 안에서 `이메일`, `GitHub Issue` 링크로 짧게 노출했다.
- 이메일 `mailto:` 템플릿과 GitHub Issues URL은 기존 경로를 유지했다.

### `docs/styles.css`

- `.feedback-section` 배경을 흰색으로 고정했다.
- `.feedback-section`에 `min-height: calc(100svh - var(--header-height))`를 적용해 스크롤 이동 후 헤더 아래 viewport를 채우도록 했다.
- 카드/버튼/2열 grid 관련 스타일을 제거했다.
- 본문 링크와 주의 문구 중심의 줄글 레이아웃을 추가했다.
- 모바일 breakpoint에서 줄글과 주의 문구의 간격과 글자 크기만 조정하도록 정리했다.

## 검증 결과

| 항목 | 결과 | 근거 |
|------|------|------|
| FAQ 아래에 문의/제보 섹션 배치 | OK | DOM 순서에서 FAQ 섹션 뒤에 `#feedback` 확인 |
| 흰 배경 유지 | OK | Browser 검증에서 `rgb(255, 255, 255)` 확인 |
| viewport 높이 섹션 구성 | OK | 1440x1000에서 948px, 820x1180에서 1128px, 390x844에서 792px로 header 52px 제외 영역 채움 |
| 카드형 CTA 제거 | OK | `feedback-card`, `feedback-options`, `feedback-primary-link`, `feedback-secondary-link` selector 제거 확인 |
| 줄글 링크 유지 | OK | `이메일`, `GitHub Issue` 링크 href 확인 |
| 가로 overflow 없음 | OK | 1440x1000, 820x1180, 390x844 Browser 검증에서 `document.documentElement.scrollWidth <= window.innerWidth` 확인 |

## 실행한 검증

```bash
git diff --check
rg -n "feedback-card|feedback-options|feedback-primary-link|feedback-secondary-link" docs/index.html docs/styles.css
rg -n "feedback-copy|feedback-text-link|feedback-section|문의/제보|이메일|GitHub Issue" docs/index.html docs/styles.css
python3 -m http.server 8766 --bind 127.0.0.1 --directory docs
```

로컬 검증 URL:

```text
http://127.0.0.1:8766/#feedback
```

## 잔여 위험

- `mailto:`는 외부 메일 클라이언트를 여는 동작이므로 실제 메일 전송은 수행하지 않았다.
- 브라우저 시각 검증은 in-app Browser 기준으로 수행했다.
