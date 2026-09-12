# Task M900 #520 Stage 4 — 공증 후보·실제 검증 진행과 승격 도구 보완

## 결과

Stage 4 전체 수용은 진행 중이다. PR #521 과 main PR #522 를 병합하고 불변 `v0.2.0` 후보를 만들었다. 이번 후속 변경은 실제 draft API에서 발견한 승격 도구 문제를 보완하며 앱이나 DMG를 다시 만들지 않는다. #520 / #513 / #337 은 열린 상태다.

| 항목 | 기준·결과 |
|---|---|
| 후보 tag / SHA | v0.2.0 / aa986e5ae59732a2423324eb3b415a06c67c8a68 |
| 버전 / 빌드 | 0.2.0 / 18 |
| core / Studio | rhwp v0.8.6, 기존 pin 유지 |
| 후보 생성 | [34699689421](https://github.com/postmelee/alhangeul-macos/actions/runs/34699689421), attempt 2 PASS |
| 원본 DMG artifact | 10300043814 |
| DMG SHA256 | 1fce404263d342de23f76f7b74485e56f87b783c976eba82eb041e329588e321 |
| Release / 크기 | ID 387608761, draft=true / prerelease=false, 192864126 bytes |
| 로컬 서명·공증·Gatekeeper·universal | PASS — 앱 실행 없이 확인, 검증용 mount 해제 |
| 새 VM 최초 설치 | [34701708901](https://github.com/postmelee/alhangeul-macos/actions/runs/34701708901), attempt 1: arm64 환경 검사 실패·Intel 전체 PASS; attempt 2 전체 재실행 중 |
| 사용자 직접 설치·기능 조작 | 대기 — 실제 앱은 에이전트가 실행하지 않음 |

[기계 판정 요약](../report/assets/task_m900_520/candidate-validation.json)에 원본 후보 식별자와 조회 검증을 보존한다. 실행 중 결과는 성공으로 합산하지 않는다.

## 실패와 원인 구분

1차 후보 생성은 Release 앱 빌드와 Developer ID 서명 preflight 후 Apple 공증 제출의 `NSURLErrorDomain -1009 / No network route`로 실패했다. 유효한 submission ID와 DMG/draft가 없음을 확인하고 같은 소스에서 새 runner로 재시도했다. 2차 실행은 서명·공증·DMG와 draft/artifact 생성을 모두 통과했다. 실패 당시 빈 JSON을 submission ID처럼 다룬 추가 로그 조회 오류도 원본 기록에 남겼으며 공증 심사 거절과 구분한다.

최초 설치 arm64 VM은 Indexing enabled 및 GUI 세션이 있어도 일반 TXT가 180초 내 검색되지 않아 `ENVIRONMENT_UNAVAILABLE`로 종료됐다. 앱 설치 이전 실패이고 시험 TXT 정리는 확인됐다. 2026-09-12 사전 환경 조사 양 runner PASS가 이후 모든 새 VM의 상태를 보증하지 않는다는 실제 사례다. Intel은 동일 후보의 첫 실행·앱 종료 후 검색·33개 lifecycle·cleanup 및 require_complete를 모두 통과했다(총 652.63초). 전체 verdict는 양 아키텍처 성공 조건을 충족하지 못해 실패다. 1차 증거를 보존하고 동일 run의 attempt 2에서 모든 job을 재실행했다. 이전 Intel PASS와 이후 arm64 결과를 섞어 승격하지 않는다.

## Stage 4.1 승격 도구 보완

인증된 `releases/tags/v0.2.0`은 실제 draft에 대해 404를 반환했지만 Release 목록/ID 조회는 성공했다. `find_release`는 모든 페이지에서 정확한 tag의 유일한 ID를 찾고 ID로 최신 draft/public 자산을 읽는다. 후보 부재로 간주해 자산을 생성하거나 덮어쓰지 않는다.

기존 tag 안의 도구를 고치려고 불변 tag를 이동하지 않는다. 승격 workflow를 검토·병합된 main에서 실행할 때 선택 입력 `source_sha`로 기존 후보를 고정한다. checkout/도구 SHA, 후보 tag/SHA, 후보→도구→main 포함 관계, 4개 version/build를 확인한다. 후보 이후 `.github/`, `scripts/`, `mydocs/` 밖의 변경은 거부하므로 앱·의존성·공개 Pages 변경을 기존 DMG와 섞지 않는다. 공개 직전 원격 tag·VM 최신 회차·Release bytes 재검사는 유지한다. 후보와 도구 SHA는 source-proof.json으로 구분한다.

## 보완 검증

- `python3 scripts/ci/test-release-promotion.py`: 14 tests PASS. 실제 Git 후보/도구 분리, 임의 branch·틀린 SHA/build·제품/Pages/dependency/유사 경로 변경 거부, 페이지 분할 draft ID 탐색·중복 거부 및 tag endpoint 없는 CLI 왕복 포함.
- `python3 scripts/ci/test-release-install-smoke.py`: 11 tests PASS.
- Python 구문, actionlint release-promote, git diff --check: PASS.
- 보완한 find_release로 실제 draft ID 387608761을 읽어 검증: PASS. 같은 자산 ID/DMG hash이고 공개 변경 없음.
- 후속 PR CI는 게시 후 해당 Checks에서 확인한다. 최초 설치 FAIL/미실행과 사용자 GUI 대기를 위 단위 테스트 결과로 대체하지 않는다.

## 직접 테스트 인계

현재 macOS 26.5.2 arm64의 v0.1.11(17) / v0.1.8(14)을 build.noindex 아래에 별도 백업하고 원본 파일 일치를 확인했다. 기존 Quick Look/Thumbnail 등록 경로도 기록했다. Documents의 별도 input/results 폴더에 합성 HWP3/HWP5/HWPX와 화면 확인용 HWP/HWPX 복사본을 준비했다. 사전 기준에서 TXT는 검색됐으며, 설치 직전 전용 본문 단어는 미검색이고 알한글 importer/실행 프로세스는 없었다.

사용자가 교체 대화상자에서 앱 없는 상태의 설치 검증을 요청했다. 복사를 취소하고 두 원본과 백업의 전체 파일 hash/symlink 일치를 재확인했다. 기존 두 앱/확장만 등록 해제한 뒤 build.noindex의 별도 격리 폴더로 원본을 이동했다. 두 Applications 경로 부재, Preview/Thumbnail 조회 no matches, 알한글 importer 부재를 확인했다. 문서·설정·과거 색인 이력은 보존했다. 이는 앱 없는 상태의 재설치이며 깨끗한 OS 최초 설치와 구분한다. 사용자가 DMG에서 다시 복사하고 DMG를 꺼낸 뒤 직접 실행해 버전을 확인하도록 인계했다. 이후 Spotlight 영문/한글·앱 종료 후 검색, 새 HWP/HWPX 저장·재열기, Word/HTML/PDF 내보내기·취소/원래 상태, 미저장 닫기, Finder 미리보기/썸네일을 순차 확인한다. 원본 앱 복원과 공개 후 실제 Sparkle 업데이트는 남아 있다. macOS 12 환경은 없고 공개 승인은 아직 받지 않았다.
