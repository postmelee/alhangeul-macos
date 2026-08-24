# Task #484 Stage 1 완료보고서

## 단계 목적

exact `devel`, v0.1.10과 사용자 제공 PDF에서 page SVG의 font-family, WebKit resolved font와 PDF font resource의 관계를 재현한다. system fallback, bundled WOFF2 source, font 범위와 readiness 후보를 제품 소스 변경 전에 비교해 한글 `ToUnicode` 누락 원인과 Stage 2의 최소 수정·검증 계약을 확정한다.

## 산출물

- 사용자 제공 21-page PDF의 font resource와 `ToUnicode` 기준선 확정
- 공개 HWP 첫 페이지의 실제 core SVG, font stack과 한글·수식 text run 조사
- system, data font, exact custom scheme, Noto, Pretendard, local alias와 font readiness 후보 비교
- `ToUnicode` 존재와 실제 Unicode mapping 정확성을 구분하는 회귀 기준 확정
- PDF 전용 exact custom scheme + Noto Hangul 범위 + `document.fonts.ready` 후보 채택
- 한글 font만 보정하고 기존 구두점·Hanja·수식 system font 경로를 유지하는 최소 범위 확정
- PDFKit search·selection, Poppler text extraction, 72/144 dpi raster와 loopback request 검증
- WebKit/Quartz 경로 안에서 Stage 2를 구현할 수 있고 PDF post-processing 분기가 불필요하다는 판정

제품 소스, 테스트 target, `project.yml`, bundled font와 `rhwp-studio` asset은 이번 단계에서 변경하지 않았다. 실험 harness, 추출 SVG, 생성 PDF·PNG와 로그는 `build.noindex/task484-stage1/` 아래에만 두고 커밋하지 않는다.

## exact 기준과 provenance

| 항목 | 확인 결과 |
|------|-----------|
| `devel` 기준 | `18cdb8b7458ea8adef0ec88057ae7742af110dd7` |
| v0.1.10 tag | `cd74a7ec8f3bc5bcc5862931b1eda9bbfeecc1b3` |
| 작업 브랜치 | `local/task484` |
| 공개 source HWP | `rhwp` samples의 `3-11월_실전_통합_2022.hwp` |
| source HWP SHA-256 | `bc8bccbb954c337d813d1af96f4e3047242124c2f2939163e282634eb721accd` |
| 사용자 app PDF SHA-256 | `0b5d64c4611555578a70f9b78540775f43f81a2886bda4e91d12db54154acdaf` |
| 비교용 Hancom PDF SHA-256 | `f06bf088ec7fda3cc6873f6158ca4103503039acbb1c608eafcf62ae16c052a7` |
| Poppler | `26.07.0` |
| Swift/Xcode | Apple Swift 6.3.3, Xcode 26.6 (`17F113`) |

사용자 Desktop PDF와 sibling `rhwp` repository의 HWP는 읽기 기준으로만 사용했다. Stage 종료 시 두 파일의 SHA-256이 최초 조사 값과 같고 HWP size·mtime도 변하지 않았음을 재확인했다.

## 사용자 PDF 기준선

사용자가 v0.1.10으로 내보낸 PDF의 구조는 다음과 같다.

| 항목 | 결과 |
|------|------|
| producer | macOS 26.5.2 Quartz PDFContext |
| PDF version | 1.4 |
| page | 21 |
| page size | 모든 page `794 × 1123 pt`, rotation 0 |
| file size | 7,570,926 bytes |
| font resource | 184개 |
| `uni=yes` | 79개 |
| `uni=no` | 105개 |

page 1의 한글 본문은 `AppleSDGothicNeo-Bold/Medium/Regular` CID Type 0C, Identity-H subset으로 생성됐으며 모두 `uni=no`다. 반면 비교용 Hancom PDF는 21 page, 1,345,036 bytes, 9 font가 모두 `uni=yes`다.

사용자 PDF에는 모든 page에 text object가 있고 PDFKit page string과 full-page selection이 존재한다. 따라서 텍스트가 bitmap이거나 수식이라서 text layer가 없는 문제는 아니다. PDFKit과 Poppler가 system font 정보를 추론할 수 있어도 명시적인 `ToUnicode`가 없는 한글 subset은 다른 viewer에서 선택·검색·복사가 안정적이지 않다.

