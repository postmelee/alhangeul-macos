# Task #460 Stage 4 완료 보고서

## 단계 목적

Stage 2~3에서 강화한 PDF·인쇄 renderer 정책이 synthetic page와 실제 HWP/HWPX의 page geometry, searchable text, image, raster와 인쇄 방향을 손상하지 않는지 검증한다. toolbar와 내부 메뉴의 PDF 저장, 일반 인쇄가 동일한 hardened renderer 결과를 사용하고 원본 문서 상태를 바꾸지 않는지도 함께 확인한다.

## 산출물

- `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` (473줄)
  - portrait `200 × 300 pt`, landscape `300 × 200 pt` media box를 오차 `0.01` 이내로 검증한다.
  - portrait/landscape mixed 2-page 문서는 job orientation을 강제하지 않는지 확인한다.
  - 각 합성 page에 blue raster sentinel을 추가하고 PDF raster에 남는 비율을 검증한다.
  - 기존 page count, PDF signature, searchable text와 PDFKit print operation 검증을 유지한다.
- `mydocs/working/task_m040_460_stage4.md`
  - synthetic·실문서 PDF 결과, 실제 인쇄 패널, 기준선 비교와 원본 무손실 결과를 기록했다.
- `mydocs/orders/20260808.md`
  - #460 상태를 Stage 4 완료 및 Stage 5 승인 대기로 갱신했다.

실제 smoke의 문서 복사본, PDF, 추출 text와 PNG raster는 gitignored `build.noindex/task460/` 아래에만 만들었다. production source, `project.yml`, 생성된 Xcode project와 bundled `rhwp-studio` asset의 tracked 변경은 없다.

## 구현 결과

### Synthetic PDF·인쇄 회귀 보강

기존 portrait/landscape 2-page fixture에 exact media box assertion과 raster sentinel을 추가했다. 두 page는 각각 `200 × 300 pt`, `300 × 200 pt`를 유지하고 page마다 blue sentinel이 nonblank raster로 남는다. 한 문서 안에 세로와 가로 page가 함께 있으므로 `RhwpStudioPrintOrientationPolicy.orientation(for:)`는 `nil`을 반환하며, 기존 `PDFDocument.printOperation(... autoRotate: true)` 생성 검증도 통과한다.

같은 renderer test suite의 script/event handler, nested data SVG, embedded data PNG, external resource/navigation와 invalid metrics fixture도 함께 통과했다. 따라서 실행·network 차단과 정상 data image·text·geometry 보존이 한 전체 test run에서 확인됐다.

### 실제 PDF 저장 결과

원본을 직접 저장 대상으로 사용하지 않고 `build.noindex/task460/stage4-fixtures/`의 `cp -p` 복사본만 앱에서 열었다.

| 문서/경로 | page 수 | page geometry | text/raster |
|---|---:|---|---|
| KTX 내부 메뉴 | 1 | `1123 × 794 pt`, rotation 0 | 검색 가능, nonblank |
| KTX toolbar | 1 | `1123 × 794 pt`, rotation 0 | 검색 가능, nonblank |
| 다중 HWP toolbar | 9 | 전 page `794 × 1123 pt`, rotation 0 | 검색 가능, 전 page nonblank |
| HWPX toolbar | 9 | 전 page `794 × 1123 pt`, rotation 0 | 검색 가능, 전 page nonblank |

KTX 내부 메뉴와 toolbar PDF는 Quartz 생성 시각 metadata 때문에 파일 SHA-256은 다르지만 추출 text와 96 DPI page raster가 byte 단위로 동일했다. KTX raster는 `1498 × 1059 px`, HWP/HWPX raster는 `1059 × 1498 px`이며 KTX의 지도·시간표·운임표와 HWP/HWPX의 로고·표·본문 이미지가 정상 표시됐다.

PR #458 Stage 4 기준선과도 비교했다. 새 KTX toolbar의 text와 raster는 기존 `ktx-toolbar.pdf` 결과와 동일했고, 새 다중 HWP 9개 page의 text와 모든 raster도 기존 `hwp-multi-toolbar.pdf` 결과와 동일했다. 보안 hardening 전후 정상 문서의 출력 손실이 관측되지 않았다.

