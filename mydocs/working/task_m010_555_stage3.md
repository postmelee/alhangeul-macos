# Task M010 #555 Stage 3 — 제품 페이지 소식 화면

- 작성일: 2026-09-15
- 이슈: [#555](https://github.com/postmelee/alhangeul-macos/issues/555)
- 작업 브랜치: `local/task555`, 통합 대상: `devel`
- 상태: **Stage 3 구현·검증 완료. Stage 4 진입 승인 요청.**
- 관련 문서: [구현계획](../plans/task_m010_555_impl.md), [Stage 2](task_m010_555_stage2.md), [API 조사](../tech/task_m010_555.md)

## 1. 승인과 구현 결과

Stage 2 보고 후 작업지시자가 같은 스레드에서 “진행해줘.”라고 지시하여 Stage 3에 진입했다. 앞서 고정한 UI를 제품 `docs/`에 반영했다.

| 위치 | 결과 |
|---|---|
| 홈·업데이트·문의·소식 헤더 | 최신 소식 내비게이션 추가 |
| 홈 하단 | 최신 글 1개를 전체 높이로 표시, 소식 더 보기로 전체 목록 이동 |
| `docs/news/index.html` | 한 열·전체 페이지 스크롤, 처음 5개·하단 약 700px 전 다음 5개 추가 |
| 카드 로딩 | 승인한 Threads 형태 스켈레톤, shimmer, 카드 높이·등장과 스켈레톤 퇴장 전환 |
| 목록 하단 | 원형 로딩, 접근성 상태 설명, 수동 추가 버튼, 마지막 묶음 안내 |
| 정상 카드 | 공식 Threads 버튼 사용, 별도 원문 버튼과 클릭 시 iframe 외곽선 제거 |
| 외부 콘텐츠 안내 | Threads 연결과 원문·사진·영상 제공 주체 설명 |

공식 SDK script는 한 번만 삽입하고 추가 카드에는 `Embeds.process()`를 호출한다. blockquote마다 고유 ID를 주어 SDK의 자리 표시자 제거와 높이 수신을 연결했다. 카드 높이는 전환이 끝나면 고정하지 않는다. 320px에서는 헤더 로고의 글자를 생략하고 임베드의 최소 너비를 컨테이너에 맞춰 가로 넘침을 방지한다.

## 2. 데이터·실패·접근성 처리

- `docs/news.js`는 같은 origin의 명시적인 `data/news.json`만 읽는다. 스키마 2, UTC 시각·최대 48시간 수명, 항목 수·응답 4MiB 상한, 작성자·플랫폼·원문 URL, 중복을 검증한다. 공개 JSON의 원격 HTML을 DOM에 삽입하지 않는다.
- 비활성 seed·정상 빈 목록·잘못된 JSON·조회 실패·만료를 구분한다. JSON 실패는 재시도와 프로필 링크, 카드 실패는 해당 카드 재시도와 원문 링크를 제공한다. 정상 카드에는 복구 링크를 추가하지 않는다.
- JSON 조회 10초, SDK 12초, 카드 준비 20초 timeout을 적용한다. 실패한 SDK는 제거하고 재시도할 수 있다. 페이지를 열어 둔 상태의 만료는 카드·추가 로딩을 정리하며 늦게 도착한 응답이 다시 표시되지 않게 한다. 탭 복귀 때도 만료를 확인한다.
- 자동 감지가 없는 환경은 수동 추가 버튼으로 계속 읽는다. 연속 클릭을 막고 수동 추가 후 첫 새 카드로 키보드 포커스를 옮긴다. 키보드 링크·버튼의 포커스 표시는 유지한다.
- JavaScript 비활성용 `noscript` 안내와 프로필 링크를 넣었다. 동작 줄이기 설정에서는 스켈레톤·spinner CSS 애니메이션과 카드 전환을 생략한다.

iframe 생성과 높이 수신은 표시 준비 신호다. cross-origin 원문의 공개 여부·삭제 여부 판정으로 사용하지 않는다. 원문 접근 불가 화면, 내부 레이아웃·캐시·리사이즈는 공식 임베드가 제어한다.

## 3. 검증 결과

| 검증 | 결과 |
|---|---|
| 순수 데이터 계약 | Node 테스트 8개 PASS |
| 브라우저 fixture | 21개 PASS: 0/1/5/6/10/11개, 자동·수동 추가, 연속 클릭·중복, 빈 값·비활성·만료·오류, SDK 오류/timeout·카드 timeout 복구, 로딩 중 만료, 전환 정리, 4개 화면 폭 |
| 실제 Threads 글 | 첫 5개 표시, 페이지 끝 도달 전 6번째 카드 추가·마지막 안내, SDK script 1개, 실패 카드 0개 |
| 실제 글 반응형 | 1440/768/390/320px에서 새로 로드, iframe 5개·가로 넘침 없음, 320px 스크린샷 가독성 확인 |
| 홈 | 실제 최신 글 1개, article와 iframe 높이 각각 715px, 내부 스크롤 없음, 더보기 이동 |
| 키보드·기존 페이지 | Tab 순서·포커스 표시, Enter 추가 로딩/더보기 이동, Space FAQ 열기, 업데이트 탭·명령 복사, 문의 주소 복사 PASS |
| 수집 회귀 | Python 43개 PASS |
| 구문·문서 | JS 구문, preview Python 구문, 릴리스 버전 안내 검사, `git diff --check` PASS |
| 데이터·시안 보존 | 공개 seed는 비활성, 실제 토큰 bytes 비포함, 승인 UI 6개 파일 SHA-256 보존 |

실제 글 검증은 Stage 2에서 생성한 유효한 로컬 snapshot과 공식 Threads iframe으로 수행했다. API 재수집·토큰 변경·GitHub secret 등록은 하지 않았다. 비로그인 브라우저의 독립 검증은 수행하지 않았다. JavaScript 비활성 안내와 CSS 동작 줄이기는 정적으로 확인했고, JavaScript 전환 생략 경로는 fixture로 확인했다. OS 설정을 바꾼 검증으로 보고하지 않는다.

검증 중 발견한 320px 최소 너비 문제를 수정했다. 중첩 iframe의 부모 clipping 때문에 자동 로딩 fixture의 감지 대상이 가려졌던 문제는 하네스에서 노출하도록 보정했고, 실제 독립 페이지에서는 하단 도달 전 추가 로딩을 별도로 확인했다.

주요 명령:

```sh
node --check docs/news.js
node --test scripts/ci/test-news-ui.cjs
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ci/test-threads-news.py
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
python3 scripts/ci/prepare-news-ui-preview.py \
  --output-root build.noindex/task555/stage1/product \
  --live-data build.noindex/task555/stage2/live-snapshot.json
git diff --check
```

재현 절차는 [브라우저 fixture 안내](../../scripts/ci/fixtures/threads-news-ui/README.md)에 있다. `build.noindex/task555/stage1/product/qa.html`과 `/product/alhangeul-macos/`는 로컬 검증용이며 공개 파일이 아니다. 고정본 `build.noindex/task555/approved-ui/`도 수정하지 않았다.

## 4. 다음 단계와 유지 조건

Stage 4는 fresh snapshot을 기존 Pages 조립·배포 workflow에 연결하고, appcast 보존·실패 시 배포 방지·PR CI와 운영 문서를 검증한다. 전체 release helper 회귀와 최종 Pages artifact 검증은 그 단계에 포함된다. 이번 결과를 전체 PR CI 통과로 표시하지 않는다.

공개 Pages 배포·예약 수집 활성화는 수행하지 않았다. 공개 초기 JSON은 비활성 seed이며 기존 Stage 2 workflow는 dry-run 상태다. API 전체 사용 목적 확인과 정확한 토큰 만료 시각 등 공개 활성화 조건은 유지한다.
