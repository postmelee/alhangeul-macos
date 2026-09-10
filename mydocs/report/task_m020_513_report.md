# Task M020 #513 조사·자동 재색인 구현 결과보고서

## 현재 판정

**최종 개발 후보의 병합 전 복원·변경·삭제 및 새 경로 반복 설치 재검증을 통과했다. 공개 최초 설치 수용 기준은 아직 미완료다.** 제품 소스 3aa2722의 동일 universal Release ad-hoc 0.1.11(17) 패키지를 두 새 경로에서 검증했다. 제품 bytes는 변경하지 않았다.

| 검증 | 첫 설치 시험 | 새 경로 반복 설치 |
|---|---|---|
| importer 자동 발견 | 101.23초 PASS | 273.17초 PASS |
| 본문 검색·실제 후보 선택 | 6.40초 PASS | 29.89초 PASS |
| 앱 종료 후 검색·후보 선택 | 2.82초 PASS | 28.16초 PASS |
| 완료된 전체 lifecycle | 재시도 33개 PASS, 최장 검색 10.43초 | 33개 PASS, 최장 검색 40.65초 |

두 최초 실행 snapshot은 각각 실행 1회·보조 조작 없음·설치 전 corpus와 후보 bytes/시각 보존을 확인한다. HWP3/HWP5/HWPX 영문 3개와 HWP5/HWPX 한글 2개가 검색됐으며 [Finder 영문 검색](assets/task_m020_513/final-finder-body-search.png)과 [한글 검색](assets/task_m020_513/final-finder-korean-search.png)을 첨부한다. 별도 Spotlight 검색 패널 화면은 미확보다.

첫 설치 시험의 첫 lifecycle 시도는 복원 대기 중 mdfind 30초 무응답으로 실패했다. 파일을 보존한 뒤 HWP와 새 TXT가 추가 재색인 없이 늦게 검색됐다. 조회 오류 기록·남은 시간 내 재시도·검색 한도/경과 시간·실제 TXT 대조를 검증 도구에 추가했고 운영 회귀 31개가 통과했다. 전체 lifecycle을 다시 실행한 결과와 최초 실패를 구분한다. 이번 관찰로 Stage 6의 모든 실패 원인을 확정하지 않는다.

또한 사전 시험에서는 다른 작업의 Debug importer가 후보 설치 전 한글 문서를 처리했다. 작업지시자 승인으로 해당 작업의 빌드·실행 보류 및 소유 등록 제거를 조율한 뒤 위 두 시험을 시작했다. 이 사전 결과는 최종 후보의 성공 증거가 아니다.

세 시험 모두 소유 파일·프로세스·검색 결과·importer catalog 정리를 통과했고 기존 앱 hash/provider·기본 연결이 보존됐다. #516 작업에는 검증 재개를 전달했다.

최신 근거는 [Stage 7](../working/task_m020_513_stage7.md)과 [합성 결과 JSON](assets/task_m020_513/final-scenario-results.json)이다. Stage 5~6 당시 검증·실패는 아래에 보존한다. Swift 17개·bundle 5개·importer callback 13개·Debug/Release 빌드는 제품 소스가 같은 Stage 6 결과를 사용한다. 최신 head CI 결과는 PR #515 Checks와 보완 코멘트에 기록한다.

#513 및 상위 #337 이슈는 열린 상태를 유지한다. 설치 이력이 없는 계정/VM, macOS 12/Intel, Developer ID·공증·Gatekeeper·공개 Sparkle 검증은 남은 출시 관문이다. 현재 Mac의 개발 후보 성공으로 대체하지 않는다.

## Stage 6 당시 판정

**공개 최초 설치 수용 기준은 아직 미완료다.** PR #515 리뷰 보정(Stage 6)은 발견 조회의 일시 실패 재시도, stdout/stderr 분리, 설정 주입·실제 호출 연결 및 빌드 bundle 경로 검증을 추가했다. Swift 17개·Python 운영 26개·bundle 5개 및 importer callback 13개, Debug/universal Release 개발 후보 검증을 통과했다.

