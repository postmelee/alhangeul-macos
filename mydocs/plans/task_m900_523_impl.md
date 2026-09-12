# Task M900 #523 구현계획서

## 승인과 작업 기준

2026-09-12 작업지시자의 “진행해줘.”를 [수행계획](task_m900_523.md) 승인과 구현계획서 작성 지시로 반영했다. 이후 “진행해줘. ui 시각 변경사항이 있다면 로컬서버로 내가 확인할 수 있게 해줘.”를 구현계획 승인 및 Stage 1 진행 지시로 반영했다. 각 단계의 검증·보고·커밋 후 다음 단계 승인을 받는다. 로컬 미리보기 서버는 사용자 확인을 위해 유지한다.

이슈 #523 / M900, 독립 worktree의 `local/task523`을 사용한다. 기준은 `devel`의 #521 병합 commit `feab2c6724673a122adfecd9caee6268ee146595`다. 앱 및 릴리스 환경 변경과 공개 배포는 수행계획의 제외 범위를 유지한다.

2026-09-13 작업지시자의 “승인할게 다음을 진행해줘.”를 Stage 1 승인 및 Stage 2 진행 지시로 반영했다.

같은 날 Stage 2.1 보완 결과에 대한 “진행해줘.”를 Stage 3 작성 규칙·전체 회귀 검증 승인으로 반영했다.

## Stage 1 — 소개·공개일·버전 위계

### 수정과 산출물

- `docs/updates/index.html`: 소개를 한 문단으로 정리하고 최신 버전 설명의 중복 문단을 제거한다. 앱 업데이트 안내는 “메뉴 막대에서 알한글 → 업데이트 확인…을 선택하세요.”로 줄인다. 앱 업데이트와 Homebrew 제목 옆에 작은 텍스트 배지를 둔다.
- `docs/updates/v0.1.11.html`, `docs/updates/v0.2.0.html`: 소개와 중복 다운로드 안내를 분리한다. v0.1.11 공개일은 `<time datetime="2026-09-07">`을 포함한 작은 보조 문구로 유지한다. v0.2.0이 미공개라면 공개일을 만들지 않고 준비 상태를 작은 보조 문구로 표시한다. 상세 제목의 해당 버전과 최신 제공 버전의 의미를 구분한다.
- `docs/styles.css`: 업데이트 페이지 범위의 공개일·버전 배지·제목 배치를 추가한다. 소개 21px보다 작은 보조 문구와 배지를 사용하고, 기존 모바일 미디어 규칙에 의해 소개 크기로 덮어써지지 않게 한다. 배지는 제목과 함께 줄바꿈할 수 있게 하고 텍스트 대비를 확인한다.
- 기존 전역 헤더 아래 이전 버전 배너 구조와 helper 정책을 유지한다. 현재 소스의 v0.2.0 기준 배너는 공개 승격 전 배포할 수 없는 준비 상태라는 점을 보고서에 기록한다.

구현 직전에 GitHub 최신 공개 Release·공개 appcast·원격 Homebrew tap을 읽기 전용으로 재확인한다. 앱 배지는 실제 feed, Homebrew 배지는 실제 tap 버전으로 각각 작성한다. 정적 HTML에 확인된 값을 표시하며 페이지 방문마다 외부 API를 조회하는 기능은 추가하지 않는다. 홈의 최신 다운로드는 실제 공개 asset과 일치시킨다. v0.2.0 준비 문서의 후보 링크는 공개 완료로 판정하지 않고, 공개 반영 전에 최신 main의 확정 문구로 다시 정렬한다.

변경 전 로컬 웹 미리보기에서 업데이트 홈·v0.1.11·v0.2.0의 화면을 확보한다. 변경 전 기준 commit, 브라우저, viewport와 촬영 시점을 기록한다. 보관할 이미지는 `mydocs/report/assets/task_m900_523/` 아래에 두고, 임시 실행 자료는 `build.noindex/task523/` 아래에 둔다.

### 검증과 종료

- 1440×1000, 390×844 화면에서 각 페이지의 소개, 공개일, 배지, 버튼, 배너를 비교한다. 320px 너비에서 페이지 가로 넘침과 제목 줄바꿈을 추가 확인한다.
- 사이트 홈·v0.1.10도 확인해 공통 CSS가 다른 화면을 훼손하지 않는지 검사한다.
- 신규 배지 텍스트와 실제 feed/tap을 대조하고 확인 시각·출처를 기록한다.
- `git diff --check`와 `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check`를 실행한다.
- `mydocs/working/task_m900_523_stage1.md`에 결과와 공개 전 남은 조건을 기록한다.
- 커밋: `Task #523 Stage 1: 업데이트 소개와 공개 정보 위계 정리`. 수행·구현계획과 오늘할일도 첫 단계 기록에 포함한다.

