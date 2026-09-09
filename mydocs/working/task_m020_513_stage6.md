# Task M020 #513 Stage 6 — PR #515 리뷰 보정

## 승인과 기준

2026-09-10 작업지시자가 [리뷰](https://github.com/postmelee/alhangeul-macos/pull/515#issuecomment-5604725967) 보정 및 완료 코멘트 게시를 승인했다. 기준 head는 `365bb9c`다. #513 및 #337 이슈는 열린 상태를 유지하며 공개 배포·병합·버전 변경은 하지 않는다.

## 보정

1. 발견 조회 실패/잘못된 출력은 남은 deadline 안에서 재시도한다. 명령당 timeout은 30초와 남은 발견 시간 중 작은 값으로 제한하고 deadline 이후 응답은 수용하지 않는다. 종료 신호 처리의 기존 유예 2초는 유지한다.
2. catalog 파싱은 stdout만 사용하며 stderr는 null device로 분리한다. 두 출력이 합쳐지거나 pipe가 차서 교착하지 않는다. stderr 원문은 제품 로그에 게시하지 않는다. 공백/줄바꿈은 원래도 파싱 가능하며 문제가 된 것은 뒤에 섞인 진단 문장이다.
3. 앱 live 연결은 `LaunchMaintenanceService+App.swift`, 호출 순서 정책은 기존 서비스에 둔다. 같은 UserDefaults를 Spotlight 시작까지 전달하고 스케줄·발견·요청을 주입해 테스트에서 실제 mdimport나 사용자 설정을 사용하지 않는다.
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
- universal Release 개발 후보와 실제 자동 검색 smoke 결과는 추가 기록한다. Stage 5 첫 실행 성공은 당시 고정 후보의 기록으로 그대로 보존한다.
