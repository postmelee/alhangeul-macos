# Issue #135 Stage 3 완료 보고서

## 단계명

랜딩페이지 주요 섹션 구현

## 작업 범위

이번 단계에서는 Stage 2의 정적 사이트 골격을 바탕으로 실제 랜딩페이지 주요 섹션을 구현했다.

- Header 구현 보강
- Hero 첫 화면 구성 보정
- 영상 프리뷰 구현 보강
- Feature 섹션 구현
- FAQ 섹션 구현
- Footer 구현 보강
- Browser Use 기반 로컬 렌더 확인

## 변경 파일

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- `mydocs/orders/20260503.md`
- `mydocs/working/task_m010_135_stage3.md`

## 구현 내용

### Header

- 앱 로고와 `Alhangeul` 제품명을 왼쪽에 배치했다.
- GitHub 링크를 오른쪽에 배치했다.
- GitHub 아이콘과 external arrow 아이콘을 inline SVG로 추가했다.
- floating/sticky header를 유지하고 hover/focus 상태를 보강했다.

### Hero

- 지정된 H1 문구를 그대로 유지했다.

```text
Mac에서 한글 파일은 더 이상 이방인이 아닙니다.
```

- 지정된 supporting copy를 그대로 유지했다.

```text
스페이스바로 미리보고, Finder에서 썸네일로 찾고, HWP파일을 보고 편집하세요.
```

- `Mac 다운로드` 버튼은 GitHub Releases 최신 페이지로 연결했다.
- Browser Use 첫 화면 확인에서 `이방인` 중간 줄바꿈이 보였고, CSS에 `word-break: keep-all`, `text-wrap: balance`, tablet breakpoint font size 보정을 적용해 해결했다.
- font size는 `vw` 기반으로 스케일하지 않고 고정값과 media query로 조정했다.

### 영상 프리뷰

- `thumbnail2.mov`를 `<video>` 요소로 배치했다.
- `autoplay`, `muted`, `loop`, `playsinline`, `controls`, `preload="metadata"`를 지정했다.
- media frame에 검정 border, radius, shadow, blue corner accent를 적용했다.
- 내부 placeholder성 문구를 제거하고 사용자-facing caption으로 바꿨다.

### Feature

- `group-1-4x.png`를 이미지 주도 Feature visual로 배치했다.
- 기능은 README v0.1 MVP 범위를 기준으로 제한했다.
  - 스페이스바 미리보기
  - Finder 썸네일
  - HWP/HWPX 뷰어
  - 로컬 처리
- 각 기능에 blue line icon을 inline SVG로 추가했다.
- 작은 카드 그리드 대신 이미지와 선형 feature list 조합으로 구성했다.

### FAQ

- `details/summary` 기반 FAQ를 유지했다.
- JS가 있을 때는 한 번에 하나만 열리도록 `docs/script.js` 동작을 유지했다.
- FAQ 항목을 Stage 1 카피 인벤토리에 맞춰 7개로 확장했다.
- plus/minus 상태는 CSS pseudo element로 표시했다.

### Footer

- 로고와 제품명, 짧은 설명, GitHub, MIT License 링크를 배치했다.
- 설명은 README 제품 방향을 과장하지 않는 범위로 정리했다.

## Browser Use 확인

로컬 서버:

```text
http://127.0.0.1:8080/
```

확인한 항목:

- 첫 화면에서 Header, H1, supporting copy, `Mac 다운로드`, video frame이 보이는지 확인했다.
- H1이 `이방인` 중간에서 끊기던 문제를 확인하고 CSS로 보정했다.
- Feature 섹션에서 `group-1-4x.png`와 4개 feature list가 보이는지 확인했다.
- FAQ 섹션으로 스크롤해 7개 FAQ row가 보이는지 확인했다.
- `개인정보와 문서는 안전한가요?` FAQ 항목을 열어 본문이 표시되는지 확인했다.
- browser console `error`, `warning` log가 없는 것을 확인했다.

남은 시각 검증:

- Stage 4에서 desktop/mobile viewport별 screenshot 비교를 더 엄격히 수행한다.
- Stage 4에서 `view_image`로 Stage 1 콘셉트와 최신 브라우저 screenshot을 직접 비교한다.
- Stage 4에서 mobile overflow, focus outline, header overlap, 영상 autoplay 정책을 추가 확인한다.

## 검증 결과

실행한 명령:

```bash
rg -n "Mac에서 한글 파일은 더 이상 이방인이 아닙니다|스페이스바로 미리보고|Mac 다운로드|Quick Look|Finder|WKWebView|FAQ|MIT License" docs
rg -n "<video|<details|<summary|github.com/postmelee/alhangeul-macos/releases/latest|github.com/postmelee/alhangeul-macos" docs/index.html
git diff --check -- docs mydocs/working/task_m010_135_stage3.md
rg -n "vw|clamp\\(" docs/styles.css
```

결과:

- 필수 hero copy, CTA, Feature, FAQ, MIT License 문구가 `docs/`에 존재함을 확인했다.
- `<video>`, `<details>`, `<summary>`, GitHub Releases URL, GitHub 저장소 URL을 확인했다.
- `git diff --check`는 통과했다.
- `docs/styles.css`에 `vw` 또는 `clamp()` 기반 font scale이 없음을 확인했다.

## 리스크와 후속 조치

- 이번 단계의 브라우저 확인은 현재 Browser Use viewport 중심이다. Stage 4에서 desktop/mobile 크기별 검증을 별도로 수행해야 한다.
- `group-1-4x.png`는 여전히 원본 크기를 사용한다. Stage 4에서 로딩/렌더 비용이 문제면 preview 사본을 추가한다.
- `thumbnail2.mov` autoplay는 브라우저 정책 영향을 받을 수 있다. Stage 4에서 영상 frame과 control 표시를 다시 확인한다.
- `local/task135`는 `origin/devel-webview` 대비 behind 1 상태다. 이번 단계에서도 임의 merge/rebase는 하지 않았다.

## 승인 요청 사항

Stage 3 산출물 기준으로 Stage 4 `반응형, 접근성, 브라우저 시각 검증`을 진행할지 승인 요청한다.
