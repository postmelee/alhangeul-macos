# Task M900 #523 Stage 4 — v0.2.2 통합 및 공개 반영

## 승인과 범위

2026-09-15 작업지시자가 최신 브랜치 통합·충돌 해결, 최신 릴리즈까지 화면 보정, 로컬 검증, PR #527 재검토·CI, devel 병합과 별도 Pages 공개 반영까지 승인했다. 같은 범위에서 구현·검증·병합·배포를 연속 수행한다.

통합 전 main은 `0e94a31fd80d9d3ad8016909a6d0d9cefb0d9189`, devel은 `c38d27c7d585f95436394a260e310f2f3948202c`이며 두 브랜치의 tree는 같았다. 원본 checkout과 앱 설치 환경은 변경하지 않았다.

## 보정

- 업데이트 홈의 최신 다운로드와 앱·Homebrew 배지는 실제 공개 v0.2.2로 정렬했다. 두 채널의 버전 차이 안내는 제거하고 설치/업데이트 탭·복사 UI를 유지했다.
- v0.2.2 상세의 소개 중복 안내를 작은 공개일로 바꾸고 앱 메뉴·Homebrew 링크를 간결하게 했다. 실제 GitHub 공개 시각 `2026-09-14T13:18:49Z`의 한국 날짜인 9월 14일을 사용했다.
- v0.2.2의 최초 색인 대기 안내, 저장·종료 보정 설명과 복구 목록 잔존을 포함한 알려진 한계를 유지했다.
- v0.2.1은 미공개 검증 후보로 보존하고 안내를 한 문단으로 정리했다. 공개일과 후보 DMG 링크를 추가하지 않았다.
- v0.1.11·v0.2.0의 공개일·당시 변경 사실·해당 버전 고정 다운로드와 최신 v0.2.2 배너를 보존했다. 최신 devel이 고정 URL로 보정한 과거 페이지의 헤더도 유지했다.
- 충돌 3개는 업데이트 홈, v0.1.11 헤더, 9월 13일 오늘할일이다. 최신 기록·릴리즈 목록과 기존 UI를 결합했고 다른 타스크 진행 기록을 되돌리지 않았다.
- CSS와 JavaScript는 기존에 검증한 bytes를 유지했다. 새 상세 페이지에 갱신된 CSS 키를 연결했다.

## 로컬 검증

| 항목 | 결과 |
|------|------|
| 실제 제공 버전 | Release v0.2.2, feed 0.2.2/build 20, tap 0.2.2 |
| 화면 | 업데이트 홈·v0.1.11·v0.2.0·v0.2.1·v0.2.2 × 1440/390/320px 15개 조합, 가로 넘침 없음 |
| 공개일 | 공개된 상세 3개의 날짜와 14px 보조 정보 유지, 후보에는 날짜 없음 |
| Homebrew 높이 | 세 너비 모두 298.57px, 탭 전환 시 두 줄 코드 높이 유지 |
| 키보드·복사 | End/Home 탭 선택 확인, 설치 클릭·업데이트 Enter 후 실제 붙여넣기 원문·개행 일치 |
| 내부 링크 | 원본·Pages artifact 각각 HTML 18개, 리소스/링크/fragment 218건, 누락·중복 ID 없음 |
| 다운로드 | v0.2.2 고정·latest DMG 각각 HTTP 200 |
| 기본 검사 | JavaScript 구문·배너 helper·diff 검사 PASS, 브라우저 경고/오류 없음 |
| appcast | 공개 원본 XML과 artifact의 XML·cmp PASS, 각각 1,161바이트와 SHA-256 일치 |

공개 원본·artifact SHA-256: `8b0face06819d65f60cc6e3675244eaa1cccead997927c1f27c131d523313140`. 임시 검증 원본은 `build.noindex/task523/v022/appcast-local.xml`이며 실제 배포용으로 재사용하지 않는다.

브라우저의 서로 다른 탭 사이 자동 붙여넣기는 가상 clipboard가 비어 있다고 실패했다. 같은 탭에서 실제 키 입력으로 붙여넣은 설치·업데이트 명령이 정확히 일치함을 확인했다. 버튼 성공 표시만으로 통과 판정하지 않았다. 기존 Stage 2.1의 실패·지연 응답·미지원 검증은 변경하지 않은 JavaScript에 대한 근거로 유지한다.

전체 페이지 캡처에서 스크롤 연결 부분이 중복되는 도구 문제가 있어 아래 증거는 같은 viewport의 첫 화면으로 다시 확보했다. 실제 DOM에 중복 ID/섹션은 없었다.

| 화면 | 변경 전 공개 화면 | 변경 후 로컬 화면 |
|------|-------------------|-------------------|
| 홈 · 데스크톱 | [화면](../report/assets/task_m900_523/v022-before-updates-desktop.jpg) | [화면](../report/assets/task_m900_523/v022-after-updates-desktop.jpg) |
| 홈 · 모바일 | [화면](../report/assets/task_m900_523/v022-before-updates-mobile.jpg) | [화면](../report/assets/task_m900_523/v022-after-updates-mobile.jpg) |
| v0.2.2 · 데스크톱 | [화면](../report/assets/task_m900_523/v022-before-v0.2.2-desktop.jpg) | [화면](../report/assets/task_m900_523/v022-after-v0.2.2-desktop.jpg) |
| v0.2.2 · 모바일 | [화면](../report/assets/task_m900_523/v022-before-v0.2.2-mobile.jpg) | [화면](../report/assets/task_m900_523/v022-after-v0.2.2-mobile.jpg) |

후보 보존 화면: [데스크톱](../report/assets/task_m900_523/v022-after-v0.2.1-desktop.jpg), [모바일](../report/assets/task_m900_523/v022-after-v0.2.1-mobile.jpg).

## 병합·배포 기록 경로

PR #527 최종 head의 CI를 확인하고 승인된 devel 병합을 수행한다. 그 후 main 대상 별도 Pages 반영 PR에서 전체 diff에 앱/릴리즈 변경이 섞이지 않는지 확인하고 CI·main/source content gate를 통과한 head를 병합한다. main docs push는 자동 배포를 실행한다.

배포 직전에 새 공개 feed를 받아 bytes/hash를 기록하고 Release·tap을 재확인한다. 배포 후 공개 feed 동일성, 공개 HTML·CSS·JavaScript와 배포 소스의 일치, 탭·복사·최신/과거/후보 화면을 확인한다. 실제 PR·배포 run·최종 결과는 해당 PR 본문과 #523 완료 기록에 연결한다. 완료 전까지 이슈는 열린 상태로 유지한다.
