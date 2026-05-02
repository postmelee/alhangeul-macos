# Issue #135 구현 계획서

## 작업명

GitHub Pages용 알한글 랜딩페이지 제작

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_135.md`를 기준으로 진행한다.
- 작업 브랜치는 `local/task135`, 통합 대상은 `devel-webview`로 둔다.
- GitHub Pages에서 빌드 도구 없이 서빙할 수 있도록 `docs/` 하위 정적 파일을 만든다.
- 전체 카피는 한국어로 작성하고, 제품 설명은 README의 구현 상태와 로드맵을 기준으로 한다.
- 색상은 true white, black, near-black, neutral gray를 기본으로 하고 앱 로고 blue만 하이라이트로 사용한다.
- 사용자가 지정한 첫 화면 문구는 그대로 유지한다.
  - `Mac에서 한글 파일은 더 이상 이방인이 아닙니다.`
  - `스페이스바로 미리보고, Finder에서 썸네일로 찾고, HWP파일을 보고 편집하세요.`
- 레퍼런스 `https://openscreen.vercel.app/`의 구조와 리듬을 따른다.
  - 플로팅 헤더
  - 중앙 대형 히어로
  - Mac 다운로드 버튼
  - 앱 실행 영상 프리뷰
  - Feature 쇼케이스
  - FAQ
  - 짧은 푸터
- Build Web Apps 지침에 따라 실제 구현 전에 디자인 콘셉트와 토큰을 확정한다.
- 과장된 제품 주장을 피한다. 현재 구현된 기능과 향후 로드맵은 문구에서 구분한다.
- HostApp, Quick Look, Thumbnail extension, Xcode project, 배포 설정은 변경하지 않는다.
- 각 단계 완료 후 단계별 완료보고서를 작성하고 작업지시자 승인 전 다음 단계로 진행하지 않는다.

## 사전 확인 요약

- `devel-webview` 기준 README는 v0.1 MVP에서 Quick Look preview, Finder thumbnail, HWP/HWPX UTI 등록, HostApp 열기, WKWebView 기반 viewer 로드를 구현 완료로 표시한다.
- `docs/` 디렉터리는 현재 없다. 새 정적 사이트를 `docs/index.html`, `docs/styles.css`, `docs/script.js`, `docs/assets/`로 추가하는 방식이 가장 단순하다.
- `assets/logo-256@2x.png`는 worktree에 존재한다.
- `thumbnail2.mov`와 `Group 1_4x.png`는 메인 worktree 루트에는 있으나 `/private/tmp/rhwp-mac-task135` 분리 worktree에는 없다. 구현 단계에서 원본을 읽어 `docs/assets/`로 복사해야 한다.
- 레퍼런스 페이지는 상단 floating header, hero, download CTA, media preview, feature screenshots, FAQ accordion, footer로 구성되어 있다.
- 현재 실제 release artifact URL은 확정되어 있지 않다. 다운로드 버튼은 `https://github.com/postmelee/alhangeul-macos/releases/latest`로 연결하고, 버튼 문구는 `Mac 다운로드`로 둔다.

## Stage 1: 레퍼런스 분석과 디자인 콘셉트 확정

대상:

- `mydocs/working/task_m010_135_stage1.md`
- 필요 시 임시 디자인 콘셉트 이미지
- 필요 시 레퍼런스 브라우저 스크린샷

작업:

- 레퍼런스 페이지의 섹션 순서, 첫 화면 구성, 헤더/CTA/FAQ 동작을 정리한다.
- README에서 랜딩페이지에 쓸 제품 메시지를 추린다.
- 랜딩페이지 정보 구조를 확정한다.
  - Header: 로고, `Alhangeul`, GitHub 링크
  - Hero: 지정 문구 2개, Mac 다운로드 버튼
  - Media: `thumbnail2.mov` 영상 프리뷰
  - Features: Finder 미리보기, Finder 썸네일, WKWebView viewer, 로컬 처리/오픈소스 메시지
  - FAQ: 설치/무료 여부/개인정보/지원 포맷/편집 지원/손상 경고/업데이트
  - Footer: 로고, 짧은 소개, 라이선스
- Build Web Apps 지침에 맞춰 이미지 생성 기반 디자인 콘셉트를 만든다.
  - 흰색/검정 중심, blue accent
  - Open Screen 레퍼런스의 섹션 흐름
  - 앱 로고와 사용자 제공 media/feature asset 배치 고려
- 디자인 토큰을 정리한다.
  - 색상, typography, spacing, radius, border, shadow, motion, responsive breakpoints
- 구현할 copy inventory와 above-the-fold 허용 문구를 단계 보고서에 기록한다.