## 실제 page SVG 조사

pinned core의 `renderPageSVG`로 공개 HWP page 1을 추출했다. bundled Studio의 `getPageSvg`도 같은 core `renderPageSvg(page)` 경로를 사용하므로 HostApp PDF renderer 입력과 동등한 SVG 계약이다.

| 항목 | 결과 |
|------|------|
| page count | 21 |
| page size | `793.7 × 1122.5 pt` |
| SVG bytes | 320,640 |
| text run | 168 |
| Hangul run | 47 |
| Hangul scalar | 160 |
| missing Hangul glyph | 0 |
| embedded `@font-face` | 없음 |
| external font URL | 없음 |

대표 font stack은 다음과 같다.

- sans 본문: `Haansoft Dotum` → `Malgun Gothic` → `Apple SD Gothic Neo` → `Noto Sans KR` → `Pretendard`
- serif 본문: `Haansoft Batang` → `Batang` → `Nanum Myeongjo` → `AppleMyungjo` → `Noto Serif KR`
- 수식: `Latin Modern Math` → `STIX Two Text` → `STIX Two Math`

현재 HTML wrapper는 `@font-face`를 제공하지 않고 `font-src 'none'`을 사용한다. 원본의 한컴 font가 설치되지 않은 환경에서는 font stack 앞쪽의 system Apple font가 Noto/Pretendard보다 먼저 선택된다.

## 원인 판정

원인은 다음 조건의 조합이다.

1. page SVG에는 정상 Unicode `<text>`가 있다.
2. 현재 `getPageSvg` 경로는 web font를 embed하지 않는다.
3. PDF wrapper도 bundled font를 선언하지 않고 `font-src 'none'`으로 차단한다.
4. 원본 font가 없는 환경에서 WebKit은 먼저 사용 가능한 `Apple SD Gothic Neo`를 선택한다.
5. WebKit/Quartz가 이 system CJK font를 CID Type 0C, Identity-H subset으로 쓰면서 `ToUnicode`를 생성하지 않는다.

따라서 CSP 자체가 CMap을 제거하는 것은 아니지만 bundled Unicode font를 사용할 통로가 없는 현재 계약이 system CJK font 경로를 고정하는 원인이다. 수식은 별도의 STIX text font로 생성되고 대표 수식 text가 정상 추출되므로 문항 본문 선택 실패의 직접 원인이 아니다.

## 후보 실험과 판정

실제 page 1 SVG와 `문1 함수의 값은 다음과 같다`, 한글·선택지·수식을 포함한 합성 SVG를 같은 offscreen WKWebView에서 변환했다. 비영구 website data store, content JavaScript 비활성, initial `about:blank`만 허용하는 navigation과 기존 CSP를 유지하고 font source만 후보별로 변경했다.

| 후보 | page 1 bytes | font `yes/no` | Unicode 결과 | 판정 |
|------|--------------|---------------|----------------|------|
| 현재 system fallback | 195,679 | 4/5 | PDFKit 추론은 성공, AppleSDGothicNeo 한글 `uni=no` | 기준선 |
| Noto 전체 범위 data | 209,303 | 5/2 | 공백 `#`, 물음표 `(`, 쉼표 `3` 등 잘못된 mapping | 거부 |
| Noto 전체 범위 exact scheme | 209,303 | 5/2 | data와 font 구조 동일, 잘못된 mapping 동일 | 거부 |
| Pretendard 전체 범위 | 210,937 | 5/3 | `문 1`, `함 수`처럼 positioned text 사이 과도한 공백 | 거부 |
| Noto Hangul 범위 + bundled math | 210,431 | 5/3 | text 정확, 수식 glyph까지 불필요하게 변경 | 축소 |
| Noto Hangul 범위 + 기존 math, data | 198,214 | 6/4 | 한글·구두점·수식 정확 | 통과 |
| Noto Hangul 범위 + 기존 math, exact scheme | 198,214 | 6/4 | data와 byte 동일, 한글·구두점·수식 정확 | 채택 |
| local Apple alias | 252,770 | 3/4 | text 추론은 가능하지만 Apple 한글 `uni=no` 유지 | 거부 |

