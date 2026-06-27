# Task M040 #383 Stage 4 보고서

## 단계 목표

PR 리뷰와 시각 피드백 과정에서 확인된 문의/제보 경로의 배치, 정보 위계, CTA 표현을 조정한다.

- 문의/제보를 홈 화면 inline 섹션에서 `/feedback/` 별도 페이지로 분리
- 업데이트 페이지와 유사한 헤더/푸터/콘텐츠 폭을 적용
- 이메일과 GitHub Issue 경로를 카드형 UI로 정리
- 이메일 복사 버튼, `mailto:` CTA, GitHub 공식 mark 포함 Issue CTA 제공
- 민감한 정보 안내를 카드 위의 안내 박스로 분리

## 변경 내용

### `docs/feedback/index.html`

- `문의 / 제보` 별도 페이지를 추가했다.
- 상단 안내 문구는 "사용 중 불편한 점, 렌더링 차이, 설치 문제를 편하게 알려 주세요."로 정리했다.
- 민감한 정보 안내는 카드 위 안내 박스로 분리하고, 주민등록번호/연락처/내부 문서 원본 공유 주의 문구를 제공했다.
- 이메일 카드에는 제보 설명, 이메일 주소, 복사 버튼, `이메일 보내기` CTA를 배치했다.
- GitHub Issue 카드에는 공개 재현/개발 논의가 필요한 버그의 보조 경로 설명과 GitHub mark 포함 CTA를 배치했다.

### `docs/index.html`

- 헤더 `문의/제보` 링크를 `/feedback/` 페이지로 연결했다.
- FAQ의 "오류는 어디에 제보하면 되나요?" 답변을 GitHub Issue, 이메일, rhwp upstream 순서로 문단 분리했다.

### `docs/updates/index.html`

- 업데이트 페이지 헤더에도 `문의/제보` 링크를 추가했다.

### `docs/styles.css`

- feedback page hero, notice, card grid, contact card, CTA, copy button 상태 스타일을 추가했다.
- desktop에서는 이메일/GitHub Issue 카드를 2열로, 모바일에서는 1열 stack으로 배치했다.
- `body`/`main` flex layout을 적용해 짧은 페이지에서 footer 아래 공백이 생기는 회귀를 수정했다.
- 기존 sticky header 동작을 유지했다.

### `docs/script.js`

- 이메일 주소 복사 버튼 동작을 추가했다.
- `navigator.clipboard` 사용이 불가능한 환경에서는 textarea fallback을 사용하고, 실패 시 이메일 주소를 선택해 사용자가 직접 복사할 수 있게 했다.
- 복사 완료/주소 선택 상태 label과 class reset을 처리했다.

## 검증 결과

| 항목 | 결과 | 근거 |
|------|------|------|
| `/feedback/` 별도 페이지 제공 | OK | 로컬 서버에서 `/feedback/` 200 확인 |
| 이메일/GitHub Issue 카드 배치 | OK | desktop 2열, mobile 1열 stack 확인 |
| 민감한 정보 안내 위치 | OK | 카드 위 안내 박스 노출 확인 |
| 이메일 복사 버튼 | OK | 버튼 label과 복사 상태 class 동작 확인 |
| GitHub Issue CTA | OK | GitHub mark와 Issues URL 확인 |
| FAQ 오류 제보 답변 순서 | OK | GitHub Issue -> 이메일 -> rhwp upstream 순서로 문단 분리 |
| sticky header 유지 | OK | CSS에서 sticky header 유지 확인 |
| footer 하단 공백 수정 | OK | `body > main` flex layout 적용 후 footer가 viewport 하단에 붙음 |
| 가로 overflow 없음 | OK | desktop/mobile viewport에서 `scrollWidth <= innerWidth` 확인 |

## 실행한 검증

```bash
git diff --check
curl -I http://127.0.0.1:8767/feedback/
rg -n "문의 / 제보|feedback-privacy-note|feedback-card-grid|feedback-copy-button|GitHub Issue" docs/feedback/index.html docs/styles.css docs/script.js
python3 -m http.server 8767 --bind 127.0.0.1 --directory docs
```

로컬 검증 URL:

```text
http://127.0.0.1:8767/feedback/
```

## 잔여 위험

- `mailto:`는 외부 메일 클라이언트를 여는 동작이므로 실제 메일 전송은 수행하지 않았다.
- 브라우저 시각 검증은 로컬 브라우저 기준으로 수행했다.
