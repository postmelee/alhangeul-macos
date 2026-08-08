# Task #460 Stage 2 완료 보고서

## 단계 목적

PDF 저장과 일반 인쇄가 공유하는 offscreen `WKWebView`에서 문서 유래 page SVG를 능동 콘텐츠가 아닌 정적 렌더 입력으로 취급한다. website data를 비영구화하고 content JavaScript를 비활성화하며, SVG보다 먼저 적용되는 최소 권한 CSP와 앱 소유 metrics script용 `WKContentWorld.defaultClient`를 도입한다.

## 산출물

- `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` (333줄)
  - renderer 전용 `WKWebView`에 non-persistent website data store를 적용했다.
  - content JavaScript를 명시적으로 비활성화하고 deployment target보다 낮은 macOS 11 availability 분기를 제거했다.
  - page metrics 계산을 page world가 아닌 `WKContentWorld.defaultClient`에서 실행하도록 변경했다.
  - result 기반 WebKit callback을 기존 오류 처리와 exactly-once completion 흐름에 연결했다.
  - HTML wrapper에 확정 CSP를 charset 다음, 문서 유래 SVG보다 먼저 삽입했다.
- `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` (254줄)
  - CSP 문자열의 정확한 directive와 SVG보다 앞선 배치를 검증한다.
  - inline script, root/image event handler와 `javascript:` URL이 실행되지 않음을 PDF text sentinel로 검증한다.
  - 허용된 embedded data PNG가 PDF raster에 유지됨을 검증한다.
  - nested data SVG의 시각 결과는 유지하면서 내부 script와 event handler가 실행되지 않음을 색상 raster로 검증한다.
- `mydocs/working/task_m040_460_stage2.md`
  - Stage 2 구현, 검증과 Stage 3 잔여 범위를 기록했다.
- `mydocs/orders/20260808.md`
  - #460 상태를 Stage 2 완료 및 Stage 3 승인 대기로 갱신했다.

신규 production helper나 project source 항목은 필요하지 않아 `project.yml`과 생성된 Xcode project의 tracked 변경은 없다.

## 구현 결과

### WebView configuration

- `configuration.websiteDataStore = .nonPersistent()`를 적용해 PDF·인쇄 renderer의 website data가 파일 시스템에 지속되지 않도록 했다.
- `configuration.defaultWebpagePreferences.allowsContentJavaScript = false`를 직접 설정했다.
- popup 금지 설정인 `javaScriptCanOpenWindowsAutomatically = false`는 유지했다.
- renderer의 configuration과 WebView를 외부에 노출하거나 공유하지 않았다.

### HTML CSP

다음 policy를 단일 상수로 생성해 `<meta charset>` 다음, wrapper style과 untrusted SVG보다 먼저 배치했다.

```text
default-src 'none';
script-src 'none';
connect-src 'none';
frame-src 'none';
object-src 'none';
media-src 'none';
worker-src 'none';
manifest-src 'none';
base-uri 'none';
form-action 'none';
style-src 'unsafe-inline';
img-src data:;
font-src 'none';
```

wrapper CSS와 SVG의 inline presentation은 유지하고, 현재 upstream page SVG 계약에 필요한 data image만 허용했다. HTTP, HTTPS, blob과 data font는 허용하지 않는다.

### 앱 소유 metrics 실행

content JavaScript가 꺼진 상태에서도 HostApp이 소유한 `pageMetricsScript`는 `evaluateJavaScript(_:in:in:completionHandler:)`와 `.defaultClient` content world를 통해 DOM geometry를 읽는다. 성공 결과는 기존 metrics parser에 전달하고 실패 결과는 기존 renderer completion 오류로 종료한다. content JavaScript를 다시 켜는 fallback은 두지 않았다.

### 능동 콘텐츠와 data image 회귀 테스트

- 문서 SVG의 inline `<script>`, root `onload`, data PNG의 `onload`가 PDF text sentinel을 변경하지 않는다.
- `javascript:` 링크의 표시 문자열은 PDF에 남지만 URL script는 실행되지 않는다.
- known-good data PNG를 페이지 전체에 렌더한 PDF raster에서 red pixel 비율이 50%를 넘는다.
- nested `data:image/svg+xml`의 green 정적 도형은 PDF에 남고, 내부 script나 `onload`가 실행될 때 나타날 red pixel 비율은 5% 미만이다.
- metrics가 정상 반환되고 PDF 생성이 성공하므로 content JavaScript 비활성 상태에서도 앱 소유 default-client script가 동작함을 통합 경로에서 확인했다.

