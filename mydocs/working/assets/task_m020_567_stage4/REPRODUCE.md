# #567 Stage 4 재현

제품의 Coordinator·native 공급/observer·설정 View와 정식 v0.8.7 Studio를 사용한다. 활성 metadata 열거만 격리된 파일 목록으로 주입하고 고운바탕 파일의 bytes·stat·POSIX 읽기 권한·삭제·관리 복사는 실제로 처리한다. 원래 다운로드 파일과 사용자 글꼴·설정은 변경하지 않는다. OS 글꼴 설치나 signed sandbox 권한 복원 성공의 증거는 아니다.

## 준비

- macOS 로그인 GUI, Xcode/Swift 및 Node, Stage 3.2의 generated `Frameworks/Rhwp.xcframework`가 필요하다.
- 설정 창 캡처에 현재 프로세스 전용 ScreenCaptureKit API를 사용하므로 probe는 macOS 14.4 이상에서 실행한다. 제품 macOS 12 target compile/link 결과와 구분한다.
- [구현계획의 테스트 글꼴](../../../plans/task_m020_567_impl.md#4-다운로드한-테스트-글꼴)에 기록한 Google Fonts 고운바탕 Regular/Bold를 `build.noindex/task567/fonts/gowun-batang/`에 준비한다. [배포 기록](font-provenance.json)과 [OFL 원문](OFL.txt)을 유지하고 원본 SHA256을 확인한다. OS 설치는 필요 없다.
- 이미 열려 있는 probe 앱의 실행 파일을 덮어쓰지 않도록 별도 output 폴더를 사용한다.

## 명령

저장소 루트에서 실행한다.

```bash
scripts/test-font-library.sh
python3 scripts/probe-studio-font-integration.py --changes --interactive \
  --output-dir build.noindex/task567/stage4-reproduction
python3 scripts/smoke-studio-document-lifecycle.py \
  --fixture samples/re-font-dotum-empty-hancom.hwp
scripts/verify-rhwp-studio-assets.sh \
  --upstream-dir build.noindex/task567/stage3-2/upstream-v087
scripts/check-no-appkit.sh
```

`--changes`는 새 UUID state에 전용 원본 복사본과 설치 설정·보관함을 만든다. Canvas2D/CanvasKit의 열린 문서 변경, 원본 없는 관리 복사본 새 프로세스, 관리 복사본 없는 설치 원본 새 프로세스를 순서대로 실행한다. 실패하면 nonzero로 끝나며 결과 JSON의 `error`를 확인한다. 생성한 HWP/HWPX를 같은 WASM으로 다시 열어 본문·원래 이름·굵기·alias 미유출을 대조한다.

`--interactive`는 검증 후 설치 사용이 켜진 새 프로세스의 문서·설정 창을 유지한다. 상단 “Mac에 설치된 글꼴 사용” checkbox를 껐다 켜서 현재 문서와 상단 글꼴 목록의 변화를 확인한다. 보관함 버튼은 같은 격리 저장소를 연다. 모든 창을 닫으면 프로세스를 종료하고 해당 앱 경로의 LaunchServices 등록만 해제한다. 전역 Quick Look cache reset이나 개발 확장 등록은 하지 않는다.

## 보존 결과

- `changes-result.json`: 열린 문서 변경 31항목.
- `reopen-result.json`: 관리 복사본 복원 및 다음 대조 준비 5항목.
- `installed-reopen-result.json`: 설치 설정·원본 자동 사용 4항목.
- `change-face-proof.json`: 현재 frame/token에 성공 응답한 출처 ID·PS·검증 hash.
- `changes-saved-proof.json`, `changes-result.hwp/.hwpx`: 저장한 두 형식의 원래 본문·이름·스타일 대조.
- 설정 PNG는 현재 프로세스 소유 창을 캡처하고 Studio PNG는 실제 WKWebView를 캡처했다.
- `evidence.json`: 환경·소스 fingerprint·실제 검증 범위와 제한.
- `checksums.json`: 본 파일과 보존한 증거의 SHA256. 체크섬 파일 자신은 제외한다.

최종 native 104·JS 24·lifecycle 43항목과 HostApp build 및 Studio provenance 결과를 로그로 함께 보존했다. 전역 개발 등록 clean 판정, 최소 OS·Intel 실제 실행, undo stack 자체 및 대규모 성능 수용은 포함하지 않는다.