최종 소스 `3aa2722`의 universal Release ad-hoc 후보는 현재 Mac 새 경로의 첫 실행에서 자동 발견 370.01초, 본문 검색·실제 후보 선택 9.32초에 통과했다. 앱 종료 후에도 검색됐으며 실행 횟수 1·외부 보조 없음·원본 corpus/번들 보존을 확인했다. 앞선 보정 후보 `7676b93`도 첫 시험의 최초 실행은 통과했으나, 뒤이은 수정/삭제 시험은 삭제 반영 후 원본 복원이 60초 내 재검색되지 않아 실패했다. TXT 대조는 정상이다. 같은 후보를 새 경로에 다시 설치한 시험은 자동 발견·제품 재색인 요청 접수 후에도 60초 및 추가 180초에 본문이 검색되지 않았다. 이후 실제 후보 추출은 세 형식 모두 통과했다. 반복 설치·색인의 원인은 미확정이며 이 실패들을 최초 실행 성공과 분리해 보존한다.

모든 Stage 6 시험은 파일·프로세스·검색 결과·catalog 정리와 기존 앱/provider 보존 PASS(cleaned)로 마쳤다. 최종 시험의 catalog 잔존은 관찰 간격을 두고 같은 cleanup을 재실행한 뒤 해소됐다.

최신 근거는 [Stage 6](../working/task_m020_513_stage6.md) 및 [보정 후보 JSON](assets/task_m020_513/review-reindex-results.json)이다. [Stage 5](../working/task_m020_513_stage5.md)와 [당시 결과 JSON](assets/task_m020_513/launch-reindex-results.json)은 이전 후보의 최초 실행·전파/교체 결과다. 아래 Stage 1–4도 조사 PR #514 까지의 과거 기록이다.

#513 및 상위 #337 이슈는 열린 상태를 유지한다. 별도 초기 계정/VM, macOS 12/Intel 실행 환경이 없고 서명·공증 공개 후보는 별도 릴리스 관문이다.

## Stage 5 보완과 검증 범위

제품은 자신의 importer가 발견된 다음 기존 문서 재색인을 요청하고, 설치 경로·빌드·importer 변경 시각이 같으면 중복 요청을 생략한다. 최대 600초 발견 대기 또는 명령 실패 시 다음 실행에 재시도하며 메인 스레드를 막지 않는다. 접수 완료는 색인 완료를 뜻하지 않는다.

Swift 정책/파싱 7개, Python 운영 24개·bundle 5개, importer callback 13개와 universal Release ad-hoc 패키지 검증을 통과했다. 자동 수정·보호·삭제 전파는 180초 대기 후보 재실행 후 앱 종료 상태에서 검증했고, 최종 후보와의 제품 차이는 발견 대기 180→600초다. 최종 후보는 별도 첫 실행 증거를 고정한 후 같은 경로 로컬 교체도 통과했다. 2026-09-10 재개 시 앱 종료 상태의 실제 후보 선택·영문 3개·한글 2개 검색이 다시 통과했다. 로컬 교체는 표준 helper의 보조 등록/시각 변경을 포함하므로 공개 Sparkle 성공으로 해석하지 않는다.

최종 후보의 UI 양성 화면은 도구 연결 문제로 미확보다. 이전 후보 화면을 대체 첨부하지 않았다. 실제 검색 명령 결과와 최초 실행/교체 결과를 분리한 JSON을 제공한다.