### 실제 인쇄 패널

- HWPX 복사본: 9 page가 세로 preview로 표시되고 첫 두 page가 정상 내용으로 확인됐다.
- KTX 복사본: 1 page가 가로 preview로 표시되고 지도와 운임표가 회전 없이 정상 배치됐다.
- 두 패널 모두 실제 프린터로 전송하지 않고 `취소`했다.
- mixed page는 실제 저장소 sample이 없어 synthetic exact geometry, orientation 미강제와 PDFKit auto-rotate test로 확인했다.

PDF 저장과 인쇄는 모두 `RhwpStudioPagePDFRenderer`를 소유하는 `RhwpStudioPDFExportController`와 `RhwpStudioPrintController` 경로를 사용한다. 내부 `PDF로 저장…`은 HostBridge에서 native `file:export-pdf`로 canonicalize되고 toolbar도 같은 command를 실행한다.

## 본문 변경 정도 / 본문 무손실 여부

- production renderer, PDF export/print controller, main editor, Quick Look/Thumbnail, bundled `rhwp-studio`와 `rhwp` core는 수정하지 않았다.
- 기존 합성 SVG helper에 작은 blue raster sentinel만 추가했으며 기존 text sentinel과 white background를 유지했다.
- 실제 PDF smoke 중 앱의 현재 파일명과 page count가 유지됐고 저장/인쇄 뒤 source 문서에 쓰지 않았다.
- smoke 전후 원본과 복사본의 크기, SHA-256과 수정 시각이 동일했다.

| fixture | 크기 | SHA-256 | 수정 시각 epoch |
|---|---:|---|---:|
| `samples/basic/KTX.hwp` | 66,048 bytes | `6c1a027d67b33c03f469b56548b4c7d6bca36b1c1190c7cc5eac88e35c403cf1` | `1777080928` |
| `samples/hwp-multi-001.hwp` | 492,032 bytes | `cb810b94394d8116de0aff1be70d5c63f381090a55050c77f02d4ba67e89523e` | `1777080928` |
| `samples/hwpx/hwpx-01.hwpx` | 484,352 bytes | `e17464a1514e3d83391d32a5db30f662f3d0db4b7c61bbaacf4450a729f70f20` | `1777080929` |

각 복사본도 대응 원본과 같은 크기, SHA-256과 수정 시각을 유지했다. 별도 `/Users/melee/Documents/projects/forks/rhwp` 작업트리에는 쓰지 않았다.

## 검증 결과

### 구현계획 Stage 4 검증

1. `xcodegen generate`: 통과
   - project 생성 후 의도하지 않은 tracked project 변경이 없다.
2. 전체 HostAppTests: 통과
   - `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task460/stage4-tests CODE_SIGNING_ALLOWED=NO test`
   - 126 tests, 0 failures, `** TEST SUCCEEDED **`
3. HostApp Debug 빌드: 통과
   - `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task460/stage4-build CODE_SIGNING_ALLOWED=NO build`
   - `** BUILD SUCCEEDED **`