산출물:

- 디자인 콘셉트 이미지 경로
- `mydocs/working/task_m010_135_stage1.md`

검증:

```bash
git status --short
rg -n "Mac에서 한글 파일은 더 이상 이방인이 아닙니다|스페이스바로 미리보고|Finder|WKWebView|Quick Look" README.md mydocs/plans/task_m010_135.md
git diff --check -- mydocs/working/task_m010_135_stage1.md
```

완료 조건:

- 구현에 사용할 섹션 순서와 copy inventory가 확정되어 있다.
- 디자인 콘셉트와 토큰이 단계 보고서에 기록되어 있다.
- 다운로드 버튼 URL 정책이 확정되어 있다.

예상 커밋:

```text
Task #135 Stage 1: 랜딩페이지 디자인 콘셉트 확정
```

## Stage 2: GitHub Pages 정적 사이트 골격과 자산 배치

대상:

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- `docs/assets/logo-256@2x.png`
- `docs/assets/thumbnail2.mov`
- `docs/assets/group-1-4x.png`
- 필요 시 `docs/assets/group-1-4x-preview.png`
- `mydocs/working/task_m010_135_stage2.md`

작업:

- `docs/` 디렉터리와 정적 HTML/CSS/JS 파일을 만든다.
- `assets/logo-256@2x.png`를 `docs/assets/`로 복사한다.
- 메인 worktree의 `thumbnail2.mov`와 `Group 1_4x.png`를 `docs/assets/`로 복사한다.
- 파일명은 URL 안전성을 위해 소문자와 하이픈 중심으로 정리한다.
- `Group 1_4x.png`는 원본을 보존하되, 필요하면 웹 프리뷰용 축소 사본을 추가한다.
- HTML head에 기본 SEO, Open Graph, viewport, theme color를 작성한다.
- `noscript`와 media fallback 문구를 준비한다.
- 정적 페이지가 파일 경로 기준으로 자산을 정상 참조하도록 상대 경로를 사용한다.

산출물:

- `docs/` 기본 파일과 자산
- `mydocs/working/task_m010_135_stage2.md`

검증:

```bash
find docs -maxdepth 3 -type f | sort
file docs/assets/logo-256@2x.png docs/assets/thumbnail2.mov docs/assets/group-1-4x.png
rg -n "thumbnail2|group-1-4x|logo-256|Alhangeul|GitHub" docs
git diff --check -- docs mydocs/working/task_m010_135_stage2.md
```

완료 조건:

- `docs/index.html`에서 모든 자산 경로가 상대 경로로 연결되어 있다.
- 랜딩페이지 필수 자산이 `docs/assets/`에 존재한다.
- 아직 시각 구현 전이라도 정적 페이지 골격이 브라우저에서 열릴 수 있다.

예상 커밋:

```text
Task #135 Stage 2: GitHub Pages 정적 사이트 골격 구성
```

## Stage 3: 랜딩페이지 섹션 구현

대상:

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- `mydocs/working/task_m010_135_stage3.md`

작업:

- Header를 구현한다.
  - 앱 로고와 앱 이름
  - GitHub 링크
  - sticky/floating 처리
- Hero를 구현한다.
  - 지정 H1 문구
  - 지정 보조 문구
  - Mac 다운로드 버튼
  - 첫 viewport에서 다음 영상 섹션의 일부가 보이도록 높이와 spacing 조정
- 영상 프리뷰를 구현한다.
  - `thumbnail2.mov`를 `video` 요소로 배치
  - `autoplay`, `muted`, `loop`, `playsinline`, `controls` 정책 검토
  - media frame, border, shadow, fallback 텍스트 적용
- Feature 섹션을 구현한다.
  - `Group 1_4x.png` 또는 축소 사본 사용
  - Finder Quick Look, Finder thumbnail, WKWebView viewer, 로컬 처리/오픈소스 메시지
  - 반복 카드 남발 없이 레퍼런스의 넓은 media-led 구성을 유지
- FAQ 섹션을 구현한다.
  - JS 없이도 읽히는 `details/summary` 기본 구조 우선
  - 필요 시 `script.js`로 하나씩 열리는 accordion 동작 추가
- Footer를 구현한다.
  - 로고, 짧은 설명, MIT License, GitHub 링크

산출물:

- 완성된 주요 섹션
- `mydocs/working/task_m010_135_stage3.md`

검증:

```bash
rg -n "Mac에서 한글 파일은 더 이상 이방인이 아닙니다|스페이스바로 미리보고|Mac 다운로드|Quick Look|Finder|WKWebView|FAQ|MIT License" docs
rg -n "<video|<details|<summary|github.com/postmelee/alhangeul-macos/releases/latest|github.com/postmelee/alhangeul-macos" docs/index.html
git diff --check -- docs mydocs/working/task_m010_135_stage3.md
```

