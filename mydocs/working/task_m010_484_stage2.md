# Task M010 #484 Stage 2 완료 보고

## 단계 목적

Stage 1에서 승인한 `PDF 전용 exact custom scheme + Noto Sans/Serif KR의 Hangul/Jamo 범위 매핑 + font readiness 확인` 계약을 `RhwpStudioPagePDFRenderer`에 구현한다. 합성 한글·수식 PDF의 Unicode text layer와 `/ToUnicode`를 자동 검증하면서 기존 page geometry, data image, script·resource·navigation 차단과 exactly-once completion을 유지한다.

## 산출물

| 파일 | 규모 | 변경 요약 |
|------|------|-----------|
| `Sources/HostApp/Services/RhwpStudioPDFFontProvider.swift` | 288줄, 신규 | Noto Sans/Serif KR 4종 exact allowlist, bundle/directory provider, WOFF2 signature·크기·일반 파일·symlink 경계 검증, PDF 전용 scheme handler와 Hangul/Jamo alias CSS 추가 |
| `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` | 509줄 | PDF scheme handler 등록, `document.fonts.ready`와 사용 family/weight 확인, page 번호가 있는 typed font error, CSP `font-src` 최소 허용 추가 |
| `Sources/HostApp/Services/RhwpStudioPDFExportController.swift` | 86줄 | 공용 renderer 계약을 유지하면서 테스트용 renderer 주입 경계 추가 |
| `Tests/HostAppTests/CGPDFFontResourceInspector.swift` | 201줄, 신규 | page와 nested Form XObject의 font resource·`/ToUnicode` 검사, visited set과 depth 제한 추가 |
| `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` | 848줄 | 한글·수식 선택/검색/ToUnicode, exact route, invalid font, readiness failure, loopback 보안과 기존 geometry/data image 회귀 보강 |
| `Tests/HostAppTests/RhwpStudioPDFExportControllerTests.swift` | 129줄 | 2-page 한글 searchable PDF와 portrait/landscape 회귀 보강 |
| `project.yml` | 193줄 | 신규 production font provider를 HostAppTests source에 포함 |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen` 생성 | `project.yml` 기준으로 신규 production/test helper source 반영 |

신규 binary font는 추가하지 않았다. 앱에 이미 포함된 `NotoSansKR-Regular/Bold.woff2`와 `NotoSerifKR-Regular/Bold.woff2`만 재사용한다.

## 본문 변경 정도 / 본문 무손실 여부

- page SVG의 Unicode `<text>`와 수식·ASCII 경로는 변경하지 않았다.
- 한글·한글 자모 Unicode 범위만 승인된 Noto Sans/Serif KR alias로 보정한다. ASCII, 구두점, 수식, Hanja와 그 밖의 glyph는 기존 font 경로를 유지한다.
- PDF 전체 bitmap화, OCR overlay와 post-processing을 추가하지 않았다.
- bundled `rhwp-studio` minified asset과 기존 WOFF2 binary는 변경하지 않았다.
- `rhwp-core.lock`, Rust FFI, `Sources/RhwpCoreBridge`, Quick Look/Thumbnail renderer는 변경하지 않았다.
- 사용자 HWP/PDF와 sibling repository 원본은 읽기 기준으로만 사용했으며 수정하거나 저장소에 복제하지 않았다.
- 합성 PDF, harness, text와 raster 산출물은 ignored `build.noindex/task484-stage2/`에만 유지한다. PDF 스킬 시각 검사용 `tmp/pdfs/` PNG는 확인 후 삭제했다.

## 검증 결과

| 명령/검증 | 결과 |
|-----------|------|
| `xcodegen generate` | 통과. `Alhangeul.xcodeproj` 재생성 완료 |
| 계획서의 `xcodebuild ... -scheme HostAppTests ... test` | 통과. 148 tests, 0 failures, `TEST SUCCEEDED` |
| `RhwpStudioPagePDFRendererTests` | 통과. 16 tests, 0 failures |
| 계획서의 `xcodebuild ... -scheme HostApp ... build` | 통과. `BUILD SUCCEEDED` |
| built app `scripts/verify-rhwp-studio-assets.sh .../rhwp-studio` | 통과. 앱 번들의 Studio asset과 기존 font 4종 확인 |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code의 AppKit/UIKit 직접 의존 없음 |
| `git diff --check` | 통과. whitespace 오류 없음 |
| synthetic Korean/math PDFKit | 통과. `문1`, `함수`, `값은`, `f(x)`의 page string·rectangle selection·search 확인 |
| CGPDF font inspector | 통과. Noto Sans/Serif KR font resource가 모두 `/ToUnicode` 보유 |
| 독립 `pdffonts`/`pdftotext -layout` | 통과. Noto 한글 font `uni=yes`, 한글 본문과 수식 문자열 정확 추출 |
| `pdftoppm -png -r 144` 시각 확인 | 통과. 500×300 pt 1-page fixture에서 한글 bold/serif와 수식 누락·겹침·잘림 없음 |
| loopback resource probe | 통과. positive control 요청은 도달하고 renderer HTTP/HTTPS 및 invalid custom font 요청은 0건 |
| font failure lifecycle | 통과. 필수 bold font 누락이 page 1 typed error로 exactly once 완료 |

샌드박스 내부에서 계획서의 test 명령을 처음 실행했을 때 Sparkle clone의 DNS 접근이 차단됐으나, 권한 허용 환경에서 같은 명령을 그대로 재실행해 package resolve부터 148개 테스트까지 통과했다. 코드·테스트 실패로 처리할 항목은 없다.

## 잔여 위험

- Stage 2 완료 조건은 합성 Korean/math fixture와 renderer/export controller 자동 회귀에서 확인했다. 실제 21-page HWP와 대표 HWPX의 전체 page 결과는 Stage 3에 남아 있다.
- Hangul/Jamo만 Noto web font로 보정하므로 Hanja, CJK symbol, ASCII·구두점과 수식 font 일부는 system font resource를 계속 사용할 수 있다. 이를 한글 본문 매핑 실패와 구분해야 한다.
- upstream page SVG가 현재 allowlist에 없는 새로운 한글 family 이름을 사용하면 renderer가 조용히 fallback하지 않고 해당 page를 명시적 font preparation error로 종료한다. alias drift는 향후 Studio sync에서 함께 갱신해야 한다.
- page별 scheme 요청과 font subset이 21-page PDF의 생성 시간, peak memory와 최종 파일 크기에 미치는 영향은 Stage 3에서 측정해야 한다.
- 실제 Preview의 드래그 선택 UX, 메뉴/toolbar 결과 동등성과 일반 인쇄 preview는 Stage 3 수동 smoke가 필요하다.

## 다음 단계 영향

Stage 3에서는 production source를 추가 변경하지 않고 먼저 승인된 Debug app과 공개 sample 복사본으로 실제 PDF를 생성한다. 다음 항목을 전후 비교한다.

- 21 page의 media box, rotation, nonblank raster와 대표 page 배치
- 전체 font subset의 `uni=yes/no`, 예상 밖 system fallback과 PDF byte size
- `문1`, `함수`, `값은`, 문항 번호·선택지·text 수식의 검색과 rectangle selection
- 메뉴·toolbar PDF 결과 동등성과 일반 인쇄 preview
- 대표 HWPX의 geometry, 한글 mapping과 nonblank raster
- 원본 HWP/HWPX의 SHA-256과 수정 시각 불변

Stage 3의 공개 fixture 복사본과 출력 PDF, PNG, text와 로그는 `build.noindex/task484-stage3/`에만 두고 커밋하지 않는다.

## 승인 요청

작업지시자는 Stage 2 구현·검증 결과 보고 뒤 `진행해줘`라고 지시해 Stage 2 종료 보고서·단계 커밋과 Stage 3 실제 21-page HWP/HWPX 통합 검증 진행을 승인했다. 이 보고서와 Stage 2 산출물을 하나의 커밋으로 확정한 뒤 Stage 3에 진입한다.
