# Issue #430 Stage 2 완료 보고서

## 단계 목적

Task 시작 전에 시각 검토를 마친 승인 시안의 Open Graph 설명과 철학 섹션을 작업 브랜치에 선택 반영하고, 반응형 type scale·대칭 여백·footer 무손실을 정적 검증한다.

## 산출물

- `docs/index.html`
  - 13줄 추가, 2줄 삭제
  - Open Graph 설명을 짧은 승인 문구로 변경
  - CSS cache-busting query를 `20260721-philosophy-balanced`로 갱신
  - FAQ 다음, footer 직전 본문 최하단에 독립 철학 섹션 추가
- `docs/styles.css`
  - 61줄 추가
  - 철학 섹션의 경계선, 폭, 가운데 정렬, 제목·설명 위계와 대칭 여백 정의
  - 데스크톱 40px, 태블릿 38px, 모바일 32px 제목 크기 적용
  - 모바일 위아래 68px 대칭 여백과 17px 보조 설명 적용
- `mydocs/working/task_m010_430_stage2.md`
  - Stage 2 구현·검증 결과와 Stage 3 승인 요청 기록

## 본문 변경 정도 / 본문 무손실 여부

Open Graph 설명은 다음 문구로 변경했다.

```text
Mac에서 HWP/HWPX를 미리보고 편집하고 공유하는 오픈소스 앱입니다.
```

철학 섹션은 FAQ 뒤이자 `</main>` 앞에 배치했다.

```text
문서 접근은 특정 프로그램 구매 여부에 묶이면 안 됩니다.
알한글은 한글을 구매하기 어렵거나 설치할 수 없는 사람도 필요한 문서를 확인하고 제출할 수 있도록 만드는 오픈소스 도구입니다.
```

제목의 기본 굵기는 400이며 `문서 접근`과 `특정 프로그램 구매 여부`만 600으로 적용했다. `문서 접근`에만 기존 `var(--accent)` 색상을 적용했다.

footer 원문은 홈, 업데이트, 문의/제보 페이지에 모두 유지되어 있다.

```text
docs/index.html:262: Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
docs/updates/index.html:130: Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
docs/feedback/index.html:113: Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
```

`docs/updates/index.html`, `docs/feedback/index.html`과 앱 소스는 수정하지 않았다.

## 검증 결과

구현계획서의 Stage 2 검증 명령을 실행했다.

```text
$ rg -n "og:description|philosophy-section|philosophy-title|philosophy-highlight|philosophy-emphasis" docs/index.html docs/styles.css
docs/index.html:11:  <meta property="og:description"
docs/index.html:245:    <section class="philosophy-section" aria-labelledby="philosophy-title" ...>
docs/index.html:247:        <h2 id="philosophy-title" data-reveal-item>
docs/index.html:248:          <strong class="philosophy-highlight">문서 접근</strong>은 <strong class="philosophy-emphasis">특정 프로그램 구매 여부</strong>에 묶이면 안 됩니다.
docs/styles.css:405:.philosophy-section {
docs/styles.css:427:.philosophy-highlight {
docs/styles.css:432:.philosophy-emphasis {
```

```text
$ rg -n "한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다" docs/index.html docs/updates/index.html docs/feedback/index.html
docs/index.html:262: ... 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
docs/updates/index.html:130: ... 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
docs/feedback/index.html:113: ... 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.
```

```text
$ node --check docs/script.js
(출력 없음, 성공)

$ git diff --check -- docs/index.html docs/styles.css
(출력 없음, 성공)
```

보존한 승인 시안과 현재 두 파일의 내용이 정확히 일치하는지 추가로 확인했다.

```text
$ git diff --exit-code 'stash@{0}' -- docs/index.html docs/styles.css
(출력 없음, 종료 코드 0)
```

## 잔여 위험

- 제목의 실제 줄바꿈, 강조 대비와 섹션 위아래 여백은 브라우저 viewport에 따라 달라질 수 있으므로 시각 검증이 남아 있다.
- 기존 reveal 동작은 markup 속성과 JavaScript 문법만 확인했다. 스크롤 시 등장 타이밍은 Stage 3에서 확인해야 한다.
- 공개 appcast를 보존한 Pages artifact 생성은 네트워크 접근이 필요한 Stage 3 검증으로 남아 있다.
- 브라우저가 이전 stylesheet를 캐시할 가능성은 query 갱신으로 낮췄지만 로컬·공개 페이지에서 실제 로딩을 확인해야 한다.

## 다음 단계 영향

Stage 3에서는 로컬 정적 서버를 실행해 데스크톱과 모바일에서 철학 섹션의 위치, 제목 위계, 줄바꿈, 대칭 여백, footer 연결과 overflow를 확인한다. 이후 공개 appcast를 받아 XML을 검증하고 `prepare-pages-artifact.sh`로 Pages artifact 보존 경로를 사전 검증한다.

시각 검증에서 보정이 필요하면 승인된 문구와 강조 범위는 유지하고 `docs/styles.css`의 레이아웃 값만 최소 범위에서 수정한다.

## 승인 요청

이 Stage 2 구현과 검증 결과를 기준으로 Stage 3 `브라우저 시각 검증과 Pages artifact 사전 검증`에 진입할지 승인 요청한다.
