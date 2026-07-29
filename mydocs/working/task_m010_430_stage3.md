# Issue #430 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 반영한 철학 섹션을 데스크톱·모바일 브라우저에서 시각 검증하고, 공개 Sparkle appcast를 보존하는 기존 docs-only Pages artifact 생성 경로를 배포 전에 검증한다.

## 산출물

- `mydocs/working/task_m010_430_stage3.md`
  - 데스크톱·모바일 DOM/CSS 계산값과 시각 확인 결과 기록
  - 브라우저 reveal 상태와 콘솔 오류 확인 결과 기록
  - Pages artifact 구성과 public appcast 무손실 검증 결과 기록
- `build.noindex/task430-pages-artifact/`
  - 검증용 로컬 생성 산출물이며 Git 추적 대상이 아니다.
  - 현행 `docs/`와 공개 `appcast.xml`을 결합한 Pages 배포 사전 검증 결과물이다.
- `/tmp/task430-public-appcast.xml`
  - 공개 Pages에서 내려받은 검증용 임시 appcast이며 Git 추적 대상이 아니다.

## 본문 변경 정도 / 본문 무손실 여부

Stage 3에서는 `docs/index.html`, `docs/styles.css`를 포함한 Pages 소스를 수정하지 않았다. 데스크톱·모바일 모두 Stage 2 승인 시안이 의도대로 렌더링되어 추가 CSS 보정이 필요하지 않았다.

시각 확인에서 footer의 기존 문구가 철학 섹션 아래에 그대로 표시되는 것을 확인했다.

```text
Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
```

생성한 Pages artifact의 `index.html`에도 승인된 Open Graph 설명, 철학 섹션과 강조 문구가 모두 포함되어 있다.

## 검증 결과

### 로컬 서버와 브라우저 구조

로컬 `docs/` 서버를 `127.0.0.1:8080`에서 실행하고 응답을 확인했다.

```text
HTTP/1.0 200 OK
Content-type: text/html
```

브라우저 DOM snapshot에서 FAQ 다음에 철학 섹션이 있고, 그 뒤에 footer가 이어지는 구조를 확인했다. 철학 문구는 접근 가능한 level 2 heading과 paragraph로 노출된다.

```text
region "문서 접근은 특정 프로그램 구매 여부에 묶이면 안 됩니다."
  heading "문서 접근은 특정 프로그램 구매 여부에 묶이면 안 됩니다." [level=2]
    strong: 문서 접근
    strong: 특정 프로그램 구매 여부
  paragraph: 알한글은 한글을 구매하기 어렵거나 설치할 수 없는 사람도 필요한 문서를 확인하고 제출할 수 있도록 만드는 오픈소스 도구입니다.
contentinfo
```

### 데스크톱 시각 검증

1440×1000 viewport에서 계산값과 실제 렌더링을 확인했다.

```text
철학 제목: 40px / 기본 400 / line-height 45.6px
FAQ 제목: 40px / 600
문서 접근: 600 / rgb(0, 102, 204)
특정 프로그램 구매 여부: 600 / rgb(29, 29, 31)
설명: 21px / line-height 32.55px
철학 섹션 padding-top: 100px
철학 섹션 padding-bottom: 100px
가로 overflow: 0px
FAQ → 철학 섹션 → footer 순서: true
```

제목 크기는 기존 FAQ 헤더와 같고, 기본 문장은 가벼운 굵기이며 두 핵심 구절만 강조된다. 섹션 위아래 여백은 동일하고 footer와의 경계가 자연스럽게 이어졌다.

### 모바일 시각 검증

390×844 viewport에서 계산값과 실제 렌더링을 확인했다.

```text
철학 제목: 32px / 기본 400 / line-height 38.4px / 2줄
FAQ 제목: 32px / 600
문서 접근: 600 / rgb(0, 102, 204)
특정 프로그램 구매 여부: 600 / rgb(29, 29, 31)
설명: 17px / line-height 26.35px / 3줄
철학 섹션 padding-top: 68px
철학 섹션 padding-bottom: 68px
가로 overflow: 0px
FAQ → 철학 섹션 → footer 순서: true
```

