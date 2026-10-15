# Task M020 #590 최종 보고 — 웹 글꼴 안내 진입점과 모바일 헤더

## 1. 결과

사용자는 이제 **공통 헤더의 ‘글꼴 안내’** 또는 **홈 v0.2.3 배너의 ‘Mac 글꼴 설정 방법 →’**에서 Mac 설치 글꼴 설정 방법으로 바로 이동할 수 있다. 글꼴 안내 헤더를 홈과 같은 메뉴·다운로드 버튼으로 맞추고 본문 상단의 중복된 파란 안내 문구를 제거했다. 700px 이하에서는 로고/다운로드와 주요 메뉴를 두 줄로 배치해 320px에서도 읽고 누를 수 있다.

- 이슈: [#590](https://github.com/postmelee/alhangeul-macos/issues/590), M020 — 글꼴 마이그레이션.
- 일자/브랜치: 2026-10-15, `local/task590`, 게시 예정 `publish/task590` → `devel`.
- 통합 기준: `e13977ff777289a2b3235f4cf2a9a860f676c686`.
- 제품 소스 최종 변경: Stage 1.1 `a626a6dee98b416a8df310f6f6cc03eb2c789969`. 이후 Stage 2/3는 검증·문서만 추가했다.
- 승인: 수행/구현계획·Stage 1·Stage 1.1 보정에 이어 Stage 2 결과 수용 및 Stage 3 회귀·최종 보고·PR 초안 준비까지 승인받았다. **현재 로컬 준비 완료이며 공개 게시/배포 완료가 아니다.**

## 2. 변경 범위

| 변경 | 사용자에게 보이는 결과 |
|------|------------------------|
| HTML 21개 공통 헤더 | 상대 경로가 맞는 글꼴 안내 진입점. 글꼴 페이지에 현재 위치 표시 |
| 홈 배너 | 기능 소개에서 설정 안내로 바로 이동 |
| 글꼴 안내 | 홈과 같은 헤더·현재 다운로드, 별도 홈 메뉴/파란 보조 문구 제거. 나머지 제목·본문·그림 유지 |
| 공통 CSS | 데스크톱 한 줄/모바일 두 줄 sticky 헤더. 모바일 주요 메뉴·다운로드 높이 44px. 목차 여백이 헤더 높이 반영 |
| 보조 탐색 | 820px 이하에서 헤더의 Windows/Linux·GitHub를 숨기고 푸터에서 계속 접근 가능 |
| 최신 소식·문의 헤더 | 뒤처진 다운로드 URL/접근성 이름을 공식 v0.2.3으로 정렬 |
| CSS 참조 | 21개 문서에 같은 캐시 식별자 사용 |

과거 릴리즈 16개의 본문·해당 버전 다운로드·이전 안내 배너는 유지했다. 기존 홈 FAQ/푸터 안내와 news 본문/동작을 보존했다. 앱 기능·Rust/core/Studio·버전·DMG·Cask·workflow·저장소 appcast는 변경하지 않았다. 새 메뉴 라이브러리나 사이트 생성 구조도 추가하지 않았다.

## 3. 검증과 근거

| 검증 | 결과 / 근거 |
|------|-------------|
| 기본·경계·대표 하위 화면 | 25개 조합 PASS. 홈 320/360/390/768/1024/1440px와 699/700/701·819/820/821 경계, 글꼴/뉴스/문의/업데이트/최신·과거 노트. [Stage 2](../working/task_m020_590_stage2.md) |
| 키보드·목차 | 홈/글꼴의 데스크톱·모바일 Tab/Shift+Tab·본문 바로가기, 헤더/배너 Enter 4개·하위 페이지 진입 5개·목차 최종 위치 8개 PASS. 숨긴 링크는 헤더 Tab에서 제외, 푸터로 접근 가능 |
| news UI 회귀 | 9 PASS, 실패/skip 0. [로그](assets/task_m020_590/stage3/news-ui.log) |
| Pages 계약 회귀 | 14 PASS. [로그](assets/task_m020_590/stage3/news-pages.log) |
| 릴리즈 안내 | 최신 v0.2.3 일치. [로그](assets/task_m020_590/stage3/release-notices.log) |
| 구조·원문 보존 | HTML 21개/릴리즈 16개 PASS. 원본 manifest 대조, 승인한 글꼴 문구 제거 외 본문 보존, 기존 다운로드·appcast 유지. [구조 검사](assets/task_m020_590/stage3/structural-check.json) |
| 링크·증거 | 로컬 참조/자산/fragment 295곳 누락 0, 이전 증거 checksum 18개 일치·JPEG 형식 정상. [계약 검사](assets/task_m020_590/stage3/final-contracts.json) |
| 범위·공백 | HTML/CSS와 #590 문서/증거에 한정. `git diff --check` PASS |

Stage 3 [검증 요약](assets/task_m020_590/stage3/validation.json)·[단계 보고](../working/task_m020_590_stage3.md)·[checksum](assets/task_m020_590/stage3/SHA256SUMS)을 연결한다. 기존 Ruby ffi 경고가 있었으나 Pages suite 전체는 통과했으며 환경 패키지는 변경하지 않았다.

## 4. 확인 화면

[홈 미리보기](http://127.0.0.1:61371/) · [글꼴 안내 미리보기](http://127.0.0.1:61371/fonts/)

기존 loopback 서버로 `docs/` 원본을 직접 제공한다. 아래 화면은 Stage 2의 최종 제품 소스와 같아 재촬영/복사하지 않고 인계한다.

데스크톱 홈 1440×1000:

![데스크톱 헤더·설정 안내 배너](assets/task_m020_590/stage2/home-desktop.jpg)

모바일 홈 390×844:

![모바일 공통 헤더·배너](assets/task_m020_590/stage2/home-mobile.jpg)

모바일 글꼴 안내 390×844:

![통일한 모바일 글꼴 안내](assets/task_m020_590/stage2/fonts-mobile.jpg)

## 5. 한계·공개 반영

직접 화면 검증은 Codex 내장 브라우저의 지정 viewport다. 실제 iPhone/Android·Safari 등 타 브라우저 검증으로 확대하지 않는다. 뉴스는 로컬 데이터의 ‘새로운 소식을 준비하고 있습니다’ 상태로 확인했고 외부 Threads 글의 실제 수집/임베드는 이번 수용 대상이 아니다.

최종 보고 수용 후 PR 초안 `mydocs/working/task_m020_590_pr_draft.md`으로 `devel` 대상 Open PR을 게시하고 CI·리뷰를 진행한다. 원격 CI는 아직 실행하지 않았다. `devel` 반영만으로 공개 웹에 적용되는 것은 아니며, 이후 승인된 main 인계·Pages 배포가 필요하다. main 반영 직전 실제 공개 appcast 보존 입력과 동시 배포 상태를 확인해야 한다.

소형 정적 검사와 기존 화면 재사용으로 공간 사용을 제한했다. 앱/Rust 빌드·새 DMG·사이트 미디어 복사본은 만들지 않았고, 기존 설치 앱·DMG·사용자 TXT·OS 색인은 변경하지 않았다. 로컬 서버·작은 검사 로그·선별 증거는 게시/리뷰에 필요해 유지한다.
