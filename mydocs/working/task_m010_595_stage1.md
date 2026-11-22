# Task #595 Stage 1 — 공개 빌드의 첫 실패 지점

v0.2.5에서 그림 명령은 Studio의 HTML 파일 입력을 호출한다. macOS WKWebView 호스트에는 WKUIDelegate와 파일 선택 요청의 구현이 없었다. 실제 HWP와 HWPX의 그림 클릭에서 선택창이 나타나지 않았고, [제보](https://github.com/postmelee/alhangeul-macos/issues/595#issuecomment-7068775767)에 동일 결과를 기록했다.
