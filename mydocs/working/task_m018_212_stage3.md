# Task M018 #212 Stage 3 완료 보고서

## 단계 목적

Footer responsive CSS를 보정해 중간 화면 폭에서도 footer nav가 설명 아래로 내려가지 않도록 했다. desktop과 중간 폭에서는 브랜드, 설명, 링크가 같은 행의 3영역에 남고, 설명 문구만 중앙 영역에서 줄바꿈된다. mobile 1열 stack 기준은 유지했다.

## 변경 내용

`docs/styles.css`의 `.site-footer` grid 구조를 조정했다.

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 기본 grid | `minmax(140px, 1fr) minmax(0, 760px) max-content` | `minmax(max-content, 1fr) minmax(0, 760px) minmax(max-content, 1fr)` |
| footer 문구 | width만 지정 | `max-width: 760px`, `justify-self: center`, `word-break: keep-all` 추가 |
| `1180px` 이하 | 2열로 전환, nav가 2행으로 내려감 | 3열 유지, nav는 우측 고정 |
| mobile | `820px` 이하 1열 stack | 유지 |

## 추가 보정

작업지시자 확인 중 홈과 `/updates/`의 footer 설명 문구 시작 위치가 서로 다르게 보이는 문제가 발견되었다. 원인은 좌우 grid column을 `max-content` 기준으로 두어, 페이지별 footer 링크 문구 폭 차이가 가운데 문구 column의 위치에 영향을 주는 것이었다.

이에 `--footer-side-width: 260px`를 추가하고 desktop 및 중간 폭 footer grid의 좌우 column을 같은 폭 기준으로 맞췄다. 이제 홈의 `업데이트 GitHub MIT License`와 `/updates/`의 `홈 GitHub MIT License`처럼 링크 문구 폭이 달라도 가운데 설명 문구 column의 시작 위치가 동일한 기준을 따른다.

## 추가 보정 2

작업지시자 추가 확인에서 footer가 여전히 중간 폭에서 무겁고 문구가 불필요하게 줄바꿈되는 문제가 확인되었다. footer가 페이지 이동 링크까지 들고 있으면 각 페이지의 링크 구성에 따라 균형을 맞추기 어렵기 때문에, 구조를 다음처럼 단순화했다.

- header에는 `업데이트`, `GitHub`, `다운로드`를 배치했다.
- footer에는 브랜드, 설명 문구, `MIT License`만 남겼다.
- footer grid는 `max-content minmax(0, 1fr) max-content`로 단순화해 설명 문구가 가능한 넓은 영역을 사용하도록 했다.
- 이전 보정에서 추가했던 `--footer-side-width` 기반 대칭 column은 제거했다.

## 추가 보정 3

작업지시자 확인에서 가장 큰 화면의 footer 설명 문구가 중앙보다 왼쪽에 치우쳐 보이는 문제가 남아 있었다. 큰 화면 기본 footer grid를 `minmax(160px, 1fr) minmax(0, max-content) minmax(160px, 1fr)`로 바꿔 좌우 영역을 같은 폭으로 두고, 설명 문구는 가운데 column에서 중앙 정렬되도록 했다. `1180px` 이하에서는 다시 `max-content minmax(0, 1fr) max-content`와 좌측 정렬을 사용해 좁은 폭에서 문구 영역을 최대한 확보한다.

## 추가 보정 4

작업지시자 확인에서 `/updates/` 본문 정보 우선순위를 다시 조정했다.

- `앱에서 확인` 제목을 `앱에서 업데이트 확인`으로 변경했다.
- 일반 사용자가 먼저 확인할 가능성이 높은 `릴리즈 노트`를 `업데이트 feed 주소`보다 위로 올렸다.
- `업데이트 feed 주소`는 보조 정보로 유지하되 릴리즈 노트 아래로 내렸다.
- `updates/` 하위 페이지 header의 첫 링크는 현재 페이지를 가리키는 `업데이트` 대신 홈으로 돌아가는 `홈`으로 표시했다.

## 추가 보정 5

작업지시자 확인에서 홈 화면의 기능 요약과 FAQ 제보 안내를 보정했다.

