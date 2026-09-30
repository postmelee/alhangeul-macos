# Task #573 구현계획

승인 근거·범위·제외 사항은 [수행계획](task_m020_573.md)을 따른다.

## Stage 1 — README 배지와 동기화 유지

- 기존 가운데 정렬 배지에 `bundled rhwp` 표시와 고정 provenance의 릴리스 링크를 추가한다.
- lock·manifest에서 생성하는 작은 helper를 두고 동일 provenance는 하나, 다른 provenance는 native/Studio 배지로 구분한다. commit pin은 commit 링크를 사용한다.
- full sync의 core·Studio 갱신 뒤 helper를 실행하고 README를 명시 stage한다. 현재 checkout의 배지 정합성을 검사할 수 있도록 `--check`를 지원한다.
- 다음 버전 갱신·다른 provenance·commit pin·stale 표시를 검증한다. 단계 보고서와 함께 `Task #573 Stage 1: 포함 rhwp 배지와 동기화 갱신`으로 커밋한다.

## Stage 2 — 제품 간 홈페이지 이동

- `site-header`를 가진 홈페이지·소식·문의·업데이트 인덱스와 모든 버전별 페이지에 동일한 문구·절대 URL을 추가한다.
- 기존 정적 헤더 구조와 공통 CSS를 유지한다. 좁은 화면에서는 추가 링크에 별도 줄을 확보하고 숨김·잘림·겹침을 막는다.
- 페이지별 링크·모바일/태블릿/데스크톱 레이아웃을 정적 검사 및 브라우저로 검증한다.
- 단계 보고서와 함께 `Task #573 Stage 2: 홈페이지 Windows Linux 안내 링크`로 커밋한다.

## Stage 3 — 종합 검증과 PR

- 실제 native Cargo provenance와 Studio asset gate, 배지·workflow fixture, 기존 Pages 관련 검증, `git diff --check`를 수행한다.
- rhwp pin·제품 소스·릴리스 산출물 무변경, 원래 checkout 보존을 확인한다.
- 최종 보고와 오늘할일 완료 시각을 커밋한다. 검증된 body-file로 Open PR을 만들고 연결한다. merge·공개 배포는 수행하지 않는다.
