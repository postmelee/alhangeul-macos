# Task #460 Stage 3 완료 보고서

## 단계 목적

Stage 2의 content JavaScript 비활성화와 CSP를 보완해 PDF·인쇄 renderer가 앱이 시작한 최초 내부 문서 외 navigation을 허용하지 않도록 한다. test-local loopback endpoint를 통해 합성 SVG의 HTTP/HTTPS resource와 navigation 시도가 실제 WebKit에서 외부 연결을 만들지 않음을 검증한다.

## 산출물

- `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` (371줄)
  - 각 page의 최초 `about:blank` main-frame navigation만 한 번 허용하는 상태를 추가했다.
  - navigation action의 URL, main-frame 여부와 initial-load 상태를 판정하는 `RhwpStudioPagePDFNavigationPolicy`를 추가했다.
  - 최초 load 이후 main-frame navigation, subframe와 target frame이 없는 new-window 요청을 취소한다.
  - renderer 종료 시 initial-load 상태도 초기화한다.
- `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` (457줄)
  - `about:blank` main-frame 1회 허용과 HTTP/HTTPS/file/blob/custom scheme, subframe, new-window 거부 정책 행렬을 검증한다.
  - test-local `NWListener` 기반 `LoopbackRequestProbe`를 추가했다.
  - listener ready, bind failure, 준비 timeout과 양성 대조 연결 timeout을 명시적으로 판정한다.
  - CSP 없는 test-only WebView가 listener에 실제 연결되는 양성 대조군을 먼저 확인한다.
  - hardened renderer의 image, `<use>`, CSS paint, font, stylesheet, HTML image, iframe, object, meta refresh와 new-window fixture가 외부 연결을 만들지 않음을 검증한다.
  - renderer의 page count, searchable text와 exactly-once completion을 함께 확인한다.
- `mydocs/working/task_m040_460_stage3.md`
  - Stage 3 navigation 계약, network probe 결과와 Stage 4 잔여 범위를 기록했다.
- `mydocs/orders/20260808.md`
  - #460 상태를 Stage 3 완료 및 Stage 4 승인 대기로 갱신했다.

신규 production 파일과 project source 항목은 필요하지 않아 `project.yml`과 생성된 Xcode project의 tracked 변경은 없다.

## 구현 결과

### Navigation 최소 허용 정책

renderer가 `loadHTMLString(..., baseURL: nil)`을 호출하기 직전에 page별 initial main-frame load 대기 상태를 설정한다. navigation delegate는 다음 조건이 모두 참인 action만 허용하고 상태를 즉시 소비한다.

1. renderer가 현재 page의 최초 load를 기다리는 중이다.
2. `targetFrame?.isMainFrame == true`다.
3. request URL이 정확히 `about:blank`다.

따라서 같은 `about:blank`의 재이동, HTTP/HTTPS, file, blob, custom scheme, subframe와 `targetFrame == nil`인 new-window는 취소된다. 차단 action은 권한 확대나 외부 이동 없이 취소하며, 정상 inline SVG의 PDF 변환은 기존 completion 흐름을 유지한다.

### Loopback network probe

- `NWListener(using: .tcp, on: .any)`로 `127.0.0.1`의 임시 port를 사용한다.
- `.ready` 이후에만 fixture URL을 만들며 `.failed`, ready 전 `.cancelled`와 3초 timeout은 테스트 실패다.
- accepted TCP connection을 main actor에서 계수한다.
- CSP 없는 별도 test WebView의 HTTP image가 같은 listener에 도달하는 양성 대조를 확인한다. 따라서 hardened renderer의 연결 0건은 listener 자체의 미검출이나 WebKit network 경로 부재로 간주하지 않는다.
- 양성 대조 연결을 초기화한 뒤 hardened renderer 완료 후 500ms 안정화 구간까지 accepted connection이 정확히 0인지 확인한다.
- 공개 인터넷, DNS와 고정 port에 의존하지 않는다.

### 외부 resource와 navigation fixture

단일 합성 입력에 다음 HTTP/HTTPS 참조를 포함했다.

- SVG `<image>`와 `<use>`
- inline `<style>`의 `@font-face`와 external paint URL
- HTML stylesheet와 image
- iframe과 object
- meta refresh
- `target="_blank"` link

