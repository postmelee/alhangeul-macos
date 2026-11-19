# Task M900 #618 Stage 3: 두 태그의 Studio 빌드 검증

## Linux에서 확인한 결과

| 항목 | v0.9.0 | v0.9.1 |
| --- | --- | --- |
| 공식 태그 해석 및 `update-rhwp-core.sh --check` | `c9095c5f67632e6721e800ccc7fb43ea49d26682` 통과 | `981ce66b4183b13c1a3b5907e04a8969c8c42034` 통과 |
| 초기 페이지 계약 | #616 유지, 원본·변환 해시 6쌍 일치 | 확인된 upstream #9170 경로, CanvasView 원본 유지 |
| lockfile 설치, TypeScript, Vite | 7.0.2 / 8.3.5 통과 | 7.0.2 / 8.3.8 통과 |
| checkout 대조 `--verify-receipt` 및 `sync-rhwp-studio.sh --check` | 통과 | 통과 |
| Node WASM 공개 샘플 첫 쪽 SVG | HWP 1쪽·HWPX 10쪽, 첫 SVG 생성 | HWP 1쪽·HWPX 10쪽, 첫 SVG 생성 |

두 checkout은 공식 Git 객체에서 소스와 Cargo.lock을 읽었으며 각각 깨끗한 상태를 유지했다. WASM 및 JS/타입은 registry의 공식 `@rhwp/core` 0.9.0, 0.9.1 패키지에서 가져왔다. 패키지의 `gitHead`를 exact checkout SHA와 대조하고 tarball SHA-512를 registry integrity 값과 비교했다. 클라우드에서 Rust를 처음부터 재빌드하지 않았고 후보 자동화가 사용하는 Docker/wasm-pack 출력과 동일하다고 단정하지 않는다.

- WASM SHA-256: v0.9.0 `c3b0632b84881f81f2c80be7c2f9e44a4086cb01e05a6a9107a3b3c6350abc1d`, v0.9.1 `e2e56dfd387ffee5b0995d23e4a0086001407f12a045820eb61bd6a506c9abc1`.
- 새 Studio adapter receipt SHA-256: v0.9.0 `e15b1ad6f5eadd5789e00612c9904a8aa2338a5d3bb133d945be5856ebbbc37b`, v0.9.1 `be16f7e97bf43d391305abccaceebb83c24f879d72d77f1791f6cf4afa2be4a1`.
- SVG 검증은 같은 공개 `shift-return.hwp`와 `form-002.hwpx`에서 두 공식 WASM의 문서 열기 및 첫 SVG 수신만 확인했다. 뷰포트에 실제 그려졌거나 PDF 출력이 동일하다는 뜻이 아니다.

## 남은 검사와 배포 경계

- 클라우드 Chromium end-to-end는 브라우저 프로세스 시작 시 소켓 권한으로 차단됐다. 이 실패를 제품 실패로 기록하지 않는다. 실제 macOS WKWebView의 첫 화면·연속 열기·취소·호스트 글꼴·PDF는 실행하지 못했다.
- 변경 전후 제품 pin은 v0.9.0 그대로이고, 기존 Studio 번들의 실행 HTML/JS/WASM, Swift·RustBridge·Quick Look·Thumbnail 소스와 framework는 변경하지 않았다. Quick Look 실동작 재검증과 v0.9.1 native ABI/설치본 생성은 별개다.
- 자동 동기화의 로컬 target 검사·Studio 준비·strict 검증까지 통과했다. CI의 실제 WASM 재생성과 v0.9.1 후보 PR 생성 및 WKWebView 검증은 이어서 확인해야 한다. 서명·공증·배포는 실행하지 않았다.
