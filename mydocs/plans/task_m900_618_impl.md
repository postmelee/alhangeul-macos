# Task M900 #618 구현계획서

2026-11-19 · [승인된 수행계획](task_m900_618.md) · [이슈 #618](https://github.com/postmelee/alhangeul-macos/issues/618) · 통합 대상 `devel`

앱 기준은 `3ed7d3eb9cbe586979507395776beb5c29d7f3e4`다. v0.9.0은 `c9095c5f67632e6721e800ccc7fb43ea49d26682`, v0.9.1은 `981ce66b4183b13c1a3b5907e04a8969c8c42034`로 해석해야 한다. 각 태그의 깨끗한 checkout과 산출물 디렉터리는 분리한다. 생성 파일을 혼합하지 않으며, v0.9.1 동기화 후보를 검증하기 위해 배포용 pin·설치본·기존 공개판을 바꾸지 않는다. 사용자의 승인 범위를 넘는 후보 워크플로 실행, 원격 push, PR 생성, 병합 및 배포는 별개다.

## 1단계 — 공식 소스와 실패 기준 고정

- 원격 태그·전체 SHA·각 checkout HEAD·깨끗한 작업 트리를 대조하고 `scripts/update-rhwp-core.sh --check --channel stable --tag <TAG> --upstream-dir <UP>`를 태그별로 실행한다. 도구나 의존성이 없어 실행할 수 없다면 공식 객체 검증과 build check를 구분하며, 필수 실행을 대체 검증으로 통과 처리하지 않는다.
- 실패 커밋 `4b753e5`와 현재 기준의 실제 `adaptSource`를 두 태그의 공식 소스에 실행한다. 기존 v0.9.0 성공 경로, v0.9.1의 `main.ts`·`wasm-bridge.ts` named import와 #616의 `canvas-view.ts` 실패를 파일별로 기록한다. 첫 오류 뒤의 입력도 독립 실행해 가려진 실패를 확인한다.
- 두 태그의 `prepareCanvasMetrics`·`releaseCanvasFontResources`·font provider 및 출력 API, #9170의 문서 수명·취소와 #616의 삽입 책임을 비교한다. 앱의 글꼴 준비가 upstream의 새 레이아웃 경로와 중복되는 부분, 유지해야 할 출력 API와 검증 입력을 특정한다.
- 완료 조건: 소스 전체 SHA와 파일 해시, 재현 명령, 보호해야 할 동작 및 이후 단계의 정확한 수정 지점을 [단계 보고서](../working/task_m900_618_stage1.md)에 남긴다. 이 단계에는 제품·빌드 어댑터 변경, 후보 생성, 원격 작업이 없다.

## 2단계 — import 변환과 정확한 pin별 첫 화면 변환

- `scripts/studio-font-menu-adapter.mjs`에서 `@/core/local-fonts`와 `./local-fonts` 각각 기대한 모듈의 고유 named import를 찾는다. pinned TypeScript 문법의 범위 안에서 심벌 이름·alias·type-only 여부를 검사하고, 필요한 값 import만 추가한다. 순서·공백·줄바꿈, 이미 같은 심벌이 있을 때를 허용하되 대상 모듈 누락/중복, 타입 전용이거나 다른 이름으로만 존재하는 필요값, 구문이 모호한 input은 진단과 함께 거부한다. 다른 이름의 import나 동명 주석은 매칭하지 않는다. 원본 입력은 수정하지 않는다.
- `src/main.ts` 출력 bridge 확장과 `src/core/wasm-bridge.ts`의 앱 공급 보완 중 실제 필요한 것만 남긴다. `resolveRendererLocalFontCandidates`를 두 번 추가하지 않고 upstream의 `releaseHostLayoutPrograms` 호출을 가리지 않는다. 앱이 새 upstream으로 충분히 대체된다면 임의 no-op 추가 대신 Stage 1에서 확인한 기존 정리 및 화면·출력의 책임을 근거로 변환을 조정한다.
- v0.9.0의 확인된 SHA는 #616을 유지하고 v0.9.1의 확인된 SHA는 upstream #9170 계약이 확인될 때만 임시 보정을 생략한다. 두 초기화 파일에서 이전 보정 대상 또는 upstream 초기 렌더링·취소 계약이 함께 확인돼야 한다. 알 수 없는 SHA에서도 양립하지 않는 한 계약의 정확한 마커를 모두 검증한 경우에만 수용해 이후 자동 동기화를 버전 목록으로 차단하지 않는다. 혼합·중복·불명확한 경우 실패한다.
- `scripts/build-rhwp-studio.mjs`의 sourcePaths·plugin coverage·파일 fingerprint·receipt verification이 같은 선택 함수와 동일 순서를 사용하도록 맞춘다. verification은 receipt가 주장하는 소스 목록을 신뢰하지 않고 고정 커밋과 manifest에서 기대 목록을 다시 결정한다. 파일 수, original/adapted 해시와 변환 스크립트 해시, 원본 일치 조건을 완화하지 않는다.
- 완료 조건: 실제 두 태그의 순수 transform과 신규 Node 회귀가 통과한다. 양성: 기존/새 순서, 줄바꿈·공백, 기존 resolver 보존, v0.9.0 임시 경로·v0.9.1 upstream 경로, 원본 불변. 음성: 대상 없음·두 선언·잘못된 모듈·동명 주석·값 대신 타입·등록되지 않은 초기화 계약·receipt 오염. 기존 `node --test` Studio 글꼴 bootstrap, menu, provider, output 및 font-load-deadline 테스트를 함께 실행한다. 같은 커밋에 [단계 보고서](../working/task_m900_618_stage2.md)를 남긴다.

## 3단계 — 동일 SHA의 빌드 증명과 macOS 수용 확인

| 검증 경계 | 입력과 실행 | 통과 조건 |
| --- | --- | --- |
| CI와 같은 빌드 | 분리한 각각의 upstream checkout에서 동기화 workflow와 동일 명령으로 공식 WASM·`npm ci`·`node scripts/build-rhwp-studio.mjs` 실행 | 두 태그 모두 타입 검사와 Vite 빌드 통과, checkout 원본 불변, 패키지 JS·타입·WASM이 동일 SHA |
| 생산과 검증 | 임시 산출물에 `scripts/sync-rhwp-studio.sh` 실행 후 `scripts/verify-rhwp-studio-assets.sh` 및 `--verify-receipt` 실행 | 공식 태그·SHA·Cargo.lock·receipt·서로 다른 대상 목록과 파일 해시 일치, 불일치 음성 대조 거부 |
| 처음 열기 | 격리한 WKWebView 앱으로 정상 HWP/HWPX를 각기 새 프로세스에서 열기. v0.9.0 + #616과 v0.9.1 + #9170 비교 | 첫 화면에 페이지 내용이 보이고 문서 합성이 완료되며, 정상 종료 전에 사용자에게 빈 화면 상태를 성공으로 표시하지 않음 |
| 경쟁·취소 | 반복 열기, 로딩 중 문서 바꾸기, 가능한 경우 취소 직후 다른 문서 열기 | 마지막 문서만 화면·제목·명령 대상이 되고 늦게 도착한 이전 로드가 새 화면을 덮지 않음. 취소를 오류 화면으로 오인하지 않음 |
| 글꼴·출력 | 앱 관리 글꼴 공급/해제, 렌더러 전환 가능 구간, HWP 및 HWPX 열기·PDF 출력 | 실제 공급된 글꼴과 fallback을 구분하고 문서 교체 뒤 stale 공급이 남지 않음. 두 형식의 글자·쪽이 PDF에 함께 남고 종료/정리에서 JavaScript 오류 없음 |

실제 Mac은 기존 설치본과 Quick Look 등록에 손대지 않고 표준 `build.noindex/` 아래에서 실행한다. 가능한 경우 `scripts/smoke-studio-document-lifecycle.py`, `scripts/probe-studio-font-integration.py`, `scripts/test-studio-output.sh`를 사용한다. 실제 WKWebView를 쓸 수 없으면 실행하지 못한 항목, 필요한 Mac 또는 승인된 CI 조건을 기록한다. Linux나 Node 변환 통과를 실제 WKWebView 통과로 바꾸지 않으며 이번 후보로 #616의 종료를 확정하지 않는다. 결과는 [단계 보고서](../working/task_m900_618_stage3.md)에 기록한다.

## 4단계 — 자동 후보 생성 경로와 결과 인계

- `.github/workflows/rhwp-upstream-sync-pr.yml`에 원래 있던 core target 검사 → WASM/Studio 빌드 → verify → 후보 준비의 순서를 확인한다. 검사를 건너뛰거나 후보 생성 gate를 완화하지 않는다. 실제 workflow dispatch 또는 공개 브랜치 게시가 별도 승인 없이 필요한 경우 준비만 하고 대기한다.
- 두 버전의 검증 표, 후보 SHA와 증명 해시, 확인되지 않은 실제 사용 조건, #616 유지·정리 결론을 [최종 보고서](../report/task_m900_618_report.md)에 구분하고 오늘할일을 갱신한다. 실패한 필수 검증은 결과를 숨기지 않고 같은 단계에서 해결하거나 승인된 범위 재조정을 요청한다.
- 최종 보고서 승인 뒤에만 PR 게시 여부를 진행한다. 병합·서명·공증·공개 배포는 이 계획에서 제외한다.

각 단계 보고서와 해당 소스 변경은 같은 로컬 타스크 커밋에 묶는다. 이 구현계획 승인 전에는 1단계 작업을 시작하지 않는다.

## 4단계 후속 — 공식 OLE 차트 메타데이터 호환

공개 회귀 문서와 별개인 비공개 HWP/HWPX에서 공식 v0.9.1의 SVG가 `rejected` 경로를 밟았다. 고정 태그의 Rust 렌더러가 생성하는 OLE 차트 `<g>`의 네 데이터 속성과 값만 기존 정책에서 인식한다. 공개 합성 회귀 입력과 기존 공개 차트로 허용 범위·거부 조건을 대조하고, 비공개 원본 양쪽의 Preview/PNG와 PDF 렌더러·차트 구성 요소를 실제 후보로 다시 확인한다. 원본 및 파생 파일은 공개하지 않는다.
