# Task #537 Stage 3 — 회귀 검출력·최종 검토·PR 준비

## 검증 결과

최종 smoke와 동일한 제품/테스트 구성을 사용하되 `DocumentViewerView.swift`만 수정 전 `121d0e4` 버전으로 대체하여 컴파일했다. 실행은 `FAIL hwp: new document preserves WKWebView`, exit 1로 끝났다. 새 테스트가 수정 전 결함을 실제로 검출하며 수정 후 31개 PASS와 대조된다. 기준 재현의 실패는 성공으로 덮지 않고 별도 증거로 보존한다.

제품 수정은 bytes revision 기반 뷰 재생성 제거 한 곳이다. 명시적 loadID를 통한 열기/재시도, 저장 요청 token/epoch 검증과 이전 응답 차단은 유지한다. 회귀 테스트는 같은 ContentView 안의 원본 객체 유지, native/Studio epoch 일치, 실제 저장 파일과 종료 결과를 확인한다. 종료 reply 주입과 실제 창 닫힘을 구분해 보고한다.

HostApp Debug build, HostAppTests 224개, 통합 31개, asset/AppKit 경계, actionlint, Python 구문 및 main/devel 내용 gate가 통과했다. PR CI는 게시 후 같은 회귀를 실행하며 결과와 최종 head 검토를 PR 코멘트에 기록한 뒤 병합한다.

## 정리와 범위

이번 작업의 진단 앱과 Debug app 경로만 등록 해제했다. 설치본은 0.2.0(18)이며 활성 Preview/Thumbnail도 해당 `/Applications` 경로의 0.2.0이다. 기존 시스템 개발 카탈로그 잔존 전체를 이번 작업 성공으로 표시하지 않는다.

스크린샷은 #532 의 동일 결함을 관찰한 수정 전 저장 경고만 포함한다. 수정 후 UI 스크린샷을 꾸미거나 실제 실행하지 않은 signed candidate UI 검증을 주장하지 않는다. 실제 SwiftUI 자동 검사·로그가 수정 후 증거다.

새 서명 후보의 실제 Mac·VM·공개 후 Sparkle 수용은 #532 에서 별도로 수행하며 #513 / #337 을 닫지 않는다. #536 은 이번 PR에 포함하지 않는다.
