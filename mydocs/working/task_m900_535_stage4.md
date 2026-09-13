# Task M900 #535 Stage 4 — 비동기 요청 기록 관찰

## 보완과 판정

v0.2.2 실행 [34778130781](https://github.com/postmelee/alhangeul-macos/actions/runs/34778130781)의 Intel job은 전체 PASS, ARM job은 최초 설치·종료 후 검색을 통과하고 재설치 후 새 요청 기록이 즉시 보이지 않아 실패했다. 재실행 19:43:37.680Z와 cleanup 시작 19:43:39.549Z 사이에 본문/실제 importer 검사까지 완료되어, 비동기 요청·preferences 기록을 한 번만 확인하는 경합을 발견했다. 원본 실패는 제품 문제의 부재를 증명하지 않으며 그대로 보존한다.

재설치 시 요청 기록을 최대 30초 관찰한다. 이전 기록 유지 동안만 기다리고, 경로/빌드/mtime 불일치·읽기/형식 오류는 즉시 실패한다. 새 기록이 deadline 이후 보이거나 끝내 갱신되지 않아도 실패한다. 명령 실행·수동 등록·재색인·설정 쓰기는 추가하지 않았다. 검색·corpus·설치 객체 불변·cleanup 조건을 유지했다.

## 검증

- system smoke: 43개 PASS. 지연 기록 성공, 미갱신/늦은 기록 실패, 다른 경로·빌드·mtime 및 읽기·형식 오류 실패를 포함한다.
- install smoke: 25개 PASS.
- promotion: 16개 PASS.
- git diff --check: PASS.

ARM cleanup의 stale catalog 실패도 원본 증거에 보존한다. 이번 변경은 cleanup을 통과 처리하지 않는다. 검토된 main 반영 후 같은 v0.2.2 DMG로 양 VM을 새 실행해야 실제 보완 효과를 판정할 수 있다.
