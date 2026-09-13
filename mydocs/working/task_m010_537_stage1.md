# Task #537 Stage 1 — 실제 SwiftUI 재현과 원인 확인

## 결과

기준 `devel`의 실제 ContentView·Store·Coordinator·bundled Studio로 기존 HWP → Studio 새 문서 → 한글 입력 → 저장을 실행했다. 기존 코드를 통과해야 하는 smoke로 오인하지 않고 아래 불일치를 결함 재현으로 확인했다.

| 관찰 | 결과 |
|------|------|
| 기존 파일 load | native loadID 1 / epoch 1 |
| 새 문서 생성 | Store epoch 2 / newDocument |
| SwiftUI의 WKWebView 객체 유지 | false — 새 객체로 교체됨 |
| 교체된 실제 편집기 | 같은 loadID 1에서 epoch 1, sequence 3으로 재시작 |
| native 저장 결과 | saved, 합성 파일 기록 |
| 저장 후 Store | epoch 2 유지, 파일명 ‘새 문서.hwp’, source nil |

`DocumentViewerView`의 `.id(document?.revision ?? 0)`가 원인이다. 기존 파일의 revision이 있는 상태에서 Studio가 새 문서를 만들면 native bytes가 nil로 분리된다. 이 메타데이터 변경으로 뷰가 재생성되고 같은 native loadID 안에서 epoch/sequence가 초기화되어 Store가 새 편집기의 상태와 저장 완료를 오래된 응답으로 거부한다.

Coordinator만 직접 사용하는 기존 진단은 저장 후 세 번의 조회까지 clean/파일명이 유지됐다. 따라서 실제 SwiftUI 뷰 생명주기를 포함하는 회귀가 필요하며, session의 오래된 응답 차단을 완화해서 해결하지 않는다.

## 근거와 다음 단계

`build.noindex/task537/probe-before.log`와 `probe-swiftui-before.log`, `Probe.swift`, `build-probe.py`에 진단을 보존했다. 고유 진단 bundle ID, 합성 문서와 저장 destination 주입을 사용했다. 물리 입력·실제 NSSavePanel 검증으로 일반화하지 않는다. 설치 앱은 변경하지 않았다.

Stage 2에서는 문서 bytes revision 기반 뷰 identity를 제거하고 기존 Coordinator의 명시적 loadID/reload 처리를 사용한다. 실제 ContentView를 호스팅하는 반복 가능한 회귀에서 객체·세션·저장·종료와 취소/실패를 확인한다. 사용자의 전체 작업 진행 승인을 적용한다.
