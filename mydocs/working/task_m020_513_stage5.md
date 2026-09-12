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

## 검증 결과

- Swift 요청 정책/경로 파싱 7 tests PASS.
- 운영 회귀 24 tests 및 bundle 회귀 5 tests PASS.
- universal Release 빌드, portable/golden, strict ad-hoc, importer callback 검증 PASS.
- 180초 후보의 재실행 후 실제 제품 자동 요청, 앱 종료 상태의 영문/한글 검색과 automatic lifecycle 전체 PASS. 수정·보호·빈·손상·DRM·배포용·입력 크기·출력 잘림·삭제를 외부 mdimport -i 없이 확인했다.
- 최종 600초 후보는 새 direct 경로에 복사 후 한 번 실행하여 발견(launch 단계 477.52초) 및 자동 검색/후보 선택(8.25초) PASS. 설치 전 corpus 및 앱/importer hash·변경 시각 보존, 외부 등록/재색인/touch 없음. 정리 결과는 아래에 기록한다.
- CLI index 호출 2회는 verify 선행 요구로 거부됐다. 순서를 보정한 검증은 통과했으며 제품 실패와 구분한다.

## 정리 경계

180초 후보는 파일·문서·프로세스 제거와 원래 앱/provider 보존 후에도 삭제된 importer 경로가 목록에 남아 cleanup이 세 차례 MISS였다. 삭제 경로에 대한 NSWorkspace 변경 알림을 정리 진단으로 보냈으나 즉시 제거되지 않았다. 이후 별도 확인에서 소유 파일/프로세스 없음과 LaunchServices 경로 일치 0건을 확인했고, 최종 mdimport 목록에서도 제거되어 같은 cleanup이 PASS/cleaned가 됐다. 알림을 제거의 단독 원인으로 해석하지 않는다. 다음 최종 후보는 이 정리가 완료된 뒤 준비했다. 전역 초기화나 daemon 종료는 하지 않았다.

## 최종 후보의 첫 실행 결과

소스 기준은 `fa925292092a1dd9abbb5d617b966a9db3b2c6fd`이며 최종 개발 ZIP SHA-256은 `349df950c775733a45c613bc19d570de352540e954c26c5f1686d27faf874603`이다. 직전 시험의 catalog 정리까지 완료한 뒤 새 corpus/설치 경로를 준비했다.

- TXT 양성 대조 및 설치 전 본문 부재 PASS.
- 앱 복사·첫 실행 1회만 수행. importer가 약 7분 58초 뒤 발견됐고 앱의 재색인 요청 후 HWP3/HWP5/HWPX 영문 본문, HWP5/HWPX 한글 독립 단어 검색 및 대조군 제외 PASS.
- 실제 metadata 진단은 검색 성공 후 수행했고 세 형식 모두 새 후보 importer를 선택했다. `mdimport -t`를 색인 성공의 대체 근거로 사용하지 않았다.
- 앱 종료 후에도 같은 자동 검색·후보 선택 검증 PASS. 외부 등록·재색인·touch·재실행을 사용하지 않았으며 최초 corpus와 번들 hash/변경 시각이 관찰 전후 동일했다.
- 이 결과는 기존 설치/등록 이력이 있는 현재 Mac의 새 경로 첫 실행이다. 발견 지연 자체의 OS/설치 이력 원인은 확정하지 못했다. 별도 초기 계정/VM 및 공개 후보 검증의 대체가 아니다.


## 같은 경로 교체와 재개 검증 — 2026-09-10

최초 실행 state를 launch count 1, assisted action 없음으로 별도 고정한 뒤 같은 경로 교체를 시험했다. 표준 교체 helper의 시각 변경·일반 등록이 포함되므로 최초 설치 또는 공개 Sparkle 성공으로 합치지 않는다. 변경된 importer 시각에 대해 제품이 재색인 요청을 다시 접수한 로그를 확인했고 실제 후보 선택과 영문/한글 검색이 통과했다. 다음 날 재개 시 시험 앱이 실행 중이지 않음을 확인하고 `verify` → `index` 순서로 세 형식 추출·영문 3개·한글 2개 검색을 재확인했다.

이번 최종 후보의 Spotlight 양성 스크린샷은 확보하지 못했다. 닫힌 Spotlight 창 연결은 timeout이었고 Finder 대체 확인도 UI 상태 변경으로 완료되지 않았다. 이전 후보의 미검색 화면이나 선행 작업의 양성 화면을 이번 최초 실행 성공 화면으로 재사용하지 않는다. 첫 실행의 실제 검색·후보 선택 결과는 별도 보존한 state와 합성 JSON이 근거다.


## 최종 정리와 인계

2026-09-10 표준 cleanup에서 합성 검색 단어 7종의 소유 결과 0개, 원래 앱 hash/Quick Look·Thumbnail provider 보존, 시험 importer catalog 제거가 모두 PASS였다. 최종 상태는 cleaned이며 모든 Stage 5 시험 설치본과 corpus를 정리했다. HWP/HWPX 기본 연결도 기존 한컴 뷰어로 유지됐다. 공개 결과 JSON에는 합성 파일명과 판정만 남기고 계정 경로·원시 시스템 로그는 제외했다.

구현·개발 후보 검증은 리뷰 가능한 상태다. 공개 서명·공증 후보, 설치 이력이 없는 환경 및 macOS 12/Intel은 별도 출시 관문으로 남기고 #513 및 #337 이슈를 닫지 않는다.