이 실험은 `ToUnicode` stream 존재만으로 mapping 정확성을 판정하면 안 된다는 사실도 확인했다. 전체 범위 Noto와 Pretendard 결과는 `uni=yes`지만 실제 PDFKit string에 잘못된 문자 또는 과도한 공백이 생겼다. Stage 2 자동 검증은 font dictionary와 정확한 Korean sentinel string을 함께 검사해야 한다.

## 채택한 Stage 2 font·보안 계약

### PDF 전용 resource route

- 기존 `alhangeul-studio://app/` handler는 JS, WASM, HTML과 전체 Studio resource를 제공하므로 PDF font에 재사용하지 않는다.
- 별도 scheme 후보 이름은 `alhangeul-pdf-font`, host는 `bundle`로 한다.
- exact filename allowlist는 다음 네 파일이다.
  - `NotoSansKR-Regular.woff2`
  - `NotoSansKR-Bold.woff2`
  - `NotoSerifKR-Regular.woff2`
  - `NotoSerifKR-Bold.woff2`
- bundle의 `rhwp-studio/fonts` 아래 regular file만 제공한다.
- MIME은 `font/woff2`, 크기 상한은 현재 최대 1,033,556 bytes보다 여유 있는 1.25 MiB로 제한한다.
- scheme, host, path, filename, 확장자, regular file과 size 중 하나라도 맞지 않으면 실패한다.
- external HTTP/HTTPS, file, blob, data font와 다른 custom scheme은 허용하지 않는다.

### font alias와 Unicode 범위

- 실제 SVG의 한컴/HY sans·serif 첫 family를 기존 bundled Noto source에 alias한다.
- 같은 WOFF2 URL을 여러 alias가 재사용해 page HTML에 base64 font를 반복하지 않는다.
- Noto face는 다음 Hangul/Jamo 범위에만 적용한다.
  - `U+1100-11FF`
  - `U+3130-318F`
  - `U+A960-A97F`
  - `U+AC00-D7AF`
  - `U+D7B0-D7FF`
- ASCII space·구두점·circled number·Hanja와 수식은 현재 system fallback을 유지한다.
- `LatinModernMath-Regular.woff2`는 이번 수정에서 로드하지 않는다. 수식은 원인과 무관하고 현재 STIX text 추출이 정상이다.

### readiness와 실패 계약

- navigation 완료 뒤 `callAsyncJavaScript`를 `WKContentWorld.defaultClient`에서 실행한다.
- `await document.fonts.ready` 뒤 `document.fonts.status == "loaded"`와 실제 사용 face에 `error`가 없는지 확인한다.
- 성공한 실문서 후보는 Noto Sans KR Bold/Regular, Noto Serif KR Bold 세 URL만 각각 1회 요청했다.
- readiness와 metrics를 기존 page timeout lifecycle 안에서 처리한다.
- font resource 누락·거부·load error 또는 readiness 실패는 page 번호가 있는 typed render error로 반환한다.
- 실패를 system fallback으로 숨긴 채 PDF를 계속 만들지 않는다.
- content JavaScript는 계속 비활성으로 유지한다.

### CSP

기존 CSP에서 font directive만 다음과 같이 최소 변경한다.

```text
font-src alhangeul-pdf-font:;
```

`default-src`, script, connect, frame, object, media, worker, manifest, base, form과 `img-src data:` 경계는 유지한다. untrusted SVG보다 CSP와 app-owned font CSS를 먼저 배치한다.

## text·selection·raster 결과

채택 후보의 실제 page 1 결과는 다음과 같다.

| 항목 | 결과 |
|------|------|
| page geometry | `794 × 1123 pt`, 기준선과 동일 |
| PDFKit page string | 933 characters |
| PDFKit full-page selection | 933 characters |
| PDFKit `문1` find | 1건 |
| PDFKit `함수` find | 4건 |
| PDFKit `값은` find | 8건 |
| `pdftotext -layout` | `문1`, `함수`, `값은`, `(단, a, b는 상수이다.)` 보존 |
| file size 변화 | +2,535 bytes, +1.295% |
| 72 dpi pixel diff | 14,074/891,662 pixels, 1.5784% |

