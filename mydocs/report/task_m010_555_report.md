# Task M010 #555 최종 보고서 — Threads 알한글 소식

## 작업 요약

- 이슈: [#555](https://github.com/postmelee/alhangeul-macos/issues/555), 마일스톤: M010 / v0.1
- 작업 브랜치: `local/task555`, 게시 브랜치: `publish/task555`, PR 대상: `devel`
- 구현 4단계와 로컬 통합 검증 완료. Stage 4 보고 후 작업지시자의 “진행해줘.” 지시로 최종 보고·PR 게시를 진행한다.
- 목적: `@postmelee`가 실제 `알한글` 주제 태그로 작성한 글을 자동 선별하여 제품 페이지의 최신 소식으로 표시한다. X 연동은 후속 범위다.
- 결과: 홈 최신 1개 전체 높이, 한 열의 전체 소식 목록, 5개씩 추가 로딩, 공식 Threads 임베드와 스켈레톤 전환, fresh 수집을 포함한 Pages 배포 경로를 구현했다. 공개 활성화는 별도 조건으로 유지한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|---|---|
| `scripts/ci/threads-news.py` | 본인 계정·실태그·완전 조회·oEmbed 확인, 링크 전용 snapshot, 재시도·만료·수동 토큰 갱신 |
| `scripts/ci/prepare-news-data.py`, `prepare-pages-artifact.sh` | 비활성 seed 또는 해당 실행의 fresh snapshot을 appcast와 함께 조립 |
| `docs/index.html`, `docs/news/index.html`, `docs/news.js`, `docs/styles.css` | 홈과 전체 목록, 5개 단위 자동/수동 추가, 로딩·실패·만료·재시도·키보드 처리 |
| `docs/updates/index.html`, `docs/feedback/index.html` | 최신 소식 내비게이션 연결 |
| `docs/data/news.json` | 비활성 빈 초기값만 Git에 보관 |
| `.github/workflows/threads-news-sync.yml`, `pages-docs-deploy.yml`, `release-promote.yml` | 예약 호출·fresh 수집·공통 배포 잠금·secret 범위·Pages artifact 1일 보존 |
| `.github/workflows/pr-ci.yml` | 문서 전용 변경을 포함한 모든 PR에 소식 검사 연결 |
| `scripts/ci/test-threads-news.py`, `test-news-ui.cjs`, `test-news-pages.py`, `fixtures/threads-news*/`, `prepare-news-ui-preview.py` | 수집·계약·조립·브라우저 회귀 검증 |
| `mydocs/manual/threads_news_operation_guide.md` | 계정·토큰·제외·중단·삭제 요청·실패 복구 운영 절차 |
| `mydocs/plans/task_m010_555*.md`, `mydocs/tech/task_m010_555.md`, `mydocs/working/task_m010_555_stage*.md`, `mydocs/orders/20260915.md` | 승인·기술 근거·단계 결과·완료 기록 |

Swift/Rust 앱 동작, DMG 재빌드·서명 규칙은 이번 변경의 대상이 아니다. 릴리스 workflow에서는 검증된 동일 DMG를 공개하는 기존 순서에 소식 준비 단계를 연결했다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|---|---|---|
| 제품 페이지 소식 표시 | 없음 | 홈 1개, 전체 목록 처음 5개·다음 5개씩 |
| 실계정 선별 | 수동 확인 | 7페이지·263개 조회 중 실제 태그 대상 6개 확인 |
| API 본문·미디어 보관 | 별도 수집 없음 | 본문·미디어·oEmbed HTML 보관 없이 원문 링크만 사용 |
| 소식 검사 | 없음 | 수집 43개, 데이터 8개, Pages 통합 12개, 브라우저 21개 |
| Pages 갱신 | 앱 릴리스/문서 배포 | 활성화 시 6시간 예약도 동일 배포 경로 호출 |
| 뉴스 포함 Pages artifact | 기존 Pages 14일 | 1일, 기존 릴리스 증빙은 30일 유지·뉴스 제외 |

공개 사이트에 실제 반영된 개수로 보고하지 않는다. 6개는 실계정 조회 및 로컬 공식 임베드 검증 결과이며, 저장소의 공개 seed는 비활성 상태다.

## 단계별 결과

- [Stage 1](../working/task_m010_555_stage1.md), `55a8ef2`: 계정 연결·실태그·전체 조회·공식 임베드 기술 검증과 저장 계약 보정.
- [Stage 2](../working/task_m010_555_stage2.md), `3e13b0a`: 자동 선별·원자적 저장·제한된 재시도·토큰 운영·비활성 workflow.
- [Stage 3](../working/task_m010_555_stage3.md), `e41e340`: 승인 화면 제품 반영·오류/만료 처리·브라우저 회귀.
- [Stage 4](../working/task_m010_555_stage4.md), `7054f1e`: Pages 통합·기존 appcast 보존·릴리스 증빙 분리·운영 안내.

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|---|---|---|
| 본인 작성·실제 알한글 태그 선별 | OK | 실계정 263개/7페이지, 대상 6개와 공식 oEmbed 확인 |
| 전체 조회·중복·태그 제거·실패 보존 | OK | 수집 43개, API/oEmbed 실패 후 재조회·기존 bytes 보존 검사 |
| UI·로딩·5개 단위 추가·키보드·반응형 | OK | 브라우저 21개, 실제 1440/768/390/320px·6개 표시, 홈 전체 높이 |
| 데이터·토큰·HTML 경계 | OK | 데이터 8개, 공개 필드 제한·URL·만료 검사, 토큰 bytes 비포함 |
| Pages 두 경로·실패 격리·artifact 경계 | OK | 통합 12개, workflow 순서·권한·잠금·보존 검사 |
| 기존 appcast 보존 | OK | 공개 입력/조립 결과 SHA-256 `8b0face06819d65f60cc6e3675244eaa1cccead997927c1f27c131d523313140` 일치 |
| 기존 릴리스·사이트 회귀 | OK | 승격 16개, release helper·endpoint fixture·업데이트/문의 복사·v0.2.2 다운로드 경로 |
| workflow·버전·main 콘텐츠 | OK | actionlint, 구문 검사, release notice, 최신 원격 main 기준 content gate |
| 운영 안내 | OK | 설정·갱신·중단·제외·삭제·오류 복구 문서 |
| 실제 예약 운영·공개 배포·비로그인 독립 검증 | MISS / 활성화 범위 | 이번 PR 게시와 구분. 아래 조건 완료 후 별도 수행 |

최종 보고 직전 수집 43개·데이터 8개·Pages 통합 12개, workflow 검사, 버전 안내와 main content gate를 재확인했다. UI와 기존 release helper 검증은 변경 없는 Stage 3·4 결과를 사용했다. 원격 PR CI 결과는 PR에서 확인하며 로컬 결과를 원격 통과로 표시하지 않는다.

## 잔여 위험과 후속 작업

1. `threads_basic`을 이용한 본인 글 선별과 공개 사이트의 공식 임베드를 결합한 전체 사용 목적의 정책·심사 조건을 확인해야 한다. 기술 성공을 Meta 승인으로 해석하지 않는다.
2. 정확한 토큰 만료 시각은 미확인이다. 실제 검증은 보호된 토큰과 최소 필드 strict probe로 수행했으며, 만료 정보를 요구하는 운영 수집을 우회해 활성화하지 않았다. 발급 응답에 근거한 만료 시각·repository secret/variable 설정 후 운영 dry-run을 확인한다.
3. 기본 비활성이며 공개 배포·예약 활성화는 별도 승인 후 수행한다. 수집 후 15분 이내 snapshot만 조립하고 브라우저 표시는 최대 48시간이다. 배포 대기·외부 서비스 오류·원문 캐시는 별도 운영 점검 대상이다.
4. 원문 접근 불가 화면과 iframe 내부 동작은 Threads가 제어한다. iframe 생성만으로 원문의 공개/삭제 상태를 확정하지 않는다. 공개 활성화 전 비로그인 환경을 확인한다.
5. X는 `platform` 필드를 활용하는 후속 연동 후보다. 새 이슈는 아직 만들지 않았다.

## 작업지시자 승인 요청

최종 보고와 `publish/task555` → `devel` Open PR 게시를 승인받았다. 다음은 PR 리뷰·CI 결과 확인 후 merge 승인이다. 이슈 close·브랜치 정리는 merge 확인 뒤 수행한다. 공개 배포와 자동 수집 활성화는 PR merge와 별도로 판단한다.
