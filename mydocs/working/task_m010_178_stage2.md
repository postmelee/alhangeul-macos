# Issue #178 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 보강한 두 번째 섹션을 로컬 정적 서버와 Browser/IAB로 확인하고, 반응형 추가 보정 필요 여부를 판단했다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m010_178_stage2.md` | Stage 2 브라우저 검증 결과 보고서 |

이번 단계에서 `docs/` 소스 추가 변경은 없었다. Stage 1 변경 상태가 Browser 검증 기준을 통과해 별도 CSS 보정 없이 유지했다.

## 검증 환경

- 로컬 서버: `http://127.0.0.1:8080/`
- 서버 명령: `python3 -m http.server 8080 --directory docs`
- Browser 경로: Browser Use / IAB
- 확인 흐름: 페이지 로드 → hero 확인 → 두 번째 섹션 확인 → Feature/FAQ DOM smoke 확인
- 현재 서버는 작업지시자 시각검증을 위해 계속 실행 중이다.

## 검증 결과

### 추가 요청 반영: 첫 화면 MacBook 섹션과 같은 높이

작업지시자의 추가 요청에 따라 두 번째 섹션도 첫 진입 MacBook 목업 섹션과 같은 높이 모델을 사용하도록 보정했다.

- `.app-intro-section` 높이를 `calc(100svh - var(--header-height))`로 맞추고, 최소 높이는 첫 섹션과 같은 `var(--intro-min-height)`를 사용하게 했다.
- 큰 화면에서 한 viewport 안에 `알한글` 제목, 리드 문구, 철학 설명, 스크린샷, 기능 요약 4개가 모두 들어오도록 padding/gap을 줄였다.
- 스크린샷은 `fit-content` 컨테이너와 `max-height: min(58svh, 660px)`로 제어해, 넓은 화면에서는 크게 보이되 viewport 밖으로 밀리지 않게 했다.
- 960px 이하 화면에서는 기존처럼 `height: auto`와 `overflow: visible`로 되돌려 모바일 스크롤 흐름을 유지했다.

Browser/IAB 현재 viewport에서도 두 번째 섹션의 모든 주요 요소가 한 화면에 표시되는 것을 확인했다.

```json
{
  "introVisible": {
    "title": true,
    "lead": true,
    "principle": true,
    "shot": true,
    "capabilities": true
  },
  "logs": []
}
```

### 페이지 로드와 콘솔

Browser/IAB에서 다음 값을 확인했다.

```json
{
  "url": "http://127.0.0.1:8080/",
  "title": "알한글 - Mac용 HWP/HWPX 뷰어"
}
```

페이지 DOM과 console health 확인 결과:

```json
{
  "hasHero": true,
  "hasIntroTitle": true,
  "hasLead": true,
  "hasPrinciple": true,
  "hasImageAlt": true,
  "logCount": 0
}
```

### 두 번째 섹션

두 번째 섹션에서 다음 텍스트와 이미지 표시를 확인했다.

```json
{
  "introText": "알한글\n\nHWP/HWPX 문서를 Mac에서 빠르게 확인하고, 편집하고, 공유하세요.\n\n문서 접근은 특정 프로그램 구매 여부에 묶이면 안 됩니다.\n\n알한글은 한글을 설치하기 어려운 Mac에서도 필요한 HWP/HWPX 문서를 확인하고 제출할 수 있게 만드는 오픈소스 도구입니다.",
  "capCount": 4,
  "shotVisible": true
}
```

시각 확인 결과:

- `알한글` 제목 위 여백은 과하게 비어 보이지 않는다.
- 리드 문구가 가장 강한 보조 문구로 유지된다.
- 철학 설명은 hairline 영역 안에서 선언문과 보조 설명으로 분리되어 보인다.
- `og-main.png` 스크린샷은 기존보다 크게 표시되며 섹션 중심 자산으로 읽힌다.
- 기능 요약 4개 항목은 현재 Browser viewport에서 줄바꿈과 간격이 깨지지 않는다.

### 주변 섹션 회귀 확인

Feature/FAQ DOM smoke 확인 결과:

```json
{
  "featureChecks": {
    "hasFeaturesTitle": true,
    "hasFinder": true
  },
  "faqChecks": {
    "hasFreeQuestion": true
  },
  "logs": []
}
```

Feature sticky section은 기존 구조상 긴 scroll-driven 구간을 사용하므로 anchor 이동 시 현재 scroll state에 따라 같은 visual이 반복 표시될 수 있다. 이번 작업이 Feature DOM, script, asset을 변경하지 않았고 console error도 없음을 확인했다.

## 명령 검증

실행한 명령:

```bash
node --check docs/script.js
rg -n "app-intro|reveal|og-main" docs/index.html docs/styles.css docs/script.js
git diff --check -- docs mydocs/working/task_m010_178_stage2.md
curl -I http://127.0.0.1:8080/
```

결과:

- `node --check docs/script.js` 통과
- `rg`로 `app-intro`, reveal hook, `og-main` 참조 존재 확인
- `git diff --check` 통과
- 로컬 서버 응답 확인:

```text
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.13.5
Content-type: text/html
Content-Length: 20387
```

## 모바일 확인 한계

Browser/IAB는 이번 환경에서 viewport resize API를 제공하지 않아 실제 390px 브라우저 viewport 자동 캡처는 수행하지 못했다. 모바일 폭 확인용 iframe harness를 `data:` URL로 열려 했으나 Browser 보안 정책상 차단되어 우회하지 않았다.

대신 다음을 확인했다.

- `docs/styles.css`에 960px 이하, 820px 이하, 좁은 화면 override가 존재한다.
- Stage 1에서 `.app-intro-philosophy`, `.app-intro-principle`, `.app-intro-media`, `.app-intro-capabilities` 모바일 override를 직접 보정했다.
- 로컬 서버가 계속 실행 중이므로 작업지시자가 실제 브라우저에서 폭을 줄여 모바일 레이아웃을 확인할 수 있다.

## 잔여 위험

- 실제 모바일 기기 또는 브라우저 devtools의 390px 전용 시각 캡처는 아직 남아 있다.
- Feature sticky 구간은 기존 scroll-driven 동작 특성상 현재 viewport와 scroll position에 따라 screenshot 재현성이 낮다.

## 다음 단계 영향

Stage 3에서는 최종 보고서 작성, 오늘할일 완료 처리, PR 준비 절차로 넘어간다. 별도 소스 보정은 현재 필요하지 않다.

## 승인 요청

Stage 2 산출물 기준으로 Stage 3 `최종 보고와 PR 준비`를 진행할지 승인 요청한다.
