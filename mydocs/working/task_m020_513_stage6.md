# Task M020 #513 Stage 6 — PR #515 리뷰 보정

## 승인과 기준

2026-09-10 작업지시자가 [리뷰](https://github.com/postmelee/alhangeul-macos/pull/515#issuecomment-5604725967) 보정 및 완료 코멘트 게시를 승인했다. 기준 head는 `365bb9c`다. #513 및 #337 이슈는 열린 상태를 유지하며 공개 배포·병합·버전 변경은 하지 않는다.

## 보정

1. 발견 조회 실패/잘못된 출력은 남은 deadline 안에서 재시도한다. 명령당 timeout은 30초와 남은 발견 시간 중 작은 값으로 제한하고 deadline 이후 응답은 수용하지 않는다. 종료 신호 처리의 기존 유예 2초는 유지한다.
2. catalog 파싱은 stdout만 사용하며 stderr는 null device로 분리한다. 두 출력이 합쳐지거나 pipe가 차서 교착하지 않는다. stderr 원문은 제품 로그에 게시하지 않는다. 공백/줄바꿈은 원래도 파싱 가능하며 문제가 된 것은 뒤에 섞인 진단 문장이다.
3. 앱 live 연결은 `LaunchMaintenanceService+App.swift`, 호출 순서 정책은 기존 서비스에 둔다. 같은 UserDefaults를 Spotlight 시작까지 전달하고 외부 동작(스케줄·발견·요청)만 Operations로 주입해 테스트에서 실제 mdimport나 사용자 설정을 사용하지 않는다. 유지보수 테스트는 실제 SpotlightReindexService.start를 통과하며 시작 호출 자체가 제거되면 실패한다.
4. 기존 Quick Look 유지보수 완료 기록이 있어도 Spotlight가 시작되는지와 최초 실행 시 순서를 검증한다. 시작 worker의 importer 존재 검사, 경로·빌드 전달과 접수 기록도 검증한다.
5. 제품의 importer URL 계산을 공통 함수로 두고 CI에서 먼저 빌드한 실제 HostApp 내부 bundle ID·실행 파일을 대조한다. Swift·shell·Python을 연결하는 신규 설정 생성기는 만들지 않는다.
6. smoke timeout 인자를 범위 검증 함수로 바꾸어 잘못된 입력이 600개 선택지를 출력하지 않게 한다. logger subsystem과 project 항목 순서도 주변 코드에 맞췄다.

## 수용하지 않은 범위

여러 앱 사본의 설치별 접수 기록 저장은 별도 정책과 기록 정리 설계가 필요해 이번에 확대하지 않았다. 단일 접수 기록의 제한은 유지한다. PID 재사용 경계는 재현된 결함이 없어 기존 종료 정책을 재설계하지 않았다.

## 검증

- Debug HostApp 빌드 PASS.
- Swift 정책·subprocess 출력 분리·호출 연결·실제 빌드 bundle 계약 17 tests PASS(기존 7 + 신규 10).
- Python 운영 26 tests PASS(기존 24 + 신규 2), bundle 5 tests PASS.
- 공유 Swift 경계 및 `git diff --check` PASS.
- universal Release ad-hoc 후보 빌드, strict 서명 무결성, 4개 universal 실행 파일 및 importer callback 13개 PASS. 후보 소스는 `7676b935a27cb87cbda630f1b87aef3cafa388b9`, ZIP SHA-256은 `04753c204cbd0c5731461a34a42512e69be79482143910cb2f7ee43c84be7f6a`다.
- 첫 시험: 설치 전 TXT 대조 13.61초, 첫 실행 발견 103.33초, 자동 본문 검색·실제 후보 선택 9.15초 PASS. 앱 종료 후 재검색도 2.47초 PASS. 실행 횟수 1·보조 조작 없음과 원본 corpus/번들 보존을 별도 state로 고정했다.
- 뒤이은 automatic lifecycle은 원본 영문·한글 삭제 반영까지 PASS였으나 `modified-restored`가 60초 내 검색되지 않아 FAIL이었다. TXT 대조는 정상이다. 이 실패를 최초 실행 성공과 합치거나 지우지 않는다. 재현/추가 대기 진단과 정리 결과를 추가 기록한다.
- 첫 cleanup은 소유 검색 결과·파일 제거와 기존 앱/provider 보존 PASS, 삭제된 importer catalog의 비동기 잔존 때문에 MISS였다. 같은 표준 cleanup으로 후속 확인한다. Stage 5 최초 실행 및 전파 성공은 당시 고정 후보의 기록으로 보존한다.


## 반복 설치/색인 관찰

첫 시험 정리는 최초 cleanup의 catalog MISS 이후 같은 표준 cleanup 재실행에서 PASS/cleaned였다. 이어 같은 7676b93 후보를 새 소유 경로에서 다시 시험했다. TXT 대조 12.02초, 자동 발견 330.72초 PASS였으나 본문 검색은 60초 내 0건으로 FAIL이었다. 실행 중인 정확한 후보 PID와 제품 로그를 대조해 해당 앱의 재색인 요청 접수를 확인했다. 파일/등록/앱 실행을 변경하지 않은 추가 180초 관찰도 FAIL이었다.

추가 대기 후 `verify` 진단은 세 형식 모두 실제 후보 importer를 선택하고 본문을 추출했다. 파일의 HWP/HWPX 콘텐츠 유형과 TXT 양성 대조는 기대대로였다. 재시도에는 최초 본문 검색 성공이 없어 lifecycle을 실행하지 않았다. 이 시험의 발견 대기 중 호출 연결 테스트를 강화하기 위한 Debug 빌드가 있었으므로 첫 시험과 완전히 통제된 시간 비교로 쓰지 않는다. 현재 Mac의 등록 이력·OS 색인 동작과 제품 결함의 원인은 확정하지 못했다. 추출/요청 성공을 자동 색인 성공으로 바꾸지 않는다.

Stage 6.1에서는 시작 함수를 mock으로 대체하지 않고 실제 시작 경로를 통과하도록 Operations 주입을 정리했다. 최종 소스는 `3aa2722937be50fdf094170d7cce95521e410d54`이며 Debug 빌드와 강화된 Swift 17개가 PASS다. 최종 Release 후보의 최초 실행과 모든 시험 정리 결과를 별도로 기록한다.


## 최종 소스 후보

3aa2722의 universal Release ad-hoc 개발 ZIP SHA-256은 `f9134bb199236fd0e9076270bd937008790f99d0266beb8aea74a813dacefa8d`다. 소유한 이전 시험의 정리가 끝난 뒤 빌드하고 새 경로에서 검증했다.

- TXT 대조 8.16초, 앱 복사 후 첫 실행의 자동 발견 370.01초, 본문 검색·실제 후보 선택 9.32초 PASS.
- 앱 종료 후 자동 검색/후보 선택 1.68초 PASS. HWP3/HWP5/HWPX 영문 3개, HWP5/HWPX 한글 2개와 대조군 제외를 확인했다.
- 첫 실행 1회·외부 등록/재색인/touch/재실행 없음, corpus 및 앱/importer hash·변경 시각 보존을 별도 state로 고정했다.
- 이 후보의 lifecycle은 반복하지 않았다. 중간 후보의 복원 실패와 새 경로 반복 설치 후 미검색은 그대로 미해결이며, 최종 최초 실행 성공으로 덮어쓰지 않는다. 현재 Mac의 기존 설치/등록 이력이 있으므로 깨끗한 초기 환경·공개 후보의 성공을 보증하지 않는다.


## 최종 정리와 인계

세 시험 모두 소유 앱·문서·프로세스·검색 결과·importer catalog 제거와 기존 앱 hash/provider 보존을 확인해 cleaned로 마쳤다. 최종 시험은 최초 cleanup과 두 번의 재확인에서도 catalog가 남았다. 읽기 전용 진단은 앱/문서 없음·프로세스 0·LaunchServices 경로 일치 0을 확인했고, 관찰 간격을 둔 다음 표준 cleanup에서 catalog 제거가 PASS였다. 원래 사용자 앱·기본 연결을 변경하거나 전역 index reset/daemon 종료를 하지 않았다.

[합성 결과 JSON](../report/assets/task_m020_513/review-reindex-results.json)은 최초 실행·반복 실패·추출 진단·정리 재시도를 구분하며 계정 경로/원시 로그를 포함하지 않는다. 리뷰 보정은 완료했으나 반복 설치/색인 재현성, 깨끗한 초기 환경, 공개 후보 검증은 #513 및 #337 이슈에 남는다. PR 본문과 보정 코멘트에서 최종 CI 결과를 별도 확인한다.
