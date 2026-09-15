# Task M010 #555 Stage 1 — 자동 선별·공식 임베드 기술 검증

- 작성일: 2026-09-15
- 이슈: [#555](https://github.com/postmelee/alhangeul-macos/issues/555)
- 작업 브랜치: `local/task555`, 통합 대상: `devel`
- 상태: **기술 검증 완료. 구현계획 보정안 수용 및 Stage 2 진입 승인 요청.**
- 관련 문서: [수행계획](../plans/task_m010_555.md), [구현계획 보정안](../plans/task_m010_555_impl.md), [공식 근거·실측 기록](../tech/task_m010_555.md)

## 1. 단계 목적과 승인 범위

본인 Threads 계정의 실제 `알한글` 태그 글을 자동으로 선별하고 제품 페이지에서 표시할 수 있는 기술 경로를 확인한다. 본인 API 조회와 공개 표시를 구분하고, 게시물 본문을 Git에 아카이빙하는 초기 설계를 보정한다.

작업지시자는 수행·구현계획과 Stage 1 진입을 승인했고, 이후 Chrome을 통한 앱 생성·계정 연결을 지시했다. 앱 생성 최종 버튼, 테스터 초대 수락, 기본 조회 인증 동의는 작업지시자가 직접 실행했다. 자동 선별·공식 임베드의 가능 여부 설명 후 “진행해줘.” 지시에 따라 해당 기술 검증과 계획 보정을 수행했다.

이 보고서는 Meta의 정책 승인, 전체 타스크 완료 또는 공개 운영 완료를 의미하지 않는다. 원래 Stage 1에 포함된 운영 적합성 확정 중 **전체 API 사용 목적 확인은 아직 미해결**이며, 보정안에서 이를 공개 활성화 게이트로 분리하도록 제안한다. 이 보정을 수용하기 전 Stage 1 전체의 무조건 완료나 Stage 2 진입으로 간주하지 않는다.

## 2. 산출물

| 파일 | 결과 |
|---|---|
| `scripts/ci/threads-news.py` | 본인 조회 `probe`, 선택적 공개 `--check-embeds`, 로컬 링크 결과 `--reference-output`, 스키마 2 `validate`; token을 받지 않는 별도 oEmbed client |
| `scripts/ci/test-threads-news.py` | 태그·작성자·페이지·비밀 경계·링크 계약·oEmbed 원문 대응·부분 실패 등 22개 fixture 검사 |
| `scripts/ci/fixtures/threads-news/` | synthetic 본인 조회, 링크 JSON v2, oEmbed 응답 및 설명 |
| `mydocs/tech/task_m010_555.md` | 계정 연결 기록, 공식 권한/oEmbed 근거, 실제 API 결과와 보관·운영 조건 |
| 수행·구현계획과 오늘할일 | 자동 선별·공식 임베드·실행별 snapshot 보정안과 단계 상태 |
| `build.noindex/task555/stage1/` | 실제 링크 6개의 검증 JSON과 로컬 임베드 연결 페이지. gitignore 대상이며 커밋하지 않음 |

현재 `probe`는 운영용 동기화가 아니다. 새 로컬 결과 파일만 생성하며 기존 파일을 덮어쓰지 않는다. 정기 실행, 기존 snapshot의 원자적 교체, 오류 재시도·토큰 만료 운영은 Stage 2에 남는다.

## 3. 본문 변경 정도와 보존 경계

- macOS 앱·Rust·Quick Look·기존 제품 페이지 소스는 변경하지 않았다.
- 공개 데이터 계약을 본문·미디어를 포함한 초기 스키마 1에서 **플랫폼·원문 URL만 포함한 스키마 2**로 보정했다. 목록 갱신·표시 만료 시각만 별도 최상위 필드로 둔다.
- 본문 무손실 아카이브를 제공하지 않는다. 본문·날짜·이미지·영상은 Threads 공식 iframe이 표시하며 원문을 추출·재구성하지 않는다.
- 실제 토큰은 저장소 밖의 본인 소유 디렉터리 700·파일 600으로 보관했다. 계정 검증에 사용한 토큰이 소스·문서·fixture·미리보기에 포함되지 않았음을 실제 값 비교로 확인했다. 토큰 값을 로그로 출력하지 않았다.
- 실제 API 원본 응답과 본문을 저장하지 않았다. 선택된 원문 참조의 로컬 JSON만 검증·미리보기에 사용했다.

## 4. 실제 계정과 공개 임베드 결과

| 검증 | 결과 |
|---|---|
| Meta 앱 / Threads 앱 | `1601095448152539` / `1584332403182930`, 이름 `알한글 소식` |
| 계정 | `postmelee`, API 사용자 ID `29072097499042855` |
| 인증 화면 | 게시·답글 관리·인사이트·답글 조회 선택 권한 4개 해제, 기본 조회만 남김 |
| 본인 글 조회 | 7페이지, 고유 글 263개, 페이지 종료 확인 |
| 태그 판정 | 대상 6개, 다른 태그 97개, 태그 없음 149개, 재게시 11개 |
| 예시 글 | `DdTIl2SEsaU`, 작성자·실태그·정규 원문·유형/인용 조건 통과 |
| 공개 oEmbed | 대상 6개 모두 인증 없는 요청으로 응답 검증 통과 |
| 로컬 표시 | 공식 script가 iframe 6개 생성, 각 iframe에서 `postmelee` 작성자 링크 확인 |
| 시각 확인 | 예시 v0.2 글·다른 릴리스 글과 영상·이미지 표시를 Chrome에서 확인 |

관찰 범위는 2023-07-06 10:16:58 UTC부터 2026-09-15 07:05:46 UTC까지다. 이 결과는 API가 현재 제공한 목록의 끝이며 삭제·비공개 글까지 포함한 모든 과거 활동 기록을 보장하지 않는다.

공개 oEmbed client는 `https://graph.threads.com/v1.0/oembed?url=...`를 호출한다. 사용자 토큰을 보유한 `graph.threads.net/v1.0/me` client와 분리했다. 반환 HTML의 공식 컨테이너·원문 shortcode·script host를 확인하고 링크 참조만 반환한다. 이 검증은 범용 HTML sanitizer가 아니며 raw HTML을 실행하거나 공개 JSON에 전달하지 않는다.

## 5. 검증 결과

```text
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-threads-news.py
Ran 22 tests — OK

python3 scripts/ci/threads-news.py validate scripts/ci/fixtures/threads-news/public-news.json
valid / schema_version: 2 / item_count: 1 / live_verified: false

python3 scripts/ci/threads-news.py probe --token-file <보호된 경로> \
  --expected-user-id 29072097499042855 --max-pages 20 --check-embeds \
  --reference-output build.noindex/task555/stage1/embed-references.json
probe_complete / pages: 7 / unique_posts: 263 / candidate: 6
embed_check: complete / validated_count: 6 / authenticated: false
종료 코드 0

python3 scripts/ci/threads-news.py validate build.noindex/task555/stage1/embed-references.json
valid / schema_version: 2 / item_count: 6

probe --help / Python AST syntax / git diff --check — PASS
실제 토큰 비포함 검사 — PASS
git check-ignore: 실링크 JSON·미리보기 HTML — PASS
Chrome: 원문에 대응하는 공식 iframe 6개 / 작성자 링크 6개 — PASS
```

`validate`의 `live_verified=false`와 `probe`의 `stage1_complete=false`는 도구가 실제 운영·단계 승인을 대신 판정하지 않도록 고정한 값이다. 실제 API 결과는 해당 probe 실행 결과로 별도 기록했다.

처음 로컬 연결과 HTTP 서버 실행은 sandbox의 네트워크/포트 제한으로 실패했고, 승인된 권한으로 같은 작업을 재실행하여 성공했다. 인증·공개 oEmbed 자체의 실패를 숨기거나 필드를 줄여 통과시키지 않았다. 로컬 검증 페이지는 제품 UI 완성본이 아니며 모바일·비로그인 독립 수용·배포 검증은 이후 단계에 남는다.

## 6. 운영 보정안과 잔여 위험

1. **자동 수집 유지**: 현재 목록을 완전 조회하고 태그로 자동 선별한다. 수동으로 URL을 입력하는 방식으로 목표를 축소하지 않는다.
2. **원문 참조와 공식 임베드**: 본문·미디어 사본과 Git 데이터 브랜치를 만들지 않는다. Threads를 원본으로 두고 각 배포 실행에서 fresh snapshot을 생성한다.
3. **갱신·삭제 대응**: 6시간마다 현재 대상 목록으로 교체한다. 완전 목록에서 미관찰·태그 제거인 글은 표시 대상에서 제외하되 삭제 원인을 단정하지 않는다. 한 요청이라도 실패하면 새 목록 배포를 중단한다.
4. **보존·중단**: 48시간 표시 기한, 뉴스 포함 Pages artifact 1일 보존, 명시 삭제 요청 때 사이트 재배포와 관련 artifact 제거를 제안한다. UI 만료와 서버 파일 삭제는 다르다.
5. **운영 의존성**: 활성화 후 Pages 준비가 Threads API/oEmbed 가용성에 의존한다. 릴리스 경로에 연결할 때 뉴스 조회는 공개 release 부작용 전에 검증하며, 기존 appcast 보존·배포 잠금을 유지한다. 실제 갱신 간격은 Actions 지연의 영향을 받는다.
6. **정책 확인 미해결**: oEmbed 문서는 외부 사이트 표시를 허용하지만, `threads_basic` URL 선별과 공개 oEmbed를 조합한 전체 사용 목적에 대한 Meta의 별도 승인은 없다. 이 확인을 **공개 활성화 전 조건**으로 남기고, 후속 구현·테스트는 비활성 상태로 진행하는 보정안을 요청한다. 사용자 지시나 기술 성공을 Meta의 정책 승인으로 기록하지 않는다.
7. **토큰 운영**: 장기 토큰은 문서상 60일이며 실제 만료 시각을 운영 활성화 전에 확인한다. 갱신 helper·만료 경고·저장소 secret 전달은 Stage 2 이후 검증한다. 현재 GitHub secret 등록과 자동 운영은 수행하지 않았다.

## 7. 다음 단계 영향과 승인 요청

Stage 2에서는 링크 전용 snapshot을 생성·원자적으로 교체하는 `sync`, 실패·태그 변경·정상 빈 목록 검증, 기본 비활성 workflow와 토큰 만료 검사를 구현한다. Stage 3은 홈 3개·전체 목록 12개 단위의 공식 임베드 화면, Stage 4는 기존 Pages 통합과 운영 검증이다.

**요청**: [구현계획 보정안](../plans/task_m010_555_impl.md)을 수용하고 Stage 2로 진행한다. 전체 API 사용 목적 확인은 공개 활성화 전에 충족할 게이트로 유지한다. 이 승인 전에는 Stage 2 소스를 변경하거나 공개 서비스를 활성화하지 않는다.