2026-09-10 최종 정리는 소유 검색 결과·파일·프로세스·importer catalog 제거와 기존 앱 hash/provider 보존 모두 PASS(cleaned)다. 기본 연결은 기존 한컴 뷰어로 유지됐다. 구현·개발 후보 검증을 [PR #515](https://github.com/postmelee/alhangeul-macos/pull/515) 리뷰 대상으로 제출하며 공개 릴리스는 아직 진행하지 않았다.

## Stage 1–4 변경 범위

- `spotlight-system-smoke.py`: automatic 모드, 실제 검색과 추출 진단의 순서 분리, 설치 전 txt 대조·본문 부재, corpus hash/수정 시각 유지, 첫 실행 횟수와 진단 조작 이력 검사.
- 동일 source의 앱/importer hash·디렉터리 시각을 복사 후 검증하고 자동 검색의 대기 전후에도 다시 대조한다. 관찰 중 corpus 변경과 이력에 없는 외부 touch/교체도 통과를 막는다. direct 위치는 앱을 미리 만들지 않고 복사해 ditto 시각 조건을 보존하고 device/inode로 소유권을 검사한다. 부분 복사 실패에서도 소유 정리 식별값을 보존한다.
- `diagnostic-register`는 시각 변경·재복사 없이 일반 사전 등록 한 조건만 비교한다. 진단/교체/문서 변경 이후의 결과는 일반 최초 설치 통과로 인정하지 않는다.
- 발견 경과 시간, 실행 횟수, 단계 예외를 state에 남긴다. #511 실패/timeout 출력 보존 보완과 신규 회귀 4개를 재사용했다.
- 빌드 가이드, 계획/단계 보고서와 합성 결과를 갱신했다. 앱·Rust 추출 구현, 버전과 서명 정책은 변경하지 않았다.

## 실제 관찰

macOS 26.5.2 / arm64에서 #341 universal Release ad-hoc 개발 후보를 사용했다. 각 시험은 이전 소유 앱/문서/프로세스와 importer catalog 제거를 확인한 뒤 시작했다. 기존 사용자 앱 두 개와 기본 연결은 변경하지 않았다. 동일 bundle ID/버전의 시스템 등록 이력을 초기화하지 않았으므로 새 사용자 환경과 같다고 해석하지 않는다.

| 실행 | 조건과 결과 |
|---|---|
| A | 기존 표준 절차의 새 중첩 경로: 일반 txt PASS, 사전 일반 등록 뒤 60초와 첫 실행 뒤 60초 발견 MISS |
| B | 동일 bytes/mtime, 새 중첩 경로, 수동 등록/재색인 없는 첫 실행: 36.28초 발견 PASS, 세 형식 실제 후보 추출 PASS |
| B 기존 파일 | 설치 전 HWP3/HWP5/HWPX 본문 검색: 60초 및 앱 종료 후 추가 180초 관찰 FAIL |
| B 새 파일 | 발견 후 새 HWP 하나를 생성하면 수동 색인 없이 그 파일만 검색 PASS |
| C | 초기 direct 복사의 root 선생성 혼입으로 순수 위치 비교에서 제외. 첫 실행 60초와 추가 60초 발견 MISS |
| C 누적 진단 | 재등록만: 60초 MISS. 이어 importer 시각만: 60초 MISS. 이어 app 시각 추가 갱신: 14.16초 발견 PASS. 재복사·재실행 없이 발견됐으나 단독 요인 증거는 아님 |
| C 기존 파일 | 시각 갱신 후 실제 후보 추출 PASS, 기존 파일 본문 검색 60초 FAIL. 앱 재실행 뒤에도 60초 FAIL |
| D | source importer 시각만 복사 전에 갱신한 새 중첩 경로: 첫 실행 60초 발견 MISS, 추출 진단 no plugIn |
| E | D source에서 앱 시각만 추가 갱신한 새 중첩 경로: 첫 실행 60초 발견 MISS, 추출 진단 no plugIn. 추가 무조작 180초 관찰도 MISS |
| F | 수정된 direct 복사: 원본 앱/importer hash와 두 디렉터리 시각 일치 PASS. 수동 등록/색인 없는 첫 실행 60초 발견 MISS, 본문 검색 미실행 |

A와 B는 사전 등록 외에 baseline 수동 색인 및 실행 전 대기도 다르다. B 한 번의 발견 성공만으로 사전 등록을 원인으로 단정하지 않는다. D/E의 source 시각 변경은 진단이며 일반 최초 설치 통과로 사용하지 않는다. B의 corpus snapshot 보강 경위와 C 복사 조건 수정은 [Stage 2](../working/task_m020_513_stage2.md)에 기록했다.

[합성 결과 JSON](assets/task_m020_513/initial-install-results.json)은 제품 판정·합성 파일명만 포함한다. 계정·로컬 경로·시스템 로그를 포함한 원시 state/evidence는 로컬 `build.noindex/task513`에 보존한다. 실제 Spotlight 양성 화면은 선행 #342 이슈의 증거이며 이번 일반 최초 설치 성공 화면으로 재사용하지 않았다.

## 정리와 검증

- 운영 회귀: 23 tests PASS (#342 기존/보완 12 + #513 11).
- bundle 회귀: 최종 선행 통합 후 5 tests PASS, source bundle 계약 PASS.
- Python 구문과 `git diff --check`: PASS.
- A/B/C/D/E/F: 소유 앱/문서/프로세스·LaunchServices·catalog 제거와 원래 앱 hash/provider 보존 PASS, 최종 cleaned.
- B/C에서는 파일과 LaunchServices 레코드가 제거된 뒤에도 catalog가 비동기로 남았다. 추가 대기와 동일 cleanup 재호출 후 제거됐다. 전역 reset, daemon 종료나 원본 패키지 삭제는 없었다.
- 최종 read-only 조회에서 실제 HWP/HWPX UTI의 기본 연결은 인계 시와 같은 한컴 뷰어였다. 등록되지 않은 소유 source 진단 사본도 제거했다. 원본 package/fixture와 사용자 앱은 보존했다.

## 출처와 재검증 관문

실행 바이너리 기준은 `489f5339820ea38602cfec49af949cd907cfd078`에 포함된 #341 패키지다. 앱 SHA-256은 `4c198d77a558b7523c9d2a935442c47b5d2feaef8e4ff21ebed3978c9b9034b5`, importer는 `c3230cad403408f060d23b7841b10354279cd0e47f420ce3e1bec26ec31fd3d8`이다. 두 원본 package 사본의 bytes와 strict 서명을 확인했다. source 시각 진단 사본도 bytes/서명은 동일하다.

#511 오류 진단 보완 `9930fa649b91bfcc0d6278cd1052dec64bb26f64`를 `07e1503`으로 cherry-pick했다. 최종 선행 #512 head `b3b1009bd75e1ca787d0adcf775f92fa350a0874`를 `91e2e12`로 통합했다. GitHub 재확인 시 #511/#512 PR은 OPEN, devel은 `1a5eefb50db4aef01fc82bdb61eabeabf94b19ed`였다. 코드 변경분은 최종 선행 head와 분리해 비교할 수 있다. A–F 실행 후보는 조사 조건을 고정한 이전 bytes였다. 병합 전 최신 개발 후보의 재검증은 아래 Stage 4에서 별도로 수행했다. 기존 수정/삭제/교체의 광범위한 본문 검증은 #342 근거를 재사용하며 이번 자동 최초 설치 통과를 대신하지 않는다.

새로운 설치 이력이 없는 환경과 최종 서명·공증 배포 후보의 일반 설치 검증이 남는다. macOS 12/Intel runtime은 미실행이다. 사용자 기존 앱/등록 이력을 제거하거나 공개 서명·공증·배포, Sparkle 업데이트, 버전 상향, PR merge 또는 이슈 close를 하지 않았다. 지원 문구와 출시 판단은 최초 설치 미해결 상태를 유지한다.

## 병합 전 최신 후보 재검증 — 2026-09-09

[Stage 4](../working/task_m020_513_stage4.md)에서 CI rg 의존 제거와 최종 보완 코드를 통합한 universal Release 개발 패키지를 새로 만들었다. portable source/ABI·빌드·strict ad-hoc 서명·직접 callback 13개·운영 23개·bundle 5개 검증은 통과했다.

새 direct 격리 시험에서는 일반 TXT 대조가 60초 내 자동 검색되지 않아 환경 전제에서 중단했다. 앱 설치·첫 실행·기존 문서 자동 검색은 미실행이며 importer 실패 또는 최초 설치 성공으로 해석하지 않는다. 시험 경로·프로세스·catalog 정리와 기존 앱/provider 보존은 통과했다. [최신 후보 결과 JSON](assets/task_m020_513/pre-merge-candidate-results.json)에 실행 기준과 결과를 분리했다. #514 조사 PR 병합은 이 도구·기록의 통합이며 #513 및 #337 이슈의 해결 판정은 아니다.
