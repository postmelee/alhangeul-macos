# Task M900 #535 최종 결과보고서

## 결과

재설치 전 문서가 이미 검색되는 새 VM에서 사전 미검색을 강제하던 검증을 보완했다. 앱/문서 제거 후 삭제 전파는 계속 확인하고, 재준비한 corpus를 복사 전과 실행 전에 관찰해 전체 미검색 또는 전체 검색 상태만 기록한다. 실행 후 검색을 복구/유지로 구분하며 이미 검색되던 문서를 재색인 복구 증거로 쓰지 않는다.

최초 설치 미검색/TXT 대조, 같은 DMG·앱·importer bytes/경로/빌드/mtime, 기존 요청 기록 보존, 새 설치 객체·요청 식별자, 두 번째 실행, 이후 본문 검색·종료 후 유지, lifecycle 33개와 cleanup은 그대로 필수다. schema 3에서 관찰 순서·시간·조회 내용·분류와 snapshot 연결을 검사한다. 부분 검색, 중간 조회 오류, 대조 부재, 누락된 증거로 PASS를 만들지 않는다.

삭제된 소유 앱 경로도 등록 해제를 요청하며 전역 Spotlight/LaunchServices 초기화나 daemon 종료를 추가하지 않았다. 정리·상태 저장·DMG detach 실패가 최초 검증 오류를 덮지 않도록 보존한다. 관찰 기한 때문에 30초보다 짧게 제한한 마지막 query timeout과 독립적인 명령 장애를 구분한다.

## 불변 후보 재검증

검토되어 main에 반영된 도구 SHA는 후보의 descendant이고 명시적으로 허용된 검증/문서 파일만 바뀐 경우에 한해 기존 DMG를 검사한다. fixture는 후보 SHA의 소스에서 생성한다. 승격 시 run·artifact·result와 Git source proof를 대조하고 공개 직전에 재검사한다. PR ref/미병합 도구·제품/의존성/fixture 변경은 거절한다. v0.2.1 tag와 DMG를 변경하지 않는다.

원본 실패 [34726622024 attempt 1](https://github.com/postmelee/alhangeul-macos/actions/runs/34726622024)과 ARM/Intel artifact 10307684534 / 10308435782를 보존한다. 최초 설치 검색 PASS와 전체 FAILURE를 구분해 [v0.2.1 기록](../release/v0.2.1.md)에 남겼다.

## 검증

| 검증 | 결과 |
|---|---|
| `python3 -B scripts/ci/test-spotlight-system-smoke.py` | 40개 PASS |
| `python3 -B scripts/ci/test-release-install-smoke.py` | 25개 PASS |
| `python3 -B scripts/ci/test-release-promotion.py` | 16개 PASS |
| `actionlint .github/workflows/release-first-install.yml .github/workflows/release-promote.yml` | PASS |
| `git diff --check` | PASS |

단계 보고서: [Stage 1](../working/task_m900_535_stage1.md), [Stage 2](../working/task_m900_535_stage2.md), [Stage 3](../working/task_m900_535_stage3.md). UI 변경이 없는 검증 도구 PR이므로 실제 앱 스크린샷은 추가하지 않았다.

## 후속 수용

이 보고서는 코드 보완·로컬 검증 완료 보고다. 도구 PR 검토·devel 병합·main 인계 후 고정 후보 입력으로 새 양 VM 검증을 실행한다. 검토 중 #538의 제품 수정이 devel에 병합되었으므로 기존 v0.2.1(19) DMG는 보존하고, 이 수정과 검증 도구가 함께 포함된 새 버전·빌드 후보를 만들어 검증한다. 제품 변경은 도구만 바뀐 경우의 기존 후보 재검증 예외에 해당하지 않는다. 새 실행에서 검색 유지/복구 분류, 새 요청, 종료 후 검색, lifecycle·정리를 확인해야 한다. 특히 실제 macOS importer 카탈로그 정리는 아직 통과를 확인하지 않았다.

새 VM 결과 전까지 #535 는 열린 상태를 유지하며 #532 / #513 / #337 도 종료하지 않는다. 실제 Mac UI 수용과 공개 후 0.2.0 → 새 공개 버전 Sparkle 수용이 남아 있다. 공개 승격은 별도 최종 판단이며 macOS 12 미검증·#525·Homebrew 범위는 기존과 같다.

## v0.2.2 후속 — Stage 4

[Stage 4](../working/task_m900_535_stage4.md)에서 비동기 재설치 요청 기록을 최대 30초 관찰하도록 보완했다. system 43개·install 25개·promotion 16개(총 84개) 회귀 PASS. 기록이 없거나 다른 후보의 기록이면 계속 실패한다.

새 후보 [실행 34778130781](https://github.com/postmelee/alhangeul-macos/actions/runs/34778130781)은 Intel 전체 PASS, ARM 재설치 요청 기록 판정 및 cleanup 실패다. 전체 성공으로 해석하지 않는다. 이 후속 PR의 main 인계 뒤 고정된 v0.2.2(20) DMG로 새 실행이 필요하며 #535/#539/#513/#337은 열린 상태를 유지한다.
