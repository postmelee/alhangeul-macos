# Threads 소식 운영 안내

알한글 제품 페이지는 `@postmelee` 본인 글 중 실제 `알한글` 주제 태그가 있는 글을 선별하여 공식 임베드로 표시한다. 본문·사진·영상·oEmbed HTML을 별도로 보관하지 않는다. 최초 연결 근거는 [API 조사](../tech/task_m010_555.md), 구현·검증은 [구현계획](../plans/task_m010_555_impl.md)에 있다.

## 수동 목록으로 표시

자동 수집이 꺼져 있을 때는 `docs/data/news-manual.json`에 운영자가 선택한 공개 원문을 순서대로 기록한다. 계약은 `schema_version: 3`, `mode: manual`, `items`이며 항목에는 `platform`, `permalink`만 둔다. 맨 위 항목이 홈에 표시된다.

- 새 글 추가·순서 변경·제거는 수동 파일을 수정하고 기존 PR/Pages 절차로 반영한다. 공개 원문의 작성자·태그·임베드 지원을 확인한다.
- 수동 모드는 사용자 토큰과 수집 API를 사용하지 않는다. 자동 갱신 시각·48시간 만료를 주장하지 않고, 원문 내용은 공식 Threads 임베드가 제공한다.
- 원문 삭제·비공개 시 임베드가 표시되지 않을 수 있다. 운영자가 수동 목록에서도 해당 URL을 제거한다. 게시물 본문과 미디어를 백업하는 기능은 아니다.
- `THREADS_NEWS_ENABLED=true`는 수동 목록보다 우선하며, 실패 시 수동 목록으로 대신 배포하지 않는다. helper에 수동 입력을 지정하지 않으면 기존 빈 seed가 사용된다. 현재 workflow는 수동 파일을 명시하므로 파일을 삭제하지 말고 빈 items로 중단한다.
- 두 Pages 경로 모두 현재 수동 파일을 검증한다. 잘못된 URL·중복·추가 필드·조립 입력 불일치는 새 배포를 중단한다.
- 전체 표시 중단은 자동 수집을 `false`로 두고 수동 목록의 `items`를 `[]`로 바꾼 후 재배포한다. `false` 설정만으로 수동 목록이 사라지지는 않는다.

## 자동 수집 활성화 전 조건

현재 구현은 비활성 상태로 검증했다. 아래 조건을 확인한 뒤 작업지시자의 공개 활성화 지시에 따라 설정한다.

1. `threads_basic`으로 본인 글을 선별하고 공개 사이트의 공식 임베드로 표시하는 전체 사용 목적을 Meta의 적용 정책·심사 조건에 맞게 확인한다. API 호출 성공이나 oEmbed 지원을 전체 사용 목적의 승인으로 간주하지 않는다.
2. Meta 앱의 Threads 테스터 초대 수락·기본 조회 동의와 계정 ID를 확인한다. 추가 게시·답글 관리 권한은 필요하지 않다.
3. 발급 응답에 근거한 정확한 토큰 만료 시각을 기록한다. 호출 성공으로 만료 시각을 추정하지 않는다. 미확인 토큰은 `sync --dry-run` 조사만 허용한다.
4. 아래 repository secret·variable을 준비하고 공개 브라우저 표시·비로그인 접근과 외부 콘텐츠 안내를 확인한다. 토큰은 대화·Issue·PR·로그에 붙여 넣지 않는다.

| 종류 | 이름 | 값 |
|---|---|---|
| Secret | `THREADS_ACCESS_TOKEN` | 본인 계정용 토큰 |
| Variable | `THREADS_EXPECTED_USER_ID` | 최초 `/me`로 확인한 ID |
| Variable | `THREADS_TOKEN_EXPIRES_AT` | 발급 응답에 근거한 UTC 만료 시각 |
| Variable | `THREADS_NEWS_ENABLED` | 미설정/`false`는 비활성, 승인 후 `true` |
| Variable | `THREADS_NEWS_EXCLUDED_URLS` | 선택 사항. 운영자가 명시 제외하는 정규 원문 URL의 JSON 배열. 기본 `[]` |