- 홈 화면 기능 요약에서 `Quick Look`과 `Finder 썸네일` 박스 위치를 바꿔 `Finder 썸네일`, `Quick Look`, `보기와 편집`, `내보내기와 공유` 순서로 표시했다.
- FAQ의 `앱 편집 화면의 오류는 어디에 제보하면 되나요?` 제목을 `오류는 어디에 제보하면 되나요?`로 일반화했다.
- 미리보기, 썸네일, 공유 등 알한글 저장소가 다루는 기능 오류는 `postmelee/alhangeul-macos` Issues에 제보하도록 안내 문장을 추가했다.
- 편집 화면과 `rhwp-studio` 렌더링/편집 엔진 자체 오류는 `rhwp upstream`에 제보하는 것이 가장 정확하다는 기존 설명은 유지했다.

## 추가 보정 6

작업지시자 확인에서 FAQ 목록의 `+` 표시가 버튼 중앙에 정확히 맞지 않아 보이는 문제가 있었다. 기존 `+`/`-` 문자는 폰트 메트릭의 영향을 받으므로, `summary::after`를 텍스트 대신 CSS `linear-gradient` 배경으로 그리는 아이콘으로 변경했다. 닫힌 상태는 가로선과 세로선을 같은 22px 박스 중앙에 놓고, 열린 상태는 같은 중앙 가로선만 남긴다.

## 추가 보정 7

작업지시자 확인에서 모바일 `/updates/`의 `업데이트 feed 주소` 코드블럭이 긴 URL 때문에 페이지 전체 가로 overflow를 만들 수 있는 문제가 있었다. URL을 임의로 줄바꿈하지 않고, 코드블럭 내부만 가로 스크롤되도록 `pre.code-panel`에 `overflow-x: auto`, `white-space: pre`를 적용했다. 내부 `code`는 `width: max-content`로 유지해 긴 appcast URL이 한 줄로 보이도록 했다. 동시에 `html`, `body`의 페이지 단위 수평 스크롤은 숨겨 코드블럭 밖에서 화면 전체가 좌우로 밀리지 않도록 했다.

## 추가 보정 8

작업지시자 확인에서 모바일 화면의 코드블럭 겉 박스가 본문 우측 패딩 안에 맞지 않고 잘려 보이는 문제가 남아 있었다. 원인은 `/updates/` 본문이 grid이고, grid item인 `.updates-section`의 기본 `min-width: auto`가 긴 `pre/code`의 min-content 폭을 따라가면서 섹션 전체 폭을 밀 수 있었기 때문이다. `.updates-content`와 `.updates-section`에 `min-width: 0`을 추가하고, `.code-panel`은 명시적으로 `display: block`을 지정해 겉 박스가 본문 텍스트와 같은 좌우 패딩 기준 안에 머물도록 했다.

## 의도

- 큰 화면과 중간 화면에서는 브랜드, 설명, 라이선스 링크가 같은 행에 남도록 했다.
- footer 설명 문구는 큰 화면에서 화면 중앙에 놓이고, 페이지 이동 링크 제거로 확보한 중앙 영역에서 가능한 한 한 줄로 보이게 했다.
- 업데이트 페이지 이동은 header의 주요 탐색으로 이동해 footer의 페이지별 링크 차이를 없앴다.
- 모바일 폭에서는 기존처럼 1열로 내려가므로 작은 화면의 가독성은 유지한다.

## 제외한 변경

- footer 문구 자체는 Stage 2에서 확정한 문장을 유지했다.
- `docs/appcast.xml`, workflow, release helper, Pages deployment 관련 파일은 변경하지 않았다.
- `/updates/` 본문 섹션 layout은 변경하지 않았다.

## 검증 결과

```bash
rg -n "site-footer|updates-page \\+ \\.site-footer|@media \\(max-width: 1180px\\)|@media \\(max-width: 820px\\)|@media \\(max-width: 520px\\)" docs/styles.css
```

결과: footer 기본 규칙, `1180px`, `820px`, `520px` breakpoint 위치 확인.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

```bash
python3 -m http.server 8766 --bind 127.0.0.1 --directory docs
```

결과: sandbox 권한으로는 socket bind가 막혀 승인된 실행으로 재시도했고, `http://127.0.0.1:8766`에서 task212 worktree의 `docs/` 정적 서버를 실행했다.

```bash
curl -s http://127.0.0.1:8766/styles.css | rg -n "footer-side-width|grid-template-columns:|var\\(--footer-side-width\\)"
curl -s http://127.0.0.1:8766/updates/ | rg -n "Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱|업데이트 feed 주소|수동 확인|자동 확인"
curl -s http://127.0.0.1:8766/ | rg -n "Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱|업데이트 확인"
```

