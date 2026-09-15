# Task M010 #555 구현계획서

## 작업 개요와 승인 상태

- 이슈: [#555 — 제품 페이지에 Threads 알한글 소식 수집과 카드 아카이브 추가](https://github.com/postmelee/alhangeul-macos/issues/555)
- 마일스톤: `v0.1` / M010
- 수행계획서: [task_m010_555.md](task_m010_555.md)
- 작업 경로: `/Users/melee/Documents/projects/rhwp-mac`
- 작업 브랜치: `local/task555` → `publish/task555` → `devel`
- 시작 기준: `c0b0468c6dbfdfd2f3e3d1d9c5ccf993e7bd8a3b`, 수행계획 커밋: `8a44fc1`
- 수행계획 승인: 2026-09-15 같은 스레드의 “진행해줘.” 지시.
- 구현계획 승인: 2026-09-15 같은 스레드의 “진행해줘.” 지시.
- 현재 단계: Stage 4 Pages 통합·운영 검증 완료. [Stage 3 보고서](../working/task_m010_555_stage3.md) 후 같은 스레드의 “진행해줘.” 지시로 진입했다. [Stage 4 보고서](../working/task_m010_555_stage4.md)를 최종 보고·PR 절차로 인계한다.
- 방향 보정: 사용자가 자동 연결 가능 여부 설명 뒤 “진행해줘.”라고 지시하여 자동 선별·공식 임베드의 기술 검증과 계획 보정을 진행했다. 본문 복제·Git 데이터 브랜치를 제거한 보정안에 따라 Stage 2 진행 승인을 받았다. 공개 활성화 게이트는 유지한다.
- Stage 2 결과: [단계 보고서](../working/task_m010_555_stage2.md). 43개 fixture 검사, 실계정 7페이지·263개·대상/임베드 6개, 로컬 재생성 검증을 통과했다.
- Stage 1 근거: [API 계약과 최초 연결 안내](../tech/task_m010_555.md). `threads_basic`의 URL 선별과 공개 oEmbed를 조합한 전체 사용 사례에 대한 Meta의 승인·유권해석을 확보한 것은 아니다. 구현은 비활성 상태로 검증하며, 이 사용 목적 확인은 공개 활성화 게이트로 남긴다.

아래 API 필드·권한·조회 범위는 실제 계정에서 검증해야 할 계약이다. Stage 1에서 지원되지 않는 조건이 발견되면 결과와 수정안을 제시하고 단계 계획을 보정한다. 검증하지 않은 기능을 지원한다고 가정해 후속 구현을 시작하지 않는다.

## 1. 구현 계약

### 수집 대상

- 인증된 계정의 ID와 사용자명이 `@postmelee`와 일치하는지 확인한다. 고정 계정 ID를 운영 설정에 저장하고 이후에는 이름만으로 계정 동일성을 판단하지 않는다.
- 본인 게시물 목록에서 실제 주제 태그가 `알한글`인 원문을 선택한다. 태그는 Unicode NFC와 앞뒤 공백만 정규화하며 본문 검색으로 대체하지 않는다.
- 다른 계정 글, 단순 재게시물, 답글은 제외한다. 본인이 새로 작성한 인용 게시물은 본인 작성 부분과 주제 태그가 조건을 충족할 때 포함하고 인용 원문 내용을 복제하지 않는다.
- `topic_tag`, 작성자 정보, 재게시·답글·인용 구분 필드의 실제 제공 여부를 Stage 1에서 확인한다. 미반환 필드를 거짓으로 단정하거나 본문으로 추정하지 않는다.
- 글의 게시 시각을 기준으로 최신순 정렬하고, 같은 시각은 원문 ID로 안정적으로 정렬한다.

### 공통 공개 데이터 — 스키마 2

공개 JSON은 `data/news.json`에 배치한다. 본문·작성자 객체·태그·숫자 media ID·미디어 CDN 주소·반환 HTML은 넣지 않는다. 기존 스키마 1은 공개 배포 전 조사안이므로 호환 유지 없이 거부한다.

| 필드 | 형식과 용도 |
|---|---|
| `schema_version` | 정수 2. 다른 버전과 부울 값은 거부 |
| `updated_at` | 완전 조회·검증한 UTC 시각. 비활성 초기값은 null |
| `expires_at` | 갱신 시각에서 48시간 이내의 표시 기한. 초기값은 null |
| `items` | 최신순 원문 참조 배열. 비활성 초기값과 정상 빈 결과를 시각으로 구분 |
| 항목 `platform` | 현재 `threads`. 후속 X 추가 시 명시 확장 |
| 항목 `permalink` | 검증된 `@postmelee` 정규 HTTPS 원문 URL. 동일 shortcode 별칭도 중복 거부 |

최신순 정렬·작성자·태그 판별은 인증된 수집기의 책임이다. 공개 파일은 정렬된 순서를 유지하며 날짜·본문·미디어 표시를 공식 임베드에 맡긴다. frontend는 외부 응답 HTML을 `innerHTML`로 넣지 않고 검증된 원문 URL로 공식 `blockquote.text-post-media` 컨테이너를 만든다. Threads의 고정 `embed.js` 한 개가 이를 공식 iframe으로 렌더링한다. 본문의 일부 발췌나 자체 썸네일을 만들지 않는다.

### 저장과 배포 — 실행마다 현재 원문에서 생성

1. Threads가 원문 데이터 원천이다. `data/news` Git 브랜치와 별도 장기 `state.json`을 만들지 않는다. 매 배포에서 전체 API 목록·태그와 공개 oEmbed를 새로 확인하고 그 실행의 snapshot만 사용한다. 현재 263개는 7페이지로 끝나므로 전수 조회가 실용적이다. 규모·상한이 변하면 부분 조회를 실패 처리하고 다시 설계한다.
2. `docs/data/news.json`은 스키마 2의 빈 초기값만 커밋한다. 실데이터는 `build.noindex/` 또는 runner 임시 경로에 생성하며 소스 Git 이력, release 증빙 artifact에 포함하지 않는다.
3. `NEWS_DATA_ENABLED=true`이면 모든 Pages 조립 경로가 fresh snapshot을 요구한다. 소스의 빈 값이나 이전 실행 artifact로 대체하지 않는다. 조회·검증 실패 시 배포를 중단하여 현재 공개 사이트를 유지한다. 다음 성공 실행에서 다시 생성하므로 미반영 저장 commit·배포 hash 상태가 필요 없다.
4. 6시간 정기 실행마다 새 `updated_at`과 `expires_at`으로 갱신한다. 내용이 같더라도 freshness를 갱신하여 배포한다. 48시간 갱신되지 않은 목록은 화면에서 표시를 중단하고 원문 프로필 안내를 제공한다. 이는 UI 표시 기한이며 서버 파일의 물리적 삭제를 보장하는 장치는 아니다.
5. 기존 docs-only와 release의 `pages-deploy` 잠금 안에서 조회→appcast 보존→조립→배포를 수행한다. 오래된 사전 수집 파일을 큐에 넣지 않는다. 뉴스 조회는 release 외부 부작용보다 먼저 검증한다.
6. 뉴스가 포함된 Pages artifact는 보존 기간을 1일로 줄인다. explicit 삭제 요청 시 현재 사이트 재배포와 해당 artifact 삭제를 함께 수행하는 절차를 작성한다. release 증빙은 뉴스 snapshot을 포함하지 않는다. 기존 release 증빙의 보존 정책은 유지한다. GitHub/CDN의 내부 보존까지 임의로 삭제 완료를 보장하지 않는다.

### 정기 수집과 토큰 운영

- 승인된 `main`의 실행 코드만 운영한다. `threads-news-sync.yml`은 6시간(`17 */6 * * *`) 예약과 수동 dry-run을 지원한다. 예약 실행은 정각·즉시 반영을 보장하지 않는다.
- `THREADS_NEWS_ENABLED=true`에서만 예약 실행한다. `NEWS_DATA_ENABLED`는 표시 활성화로 분리한다. 둘 다 기본 비활성이다. 연결 철회·삭제 요청 때는 fresh API 없이도 표시 제거 배포를 실행하는 명시적인 중단 경로를 제공한다.
- `THREADS_ACCESS_TOKEN`과 고정 계정 ID `29072097499042855`는 인증된 수집 단계에만 전달한다. oEmbed client는 토큰을 받지 않으며 `https://graph.threads.com/v1.0/oembed`만 호출한다. Pages 업로드·배포 단계의 환경변수에는 토큰을 두지 않는다.
- 장기 토큰은 문서상 60일이다. 실제 발급/갱신 응답의 만료 시각을 운영 변수 `THREADS_TOKEN_EXPIRES_AT`에 기록하고 14일 전부터 갱신 필요를 알린다. 발급일만으로 정확한 만료를 확정하지 않는다. 만료·철회는 실패로 처리한다.
- 운영자가 보호된 터미널에서 재발급/갱신 후 저장소 secret을 교체한다. Actions가 secret을 다시 쓰기 위한 관리자 토큰을 추가하지 않는다. 토큰 교환·갱신 helper는 Stage 2에서 비밀 없는 검증과 분리하고 실제 갱신은 발급 24시간 이후의 수동 작업으로 안내한다.
- 수집은 읽기 권한으로 동작한다. 소식 데이터를 저장하기 위한 `contents: write`는 필요 없다. release의 기존 쓰기 권한은 뉴스 수집에 확장하지 않는다. Pages 배포 job만 `pages: write`, `id-token: write`를 사용한다.
- API 본문·인증 URL·token·HTML은 실행 로그나 요약에 기록하지 않는다. 상태는 성공 여부·개수·시간·정적 오류 종류만 남긴다. 별도의 이메일·메시지는 보내지 않는다.

## 2. Stage 1 — API·계정 검증과 데이터 계약 확정

### 변경 파일과 작업

- 신규 `scripts/ci/threads-news.py`: `probe`, 선택적 `--check-embeds`/`--reference-output`, `validate` 진입점과 데이터 계약을 만든다. Python 표준 라이브러리를 우선 사용하고 외부 라이브러리가 필요하면 이유와 고정 버전을 기록한다.
- 신규 `scripts/ci/fixtures/threads-news/`: 실제 응답 구조에서 인증 정보·무관한 글을 제거한 구조 fixture와 판정용 synthetic 데이터를 구분한다. 사용자 게시물 전문이 들어간 raw 응답은 커밋하지 않는다.
- `scripts/ci/test-threads-news.py`의 Stage 1 부분은 토큰 비노출과 probe/validate 계약 검증을 위해 이 단계에서 작성한다. 실제 계정 연결 전 fixture는 synthetic임을 명시하며, Stage 2의 동기화 테스트는 후속 단계에서 추가한다.
- `mydocs/working/task_m010_555_stage1.md`: 실제 사용한 API 버전·endpoint·fields·권한·수집 범위·태그/재게시 판정·보관 조건 및 토큰 운영 확정 결과를 기록한다.
- 최초 연결 시 운영자가 수행할 Meta 앱·본인 계정 인증 동작과 토큰 전달 경로를 구체적으로 안내한다. 설정 변경이나 secret 등록은 해당 동작의 승인 후 수행하고, 토큰 값을 대화로 요청하지 않는다.

### 실측 항목

1. 인증된 계정 조회와 본인 게시물 목록의 작성자 일치.
2. 사용자 제공 공유 링크의 정규 원문과 ID, 실제 `알한글` 주제 태그 일치.
3. 태그 없는 글·다른 태그·답글·재게시물·인용 게시물의 반환 방식과 누락 필드 의미.
4. 페이지네이션, 조회 기간·개수 제한, 최초 조회 가능한 과거 시점. 검증용으로 새로운 게시물이나 댓글을 작성하지 않는다.
5. 원문 수정·태그 변경·접근 불가·삭제를 구분할 수 있는 응답. 실제 삭제 실험 대신 문서 근거와 fixture를 함께 사용한다.
6. 이미지/동영상/캐러셀/긴 텍스트 반환과 미디어 URL 수명. 본문이 잘리는 응답은 전체 본문으로 표시하지 않는다.
7. 공식 플랫폼 데이터 보관·표시 조건, 토큰 교환·갱신 조건과 저장 방식의 적합성.

### 검증과 종료

- `python3 scripts/ci/threads-news.py probe`는 인증 환경에서 실행하고 본문·토큰 없는 결과 요약만 남긴다. `--help`에 실제 토큰 입력 경로를 설명한다.
- 실제 예시 글 포함과 비대상 글 제외를 확인하고 `validate`가 복제 본문·잘못된 필드·URL·유효기간을 거부하는지 확인한다. 대상 6개를 인증 없는 oEmbed로 확인하고 로컬 공식 임베드 렌더링을 검증한다.
- Stage 1의 기술 검증은 실제 계정·태그·전체 페이지·oEmbed·로컬 렌더링을 확인한다. 보정안 수용 및 Stage 2 진입 승인을 요청하며, 전체 API 사용 목적 확인은 공개 활성화 전에 충족할 조건으로 분리해 명시한다. 기술적 성공을 Meta의 정책 승인으로 기록하지 않는다.
- 단계 보고서를 산출물과 함께 커밋: `Task #555 Stage 1: Threads 조회와 소식 데이터 계약 검증`.

## 3. Stage 2 — 자동 선별과 snapshot 생성

### 변경 파일과 작업

- `scripts/ci/threads-news.py`: Stage 1의 client/검증기를 활용하여 `sync`와 토큰 만료 상태 검사를 추가한다. 조사용 fields에서 실제 선별에 필요한 최소 필드로 줄이되 실측·회귀 검증한다.
- `scripts/ci/test-threads-news.py`, fixture: 실패 시 파일 보존, 정상 빈 결과, 태그 제거·누락·만료·oEmbed 오류·중복·정렬을 검증한다.
- `.github/workflows/threads-news-sync.yml`: 기본 비활성, 6시간 예약, 수동 dry-run. Stage 4에서 기존 Pages workflow 호출을 연결한다.
- `docs/data/news.json`: 스키마 2의 비활성 빈 초기값. 실제 결과는 `build.noindex/task555/`에만 저장한다.

### 동기화 계약

1. 계정 ID와 사용자명, 모든 페이지의 shape·cursor·상한을 검증한다. 중간 오류나 조회 상한 도달은 실패이며 새 파일을 쓰지 않는다. 확인 불가 작성자·인용 필드가 발생하면 운영 동기화는 불완전 결과로 중단한다.
2. 완전한 현재 목록에서 실제 태그가 일치하는 본인 원문만 최신순으로 고른다. 태그가 사라진 글과 전체 현재 목록에 없는 글은 새 표시 snapshot에 넣지 않는다. 목록 부재를 원문의 영구 삭제로 단정하지 않고 ‘현재 대상 목록에서 미관찰’로 기록한다. 기존 본문 아카이브를 삭제하는 작업은 없다.
3. 대상 각각의 oEmbed를 인증 없이 요청하고 원문 shortcode·공식 컨테이너·제공자·script URL을 대조한다. 한 개라도 실패하면 부분 목록을 게시하지 않는다. 권한·삭제·비공개를 일반 HTTP 상태 하나로 구별한다고 가정하지 않는다. 지속적인 특정 글 오류는 운영자가 확인하고 제외 목록으로 처리할 수 있게 한다.
4. 전체 검증 후 링크만 담은 스키마 2 snapshot을 임시 파일로 작성하고 원자적으로 교체한다. 정상 대상 0개는 갱신 시각이 있는 빈 목록이며 비활성 seed와 구분한다.
5. 429/5xx에는 제한된 횟수와 총시간의 재시도를 적용하고 `Retry-After`를 존중한다. 인증 오류는 반복하지 않는다. 두 client 간 credential·redirect 전달을 금지한다.

### 검증과 종료

- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-threads-news.py`와 syntax 검사를 통과시킨다.
- 실패 주입 전후 출력 bytes 불변, 완전 성공 시 최신 목록 교체, 날짜 순서와 48시간 만료 경계를 검증한다.
- 실제 계정으로 로컬 snapshot 생성과 재생성을 검증한다. 데이터 항목은 안정적이고 갱신 시각은 변해야 한다.
- workflow YAML·비활성 기본값·main 제한·secret 경계를 검사한다. 예약 실행, secret 등록, 공개 배포는 실행하지 않는다.
- 커밋: `Task #555 Stage 2: Threads 자동 선별과 임베드 참조 생성` + 단계 보고서.

## 4. Stage 3 — 홈과 전체 목록의 공식 임베드

### 변경 파일과 화면

- 화면 요구사항 보정: 2026-09-15 사용자가 로컬 배치 시안 검토 후 아래 표시 방식으로 변경을 지시했다. 이후 사용자가 해당 버전 고정과 Stage 2 진행을 승인했다. 고정본은 `build.noindex/task555/approved-ui/`의 6개 파일과 `sha256.json`으로 보존하며 Stage 3에서 이 화면을 구현한다. 시안 승인은 Stage 3 소스 구현 완료를 의미하지 않는다.
- `docs/index.html`: 제품 소개·FAQ·철학 설명 다음, 푸터 바로 위에 ‘최신 소식’과 최신 글 1개, ‘소식 더 보기’ 링크를 배치한다. 글의 전체 높이를 표시하고 높이 제한·내부 스크롤·스크롤 안내 문구를 두지 않는다.
- `docs/news/index.html`: 최신순 한 열과 전체 페이지 스크롤. 처음 5개를 표시하고 목록 끝 약 700px 전에 다음 5개를 추가한다. 마지막 묶음은 남은 개수만 표시한다. 연속·중복 로딩을 방지하고 초기 임베드의 높이가 잡히기 전에 전체 목록을 한꺼번에 추가하지 않는다. 자동 감지를 사용할 수 없는 경우의 ‘소식 더 불러오기’ 버튼, 키보드 포커스와 마지막 상태 안내를 처리한다.
- `docs/news.js`: 같은 origin의 명시적 상대 JSON URL을 읽고 스키마 2·유효기간·원문 URL을 검증한다. 허용한 DOM 컨테이너를 만들고 공식 script를 한 번만 로드한다. 5개 단위는 공개 참조 목록에서 임베드를 추가하는 단위이며 방문자 브라우저에서 인증 API를 호출하는 방식이 아니다. 로컬 시안에서 공식 `embed.js`의 `window.instgrm.Embeds.process()`로 동적 추가를 확인했다. 각 blockquote에 고유 ID를 부여해 공식 SDK가 로딩 자리 표시자를 제거할 수 있게 한다. Stage 3에서 실패·재시도와 연속 페이지 경계까지 검증한다.
- `docs/styles.css`: `.news-*` 범위에서 공식 최소 너비 320px을 고려한 반응형 배치. 본문·미디어·날짜의 내부 스타일은 공식 iframe에 맡긴다. 320px viewport에서는 불필요한 바깥 여백을 줄인다.
- 로딩 표시: 카드의 로딩 문구를 프로필 원·본문 줄·미디어 자리·하단 정보로 구성한 스켈레톤으로 대체하고 은은한 밝기 흐름 애니메이션을 적용한다. 실제 임베드가 준비되면 스켈레톤은 약 220ms 동안 사라지고 글은 약 320ms 동안 나타나며 6px 위로 정착한다. 카드 높이도 실제 글 높이로 전환하고 완료 후 높이 고정을 해제한다. 동작 줄이기 설정에서는 즉시 교체하며 실패 시 복구 문구로 전환한다. 목록 하단의 추가 로딩은 작은 원형 표시를 사용한다. 화면 읽기용 로딩 설명과 동작 줄이기 설정을 지원한다. 카드 클릭 시 iframe 바깥에 생기는 파란 외곽선은 제거한다.
- 홈·업데이트 목록·문의·소식 내비게이션에 ‘최신 소식’ 연결. 기존 다운로드·업데이트·복사 기능 보존.

유효기간이 지난 데이터는 임베드를 새로 로드하지 않고 갱신 지연과 프로필 링크를 표시한다. 정상 빈 상태, JSON 오류·재시도, script 차단·timeout, unavailable embed, JavaScript 비활성을 구분한다. cross-origin iframe 내용을 읽어 개별 글의 성공 여부를 단정하지 않는다. 정상 표시에서는 공식 임베드에 내장된 ‘Threads에서 보기’를 사용하고 글 하단의 별도 원문 버튼은 두지 않는다. 로딩 실패·비활성 상태의 복구 안내는 정상 표시와 분리한다. 공식 임베드가 외부 Threads 요청을 수행한다는 점은 기존 개인정보 안내와 함께 공개 전에 반영한다.

### 검증과 종료

- 프로젝트 하위 URL에서 1440/768/390/320px, Tab/Enter/Space, JSON 0/1/5/6/10/11개, 하단 도달 전 자동 로딩·수동 추가·중복 방지·마지막 묶음, script 중복·실패·재시도·만료 상태를 확인한다. 홈 글의 전체 높이, 전체 목록의 페이지 스크롤과 중복 원문 버튼 부재도 확인한다.
- 실제 글 6개를 로컬 표시하고 공식 iframe과 원문 대응을 확인한다. fixture는 공개하지 않는다.
- `node --check docs/news.js`, `git diff --check` 및 기존 홈·업데이트·문의 화면 회귀 확인.
- 커밋: `Task #555 Stage 3: 제품 페이지 Threads 소식 임베드와 목록 추가` + 단계 보고서.

## 5. Stage 4 — Pages 통합과 운영 검증

### 변경 파일과 작업

- `scripts/ci/prepare-news-data.py`: 비활성 seed/활성 fresh snapshot의 진입점. 과거 Git 데이터와 artifact를 가져오지 않는다.
- fresh 조립 기준: 생성 후 15분 이내·미만료 snapshot만 허용한다. 활성인데 입력이 없으면 실패하며 비활성은 코드가 생성한 빈 초기값만 배치한다. 브라우저 표시 기한 48시간과 조립 시 신선도 검사를 구분한다.
- `scripts/ci/prepare-pages-artifact.sh`: `--news-data`의 검증된 파일을 `data/news.json`에 배치한다. 네트워크 호출은 조립 밖에서 끝낸다. 기존 appcast 처리 보존.
- `.github/workflows/pages-docs-deploy.yml`: `workflow_call`을 추가하고 `pages-deploy` 잠금 안에서 fresh snapshot 생성과 현 공개 appcast 보존을 연결한다. secret은 조회 step에만 전달하고 업로드·배포에는 전달하지 않는다.
- `.github/workflows/threads-news-sync.yml`: main의 재사용 Pages workflow 호출을 연결한다. 수집 실패 시 배포하지 않으며 다음 실행은 fresh 생성부터 재시도한다. 서로 같은 잠금을 잡고 호출하는 교착을 만들지 않는다.
- `.github/workflows/release-promote.yml`: 뉴스 표시가 활성화된 경우 release 부작용 전에 fresh 조회를 검증한다. Pages snapshot만 삽입하고 release 증빙에는 원문 참조를 포함하지 않는다. 공통 잠금·기존 DMG 승격·서명 규칙 유지.
- 뉴스 포함 Pages artifact 보존 1일과 삭제 요청 시 재배포/해당 artifact 삭제 절차. 기존 DMG·release 증빙 보존 기간은 유지.
- `.github/workflows/pr-ci.yml`: 새 fixture 검증 연결. `scripts/ci/**` 변경에 적용되는 기존 release checks도 유지한다.
- `mydocs/manual/threads_news_operation_guide.md`: 계정 연결, 토큰 갱신·만료, 6시간 주기와 48시간 표시 기한, API 사용 목적 확인, 원문 부재·제외·중단·artifact 삭제·복구 절차를 문서화한다.

### 통합 검증

1. docs-only와 release 조립에 같은 fresh fixture를 넣어 같은 JSON인지 비교한다. 활성인데 input 부재·만료·스키마 오류이면 조립이 실패해야 한다.
2. API/oEmbed/조립/배포 실패를 주입하고 기존 공개 파일을 덮지 않음을 확인한다. 재시도는 기존 snapshot을 재사용하지 않고 현재 목록을 읽는다.
3. 공통 잠금, main 실행 기준, secret 전달 단계, Pages artifact 1일과 release 증빙 분리를 검증한다.
4. 최신 공개 appcast를 읽고 `build.noindex/task555/pages-artifact/`를 조립하여 appcast 입력/출력 bytes·SHA256을 비교한다. release 경로는 synthetic appcast로 로컬 검증한다.
5. 최종 조립의 홈·소식·업데이트·문의·다운로드·복사 동작, 실제 임베드 6개를 확인한다. 전체 사용 목적 확인은 기술 테스트와 별도 결과로 보고한다.

예정 명령:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-threads-news.py
node --check docs/news.js
bash -n scripts/ci/prepare-pages-artifact.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
scripts/ci/classify-pr-changes.sh origin/devel HEAD
scripts/ci/check-main-devel-content.sh origin/main HEAD
git diff --check
```

- 커밋: `Task #555 Stage 4: 임베드 소식 Pages 통합과 운영 검증` + 단계 보고서.

## 6. 단계 보고·최종 보고·공개 활성화

- 각 단계의 소스와 보고서를 묶어 커밋하고 다음 단계 승인을 받는다. Stage 1~4의 구현·검증 근거와 실제 공개 활성화 여부를 구분하여 보고한다.
- 모든 단계 검증 후 최종 보고서와 오늘할일을 갱신하고 승인된 절차에 따라 `publish/task555` → `devel` Open PR을 만든다.
- 공개 활성화 전: API 사용 목적의 허용 범위 확인, 실제 토큰 만료 확인과 secret 등록, main에 호환 소스 반영, 개인정보 안내, 중단·삭제·재배포 절차 검증을 마친다. 그 후 `NEWS_DATA_ENABLED` 활성화와 최초 수동 배포, 마지막으로 `THREADS_NEWS_ENABLED` 예약 실행 활성화를 승인받는다.
- 전체 사용 사례에 대한 Meta의 별도 확인은 아직 없다. 기술 검증 결과나 개발 진행 지시가 Meta의 정책 승인을 대신하지 않는다. 원격 서비스는 비활성 상태로 구현·검증하며 확인 결과가 달라지면 공개 활성화 전에 범위를 보정한다.
- 기존 앱 계정 연결 승인은 유지한다. 정책 확인을 위해 다른 사람에게 문의 메시지를 보내거나 앱 검수 서류를 제출할 경우 별도 명시 지시를 받는다.
- 연결 철회·삭제 요청은 즉시 수집 중단 후 빈 소식 표시 배포와 관련 artifact 제거로 처리한다. API 실패만으로 앱 릴리스나 다른 사용자 데이터를 삭제하지 않는다.

## 7. 근거 자료와 승인 요청

- [Meta oEmbed 안내](https://developers.facebook.com/documentation/threads/tools-and-resources/embed-a-threads-post), [oEmbed 참조](https://developers.facebook.com/documentation/threads/reference/oembed): 외부 웹사이트 표시·자동 임베드와 사용 제한. 예시 및 대상 6개를 인증 없이 실측했다.
- [Meta 권한 참조](https://developers.facebook.com/docs/permissions/): `threads_basic`의 본인 표시 용도와 기타 조회 권한의 목적을 구분한다.
- [GitHub Pages artifact](https://github.com/actions/upload-pages-artifact), [artifact 제거](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts): 1일 보존 설정과 명시 제거 절차.
- [수행계획서](task_m010_555.md), [Stage 1 조사 기록](../tech/task_m010_555.md).

승인 요청: 위 보정안(링크 전용 스키마 2, Threads 원본에서 매번 재생성, 6시간 갱신·48시간 표시 기한, 공식 임베드, 공개 활성화 조건 분리)을 수용하고 Stage 2 구현으로 진행한다.
