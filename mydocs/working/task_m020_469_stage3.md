# Task M020 #469 Stage 3 완료보고서

## 실제 통합 검증

- writer 재실행 후 tracked golden과 사전 복사본 `cmp` 동일, git diff 없음.
- 실제 verifier 성공: pinned core/source/sample/byte/Swift contract 일치.
- 실제 CLI negative 3종: stale pin, stale tree, malformed known TextRun 모두 nonzero와 기대 메시지, 입력 fixture byte 불변.
- malformed known 진단: `variant=TextRun path=$.children[5].children[0].children[0].node_type.TextRun.text cause=keyNotFound`.
- minimal decoder 18개, helper unittest 16개(7종 경로 subcase), 기본 native HWP 3종 smoke 통과. native 결과는 #470 결과와 같은 TextRun/비백색 픽셀 수다.
- no-AppKit, shell/Rustfmt/YAML/diff 검증 통과. core/Cargo/FFI pin과 reference artifact hash 불변.

로그와 검증용 복사본은 `build.noindex/task469/`에 보관한다. 등록·설치·배포 workflow는 실행하지 않았다. CI는 PR 게시 후 확인한다.
