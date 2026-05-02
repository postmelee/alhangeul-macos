# Issue #135 Stage 4 완료 보고서

## 단계명

디자인 규칙 반영과 브라우저 시각 보정

## 작업 범위

이번 단계에서는 작업지시자가 추가로 지정한 디자인 규칙과 `getdesign.md` Apple Preview 레퍼런스를 반영해 랜딩페이지의 헤더, 타이포그래피, hero 하이라이트, Feature 이미지 프레이밍을 보정했다.

- `DESIGN.md` 기반 Apple-style typography/color/spacing 반영
- 상단 헤더를 frosted sub-nav 형태로 변경
- 제품명을 `알한글`로 한국어 표기
- 오른쪽에 `GitHub` 링크와 `다운로드` 버튼 배치
- hero H1 크기 축소와 명시적 줄바꿈 적용
- `이방인` 단어에 앱 로고색 계열 blue highlight 적용
- Feature 이미지를 parchment 배경 위 white product frame 형태로 변경
- Browser Use로 첫 화면과 Feature 섹션 렌더 확인

## 변경 파일

- `docs/index.html`
- `docs/styles.css`
- `mydocs/orders/20260503.md`
- `mydocs/working/task_m010_135_stage4.md`
- `mydocs/working/assets/task_m010_135_stage4_browser.png`
- `mydocs/working/assets/task_m010_135_stage4_feature.png`

## 디자인 반영 내용

### Header

- 기존 floating pill header를 제거하고, 화면 상단에 고정되는 52px frosted sub-nav로 변경했다.
- 왼쪽에는 앱 로고와 `알한글`을 배치했다.
- 오른쪽에는 text link `GitHub`와 blue pill `다운로드` CTA를 배치했다.
- header shadow를 제거하고 hairline border와 backdrop blur만 유지했다.

### Typography

- font stack을 Apple system font 우선으로 정리했다.
- body 기본 크기를 17px로 두고, hero display는 56px / weight 600 / line-height 1.07로 낮췄다.
- 섹션 제목은 40px / weight 600 중심으로 낮춰 Apple Preview의 절제된 hierarchy에 맞췄다.
- `DESIGN.md`에는 negative letter spacing이 있으나, 현재 프론트엔드 작업 지침의 충돌 방지를 위해 `letter-spacing: 0`을 유지했다.

### Hero

H1은 요청대로 명시적 줄바꿈과 highlight span을 적용했다.

```text
Mac에서 한글 파일은
더 이상 이방인이 아닙니다.
```

- `이방인`만 `#0066cc` blue로 하이라이트했다.
- supporting copy와 `Mac 다운로드` 버튼은 첫 화면 중앙 흐름을 유지했다.

### Feature 이미지

- Feature 섹션을 full-width parchment band로 변경했다.
- `group-1-4x.png`는 흰색 18px product frame 안에 배치했다.
- decorative icon list를 제거하고, 이미지와 선형 feature list 중심으로 단순화했다.
- 그림자는 product asset에만 제한했다.

## Browser Use 확인

로컬 서버:

```text
http://127.0.0.1:8080/
```

확인한 스크린샷:

- `mydocs/working/assets/task_m010_135_stage4_browser.png`
- `mydocs/working/assets/task_m010_135_stage4_feature.png`

확인한 항목:

- 상단 header에 로고, `알한글`, `GitHub`, `다운로드`가 보인다.
- hero H1이 `Mac에서 한글 파일은` / `더 이상 이방인이 아닙니다.` 두 줄로 표시된다.
- `이방인` highlight가 blue accent로 적용되어 있다.
- 영상 프리뷰가 dark tile 위에서 정상 표시된다.
- Feature 섹션이 parchment 배경과 white product frame으로 표시된다.
- Browser console error가 없다.

Browser Use DOM/log 확인 결과:

```json
{
  "hasKoreanBrand": true,
  "hasGithub": true,
  "hasDownload": true,
  "hasHeroBreakText": true,
  "consoleErrors": []
}
```

## 검증 결과

실행한 명령:

```bash
node --check docs/script.js
rg -n "Alhangeul|frame-corner|accent-strong|--max-width|letter-spacing|box-shadow" docs
git diff --check
```

결과:

- `docs/script.js` 문법 검사를 통과했다.
- 이전 floating/header 장식 잔여 클래스와 old accent token이 제거된 것을 확인했다.
- `box-shadow`는 media/product image에만 남겼다.
- `letter-spacing`은 0으로 유지했다.
- `git diff --check`는 통과했다.

## 리스크와 후속 조치

- Browser Use의 현재 viewport는 약 737px 폭으로 확인했다. CSS media query로 520px 이하 header/button/hero 크기를 별도 보정했지만, Stage 5에서 최종 검증 시 작은 모바일 폭을 다시 확인하는 것이 좋다.
- `local/task135`는 `origin/devel-webview` 대비 behind 상태다. 통합 브랜치 병합/리베이스는 작업지시자 승인 없이 수행하지 않았다.
- 다운로드 버튼은 실제 배포 산출물 대신 GitHub Releases 최신 페이지로 연결한다.

## 승인 요청 사항

Stage 4 산출물 기준으로 Stage 5 `최종 보고와 PR 준비`를 진행할지 승인 요청한다.
