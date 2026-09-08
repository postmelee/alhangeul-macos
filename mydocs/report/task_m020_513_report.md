# Task M020 #513 조사·검증 결과보고서

## 현재 판정

**일반 최초 설치 수용 기준은 미완료다.** 수동 등록과 수동 재색인을 배제하는 검증 경로를 만들고 최초 발견 실패를 재현했다. 자동 발견 뒤 새로 만든 파일은 자동 검색됐지만 설치 전부터 있던 문서는 관찰 시간 내 검색되지 않았다. 제품 통합/패키징 문제와 동일 ID/버전의 개발 설치 이력 영향을 아직 확정적으로 구분하지 못했다.

이 보고서와 후속 PR은 검증 절차 보완 및 조사 결과를 제출한다. #513/상위 #337 종료나 v0.2.0 출시 승인을 의미하지 않는다.

## 변경 범위

- `spotlight-system-smoke.py`: automatic 모드, 실제 검색과 추출 진단의 순서 분리, 설치 전 txt 대조·본문 부재, corpus hash/수정 시각 유지, 첫 실행 횟수와 진단 조작 이력 검사.
- 동일 source의 앱/importer hash·디렉터리 시각을 복사 후 검증한다. direct 위치는 앱을 미리 만들지 않고 복사해 ditto 시각 조건을 보존하고 device/inode로 소유권을 검사한다. 부분 복사 실패에서도 소유 정리 식별값을 보존한다.
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

[합성 결과 JSON](assets/task_m020_513/initial-install-results.json)은 제품 판정·합성 파일명만 포함한다. 계정·로컬 경로·시스템 로그를 포함한 원시 state/evidence는 로컬 `build.noindex/task513`에 보존한다. 실제 Spotlight 양성 화면은 선행 #342의 증거이며 이번 일반 최초 설치 성공 화면으로 재사용하지 않았다.

## 정리와 검증

- 운영 회귀: 21 tests PASS (#342 기존/보완 12 + #513 9).
- bundle 회귀: 최종 선행 통합 후 5 tests PASS, source bundle 계약 PASS.
- Python 구문과 `git diff --check`: PASS.
- A/B/C/D/E/F: 소유 앱/문서/프로세스·LaunchServices·catalog 제거와 원래 앱 hash/provider 보존 PASS, 최종 cleaned.
- B/C에서는 파일과 LaunchServices 레코드가 제거된 뒤에도 catalog가 비동기로 남았다. 추가 대기와 동일 cleanup 재호출 후 제거됐다. 전역 reset, daemon 종료나 원본 패키지 삭제는 없었다.
- 최종 read-only 조회에서 실제 HWP/HWPX UTI의 기본 연결은 인계 시와 같은 한컴 뷰어였다. 등록되지 않은 소유 source 진단 사본도 제거했다. 원본 package/fixture와 사용자 앱은 보존했다.

## 출처와 재검증 관문

실행 바이너리 기준은 `489f5339820ea38602cfec49af949cd907cfd078`에 포함된 #341 패키지다. 앱 SHA-256은 `4c198d77a558b7523c9d2a935442c47b5d2feaef8e4ff21ebed3978c9b9034b5`, importer는 `c3230cad403408f060d23b7841b10354279cd0e47f420ce3e1bec26ec31fd3d8`이다. 두 원본 package 사본의 bytes와 strict 서명을 확인했다. source 시각 진단 사본도 bytes/서명은 동일하다.

#511 오류 진단 보완 `9930fa649b91bfcc0d6278cd1052dec64bb26f64`를 `07e1503`으로 cherry-pick했다. 최종 선행 #512 head `b3b1009bd75e1ca787d0adcf775f92fa350a0874`를 `91e2e12`로 통합했다. GitHub 재확인 시 #511/#512는 OPEN, devel은 `1a5eefb50db4aef01fc82bdb61eabeabf94b19ed`였다. 코드 변경분은 최종 선행 head와 분리해 비교할 수 있다. 실행 후보는 조사 조건을 고정한 이전 bytes이므로 최종 리뷰 보완과 최신 devel로 새로 만든 후보는 후속 PR 병합 전에 재검증해야 한다. 기존 수정/삭제/교체의 광범위한 본문 검증은 #342 근거를 재사용하며 이번 자동 최초 설치 통과를 대신하지 않는다.

새로운 설치 이력이 없는 환경과 최종 서명·공증 배포 후보의 일반 설치 검증이 남는다. macOS 12/Intel runtime은 미실행이다. 사용자 기존 앱/등록 이력을 제거하거나 공개 서명·공증·배포, Sparkle 업데이트, 버전 상향, PR merge 또는 이슈 close를 하지 않았다. 지원 문구와 출시 판단은 최초 설치 미해결 상태를 유지한다.
