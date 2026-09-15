# Task #558 최종 구현 보고

## 결과

자동 수집을 켜지 않고 운영자가 선택한 기존 공개 Threads 글 6개를 표시하는 수동 모드를 구현했다. 홈은 최신 1개, 최신 소식 페이지는 5개씩 추가 표시한다. 원문은 공식 임베드로 제공되며 본문·사진·영상·oEmbed HTML을 저장하지 않는다.

- 수동 원천: `docs/data/news-manual.json`, v3 manual 링크 목록.
- 자동 v2의 새 수집·48시간 만료·실패 보존 정책 유지.
- 수동은 토큰·API 없이 조립되며 시간이 지나도 목록이 만료되지 않는다. 원문 접근 제한은 Threads가 처리하고, 목록 변경은 운영자가 수행한다.
- Docs-only와 Release Pages 양 경로에 연결, appcast bytes 보존.

## 문의 제출

[Meta 개발자 커뮤니티 문의](https://developers.facebook.com/community/threads/1389361209839223/)를 Platform Policy에 게시했다. 게시 직후 해결되지 않음 상태이며 답변 기한은 제시되지 않았다. AI 도우미 답변과 커뮤니티 게시를 Meta의 개별 승인으로 간주하지 않는다. 정식 앱 심사는 제출하지 않았다.

## 검증

| 범위 | 결과 |
|---|---|
| 기존 수집 | 43개 PASS |
| Pages 통합·수동/자동 경계 | 14개 PASS |
| UI 데이터·시간 경과 | 9개 PASS |
| 브라우저 회귀 | 21/21 PASS |
| 공식 oEmbed | 인증 없는 6개 응답 PASS |
| 실제 브라우저 | 홈1, 피드5+1, 본문·전체 높이 PASS |
| workflow/shell/diff | actionlint·구문·공백 검사 PASS |
| 로컬 Pages appcast | 입력과 bytes 동일 |

## 운영 및 공개 반영

`THREADS_NEWS_ENABLED=false`를 유지한다. 신규 게시물은 목록 수정·배포로 추가한다. 수동 모드가 있으므로 false 설정만으로 전체 글이 숨겨지지 않으며 중단 시 수동 items도 비워야 한다.

작업지시자가 구현부터 공개 배포까지 연속 진행을 승인했다. devel PR과 main 배포 PR의 CI 성공 후 공개 반영한다. 실제 배포 SHA/run·공개 목록·appcast 검증 결과는 배포 PR에 기록한다.
