# Task #484 최종 결과보고서

## 작업 요약

- 이슈: [#484 HostApp PDF 내보내기의 한글 글꼴 ToUnicode 누락과 텍스트 선택 회귀 수정](https://github.com/postmelee/alhangeul-macos/issues/484)
- 마일스톤: v0.1 (`M010`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task484` → 게시 브랜치 `publish/task484`
- 기준 `origin/devel`: `18cdb8b7458ea8adef0ec88057ae7742af110dd7`
- 단계 수: 4

v0.1.10에서 `3-11월_실전_통합_2022.hwp`를 PDF로 내보냈을 때 문항 텍스트 선택·검색·복사가 불안정한 원인은 페이지 전체 bitmap화나 수식 자체가 아니었다. page SVG의 한글이 WebKit/Quartz의 system fallback인 `AppleSDGothicNeo` subset으로 들어가면서 `/ToUnicode` CMap이 생성되지 않은 글꼴 resource가 다수 생긴 것이 직접 원인이었다.

PDF/인쇄 공용 renderer에 앱이 이미 보유한 Noto Sans/Serif KR WOFF2 네 종을 제공하는 좁은 custom scheme을 추가하고 Hangul/Jamo와 Enclosed/Circled Hangul 범위에 적용했다. font readiness와 실제 family/weight load를 확인한 뒤 PDF를 생성한다. known/generic family는 Sans/Serif 의미를 보존하고, family가 없거나 미등록·monospace인 한글 text는 Noto Sans KR로 보정한다. 선택된 owned face가 실제로 load되지 않으면 page 단위 오류로 종료한다. 기존의 content script·외부 resource·navigation 차단과 page geometry는 유지했다.

공개 21쪽 HWP와 대표 9쪽 HWPX를 실제 앱에서 내보내고 일반 인쇄·취소까지 검증했다. 한글을 담당하는 새 Noto subset은 모두 `uni=yes`였고 macOS 미리보기에서 실제 문장을 드래그 선택·복사·검색했다. 동일 조건 v0.1.10과 비교해 줄바꿈, 수식·표·도형 배치와 페이지 크기를 유지했다.

## Stage와 커밋

| Stage | 커밋 | 결과 |
|-------|------|------|
| 수행·구현 계획 | `61dd878`, `d2c16f8` | 사용자 PDF 분석 범위, font 후보, 보안 경계, 실문서 smoke와 4단계 검증 계약 확정 |
| Stage 1 | `70ab700` | v0.1.10 증상 재현, `/ToUnicode` 누락 원인과 exact Noto custom scheme·readiness 수정 계약 확정 |
| Stage 2 | `0457756` | PDF 전용 font provider, Hangul/Jamo mapping, readiness와 CGPDF/PDFKit·보안 자동 회귀 구현 |
| Stage 3 | `cf64b13` | 공개 21쪽 HWP·9쪽 HWPX의 PDF 선택·렌더·인쇄 통합 검증과 수식 generic stack 보정 |
| Stage 4 | `6d8de73` | font source·Unicode mapping·보안 경계·잔여 제한 문서화와 clean 최종 검증 |
| PR #485 리뷰 보정 | 본 보고서를 포함한 보정 커밋 | 외부 이미지 placeholder를 포함한 미분류 한글 fallback, Unicode 범위 단일화, 번들 font 자산 검증 보강 |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioPDFFontProvider.swift` | Noto Sans/Serif KR 네 종 exact allowlist, bundle/directory provider, WOFF2 signature·크기·regular file·symlink 검증, PDF 전용 scheme handler와 Hangul Unicode 범위의 CSS/JavaScript 단일 진실 원천 추가 |
| `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` | PDF font scheme 등록, 한글 family·weight 수집, `document.fonts.ready/load` 검증, known/generic Sans·Serif 보정, 미분류 한글의 Noto Sans fallback과 typed font error 추가 |
| `Sources/HostApp/Services/RhwpStudioPDFExportController.swift` | 사용자 저장·인쇄의 공용 renderer 계약을 유지하면서 deterministic test renderer 주입 경계 보강 |
| `Tests/HostAppTests/CGPDFFontResourceInspector.swift` | page와 nested Form XObject의 font resource·`/ToUnicode` 검사, cycle·depth 제한 추가 |
| `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` | 한글·수식 selection/search/ToUnicode, exact font route와 production bundle provider, readiness failure, 실제 외부 이미지 placeholder·미분류·monospace·Enclosed/Circled Hangul, CSP·외부 resource·navigation과 기존 geometry/raster 회귀 검증 |
| `scripts/verify-rhwp-studio-assets.sh` | source와 빌드 앱의 exact font 4종 존재·regular file·non-symlink·WOFF2 signature 검증 추가 |
| `Tests/HostAppTests/RhwpStudioPDFExportControllerTests.swift` | 2쪽 한글 searchable PDF와 portrait/landscape export controller 회귀 보강 |
| `project.yml`, `Alhangeul.xcodeproj/project.pbxproj` | 신규 production font provider와 test helper를 HostAppTests 구성에 포함하고 XcodeGen으로 project 재생성 |
| `README.md` | 다음 패치 릴리스 후보의 한글 PDF mapping 개선과 positioned SVG·Hanja·수식·이미지/OCR 제한 안내 |
| `mydocs/tech/project_architecture.md` | page SVG부터 PDFKit merge까지의 font·보안·검증 ownership과 Stage 3 측정치 문서화 |
| `mydocs/plans/task_m010_484.md`, `task_m010_484_impl.md` | 조사·구현·실문서·문서화 4단계 계획과 수용 기준 기록 |
| `mydocs/working/task_m010_484_stage1.md` ~ `task_m010_484_stage4.md` | 원인 실험, 구현, 실제 HWP/HWPX smoke와 최종 문서화 결과 기록 |
| `mydocs/orders/20260824.md` | Task #484 진행과 완료 상태 기록 |

신규 font binary는 추가하지 않았다. 기존 bundle에 provenance·license와 함께 포함된 `NotoSansKR-Regular/Bold.woff2`, `NotoSerifKR-Regular/Bold.woff2`만 재사용한다. `Sources/RhwpCoreBridge`, bundled `rhwp-studio` minified asset, `rhwp-core.lock`, Quick Look/Thumbnail 제품 source, HWP/HWPX 저장 exporter는 변경하지 않았다.

## 변경 전·후 정량 비교

### 실제 21쪽 HWP PDF

| 항목 | v0.1.10 사용자 PDF | 수정 후 PDF |
|------|---------------------|-------------|
| page count | 21 | 21 |
| media box·rotation | 794×1123 pt, rotation 0 | 794×1123 pt, rotation 0 |
| 파일 크기 | 7,570,926 bytes | 7,540,583 bytes |
| font resource | 184 | 228 |
| `uni=yes` | 79 | 143 |
| `uni=no` | 105 | 85 |
| 한글 Noto subset / `uni=yes` | 0 / 0 | 64 / 64 |
| AppleSDGothicNeo subset / `uni=yes` | 63 / 0 | 43 / 0 |
| 전체 page PDFKit string·rectangle selection | text object는 있으나 mapping 불안정 | 21/21 page 문자열 길이 일치 |
| macOS 미리보기 실제 선택 | 문항 text 선택 불안정 | `모든 항이 양수이고` 선택·복사·검색 성공 |

보관된 v0.1.10 앱을 현재와 같은 대체 글꼴 상태로 다시 실행한 비교 PDF는 7,574,379 bytes였다. 새 PDF는 이 동일 조건 기준선보다 33,796 bytes 작다. 21쪽 raster의 콘텐츠·줄바꿈·수식·표·도형 배치는 일치했으며 Noto glyph 외형에 따른 픽셀 차이는 평균 2.1056%, 최대 4.4077%(15쪽)였다. page content 이동, 잘림, 겹침과 baseline 붕괴는 발견되지 않았다.

### 대표 HWPX와 자동 검증

| 항목 | 결과 |
|------|------|
| 대표 HWPX PDF | 9쪽, 794×1123 pt, 968,865 bytes |
| HWPX font resource | 63개, `uni=yes` 45개, `uni=no` 18개 |
| HWPX 한글 Noto subset | 32개, 모두 `uni=yes` |
| HWP PDFKit 검색 | `문1` 22건, `함수` 48건, `값은` 37건, `f ( x )` 50건 |
| PDF renderer 표적 테스트 | 19개, 실패 0개 |
| HostAppTests 전체 | 151개, 실패 0개 |
| 최종 Task diff | PR 리뷰 보정 포함 19개 파일, 2,493줄 추가, 60줄 삭제 |

## 구현 결과

### PDF 전용 font source와 최소 허용 경계

`RhwpStudioPDFFontResource`는 허가된 WOFF2 네 파일의 이름, MIME, weight와 family를 고정한다. `RhwpStudioPDFFontSchemeHandler`는 `alhangeul-pdf-font://bundle/<filename>`의 단일 exact route만 제공한다.

- query, fragment, credential, port와 중첩 path 거부
- bundle font directory 밖 symlink와 일반 파일이 아닌 항목 거부
- 빈 파일, 최대 크기 초과와 WOFF2 signature가 아닌 data 거부
- CSP `font-src`에는 전용 scheme만 추가하고 HTTP/HTTPS, file, blob과 임의 custom scheme은 계속 차단
- main editor의 `alhangeul-studio://app` handler나 resource 표면을 공유하지 않음

원본 proprietary font binary는 PDF에 새로 포함하지 않는다. known 한글 alias와 generic serif/sans stack의 Hangul/Jamo·Enclosed/Circled Hangul Unicode 범위만 Noto Sans/Serif KR로 연결하고 ASCII, Hanja, 수식 glyph와 기존 family 순서는 유지한다. family가 없거나 분류할 수 없는 한글 text는 Noto Sans KR로 보정한다.

### font readiness와 실패 계약

page가 load되면 HostApp preparation script가 `WKContentWorld.defaultClient`에서 다음 순서를 수행한다.

1. `document.fonts.ready` 대기
2. Hangul이 있는 SVG text의 computed family와 weight를 수집하고 known/generic family 또는 Noto Sans fallback 결정
3. 결정된 허가 face별 `document.fonts.load` 호출
4. readiness와 family/weight별 loaded face 재확인
5. SVG page metrics 확정 뒤 `WKWebView.createPDF` 호출

미분류 family 자체는 Noto Sans KR로 보정하지만, 결정된 owned face를 실제로 load하지 못하면 page 번호와 원인이 있는 `fontPreparationFailed`로 종료한다. content JavaScript를 다시 켜거나 system fallback 성공으로 간주하는 우회 경로는 없다. font 준비도 기존 page별 30초 watchdog과 exactly-once completion lifecycle 안에 포함된다.

CSS `unicode-range`와 JavaScript의 Hangul 판별식은 production Swift의 동일 범위 목록에서 생성한다. 이 범위에는 `U+3200–321E` Enclosed Hangul과 `U+3260–327F` Circled Hangul도 포함된다. bundled Studio WASM이 외부 이미지를 표시할 때 만드는 family 없는 `[외부: sample.png]` text를 그대로 사용한 WebKit/PDFKit 회귀로 fallback과 선택·검색을 검증한다.

### Unicode mapping 회귀 검증

화면에 한글이 보이거나 `PDFPage.string`이 우연히 추론되는 것만으로 완료 처리하지 않는다.

- CGPDF resource inspector가 page와 nested Form XObject의 Noto subset `/ToUnicode`를 확인
- PDFKit `PDFPage.string`, media box rectangle selection과 `findString`을 함께 확인
- `pdffonts`의 `uni` 열과 `pdftotext -layout`으로 독립 교차 확인
- 실제 macOS 미리보기에서 drag selection, copy와 search 확인
- malformed/cyclic PDF resource가 inspector를 무한 순회하지 않도록 visited object와 depth 제한 적용

### PDF 저장·인쇄와 제품 경계

PDF 저장과 일반 인쇄는 계속 current editor의 page SVG와 같은 `RhwpStudioPagePDFRenderer`를 사용한다. PDF export controller는 destination atomic write를, print controller는 PDFKit/AppKit print operation을 소유한다. Quick Look/Thumbnail은 Rust bridge와 CoreGraphics/CoreText bitmap renderer를 사용하는 기존 경계를 유지한다.

## 실제 HWP/HWPX 통합 검증

### 공개 21쪽 HWP

- 내부 메뉴와 toolbar 결과 모두 21쪽, 794×1123 pt, rotation 0
- 두 결과의 `pdftotext -layout`가 byte 단위로 같고 1·10·21쪽 144 dpi raster hash 일치
- 전 21쪽이 nonblank이며 PDFKit page string과 전체 media box selection 길이 일치
- Noto subset 64개 모두 `uni=yes`
- Preview에서 `모든 항이 양수이고`를 직접 선택·복사하고 검색 결과 1쪽 확인
- 인쇄 panel에서 `21페이지 모두`, portrait preview와 실제 출력 없는 취소 확인
- 저장 panel 취소 시 partial destination 없음

### 대표 9쪽 HWPX

- 9쪽 모두 794×1123 pt, rotation 0과 nonblank 유지
- Noto subset 32개 모두 `uni=yes`
- 전 9쪽의 PDFKit page string과 rectangle selection 길이 일치
- `pdftotext -layout`에서 한글 본문 보존

smoke 전후 HWP/HWPX 원본의 SHA-256과 수정 시각은 동일했다. 앱은 문서를 편집·저장하지 않고 PDF 내보내기, 인쇄 preview와 취소만 수행했다.

## 수용 기준별 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 한글 문항 본문 font에 유효한 Unicode mapping 포함 | OK | HWP Noto 64/64, HWPX 32/32 `/ToUnicode`와 `uni=yes` |
| PDFKit 영역 selection과 검색에 한글·수식 포함 | OK | 전체 page selection, `문1`·`함수`·`값은`·`f ( x )` 검색 |
| 독립 text 검사에서 대표 한글 보존 | OK | `pdftotext -layout`와 Preview copy/search 통과 |
| 21쪽과 794×1123 pt geometry 유지 | OK | menu·toolbar 결과의 전 page media box·rotation 확인 |
| 허용되지 않은 metric·줄바꿈·수식 배치 변화 없음 | OK | 동일 조건 v0.1.10 전 page raster 및 대표 page 육안 대조 |
| script·외부 resource·navigation 차단 유지 | OK | loopback 0건, CSP·navigation·script sentinel 자동 테스트 |
| 실제 한글 회귀를 deterministic test로 추적 | OK | Korean/math fixture, CGPDF inspector와 PDFKit selection/search test |
| 원본·core·Studio asset·extension 경계 유지 | OK | source hash, asset verifier와 변경 파일 경계 검사 |

## 최종 통합 검증

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과. project 재생성 뒤 추가 diff 없음 |
| HostAppTests | `** TEST SUCCEEDED **`, 151개, 실패 0개 |
| `RhwpStudioPagePDFRendererTests` | 19개, 실패 0개 |
| HostApp Debug build | `** BUILD SUCCEEDED **` |
| source·최종 앱 bundled Studio asset | exact WOFF2 font 4종을 포함해 verifier 통과 |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code AppKit/UIKit 직접 의존 없음 |
| `git diff --check` | 통과 |
| 최신 `origin/devel...HEAD` | `0 8`, PR 리뷰 보정 커밋 반영 뒤 작업 브랜치가 뒤처지지 않고 8개 commit 앞섬 |

WebKit 테스트 중 RunningBoard, pasteboard와 audio registrar 관련 sandbox 진단이 출력되지만 renderer 테스트와 전체 suite는 정상 완료됐다. 최초 clean test의 Sparkle dependency resolve는 sandbox DNS 제한으로 중단됐으나 허용된 host 환경에서 동일 명령을 재실행해 package resolve부터 151개 테스트까지 통과했다.

## 잔여 위험과 후속 작업

- positioned SVG text의 논리 읽기 순서와 drag selection 경계는 viewer마다 다를 수 있다.
- Hangul/Jamo의 Noto subset은 `uni=yes`지만 Hanja, 일부 수식·기호와 ASCII를 담당하는 Apple/STIX system subset에는 `uni=no`가 남을 수 있다. 모든 glyph의 완전한 선택은 이번 범위가 아니다.
- 이미지·스캔과 path/도형으로 그린 문자는 text layer가 아니므로 선택되지 않는다. OCR이나 숨은 text overlay는 제공하지 않는다.
- page별 font subset 때문에 장문 문서의 resource 수, 생성 시간과 memory 비용이 증가할 수 있다. 이번 21쪽 결과에서는 동일 조건 v0.1.10보다 파일 크기가 증가하지 않았다.
- upstream page SVG의 새 한글 family는 Noto Sans KR로 보정되므로 export 전체를 중단하지 않는다. 다만 원래 serif 의도처럼 분류할 근거가 없는 family 의미는 보존할 수 없으므로 bundled Studio 동기화에서 alias drift를 함께 확인해야 한다.
- 실문서 HWP/HWPX smoke는 수동 회귀이며 CI는 합성 Korean/math와 보안 경계 fixture로 deterministic 회귀를 담당한다.
- PR merge 확인 뒤 Issue #484 close, `publish/task484`/`local/task484`와 필요 없는 worktree를 정리한다.

## 최종 결론

Issue #484의 계획된 Stage 1~4를 완료했다. v0.1.10 PDF의 선택 불안정은 수식이나 bitmap 때문이 아니라 한글 system fallback subset의 `/ToUnicode` 누락이 원인이며, PDF 전용 exact Noto font source와 readiness 검증으로 한글 text mapping을 보강했다.

공개 21쪽 HWP와 대표 9쪽 HWPX에서 page geometry, 수식·표·도형 배치, nonblank 출력과 원본 불변을 유지하면서 한글 Noto subset 전체의 Unicode mapping과 Preview 실제 선택·복사·검색을 확인했다. 기존 PDF/인쇄 공용 renderer, WebKit 격리와 Quick Look/Thumbnail 제품 경계도 유지했다.

## 작업지시자 승인 요청

Task #484의 4개 Stage, 최종 수용 검증과 결과보고서 작성을 완료했다. `publish/task484`를 `devel` 대상으로 게시한 Open PR의 리뷰와 merge 승인을 요청한다. merge 전에는 Issue #484를 열린 상태로 유지하고, merge 확인 뒤 정리 절차를 수행한다.
