# Task M900 #618 Stage 1: 공식 소스와 실패 기준

- v0.9.0: `c9095c5f67632e6721e800ccc7fb43ea49d26682`; v0.9.1: `981ce66b4183b13c1a3b5907e04a8969c8c42034`.
- 고정 커밋의 공식 Studio 소스를 분리해서 소스별 `adaptSource`에 전달했다. v0.9.0은 여섯 소스의 원본·변환 SHA-256 모두 기존 HostApp bundle receipt와 일치했다. v0.9.1은 실패 커밋 `4b753e5`에서 `main.ts`·`wasm-bridge.ts` 실패, 현재 `devel`에서 #616의 `canvas-view.ts` 실패까지 확인했다.
- v0.9.1 화면 첫 열기는 upstream 취소 경로를 사용한다. v0.9.0의 임시 변환은 그대로 유지한다. v0.9.1의 app provider는 새 host layout opt-in을 전달하지 않으므로 기존 앱의 선언 글꼴 보완은 유지하고 upstream의 기본 정리 호출을 보존한다. 호환 보완이 opt-in 레이아웃과 동시에 같은 환경을 소유하지 않는지 이후 통합 검증에서 확인한다.
- v0.9.1 target 확인은 [기존 CI](https://github.com/postmelee/alhangeul-macos/actions/runs/44482822101/job/135420298236)에서 통과했다. 로컬 full checkout을 두 벌 동시에 만드는 시도는 scratch 용량 때문에 중단했다. 두 버전의 로컬 전체 compatibility/build 검사는 Stage 3 검증 대상으로 남겨 두며 이 재현을 build 성공으로 간주하지 않는다.
