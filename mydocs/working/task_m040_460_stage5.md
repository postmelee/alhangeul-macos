# Task #460 Stage 5 완료 보고서

## 단계 목적

Stage 2~4에서 구현·검증한 문서 유래 page SVG의 PDF·인쇄 보안 경계를 architecture 문서에 명시하고, Issue #460 전체 변경을 clean 빌드 환경에서 최종 검증한다. 코드, 테스트와 문서의 계약이 일치하는지 확인하고 최종 결과보고서 작성 및 PR 게시 단계로 넘길 수 있는 상태를 만든다.

## 산출물

- `mydocs/tech/project_architecture.md` (437줄)
  - upstream page SVG를 비신뢰 정적 렌더 입력으로 정의했다.
  - renderer 전용 non-persistent WebView, content JavaScript 비활성, default client content world의 app-owned metrics, CSP와 navigation deny-by-default 정책을 기록했다.
  - 정상 page 표현을 위한 inline style과 `data:` image만 예외로 두고 HTTP/HTTPS, blob, file, 외부 font와 custom scheme을 허용하지 않는 계약을 명시했다.
  - PDF 저장과 인쇄가 같은 hardened renderer를 사용하며 main editor, HWP/HWPX 저장, Quick Look/Thumbnail과 Rust core는 범위 밖임을 기록했다.
  - 현재의 memory/time 비용, deployment target WebKit 검증 한계와 향후 resource 계약 확장 조건을 남겼다.
- `mydocs/working/task_m040_460_stage5.md`
  - Stage 5 문서 변경, 최종 검증과 잔여 위험을 기록했다.
- `mydocs/orders/20260808.md`
  - #460 상태를 Stage 5 완료 및 최종 보고서·PR 승인 대기로 갱신했다.

## 구현 결과

### page SVG trust boundary 문서화

architecture의 HostApp page SVG PDF renderer 설명에 다음 방어선을 코드와 테스트가 보장하는 책임 단위로 정리했다.

| 방어선 | 책임 |
|---|---|
| WebView 격리 | main editor와 configuration, script, handler, scheme을 공유하지 않는 renderer 전용 WebView와 `.nonPersistent()` data store를 사용한다. |
| 문서 실행 차단 | content JavaScript와 자동 popup을 비활성화해 SVG script, event handler와 `javascript:` 실행을 차단한다. |
| metrics 격리 | page 크기 측정만 `WKContentWorld.defaultClient`에서 수행하고 실패 시 content JavaScript를 다시 켜지 않는다. |
| subresource 차단 | raw SVG보다 앞선 CSP가 외부 script, connect, frame, object, media, worker, font와 base/form 동작을 기본 거부한다. |
| navigation 차단 | page별 최초 main-frame `about:blank` 한 번 외에는 main/subframe, new-window와 모든 scheme 이동을 취소한다. |
| fail closed | invalid metrics, 단일 page가 아닌 PDF, 잘못된 media box, page count 불일치와 WebContent 종료를 render 실패로 반환한다. |

CSP는 subresource, navigation delegate는 frame/document 이동을 담당한다고 구분했다. navigation delegate가 모든 CSS·image·font 요청을 관측한다고 오해하거나 non-persistent store가 실행·network 차단을 대신한다고 해석하지 않도록 각 정책의 경계를 명시했다.

### 전체 범위 대조

`devel` 기준 production source 변경은 `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` 하나다. 테스트는 `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift`에 한정된다. Stage 5에서는 production code를 추가로 수정하지 않았다.

- PDF export controller와 print controller는 동일한 `RhwpStudioPagePDFRenderer`를 계속 사용한다.
- `Sources/RhwpCoreBridge`, main editor와 `Sources/HostApp/Resources/rhwp-studio`에는 변경이 없다.
- Quick Look/Thumbnail renderer, HWP/HWPX exporter와 source document write 경로에는 변경이 없다.
- `xcodegen generate` 뒤 생성된 Xcode project의 tracked 변경이 없다.

## 본문 변경 정도 / 본문 무손실 여부

- Stage 5의 본문 변경은 architecture 문서 24줄 추가·보정뿐이며 production source와 test fixture를 수정하지 않았다.
- Stage 4에서 확인한 KTX 가로 1쪽과 HWP/HWPX 세로 9쪽의 geometry, searchable text와 raster 결과를 그대로 유지한다.
- Task #460 전체 구현은 SVG 문자열을 sanitizer로 재작성하지 않고 실행·resource·navigation capability를 제한하므로 정상 SVG markup과 embedded data image를 보존한다.
- 실제 PDF 저장·인쇄 smoke 전후 원본 HWP/HWPX의 bytes, SHA-256과 수정 시각이 동일했던 Stage 4 결과에 영향을 주는 변경이 없다.

