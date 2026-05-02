# Task #134 Stage 5 완료 보고서

## 단계 목적

WKWebView 기반 HostApp viewer 전환 결과를 MVP smoke 관점에서 확인하고, README/운영 문서/최종 보고서를 현재 구현 기준으로 정리한다.

## 산출물

- `README.md`
  - v0.1 WKWebView viewer 체크리스트 완료 처리
  - `rhwp-studio` 기준을 `edwardkim/rhwp` `v0.7.9` snapshot으로 보정
  - Checks와 Project Structure에 `rhwp-studio` asset 검증과 WKWebView viewer 경로 반영
- `mydocs/manual/build_run_guide.md`
  - HostApp WKWebView viewer smoke test 절차 추가
- `mydocs/working/task_m010_134_stage5.md`
  - Stage 5 완료 보고서
- `mydocs/report/task_m010_134_report.md`
  - Task #134 최종 보고서
- `mydocs/orders/20260503.md`
  - #134 완료 처리

## 검증 환경

- worktree: `/private/tmp/rhwp-mac-task134`
- branch: `devel-webview`
- Debug app: `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app`
- HWP smoke sample: `samples/basic/KTX.hwp`
- HWPX smoke sample: `samples/hwpx/hwpx-01.hwpx`
- `rhwp-studio` upstream 기준: `edwardkim/rhwp` `v0.7.9`, resolved commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863`

## 검증 결과

```bash
$ xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [0.324 sec]
```

결과: 성공. Xcode가 CoreSimulatorService/DVT 관련 경고를 출력했지만 macOS HostApp build 자체는 성공했다.

```bash
$ find build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources -maxdepth 4 -type f
```

결과 요약:

- `rhwp-studio/index.html` 존재
- `rhwp-studio/assets/index-CCXookfl.js` 존재
- `rhwp-studio/assets/index-ro3nVBB2.css` 존재
- `rhwp-studio/assets/rhwp_bg-DtQ01XFR.wasm` 존재
- bundled fonts/icons/PWA 보조 asset 존재

```bash
$ test -f build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/index.html
$ test -f build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/assets/rhwp_bg-DtQ01XFR.wasm
```

결과: 둘 다 성공.

```bash
$ /usr/bin/open -n -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/basic/KTX.hwp
$ pgrep -x AlhangeulMacHost
11719
$ /usr/bin/osascript -e 'tell application "System Events" to tell process "AlhangeulMacHost" to get name of windows'
알한글
```

결과: HWP 샘플 open 후 Debug HostApp 프로세스와 앱 창이 유지되었다.

```bash
$ /usr/bin/open -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/hwpx/hwpx-01.hwpx
$ /usr/bin/osascript -e 'tell application "System Events" to tell process "AlhangeulMacHost" to count windows'
2
$ /usr/bin/osascript -e 'tell application "System Events" to tell process "AlhangeulMacHost" to get name of windows'
알한글, 알한글
```

결과: HWPX 샘플 open 후 Debug HostApp 프로세스와 앱 창이 유지되었다. 이 smoke는 launch/document open handoff와 WKWebView bundle resource 연결의 최소 확인이며, 문서 내용의 세부 시각 정합성은 별도 수동/자동 UI 검증으로 보강해야 한다.

```bash
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

결과: 성공.

```bash
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task134/Sources/HostApp/Resources/rhwp-studio
```

결과: 성공.

```bash
$ rg -n "WKWebView|rhwp-studio|HostApp viewer|Quick Look|Thumbnail" README.md mydocs/tech mydocs/manual Sources
```

결과 요약:

- README와 architecture/manual 문서가 WKWebView HostApp viewer 경로를 설명한다.
- `Sources/HostApp`에 WebKit/WKWebView bridge가 있다.
- Quick Look/Thumbnail native 경로는 별도 문맥으로 남아 있다.

```bash
$ git diff --check
```

결과: 출력 없음. whitespace error 없음.

## 완료 판단

- HostApp Debug build 성공.
- app bundle 안에서 `rhwp-studio` entrypoint와 WASM asset 확인.
- HWP/HWPX 샘플을 Debug HostApp으로 열었을 때 앱 프로세스와 창이 유지됨 확인.
- `Sources/RhwpCoreBridge` AppKit/UIKit 직접 의존 없음 확인.
- README/빌드 가이드/최종 보고서/오늘할일 갱신 완료.

## 잔여 위험

- Stage 5 smoke는 process/window 유지 기준의 최소 검증이다. WKWebView 내부 canvas/text 렌더링의 시각 정합성, 페이지 이동, zoom control 세부 동작은 foreground 수동 QA 또는 UI 자동화가 필요하다.
- Debug build는 `CODE_SIGNING_ALLOWED=NO` 산출물이므로 Finder Quick Look/Thumbnail registration 판정에는 사용하지 않는다.
- bundled `rhwp-studio`의 service worker/PWA 산출물과 CDN font fallback은 app launch smoke에서 blocker로 드러나지 않았지만, 완전 offline/네트워크 차단 정책 검증은 후속 범위다.
- HostApp target에는 `Sources/Shared`와 `Sources/RhwpCoreBridge`가 계속 포함된다. MVP viewer 화면은 native render tree 경로를 호출하지 않지만 target 구성 축소는 별도 설계가 필요하다.

## 다음 단계 영향

Task #134 구현 단계는 Stage 5까지 완료되었다. 다음 절차는 작업지시자 승인 후 `publish/task134` 브랜치 게시와 `devel-webview` 대상 PR 생성이다.