4. built app asset 검증: 통과
   - `scripts/verify-rhwp-studio-assets.sh build.noindex/task460/stage4-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
   - `OK: rhwp-studio assets verified`
5. `pdfinfo -box`: 통과
   - KTX 1 page `1123 × 794 pt`
   - HWP/HWPX 각 9 page, 모든 page `794 × 1123 pt`
6. `pdftotext -layout`: 통과
   - KTX 6,875 bytes, HWP 24,557 bytes, HWPX 23,237 bytes의 text layer를 추출했다.
   - `KTX`, `노선도`, `운임`, `보도자료`, 해외직접투자 관련 한글·숫자 본문이 검색됐다.
7. page raster/thumbnail: 통과
   - 96 DPI로 KTX 1 page와 HWP/HWPX 각 9 page를 PNG로 렌더했다.
   - 모든 frame의 luminance 범위가 `YMIN=16`, `YMAX=235`를 포함해 nonblank였다.
   - 대표 첫/마지막 page를 시각 검사해 image, 표, 강조 배경, 본문과 page 번호가 정상임을 확인했다.
8. 기준선 및 메뉴/toolbar 비교: 통과
   - KTX 메뉴/toolbar의 추출 text와 raster가 byte 단위로 동일했다.
   - PR #458 기준 KTX 1 page와 HWP 9 page의 text/raster가 새 결과와 동일했다.
9. 원본/복사본/output SHA-256: 통과
   - 원본과 복사본 hash·mtime은 smoke 전후 동일했다.
   - output SHA-256은 KTX 메뉴 `aeb3acbf78c6990bc1dd323f229c5318fb9218665d518b5e5243fb245c76bf25`, KTX toolbar `171d20ebd5a46066ae64bc2c4d54bddfd6506e70cc5afe048859264cef7d4aa1`, HWP `c6f531ea920085ac5c99a2cd1de1739346a136222f9dd0014782859347568d7a`, HWPX `45f62771af992555ab224503c07398da3b9a30aa4b078e0d0eb21d5daa60be2e`다.
10. 실제 PDF 저장과 인쇄 패널 수동 smoke: 통과
    - KTX 가로와 HWPX 9 page 세로 preview를 확인하고 취소했다.
11. 공유 Swift 코드 플랫폼 경계 검사: 통과
    - `./scripts/check-no-appkit.sh`
    - `OK: shared Swift code has no AppKit/UIKit dependencies`
12. `git diff --check`: 통과

WebKit test process의 RunningBoard, pasteboard와 linkd 관련 sandbox 진단은 출력됐지만 전체 126 tests, PDF 생성과 실제 앱 smoke 결과는 정상 통과했다.

## 잔여 위험

- 실제 앱에서 열 수 있는 세로/가로 혼합 page sample이 저장소에 없어 mixed 인쇄 패널은 자동 test의 exact media box, orientation 미강제와 PDFKit auto-rotate로 검증했다. 실제 혼합 HWP/HWPX sample이 추가되면 패널 smoke fixture로 확장할 수 있다.
- 자동·수동 검증은 현재 개발 호스트의 macOS 26.5.2 WebKit과 인쇄 패널에서 수행됐다. deployment target macOS 12의 실제 장비 UI 검증은 별도 환경이 필요하다.
- PDF 파일 SHA-256에는 Quartz 생성 시각 metadata가 반영되므로 본문 동등성 판단에는 geometry, extracted text와 page raster를 사용해야 한다.
- HWPX smoke는 편집하지 않은 원본 복사본 기준이다. 현재 editor 편집 반영과 디스크 원본 무손실은 PR #458 Stage 4에서 별도 검증됐으며 이번 hardening은 해당 bridge/controller 경로를 변경하지 않았다.

## 다음 단계 영향

Stage 5에서는 지금까지 확인한 SVG trust boundary를 architecture 문서에 반영하고 전체 타스크 범위를 clean 환경에서 최종 검증한다.

- content JavaScript 비활성, default client metrics, CSP와 제한된 data image 허용을 문서화한다.
- 최초 `about:blank` main-frame 1회 외 navigation 거부와 non-persistent data store 경계를 기록한다.
- PDF export와 print controller가 같은 hardened renderer를 사용하는 구조를 코드·문서와 대조한다.
- clean HostAppTests, HostApp build, built asset와 targeted 보안 tests를 재실행한다.
- 전체 변경이 Issue #460 범위에 한정됐는지 `devel...HEAD` 기준으로 확인한다.

Stage 4에서는 보안 hardening으로 인한 정상 문서 PDF·인쇄 회귀가 관측되지 않았으므로 Stage 5에 production 보완 작업을 이관하지 않는다.

## 승인 요청

Stage 4 PDF·인쇄 보안 회귀 검증 결과를 검토하고 Stage 5 SVG trust boundary 문서화와 최종 검증 진입 승인을 요청한다.
