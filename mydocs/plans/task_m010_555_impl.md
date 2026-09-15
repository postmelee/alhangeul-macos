# Task M010 #555 구현계획서

## 작업 개요와 승인 상태

- 이슈: [#555 — 제품 페이지에 Threads 알한글 소식 수집과 카드 아카이브 추가](https://github.com/postmelee/alhangeul-macos/issues/555)
- 마일스톤: `v0.1` / M010
- 수행계획서: [task_m010_555.md](task_m010_555.md)
- 작업 경로: `/Users/melee/Documents/projects/rhwp-mac`
- 작업 브랜치: `local/task555` → `publish/task555` → `devel`
- 시작 기준: `c0b0468c6dbfdfd2f3e3d1d9c5ccf993e7bd8a3b`, 수행계획 커밋: `8a44fc1`
- 수행계획 승인: 2026-09-15 같은 스레드의 “진행해줘.” 지시.
- 현재 단계: 구현계획서 작성 완료, 승인 대기. Stage 1의 실제 API 검증과 소스 구현은 아직 시작하지 않았다.

아래 API 필드·권한·조회 범위는 실제 계정에서 검증해야 할 계약이다. Stage 1에서 지원되지 않는 조건이 발견되면 결과와 수정안을 제시하고 단계 계획을 보정한다. 검증하지 않은 기능을 지원한다고 가정해 후속 구현을 시작하지 않는다.

## 1. 구현 계약

### 수집 대상

- 인증된 계정의 ID와 사용자명이 `@postmelee`와 일치하는지 확인한다. 고정 계정 ID를 운영 설정에 저장하고 이후에는 이름만으로 계정 동일성을 판단하지 않는다.
- 본인 게시물 목록에서 실제 주제 태그가 `알한글`인 원문을 선택한다. 태그는 Unicode NFC와 앞뒤 공백만 정규화하며 본문 검색으로 대체하지 않는다.
- 다른 계정 글, 단순 재게시물, 답글은 제외한다. 본인이 새로 작성한 인용 게시물은 본인 작성 부분과 주제 태그가 조건을 충족할 때 포함하고 인용 원문 내용을 복제하지 않는다.
- `topic_tag`, 작성자 정보, 재게시·답글·인용 구분 필드의 실제 제공 여부를 Stage 1에서 확인한다. 미반환 필드를 거짓으로 단정하거나 본문으로 추정하지 않는다.
- 글의 게시 시각을 기준으로 최신순 정렬하고, 같은 시각은 원문 ID로 안정적으로 정렬한다.

### 공통 공개 데이터

공개 JSON의 초기 경로는 `docs/data/news.json`, 런타임 스키마 버전은 1이다. 실제 글의 데이터를 계획서에 예시로 꾸며 넣지 않는다.

| 필드 | 형식과 용도 |
|---|---|
| `schema_version` | 정수 1. 수집기·페이지·배포 검증기의 계약 |
| `updated_at` | 현재 표시 데이터가 바뀐 UTC 시각. 매 실행마다 바꾸지 않는다. |
| `items` | 아래 게시물의 배열. 초기 미연결 상태에는 빈 배열 허용 |
| 게시물 `platform`, `id` | 초기 플랫폼 `threads`, ID는 문자열. 두 값의 조합으로 중복 제거 |
| `author.id`, `author.username` | 검증된 작성자. 숫자 ID도 문자열로 보존 |
| `text`, `published_at`, `topic_tag` | 본인 본문, ISO 8601 UTC 시각, 실제 주제 태그 |
| `permalink` | API가 반환한 HTTPS 정규 원문 링크. 공유 단축 링크를 원문 ID로 쓰지 않음 |
| `media` | 종류·HTTPS URL·대체 텍스트·썸네일 정보의 배열. 사용 가능한 값만 허용 |
| `synced_at` | 해당 게시물의 내용·미디어 등 공개 데이터가 갱신된 수집 시각 |

호출 상태와 전체 수집 시각·조회 범위·만료 예정일은 별도 `state.json`의 비밀이 아닌 운영 메타데이터로 관리한다. 토큰, 갱신 응답, 원본 API 응답, 인증이 담긴 페이지네이션 URL은 공개 JSON·상태 파일·artifact에 저장하지 않는다. 성공했지만 내용 변화가 없을 때 사이트 데이터는 유지하고 운영 상태만 갱신한다.

### 저장과 배포

1. 영속 원천은 소스 브랜치와 분리한 `data/news` 운영 브랜치로 제안한다. `news.json`, 비밀이 아닌 `state.json`, 짧은 역할 안내만 보관하고 실행 코드는 두지 않는다. 이 브랜치는 임시 `local/task555`/`publish/task555`와 달리 운영 중 유지한다. 실제 원격 생성은 공개 운영 활성화 승인 후 수행한다.
2. 수집기는 검증한 후보 데이터를 임시 파일에 쓴 뒤 파일을 교체한다. 운영 브랜치 갱신은 기대한 이전 SHA가 유지될 때만 fast-forward하고 강제 push는 사용하지 않는다. 충돌 시 재조회·재검증하며 소스 브랜치에는 직접 쓰지 않는다.
3. 사이트 소스의 `docs/data/news.json`은 스키마가 맞는 빈 초기값이다. `NEWS_DATA_ENABLED=true`로 데이터 표시를 활성화한 후 Pages 조립 시 `data/news`를 한 번 commit SHA로 고정하고 검증한 `news.json`으로 덮어쓴다. 활성화 상태에서 원천 조회 실패·파일 누락·스키마 오류가 나면 배포를 중단한다. 소스의 빈 초기값으로 대체해 공개 소식이 사라지게 하지 않는다.
4. 홈과 전체 목록은 같은 출처의 상대 URL로 JSON을 읽는다. 브라우저의 GitHub/Threads 인증이나 교차 출처 API 호출은 필요하지 않다.
5. docs-only 배포, 정기 수집 후 배포, 앞으로의 release 배포에 같은 데이터 조립 helper를 연결한다. `pages-deploy` 잠금 안에서 최신 데이터 SHA를 읽어 순서가 뒤집힌 실행이 오래된 소식을 다시 게시하지 않게 한다.
6. Git 이력은 이전 공개 본문을 보존할 수 있다. 원문 삭제 반영은 현재 표시 데이터에서 제거하는 것을 뜻하며 과거 Git 이력에서의 영구 삭제를 뜻하지 않는다. Stage 1에서 플랫폼 데이터 보관 조건과 이 방식의 적합성을 확인하고 맞지 않으면 저장 방식을 변경하도록 승인을 받는다.

### 정기 수집과 토큰 운영

- 실행 코드는 검토·병합된 `main`에서 사용한다. 초기 간격은 6시간, GitHub Actions 예약식 후보는 `17 */6 * * *`다. 실행 시각은 서비스 사정으로 지연될 수 있으므로 화면에 즉시 반영을 약속하지 않는다.
- 새 `threads-news-sync.yml`은 수동 실행과 예약 실행을 지원한다. 저장소 변수 `THREADS_NEWS_ENABLED=true`일 때만 원격 수집·데이터 갱신을 허용한다. 변수 미설정은 비활성이다. 이 타스크의 로컬 구현으로 운영이 자동 활성화되지 않는다.
- secret 후보는 `THREADS_ACCESS_TOKEN`, 비밀이 아닌 설정은 계정 ID·사용자명·태그·토큰 만료 시각이다. 초기 Meta 앱과 인증은 운영자가 연결하고 최소 조회 권한을 실제 응답으로 확인한다.
- MVP에서는 운영자가 만료 전에 갱신 helper를 실행해 새 토큰을 GitHub Actions secret에 다시 저장한다. helper는 토큰을 터미널 인자·표준 출력에 노출하지 않고, 숨김 입력 또는 보호된 파일로 받아 검증 후 인증된 `gh secret set`의 표준 입력으로 전달하는 경로를 제공한다. 토큰 수명은 실제 인증 응답을 기준으로 기록한다.
- 주기 작업이 token secret을 자동으로 다시 쓰도록 별도 관리자 자격 증명이나 기존 GitHub App의 권한 확대를 도입하지 않는다. 운영 상태에서 만료 14일 전부터 갱신 필요를 알리고 실패 상태를 통해 운영자가 알 수 있게 한다. 이 안내가 떠도 아직 유효한 토큰으로 성공한 수집은 보존한다. 만료·철회 후에는 재인증이 필요하다.
- 정기 작업에는 `contents: write`를 데이터 저장 job에만 부여한다. Pages 실행 job에만 필요한 Pages 권한을 부여하고 Threads secret을 전달하지 않는다. 기존 release secret을 수집 workflow에 전달하지 않는다.
- 수집은 `threads-news-sync`, 배포는 `pages-deploy`로 직렬화한다. 동일 잠금을 가진 호출 workflow와 호출된 workflow가 서로 기다리지 않도록 배포 잠금은 기존 Pages workflow가 소유한다.
- 원격 변경에 따른 push 이벤트의 재실행에 의존하지 않고 기존 Pages workflow를 `workflow_call`로 재사용한다. 수집 결과가 바뀌었거나 이전 데이터 저장 후 배포가 실패한 경우 재배포한다. 마지막으로 배포한 `news.json`의 SHA-256과 현재 내용 hash를 비교해 재시도한다. 상태 파일 커밋으로 바뀌는 branch commit SHA를 데이터 변경 기준으로 사용하지 않는다. 재사용 workflow는 실제 조립한 데이터 hash를 반환하고 그 값만 성공 상태에 기록한다.

## 2. Stage 1 — API·계정 검증과 데이터 계약 확정

### 변경 파일과 작업

- 신규 `scripts/ci/threads-news.py`: `probe`와 `validate` 진입점, 최소 API client와 데이터 검증 계약을 만든다. Python 표준 라이브러리를 우선 사용하고 외부 라이브러리가 필요하면 이유와 고정 버전을 기록한다.
- 신규 `scripts/ci/fixtures/threads-news/`: 실제 응답 구조에서 인증 정보·무관한 글을 제거한 구조 fixture와 판정용 synthetic 데이터를 구분한다. 사용자 게시물 전문이 들어간 raw 응답은 커밋하지 않는다.
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
- 실제 예시 글 포함과 비대상 글 제외를 확인하고 `validate`가 잘못된 필드·URL·시각을 거부하는지 확인한다.
- 계정 미연결이나 태그 판별 불가 상태에서는 Stage 1을 완료하지 않는다. 독립적으로 가능한 문서 조사와 fixture 작업까지만 수행하고 필요한 연결 동작을 알린다.
- 단계 보고서를 산출물과 함께 커밋: `Task #555 Stage 1: Threads 조회와 소식 데이터 계약 검증`.

## 3. Stage 2 — 수집·동기화와 운영 경로 구현

### 변경 파일과 작업

- `scripts/ci/threads-news.py`: `sync`, 토큰 갱신 및 운영 상태 검사 진입점을 추가한다. API client, 정규화, 병합, JSON 검증을 구분한다.
- 신규 `scripts/ci/test-threads-news.py` 및 관련 fixture: 데이터 보존·오류·대상 판정 검증.
- 신규 `.github/workflows/threads-news-sync.yml`: 비활성 기본값, 6시간 예약, 수동 dry-run, 데이터 SHA 확인·저장, 비밀 없는 실행 결과를 구성한다. Pages 호출은 Stage 4에서 연결한다.
- 신규 `docs/data/news.json`: 스키마 버전 1의 빈 초기 데이터. 초기 실제 계정 수집은 `build.noindex/task555/`에 저장해 검증한다.

### 동기화 알고리즘

1. 입력 JSON과 계정 identity를 검증하고 요청당 timeout, 전체 실행 시간·페이지·레코드·응답 크기의 상한을 둔다. 상한 도달은 완전 수집 성공이 아니다.
2. 허용한 API host와 endpoint만 호출한다. 페이지네이션 cursor로 요청을 재구성하며 응답의 임의 URL을 인증 토큰과 함께 따라가지 않는다. 반복 cursor를 오류로 처리한다.
3. API가 보장하는 범위의 본인 게시물을 모두 읽고 필터링한다. 최근 목록에 없는 기존 저장 글은 개별 재조회로 보완한다. 계정 규모상 이 방법이 호출 제한을 초과하면 Stage 1 근거로 증분·전체 재검증 주기를 보정한다.
4. 본인 글의 태그 제거가 확인되면 현재 목록에서 제거한다. 조회 불가를 삭제로 확정하지 않는다. 삭제가 확실하지 않은 기존 글은 보존하고 상태를 기록한다. 일반 오류 코드로 여러 상태가 섞여 있으면 운영자가 원문을 확인해 명시적으로 제외하는 관리 입력을 제공한다.
5. 조회·검증이 완전히 성공하면 내용 변경·새 글·확인된 제외를 병합해 임시 파일에 쓴다. 오류가 있으면 정상 데이터의 bytes를 유지하고 상태를 실패로 반환한다. 정상적으로 대상 글이 0개임을 확인한 경우는 오류와 구분한다.
6. 429와 일시적 5xx에는 상한이 있는 재시도를 적용하고 `Retry-After`를 존중한다. 인증·권한 오류는 반복 재시도하지 않는다. 예외 메시지에 요청 URL·헤더·응답 전문을 노출하지 않는다.

### 검증과 종료

- `python3 scripts/ci/test-threads-news.py`: 필터링, NFC, 정렬·중복, 전체 페이지, 반복 cursor, 부분 오류, timeout/429, 토큰 만료, 정상 빈 결과, 태그 제거, 불확실한 삭제, 잘못된 계정과 URL, 크기 제한을 검증한다.
- 실패 시 기존 데이터 bytes 불변, 재시도 시 중복 없음, 내용 무변경 시 공개 파일 무변경, 데이터 브랜치 SHA 충돌 시 강제 덮어쓰기 없음, 토큰 갱신 저장 실패 시 성공으로 보고하지 않음을 검증한다.
- 운영 Git 저장은 임시 로컬 저장소로 검증하고 GitHub 예약 실행·secret 값 등록·원격 데이터 브랜치 생성은 활성화 승인 전 실행하지 않는다.
- 실제 계정으로 초기 수집과 두 번째 수집을 로컬 실행하고 fixture 성공과 분리해 기록한다.
- 커밋: `Task #555 Stage 2: Threads 소식 수집과 동기화 구현` + `mydocs/working/task_m010_555_stage2.md`.

## 4. Stage 3 — 홈 소식 카드와 전체 목록

### 변경 파일과 화면

- `docs/index.html`: 기능 소개 다음, FAQ 이전에 “알한글 소식” 영역을 넣고 최신 3개·“소식 모두 보기”를 제공한다.
- 신규 `docs/news/index.html`: “알한글 소식” 제목, 짧은 소개, 최신순 목록. 처음 12개를 표시하고 “더 보기”로 12개씩 추가한다. 버튼 포커스를 잃지 않게 하고 추가 개수를 상태 영역에 알린다.
- 신규 `docs/news.js`: 홈과 전체 목록에서 데이터 로딩·스키마 검증·안전한 카드 렌더링을 공유한다. `textContent`/DOM API를 사용하고 외부 본문을 HTML로 삽입하지 않는다. 코드 분기에서 파일 경로를 추정하지 않고 페이지가 명시한 상대 데이터 URL을 사용한다.
- `docs/styles.css`: `.news-*` 범위의 스타일, 화면 폭에 따른 3/2/1열, 긴 단어 줄바꿈과 가시적인 포커스. 새로운 모션 기능은 추가하지 않는다.
- 홈·업데이트 목록·문의·소식 페이지의 헤더에 “소식” 링크를 연결한다. 과거 릴리스 본문과 다운로드 주소는 이 작업에서 변경하지 않는다.

카드에는 작성자·Threads 표시·한국어 날짜, 최대 240자 정도의 본문 미리보기, 대표 이미지 1개 또는 동영상 썸네일, “Threads에서 원문 보기”를 둔다. 날짜는 `Asia/Seoul`로 표시하고 `<time datetime>`에는 원본 시각을 둔다. 이미지 추가 수가 있으면 원문에서 더 볼 수 있음을 표시하고 동영상을 자동 재생하지 않는다. 썸네일을 얻지 못하면 텍스트 카드로 표시한다.

정상 빈 데이터는 “아직 등록된 소식이 없습니다”, 조회 실패는 “소식을 불러오지 못했습니다”와 재시도·Threads 프로필 링크를 제공한다. JavaScript 비활성 시에는 정적 안내와 프로필 링크를 남긴다. 이미지 오류는 카드 본문과 원문 링크를 유지한다. 키보드 포커스와 상태 안내는 네이티브 버튼·링크 및 적절한 live region으로 제공한다.

### 검증과 종료

- 로컬 정적 서버의 `/alhangeul-macos/` 하위 경로에서 홈과 소식을 함께 확인한다. 실제 미리보기 URL을 사용자에게 제공한다.
- 1440px·768px·390px·320px에서 카드·헤더·더 보기·긴 텍스트·본문 빈 이미지 글·이미지 실패를 점검하고 전후 화면을 기록한다.
- 0/1/3/13개 이상의 fixture로 홈 개수와 목록 추가, 마지막 버튼 상태를 검증한다. 가짜 글 fixture는 로컬 검증에만 사용한다.
- 상대 URL·미디어·원문 링크, 네트워크 오류·재시도, 키보드 Tab/Enter/Space, 날짜, 가로 넘침, 콘솔 오류와 악성 문자열의 비실행을 확인한다.
- `node --check docs/news.js`, `git diff --check` 및 공통 CSS가 적용되는 기존 화면을 확인한다.
- 커밋: `Task #555 Stage 3: 제품 페이지 소식 카드와 전체 목록 추가` + `mydocs/working/task_m010_555_stage3.md`.

## 5. Stage 4 — Pages 통합·운영 안내·회귀 검증

### 변경 파일과 작업

- 신규 `scripts/ci/prepare-news-data.py`: 운영 브랜치를 SHA로 고정해 읽고 데이터 검증 후 로컬 파일로 제공한다. 운영 활성화 상태와 개발용 비활성 상태를 명시 입력으로 구분한다.
- `scripts/ci/prepare-pages-artifact.sh`: 선택 입력 `--news-data`를 추가해 검증된 파일을 조립 결과의 `data/news.json`에 배치한다. 기존 appcast 처리와 소스 파일은 유지한다. 외부 API 호출은 조립 helper 밖에서 수행한다.
- `.github/workflows/pages-docs-deploy.yml`: 기존 수동/main push 진입점을 유지하면서 `workflow_call`을 추가하고, 같은 잠금 범위 안에서 운영 데이터 로딩을 연결한다. 기존 공개 appcast의 다운로드·XML 검증·보존을 유지한다.
- `.github/workflows/threads-news-sync.yml`: 데이터 반영 후 재사용 Pages workflow 호출과 성공/실패 상태 기록을 연결한다. 호출 job과 수집 job의 권한을 구분한다.
- `.github/workflows/release-promote.yml`: 기존 검증·동일 DMG 승격·서명 로직은 유지하며 Pages 조립 직전 최신 소식 데이터 입력만 추가한다. 비활성 상태의 기존 release helper 검증도 통과해야 한다.
- `scripts/ci/test-threads-news.py`: 데이터 원천·조립·오류·배포 재시도 검증을 확장한다. `.github/workflows/pr-ci.yml`에 이 fixture 검사를 연결한다. `scripts/ci/`와 workflow는 기존 분류상 release checks 대상이므로 불필요한 앱 빌드 예외를 새로 만들지 않는다.
- 신규 `mydocs/manual/threads_news_operation_guide.md`: 초기 연결, 수동 토큰 갱신, 수집 주기·범위, 삭제 판별 한계, 데이터 제외, 실패 복구, 활성화/중단/배포 재시도를 설명한다. 기존 CI·Pages 가이드에는 역할과 링크만 필요한 만큼 추가한다.

### 통합 검증

1. 임시 Git 저장소에서 최신 데이터 commit을 만든 뒤 docs-only와 release 조립을 각각 실행해 같은 `data/news.json`이 나오는지 비교한다.
2. 활성 상태의 데이터 branch/file 부재, API 오류, 스키마 오류는 배포 준비 실패로 끝나고 기존 공개 데이터 대체를 만들지 않아야 한다.
3. 소식 저장 성공 후 배포 실패를 주입하고 다음 실행에서 내용 변경이 없어도 미반영 내용 hash를 재배포하는지 확인한다. 상태 기록 충돌은 재조회로 처리한다. 상태만 바뀐 커밋으로 무한 재배포가 발생하지 않는지도 확인한다.
4. release와 docs-only 경로의 배포 직렬화, 데이터 읽기 위치, 실제 사용하는 workflow/helper 버전을 확인한다. 이 기능이 없는 과거 tag의 workflow 재실행은 소식을 보존한다고 보장할 수 없으므로 최신 호환 배포 도구를 사용하는 복구 절차를 명시한다.
5. 당시 공개 appcast를 새로 내려받아 XML 검증 후 `build.noindex/task555/pages-artifact/`를 조립하고 입력/출력 appcast bytes·SHA256 일치를 확인한다. release 경로는 별도 synthetic appcast로 helper 동작만 확인하며 공개 feed를 생성·게시하지 않는다.
6. 조립 결과로 로컬 미리보기를 실행해 실제 소식 카드, 전체 목록, 더 보기, 다운로드·업데이트·문의·복사 버튼을 확인한다.

예정 검증 명령(구현 전이며 통과 결과가 아님):

```sh
python3 scripts/ci/test-threads-news.py
node --check docs/news.js
bash -n scripts/ci/prepare-pages-artifact.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
scripts/ci/classify-pr-changes.sh origin/devel HEAD
scripts/ci/check-main-devel-content.sh origin/main HEAD
git diff --check
```

Pages 조립은 단계에서 확보한 `public-appcast.xml`과 검증된 `news.json`을 명시 입력으로 사용하며 `cmp`로 두 결과 파일을 대조한다. fixture 외부 네트워크 오류와 인증 문제를 제품 성공으로 기록하지 않는다. 변경에 해당하는 기존 release helper dry-run은 PR CI와 같은 입력으로 실행한다.

- 커밋: `Task #555 Stage 4: 소식 Pages 통합과 운영 검증 정리` + `mydocs/working/task_m010_555_stage4.md`.

## 6. 단계 보고·최종 보고·운영 활성화

- 각 단계 보고서는 해당 소스와 함께 커밋하며 승인 후 다음 단계로 진행한다. 계획과 실제 API 조건이 다르면 보고서만으로 범위를 바꾸지 않고 구현계획을 보정한다.
- Stage 4 승인 후 `mydocs/report/task_m010_555_report.md`에 실제 API/fixture/로컬 화면/조립 검증과 남은 운영 절차를 구분해 작성한다. 오늘할일 갱신 및 최종 보고 승인 후 `publish/task555`로 게시하고 `devel` 대상 Open PR을 만든다.
- 실제 계정 연결·원격 데이터 브랜치 생성·secret 등록·자동 수집 활성화·main 반영과 Pages 배포는 구체적인 설정과 결과물을 제시한 뒤 운영 승인 범위에 따라 실행한다. 이번 구현계획 승인만으로 공개 서비스를 활성화하지 않는다.
- 공개 활성화 순서는 최초 실제 데이터 검증 → 데이터 원천 준비 → 인증·만료 정보 등록 → `NEWS_DATA_ENABLED=true` 설정 → 호환 소스 main 반영 및 최초 Pages 배포 → `THREADS_NEWS_ENABLED=true` 설정 및 수동 통합 실행 → 예약 실행 결과 확인이다. 실행 전 각 배포 진입점이 최신 helper를 사용하는지 확인하고 실제 데이터가 표시되는 수동 통합 실행까지 완료한 후 공개 운영 완료로 보고한다.
- 중단 시 예약 수집의 `THREADS_NEWS_ENABLED`만 비활성화하고 데이터 표시의 `NEWS_DATA_ENABLED`는 유지한다. 두 설정을 분리해 수집 중단이 빈 목록 배포로 이어지지 않게 한다.
- 실패 상태·만료 갱신 필요는 workflow 결과로 알리고 별도의 이메일·메시지를 자동 전송하지 않는다.

## 7. 근거 자료와 승인 요청

- [Meta Threads 공식 API·인증 안내](https://www.postman.com/meta/threads/documentation/dht3nzz/threads-api?entity=folder-34203612-50c60b6d-a653-4334-8ceb-223dd1e63d44): 앱 생성·사용자 인증·토큰 교환/갱신 기능을 확인. 실제 본인 조회 권한과 필드는 Stage 1에서 검증한다.
- [GitHub 재사용 workflow](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows), [GITHUB_TOKEN](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token): 호출 구조와 job별 권한 설계의 기준. 예약 실행과 배포는 기존 저장소 workflow 정책을 함께 따른다.
- 저장소 기준: `mydocs/manual/task_workflow_guide.md`, `git_workflow_guide.md`, `ci_workflow_guide.md`, `release_github_pages_sparkle_guide.md`.

승인 요청은 위 4단계 구현계획과 Stage 1 진입이다. 특히 `data/news`의 영속 데이터 분리, 6시간 주기, 운영자의 만료 전 토큰 갱신, 홈 3개·목록 12개 단위 표시를 기본안으로 둔다. 계정 실측 또는 플랫폼 조건에 따라 필요한 변경은 Stage 1 결과로 다시 제시한다.
