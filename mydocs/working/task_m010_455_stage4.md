# Task #455 Stage 4 완료보고서

## 단계 목적

실제 WKWebView editor와 macOS native save panel에서 HWP/HWPX PDF 저장의 두 진입점, 최신 편집 상태, page geometry, text layer, 원본 불변성과 실패 복구 경로를 검증한다.

Stage 4는 제품 소스를 추가 변경하지 않고 Stage 3 구현을 실제 fixture와 Debug 앱으로 통합 검증하는 단계다.

## 검증 환경

- 브랜치: `local/task455`
- Xcode: macOS 26.5 SDK 환경
- 앱: `build.noindex/task455/stage4-build/Build/Products/Debug/Alhangeul.app`
- 테스트 DerivedData: `build.noindex/task455/stage4-tests`
- 검증용 복사본: `build.noindex/task455/stage4-fixtures`
- PDF 산출물: `build.noindex/task455/stage4-output`
- raster와 text 추출물: `build.noindex/task455/stage4-rendered`

repository fixture는 직접 열거나 수정하지 않고 동일 해시의 복사본만 앱에 열었다.

## 원본 fixture 기준선

| fixture | 크기 | SHA-256 | 수정 시각 epoch |
|---------|------|---------|-----------------|
| `samples/basic/KTX.hwp` | 66,048 bytes | `6c1a027d67b33c03f469b56548b4c7d6bca36b1c1190c7cc5eac88e35c403cf1` | `1777080928` |
| `samples/hwp-multi-001.hwp` | 492,032 bytes | `cb810b94394d8116de0aff1be70d5c63f381090a55050c77f02d4ba67e89523e` | `1777080928` |
| `samples/hwpx/hwpx-01.hwpx` | 484,352 bytes | `e17464a1514e3d83391d32a5db30f662f3d0db4b7c61bbaacf4450a729f70f20` | `1777080929` |

smoke 종료 후 원본과 복사본의 SHA-256을 다시 계산했다. 세 원본의 크기, 해시와 수정 시각은 모두 기준선과 같았고 복사본도 각 원본과 같은 해시를 유지했다.

## 실제 native PDF 저장 결과

### 단일 가로 HWP

`KTX-copy.hwp`에서 내부 `PDF로 저장…`과 HostApp toolbar `PDF로 내보내기`를 각각 실행했다.

| 진입점 | 산출물 | page count | page size | 결과 |
|--------|--------|------------|-----------|------|
| 내부 메뉴 | `ktx-menu.pdf` | 1 | `1123 × 794 pt` | 가로 방향 유지 |
| toolbar | `ktx-toolbar.pdf` | 1 | `1123 × 794 pt` | 가로 방향 유지 |

- 두 결과의 `pdftotext -layout` 출력은 byte 단위로 같았다.
- 두 결과를 96 dpi로 rasterize한 page PNG도 pixel 단위로 같았다.
- `KTX`, 노선도, 운임과 소요 시간의 한글 text layer가 추출됐다.
- 기존 인쇄 회귀에서 문제가 됐던 90도 회전이나 세로 media box는 발생하지 않았다.

PDF 파일 자체의 SHA-256은 Quartz `CreationDate`/`ModDate` metadata가 달라 서로 다르지만, page geometry, 추출 text와 raster 본문은 동일하다.

### 다중 HWP

`hwp-multi-001-copy.hwp`의 upstream editor page count는 9쪽으로 표시됐다. 내부 메뉴와 toolbar 결과도 각각 9쪽이었다.

| 진입점 | 산출물 | page count | 모든 page size | 결과 |
|--------|--------|------------|----------------|------|
| 내부 메뉴 | `hwp-multi-menu.pdf` | 9 | `794 × 1123 pt` | 통과 |
| toolbar | `hwp-multi-toolbar.pdf` | 9 | `794 × 1123 pt` | 통과 |

- 9개 page의 MediaBox/CropBox는 모두 `794 × 1123 pt`, rotation 0이었다.
- 두 결과의 추출 text는 byte 단위로 같았다.
- 두 결과의 page별 raster도 pixel 단위로 같았다.
- 9쪽 모두 nonblank bbox가 존재했고 최소 ink ratio는 `0.066785`였다.
- `보도자료`, `2024년 3분기`, `해외직접투자` 한글 text를 검색했다.

계획서에 다중 HWP fixture의 고정 page count를 미리 적지 않았으며, 이번 판정은 앱에 표시된 upstream page count 9쪽과 PDF page count 9쪽의 일치를 기준으로 했다.

### 다중 HWPX와 최신 편집 반영

`hwpx-01-copy.hwpx`의 upstream editor page count는 9쪽이었다. 내부 메뉴와 toolbar 결과도 각각 9쪽이었다.

