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
- `docs/script.js`
- `docs/assets/mac_mock.png`
- `docs/assets/finder-before.png`
- `docs/assets/finder-after.png`
- `mydocs/orders/20260503.md`
- `mydocs/working/task_m010_135_stage4.md`
- `mydocs/working/assets/task_m010_135_stage4_browser.png`
- `mydocs/working/assets/task_m010_135_stage4_feature.png`
- `mydocs/working/assets/task_m010_135_stage4_hero_macbook.png`
- `mydocs/working/assets/task_m010_135_stage4_feature_sticky_start.png`
- `mydocs/working/assets/task_m010_135_stage4_feature_sticky_mid.png`
- `mydocs/working/assets/task_m010_135_stage4_feature_sticky_second.png`
- `mydocs/working/assets/task_m010_135_stage4_faq_footer.png`
- `mydocs/working/assets/task_m010_135_stage4_finder_start.png`
- `mydocs/working/assets/task_m010_135_stage4_finder_install.png`
- `mydocs/working/assets/task_m010_135_stage4_finder_after.png`

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

- Feature 섹션을 full-width parchment band와 sticky viewport 구조로 변경했다.
- `group-1-4x.png`는 별도 박스에 담지 않고 큰 이미지 viewport 안에서 확대 표시했다.
- decorative icon list를 제거하고, 현재 단계의 핵심 문구와 큰 제품 이미지 중심으로 단순화했다.
- 그림자는 product 이미지 표현에만 제한했다.

### 추가 디자인 보정

작업지시자의 추가 피드백을 반영해 Stage 4 안에서 다음 보정을 추가로 수행했다.

- 상단 캐치프레이즈의 top padding을 줄여 첫 화면에서 더 위로 배치했다.
- `mac_mock.png`를 `docs/assets/mac_mock.png`로 추가하고, `thumbnail2.mov`를 MacBook 화면 영역 위에 overlay했다.
- 영상 섹션의 dark/gray 배경을 제거하고 hero CTA 바로 아래에 붙여 첫 viewport에서 영상이 더 크게 보이게 했다.
- Feature 이미지를 white box 안에 넣는 표현을 제거하고, sticky viewport 안에서 더 크게 보이도록 확대했다.
- Feature 섹션을 scroll-driven sticky section으로 변경했다.
- 스크롤 진행도에 따라 이미지가 세로로 이동하고, 현재 단계의 핵심 문구가 `text_highlight.png` 레퍼런스처럼 blue highlight와 sweep animation으로 강조되게 했다.
- 비활성 Feature 문구는 opacity와 typography hierarchy를 낮췄다.
- 좁은 화면에서는 Feature 설명이 이미지 위에 배치되고, active 설명만 애니메이션으로 교체되게 했다.
- FAQ heading/list의 좌측 기준을 같은 content width로 맞췄다.
- Footer content width를 `1260px` 기준으로 넓혀 양끝 배치를 강화했다.

### Finder 썸네일 스토리 보정

추가 피드백에 따라 Feature 첫 번째 순서를 `Finder에서 썸네일로 찾기`로 변경하고, `스페이스바로 즉시 미리보기`를 두 번째 순서로 이동했다.

- `before.png`를 `docs/assets/finder-before.png`로 추가했다.
- `after.png`를 `docs/assets/finder-after.png`로 추가했다.
- 첫 번째 Feature의 이미지 전환을 `기존 mac -> 알한글 설치 -> Finder 썸네일` 순서로 구성했다.
- 초록색 progress bar와 3개 checkpoint를 텍스트 박스 아래에서 Finder 이미지 상단으로 이동했다.
- 첫 번째 Finder 스토리는 연속 scroll progress 값 대신 `기존 mac`, `알한글 설치`, `Finder 썸네일` 3개 snap stage로 나눴다.
- `알한글 설치` stage에서는 progress bar와 앱 로고 ring이 전부 찬 뒤 초록 check가 표시되게 했다.
- `기존 mac`에서 `알한글 설치`로 넘어가면 `.hwp 정보 잠김` pill과 lock icon은 더 빠르게 사라지게 했다.
- `알한글 설치`에서 `Finder 썸네일`로 넘어갈 때 Finder 화면은 before image에서 after image로 crossfade된다.
- Apple 공식 MacBook Pro 페이지의 highlights/closer-look product storytelling과 MacBook Air/Pro 환경 섹션의 큰 카드형 수치 강조를 참고했다.
  - `https://www.apple.com/macbook-pro/`
  - `https://www.apple.com/macbook-air/`
- 추가 조사 결과 Apple 제품 페이지는 section/storytelling 구조는 확인 가능하지만, snap threshold나 timeout 숫자는 공개 문서로 노출하지 않는다.
- Apple 산하 WebKit의 CSS Scroll Snap 설명은 active scrolling operation이 없을 때 snap point에 도달하는 모델과, JS가 trackpad scroll phase를 정확히 알기 어렵다는 점을 설명한다.
  - `https://webkit.org/blog/4017/scroll-snapping-with-css-snap-points/`
