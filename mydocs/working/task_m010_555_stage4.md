# Task M010 #555 Stage 4 — Pages 통합과 운영 검증

- 작성일: 2026-09-15
- 이슈: [#555](https://github.com/postmelee/alhangeul-macos/issues/555)
- 작업 브랜치: `local/task555`, 통합 대상: `devel`
- 상태: **Stage 4 구현·검증 완료. 최종 보고·PR 절차 승인 요청.**
- 관련 문서: [구현계획](../plans/task_m010_555_impl.md), [Stage 3](task_m010_555_stage3.md), [운영 안내](../manual/threads_news_operation_guide.md)

## 1. 승인과 구현 결과

Stage 3 보고 후 작업지시자가 같은 스레드에서 “진행해줘.”라고 지시하여 Stage 4에 진입했다. 승인한 화면을 유지하면서 소식 수집을 기존 Pages 조립·배포 경로에 연결했다.

| 산출물 | 결과 |
|---|---|
| `prepare-news-data.py` | 비활성 seed 생성, 활성 상태의 fresh 완전 수집, 네트워크 없는 조립 입력 검증 |
| `prepare-pages-artifact.sh` | `--news-enabled`·`--news-data` 추가, appcast와 소식 JSON을 같은 산출물로 조립 |
| `pages-docs-deploy.yml` | 재사용 workflow 진입점, 본 저장소/main 제한, 수집 step에만 Threads secret 전달 |
| `threads-news-sync.yml` | 활성화된 6시간 일정에서 Pages workflow 호출, 수동 실행은 제외 목록을 반영하는 dry-run 유지 |
| `release-promote.yml` | 기존 VM/DMG 검증 후·릴리스 부작용 전 수집, 동일 Pages 조립, 뉴스 JSON을 릴리스 증빙에서 제외 |
| `pr-ci.yml` | 모든 PR의 script checks에 수집·데이터·Pages 통합 검사 연결, 기존 release checks 유지 |
| 운영 안내 | 계정·토큰·활성화, 제외·중단·삭제 요청, 실패·복구 절차 |

Docs-only와 release 경로는 기존 `pages-deploy` 잠금을 workflow 전체에서 유지한다. 예약 호출자의 `threads-news-sync` 잠금은 별개여서 같은 잠금을 중복 획득하지 않는다. 재사용 호출에는 필요한 Pages/OIDC 권한과 Threads secret만 명시적으로 전달한다. [GitHub 재사용 workflow 문서](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)

## 2. 데이터·실패·보존 계약

- 활성 소식은 해당 실행에서 완전 조회하고 모든 대상의 공개 oEmbed를 확인한다. 이전 Git snapshot·workflow artifact를 내려받아 재사용하지 않는다. `THREADS_NEWS_EXCLUDED_URLS`는 명시적인 제외 목록으로만 처리한다.
- 활성인데 토큰·정확한 만료 시각·계정 ID가 없으면 외부 조회 또는 저장 전에 실패한다. 비활성은 토큰 없이 seed를 만들며 잘못된 활성화 값도 거부한다.
- Pages 조립은 생성 후 15분 이내·미만료 snapshot만 받는다. 활성인데 입력 부재·비활성 seed·오래된/잘못된 JSON이면 실패한다. 비활성 조립은 repository에 과거 소식이 있어도 빈 seed로 바꾸며 repository 원본은 변경하지 않는다. 48시간 브라우저 표시 기한과 15분 조립 기준은 구분한다.
- 새 JSON 검증은 기존 산출물 교체 전에 실행한다. API/oEmbed/조립 실패는 upload와 deploy로 진행하지 않는다. 다음 실행은 현재 목록부터 다시 조회한다.
- 뉴스가 포함된 Pages artifact 보존을 1일로 설정했다. 릴리스 증빙의 30일 보존은 유지하면서 `promotion/pages/**`를 제외했다. 수집 원본 snapshot은 `RUNNER_TEMP`에만 둔다. [공식 Pages artifact action](https://github.com/actions/upload-pages-artifact)
- 배포 action 자체가 실패한 경우의 원격 서비스 상태는 실제 마지막 성공 배포와 공개 화면으로 확인해야 한다. 로컬 실패 검사를 원격 부분 실패의 원상 보존 보장으로 해석하지 않는다.

## 3. 검증 결과

| 검증 | 결과 |
|---|---|
| 신규 Pages 통합 검사 | 12개 PASS: 활성화 값·비활성 무통신·만료 정보 누락, fresh/빈 결과, 실제 조립 두 경로의 동일 JSON/appcast, 실패 시 기존 디렉터리 bytes 보존, API/oEmbed 실패, 재조회 후 태그 제거 반영, 비밀 출력 금지, workflow 잠금·권한·순서·artifact 경계 |
| 수집·화면 데이터 회귀 | Python 43개·Node 8개 PASS |
| 기존 릴리스 승격 회귀 | Python 16개 PASS |
| 기존 release helper | release CLI help, v0.1.5/v0.2.0 note 생성·template/body 검사, PR 분석·body 검사, delta checklist, synthetic Sparkle appcast, 비활성 Pages 조립 PASS |
| 기존 endpoint fixture | PASS |
| workflow/구문 | actionlint 4개 workflow, 전체 YAML parse, shell·신규 Python·news.js 구문, CLI help PASS |
| 기존 버전·통합 기준 | v0.2.2 release notice 검사, main/source 콘텐츠 보존 검사 PASS |
| 실제 최소 필드 수집 | 7페이지·263개 조회·대상 6개·공식 oEmbed 확인 PASS |
| 실제 Pages 산출물 | 소식 5개→6개, 실패 0개, SDK script 1개, 홈 최신 1개 전체 높이·더보기/헤더 연결·업데이트/문의 복사 PASS |
| appcast 보존 | 공개 입력과 조립 결과 bytes·SHA-256 일치 |
| 비밀·시안·공개 seed | 토큰 bytes 비포함, 승인 UI 6개 SHA-256 보존, 공개 seed 비활성 유지 |

실제 수집 시각은 `2026-09-15T10:30:16+00:00`이다. 로컬 보호 토큰의 정확한 만료 시각은 여전히 미확인이므로 운영 `collect/sync` 저장을 억지로 통과시키지 않았다. 기존 최소 필드·strict `probe` 엔진과 공식 oEmbed 검증으로 fresh 링크 JSON을 생성해 로컬 조립에 사용했다. 활성 운영 helper의 자격 정보·저장 경로는 synthetic 응답으로 검증했으며, 예약 운영 성공으로 보고하지 않는다.

실제 공개 appcast 입력과 조립 결과 SHA-256:

```text
8b0face06819d65f60cc6e3675244eaa1cccead997927c1f27c131d523313140
```

로컬 산출물은 `build.noindex/task555/stage4/pages-artifact/`, 검증 로그는 같은 `stage4/` 아래에 있다. 실제 UI는 기존 로컬 서버의 `/integrated/` 프로젝트 하위 경로에서 확인했다. 홈의 article/iframe은 각각 715px로 전체 높이를 표시하며 다운로드 링크는 v0.2.2를 유지한다. 실제 임베드 내부 내용은 별도로 저장하지 않았다.

기존 PR 분석 helper는 `v0.1.4..e41e340` 범위의 공개 PR 메타데이터를 읽어 로컬 초안을 생성했고 body 검사를 통과했다. 게시하지 않았다. main/source 검사는 sandbox의 임시 Git 객체 생성 제한을 승인된 접근으로 해소한 뒤 통과했다. GitHub 원격 PR CI·예약 workflow·공개 배포 자체는 실행하지 않았다. Ubuntu runner와 원격 배포 서비스 검증을 로컬 macOS 결과로 대신했다고 표시하지 않는다.

## 4. 재현 명령

```sh
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-news-pages.py
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-threads-news.py
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-release-promotion.py
node --test scripts/ci/test-news-ui.cjs
actionlint .github/workflows/pages-docs-deploy.yml .github/workflows/threads-news-sync.yml \
  .github/workflows/release-promote.yml .github/workflows/pr-ci.yml
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast <검증된-appcast> \
  --news-enabled true --news-data <15분-이내-fresh-snapshot> \
  --output-dir build.noindex/news-check/pages
scripts/ci/check-main-devel-content.sh origin/main HEAD
git diff --check
```

## 5. 다음 절차와 공개 활성화 조건

Stage 1~4 구현·로컬 검증을 완료했다. 최종 보고서와 PR 절차로 인계하며 실제 공개 활성화는 별도다. `THREADS_NEWS_ENABLED`나 GitHub secret을 설정하지 않았고 원격 push·PR 생성·배포·이슈 close를 수행하지 않았다.

공개 활성화 전에는 전체 API 사용 목적 확인, 발급 응답에 근거한 토큰 만료 시각·repository secret/variable 설정, 비로그인 공개 화면 확인과 작업지시자 승인이 필요하다. 운영 중 제외·중단·삭제·만료 대응은 [운영 안내](../manual/threads_news_operation_guide.md)를 따른다.
