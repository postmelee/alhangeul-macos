# Task M010 #555 Stage 2 — 자동 수집과 snapshot 생성

- 작성일: 2026-09-15
- 이슈: [#555](https://github.com/postmelee/alhangeul-macos/issues/555)
- 작업 브랜치: `local/task555`, 통합 대상: `devel`
- 상태: **Stage 2 구현·검증 완료. Stage 3 진입 승인 요청.**
- 관련 문서: [수행계획](../plans/task_m010_555.md), [구현계획](../plans/task_m010_555_impl.md), [Stage 1](task_m010_555_stage1.md), [API 계약](../tech/task_m010_555.md)

## 1. 승인과 화면 기준 고정

작업지시자가 “확인했어. 이 버전으로 고정하고 Stage 2 자동 수집 구현으로 진행해줘.”라고 지시했다. 자동 선별·공식 임베드·실행별 snapshot 보정안에 따라 Stage 2를 진행했다. API 사용 목적 확인 등 공개 활성화 전 조건은 유지한다.

승인 화면은 홈 하단 최신 글 1개 전체 높이 표시, ‘최신 소식’ 내비게이션, 전체 목록 한 열·페이지 스크롤, 5개씩 하단 접근 전 자동 추가, 중복 원문 링크 제거, 클릭 외곽선 제거, 하단 원형 로딩, 카드 스켈레톤과 전환 애니메이션이다. Stage 3은 이 기준으로 제품 페이지 소스를 구현한다.

로컬 고정본은 `build.noindex/task555/approved-ui/`에 HTML 2개, CSS 2개, JS 2개와 `sha256.json`으로 보존했다. 실링크가 포함된 시안은 Git에 넣지 않는다. 원본 미리보기는 `build.noindex/task555/stage1/layout/`에서 계속 확인할 수 있다. Stage 2에서 고정본·미리보기 화면을 변경하지 않았다.

- `news-preview.css` SHA-256: `f651484ed7f1eb759aa86dac9eb0f8a0fe2ec4b393bb56dc4fcd43bac159faff`
- `news-preview.js` SHA-256: `e3f89b6421b8c95bba81c72537c3288702c0760444275aadd217a6e1a1b0904a`

## 2. 구현 결과

| 산출물 | 구현 내용 |
|---|---|
| `scripts/ci/threads-news.py` | `sync`, 원자적 JSON 교체, 최소 필드·엄격한 분류, 제한된 재시도, 제외 목록, 만료 검사, 수동 토큰 교환/갱신 |
| `scripts/ci/test-threads-news.py` | 기존 22개와 Stage 2 21개를 합친 43개 검사 |
| `.github/workflows/threads-news-sync.yml` | 6시간 일정, 기본 비활성·main/본 저장소 제한, 수동 dry-run, 조회 step에만 토큰 전달 |
| `docs/data/news.json` | 스키마 2의 비활성 빈 초기값 |
| 계획서·오늘할일·기술 기록 | 화면 승인, Stage 2 진행/검증 상태, 다음 단계 인계 |

### 수집과 저장

1. 고정 계정 ID·사용자명을 확인한 뒤 현재 게시물을 완전 조회한다. 조회 필드는 12개이며 본문·미디어 URL·첨부·children은 요청하지 않는다.
2. 실제 `알한글` 주제 태그로 판정한다. 작성자·인용·원문을 확인할 수 없는 대상, 잘못된 cursor, 페이지 상한 도달, 중간 API 오류는 수집 실패다. 동일 ID의 동일 응답은 중복 제거하고 응답이 충돌하면 중단한다.
3. 최신순으로 정렬하고 같은 시각은 숫자 ID 역순으로 고정한다. 선택된 모든 원문의 공개 oEmbed를 인증 없이 확인한다. 본문·HTML은 저장하지 않는다.
4. 검증한 링크만 담은 JSON을 같은 디렉터리의 600 임시 파일에 쓰고 flush/fsync 후 원자적으로 교체한다. 교체 전 실패는 기존 파일의 bytes를 보존하고 임시 파일을 제거한다. 정상 0개는 갱신 시각이 있는 빈 결과로 저장한다.
5. 이전 snapshot과 병합하지 않으므로 미관찰·태그 제거된 글은 새 결과에서 빠진다. `--exclude-file`은 운영자가 명시한 정규 원문 URL 배열만 허용한다. 오류 글을 자동으로 무시하지 않는다.
6. 인증 client와 공개 oEmbed client는 분리한다. 운영 수집은 각 요청 최대 3회 시도, 한 번의 연결 timeout 최대 15초, client 생성부터 각각 300초 예산을 적용한다. 429/5xx와 연결 실패를 재시도하고 인증 오류는 반복하지 않는다. `Retry-After`의 초·HTTP 날짜를 해석하며 예산보다 긴 대기는 짧게 줄여 재요청하지 않고 실패한다.

`sync --dry-run`은 전체 조회·검증을 수행하지만 파일을 쓰지 않는다. 실제 토큰 만료 시각이 미확인인 로컬 조사에는 이 모드만 허용한다. 운영 저장은 확인된 만료 시각이 있어야 하며 수집 전과 저장 직전에 만료 여부를 확인한다.

### 토큰과 workflow

- `token-status`는 토큰 없이 기록된 UTC 만료 시각을 검사한다. 미확인·만료는 종료 코드 1이며 14일 이내 만료를 갱신 필요 상태로 표시한다.
- `refresh-token`은 마지막 발급/갱신 후 24시간 경과·미만료를 요구한다. `exchange-token`은 별도 보호 파일로 앱 secret을 읽는다. 기존 토큰을 덮어쓰지 않고 새 600 파일에만 결과 토큰을 저장하며, stdout은 발급·만료 시각 등 비밀 없는 메타데이터만 출력한다. GitHub secret 자동 교체는 없다.
- 두 토큰 명령은 synthetic 응답으로만 검증했다. 실제 토큰 갱신·교환이나 앱 secret 열람은 실행하지 않았다.
- workflow는 본 저장소의 `main`에서만 실행된다. schedule은 `THREADS_NEWS_ENABLED == 'true'`일 때만 진행하며 미설정이면 비활성이다. 수동 실행은 dry-run만 지원한다. Stage 2에서는 schedule도 dry-run이고 파일/Pages 업로드 step과 쓰기 권한은 없다.
- workflow의 `THREADS_EXPECTED_USER_ID`, `THREADS_TOKEN_EXPIRES_AT`는 repository variable, `THREADS_ACCESS_TOKEN`은 secret이다. workflow는 만료 시각 미설정이면 토큰을 사용하는 조회 step 전에 중단한다. 실제 원격 설정·실행은 하지 않았다.

## 3. 검증 결과

| 검증 | 결과 |
|---|---|
| fixture 테스트 | 43개 PASS: 기존 계약, 완전/부분 조회, 원자적 교체와 디스크 실패, 태그 제거·정상 빈 결과, 중복 충돌, 제외 목록, 만료 경계, 재시도와 비밀 경계, 수동 갱신/교환 |
| 신규 workflow | actionlint PASS, 기본 비활성·main/본 저장소 제한·조회 step의 secret 범위 정적 확인 |
| Python 구문·CLI help | PASS |
| 공개 초기 JSON | schema 2 / item_count 0 / 비활성 PASS |
| 실제 `sync --dry-run` | 7페이지·263개 조회·대상 6개·oEmbed 6개 PASS, 파일 저장·공개 배포 없음 |
| 실계정 수집 엔진·로컬 재생성 | 두 번 모두 7페이지·6개, 항목 동일·갱신 시각 변경, 원자적 교체 후 읽기 결과 동일 |
| 비밀·시안 보존 | 실제 토큰 bytes가 변경 산출물·고정 시안·검증 JSON에 없음, 고정본과 미리보기 SHA-256 동일 |
| `git diff --check` | PASS |

실제 dry-run에서 태그 분류는 대상 6, 다른 태그 97, 태그 없음 149, 재게시 11개로 Stage 1과 같았다. 실제 토큰 만료 시각은 미확인이므로 `token.status=unknown` 경고를 확인했다. API 호출 성공을 정확한 만료 시각 확인으로 대신하지 않았다.

실계정 파일 교체 검증은 `sync`와 같은 엄격한 `probe` 수집 엔진·최소 필드·oEmbed 검증과 `atomic_write`를 로컬 하네스에서 연결했다. 생성 시각은 `2026-09-15T09:45:29+00:00`, 재생성 시각은 `2026-09-15T09:45:37+00:00`이며 항목 배열은 동일했다. 최종 파일은 `build.noindex/task555/stage2/live-snapshot.json`이다. 이는 로컬 검증이며, 만료 시각이 필요한 운영 `sync` CLI 저장·GitHub 예약 실행의 실운영 검증으로 보고하지 않는다.

주요 검증 명령:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-threads-news.py
actionlint .github/workflows/threads-news-sync.yml
python3 scripts/ci/threads-news.py validate docs/data/news.json
python3 scripts/ci/threads-news.py sync --help
python3 scripts/ci/threads-news.py sync --token-file <보호된 토큰 파일> \
  --expected-user-id 29072097499042855 --dry-run
git diff --check
```

macOS 앱·Rust·기존 Pages 조립/릴리스 workflow는 변경하지 않았다. 기존 release helper 전체 회귀·PR CI 연결·실제 Pages 조립은 Stage 4에서 수행한다. 현재 결과를 전체 PR CI 통과로 표시하지 않는다.

## 4. 운영 명령과 남은 조건

확인된 만료 시각이 있을 때 로컬 수집 파일 생성:

```sh
mkdir -p build.noindex/task555/stage2
python3 scripts/ci/threads-news.py sync --token-file <보호된 토큰 파일> \
  --expected-user-id 29072097499042855 \
  --token-expires-at <발급 응답에 근거한 UTC 만료 시각> \
  --output build.noindex/task555/stage2/news.json
```

수동 갱신은 `refresh-token --help`, 단기 토큰 교환은 `exchange-token --help`를 참고한다. 출력 디렉터리는 본인 소유 700, 새 토큰 파일은 600이어야 한다. 실제 토큰 값은 명령행 인자나 문서·대화에 넣지 않는다. 갱신 결과의 만료 시각을 기록한 뒤 운영자가 repository secret/variable을 교체하는 절차는 공개 활성화 전에 검증한다.

다음 단계는 **Stage 3: 고정한 화면을 제품 페이지에 구현**이다. Stage 4의 Pages 연결, API 사용 목적 확인, 실제 토큰 만료·secret 설정, 개인정보·중단/삭제 운영 검증과 공개 활성화 승인은 남아 있다. Stage 3 진입은 작업지시자 승인 후 수행한다.