동일 조건의 PNG를 직접 확인한 결과 허가된 Noto fallback을 쓰는 한글 glyph 모양만 달라졌다. page geometry, column·표·도형 위치, 줄바꿈, 수식 font·baseline과 image는 유지됐다. 사용자 PDF 21 page는 144 dpi에서 모두 `1588 × 2246 px`로 렌더됐고 page 1, 10, 21을 대표 확인해 clipping, overlap, black square와 unreadable glyph가 없음을 확인했다.

## external resource·navigation 경계 확인

후보 CSP와 exact scheme을 적용한 임시 harness에 다음 loopback resource를 넣었다.

- HTTP `@font-face`
- HTTP `<image>`
- HTTP CSS paint/background URL

`127.0.0.1:18984` 서버를 준비하고 `probe.txt` 양성 대조 1건을 성공시킨 뒤 system, data, scheme와 local alias 7개 후보를 렌더했다. 최종 HTTP request 수도 1건이어서 renderer가 추가로 만든 external font/image request는 0건이었다.

후보가 바꾸는 fetch 권한은 `alhangeul-pdf-font:`뿐이며 기존 navigation delegate는 그대로 유지한다. traversal, wrong host·path와 resource load failure의 자동 회귀는 Stage 2에서 pure route test와 renderer integration test로 고정한다.

## Stage 2 자동 테스트 계약

1. exact scheme/host/font filename과 MIME·size 허용
2. wrong scheme/host, traversal, query/path 위장, non-WOFF2, missing/oversize file 거부
3. `@font-face`와 CSP가 untrusted SVG보다 먼저 배치됨
4. `font-src`가 PDF scheme만 허용하고 HTTP/HTTPS/file/blob/data를 거부함
5. content JavaScript 비활성 유지
6. `document.fonts.ready`와 used face 상태 확인 뒤에만 `createPDF` 호출
7. font load 실패·readiness timeout의 page error와 exactly-once completion
8. CGPDF page/nested resource에서 Noto 한글 font의 `/ToUnicode` 존재 확인
9. Korean/math synthetic PDF의 exact page string, search와 rectangle selection
10. `문1`, `함수`, `값은`, 공백·쉼표·물음표·괄호가 정확히 유지됨
11. portrait/landscape, data PNG/SVG와 nonblank raster 유지
12. script/event/`javascript:` 실행 차단과 loopback external request 0건
13. export controller의 한글 searchable PDF 회귀

CGPDF helper가 한글 font를 다른 성공 font와 혼동하지 않도록 `/BaseFont`와 `/ToUnicode`를 함께 기록한다. malformed/cyclic nested resource는 visited set과 depth 제한으로 종료를 보장한다.

## 본문 변경 정도와 무손실 확인

- production source와 test: 변경 없음
- bundled WOFF2와 `rhwp-studio`: 변경 없음
- `project.yml`과 `Alhangeul.xcodeproj`: 변경 없음
- `rhwp-core.lock`, Rust FFI와 dependency: 변경 없음
- Quick Look/Thumbnail native renderer: 변경 없음
- 사용자 HWP/PDF와 sibling repository: hash 불변
- 추적 문서: 이 Stage 1 완료보고서 신규 작성
- 오늘할일: Stage 1 완료·Stage 2 승인 대기로 갱신
- 실험 산출물: `build.noindex/task484-stage1/`에만 존재, commit 대상 아님

PDF 스킬의 임시 `tmp/pdfs/` PNG는 시각 확인 뒤 삭제했다. 재현 가능한 candidate PDF·PNG·font/text 로그는 구현 단계 비교를 위해 ignored `build.noindex/`에 유지한다.

## 검증 결과

| 명령/검증 | 결과 |
|-----------|------|
| `shasum -a 256 <source.hwp> <app.pdf> <reference.pdf>` | 통과. 세 SHA-256이 기준값과 일치 |
| `pdfinfo <app.pdf>` | 통과. 21 page, `794 × 1123 pt`, rotation 0, 7,570,926 bytes |
| `pdffonts <app.pdf>` | 통과. 184 fonts, `uni=yes` 79, `uni=no` 105 재현 |
| `pdftotext -layout <app.pdf> <app.txt>` | 통과. 21-page text layer 생성과 대표 한글 확인 |
| `pdftoppm -png -r 144 <app.pdf> ...` | 통과. 21 PNG, 각 `1588 × 2246 px`; page 1·10·21 시각 확인 |
| `scripts/verify-rhwp-studio-assets.sh` | 통과. `OK: rhwp-studio assets verified` |
| actual SVG 조사 | 통과. 168 text run, 47 Hangul run, 160 Hangul scalar, missing glyph 0 |
| 후보 PDFKit probe | 통과. page string·full selection 933, `문1`/`함수`/`값은` 검색 성공 |
| 후보 `pdffonts`/`pdftotext` | 통과. Noto 한글 `uni=yes`, 대표 한글·구두점·수식 정확 |
| 후보 raster diff | 통과. geometry 동일, diff 1.5784%, 한글 glyph 외 layout 변화 없음 |
| loopback security probe | 통과. positive control 1건, renderer external request 0건 |
| `git diff --check` | 통과. whitespace 오류 없음 |