| 진입점 | 산출물 | page count | 모든 page size | 결과 |
|--------|--------|------------|----------------|------|
| 내부 메뉴 | `hwpx-menu-edited.pdf` | 9 | `794 × 1123 pt` | 통과 |
| toolbar | `hwpx-toolbar-edited.pdf` | 9 | `794 × 1123 pt` | 통과 |

- 두 결과의 추출 text는 byte 단위로 같았다.
- 두 결과의 page별 raster도 pixel 단위로 같았다.
- 9쪽 모두 nonblank bbox가 존재했고 최소 ink ratio는 `0.066833`이었다.

current editor state 확인을 위해 복사본을 디스크에 저장하지 않은 상태에서 `TASK455_EDIT_MARKER`를 입력하고 `hwpx-edit-marker.pdf`를 추가 저장했다. 표 내부 편집 위치와 SVG text 배치 때문에 추출 text는 공백이 포함된 다음 형태로 나타났다.

```text
TS455_ … IT_ … M … TASK455_ … EDIT_ … MARKER
```

첫 입력 시 일부 marker가 반영됐고 접근성 값 입력으로 전체 marker를 다시 반영했다. 최종 PDF의 첫 page raster와 text layer가 편집 전 결과에서 달라졌으며, 디스크의 HWPX 복사본 SHA-256은 원본과 같은 상태를 유지했다. 따라서 PDF 저장이 source file 재읽기가 아니라 현재 editor의 page SVG를 사용함을 확인했다.

## PDF geometry와 visual QA

모든 대표 PDF를 `pdftoppm -png -r 96`으로 rasterize했다. PDF 검토 절차에 따라 다음 contact sheet를 생성해 전 page를 시각 확인했다.

- `contact-ktx-menu.png`: KTX 가로 page
- `contact-hwp-menu.png`: HWP 9쪽
- `contact-hwpx-marker.png`: 편집된 HWPX 9쪽

확인 결과는 다음과 같다.

- KTX는 landscape media box 안에 정상 방향으로 표시됨
- HWP/HWPX 9쪽 모두 page boundary 안에 본문이 존재함
- 빈 page, 90도 회전, media box 잘림과 전체 page 누락 없음
- 표, 이미지, 본문과 footer page number가 각 page에 유지됨
- menu/toolbar 대응 결과는 page별 pixel 비교가 모두 동일함

ink ratio와 non-white bbox는 렌더 누락을 보조 판정하는 데 사용했고, 최종 판정은 contact sheet 시각 확인과 함께 수행했다.

## text layer와 Preview 선택

`pdftotext -layout` 결과에서 다음 대표 text를 확인했다.

- KTX: `KTX`, `소요 시간`, `운임`
- HWP: `보도자료`, `2024년 3분기`, `해외직접투자`
- HWPX: `보도자료`, `2024년 1분기`, `해외직접투자`, 편집 marker

macOS Preview에서 `hwpx-edit-marker.pdf`를 직접 열었다. Preview 접근성 tree에 9개 PDF page의 한글 text node와 편집 marker가 노출됐으며, 첫 page의 `보도자료`를 실제 text selection으로 선택했다. bitmap-only PDF가 아니라 검색·선택 가능한 text layer가 유지된다.

## save panel과 실패 복구

### 취소

toolbar에서 save panel을 열고 destination name을 `cancelled.pdf`로 바꾼 뒤 취소했다.

- output 생성 0건
- 앱은 editor 화면으로 복귀
- 다음 toolbar export 재진입 성공

### 기존 파일 대치

기존 `hwpx-edit-marker.pdf`와 같은 이름으로 다시 저장했다.

- macOS 대치 확인 sheet 표시
- `대치` 후 PDF 재생성·atomic write 성공
- 결과 PDF는 9쪽으로 다시 열림

### write permission 실패

`build.noindex/task455/stage4-readonly`를 mode `0555`로 만들고 `write-failure.pdf` 저장을 시도했다.

- 사용자 오류: `PDF를 내보낼 수 없습니다: ‘stage4-readonly’ 폴더에 ‘write-failure.pdf’ 파일을 저장할 수 있는 권한이 없습니다.`
- partial `write-failure.pdf` 생성 0건
- 오류 표시가 정리된 뒤 PDF toolbar save panel 재진입 성공
- 재진입 panel 취소 후 editor 정상 유지
- 검증 종료 후 directory permission을 `0755`로 복원

이 결과로 save panel 취소, 대치, write error와 이후 `idle` 복귀를 실제 UI에서 확인했다.

## 일반 인쇄 회귀

편집된 9쪽 HWPX 상태에서 `Command+P`로 일반 인쇄 panel을 열었다.

- `9페이지 모두` 표시
- 왼쪽 preview에 `1/9페이지`, `2/9페이지`가 표시됨
- portrait page preview가 정상 방향으로 표시됨
- 취소 후 editor로 복귀

