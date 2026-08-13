# Task #460 Stage 1 완료 보고서

## 단계 목적

문서 유래 page SVG를 PDF·인쇄용 offscreen `WKWebView`에 삽입하는 경계를 production code 변경 전에 조사하고, macOS 12에서 적용할 content JavaScript, metrics content world, CSP, navigation, website data store와 network test 계약을 확정한다.

## 산출물

- `mydocs/plans/task_m040_460_impl.md` (444줄)
  - 실제 upstream page SVG 경로 조사 결과를 반영해 `font-src data:` 후보를 `font-src 'none'`으로 축소했다.
  - data font를 현재 계약 밖 resource로 명시하고 Stage 4 회귀 범위를 data image 중심으로 보정했다.
- `mydocs/working/task_m040_460_stage1.md`
  - WebKit SDK 계약, upstream SVG 통계, CSP·scheme 허용표와 network test 구조를 기록했다.
- `mydocs/orders/20260808.md`
  - #460 상태를 Stage 1 완료 및 Stage 2 승인 대기로 갱신했다.

production source와 test source는 이 단계에서 변경하지 않았다.

## 조사 결과와 보안 계약

### WebKit SDK 계약

- 프로젝트 deployment target은 macOS 12.0이다.
- Xcode 26.6의 macOS 26.5 SDK에서 `WKWebpagePreferences.allowsContentJavaScript`와 content-world 지정 `evaluateJavaScript`는 macOS 11.0 이상 API다.
- SDK header는 `allowsContentJavaScript = false`가 inline/external script, `javascript:` URL과 web content가 참조한 모든 JavaScript 실행을 막지만, 앱의 `evaluateJavaScript`와 `WKUserScript` 실행은 허용한다고 명시한다.
- `WKContentWorld.defaultClientWorld`는 page world와 JavaScript 전역 상태를 분리하면서 DOM과 built-in DOM API에 접근할 수 있다.
- `WKWebsiteDataStore.nonPersistentDataStore`는 website data를 파일 시스템에 기록하지 않는다.
- macOS 12 target Swift typecheck에서 다음 API 조합이 가용함을 확인했다.
  - `WKWebsiteDataStore.nonPersistent()`
  - `defaultWebpagePreferences.allowsContentJavaScript = false`
  - `WKContentWorld.defaultClient`
  - result 기반 `evaluateJavaScript(_:in:in:completionHandler:)`

따라서 Stage 2에서는 content JavaScript를 끄고 metrics script만 `WKContentWorld.defaultClient`에서 실행한다. 기존 macOS 11 availability 분기는 deployment target보다 낮으므로 제거한다.

### 현재 trust boundary

- `RhwpStudioPagePDFRenderer`가 page SVG 문자열을 HTML body에 직접 넣고 `loadHTMLString(baseURL: nil)`로 로드한다.
- 현재 configuration은 content JavaScript를 명시적으로 켜고 있으며 persistent default website data store를 사용한다.
- metrics는 page world 기본 overload의 `evaluateJavaScript`로 측정한다.
- HTML wrapper에는 CSP가 없고 navigation delegate는 load failure와 web process termination만 처리한다.
- PDF 저장의 `RhwpStudioPDFExportController`와 일반 인쇄의 `RhwpStudioPrintController`가 각각 같은 renderer type을 전용 인스턴스로 소유한다.
- main editor WebView, Quick Look과 Thumbnail renderer는 이 offscreen renderer를 사용하지 않으므로 변경 범위 밖이다.

### bundled/upstream SVG resource 조사

bundled `rhwp-studio` manifest의 기준은 release tag `v0.8.2`, resolved commit `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`다.

고정 커밋의 호출 경로는 다음과 같다.

1. `rhwp-studio/src/main.ts`의 `getPageSvg`가 `wasm.renderPageSvg(page)`를 호출한다.
2. `src/wasm_api.rs`의 `renderPageSvg`가 `render_page_svg_native`를 호출한다.
3. 기본 경로는 `render_page_svg_legacy_native`이며 `SvgRenderer::new()`를 사용한다.
4. data font `@font-face` 생성 코드는 별도 layer/profile·font embedding 경로에는 존재하지만 현재 HostApp `getPageSvg` 기본 경로에는 적용되지 않는다.
5. legacy renderer와 OLE/WMF 변환 경로는 bitmap과 중첩 vector를 `data:image/...`로 생성할 수 있다.