재사용 workflow에는 Threads secret만 명시적으로 전달한다. environment secret은 호출자에서 자동 전달되지 않으므로 repository 설정을 사용한다. [GitHub 재사용 workflow 문서](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)

## 실행 흐름

- **Threads News Sync 수동 실행**: `main`에서 실제 조회·검증만 하는 dry-run이다. 공개 사이트를 바꾸지 않는다. 토큰 만료 시각 설정이 필요하다.
- **예약 수집**: 6시간마다 UTC 분 23에 실행한다. `THREADS_NEWS_ENABLED=true`, 본 저장소·`main`일 때만 Pages workflow를 호출한다. GitHub 일정은 지연될 수 있으므로 정시 갱신을 보장하지 않는다.
- **Docs-only Pages Deploy**: `main`의 `docs/**` 변경 또는 명시적인 수동 실행이다. 링크된 공개 DMG 존재를 확인하고 현재 공개 appcast를 보존하며, 자동 활성 상태에서 해당 실행의 소식을 완전 재수집한다. 자동 비활성은 외부 조회 없이 수동 목록을 사용하며, 수동 입력이 없으면 seed를 만든다.
- **Release Promote Verified DMG**: 기존 양 VM·DMG 검증 뒤, 서명·공개 부작용 전에 소식을 수집한다. 새 appcast와 소식을 함께 조립한다. DMG 검증·승격·공개 승인 절차는 기존 [릴리스 안내](release_github_pages_sparkle_guide.md)를 따른다.

두 Pages 경로는 workflow 전체에 `pages-deploy` 잠금을 유지한다. 예약 호출자는 다른 잠금을 사용하여 호출자와 피호출자가 같은 잠금을 기다리는 상황을 피한다. appcast 준비·수집·조립·배포를 같은 잠금 안에서 수행하며 이전 실행의 snapshot/artifact를 가져오지 않는다.

자동 수집 공개 JSON(v2)은 `schema_version`, `updated_at`, `expires_at`, `items`를 갖고 각 항목은 `platform`, `permalink`만 포함한다. 수집 후 15분 이내·미만료인 결과만 새 Pages 산출물에 삽입한다. 48시간은 브라우저의 표시 기한이며, 열린 탭에서도 기한을 지나면 소식을 제거하고 갱신 지연 안내를 표시한다. 정상 대상 0개와 수집 실패를 구분한다.

## 로컬 검증 명령

보호된 토큰 파일을 사용할 때:

```sh
python3 scripts/ci/threads-news.py token-status --expires-at <확인된-UTC-만료시각>
python3 scripts/ci/threads-news.py sync --token-file <권한-600-토큰파일> \
  --expected-user-id <확인된-ID> --token-expires-at <확인된-UTC-만료시각> --dry-run
```

운영과 같은 수집은 보호된 환경변수를 주입한 runner에서 수행한다. 토큰을 명령 인수에 쓰지 않는다.

```sh
python3 scripts/ci/prepare-news-data.py collect --output "$RUNNER_TEMP/threads-news.json"
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast <검증된-appcast> \
  --news-enabled true --news-data "$RUNNER_TEMP/threads-news.json" \
  --output-dir build.noindex/news-check/pages
```

`collect`에 `--manual-input docs/data/news-manual.json`을 주면 자동 비활성 상태에서 해당 목록을 사용한다. 수동 입력 없는 비활성 기본값은 seed 생성이다. 잘못된 활성화 값, 활성 상태의 토큰·만료 정보 누락, 불완전 조회, oEmbed 실패는 실패로 종료한다. `prepare`는 네트워크 없이 조립 입력을 검증한다. stdout은 개수·시각·갱신 필요 여부이며 원문 본문과 토큰을 출력하지 않는다.

## 토큰 갱신·만료

토큰 만료 14일 전부터 경고를 출력한다. 유효한 장기 토큰은 마지막 발급/갱신 후 24시간이 지난 다음 수동 갱신할 수 있다. 만료한 토큰은 재인증한다.

