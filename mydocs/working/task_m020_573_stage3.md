# Task #573 Stage 3 — 종합 검증과 최종 보고

## 결과

Stage 1·2의 검증 결과와 화면 증거를 최종 보고에 묶고 오늘할일을 완료 처리했다. 별도 worktree에서 `publish/task573`으로 게시하여 `devel` 대상으로 Open PR을 생성한다. 승인 범위는 PR 생성까지이며 merge·이슈 close·공개 배포는 남겨 둔다.

## 최종 검증

- 실제 TOML/JSON 파싱으로 core lock, RustBridge Cargo dependency와 resolved lock, Studio manifest의 tag·commit 일치를 확인했다: `v0.8.6` / `f1f9c6ae58344ee9368996d3543f76b9345cf227`.
- 새 helper·fixture Python 문법 검사 통과. 생성된 bytecode는 정리했다.
- `scripts/ci/check-main-devel-content.sh origin/main HEAD`: 통과. main-only 3개는 모두 transport-only merge이며 미인계 content 없음.
- `git diff --exit-code origin/devel -- rhwp-core.lock RustBridge/Cargo.toml RustBridge/Cargo.lock Sources/HostApp Sources/RhwpCoreBridge Frameworks project.yml`: 통과. 제품·pin·framework source 변경 없음.
- `git diff --check origin/devel`: 통과. 기존 checkout은 `local/task567` / `7a60448`을 유지하며 clean 상태다.
- [Stage 1](task_m020_573_stage1.md)의 배지 10개 검증·core build info·Studio asset gate, [Stage 2](task_m020_573_stage2.md)의 Pages 14개·소식 UI 9개·workflow 문법·19개 페이지 88개 화면 조합·실제 링크 이동은 모두 통과했다. 성공한 검증은 변경 없이 반복하지 않았다.

실제 다음 upstream full sync의 빌드·pin 갱신은 실행하지 않았다. 다음 가상 pin으로 helper를 실행하고 workflow의 갱신 순서·README stage를 검증했으며 실제 pin은 보존했다. PR CI 실행 링크는 게시 후 최종 응답으로 전달하고 완료를 기다리지 않는다.

## Stage 3.1 — PR CI 실패 후속 보정

2026-09-30 사용자 지시에 따라 [PR #574](https://github.com/postmelee/alhangeul-macos/pull/574)의 head `c895dbdb61648012cb41fcc713dd1f1a66b69378`에서 실패한 [Script syntax checks job](https://github.com/postmelee/alhangeul-macos/actions/runs/36726004622/job/109923088685)의 로그를 직접 조회했다. 전체 run 완료를 기다리지 않았다.

새 배지 검증과 Pages 검증 단계는 성공했다. 실패는 기존 `test_reinstall_preserves_receipt_and_copy_dates_without_registration_or_touch`에서 `ValueError: reinstall did not create a new installation object`가 발생한 것이다. Linux의 `installation_object`는 birthtime 없이 device/inode로 비교한다. 삭제 직후 copy에서 inode가 재사용되면 새 synthetic 설치본도 같은 객체로 판정되는 테스트 전제가 원인으로 판단된다.

`test-spotlight-system-smoke.py`의 fixture에서 이전 importer 디렉터리를 열린 fd로 유지하고 test cleanup에서 닫도록 보완했다. 실제 삭제·copy·hash·mtime·receipt 검증은 유지하며 inode가 새 copy에 즉시 재사용되는 것을 막는다. 동일 설치 객체면 launch 전에 실패하는 경계 검증도 추가했다. 운영 smoke helper·제품 기능은 수정하지 않았다.

검증:

- Spotlight 전체 44개 통과.
- 실제 stat의 birthtime을 제거한 Linux 설치 객체 조건으로 전체 44개, 재설치 성공·미기록 교체 거부 경계 각 20회(총 40개) 통과.
- 동일 CI step의 Spotlight bundle fixture 5개, release install 25개, release promotion 16개와 bundle 계약 gate 통과.
- README 배지 fixture 10개, 현재 pin 배지 `--check`, Python AST 문법, `git diff --check` 통과.
- 기존 head 대비 운영 smoke·README·홈페이지·rhwp pin·제품 source·framework·project.yml 변경 없음 확인.

로컬 Docker daemon이 실행 중이지 않아 실제 Linux 컨테이너 실행은 하지 않았다. birthtime 없는 조건 검증과 실제 Linux 새 head CI 결과는 구분한다. 보정 commit을 push하여 새 head에 연결된 CI run 링크를 최종 응답으로 전달하며 완료는 기다리지 않는다. 모바일 링크 위치 변경은 별도 후속 결정으로 남겨 둔다.
