# Task M020 #469 Stage 4 — PR 리뷰 보완

verifier의 `--check-environment`는 Python 3.11+ 존재와 버전만 확인한다. release/package는 출력 준비·cleanup trap·Rust build 전에 검사하여 구버전 Python 때문에 기존 staging을 삭제하지 않는다. writer도 같은 사전 검사를 공유한다. 선행 #506에 기대지 않고 이 PR만으로 필요한 Python 계약을 갖춘다.

단일 파일 Swift consumer의 목적, tree hash의 조기 진단 역할, source verifier와 공통인 feature 배열 순서 정책을 설명했다. golden example의 classifier 사유 중복을 없앴다. 현재 request 0쪽의 15종 전체를 Swift로 decode하며 없는 variant의 변화는 검출하지 못한다는 범위를 명시했다.

검증:

- helper unittest 21개 통과. Python 없음/3.10 차단, 3.11 허용, 추가 인자 거부, 실제 release/package/writer script 복사본의 조기 실패와 기존 staging 보존을 포함한다.
- 실제 pinned producer golden verifier 통과: tracked/current 모두 TextRun 103, Table 4, TextLine 65. golden 파일·core/Cargo/FFI lock 불변.
- 변경 shell syntax와 diff 검증 통과. classifier의 example macOS 사유가 한 번만 출력됨을 fixture로 검증했다.
- 로그: `build.noindex/task469/review-{helper,golden}.log`.

## 리뷰 사실관계

기존 [PR CI job](https://github.com/postmelee/alhangeul-macos/actions/runs/34053953719/job/101542406245)에서 producer host build 4m52s 뒤 arm64 bridge는 1.93s였고 core를 다시 compile하지 않았다. x86_64 3m06s는 universal에 필요한 별도 아키텍처다. 같은 Cargo target 결과가 재사용되므로 schema 실패를 먼저 잡는 현재 순서를 유지한다. `run_rust_verify=false`인 Swift/example 변경에도 golden 계약은 필요하다.

#469는 모든 variant corpus를 요구하지 않는다. #259는 Skia visual/performance/package gate이며 decoder corpus 확장은 별도 범위를 정해야 한다. 최신 OS에서 성공한 golden은 #470의 macOS 12 미검증 조건을 해소하지 않는다.