```sh
python3 scripts/ci/threads-news.py refresh-token --token-file <현재-보호파일> \
  --issued-at <확인된-발급시각> --expires-at <확인된-만료시각> \
  --output-token-file <새-보호파일>
```

명령은 새 600 파일에 저장하며 기존 파일과 GitHub secret을 덮어쓰지 않는다. 발급된 메타데이터를 검증한 뒤 secret과 만료 variable을 함께 교체하고 dry-run을 확인한다. short-lived 토큰 교환은 `exchange-token --help`를 참고하며 앱 secret도 별도 보호 파일로만 전달한다. 토큰 폐기·권한 철회 뒤 기존 secret과 로컬 임시 파일도 제거한다.

## 실패·복구

- 인증 오류·만료·부분 조회·API/oEmbed 실패는 새 배포를 진행하지 않는다. 오류 글을 자동으로 누락시키거나 이전 JSON으로 대체하지 않는다.
- API 429·5xx·연결 오류는 제한된 재시도를 수행한다. 다음 workflow 실행은 현재 목록을 다시 완전 조회한다. 태그 제거·미관찰 글은 다음 성공 결과에서 빠진다. 삭제·비공개 이유까지 확정하지 않는다.
- 조립 오류는 기존 로컬 산출물을 보존하며 upload와 deploy가 실행되지 않는다. 배포 action 자체가 실패하면 GitHub Pages의 마지막 성공 배포와 공개 화면을 확인한다. 원격 서비스의 부분 실패를 로컬 검사만으로 원상 보존됐다고 단정하지 않는다.
- 배포 environment 승인이나 대기 시간이 길어 snapshot이 오래됐다면 오래된 artifact를 수동 재배포하지 않고 전체 workflow를 새로 실행한다. 브라우저는 만료한 JSON을 표시하지 않는다.
- 원문이 표시되지 않으면 공식 Threads 접근 상태를 확인한다. JSON 재시도/카드 재시도·원문 링크를 이용할 수 있지만 cross-origin iframe 내부의 성공 여부는 사이트 코드가 판정하지 않는다.

## 제외·중단·삭제 요청

1. 수동 모드는 수동 목록에서 해당 URL을 제거한 뒤 재배포한다. 자동 모드에서 특정 글의 즉시 제외는 승인된 정규 URL을 `THREADS_NEWS_EXCLUDED_URLS` 배열에 넣고 `main`의 Docs-only Pages Deploy를 실행한다. 제외를 해제할 때도 현재 목록을 다시 수집한다.
2. 전체 중단은 `THREADS_NEWS_ENABLED=false`로 바꾸고 수동 목록의 `items`도 `[]`로 변경한 뒤 Docs-only Pages Deploy를 실행한다. variable 변경만으로 기존 사이트나 열린 iframe이 즉시 사라지지는 않는다. 수동 목록을 이미 연 탭은 새로고침해야 변경을 반영한다. 자동 목록은 새로고침 또는 표시 기한 만료 때 반영한다.
3. 삭제 요청 시 현재 사이트 재배포와 이전 뉴스 포함 Pages artifact 삭제를 함께 처리한다. 관련 성공·실패 run의 `github-pages` artifact를 확인한다. [GitHub artifact 삭제 안내](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts)
4. 뉴스가 포함된 Pages artifact의 보존 기간은 1일이다. release 증빙 30일 보존은 유지하되 `promotion/pages/**`를 제외하여 소식 JSON이 증빙에 포함되지 않게 한다. 실제 수집 snapshot은 `RUNNER_TEMP`에만 둔다. [공식 Pages artifact action](https://github.com/actions/upload-pages-artifact)
5. API 사용 중단이 필요하면 권한을 철회하고 secret을 제거한다. 수집 실패로 전체 Pages 갱신이 막히지 않게 비활성 설정과 수동 목록 또는 빈 목록 배포를 먼저 확인한다. 재개는 활성화 전 조건부터 다시 검증한다.
