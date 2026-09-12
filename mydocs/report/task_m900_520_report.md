# Task M900 #520 릴리스 준비 결과보고서

## 결과와 범위

[PR #521](https://github.com/postmelee/alhangeul-macos/pull/521)에서 v0.2.0/18 준비와 동일 DMG 공개 자동화를 구현하고, PR #524 / #526 에서 실제 API·후보/도구 분리 gate를 보완했다. 2026-09-13 동일 공증 후보를 공개했고 Pages/Sparkle 배포와 실제 0.1.11→0.2.0 다운로드·설치·자동 재실행·Finder를 확인했다. **공개는 완료됐지만 전체 수용 완료 보고는 아니다.** 이전 버전 상태를 재구성한 업데이트의 기존 문서 자동 검색은 PASS지만, 동일 버전 재설치의 과거 요청 기록 처리는 남아 #520 / #513 / #337 은 유지한다. [Stage 5 진행 기록](../working/task_m900_520_stage5.md)에 공개 근거와 성공·미해결 범위를 구분한다.

양 아키텍처 새 VM 최초 설치는 같은 attempt 3에서 전체 PASS이며 앞선 환경 실패를 보존했다. 실제 Mac의 직접 설치·Spotlight·종료 후 검색·저장·내보내기·Finder도 확인했다. #525 복구 후보 잔존과 최소 macOS 12 미검증은 알려진 한계로 공개 승인을 받았으며, 동일 버전 재설치에서 관찰한 누락은 별도 후속 수용 범위다. 과거 LaunchServices 등록 41개로 전체 등록 위생 MISS였던 이력도 유지한다.

기준은 devel 41efb1770ae7a464c9cf766fe001c2da79a95823, 직전 공개 v0.1.11/17이다. core/Studio v0.8.6은 유지하며 PR #517 까지 포함한다. 변경 근거와 사용자 문구는 [v0.2.0 기록](../release/v0.2.0.md)에 정리했다.

## 구현

- draft builder는 기존 Release 교체와 직접 공개를 거부한다.
- 새 승격 workflow는 후보 artifact 및 최신 validation attempt의 arm64/Intel PASS, 실제 자동 검색/앱 종료/33개 lifecycle/cleanup을 확인한다.
- Release DMG/checksum bytes를 검사하고 같은 DMG의 Sparkle 서명/Pages를 준비한다. 공개 직전에 tag·회차·자산을 재확인하고 draft 상태만 변경한다. 더 최신 release로의 downgrade를 거부하며 동일 public 자산의 Pages 재시도는 허용한다.
- Pages 확인부터 배포까지 docs-only workflow와 직렬화하고, draft/prerelease 공개 문구 조기 배포를 차단한다.
- 4개 bundle 버전, 릴리스 분석/문구, 사용자 Pages와 운영 매뉴얼을 정렬했다. 준비 당시 README/Cask는 v0.1.11을 유지했고 이번 공개 기록에서 README는 0.2.0으로 정렬한다. Cask는 별도 배포 전까지 0.1.11이다.

## 검증과 증거

| 검증 | 결과 |
|---|---|
| 최초 설치 helper 회귀 | 11 tests PASS |
| 준비 PR 승격 gate 회귀 | 12 tests PASS — 후보/회차/증거/자산 교체·재시도와 모의 GitHub API/실제 ZIP CLI 연결 포함 |
| Stage 4.1 승격 도구 회귀 | 14 tests PASS — 실제 workflow preflight·clean checkout·고정 후보/도구 분리·draft ID 조회 포함 |
| actionlint 전체 workflow | PASS |
| 4 bundle contract/version | PASS, 0.2.0/18 |
| v0.2.0 release notes 생성/template/body | PASS, 검증용 가상 hash 사용 |
| Pages artifact/XML/banner 검사 | PASS, 공개 실행 없음 |
| 브라우저 실제 페이지 | DOM/viewport 확인, 아래 캡처 |
| PR CI macOS build/release helper | [PR #521 Checks](https://github.com/postmelee/alhangeul-macos/pull/521/checks)와 PR 본문에서 최종 head 결과를 추적한다. 실제 배포 검증과 구분한다 |

![v0.2.0 릴리스 페이지 후보](assets/task_m900_520/release-notes-preview.png)

## 공개 결과와 남은 종료 조건

[공개 승격 34709043904](https://github.com/postmelee/alhangeul-macos/actions/runs/34709043904)은 PASS다. 공개 DMG hash·길이가 양 VM 및 실제 Mac에서 확인한 후보와 같고 appcast/Pages도 0.2.0/18이다. 실제 Sparkle UI로 다운로드·설치했고 새 PID를 먼저 확인한 뒤 About을 열어 도구가 재실행을 대신하지 않았음을 검증했다.

1. 첫 시험은 같은 0.2.0을 먼저 설치한 뒤 이전 앱만 복원했다. 기존 HWP3 누락·새 사본 검색과 요청 키 하나만 분리한 회복을 기록했다. 이를 일반 새 버전 업데이트 실패로 확대하지 않는다.
2. 두 번째 실제 Sparkle 시험은 이전 버전에 없던 대상 요청 키 하나만 분리하고 새 corpus의 사전 미검색/TXT 검색을 확인했다. 다운로드·설치·자동 재실행 후 82.80초에 기존 영문 3개·한글 2개가 자동 검색되고 앱 종료 후에도 유지됐다. 원본 hash·mtime, 실제 importer 선택, 표준 확장 helper PASS다. 재구성한 환경 조건을 함께 기록했다.
3. 동일 버전 재설치의 과거 요청 기록 처리와 최종 수용은 #513 에서 이어가며 #337 / #520 도 유지한다. 새 VM의 깨끗한 최초 설치와 현재 Mac의 반복 설치를 구분한다.
4. #525 복구 후보 잔존은 원본 보존을 확인하고 별도 후속 수정으로 공개 승인받았다. macOS 12 환경 부재를 PASS로 바꾸지 않는다. 공개 설치 문구 강조와 페이지 구조는 #523 / PR #527 에서 반영한다. Homebrew는 별도 배포 승인 범위다.

문서 PR은 공개 사실·검증 증거·남은 조건을 정렬하는 진행 기록이다. 미완료 Stage 5를 완료로 처리하거나 공개 후보 bytes를 교체하지 않는다.
