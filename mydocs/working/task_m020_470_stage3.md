# Task M020 #470 Stage 3 완료보고서

## 통합 검증

- decoder 18개 계약, 기본 HWP 3종/HWPX 1종 native smoke, page boundary/producer null-output 검증 통과.
- `xcodegen generate`, HostApp Debug build 성공(12.301초). no-AppKit, diff check, core/Cargo/FFI lock 불변 확인.
- KTX/request core SVG·native PNG·diff 생성 및 육안 확인. core/native 차이 비율은 각각 0.556528/0.177364이며 raster 크기 1px 차이, font/gradient/line 표현 차이가 남아 있다. pixel parity 통과로 표시하지 않는다.
- #394 head `de4d374`의 decoder/document로 같은 native smoke를 별도 컴파일해 비교했다. KTX TextRun 410→415, 한글 scalar 209→234, request TextRun 102→103, 한글 scalar 309→312로 기존 unsigned metadata decode 실패에 가려졌던 텍스트가 복원됐다. renderer source는 변경하지 않았다.

로그/이미지: `build.noindex/task470/{decoder.log,render.log,build.log,baseline.log,compare-host/}`.

## 개발 등록 정리

빌드의 LaunchServices 등록 명령을 확인한 뒤 표준 `check-extension-registration-hygiene.sh --cleanup-dev-registrations`를 실행했다. task470 앱과 appex의 unregister 호출을 기록했고 PlugInKit provider에는 기존 `/Applications` 및 사용자 `Applications` 설치본만 남아 있다. 전체 hygiene 명령은 과거 LaunchServices 경로 잔존과 두 설치본 provider 때문에 exit 1이므로 전역 hygiene 통과라고 보고하지 않는다. 기존 설치본·과거 작업 파일은 보존했다. 이번 작업은 설치본 Finder smoke 또는 release gate가 아니다.
