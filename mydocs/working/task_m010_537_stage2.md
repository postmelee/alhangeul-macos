# Task #537 Stage 2 — 편집기 identity 유지와 통합 회귀

## 변경

`DocumentViewerView`의 문서 bytes revision 기반 `.id`를 제거했다. 기존 Coordinator의 loadID 경로가 명시적 파일 열기/재시도를 담당한다. 새 문서 생성과 저장은 같은 WKWebView 안에서 진행하며, token/sequence/epoch 거부 및 저장 실패·변경 감지 로직은 변경하지 않았다.

반복 가능한 `smoke-studio-document-lifecycle.py`와 실제 ContentView를 호스팅하는 Swift 진단을 추가했다. 읽기 전용 fixture, 고유 bundle ID, 요청별 출력 디렉터리와 정확한 앱 등록 해제를 사용한다. 실제 core로 저장 결과의 컨테이너·한글 표식을 확인하고 최초 실패와 cleanup 결과를 구분한다. PR macOS CI에서 실행하고 실패 시에도 build/run/cleanup 로그를 보존한다.

## 검증

- HostApp Debug build: PASS.
- HostAppTests: 224개, 실패 0. 기존 session·저장 보호·오래된 응답 거부 회귀 포함.
- 실제 SwiftUI + bundled Studio smoke: 31개, 실패 0, exit 0 (`build.noindex/studio-lifecycle-l2fxnv07`).
- HWP/HWPX 각각: 기존 파일 → 새 문서의 객체/epoch 유지, 저장 취소·쓰기 실패, 첫 저장·반복 저장·명시적 재열기, 닫기 취소·닫기 저장 실패, 종료 취소·저장 허용, 실제 창 닫힘, 버리기 후 원본 bytes 보존.
- AppKit 공통 경계, Studio asset 검증, actionlint, Python 구문, diff 공백: PASS.

초기 harness의 AppKit 응답 타입 오류와 sheet completion 대기 경합은 제품 오류와 구분해 수정했다. HWPX 재열기 후 입력 위치가 앞쪽으로 이동해 순서 검사만 실패한 실행은 보존했고, 실제 본문에 누락이 없음을 확인한 뒤 필수 표식 보존 검사로 보정했다. 초기 실행을 전체 PASS에 포함하지 않는다.

## 범위와 한계

입력·저장 destination·NSAlert 응답·종료 reply는 진단 코드에서 주입한다. 실제 제품의 SwiftUI/Store/Coordinator/controller와 고정 Studio를 실행했으며 물리 IME, 실제 NSSavePanel, signed sandbox/DMG 검증을 대체하지 않는다. 기존 macOS 12 runtime 공백과 #525 는 유지한다. 공개 후보는 #532 에서 새 앱으로 재검증해야 한다.
