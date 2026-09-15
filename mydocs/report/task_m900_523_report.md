# Task M900 #523 최종 결과보고서

## 완료 결과

2026-09-15 15:31 KST 기준 v0.2.2까지 업데이트 Pages 화면 보정과 공개 배포·사후 검증을 완료했다. [PR #527](https://github.com/postmelee/alhangeul-macos/pull/527)을 devel에 병합하고 [PR #553](https://github.com/postmelee/alhangeul-macos/pull/553)로 main에 공개 반영했다. 작업지시자가 2026-09-15 최신 통합·충돌 해결부터 검증·병합·Pages 공개까지 명시 승인했다.

업데이트 홈은 소개 한 문단과 작은 버전 배지를 사용하고, Homebrew 최초 설치·업데이트를 탭과 공통 복사 버튼으로 전환한다. v0.1.11·v0.2.0·v0.2.2 공개일은 14px 보조 정보로 표시하며 과거 고정 다운로드를 보존한다. v0.2.1 미공개 후보에는 날짜나 설치 파일을 추가하지 않았다. 최신 릴리즈의 색인 대기 안내·알려진 한계와 다른 타스크의 기록은 유지했다.

- [공개 업데이트 홈](https://postmelee.github.io/alhangeul-macos/updates/#homebrew)
- [공개 v0.2.2 상세](https://postmelee.github.io/alhangeul-macos/updates/v0.2.2.html)
- [Pages 배포 실행](https://github.com/postmelee/alhangeul-macos/actions/runs/34937144308)
- main 반영 commit: `b1cf47fde99f48161c87b87dd165c34c01192819`.
- 앱·Homebrew 제공 버전: v0.2.2. 앱 feed: 0.2.2 / build 20.

## 변경과 보존

| 대상 | 결과 |
|------|------|
| 업데이트 홈 | 중복 소개 제거, 실제 채널별 버전 배지, 간결한 메뉴 안내 |
| Homebrew | 처음 설치/업데이트 탭, 명령 원문 복사, 키보드 전환·피드백·실패 처리 |
| 상세 노트 | 작은 공개일, 공통 Homebrew 안내 링크, 과거 사실·고정 다운로드 보존 |
| 미공개 후보 | v0.2.1 상태 보존, 안내를 한 문단으로 정리 |
| 작성 매뉴얼 | 위계·버전 출처·복사 접근성·공개 feed 보존 규칙 |

탭은 선택한 명령만 표시하고 두 줄 코드 높이를 유지한다. Homebrew section 높이는 1440/390/320px 모두 298.57px이며 탭 전환으로 아래 내용이 이동하지 않는다. JavaScript 미실행 시 두 명령을 모두 표시한다. 늦게 도착한 이전 탭의 복사 응답은 현재 탭의 안내를 덮어쓰지 않는다.

## 검증

| 구분 | 결과 |
|------|------|
| 로컬 화면 | 홈·v0.1.11·v0.2.0·v0.2.1·v0.2.2 × 1440/390/320px 15개 조합, 가로 넘침 없음 |
| 로컬 링크 | 원본·artifact 각각 HTML 18개, 내부 링크·리소스·fragment 218건 정상 |
| 다운로드 | 변경 대상 최신·과거 Release/DMG 링크 8개 HTTP 200 |
| 복사 | 로컬·공개 페이지 모두 설치/업데이트 버튼 실행 후 실제 붙여넣기 값과 LF 일치 |
| 키보드·예외 | 최종 End/Home 전환 확인, 변경 없는 JS의 기존 방향키·Tab·권한 거부·미지원·지연 응답·no-script 검증 유지 |
| 공개 소스 | HTML 5개·CSS·JavaScript 공개 응답 bytes가 배포 소스와 정확히 일치 |
| appcast | 로컬 조립·공개 배포 전후 XML·bytes·SHA-256 일치 |
| CI | [PR #527 CI](https://github.com/postmelee/alhangeul-macos/actions/runs/34935668186), [main PR CI](https://github.com/postmelee/alhangeul-macos/actions/runs/34936372526) 성공 |

공개 배포 직전에 새로 받은 appcast와 배포 후 원본은 각각 1,161바이트, SHA-256 `8b0face06819d65f60cc6e3675244eaa1cccead997927c1f27c131d523313140`로 동일하다. 저장소 feed 대체·재생성·재직렬화 없이 기존 Docs-only Pages Deploy를 사용했다. 앱 소스·버전·tag·Release 자산·tap·workflow 구현을 추가 변경하지 않았다.

브라우저 가상 clipboard의 서로 다른 탭 사이 붙여넣기 제한은 같은 탭의 실제 키 입력으로 검증했다. 전체 페이지 캡처의 스크롤 연결 오류는 viewport 캡처로 보정했다. 모의 예외 검증과 실제 복사 검증을 구분하며 상세 근거는 단계 보고서에 남겼다.

## 화면과 단계 기록

| 화면 | 변경 전 | 최종 |
|------|---------|------|
| 업데이트 홈 | [데스크톱](assets/task_m900_523/v022-before-updates-desktop.jpg) | [데스크톱](assets/task_m900_523/v022-after-updates-desktop.jpg) |
| v0.2.2 상세 | [모바일](assets/task_m900_523/v022-before-v0.2.2-mobile.jpg) | [모바일](assets/task_m900_523/v022-after-v0.2.2-mobile.jpg) |

- [수행계획](../plans/task_m900_523.md), [구현계획·공개 승인](../plans/task_m900_523_impl.md)
- [Stage 1](../working/task_m900_523_stage1.md): 소개·공개일·배지
- [Stage 2·2.1](../working/task_m900_523_stage2.md): 명령 복사·탭 전환
- [Stage 3](../working/task_m900_523_stage3.md): 작성 규칙·v0.2.0 준비 시점 검증
- [Stage 4](../working/task_m900_523_stage4.md): v0.2.2 통합·공개 반영

## 인계

향후 릴리스에서는 실제 Release·앱 feed·Homebrew 버전과 공개일을 확인해 정적 안내를 갱신하고 기존 Pages 작성 규칙을 적용한다. 로컬 미리보기는 사용자 확인을 위해 유지한다. 원본 checkout과 설치 앱은 변경하지 않았으며, 앱 릴리스 자체의 검증·종료 기록은 각 릴리스 타스크의 소유 범위를 유지한다.