일반 인쇄와 PDF 파일 저장이 같은 SVG renderer를 공유하는 상태에서 print panel 회귀가 발생하지 않았다.

## 자동 검증 결과

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과. Xcode project diff 0건. |
| HostAppTests | 통과. 116개 테스트, 실패 0개. |
| HostApp Debug build | 통과. `CODE_SIGNING_ALLOWED=NO`, `** BUILD SUCCEEDED **`. |
| bundled rhwp-studio asset | 통과. manifest와 built asset 일치. |
| `pdfinfo -box` | 통과. KTX 1쪽 가로, HWP/HWPX 각 9쪽 세로 geometry 확인. |
| `pdftotext -layout` | 통과. 대표 한글과 current edit marker 확인. |
| page raster nonblank | 통과. 대표 PDF 전 page bbox/ink 확인. |
| menu/toolbar raster 비교 | 통과. HWP/HWPX/KTX 모든 대응 page pixel 동일. |
| macOS Preview text selection | 통과. `보도자료` 선택 성공. |
| save 취소 | 통과. output 0건과 재진입 확인. |
| existing PDF overwrite | 통과. 대치 확인 후 재생성 성공. |
| permission failure | 통과. 사용자 오류, partial output 0건, 재진입 확인. |
| 일반 인쇄 panel | 통과. 9쪽 preview와 취소 복귀 확인. |
| 원본 SHA-256/mtime | 통과. smoke 전후 동일. |
| `./scripts/check-no-appkit.sh` | 통과. |
| extension registration hygiene | 통과. 등록된 development provider 0건. |
| `git diff --check` | 통과. |

HostAppTests 최종 결과는 다음과 같다.

```text
Executed 116 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

테스트 실행 중 WebKit 보조 process의 sandbox 진단 로그가 출력됐지만 renderer/controller 테스트와 전체 suite는 정상 완료됐다.

## 변경 파일

- 신규 `mydocs/working/task_m010_455_stage4.md`
- 수정 `mydocs/orders/20260804.md`

Stage 4에서는 제품 소스, 테스트, `project.yml`, Xcode project와 bundled upstream asset을 변경하지 않았다. 모든 fixture 복사본, PDF, raster, text와 QA contact sheet는 git에서 제외되는 `build.noindex/task455/` 아래에 있다.

## 완료 기준 판단

- 내부 메뉴와 toolbar가 HWP/HWPX에서 같은 native save panel·SVG PDF 경로 사용: 충족
- menu/toolbar page count, geometry, text와 raster 일치: 충족
- 최신 editor edit가 PDF에 반영되고 source file은 변경되지 않음: 충족
- KTX landscape width > height 유지: 충족
- HWP/HWPX 다중 page count가 upstream page count와 일치: 충족
- 모든 대표 page nonblank와 visual QA: 충족
- 대표 한글 검색과 Preview text selection: 충족
- 취소, 대치, write failure와 이후 상태 복구: 충족
- 일반 인쇄 panel 회귀 없음: 충족
- 전체 tests, build, asset와 dependency boundary 검증: 충족

## 잔여 위험

- 큰 다중-page 문서는 전체 SVG 문자열을 native message와 renderer에서 보관하므로 memory/time 비용이 남는다.
- 실제 가로·세로 혼합 HWP/HWPX fixture는 이번 대표 세트에 없으며, 혼합 orientation 자체는 Stage 2 합성 SVG 자동 테스트와 일반 인쇄 정책 테스트로 유지된다.
- Quartz PDF metadata에는 export 시각이 들어가므로 같은 본문을 다시 저장해도 PDF file SHA-256은 달라진다. 본문 동등성은 geometry, extracted text와 page raster로 판정해야 한다.
- upstream SVG의 text layout 때문에 편집 marker와 일부 한글이 `pdftotext -layout`에서 시각 위치 기준 공백으로 분리될 수 있으나 Preview text node와 selection은 유지된다.

## 다음 단계 영향

Stage 5는 Stage 2~4에서 확정된 ownership을 architecture 문서에 반영한다.

- 메뉴와 save UX: HostApp
- page source: upstream `getPageSvg`
- PDF generation: 공용 `RhwpStudioPagePDFRenderer`와 `WKWebView.createPDF`
- PDF write: HostApp atomic write
- 일반 인쇄: 같은 SVG renderer를 사용하는 별도 print controller
- Quick Look/Thumbnail: 기존 render tree bitmap 경로 유지

Stage 4 실측 결과와 잔여 제한을 문서화한 뒤 최종 검증으로 진행한다.

## 승인 요청

Stage 4 `HWP/HWPX PDF 저장 통합 검증`을 완료했다. 완료보고서 승인과 Stage 5 `PDF ownership 문서와 잔여 제한 정리` 진행 승인을 요청한다.