## Stage 2 — Homebrew 명령과 복사 동작

### 승인된 보완 — Stage 2.1

2026-09-13 두 명령 블록의 세로 길이를 줄이자는 요청에 `처음 설치 | 업데이트` 탭과 고정 위치 복사 버튼을 제안했고, 작업지시자의 “진행해줘.”로 보완 구현을 승인받았다. 아래 최초 계획의 동시 표시·개별 복사 버튼 구조를 탭별 패널과 공통 복사 버튼으로 보정한다. 코드 영역은 두 줄 높이를 확보하고, 탭 전환 시 성공·실패 피드백을 초기화한다. 좌우 방향키·Home/End·Tab, 실제 복사값, 복사 처리 중 전환의 늦은 응답을 추가 검증한다. JavaScript 미실행 시에는 두 명령을 모두 표시한다.

### 수정과 산출물

- `docs/updates/index.html`: Homebrew 영역을 “처음 설치”와 “Homebrew로 설치한 앱 업데이트”로 나눈다. 기존 `.code-panel`을 사용하는 `<pre><code>`와 명령별 복사 버튼을 제공한다.
- 상세 노트 두 페이지의 설치 안내는 앱 메뉴 설명을 간결하게 유지하고 Homebrew 최신 명령은 업데이트 홈의 해당 영역으로 연결한다. 과거 노트에서 현재 tap이 해당 과거 버전을 설치한다고 오해할 문구를 제거하되 릴리스 당시 사실·변경 요약은 유지한다.
- `docs/styles.css`: 코드 블록과 복사 버튼을 배치한다. 긴 명령은 블록 내부에서 가로 스크롤하며 페이지 전체를 늘리지 않게 한다. 버튼의 키보드 포커스를 명확히 표시한다.
- 신규 `docs/updates.js`: 업데이트 홈에 `defer`로 연결한다. 복사 대상 `<code>`의 텍스트를 사용해 표시 명령과 복사 값의 중복 관리를 피한다. 명령에 shell prompt, 제목, 버튼 텍스트를 포함하지 않는다.
- 버튼은 네이티브 `<button type="button">`을 사용하고 “설치 명령어 복사”, “업데이트 명령어 복사”처럼 구분한다. 성공 시 “복사됨”과 상태 안내를 제공한다. 실패 시 성공으로 표시하지 않고 수동 복사 안내를 제공한다. JavaScript가 없거나 clipboard 기능이 없을 때도 명령은 읽고 선택할 수 있어야 한다.

기존 `docs/script.js`의 복사 기능은 문의 주소와 홈 화면 기능에 연결되어 있다. 이 작업에서는 해당 동작의 범용화까지 확대하지 않고 업데이트용 최소 스크립트로 구현한다. 비동기 복사 중 중복 클릭과 연속 복사에 따른 피드백 충돌을 방지하고, 버튼 포커스를 유지한다.

정확한 복사 값은 다음과 같다. 첫 명령은 개행 없이, 업데이트 명령은 두 줄 사이 LF 하나만 포함하며 마지막 개행은 넣지 않는다.

```text
brew install --cask postmelee/tap/alhangeul
```

```text
brew update
brew upgrade --cask postmelee/tap/alhangeul
```

### 검증과 종료

- 두 버튼을 마우스와 Tab/Enter/Space로 실행하고 실제 clipboard 값을 위 문자열과 대조한다. 터미널에서 명령을 실행하거나 앱을 설치하지 않는다.
- 성공·재복사·빠른 반복 클릭·실패·clipboard API 미지원 상태의 화면 안내와 포커스를 확인한다. 실제 clipboard 검사와 실패를 유도한 검사를 보고서에서 구분한다.
- 390px·320px에서 복사 버튼이 코드와 겹치지 않는지, 코드 전체를 스크롤·선택할 수 있는지 확인한다.
- 브라우저 콘솔과 JavaScript 구문을 검사하고 `git diff --check`를 실행한다.
- `mydocs/working/task_m900_523_stage2.md` 작성 후 `Task #523 Stage 2: Homebrew 설치와 업데이트 명령 복사 제공`으로 커밋한다.

## Stage 3 — 작성 규칙과 전체 회귀

### 수정과 산출물