고정 커밋의 golden/report SVG 9개를 스캔한 결과는 다음과 같다.

| 항목 | 결과 |
|------|------|
| `data:image/jpeg` href | 4건 |
| `data:image/png` href | 3건 |
| 내부 `url(#...)` | 129건 |
| HTTP/HTTPS href 또는 CSS URL | 0건 |
| `blob:`·relative href | 0건 |
| `<script>`·event handler | 0개 파일 |
| `<style>`·style attribute·`@font-face` | 0개 파일 |
| `<foreignObject>` | 0개 파일 |

표본에는 없지만 upstream 생성 코드가 `data:image/svg+xml`도 만들 수 있으므로 `img-src data:`는 MIME별 세분화가 불가능한 CSP scheme source로 유지하고 nested data SVG 보안 fixture를 추가한다. data font는 현재 경로에 필요하지 않으므로 허용하지 않는다.

### 확정 CSP

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

- `style-src 'unsafe-inline'`은 HostApp wrapper CSS와 SVG의 inline presentation 호환을 위한 예외다. CSS가 참조하는 외부 resource는 나머지 fetch directive와 `default-src 'none'`이 거부한다.
- `img-src data:`는 실제 bitmap과 생성 가능한 nested vector image를 보존한다.
- script, connect, frame, object, media, worker, manifest, font는 모두 거부한다.
- `<base>`와 form 제출은 각각 `base-uri 'none'`, `form-action 'none'`으로 거부한다.
- [W3C CSP3 meta element 계약](https://www.w3.org/TR/CSP3/#meta-element)에 따라 meta CSP는 선행 콘텐츠에 소급 적용되지 않으므로 charset 다음, untrusted SVG보다 먼저 둔다.
- meta CSP에서 지원되지 않는 `sandbox`와 이 renderer의 embedding과 무관한 `frame-ancestors`는 사용하지 않는다.

### scheme과 navigation 허용표

| 입력 | 정책 | 담당 방어선 |
|------|------|-------------|
| 앱이 시작한 최초 main-frame `about:blank` load | 페이지마다 1회 허용 | navigation delegate |
| 이후 top-level navigation | 거부 | navigation delegate |
| subframe·target frame 없는 new-window navigation | 거부 | navigation delegate + `frame-src 'none'` |
| HTTP/HTTPS resource | 거부 | CSP, loopback 통합 테스트 |
| `blob:` resource/navigation | 거부 | CSP + navigation delegate |
| file·relative·custom scheme | 거부 | CSP + navigation delegate |
| `data:` image | 허용 | `img-src data:` |
| `data:` font/script/frame/media | 거부 | 전용 CSP directive |
| 동일 SVG 내부 `url(#id)` | 허용 | same-document fragment |

navigation delegate는 app-owned initial load만 허용하는 상태를 페이지마다 초기화한다. initial load 이후 main-frame navigation, 모든 subframe과 `targetFrame == nil` 요청은 취소한다. CSP는 image, CSS URL, font와 connect 같은 subresource를 담당하고 navigation delegate는 문서 이동을 담당한다.

### Stage 3 network test 구조

- HostAppTests에 이미 연결된 `Network.framework`를 사용해 test-only `NWListener` helper를 둔다.
- `.tcp` listener를 임의 port로 열고 state가 `.ready`가 된 뒤에만 `127.0.0.1` HTTP/HTTPS fixture URL을 구성한다.
- listener bind 실패나 ready timeout은 요청 0건 성공이 아니라 test failure다.
- connection handler는 accepted TCP connection 수를 thread-safe하게 기록하고, 요청이 발생해도 renderer가 무기한 대기하지 않도록 최소 응답 또는 connection 종료를 수행한다.
- renderer completion 뒤 짧은 grace window까지 기다린 다음 accepted connection 수가 정확히 0인지 판정한다.
- 전체 test에는 상한 timeout을 두어 CSP·navigation 오류가 completion 누락으로 이어지는 경우 실패시킨다.
- image, `<use>`, CSS URL/font, iframe/object, meta refresh와 new-window 형태를 한정된 합성 fixture로 검증한다.
- `URLProtocol`은 WKWebView networking process의 실제 요청 관측을 보장하지 않으므로 완료 근거로 사용하지 않는다.

Stage 2 production 변경은 기존 `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift`에 한정하는 것을 우선한다. policy 분리가 필요하지 않으면 production API와 `project.yml` source 항목을 늘리지 않는다. Stage 3 listener/helper는 test target 내부에 둔다.

## 본문 변경 정도 / 본문 무손실 여부

- production code, test code와 bundled `rhwp-studio` asset은 변경하지 않았다.
- 구현계획서는 Stage 1 조사로 불필요함이 확인된 data font 권한만 축소했으며 기존 Stage 순서와 Issue #460 범위를 유지했다.
- HWP/HWPX sample 원본은 읽기와 존재 확인만 수행했으며 변경하지 않았다.
- 별도 `/Users/melee/Documents/projects/forks/rhwp` 작업트리의 기존 dirty file에는 쓰지 않고 pinned commit object만 조회했다.

## 검증 결과

### 구현계획 Stage 1 검증

1. SDK header 검색: 통과
   - `allowsContentJavaScript`: macOS 11.0 이상
   - `defaultClientWorld`: DOM 접근 가능한 client world 계약 확인
   - content-world 지정 `evaluateJavaScript`: macOS 11.0 이상
2. current renderer 검색: 통과
   - renderer, HTML wrapper, metrics script와 `createPDF` 호출 위치 확인
   - PDF export와 print controller의 공용 renderer type 사용 확인
3. bundled asset 검색: 통과
   - bundled JS/CSS의 data image와 `@font-face` 가능성 확인
   - 실제 page SVG 계약은 pinned source와 representative SVG로 별도 판정
4. 대표 SVG 조사와 scheme 표 대조: 통과
   - 9개 파일, external/blob/relative URL 0건
   - data JPEG 4건, PNG 3건, internal fragment 129건
5. Stage 4 대표 sample 존재 확인: 통과
   - `samples/basic/KTX.hwp`
   - `samples/hwp-multi-001.hwp`
   - `samples/hwpx/hwpx-01.hwpx`
6. macOS 12 target Swift API typecheck: 통과
7. `git diff --check`: 통과

## 잔여 위험

- meta CSP와 navigation policy의 macOS 12 실제 WebKit 동작은 Stage 2·3 통합 테스트 전까지 계약과 정적 근거 수준이다.
- `style-src 'unsafe-inline'`은 SVG의 시각 표현 변경을 허용하지만 외부 fetch는 다른 directive가 차단한다. 실제 차단 공백은 loopback 테스트로 확인해야 한다.
- `img-src data:`는 nested SVG를 포함하므로 data SVG 안의 script/event 비실행을 별도 WebKit fixture로 증명해야 한다.
- future bundled renderer가 `getPageSvg`를 layer/profile 경로로 변경해 embedded font를 넣으면 현재 `font-src 'none'`이 시각 충실도에 영향을 줄 수 있다. 그 변경은 asset 갱신 시 명시적 정책 재검토 대상이다.
- initial `about:blank` navigation의 정확한 delegate event 순서와 페이지 반복 상태는 Stage 3에서 검증해야 한다.

## 다음 단계 영향

Stage 2에서는 다음 범위만 구현한다.

- non-persistent website data store
- content JavaScript 비활성화
- untrusted SVG 앞 CSP meta 삽입
- `WKContentWorld.defaultClient` metrics evaluation
- script/event/`javascript:`/nested data SVG와 data image 회귀 테스트

navigation policy와 실제 loopback 요청 0건 검증은 계획대로 Stage 3에 유지한다. content rule list는 기본안에 추가하지 않으며 CSP 차단 공백이 실제로 확인될 때만 검토한다.

## 승인 요청

Stage 1 조사 결과와 보정된 최소 권한 정책을 검토하고 Stage 2 content JavaScript·CSP 격리 구현 진입 승인을 요청한다.
