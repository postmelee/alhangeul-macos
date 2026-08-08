# Task #460 최종 결과보고서

## 작업 요약

- 이슈: [#460 문서 유래 SVG의 PDF·인쇄 WebView 보안 hardening 검증 및 적용](https://github.com/postmelee/alhangeul-macos/issues/460)
- 마일스톤: v0.4 (`M040`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task460` → 게시 브랜치 `publish/task460`
- 단계 수: 5개 Stage

PDF 저장과 일반 인쇄가 공유하는 `RhwpStudioPagePDFRenderer`의 page SVG를 비신뢰 정적 렌더 입력으로 정의하고, offscreen `WKWebView`의 실행·resource·navigation 권한을 최소화했다. 문서 content JavaScript와 popup을 비활성화하고, renderer가 소유한 page metrics script만 격리된 `WKContentWorld.defaultClient`에서 실행한다.

raw SVG보다 앞선 deny-by-default CSP는 inline style과 `data:` image만 허용한다. navigation delegate는 page마다 최초 main-frame `about:blank` 한 번 외의 main/subframe 이동과 new-window를 차단한다. 정상 HWP/HWPX/KTX의 page geometry, searchable text, embedded image와 PDFKit 인쇄 결과는 유지했고, script·event handler 미실행과 외부 HTTP/HTTPS 요청 0건을 실제 WebKit 통합 테스트로 확인했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|---|---|
| `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` | non-persistent 전용 WebView configuration, content JavaScript·popup 비활성, strict CSP, default client metrics와 최초 `about:blank` 1회 navigation 정책을 구현했다. |
| `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` | script/event, data image·nested SVG, navigation, external resource 0건, geometry·text·raster·print 회귀를 검증하는 합성 WebKit 테스트와 loopback 양성 대조를 추가했다. |
| `mydocs/tech/project_architecture.md` | page SVG trust boundary, 각 방어선의 책임, 허용 resource, 실패 조건과 알려진 제한을 기록했다. |
| `mydocs/plans/task_m040_460.md` | 보안 hardening 목표, 포함·제외 범위, 설계 방향과 검증 계획을 기록했다. |
| `mydocs/plans/task_m040_460_impl.md` | WebKit 계약과 5단계 구현·검증·승인 게이트를 확정했다. |
| `mydocs/working/task_m040_460_stage1.md` | WebKit SDK 동작, upstream SVG resource 형태, CSP·scheme·navigation 계약 조사 결과를 기록했다. |
| `mydocs/working/task_m040_460_stage2.md` | content JavaScript·CSP 격리 구현과 data image 보존 결과를 기록했다. |
| `mydocs/working/task_m040_460_stage3.md` | navigation 최소 허용 정책과 loopback 외부 resource 0건 검증 결과를 기록했다. |
| `mydocs/working/task_m040_460_stage4.md` | synthetic·실제 HWP/HWPX/KTX PDF·인쇄 회귀와 원본 무손실 결과를 기록했다. |
| `mydocs/working/task_m040_460_stage5.md` | architecture 보안 경계와 clean 최종 검증 결과를 기록했다. |
| `mydocs/orders/20260808.md` | #460의 단계 진행과 완료 상태를 추적했다. |
| `mydocs/report/task_m040_460_report.md` | 전체 변경, 수용 기준, 검증과 잔여 위험을 종합했다. |

`Sources/RhwpCoreBridge`, bundled `rhwp-studio`, main editor WebView, HWP/HWPX exporter, Quick Look/Thumbnail과 Rust `rhwp` core는 변경하지 않았다. PDF export controller와 print controller는 기존처럼 같은 `RhwpStudioPagePDFRenderer`를 사용한다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|---|---:|---:|
| renderer source | 308줄 | 371줄 |
| renderer test source | 95줄 | 473줄 |
| HostAppTests | 120개 | 126개, 실패 0개 |
| page content script | 실행 가능 | `allowsContentJavaScript = false`로 실행 차단 |
| renderer data store | 기본 persistent store | `.nonPersistent()` |
| subresource 정책 | 명시적 CSP 없음 | deny-by-default CSP, inline style·`data:` image만 허용 |
| navigation 정책 | 전용 deny 계약 없음 | 최초 main-frame `about:blank` 1회 외 전부 취소 |
| 외부 요청 검증 | 정량 검증 없음 | loopback 양성 대조 후 hardened renderer 요청 0건 |

최종 보고서 작성 전 `devel...HEAD` 기준 변경은 11개 파일, 1,674줄 추가와 7줄 삭제다. production source는 renderer 한 파일에서 69줄 추가·6줄 삭제이며, test source는 378줄 추가됐다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|---|---|---|
| 수행·구현 계획 | `44c0180`, `473e685` | Issue 범위, WebKit trust boundary, 5단계 검증과 승인 게이트 확정 |
| Stage 1 | `0cb3d0b` | content/page world 실행 차이, upstream SVG resource, CSP와 navigation 계약 확정 |
| Stage 2 | `248403f` | non-persistent WebView, content JavaScript 비활성, strict CSP와 default client metrics 구현 |
| Stage 3 | `7e22edc` | 최초 `about:blank` 1회 외 navigation 차단과 실제 외부 resource 요청 0건 검증 |
| Stage 4 | `5aca07a` | 합성·실제 HWP/HWPX/KTX의 geometry, text, raster, 인쇄 방향과 원본 무손실 검증 |
| Stage 5 | `09e974e` | architecture trust boundary 문서화와 clean 최종 검증 |

## 구현 결과

### 실행 권한과 app-owned metrics 분리

renderer는 `WKWebViewConfiguration`마다 `.nonPersistent()` website data store를 사용하고 `defaultWebpagePreferences.allowsContentJavaScript = false`와 `javaScriptCanOpenWindowsAutomatically = false`를 적용한다. SVG의 `<script>`, inline event handler와 `javascript:` URL은 실행되지 않는다.

page width·height·viewBox와 rendered bounding rect 측정은 HostApp이 직접 호출하는 script만 `WKContentWorld.defaultClient`에서 수행한다. 이 world는 page script 전역과 분리되며 content JavaScript를 다시 켜는 fallback이 없다. 따라서 정적 page content의 실행 권한 없이 기존 DOM 기반 metrics 우선순위를 유지한다.

### CSP와 navigation deny-by-default

HTML wrapper는 raw SVG보다 앞에 CSP meta를 배치한다. `default-src`, script, connect, frame, object, media, worker, manifest와 font를 `'none'`으로 두고 `base-uri`와 `form-action`도 거부한다. 정상 upstream page 표현에 필요한 `style-src 'unsafe-inline'`과 `img-src data:`만 예외다.

navigation delegate는 renderer가 `loadHTMLString(baseURL: nil)`으로 만드는 최초 main-frame `about:blank` navigation을 page마다 한 번 허용한다. 그 뒤의 main-frame 이동, subframe, `targetFrame == nil` new-window와 HTTP/HTTPS/file/blob/custom scheme navigation은 취소한다.

CSP는 image·font·CSS 등 subresource를, navigation policy는 frame·document 이동을 담당한다. non-persistent store는 영구 website data를 남기지 않는 격리선이며 다른 두 정책의 대체 수단으로 취급하지 않는다.

### 실제 WebKit 공격·보존 검증

test-local `NWListener`는 CSP가 없는 양성 대조 WebView가 loopback HTTP endpoint에 실제 연결되는지 먼저 확인한다. 같은 endpoint를 가리키는 hardened SVG의 HTTP/HTTPS image, `<use>`, CSS paint/font/stylesheet, iframe, object, meta refresh와 new-window fixture는 renderer 성공과 연결 0건을 함께 만족한다.

별도 sentinel은 SVG `<script>`, `onload`와 nested data SVG script가 실행되지 않음을 확인한다. 동시에 searchable text, embedded data PNG, nested data SVG raster, portrait/landscape media box와 PDF page count가 보존된다.

### PDF·인쇄 정상 경로 보존

KTX 가로 HWP는 PDF와 실제 인쇄 panel에서 `1123 × 794 pt` 1쪽을 회전 없이 유지했다. 대표 HWP/HWPX는 `794 × 1123 pt` 9쪽, searchable text와 nonblank raster를 유지했다. 내부 메뉴와 toolbar 결과, PR #458 기준선의 text/raster가 일치했다.

실제 인쇄 panel에서 KTX는 가로, HWPX는 세로 9쪽으로 표시됐으며 작업지시자가 방향 보완을 확인했다. 저장소에 실제 가로·세로 혼합 fixture가 없어 mixed document는 synthetic exact geometry, job orientation 미강제와 PDFKit auto-rotate test로 검증했다.

PDF 저장과 인쇄는 source document를 쓰지 않는다. smoke 전후 repository 원본과 복사본의 크기, SHA-256과 수정 시각은 동일했다.

## 검증 결과

### Issue 완료 조건

| 완료 조건 | 결과 | 근거 |
|---|---|---|
| 합성 SVG script와 event handler 미실행 | OK | content JavaScript 비활성 WebKit sentinel과 nested data SVG script 테스트 통과 |
| 외부 HTTP/HTTPS resource 요청 없음 | OK | CSP 없는 양성 대조 연결 성공 후 hardened renderer loopback 요청 0건 |
| HostApp page metrics 정상 동작 | OK | `WKContentWorld.defaultClient`에서 width/height/viewBox/bounding rect 측정과 PDF 생성 통과 |
| PDF·인쇄 page count, geometry와 searchable text 유지 | OK | synthetic portrait/landscape/mixed 및 실제 KTX/HWP/HWPX 비교 통과 |
| HostAppTests와 HostApp Debug build 통과 | OK | 새 clean DerivedData에서 126 tests, 실패 0개와 Debug build 성공 |
| 보안 정책과 알려진 제한 architecture 반영 | OK | `page SVG trust boundary`에 WebView/CSP/navigation/실패·제한 계약 기록 |

### 최종 통합 검증

| 검증 | 결과 |
|---|---|
| `xcodegen generate` | 통과, 생성 project의 추가 tracked diff 없음 |
| HostAppTests (`build.noindex/task460/final-tests`) | `** TEST SUCCEEDED **`, 126개, 실패 0개 |
| HostApp Debug build (`build.noindex/task460/final-build`) | `** BUILD SUCCEEDED **` |
| built app bundled studio asset | `OK: rhwp-studio assets verified` |
| `./scripts/check-no-appkit.sh` | Shared/RhwpCoreBridge AppKit/UIKit 의존 없음 |
| core·bundled studio asset scope | `devel` 기준 변경 0건 |
| `git diff --check` | 통과 |

WebKit test process의 RunningBoard, pasteboard와 linkd 관련 sandbox 진단은 출력됐지만 renderer 통합 테스트와 전체 suite는 실패 없이 완료됐다.

## 잔여 위험과 후속 작업

- 검증은 현재 개발 호스트의 WebKit과 인쇄 panel에서 수행됐다. deployment target macOS 12 실제 장비의 UI·WebKit 동작은 별도 환경에서 확인해야 한다.
- `style-src 'unsafe-inline'`과 `img-src data:`는 현재 upstream SVG 충실도에 필요한 최소 예외다. 향후 data font나 다른 resource 계약을 추가하면 허용 범위를 넓히기 전에 별도 보안·PDF·인쇄 회귀 검증이 필요하다.
- renderer는 SVG 문자열을 범용 sanitizer로 재작성하지 않는다. 안전성은 content JavaScript 비활성, CSP, navigation deny와 전용 non-persistent WebView의 결합에 의존한다.
- bridge message와 native payload가 전체 page SVG 문자열을 보유하고 page별 30초 timeout 외에 전체 document deadline이 없다. 대용량 memory/time, progress와 사용자 취소는 이번 범위 밖이다.
- 실제 가로·세로 혼합 HWP/HWPX fixture는 없다. 현재는 synthetic exact geometry와 PDFKit 인쇄 정책으로 검증한다.
- PDF·인쇄 lifecycle의 중복 요청과 stale navigation callback 방어는 별도 [Issue #459](https://github.com/postmelee/alhangeul-macos/issues/459)에서 추적한다.

Issue #460 완료를 막는 잔여 결함은 확인되지 않았다. resource 계약 확장, 대용량 성능 또는 구형 macOS 실장 검증을 실제로 추진할 때는 각각 독립 범위로 등록한다.

## 최종 결론

Issue #460의 계획된 Stage 1~5를 완료했다. 문서 유래 page SVG는 PDF·인쇄 renderer에서 능동 콘텐츠로 실행되지 않고 외부 network·navigation capability를 갖지 않는다. HostApp이 소유한 metrics와 정상 page 표현에 필요한 최소 data image만 유지한다.

공격 fixture의 실제 WebKit 실행·요청 차단과 대표 HWP/HWPX/KTX의 geometry, text, raster, 인쇄 방향 및 원본 무손실을 함께 확인했다. main editor, 저장 exporter, Quick Look/Thumbnail, bundled upstream asset과 Rust core의 경계는 변경하지 않았다.

## 작업지시자 승인 요청

이 보고서 커밋 후 `publish/task460`을 `devel` 대상으로 게시한 Open PR의 리뷰와 merge를 요청한다. merge 전에는 Issue #460을 열린 상태로 유지하고, merge 확인 뒤 `pr-merge-cleanup` 절차로 이슈와 브랜치 부산물을 정리한다.