- `mydocs/manual/release_github_pages_sparkle_guide.md`의 기존 Pages 작성 기준에 소개 한 문단, 작은 공개일, 배지의 버전 출처, Homebrew 설치·업데이트 구분과 복사 접근성 규칙을 반영한다. 특정 버전의 조회 결과와 hash는 단계·최종 보고서에만 남긴다.
- 최종 변경 후 이미지를 Stage 1과 같은 조건으로 확보한다. 보고서와 PR의 Before/After 표에 실제 이미지를 연결한다.
- HTML 내부 경로와 fragment, CSS·JavaScript 로드, 공개 다운로드와 릴리스 링크를 검사한다. 상세 본문은 해당 버전 고정 DMG, 최신 다운로드는 현재 공개 DMG로 목적을 구분한다. 변경 대상 상세 페이지의 헤더도 최신 URL과 파일명이 일치하는지 확인한다.
- 앱·Homebrew 버전이 다를 때의 안내와 긴 명령 표시를 점검한다. 임시 fixture로 검증한 상태를 실제 공개 상태와 구분한다.

### Pages 보존 검증

공개 appcast를 이 단계에서 새로 내려받아 XML 검사 후 로컬 Pages artifact를 조립한다. 다음은 실행 예정 명령이며 지금의 통과 결과가 아니다. artifact 경로는 이 작업 전용으로 사용한다.

```sh
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml -o build.noindex/task523/public-appcast-stage3.xml
test -s build.noindex/task523/public-appcast-stage3.xml
xmllint --noout build.noindex/task523/public-appcast-stage3.xml
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast build.noindex/task523/public-appcast-stage3.xml --output-dir build.noindex/task523/pages-artifact
xmllint --noout build.noindex/task523/pages-artifact/appcast.xml
cmp build.noindex/task523/public-appcast-stage3.xml build.noindex/task523/pages-artifact/appcast.xml
shasum -a 256 build.noindex/task523/public-appcast-stage3.xml build.noindex/task523/pages-artifact/appcast.xml
git diff --check
```

`prepare-pages-artifact.sh` 및 `.github/workflows/pages-docs-deploy.yml`은 기존 경로를 유지한다. 공개 appcast 다운로드나 XML 검증이 실패하면 artifact 검증을 중단하고 실패를 기록한다.

### 단계 종료와 PR 인계

- 업데이트 홈·v0.1.11·v0.2.0·이전 배너·공유 CSS 확인, Stage 2 복사 동작과 공개 링크 회귀를 마친다. 최종 HTML과 조립 artifact 양쪽에서 리소스 경로를 확인한다.
- `mydocs/working/task_m900_523_stage3.md`에 실제 결과, 이미지 경로, appcast 비교, 미공개 asset 또는 외부 검증 제한을 기록한다.
- 커밋: `Task #523 Stage 3: Pages 작성 규칙과 회귀 검증 기록`.
- 단계 승인 후 `mydocs/report/task_m900_523_report.md` 작성 및 오늘할일 갱신으로 이어간다. 최종 보고 승인 후 `publish/task523`에 게시하고 `.github/pull_request_template.md`를 따른 `devel` 대상 Open PR을 생성한다. 본문은 `scripts/validate-github-body.sh` 검증을 거친다. PR CI는 게시 후 실제 실행 결과로 기록한다.

## 공개 전 재정렬과 완료 구분

리뷰 PR 준비와 공개 반영을 구분한다. v0.2.0 공개 승격·Pages 배포가 끝난 뒤 최신 main의 공개 문구, 공개일, DMG, 앱 feed와 Homebrew 버전을 다시 조회하고 겹친 docs 변경을 정렬한다. 정렬로 변경된 페이지는 링크·화면·복사·helper 검사를 다시 수행한다.

main의 `docs/**` 변경은 자동 Pages 배포를 유발하므로 main 반영·merge·workflow 실행은 별도 공개 승인 후에만 진행한다. 당시 공개 appcast를 새로 받아 XML 검사한 원본을 보존하고 배포 전후 bytes/hash를 비교한다. 저장소 feed fallback과 재생성은 하지 않는다. 동시 릴리스 배포가 있으면 그 완료 후 기준을 다시 확인한다.

실제 공개 배포와 배포 후 검증이 끝나기 전에는 #523 전체를 배포 완료로 보고하거나 이슈의 해당 체크 항목을 완료 처리하지 않는다. #520, #513, #337과 앱 릴리스 자산은 메인 세션의 소유 범위를 유지한다.