한국어 줄바꿈이 문장 의미를 해치지 않고, footer의 세로 배치와 본문 폭에도 회귀가 없었다.

### reveal과 브라우저 오류

철학 섹션의 reveal 상태와 브라우저 콘솔을 확인했다.

```text
section class: philosophy-section is-revealed
h2 opacity: 1
h2 transform: matrix(1, 0, 0, 1, 0, 0)
p opacity: 1
p transform: matrix(1, 0, 0, 1, 0, 0)
console warning/error: 0건
```

### 정적 검사와 Pages artifact

```text
$ node --check docs/script.js
(출력 없음, 성공)

$ scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
Release version notices are up to date for latest v0.1.8.
```

공개 appcast를 내려받아 XML을 검증한 뒤 기존 workflow와 같은 스크립트로 artifact를 생성했다.

```text
$ xmllint --noout /tmp/task430-public-appcast.xml
(출력 없음, 성공)

$ scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast /tmp/task430-public-appcast.xml --output-dir build.noindex/task430-pages-artifact
Prepared Pages artifact at /Users/melee/Documents/projects/rhwp-mac/build.noindex/task430-pages-artifact

index.html: present
updates/index.html: present
artifact appcast: valid XML
```

공개 원본과 artifact appcast의 SHA-256이 일치한다.

```text
fd1c25bb6befcbaa0c4bceb7670c2b7b42cf6db7848cc3824ce6272ce0114af4  /tmp/task430-public-appcast.xml
fd1c25bb6befcbaa0c4bceb7670c2b7b42cf6db7848cc3824ce6272ce0114af4  build.noindex/task430-pages-artifact/appcast.xml
```

최신 appcast 항목도 현행 v0.1.8 배포를 가리킨다.

```text
Alhangeul v0.1.8
https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.8/alhangeul-macos-0.1.8.dmg
```

artifact 홈의 승인 문구 포함 여부와 Git 형식 검사도 통과했다.

```text
content="Mac에서 HWP/HWPX를 미리보고 편집하고 공유하는 오픈소스 앱입니다."
<section class="philosophy-section" ...>
<strong class="philosophy-highlight">문서 접근</strong>
<strong class="philosophy-emphasis">특정 프로그램 구매 여부</strong>

$ git diff --check -- docs
(출력 없음, 성공)
```

## 잔여 위험

- 로컬 artifact 검증은 성공했지만 GitHub Actions의 Pages 권한, 배포 환경과 CDN 반영은 실제 workflow 실행 때만 확인할 수 있다.
- docs-only workflow는 공개 appcast 다운로드에 의존하므로 배포 시점의 네트워크 또는 Pages 상태가 비정상이면 안전하게 실패할 수 있다.
- `origin/main`과 `origin/devel`에는 Task #430 외 차이가 있으므로 Task PR merge 뒤에도 `main` 승격 범위를 다시 확인해야 한다.
- 공개 페이지에는 CDN 캐시로 인해 workflow 성공 직후 잠시 이전 HTML/CSS가 보일 수 있다.

## 다음 단계 영향

Stage 4에서는 구현·시각·artifact 검증 결과를 최종 결과보고서에 정리하고 오늘할일을 완료 처리한다. 이후 `task-final-report` 절차에 따라 `publish/task430` 원격 브랜치와 `devel` 대상 PR을 생성한다.

Stage 4는 PR 게시 단계이므로 이 보고서 검토와 작업지시자 승인을 받은 뒤에만 진행한다. PR merge 뒤 `main` 승격과 public Pages 배포는 Stage 5의 별도 승인 지점으로 유지한다.

## 승인 요청

이 Stage 3 검증 결과를 기준으로 Stage 4 `최종 보고와 devel 대상 PR 게시`에 진입할지 승인 요청한다.
