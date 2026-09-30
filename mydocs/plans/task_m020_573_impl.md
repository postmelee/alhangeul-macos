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

## Stage 3.1 — PR CI 실패 후속 검증

2026-09-30 사용자가 PR #574의 실제 실패 로그 조사·범위 내 수정·검증·PR 갱신을 지시했다. `Script syntax checks` 실패는 기존 Spotlight 재설치 fixture의 설치 객체 비교에서 발생했다. Linux에서 삭제 직후 inode가 재사용될 수 있는 테스트 전제를 제거하고, 실제 재설치 smoke의 동일 객체 거부 gate는 유지한다. fixture 수정과 해당 경계 회귀 검증, 같은 CI step의 관련 검증을 수행한 후 보고·커밋·push한다. 새 head의 CI run을 확인하여 완료 대기 없이 링크를 전달한다. 모바일 링크 위치 제안은 이 CI 보정에 포함하지 않는다.

## Stage 3.2 — 모바일 플랫폼 링크 위치 보정

사용자가 모바일에서 헤더 추가를 부담스럽게 판단하고 다운로드 영역 아래 보조 링크와 기존 한 줄 헤더를 적용하도록 승인했으며, 같은 채팅에서 이어서 진행을 지시했다. 데스크톱 헤더의 기존 문구·링크를 유지하고 820px 이하에서는 숨긴다. 홈페이지의 릴리스 다운로드 버튼 아래에 짧은 보조 링크를 넣고, 나머지 하위 페이지에서는 기존 푸터(푸터가 없는 소식 페이지는 하단 안내)에 모바일 링크를 둔다. 각 화면에서 보이는 플랫폼 링크는 하나로 유지한다. 기존 제품 안내·다운로드 URL·pin을 보존하고 cache query를 갱신한다.

19개 페이지의 모바일/데스크톱 표시 위치·문구·URL, 한 줄 헤더 높이·겹침·잘림·푸터 가로 넘침을 검사하고 화면 증거·보고를 갱신한다. 기존 관련 Pages·배지·버전 안내 gate를 검증한 뒤 PR #574를 갱신한다. Stage 3.1 head `505a481`의 CI는 이어서 진행 시 조회에서 성공을 확인했다. 최종 새 head CI는 완료 대기 없이 run 링크만 전달한다. merge·공개 배포는 수행하지 않는다.

## Stage 3.3 — 승인된 병합과 Pages 배포

사용자의 `병합하고 배포해줘` 지시에 따라 PR #574의 정확한 head 검증 성공을 확인한 뒤 merge한다. `main`에는 타스크의 5개 커밋만 선별 반영하는 별도 PR을 만들어 병합한다. 다른 devel 앱 기능을 배포에 포함하지 않으며, public appcast를 보존하는 `Docs-only Pages Deploy`로 홈페이지를 공개한다. 공개 URL의 모바일 링크·헤더 배치와 기존 appcast 보존, source·pin 무변경, main/devel 콘텐츠 인계를 확인한 뒤 merge된 작업 브랜치·임시 worktree를 정리한다. 원래 `local/task567` checkout은 보존한다.