## 검증 결과

### 구현계획 Stage 5 검증

1. `xcodegen generate`: 통과
   - project를 재생성했고 의도하지 않은 tracked project 변경이 없다.
2. 전체 HostAppTests: 통과
   - `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task460/stage5-tests CODE_SIGNING_ALLOWED=NO test`
   - 126 tests, 0 failures, `** TEST SUCCEEDED **`
3. HostApp Debug 빌드: 통과
   - `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task460/stage5-build CODE_SIGNING_ALLOWED=NO build`
   - `** BUILD SUCCEEDED **`
4. built app bundled studio asset 검증: 통과
   - `scripts/verify-rhwp-studio-assets.sh build.noindex/task460/stage5-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
   - `OK: rhwp-studio assets verified`
5. 핵심 SVG 보안 회귀 tests 재실행: 통과
   - CSP 위치·정책, 최초 `about:blank` navigation만 허용, script/event handler 미실행, embedded data PNG 보존, nested data SVG 보존·script 미실행, 외부 resource/navigation 0건을 대상으로 했다.
   - 6 tests, 0 failures, `** TEST SUCCEEDED **`
6. 공유 Swift 코드 플랫폼 경계 검사: 통과
   - `./scripts/check-no-appkit.sh`
   - `OK: shared Swift code has no AppKit/UIKit dependencies`
7. `git diff --check`: 통과
8. `devel` 기준 변경 범위 대조: 통과
   - production source 변경은 `RhwpStudioPagePDFRenderer.swift` 하나다.
   - `Sources/RhwpCoreBridge`와 bundled `rhwp-studio` asset에는 변경이 없다.

WebKit test process의 RunningBoard, pasteboard와 linkd 관련 sandbox 진단은 출력됐지만 전체 126 tests와 핵심 6 tests는 실패 없이 완료됐다. 최초 sandbox 실행은 사용자 cache 쓰기 제한으로 SwiftPM package 해석에 실패했으며, 동일 명령을 허용된 Xcode cache 접근 조건에서 다시 실행해 정상 통과했다. 구현·테스트 실패로 판정할 항목은 없다.

## 잔여 위험

- 자동·수동 검증은 현재 개발 호스트의 WebKit과 인쇄 패널에서 수행됐다. deployment target macOS 12 실제 장비의 UI·WebKit 동작은 별도 환경에서 확인해야 한다.
- `style-src 'unsafe-inline'`과 `img-src data:`는 현재 upstream SVG 표현 충실도를 위한 최소 예외다. 향후 data font나 다른 resource 계약이 필요하면 허용 범위를 넓히기 전에 별도 변경과 보안·회귀 검증이 필요하다.
- renderer는 raw SVG를 범용 sanitizer로 재작성하지 않는다. 안전성은 content JavaScript 비활성, CSP, navigation deny와 격리된 non-persistent WebView의 결합에 의존하므로 정책 중 하나를 변경할 때 통합 테스트를 함께 갱신해야 한다.
- bridge message와 native payload는 전체 page SVG 문자열을 보유하며 page별 30초 timeout 외에 전체 문서 deadline이 없다. 대용량·다중 page 문서의 memory/time 비용은 이번 보안 hardening 범위에 포함하지 않았다.
- 저장소에 실제 가로·세로 혼합 HWP/HWPX sample이 없어 혼합 문서 인쇄는 synthetic exact geometry, orientation 미강제와 PDFKit auto-rotate test로 검증했다.

현재 잔여 위험 중 Issue #460 완료를 막거나 즉시 후속 이슈 등록이 필요한 새 결함은 확인되지 않았다. resource 계약 확장, 대용량 성능 또는 구형 macOS 실장 검증을 실제로 추진할 때 각각 별도 범위로 등록하는 것이 적절하다.

## 다음 단계 영향

Stage 1~5 구현과 검증이 모두 완료됐다. 다음 단계에서는 명시 호출형 `task-final-report` 절차로 전체 결과보고서를 작성하고 오늘할일 완료 처리, 최종 커밋, `publish/task460` push와 `devel` 대상 PR 생성을 수행할 수 있다.

Stage 5에서는 최종 결과보고서, 원격 push와 PR 생성을 수행하지 않는다.

## 승인 요청

Stage 5 SVG trust boundary 문서화와 최종 검증 결과를 검토하고 Task #460 최종 결과보고서 작성 및 PR 게시 진행 승인을 요청한다.