## 본문 변경 정도 / 본문 무손실 여부

- 기존 page count, geometry 계산 우선순위, PDF page 병합, text layer, sequential conversion과 completion 계약은 변경하지 않았다.
- PDF 저장과 인쇄 controller는 계속 동일 renderer 결과를 공유하므로 메뉴·저장·인쇄 UX와 호출 구조는 변경하지 않았다.
- main editor WebView, Quick Look/Thumbnail, bundled `rhwp-studio`, `rhwp` core와 HWP/HWPX sample은 변경하지 않았다.
- SVG 문자열의 sanitizer나 escape 재작성은 도입하지 않아 정적 SVG markup과 embedded data image 본문은 그대로 전달된다.
- 별도 `/Users/melee/Documents/projects/forks/rhwp` 작업트리의 기존 변경에는 쓰지 않았다.

## 검증 결과

### 구현계획 Stage 2 검증

1. Xcode project 재생성: 통과
   - `xcodegen generate`
   - `project.yml` 기준으로 생성했으며 tracked project diff는 발생하지 않았다.
2. HostAppTests: 통과
   - `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task460/stage2-tests CODE_SIGNING_ALLOWED=NO test`
   - 124 tests, 0 failures, `** TEST SUCCEEDED **`
3. HostApp Debug 빌드: 통과
   - `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task460/stage2-build CODE_SIGNING_ALLOWED=NO build`
   - `** BUILD SUCCEEDED **`
4. bundled asset 검증: 통과
   - `scripts/verify-rhwp-studio-assets.sh build.noindex/task460/stage2-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
5. 공유 Swift 코드 플랫폼 경계 검사: 통과
   - `./scripts/check-no-appkit.sh`
6. content JavaScript 재활성화·불필요 availability 분기 검색: 통과
   - renderer source에 `allowsContentJavaScript = true`와 `#available(macOS 11` 없음
7. `git diff --check`: 통과

테스트 fixture의 최초 raster 색상 생성 방식과 WebKit 색상 변환을 실제 출력에 맞게 교정한 뒤 대상 테스트와 전체 HostAppTests를 다시 실행했다. 최종 source에는 진단 출력이 남지 않았다.

## 잔여 위험

- navigation delegate의 initial load 허용과 이후 top-level, subframe, new-window 차단은 아직 구현하지 않았다.
- CSP가 macOS 12 실제 WebKit에서 image, `<use>`, CSS URL, iframe/object와 navigation 형태의 loopback 요청을 모두 0건으로 만드는지는 Stage 3 통합 테스트가 필요하다.
- `style-src 'unsafe-inline'`은 시각 표현을 위해 유지했으므로 CSS가 유발하는 외부 fetch의 실제 차단은 loopback listener로 검증해야 한다.
- `img-src data:`가 허용하는 nested SVG는 현재 script/event 비실행과 정적 raster 보존을 검증했지만, 다른 외부 참조 형태는 Stage 3 network fixture에서 다룬다.
- 실제 대표 HWP/HWPX의 page geometry, text, nonblank raster와 인쇄 패널 방향 회귀는 Stage 4 범위다.

## 다음 단계 영향

Stage 3에서는 계획대로 navigation policy와 test-only `NWListener` loopback probe를 추가한다.

- 앱이 시작한 최초 내부 main-frame load만 허용하고 이후 top-level navigation을 취소한다.
- 모든 subframe과 `targetFrame == nil`인 new-window 요청을 취소한다.
- HTTP/HTTPS image, `<use>`, CSS URL, iframe/object, meta refresh와 navigation fixture가 renderer 완료 뒤 grace window까지 connection 0건인지 검증한다.
- listener 준비 실패와 timeout은 성공으로 간주하지 않는다.
- content rule list는 CSP 차단 공백이 실제로 관측될 때만 보완안으로 검토한다.

## 승인 요청

Stage 2 content JavaScript·CSP 격리 구현과 검증 결과를 검토하고 Stage 3 navigation·외부 resource 차단 통합 검증 진입 승인을 요청한다.