renderer는 한 페이지 PDF를 정상 생성하고 `NETWORK-BLOCKED` text를 유지했으며 completion은 한 번만 호출됐다. 양성 대조 연결 이후 hardened fixture의 accepted connection 수는 0이었다. CSP와 navigation delegate 사이의 공백이 관측되지 않아 content rule list는 추가하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- HTML wrapper의 CSP, page SVG 본문, metrics script와 PDF 생성·병합 코드는 변경하지 않았다.
- 기존 page count, media box, searchable text, sequential page conversion과 completion 계약을 유지했다.
- portrait/landscape 혼합 2-page fixture가 새 navigation 상태를 거쳐 반복 성공하므로 page마다 최초 load 권한이 정상 재설정됨을 확인했다.
- PDF 저장과 일반 인쇄 controller의 공유 renderer 구조, main editor WebView, Quick Look/Thumbnail, bundled `rhwp-studio`와 `rhwp` core는 변경하지 않았다.
- HWP/HWPX sample 원본과 별도 `/Users/melee/Documents/projects/forks/rhwp` 작업트리에는 쓰지 않았다.

## 검증 결과

### 구현계획 Stage 3 검증

1. 대상 external resource/navigation HostAppTests 반복 실행: 통과
   - navigation policy, loopback 차단, portrait/landscape 2-page 테스트를 각각 3회 실행했다.
   - 9 tests, 0 failures, `** TEST SUCCEEDED **`
   - loopback 테스트는 매 iteration마다 CSP 없는 WebView의 양성 연결과 hardened renderer의 연결 0건을 함께 확인했다.
2. 전체 HostAppTests: 통과
   - `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task460/stage3-tests CODE_SIGNING_ALLOWED=NO test`
   - 126 tests, 0 failures, `** TEST SUCCEEDED **`
3. HostApp Debug 빌드: 통과
   - `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task460/stage3-build CODE_SIGNING_ALLOWED=NO build`
   - `** BUILD SUCCEEDED **`
4. URL/CSP 정적 검색: 통과
   - production renderer에는 deny-by-default CSP directive만 존재한다.
   - HTTP/HTTPS/blob 참조는 정책·보안 fixture와 기존 analytics 테스트 범위에서 확인됐다.
5. 공유 Swift 코드 플랫폼 경계 검사: 통과
   - `./scripts/check-no-appkit.sh`
   - `OK: shared Swift code has no AppKit/UIKit dependencies`
6. `git diff --check`: 통과

추가 확인으로 Stage 3 Debug app의 bundled `rhwp-studio` asset 검증도 통과했다. WebKit test process의 RunningBoard, pasteboard와 linkd 관련 sandbox 진단은 출력됐지만 모든 대상·전체 테스트와 PDF 생성 결과는 정상 통과했다.

## 잔여 위험

- 자동 테스트는 현재 개발 호스트의 WebKit에서 실행됐다. deployment target macOS 12의 공개 API 계약은 Stage 1에서 확인했지만 실제 macOS 12 장비 런타임 검증은 별도 환경이 필요하다.
- navigation policy는 renderer의 현재 `loadHTMLString(baseURL: nil)` 계약에 맞춰 정확한 `about:blank`만 허용한다. 향후 base URL 또는 로드 방식이 바뀌면 정책과 테스트를 함께 갱신해야 한다.
- loopback probe는 TCP connection 발생 여부를 판정하며 개별 HTTP request body나 path를 해석하지 않는다. 보안 완료 조건인 외부 연결 0건 판정에는 충분하지만 요청별 프로토콜 분석 용도는 아니다.
- 실제 대표 HWP/HWPX의 page geometry, text, embedded image와 인쇄 패널 방향 회귀는 Stage 4 범위다.
- Stage 2의 `style-src 'unsafe-inline'`과 `img-src data:` 최소 예외는 유지된다. 실제 문서 충실도와 data image 보존을 Stage 4에서 다시 확인해야 한다.

## 다음 단계 영향

Stage 4에서는 강화된 renderer를 실제 PDF 저장·인쇄 경로와 대표 문서에 적용해 보안 정책이 정상 본문을 손상하지 않는지 검증한다.

- synthetic portrait, landscape와 mixed page의 media box, page count, text와 raster를 확인한다.
- KTX 가로 1-page, 대표 다중 HWP와 9-page HWPX의 geometry, searchable text와 nonblank raster를 확인한다.
- embedded data image 보존과 PDFKit 인쇄 orientation policy를 검증한다.
- 원본 hash와 수정 시각을 smoke 전후 비교한다.
- 실제 PDF 저장과 인쇄 패널 preview는 작업지시자 수동 확인을 포함한다.

Stage 3에서 CSP·navigation 차단 공백이 발견되지 않았으므로 Stage 4에 content rule list 도입 작업은 이관하지 않는다.

## 승인 요청

Stage 3 외부 resource·navigation 차단 구현과 검증 결과를 검토하고 Stage 4 PDF·인쇄 보안 회귀 검증 진입 승인을 요청한다.
