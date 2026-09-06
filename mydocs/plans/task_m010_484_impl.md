# Task M010 #484 구현계획서

## 1. 개요

- 이슈: [#484 HostApp PDF 내보내기의 한글 글꼴 ToUnicode 누락과 텍스트 선택 회귀 수정](https://github.com/postmelee/alhangeul-macos/issues/484)
- 마일스톤: `M010` (`v0.1`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task484`
- 게시 브랜치: `publish/task484`
- 수행계획서: `mydocs/plans/task_m010_484.md`
- 단계 수: 4

이 문서는 v0.1.10의 page SVG → `WKWebView.createPDF` 경로에서 일부 한글 글꼴 subset에 `ToUnicode` CMap이 생성되지 않는 조건을 분리 재현하고, 시각 정합성과 격리 보안 경계를 유지하는 최소 수정과 검증 절차를 확정한다. 구현계획 승인 전에는 Stage 1을 시작하지 않으며, 각 Stage 종료 뒤 `task-stage-report` 절차로 실제 결과와 다음 단계 진입을 다시 승인받는다.

## 2. 구현 전 확인 결과

| 항목 | 확인 결과 | 구현 영향 |
|------|-----------|-----------|
| 기준선 | `devel` 기준 commit은 `18cdb8b7458ea8adef0ec88057ae7742af110dd7`, v0.1.10 tag는 `cd74a7ec8f3bc5bcc5862931b1eda9bbfeecc1b3`이다. | Stage 1에서 두 기준의 renderer 계약과 사용자 산출물을 구분해 기록한다. |
| 현재 PDF 경로 | `RhwpStudioPagePDFRenderer`가 page SVG를 `loadHTMLString(..., baseURL: nil)`로 page별 로드하고 `WKWebView.createPDF` 뒤 PDFKit으로 병합한다. PDF 저장과 일반 인쇄가 이 renderer를 공유한다. | 수정은 공용 renderer 경계에서 검증하며 export controller에 별도 우회 경로를 만들지 않는다. |
| 현재 격리 정책 | 비영구 WebView, content JavaScript 비활성, initial `about:blank` 외 navigation 차단과 `font-src 'none'` CSP를 사용한다. | font 허용 변경은 외부 resource·navigation 차단 회귀와 한 단계에서 검증해야 한다. |
| font readiness | navigation 완료 뒤 page metrics만 읽고 즉시 `createPDF`를 호출하며 `document.fonts.ready` 또는 개별 font 상태를 기다리지 않는다. | font source와 readiness를 독립 변수로 측정하고, 채택 시 timeout·실패 계약을 정의한다. |
| 번들 글꼴 | `rhwp-studio/fonts`에 Noto Sans/Serif KR, Pretendard, Latin Modern Math 등 허가된 WOFF2가 이미 앱 resource로 포함된다. proprietary 한컴/HY/Microsoft 글꼴은 포함하지 않는 정책이다. | 새 binary font를 추가하거나 라이선스 불명 글꼴을 포함하지 않고 기존 허가 font 재사용을 우선한다. |
| 기존 resource scheme | `alhangeul-studio://app/` scheme handler는 bundle의 전체 Studio resource를 제공하고 `woff2` MIME도 지원한다. | PDF renderer에서 그대로 재사용하면 허용 표면이 넓어질 수 있으므로, 필요 시 PDF 전용 exact allowlist route를 우선한다. |
| 사용자 PDF | 21 page, `794 × 1123 pt`, 7,570,926 bytes이며 184개 font subset 중 105개가 `uni=no`이다. 한글 본문의 `AppleSDGothicNeo` 계열 subset도 `uni=no`다. | page string 유무가 아니라 실제 font dictionary와 영역 selection을 완료 기준으로 삼는다. |
| 수식 여부 | page 1 `문1` 영역에서 한글 본문과 분수·근호 수식이 함께 PDFKit selection으로 반환된다. | 문항 전체가 수식 이미지라서 선택되지 않는 문제로 보지 않고, 본문 mapping과 수식 mapping을 분리 검증한다. |
| 기존 테스트 | 영문 합성 SVG의 `PDFPage.string`, page geometry, script/resource 차단을 확인하지만 한글 font의 `ToUnicode`는 확인하지 않는다. | 최소 한글·수식 합성 fixture와 CGPDF font resource 검사를 추가한다. |

## 3. 공통 설계·안전 원칙

### 3.1 Unicode text layer와 시각 결과를 함께 보존

- page SVG의 Unicode `<text>`를 진실 원천으로 유지한다.
- PDF 전체 bitmap화, 수식 raster 치환과 OCR text overlay는 이번 타스크의 해결책으로 사용하지 않는다.
- `PDFPage.string` 또는 `pdftotext` 결과만으로 완료 처리하지 않는다.
- 대표 한글을 그리는 PDF font resource의 `ToUnicode` 존재, PDFKit search, rectangle selection과 독립 도구 추출을 함께 확인한다.
- 원본 글꼴을 번들할 수 없는 문서는 허가된 fallback을 사용하되, 글자 폭·baseline·줄바꿈·표·수식 배치 회귀를 raster 비교로 차단한다.
- 이미지·스캔·도형 내부의 글자는 text object가 아니므로 선택 가능 보장 대상에서 제외한다.

### 3.2 PDF 전용 font source 최소 허용

Stage 1은 다음 후보를 같은 fixture와 환경에서 비교한다.

| 후보 | font source | readiness | 보안·성능 검토 |
|------|-------------|-----------|----------------|
| A | 현재 system fallback, `font-src 'none'` | navigation 완료만 | 현재 결함 기준선 |
| B | 기존 허가 WOFF2를 `data:` URL로 wrapper에 주입 | 대기 없음/있음 비교 | HTML·메모리 중복, CSP `data:` 범위, page별 decode 비용 |
| C | PDF 전용 custom scheme의 exact allowlist WOFF2 | 대기 없음/있음 비교 | scheme·host·path·MIME·파일 크기 제한, cache와 요청 실패 |
| D | 기존 `alhangeul-studio` scheme 재사용 | 대기 있음 | 전체 Studio resource 노출 범위가 최소권한 원칙을 통과하는지 비교 |

- `http`, `https`, `file`, 임의 `blob`, 외부 custom scheme과 navigation은 계속 거부한다.
- 후보 D가 기능상 동작해도 PDF에 필요하지 않은 JS/WASM/HTML까지 접근 가능하면 채택하지 않는다.
- custom scheme을 채택하면 허용 host와 font 파일명을 코드에 고정하고, 경로 정규화·상위 경로 이동·확장자 위장·과대 resource를 거부한다.
- data font를 채택하면 app bundle에서 읽은 허가 font만 base64로 만들고 SVG가 제공한 data font나 임의 URL은 허용하지 않는다.
- `document.fonts.ready`는 app-owned `evaluateJavaScript(..., in: .defaultClient)` 경로로 확인한다. content JavaScript를 활성화하지 않는다.

### 3.3 font 선택과 metric 변경 제한

- Stage 1에서 page SVG의 선언 font-family와 WebKit resolved font를 기록한 뒤 최소 fallback mapping을 확정한다.
- 기본 비교 font는 한글 본문용 `NotoSansKR-Regular/Bold`와 serif가 실제 필요한 경우의 `NotoSerifKR-Regular/Bold`다. Pretendard와 `LatinModernMath-Regular`는 실제 SVG family·glyph coverage가 요구할 때만 후보에 포함한다.
- 모든 번들 font를 일괄 로드하지 않는다. 대표 SVG에 필요한 family/style/weight와 안정적인 기본 fallback만 준비한다.
- 원문 family 이름을 허가 font alias로 매핑할 때 proprietary font 이름과 대체 family 관계가 기존 `FONTS.md` 정책과 일치해야 한다.
- font 변경으로 대표 page의 줄바꿈, page overflow, 표 높이, 수식 baseline이 달라지면 mapping 개선만으로 채택하지 않는다.

### 3.4 PDF font 검증 계약

자동 테스트 helper는 CGPDF page resource의 `/Font` dictionary와 필요 시 nested Form XObject resource를 순회해 다음 정보를 수집한다.

- resource name, `/Subtype`, `/BaseFont`
- `/ToUnicode` stream 존재 여부
- page별 전체 font 수와 mapping 누락 수

합성 fixture는 한글 본문 font를 제한해 해당 text font가 다른 font의 성공에 가려지지 않게 한다. 실문서 검증은 `pdffonts`의 `uni` 열, PDFKit rectangle selection과 `pdftotext -layout`을 함께 사용한다. 테스트 helper가 malformed/cyclic resource를 만나도 무한 순회하지 않도록 visited object와 depth 제한을 둔다.

### 3.5 기존 renderer 계약 유지

- page별 오류 격리, 30초 timeout, exactly-once completion과 최종 page count 검사를 유지한다.
- font 준비를 기존 page timeout 안에 포함하고, 준비 실패·timeout은 어느 page에서 실패했는지 식별 가능한 typed error로 반환한다.
- portrait, landscape와 mixed page의 media box를 유지한다.
- PDF 저장과 일반 인쇄는 계속 같은 renderer 결과를 사용한다.
- page별 PDF 병합 구조와 font subset deduplication은 `ToUnicode` 수정에 필수라는 근거가 없으면 변경하지 않는다.
- production runtime에 Poppler나 별도 CLI 의존을 추가하지 않는다.

## 4. Stage 1 — font mapping 재현과 수정 계약 확정

### 4.1 목적

exact `devel`, v0.1.10과 사용자 산출물에서 page SVG 선언 font, WebKit resolved font와 PDF font resource의 관계를 재현한다. production source를 바꾸기 전에 후보 A~D를 최소 harness에서 비교해 Stage 2의 font source, readiness, CSP와 시각 허용 기준을 확정한다.

### 4.2 작업 범위

1. 기준 commit과 사용자 제공 HWP/PDF hash를 다시 확인한다.
   - HWP SHA-256: `bc8bccbb954c337d813d1af96f4e3047242124c2f2939163e282634eb721accd`
   - PDF SHA-256: `0b5d64c4611555578a70f9b78540775f43f81a2886bda4e91d12db54154acdaf`
2. 사용자 PDF와 비교용 Hancom PDF에서 page count, geometry, PDF producer, font subset, `uni=yes/no`, byte size와 대표 text 추출을 표로 고정한다.
3. 공개 `rhwp` sample의 읽기 전용 복사본을 `build.noindex/task484-stage1/`에 준비하고, Debug app의 `getPageSvg` 결과 또는 동일 public bridge 경로에서 대표 page SVG를 수집한다.
4. 대표 SVG에서 다음을 기록한다.
   - text node와 한글·수식 Unicode 문자열
   - `font-family`, weight, style과 embedded `@font-face`/font URL 유무
   - WebKit computed style과 `document.fonts.check` 결과
   - 생성 PDF의 `/BaseFont`, `/Subtype`, `/ToUnicode`
5. 합성 fixture를 준비한다.
   - 한글: `문1 함수의 값은 다음과 같다`
   - 영문·숫자: `ABC 123`
   - 수식: 실제 page SVG와 같은 text 기반 분수·근호·기호 조합
   - portrait/landscape geometry와 data PNG 보존 fixture
6. 후보 A~D와 readiness 대기 유무를 같은 macOS/WebKit process에서 반복 변환한다.
7. 각 후보의 font load 성공/실패, PDF mapping, selection, raster, 생성 시간, peak HTML/font payload와 PDF byte size를 비교한다.
8. 외부 loopback font/image 요청, navigation, script/event handler가 후보별로 계속 0건인지 확인한다.
9. Stage 2 구현안을 한 가지로 축소하고 다음 계약을 확정한다.
   - font source와 exact allowlist
   - family/style/weight mapping
   - readiness script와 timeout/error
   - CSP 문자열과 navigation/resource policy
   - CGPDF test helper의 통과 기준

### 4.3 예상 산출물

- `mydocs/working/task_m010_484_stage1.md`
- `mydocs/orders/20260824.md` 상태 갱신

Stage 1의 harness, 추출 SVG, font/PDF/raster와 로그는 `build.noindex/task484-stage1/` 아래에만 두고 커밋하지 않는다. 사용자 Desktop PDF와 sibling repository 원본은 읽기 기준으로만 사용하며 수정하거나 저장소에 복제하지 않는다.

### 4.4 검증

```bash
shasum -a 256 <source.hwp> <app.pdf> <reference.pdf>
pdfinfo <app.pdf>
pdffonts <app.pdf>
pdftotext -layout <app.pdf> <app.txt>
pdftoppm -png -r 144 <app.pdf> build.noindex/task484-stage1/app-page
scripts/verify-rhwp-studio-assets.sh
git diff --check
```

PDF raster는 같은 해상도와 color space로 생성해 page geometry, nonblank 상태와 대표 page의 글자 폭·baseline·줄바꿈·수식·표 배치를 비교한다. 실험용 외부 CLI는 판단 자료에만 사용하고 production code에는 포함하지 않는다.

### 4.5 완료 기준

- system fallback, font source와 readiness 중 `ToUnicode` 누락을 재현하는 최소 조건이 확인된다.
- 한글 본문과 수식의 mapping 성공·실패를 font resource 단위로 설명할 수 있다.
- 유효한 `ToUnicode`, PDFKit rectangle selection, `pdftotext`와 시각 정합성을 함께 통과하는 후보가 하나 이상 있다.
- 채택 후보가 외부 network/file/resource와 navigation 차단을 유지한다.
- Stage 2의 변경 파일, font allowlist, error와 테스트 계약이 확정된다.

후보 A~D가 모두 완료 기준을 충족하지 못하면 Stage 2를 시작하지 않는다. 제한된 Unicode text-run overlay나 PDF post-processing 대안의 정확도·보안·범위를 별도로 보고하고 구현계획 보정 승인을 요청한다.

### 4.6 커밋

`Task #484 Stage 1: PDF font mapping 원인과 수정 계약 확정`

## 5. Stage 2 — 격리 font 준비와 한글 PDF 회귀 구현

### 5.1 목적

Stage 1에서 승인된 최소 font source와 readiness 계약을 `RhwpStudioPagePDFRenderer`에 구현한다. 한글 본문과 text 기반 수식의 Unicode mapping을 자동 검증하면서 기존 script/resource/navigation 차단과 page geometry를 유지한다.

### 5.2 예상 변경 파일

- `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift`
- 필요 시 `Sources/HostApp/Services/RhwpStudioPDFFontProvider.swift`
- 필요 시 PDF 전용 scheme handler 파일
- 필요 시 `Sources/HostApp/Services/RhwpStudioResourceLocator.swift`
- `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift`
- `Tests/HostAppTests/RhwpStudioPDFExportControllerTests.swift`
- 필요 시 CGPDF font resource 검사용 HostAppTests helper
- 필요 시 `project.yml`
- `mydocs/working/task_m010_484_stage2.md`
- `mydocs/orders/20260824.md`

새 production/helper 파일이 필요할 때만 `project.yml`을 수정하고 `xcodegen generate`로 project를 재생성한다. `Alhangeul.xcodeproj`를 직접 편집하지 않는다. 기존 번들 font를 사용하며 새 binary asset은 추가하지 않는다.

### 5.3 구현 항목

1. Stage 1에서 채택한 허가 font만 bundle에서 resolve하는 typed provider를 둔다.
2. resource가 없거나 MIME·size·path 검증에 실패하면 system fallback으로 조용히 진행하지 않고 해당 page render를 실패시킨다.
3. wrapper에 승인된 `@font-face`와 fallback mapping을 SVG보다 먼저 배치한다.
4. CSP의 `font-src`는 채택 source만 허용하고 `http`, `https`, `file`, 임의 `blob`은 계속 차단한다.
5. navigation 완료 뒤 app-owned preparation script로 다음을 확인한다.
   - `document.fonts.ready` 완료
   - 필수 family/weight의 `document.fonts.check` 성공
   - SVG metrics의 유효성
6. font 준비와 metrics를 기존 page timeout lifecycle에 결합하고 중복 `createPDF`·completion을 막는다.
7. font load 실패, readiness 실패와 timeout을 page 번호가 있는 typed error로 매핑한다.
8. synthetic Korean/math fixture로 PDF를 생성하고 CGPDF helper가 해당 font resource의 `/ToUnicode`를 확인하도록 한다.
9. PDFKit search와 rectangle selection이 `문1`, `함수`, `값은`과 대표 수식 문자열을 반환하는지 확인한다.
10. 기존 영문 text, portrait/landscape, data PNG/SVG, script/event와 외부 resource/navigation test를 유지·보강한다.
11. loopback probe에 font URL과 우회 경로를 추가해 외부 요청이 0건임을 확인한다.
12. 동일 renderer를 사용하는 export controller의 searchable PDF 회귀를 한글 sentinel로 보강한다.

Stage 1에서 data font를 채택하면 PDF 전용 scheme handler는 만들지 않는다. custom scheme을 채택하면 기존 `RhwpStudioResourceSchemeHandler`를 넓히기보다 font 파일만 제공하는 좁은 handler를 우선하며, 공통 locator 재사용은 bundle traversal 방어가 동일하게 유지될 때만 허용한다.

### 5.4 단위·통합 회귀

- 허가된 Regular/Bold font resolve 성공
- 누락·과대·허용되지 않은 font와 traversal path 거부
- content JavaScript 비활성 유지와 app-owned readiness 성공
- readiness 실패·timeout의 exactly-once completion
- 한글 본문 font resource의 `ToUnicode` 존재
- 다른 font 하나의 성공이 한글 font 실패를 가리지 않음
- malformed/cyclic PDF resource에 대한 inspector 종료 보장
- `문1`, `함수`, `값은`과 대표 text 수식의 검색·rectangle selection
- 영문 text layer, page count와 portrait/landscape media box 유지
- data PNG/SVG 보존과 nonblank raster
- script, event handler, `javascript:` 실행 차단
- HTTP/HTTPS/file/blob/custom resource와 navigation 차단
- PDF 저장 controller와 일반 인쇄 공용 renderer 계약 유지

### 5.5 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task484-stage2-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task484-stage2-build \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/task484-stage2-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
./scripts/check-no-appkit.sh
git diff --check
```

외부 resource/navigation targeted test는 반복 실행해 loopback listener 준비 실패를 차단 성공으로 오인하지 않는지 확인한다.

### 5.6 완료 기준

- 합성 한글 본문 font resource에 유효한 `ToUnicode`가 존재한다.
- 한글·수식 PDFKit selection과 독립 text extraction이 통과한다.
- content JavaScript 비활성, CSP와 navigation 차단이 유지된다.
- font 준비 실패가 조용한 mapping 회귀가 아니라 명시적 render 오류가 된다.
- 기존 page geometry, data image, 영문 text와 print renderer 회귀가 없다.
- 전체 HostAppTests와 HostApp Debug build가 통과한다.

### 5.7 커밋

`Task #484 Stage 2: 한글 PDF Unicode mapping 보강`

## 6. Stage 3 — 실제 HWP/HWPX PDF 선택·렌더 통합 검증

### 6.1 목적

공개 `3-11월_실전_통합_2022.hwp`와 대표 HWPX를 Debug app에서 열어 메뉴·toolbar PDF 내보내기와 일반 인쇄를 검증한다. 실제 21-page 문서에서 font mapping 개선이 page geometry와 시각 배치를 손상하지 않는지 확인한다.

### 6.2 대표 fixture와 보관 경계

| fixture | 역할 | 보관 |
|---------|------|------|
| `3-11월_실전_통합_2022.hwp` 공개 sample | 21-page 한글 문항·수식·표·도형 통합 검증 | pinned/public source에서 `build.noindex/task484-stage3/`로 복사, 미커밋 |
| 대표 HWPX | HWPX page SVG와 PDF 공용 경로 회귀 | 저장소 공개 sample 복사본, 미커밋 |
| Stage 2 synthetic Korean/math | deterministic Unicode mapping 자동 회귀 | test source에 text fixture만 포함 |

실제 sample은 크기·출처 문제로 repository test asset에 복제하지 않는다. 원본 SHA-256과 수정 시각을 smoke 전후 비교한다.

### 6.3 검증 행렬

| 경로 | 필수 확인 |
|------|-----------|
| 내부 메뉴 PDF 내보내기 | 21 page, page geometry, 한글·수식 selection, `ToUnicode`, 정상 raster |
| toolbar PDF 내보내기 | 메뉴 결과와 text/raster/geometry 동등성 |
| 일반 인쇄 | 동일 renderer 결과, print preview page count·방향·내용 |
| 대표 HWPX | page count·geometry, 한글 mapping, nonblank raster |
| 취소·오류 | 원본과 current document state 불변, partial destination 없음 |

### 6.4 작업 범위

1. exact public sample provenance, source hash와 앱 build commit을 기록한다.
2. 메뉴와 toolbar에서 별도 PDF를 내보내고 SHA, byte size, page count와 media box를 기록한다.
3. 21개 page 전체의 `pdffonts` 결과를 집계한다.
   - 전체 font subset 수
   - `uni=yes/no` 수
   - `AppleSDGothicNeo` 등 예상 밖 system fallback 잔존
   - page별 subset 중복과 byte-size 변화
4. page 1을 포함한 대표 page에서 `문1`, `함수`, `값은`, 문항 번호·선택지와 text 기반 수식의 search·rectangle selection·복사를 확인한다.
5. `pdftotext -layout` 결과에서 한글 손실·깨짐과 과도한 reading-order 회귀를 확인한다.
6. 수정 전 사용자 PDF와 수정 후 PDF를 같은 조건으로 `pdftoppm` rasterize한다.
7. 모든 page의 크기·nonblank를 자동 확인하고 대표 page의 글자 폭, baseline, 줄바꿈, 수식·표·도형 배치를 side-by-side와 pixel summary로 비교한다.
8. 일반 인쇄 preview에서 page count, portrait/landscape와 내용이 PDF 저장 경로와 일치하는지 확인한다.
9. 대표 HWPX에서 같은 핵심 검증을 반복한다.
10. smoke 전후 source hash·mtime과 current document dirty state가 변하지 않았는지 확인한다.

Stage 3에서 발견된 수정이 Stage 2 계약 안의 소규모 보정이면 source/test와 함께 기록한다. 새로운 PDF post-processing, renderer 구조 변경이나 core/Studio asset 변경이 필요하면 해당 단계에 임의 포함하지 않고 구현계획 보정 승인을 요청한다.

### 6.5 검증

```bash
shasum -a 256 build.noindex/task484-stage3/*.{hwp,hwpx,pdf}
pdfinfo build.noindex/task484-stage3/*.pdf
pdffonts build.noindex/task484-stage3/*.pdf
pdftotext -layout <output.pdf> <output.txt>
pdftoppm -png -r 144 <output.pdf> build.noindex/task484-stage3/output-page
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task484-stage3-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
git diff --check
```

glob이 fixture 부재로 모호해지는 환경에서는 검증 대상의 확정 경로를 Stage 보고서에 개별 기록해 실행한다.

### 6.6 완료 기준

- 공개 21-page sample에서 한글 문항 본문 font의 `ToUnicode`가 확인된다.
- macOS Preview 실제 선택·복사, PDFKit selection과 `pdftotext`가 대표 한글을 보존한다.
- text 기반 수식은 가능한 범위에서 선택되며 이미지·도형 text와 명확히 구분된다.
- 21 page와 `794 × 1123 pt`, rotation 0이 유지된다.
- 수정 전후 대표 raster에서 줄바꿈, baseline, 수식·표·도형 배치 회귀가 없다.
- 메뉴·toolbar PDF와 일반 인쇄가 같은 renderer 계약을 유지한다.
- PDF byte size와 subset 중복 변화가 기록되고 실사용을 저해하는 급증이 없다.
- HWP/HWPX 원본과 current document state가 변경되지 않는다.

### 6.7 커밋

`Task #484 Stage 3: 실제 문서 PDF 선택과 렌더 회귀 검증`

## 7. Stage 4 — PDF text mapping 문서화와 최종 검증

### 7.1 목적

HostApp PDF/print renderer의 font source, readiness, Unicode mapping 검증과 알려진 선택 제한을 architecture·사용자 문서에 반영한다. 전체 타스크 변경을 clean 환경에서 최종 검증한다.

### 7.2 예상 변경 파일

- `mydocs/tech/project_architecture.md`
- 필요 시 `README.md`
- 필요한 경우 Stage 3에서 발견된 소규모 source/test 보정
- `mydocs/working/task_m010_484_stage4.md`
- `mydocs/orders/20260824.md`

v0.1.10 공개본이 이미 수정된 것처럼 release 문서를 소급 변경하지 않는다. 사용자 문서 보정이 필요하면 적용 대상이 다음 release 후보임을 명시한다.

### 7.3 문서화 항목

- page SVG → 격리 WebView → font readiness → page PDF → PDFKit merge 흐름
- PDF 전용 font source와 exact allowlist, CSP·navigation 경계
- `ToUnicode`, PDFKit selection, independent text extraction을 함께 보는 검증 기준
- 원본 proprietary font를 포함하지 않고 허가된 fallback을 사용하는 정책
- 일반 인쇄와 PDF 저장의 공용 renderer ownership
- positioned SVG text의 reading order와 viewer별 selection 차이
- 이미지·스캔·도형 안 글자는 선택되지 않으며 OCR을 제공하지 않는 제한
- page별 subset과 파일 크기 특성, 실제 Stage 3 측정치

### 7.4 최종 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task484-final-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task484-final-build \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/task484-final-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
./scripts/check-no-appkit.sh
git diff --check
git diff --stat devel...HEAD
```

Stage 2의 Korean/math mapping test와 external resource/navigation targeted test를 clean derived data에서 다시 실행한다. Stage 3의 대표 HWP/PDF smoke 결과도 최종 source commit과 일치하는지 확인한다.

### 7.5 완료 기준

- architecture와 사용자 문서가 실제 font-loading·보안·selection 계약과 일치한다.
- 한글 `ToUnicode` 회귀가 deterministic test와 실제 sample smoke로 추적된다.
- 전체 HostAppTests, HostApp Debug build, asset와 AppKit boundary 검사가 통과한다.
- `Sources/RhwpCoreBridge`, bundled minified Studio asset, core lock과 native Quick Look/Thumbnail renderer에 의도하지 않은 변경이 없다.
- Issue #484 완료 결과와 잔여 viewer/이미지 제한을 최종 보고할 수 있다.

### 7.6 커밋

`Task #484 Stage 4: PDF text mapping 문서와 최종 검증 정리`

## 8. 중단 및 분기 기준

1. exact 기준선에서 사용자 증상을 재현할 수 없으면 viewer, 선택 방식과 PDF font dictionary 차이를 다시 분리하고 Stage 2를 시작하지 않는다.
2. 기존 허가 WOFF2의 라이선스·bundle 포함 상태가 문서와 다르면 새 font를 추가하지 않고 자산 provenance 보정 범위를 승인받는다.
3. font source/readiness 후보가 `ToUnicode`를 만들지 못하면 불완전한 CSP 완화나 system font 교체만 병합하지 않는다.
4. `ToUnicode` 개선이 줄바꿈, page overflow, 표 높이 또는 수식 baseline을 바꾸면 시각 회귀를 허용하지 않고 다른 family/format 후보를 검토한다.
5. custom scheme이 PDF에 필요하지 않은 Studio resource까지 노출하거나 traversal을 막지 못하면 해당 후보를 폐기한다.
6. font 준비를 위해 content JavaScript, 외부 network/file 접근 또는 임의 data font 실행이 필요하면 보안 계약을 완화하지 않고 계획 보정 승인을 요청한다.
7. CGPDF helper가 생성 환경에 과적합되어 실제 font resource를 신뢰성 있게 구분하지 못하면 `pdffonts`만 CI 의존으로 추가하지 않고 test fixture·검사 설계를 보정한다.
8. page별 PDF merge 때문에 mapping이 다시 소실되는 것으로 확인되면 single-document 변환이나 post-processing을 같은 Stage에 끼워 넣지 않고 별도 범위와 migration 위험을 보고한다.
9. 실제 HWP/HWPX에서 합성 fixture와 다른 수식 font 문제가 남으면 본문 mapping 완료 여부와 분리해 후속 범위를 제안한다.
10. PDF byte size나 생성 시간이 기준선 대비 실사용을 저해할 만큼 증가하면 수치와 원인을 보고하고 cache/subset 최적화 범위 승인을 받는다.

## 9. 단계별 승인·보고·PR 경계

- 각 Stage 종료 시 `task-stage-report`를 명시 호출해 `mydocs/working/task_m010_484_stage{N}.md`를 작성하고 해당 단계의 source·test·문서와 함께 하나의 Stage 커밋으로 묶는다.
- Stage 보고에는 실제 실행 명령, fixture provenance, 원본·출력 hash, font resource와 `uni=yes/no`, selection·raster 결과, 실패·제한과 다음 Stage 진입 조건을 기록한다.
- Stage 1 승인 전 Stage 2 production source와 test를 변경하지 않는다.
- Stage 2 승인 전 Stage 3 실제 앱 smoke를 시작하지 않는다.
- Stage 3 승인 전 Stage 4 사용자·architecture 문서와 최종 검증을 시작하지 않는다.
- 네 Stage가 모두 승인된 뒤에만 `task-final-report`를 명시 호출해 `mydocs/report/task_m010_484_report.md`, 오늘할일 완료 처리, 최종 커밋, `publish/task484` push와 `devel` 대상 PR을 수행한다.
- PR 본문에는 `Closes #484`를 사용한다. #455는 원인 도입 이력으로만 참조하고 상태를 변경하지 않는다.
- release, 서명, 공증, GitHub Release, appcast와 Homebrew 배포는 이 타스크 범위가 아니다.

## 10. 리뷰 포인트

- 한글 text가 존재한다는 사실과 해당 font resource의 `ToUnicode` 존재를 구분해 검사하는가?
- font source가 기존 허가 번들 asset의 exact allowlist로 제한되는가?
- content JavaScript 비활성과 외부 resource·navigation 차단을 유지하는가?
- `document.fonts.ready`와 필수 family 확인 뒤에만 `createPDF`를 호출하는가?
- font load 실패가 system fallback으로 은폐되지 않고 page 단위 오류가 되는가?
- 한글 본문 mapping 개선이 수식·표·줄바꿈·page geometry를 바꾸지 않는가?
- 합성 fixture뿐 아니라 공개 21-page HWP와 대표 HWPX에서 검증하는가?
- 메뉴·toolbar PDF 저장과 일반 인쇄가 동일 renderer 계약을 유지하는가?
- 이미지/스캔 text와 viewer별 reading-order 제한을 과도하게 보장하지 않는가?
- 새 font binary, bundled minified Studio asset, core/FFI와 native renderer를 범위 밖으로 유지하는가?

## 11. 구현계획 승인 요청

- Stage 1에서 current fallback, data WOFF2, PDF 전용 custom scheme과 readiness 대기 유무를 비교해 수정 계약을 확정한다.
- Stage 2에서 승인된 최소 font source·readiness와 한글 `ToUnicode`/selection 회귀 테스트를 구현한다.
- Stage 3에서 공개 21-page HWP와 대표 HWPX의 PDF 저장·인쇄 text/raster/geometry를 통합 검증한다.
- Stage 4에서 PDF text mapping 경계와 잔여 제한을 문서화하고 전체 clean 검증을 완료한다.

위 단계, font source 최소권한 원칙, 시각 회귀 및 WebKit 한계 중단 기준 승인 후 Stage 1 조사를 시작한다.