- 이를 기준으로 Finder stage 전환은 per-frame 즉시 전환 대신 hysteresis와 settle timeout을 적용했다.
  - `installEnter`: 8%
  - `beforeReturn`: 2.5%
  - `afterEnter`: 50%
  - `installReturn`: 42%
  - `settle timeout`: 120ms

## Browser Use 확인

로컬 서버:

```text
http://127.0.0.1:8080/
```

확인한 스크린샷:

- `mydocs/working/assets/task_m010_135_stage4_browser.png`
- `mydocs/working/assets/task_m010_135_stage4_feature.png`
- `mydocs/working/assets/task_m010_135_stage4_hero_macbook.png`
- `mydocs/working/assets/task_m010_135_stage4_feature_sticky_start.png`
- `mydocs/working/assets/task_m010_135_stage4_feature_sticky_mid.png`
- `mydocs/working/assets/task_m010_135_stage4_feature_sticky_second.png`
- `mydocs/working/assets/task_m010_135_stage4_faq_footer.png`
- `mydocs/working/assets/task_m010_135_stage4_finder_start.png`
- `mydocs/working/assets/task_m010_135_stage4_finder_install.png`
- `mydocs/working/assets/task_m010_135_stage4_finder_after.png`

확인한 항목:

- 상단 header에 로고, `알한글`, `GitHub`, `다운로드`가 보인다.
- hero H1이 `Mac에서 한글 파일은` / `더 이상 이방인이 아닙니다.` 두 줄로 표시된다.
- `이방인` highlight가 blue accent로 적용되어 있다.
- 영상 프리뷰가 MacBook mock 화면 안에서 정상 표시된다.
- Feature 섹션이 parchment 배경 위 sticky viewport와 active text card로 표시된다.
- Browser console error가 없다.
- 추가 보정 후 영상은 MacBook mock 화면 안에 표시된다.
- 추가 보정 후 Feature sticky 구간에서 스크롤에 따라 active 문구와 이미지 위치가 변경된다.
- FAQ 리스트와 footer는 현재 Browser Use viewport에서 정렬 기준이 어긋나지 않는다.
- Finder 썸네일 Feature가 첫 번째 순서로 표시된다.
- `기존 mac -> 알한글 설치 -> Finder 썸네일` checkpoint와 progress bar가 Finder 이미지 상단에 표시된다.
- Finder 첫 번째 스토리는 `기존 mac`, `알한글 설치`, `Finder 썸네일` 3개 stage로 snap된다.
- 설치 stage에서 progress bar와 앱 로고 ring이 모두 찬 뒤 check 완료 상태가 표시된다.
- 설치 stage에서 `.hwp 정보 잠김` pill은 빠르게 사라진다.
- Finder 이미지는 `알한글 설치`에서 `Finder 썸네일`로 넘어갈 때 `finder-before.png`에서 `finder-after.png`로 crossfade된다.
- Firefox 로컬 탭에서 새로고침 후 `기존 mac`, `알한글 설치`, `Finder 썸네일` stage 전환을 확인했다.
- 기존에 `Finder 썸네일` 이미지로 넘어가지 않던 현상은 first Feature scroll segment를 78%로 넓히고, `afterEnter` threshold를 50%로 둔 hysteresis stage 전환으로 보정했다.

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
rg -n "mac_mock|data-feature-step|feature-highlight|requestAnimationFrame|faq-title" docs
rg -n "Finder에서|스페이스바로|finder-before|finder-after|기존 mac|알한글 설치|Finder 썸네일" docs
git diff --check
```

결과:

- `docs/script.js` 문법 검사를 통과했다.
- 이전 floating/header 장식 잔여 클래스와 old accent token이 제거된 것을 확인했다.
- `box-shadow`는 media/product image에만 남겼다.
- `letter-spacing`은 0으로 유지했다.
- MacBook mock asset, Feature step markup, Feature highlight, scroll animation JS, FAQ anchor가 존재함을 확인했다.
- Finder 썸네일 Feature의 순서, before/after asset 참조, progress checkpoint 문구가 존재함을 확인했다.
- `git diff --check`는 통과했다.

## 리스크와 후속 조치

- Browser Use의 현재 viewport는 약 737px 폭으로 확인했다. CSS media query로 520px 이하 header/button/hero 크기를 별도 보정했지만, Stage 5에서 최종 검증 시 작은 모바일 폭을 다시 확인하는 것이 좋다.
- `local/task135`는 `origin/devel-webview` 대비 behind 상태다. 통합 브랜치 병합/리베이스는 작업지시자 승인 없이 수행하지 않았다.
- 다운로드 버튼은 실제 배포 산출물 대신 GitHub Releases 최신 페이지로 연결한다.

## 승인 요청 사항

Stage 4 산출물 기준으로 Stage 5 `최종 보고와 PR 준비`를 진행할지 승인 요청한다.
