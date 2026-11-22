# Task #595 — WKWebView 그림 삽입 결과

공개 v0.2.5 편집 WKWebView에는 macOS 파일 입력에 필요한 네이티브 시트 연결이 없었다. 변경한 Coordinator는 같은 문서 창의 Studio main frame에서 시작된 파일 선택을 NSOpenPanel로 처리한다.

별도 식별자의 실제 Debug HostApp에서 그림 선택창, 취소, PNG/JPEG 배치, HWP/HWPX 저장과 재열기 네 조합을 확인했다. 공개 설치본에서 재검증 후 제보를 종료한다. 원 제보 OS는 macOS 27.2 Beta다.
