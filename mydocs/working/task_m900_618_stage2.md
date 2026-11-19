# Task M900 #618 Stage 2: Studio 변환 호환성

- v0.9.1 `main.ts`에는 같은 `local-fonts` 모듈을 가져오는 두 실제 선언이 있다. 고유한 `setHostFontProvider` 값 선언을 식별해 출력 함수를 추가했다. `wasm-bridge.ts`에서는 `hasHostFontProvider`에 연결하되 기존 `resolveRendererLocalFontCandidates`와 upstream `releaseHostLayoutPrograms`를 보존한다.
- #616은 v0.9.0에서 그대로 적용하고, v0.9.1은 upstream 초기 렌더링 경로로 전환한다. 빌드와 strict receipt 검증은 같은 두 원본에서 모드를 선택하고 Vite coverage에서 두 모드 모두 여섯 파일의 변환 또는 원본 유지 증명을 남긴다. 이후 버전은 동일한 검증된 구/신 계약을 충족할 때만 허용하고 혼합·누락·중복은 거부한다. 고정 npm 환경의 `tsc` 실행 파일을 사용하도록 내부 경로 가정을 제거했다.
- 공식 두 태그의 실제 입력 12개를 검증했다. v0.9.1 CanvasView는 원본과 바이트 일치, 나머지 변환 5개는 Node TypeScript 파서와 `node --check`를 사용한 문법·중복 import 검사를 통과했다. v0.9.0 입력 6개의 원본·변환 SHA-256은 기존 출처 증명과 일치해서 실행 자산은 변경하지 않고 스크립트 해시·receipt의 manifest 참조만 갱신했다.
- Studio 글꼴 Node 테스트 34건, Cargo.lock/동기화 fixture, 현재 번들의 검증 스크립트 통과. receipt의 소스 행을 바꾼 음성 대조와 확인되지 않은 초기 렌더링 계약은 거부됐다.
- 공식 두 태그의 전체 WASM/Studio 빌드와 WKWebView 실제 첫 화면·취소·글꼴/PDF는 후속 검증이다. 이번 단계의 문법 검사를 TypeScript 타입 검사나 실제 앱 수용 검증으로 간주하지 않는다.
