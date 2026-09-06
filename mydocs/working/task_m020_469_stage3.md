# Task M020 #469 Stage 3 완료보고서

## 실제 통합 검증

- writer 재실행 후 tracked golden과 사전 복사본 `cmp` 동일, git diff 없음.
- 실제 verifier 성공: pinned core/source/sample/byte/Swift contract 일치.
- 실제 CLI negative 3종: stale pin, stale tree, malformed known TextRun 모두 nonzero와 기대 메시지, 입력 fixture byte 불변.
- malformed known 진단: `variant=TextRun path=$.children[5].children[0].children[0].node_type.TextRun.text cause=keyNotFound`.
- minimal decoder 18개, helper unittest 16개(7종 경로 subcase), 기본 native HWP 3종 smoke 통과. native 결과는 #470 결과와 같은 TextRun/비백색 픽셀 수다.
- no-AppKit, shell/Rustfmt/YAML/diff 검증 통과. core/Cargo/FFI pin과 reference artifact hash 불변.

로그와 검증용 복사본은 `build.noindex/task469/`에 보관한다. 등록·설치·배포 workflow는 실행하지 않았다. CI는 PR 게시 후 확인한다.

## PR CI 보완

최초 CI에서 path classification fixture가 `GITHUB_STEP_SUMMARY`를 상속하여 stdout 대신 Actions summary로 출력했다. fixture subprocess에서 `GITHUB_STEP_SUMMARY`/`GITHUB_OUTPUT`을 제거해 테스트 출력 계약을 격리했다. 두 env가 설정된 실제 CI 형태로 local unittest 16개와 7종 경로 subcase 통과 및 외부 summary/output 파일을 만들지 않음을 확인했다. 제품 classifier의 Actions summary 동작은 유지한다.
