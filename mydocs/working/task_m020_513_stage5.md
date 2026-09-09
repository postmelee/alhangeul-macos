# Task M020 #513 Stage 5 — 첫 실행 재색인 요청 구현과 실제 검색 검증

## 기준과 원인 분리

선행 PR #507–#512 및 #514가 병합된 devel `56fe1ca`에서 재개했다. macOS 26.5.2 / Apple Silicon, universal Release ad-hoc 개발 패키지이며 버전은 0.1.11 (17)을 유지한다. 기존 사용자 앱 두 개와 한컴 기본 연결을 보존한다. 작업지시자는 설치 이력이 없는 별도 계정/VM도 없다고 확인했으므로 깨끗한 초기 환경 검증은 미실행이다.

| 비교 | 관찰 |
|---|---|
| TXT 직접 생성 / fixture 복사 | 모두 자동 검색. 직접 생성 TXT는 관찰 시작 12.2초에 발견. 이전 Stage 4의 TXT 실패는 재현되지 않음 |
| 변경 전 최신 후보, 새 direct 설치 | 첫 실행 후 12.13초에 importer 발견. 설치 전 HWP3/HWP5/HWPX는 60초 및 설치 후 약 549초 추가 조회에도 본문 미검색; TXT는 검색됨 |
| 외부 LSRegisterURL 단독 | 반환 0, 기존 본문은 추가 60초 미검색 |
| 최소 App Sandbox 진단 | LSRegisterURL은 -10819, 발견된 importer에 대한 mdimport -r은 종료 0. 기존 세 형식 영문 본문·두 형식 한글 검색, 실제 후보 추출, 앱 종료 후 검색 PASS |
| 첫 구현 후보: 발견 전 요청 | 앱의 자동 요청은 접수됐지만 발견은 첫 실행 60.83초 MISS, 이어 56.75초에 PASS. 기존 본문은 60초 미검색. 명령 접수만 완료 처리하면 안 됨을 확인 |

Apple의 [importer 안내](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/MDImporters/Concepts/Troubleshooting.html)는 첫 실행의 발견과 기존 파일 색인, importer별 `mdimport -r` 요청을 설명한다. 현재 OS의 `man mdimport`도 -r을 해당 importer가 처리하는 UTI의 재색인 요청으로 명시한다. SDK에서 -10819는 kLSNotRegisteredErr다. 앱 안팎의 반환 차이만으로 모든 발견 실패를 이 오류 하나로 단정하지 않는다.

첫 샌드박스 진단 실행 파일에는 서명용 Info.plist 정보가 없어 libsecinit 초기화에서 종료됐다. 본체 실행 전 실패로 분류하고 식별 정보를 보완한 별도 진단만 유효 결과로 사용했다. 진단 실행 파일 추가와 외부 등록은 assisted 이력에 기록했고 자동 설치 성공으로 사용하지 않았다.

180초 대기 후보는 추가 관찰에서 105.38초 후 발견되어 첫 실행부터 약 286초가 걸렸다. worker는 이미 대기를 마쳤으므로 기존 문서가 검색되지 않았다. 같은 후보를 재실행하자 제품 코드의 발견 확인과 재색인 요청이 접수됐고 세 형식 영문 및 두 형식 한글 본문 검색이 통과했다. 이 결과는 재실행 성공으로 분류한다. 최종 후보는 관찰된 지연을 반영해 대기를 600초로 늘렸다.

## 구현

- SpotlightReindexService가 메인 스레드 밖에서 최대 600초 동안 자기 importer의 발견을 확인한 후 `/usr/bin/mdimport -r`을 요청한다. 일반 앱 등록/Quick Look 유지보수 완료 기록과 별개로 실행한다.
- `mdimport -L`의 OpenStep 배열을 파싱해 정확한 경로를 비교한다. 공백/한글 escape와 directory URL을 처리하며, 형식이 다르거나 조회에 실패하면 완료로 기록하지 않는다.
- 설치 경로·빌드·importer 변경 시각별 요청 접수를 기록한다. 발견 실패·명령 실패·timeout은 다음 앱 실행에서 재시도한다. 접수 로그는 비동기 색인 완료를 뜻하지 않는다.
- App Sandbox entitlement, 원본 문서, 기본 앱 연결, 전체 볼륨 색인은 바꾸지 않는다. 임시 명령 출력은 앱의 임시 위치에만 저장하고 제거하며 제품 로그에는 본문/경로를 넣지 않는다.
- automatic lifecycle에서 외부 `mdimport -i` 호출을 제거했다. 기존 진단 모드는 유지한다. 발견 대기 시간은 prepare의 `--discovery-timeout`으로 기록하며 기본 60초, 180초 후보와 최종 600초 후보를 구분한다. 과거 60초 실패를 소급 변경하지 않는다.

## 검증 진행

- Swift 요청 정책/경로 파싱 7 tests PASS.
- 운영 회귀 24 tests 및 bundle 회귀 5 tests PASS.
- universal Release 빌드, portable/golden, strict ad-hoc, importer callback 검증 PASS.
- 180초 후보의 재실행 후 실제 제품 자동 요청, 앱 종료 상태의 영문/한글 검색과 automatic lifecycle 전체 PASS. 수정·보호·빈·손상·DRM·배포용·입력 크기·출력 잘림·삭제를 외부 mdimport -i 없이 확인했다.
- 최종 600초 후보의 새 경로 첫 실행 및 정리 결과는 다음 검증에서 확정한다.
- CLI index 호출 2회는 verify 선행 요구로 거부됐다. 순서를 보정한 검증은 통과했으며 제품 실패와 구분한다.
