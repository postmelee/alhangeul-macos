# Task #595 — 편집 WKWebView의 파일 선택창 구현계획서

1. v0.2.5 앱과 번들의 그림 명령을 고정해, 사용자 동작이 HTML 파일 입력까지 도달하고 macOS 파일 선택이 표시되지 않음을 확인한다.
2. 기존 Coordinator를 WKUIDelegate로 연결한다. 편집기의 main frame과 자기 창의 요청만 시트로 수락한다. 동시 요청, 취소, WebView 해제 때 URL 또는 nil을 한 번 반환한다. 그림 형식과 문서 파일 선택은 호출자를 따른다.
3. T7의 별도 설치 경로에서 실제 WKWebView 그림 버튼, 선택·취소, PNG·JPEG 배치 및 HWP/HWPX 저장·재열기를 확인한다. 가능한 CI와 실제 서명 설치판 검증을 기록한다.
