# Task M900 #518 최종 결과 보고서

## 결과

매 릴리스에서 재사용할 최초 설치 검증 workflow와 판정 helper를 구현했다. 새 GitHub-hosted VM의 환경 조사는 실제로 실행했고 Apple Silicon/Intel 모두 TXT 자동 검색을 통과했다. **실제 서명·공증 후보의 최초 설치·HWP/HWPX 검색은 아직 미실행이다.** 자동화 구현과 해당 후보의 수용 완료를 구분한다.

## 변경

- `install-environment-probe.yml`: 새 VM의 GUI·기존 등록·TXT 자동 색인 조사. 측정 job 성공이 후보 PASS가 되지 않는다.
- `release-first-install.yml`: workflow_dispatch/workflow_call 입력 6개로 같은 저장소의 성공한 release-publish 실행·artifact·소스 SHA·DMG SHA256·버전·빌드를 고정한다. fixture 생성과 arm64/Intel 설치 VM을 분리한다.
- `release-install-smoke.py`: artifact 출처·ZIP 경로·hash·서명·공증·universal/번들 검사, 표준 자동 첫 실행/종료 후 검색·33개 lifecycle·cleanup 증거를 연결한다. 실패·미실행·정리 실패는 release verdict를 통과하지 못한다.
- PR CI 판정 회귀와 최초 설치 운영 가이드, 공개 전 DMG 동일성 규칙을 추가했다.

## 검증

| 항목 | 결과 |
|---|---|
| [새 VM 환경 조사 34452311307](https://github.com/postmelee/alhangeul-macos/actions/runs/34452311307) | 두 아키텍처 ENVIRONMENT_READY |
| macOS 15.7.9 arm64 / image 20260829.0321.1 | GUI·TXT 자동 검색·소유 정리, 51.34초 |
| macOS 15.7.9 Intel / image 20260824.0482.1 | GUI·TXT 자동 검색·소유 정리, 34.12초 |
| 후보/증거 판정 회귀 | 11 PASS |
| 기존 Spotlight smoke 회귀 | 31 PASS |
| Python 구문·actionlint·git diff --check | PASS |
| 최종 PR CI | 게시 후 결과 보정 |
| 서명·공증 후보 설치 전체 실행 | 미실행 — 별도 릴리스 후보 필요 |

[보존한 환경 결과](assets/task_m900_518/environment-assessment.json), [Stage 1](../working/task_m900_518_stage1.md), [Stage 2](../working/task_m900_518_stage2.md), [Stage 3](../working/task_m900_518_stage3.md).

첫 조사 34451904493의 ENVIRONMENT_UNAVAILABLE은 임의 하위 폴더 mdutil unknown을 잘못 해석한 도구 오류였다. 볼륨 조회와 실제 TXT 양성 대조로 수정한 후 재실행했다. 시스템 색인 설정 변경 없이 통과했으며 첫 결과를 색인 비활성 근거로 사용하지 않는다.

## 재사용과 남은 조건

[운영 절차](../manual/release_first_install_guide.md)의 입력 6개를 매 릴리스 후보로 바꾸어 실행한다. 검증 도구 ref는 신뢰한 병합본을 사용하고 후보 소스 SHA와 구분한다. 후보 입력은 stable 숫자 버전/빌드로 제한한다.

현재 공개 workflow는 재실행하면 DMG를 다시 만들므로 draft PASS를 다음 공개 파일에 그대로 적용할 수 없다. 검증 파일 승격 또는 새 DMG의 공개 전 검증을 별도 릴리스 통합에서 확보해야 한다. 이 PR은 기존 publish workflow의 자동 차단을 변경하지 않는다.

일반 Applications 아래 소유한 고유 `.app` 경로를 검증하며 시스템 `/Applications/Alhangeul.app` 직접 설치 및 사용자 Finder 설치 경험과 구분한다. macOS 12, 실제 Spotlight 화면, Quick Look/Thumbnail GUI, 공개 Sparkle 업데이트는 이 자동화 결과로 대체하지 않는다. 후보 전체 실행 결과가 없으므로 #513 / #337 은 OPEN 유지한다. 공개 서명·공증 실행, 버전·tag·Release·Pages·appcast 변경은 하지 않았다.