완료 조건:

- 요청된 모든 섹션이 `docs/index.html`에 존재한다.
- FAQ는 키보드와 기본 브라우저 동작으로 열고 닫을 수 있다.
- 다운로드 버튼과 GitHub 링크가 실제 URL로 연결된다.
- Feature 문구가 README의 현재 구현/로드맵 상태를 과장하지 않는다.

예상 커밋:

```text
Task #135 Stage 3: 랜딩페이지 주요 섹션 구현
```

## Stage 4: 반응형, 접근성, 브라우저 시각 검증

대상:

- `docs/index.html`
- `docs/styles.css`
- `docs/script.js`
- 필요 시 `docs/assets/*`
- `mydocs/working/task_m010_135_stage4.md`

작업:

- 로컬 정적 서버로 페이지를 실행한다.
- Browser/IAB 또는 사용 가능한 브라우저 검증 도구로 데스크톱과 모바일 크기를 확인한다.
- `view_image`로 디자인 콘셉트와 최신 구현 스크린샷을 직접 비교한다.
- 첫 화면 copy diff를 확인한다.
- 영상과 Feature 이미지 로드 상태를 확인한다.
- FAQ 토글, GitHub 링크, 다운로드 링크를 확인한다.
- responsive overflow, 줄바꿈, 버튼 텍스트, media frame, header 겹침을 수정한다.
- 접근성을 확인한다.
  - alt text
  - focus-visible
  - `aria-label`
  - `prefers-reduced-motion`
  - color contrast

산출물:

- 최종 보정된 `docs/` 파일
- 브라우저 검증 스크린샷 경로
- `mydocs/working/task_m010_135_stage4.md`

검증:

```bash
python3 -m http.server 8080 --directory docs
find docs -maxdepth 3 -type f | sort
rg -n "aria-label|prefers-reduced-motion|alt=|details|summary|video" docs
git diff --check -- docs mydocs/working/task_m010_135_stage4.md
```

브라우저 수동 검증 항목:

- desktop first viewport
- mobile first viewport
- 영상 visible frame
- Feature 이미지 visible frame
- FAQ open/close
- header/GitHub/download 링크
- text overlap/overflow 없음

완료 조건:

- 데스크톱과 모바일에서 첫 화면 문구가 겹치거나 잘리지 않는다.
- 영상과 Feature 이미지가 정상 표시된다.
- FAQ와 링크가 동작한다.
- 디자인 콘셉트와 구현 스크린샷 비교 결과 남은 중대 시각 drift가 없다.

예상 커밋:

```text
Task #135 Stage 4: 랜딩페이지 브라우저 검증과 보정
```

## Stage 5: 최종 보고와 PR 준비

대상:

- `mydocs/report/task_m010_135_report.md`
- `mydocs/orders/20260503.md`
- 필요 시 `README.md`

작업:

- 최종 결과보고서를 작성한다.
- 오늘할일 #135 상태를 완료로 갱신한다.
- 모든 변경 파일을 확인한다.
- 정적 사이트 검증 결과와 시각 검증 결과를 최종 보고서에 남긴다.
- PR 본문에 넣을 요약, 검증, 문서 링크를 정리한다.

산출물:

- `mydocs/report/task_m010_135_report.md`
- 완료 처리된 `mydocs/orders/20260503.md`

검증:

```bash
git status --short
git diff --check -- docs mydocs README.md
find docs -maxdepth 3 -type f | sort
rg -n "GitHub Pages|랜딩페이지|Mac 다운로드|검증" mydocs/report/task_m010_135_report.md
```

완료 조건:

- 최종 보고서가 작성되어 있다.
- 오늘할일이 완료 상태로 갱신되어 있다.
- PR 직전 미커밋 변경이 없도록 정리할 수 있다.

예상 커밋:

```text
Task #135 Stage 5 + 최종 보고서: 랜딩페이지 검증 정리
```

## 전체 검증 명령

구현 전체 완료 전 최소 확인:

```bash
find docs -maxdepth 3 -type f | sort
rg -n "Mac에서 한글 파일은 더 이상 이방인이 아닙니다|스페이스바로 미리보고|Mac 다운로드|Quick Look|Finder|WKWebView|FAQ|GitHub" docs
git diff --check -- docs mydocs README.md
```

브라우저 확인:

```bash
python3 -m http.server 8080 --directory docs
```

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1을 진행할지 승인 요청한다. 승인 전에는 `docs/` 구현 파일과 랜딩페이지 자산을 생성하지 않는다.