Stage 1은 조사와 임시 harness만 사용하는 단계이므로 Xcode project 생성, HostAppTests와 HostApp build는 실행하지 않았다. Stage 2 구현 뒤 계획에 정한 전체 test/build를 수행한다.

## 잔여 위험

- Stage 1 후보는 공개 HWP의 첫 page SVG와 합성 Korean/math SVG에서 검증했다. 21-page 실제 수정 PDF와 대표 HWPX 전체 page 검증은 Stage 3에 남아 있다.
- Hangul/Jamo만 Noto web font로 보정한다. Hanja, CJK symbol, ASCII·구두점과 수식 font 중 일부 `uni=no`는 현재 system 경로를 유지하며 이번 한글 본문 완료 조건과 구분해야 한다.
- `ToUnicode`가 있어도 positioned text reading order와 viewer별 selection UX를 완전히 보장하지 않는다. 정확한 sentinel과 실제 Preview selection을 함께 유지해야 한다.
- alias family가 future upstream SVG에서 바뀌면 해당 한글 text가 system fallback으로 돌아갈 수 있다. Stage 2 테스트와 asset sync 검토에서 alias 목록 drift를 확인해야 한다.
- exact scheme handler가 같은 URL을 page마다 다시 읽을 수 있다. 첫 page에서는 요청당 1회였지만 21-page 생성 시간과 cache·memory는 Stage 3에서 측정해야 한다.
- first-page 후보 PDF는 1.295% 증가했지만 page별 subset merge 구조에서 21-page 총 크기 증가는 별도 측정이 필요하다.
- `document.fonts.ready`는 사용 face의 상태 확인과 함께 써야 한다. Promise resolve만 보고 font failure를 성공으로 오인하지 않아야 한다.
- Xcode test bundle에서 production font를 읽는 방식은 새 binary 복제 없이 hermetic해야 한다. `project.yml` resource 연결 또는 injectable provider 중 최소 방식을 Stage 2에서 선택한다.

## 다음 단계 영향

Stage 2는 `RhwpStudioPagePDFRenderer`에 PDF font preparation state를 결합하고, 별도 PDF font route/handler와 exact alias CSS를 추가한다. 신규 production 파일을 분리하면 `project.yml` HostAppTests source와 기존 WOFF2 test resource 연결을 갱신하고 `xcodegen generate`로 project를 재생성한다. `Alhangeul.xcodeproj`는 직접 수정하지 않는다.

우선 변경 후보는 다음과 같다.

- `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift`
- 필요 시 `Sources/HostApp/Services/RhwpStudioPDFFontResource.swift`
- `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift`
- `Tests/HostAppTests/RhwpStudioPDFExportControllerTests.swift`
- 필요 시 CGPDF font inspector test helper와 `project.yml`

기존 `RhwpStudioResourceSchemeHandler`를 확장하지 않고 PDF font resource만 제공하는 별도 handler를 우선한다. bundled minified Studio asset, core/FFI와 Quick Look/Thumbnail renderer는 변경하지 않는다.

## 승인 요청

Stage 1에서 한글 `ToUnicode` 누락 원인을 system Apple CJK font fallback 경로로 확정했고, `PDF 전용 exact scheme + Noto Hangul 범위 + font readiness` 최소 후보가 정확한 text mapping, 시각 배치와 외부 resource 차단을 함께 통과했다.

Stage 1 완료 결과와 위 구현·테스트 계약을 검토하고 Stage 2 `격리 font 준비와 한글 PDF 회귀 구현` 진입 승인을 요청한다.