결과: 8766 서버가 최신 footer CSS, 홈 footer 문구, `/updates/` footer 문구와 업데이트 안내 문구를 내보내는 것을 확인했다. `/updates/`의 `수동 확인`, `자동 확인` 카드 문구는 더 이상 검출되지 않았다.

```bash
curl -s http://127.0.0.1:8766/ | rg -n "class=\"header-link\"|푸터 링크|MIT License|footer-side-width|업데이트"
curl -s http://127.0.0.1:8766/updates/ | rg -n "class=\"header-link\"|푸터 링크|MIT License|>홈<|>GitHub<|업데이트"
curl -s http://127.0.0.1:8766/styles.css | rg -n "footer-side-width|grid-template-columns: max-content minmax\\(0, 1fr\\) max-content|header-link"
```

결과: 8766 서버에서 홈과 `/updates/` 모두 header의 `업데이트` 링크와 footer의 `MIT License` 단일 링크가 확인되었다. CSS에서는 `--footer-side-width`가 더 이상 검출되지 않고, footer grid가 `max-content minmax(0, 1fr) max-content` 기준으로 서빙되는 것을 확인했다.

```bash
/opt/homebrew/bin/timeout 15 '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  --headless --disable-gpu --disable-background-networking --disable-component-update \
  --disable-sync --no-first-run --disable-default-apps --disable-extensions \
  --user-data-dir=/private/tmp/chrome-task212-footer2 \
  --window-size=1919,1700 \
  --screenshot=/private/tmp/task212-updates-footer2.png \
  http://127.0.0.1:8766/updates/
```

결과: `/updates/` footer 문구가 desktop 폭에서 한 줄로 표시되고, footer 링크는 `MIT License`만 남은 것을 스크린샷으로 확인했다. 명령은 Chrome headless가 스크린샷 생성 후 timeout으로 종료되어 exit code 124를 반환했지만, 파일 생성과 렌더링 확인은 완료했다.

```bash
curl -s http://127.0.0.1:8766/styles.css | rg -n "grid-template-columns: minmax\\(160px, 1fr\\)|width: max-content|text-align: center|text-align: left"
```

결과: 8766 서버가 큰 화면용 중앙 정렬 footer grid와 `1180px` 이하 좌측 정렬 fallback을 최신 CSS로 내보내는 것을 확인했다.

```bash
/opt/homebrew/bin/timeout 15 '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  --headless --disable-gpu --disable-background-networking --disable-component-update \
  --disable-sync --no-first-run --disable-default-apps --disable-extensions \
  --user-data-dir=/private/tmp/chrome-task212-footer4 \
  --window-size=1919,1700 \
  --screenshot=/private/tmp/task212-updates-footer4.png \
  http://127.0.0.1:8766/updates/
```

결과: `/updates/` 큰 화면 렌더링에서 footer 설명 문구가 한 줄로 유지되고 화면 중앙 기준에 놓이는 것을 스크린샷으로 확인했다. 명령은 Chrome headless가 스크린샷 생성 후 timeout으로 종료되어 exit code 124를 반환했지만, 파일 생성과 렌더링 확인은 완료했다.

```bash
curl -s http://127.0.0.1:8766/updates/ | rg -n "알한글 홈으로 이동|홈|앱에서 업데이트 확인|릴리즈 노트|업데이트 feed 주소"
curl -s http://127.0.0.1:8766/updates/v0.1.1.html | rg -n "알한글 홈으로 이동|>홈<|>업데이트<"
```

결과: 8766 서버에서 `/updates/` header의 `홈`, `앱에서 업데이트 확인`, `릴리즈 노트`, `업데이트 feed 주소` 순서를 확인했다. 릴리즈 노트 상세 페이지의 header도 홈 링크를 내보내는 것을 확인했다.

```bash
/opt/homebrew/bin/timeout 15 '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  --headless --disable-gpu --disable-background-networking --disable-component-update \
  --disable-sync --no-first-run --disable-default-apps --disable-extensions \
  --user-data-dir=/private/tmp/chrome-task212-updates-order \
  --window-size=1919,1700 \
  --screenshot=/private/tmp/task212-updates-order.png \
  http://127.0.0.1:8766/updates/
```

