# Task M020 #342 Stage 2 완료보고서

## 실제 색인·수정·삭제·교체 검증

## 실제 실행 결과

현재 macOS 26.5.2 arm64에서 격리 설치본의 실제 mdimport callback을 사용했다. HWP3/HWP5/HWPX 본문 추출 PASS. 파일의 UTI는 기존 한컴 선언 계열이 선택됐으며 importer의 9종 UTI 매핑으로 처리했다.

| 전환 | metadata 판정 | 실제 검색 전파 |
|---|---|---|
| 정상 본문 → 수정 본문 | 새 단어 존재·옛 단어 부재 PASS | MISS |
| 정상 → 암호 HWPX / 빈 HWPX | 이전 본문 미제공 PASS | MISS |
| 정상 → 손상 / DRM / 배포용 HWP | 이전 본문 미제공 PASS | MISS |
| 정상 → 32 MiB 초과 | 본문 미제공 PASS | MISS |
| 40만 한글 문자 | UTF-8 유효·1 MiB 이하 절단 PASS | MISS |
| 파일 삭제 | 시험 파일 삭제 수행 | 색인 삭제 전파 MISS |

일반 txt의 파일명·본문 양성 대조까지 검색되지 않았다. mdutil 루트는 enabled지만 실제 Documents의 Data 볼륨 상태는 unknown이다. 60초 polling과 앱 교체 후 재시도에도 검색 대조가 실패했다. 따라서 검색 성공·stale term 제거·삭제 전파·Finder 양성 화면을 보증하지 않는다. 코드 판정 실패를 숨기지 않고 환경 unavailable 및 각 검색 MISS를 상태 JSON에 기록했다.

## 앱 교체와 미실행

동일 버전 후보를 종료하고 시험 앱만 unregister/제거한 뒤 같은 개발 패키지를 복사했다. importer/app timestamp를 갱신하고 일반 lsregister 및 첫 실행을 거쳐 재발견 PASS. 교체 후 앱을 종료한 상태에서도 세 형식 metadata 추출 PASS. 이 과정은 공개 Sparkle 업데이트 또는 깨끗한 사용자 계정의 최초 설치 시험이 아니다.

## 도구 보완과 검증

- 경로 소유권/표시·symlink, txt 환경 대조 실패, mdimport -o 반복 실행, 제목을 본문으로 오인하지 않는 검사: 4 tests PASS.
- 기존 bundle 계약 3 tests, no-AppKit, YAML 및 diff PASS.
- 소유한 후보 앱 경로의 프로세스만 종료하며, 종료 확인 전 앱을 제거하지 않는다.
- 실패해도 cleanup 가능하도록 단계별 state를 저장한다. extraction-only 옵션은 검색을 PASS로 만들지 않는다.
- CI에는 환경 의존 시스템 색인 대신 경로·판정 회귀 검사를 연결했다.

## 인계

실제 검색 환경 복구와 일반 설치/공증 배포/macOS 12 검증은 출시 전 잔여 관문이다. 이번 범위에서 전역 색인 reset·기존 앱 교체·서비스 강제 종료를 하지 않는다. Stage 3에서 시험 등록·문서·앱을 정리하고 원래 설치/확장 상태를 대조한다.