결과: `/updates/` 큰 화면 렌더링에서 `앱에서 업데이트 확인`, `릴리즈 노트`, `업데이트 feed 주소` 순서와 header의 `홈` 링크를 스크린샷으로 확인했다. 명령은 Chrome headless가 스크린샷 생성 후 timeout으로 종료되어 exit code 124를 반환했지만, 파일 생성과 렌더링 확인은 완료했다.

```bash
curl -s http://127.0.0.1:8766/ | rg -n "<strong>Finder 썸네일</strong>|<strong>Quick Look</strong>|오류는 어디에 제보하면 되나요|alhangeul-macos/issues|rhwp upstream"
```

결과: 8766 서버에서 홈 기능 요약이 `Finder 썸네일` 후 `Quick Look` 순서로 표시되고, FAQ 제목과 알한글 Issues 링크, `rhwp upstream` 링크가 함께 노출되는 것을 확인했다.

```bash
curl -s http://127.0.0.1:8766/styles.css | rg -n "faq-list summary::after|linear-gradient\\(currentColor|details\\[open\\] summary::after|content: \"\\+\"|content: \"-\""
```

결과: 8766 서버에서 FAQ `summary::after`가 CSS 배경 기반 plus/minus 아이콘으로 서빙되고, 기존 텍스트 `+`/`-` content 규칙이 남아 있지 않은 것을 확인했다.

```bash
curl -s http://127.0.0.1:8766/styles.css | rg -n "overflow-x: hidden|\\.code-panel|\\.code-panel code|white-space: pre|width: max-content"
```

결과: 8766 서버에서 `html`, `body`의 페이지 단위 수평 overflow 차단과 `.code-panel` 내부 가로 스크롤 규칙이 최신 CSS로 서빙되는 것을 확인했다.

Browser quick check:

- URL: `http://127.0.0.1:8766/updates/`
- viewport: `435 x 896`
- page title: `알한글 업데이트`
- console error/warn: 없음
- 모바일 상태: `업데이트 feed 주소`의 긴 URL이 줄바꿈되지 않고 코드블럭 안에서 한 줄로 유지되며, 코드블럭 밖의 페이지 전체 수평 스크롤은 발생하지 않음

```bash
curl -s http://127.0.0.1:8766/styles.css | rg -n "updates-content|updates-section|display: block|min-width: 0|\\.code-panel"
```

결과: 8766 서버에서 `.updates-content`, `.updates-section`, `.code-panel`의 폭 축소 허용 규칙이 최신 CSS로 서빙되는 것을 확인했다.

Browser quick check:

- URL: `http://127.0.0.1:8766/updates/`
- viewport: `435 x 896`
- page title: `알한글 업데이트`
- console error/warn: 없음
- 모바일 상태: 릴리즈 카드와 `업데이트 feed 주소` 코드블럭 겉 박스가 본문 텍스트와 같은 좌우 패딩 안에 맞고, 긴 URL만 코드블럭 내부 가로 스크롤바로 이동됨

Browser quick check:

- URL: `http://127.0.0.1:8766/updates/`
- viewport: `1000 x 760`
- page title: `알한글 업데이트`
- console error/warn: 없음
- footer 상태: nav가 우측에 유지되고, footer 설명 문구가 가운데 영역에서 두 줄로 줄바꿈됨

## 산출물

- `docs/styles.css`
- `mydocs/working/task_m018_212_stage3.md`

본문 변경 정도 / 본문 무손실 여부: 해당 없음. 이번 단계는 CSS layout 보정만 수행했다.

## 잔여 위험

- Stage 3에서는 중간 폭 quick check만 수행했다. desktop과 mobile을 포함한 정식 렌더링 QA는 Stage 4에서 반복해야 한다.
- 실제 사용자의 브라우저 폭과 폰트 렌더링에 따라 줄바꿈 위치는 달라질 수 있으므로, 서버 URL에서 작업지시자 육안 확인이 필요하다.

## 다음 단계

Stage 4에서는 로컬 서버 기반으로 홈과 `/updates/`의 desktop, 중간 폭, mobile viewport를 확인하고 최종 보고서를 작성한다.

## 승인 요청

Stage 3 산출물 승인을 요청한다.

승인 후 Stage 4 `렌더링 QA와 최종 정리`로 진행한다.
