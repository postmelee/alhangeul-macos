# Task M010 #484 Stage 3 완료 보고

## 단계 목적

공개 21쪽 HWP와 대표 HWPX를 Debug 앱에서 열어 내부 메뉴·toolbar PDF 내보내기, 일반 인쇄, 취소 경로를 통합 검증한다. 실제 문서의 한글 본문에 유효한 `/ToUnicode`가 생성되고 PDFKit·`pdftotext`·macOS 미리보기에서 선택과 검색이 가능하면서 페이지 수, 지면 크기, 수식·표·도형 배치가 유지되는지 확인한다.

## 산출물

| 파일 | 규모 | 변경 요약 |
|------|------|-----------|
| `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` | 544줄, Stage 3에서 +38/-3 | 수식용 serif/sans-serif generic stack에 한글이 섞인 경우 한글 범위만 Noto Serif/Sans KR로 연결하고, 필수 face를 명시적으로 load한 뒤 readiness를 재확인 |
| `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` | 918줄, Stage 3에서 +70 | 한글·수식 혼합 serif stack의 선택·검색·`/ToUnicode` 회귀와 generic fallback이 없는 미등록 한글 family의 typed failure 검증 추가 |
| `build.noindex/task484-stage3/` | 미커밋 smoke 산출물 | 공개 HWP/HWPX 복사본, 사용자 v0.1.10 PDF, 동일 조건 v0.1.10 재현 PDF, 메뉴·toolbar·HWPX PDF, text·raster·검사 harness 보관 |

앱 build 기준은 Stage 2 커밋 `0457756c52f5f094ee41956a79f8f799785c0c9c`에 Stage 3의 위 두 파일 변경을 적용한 상태다. 실제 fixture와 생성 PDF, PNG, text, harness는 모두 ignored `build.noindex/`에만 두며 커밋하지 않는다.

## fixture provenance와 원본 무손실

| fixture | 원본 | SHA-256 | 크기·수정 시각 |
|---------|------|---------|----------------|
| 21쪽 HWP | `/Users/melee/Documents/projects/forks/rhwp/samples/3-11월_실전_통합_2022.hwp` | `bc8bccbb954c337d813d1af96f4e3047242124c2f2939163e282634eb721accd` | 5,534,720 bytes, 2026-06-08 04:47:43 +0900 |
| 사용자 v0.1.10 PDF | `/Users/melee/Desktop/3-11월_실전_통합_2022.pdf` | `0b5d64c4611555578a70f9b78540775f43f81a2886bda4e91d12db54154acdaf` | 7,570,926 bytes, 2026-08-24 12:31:37 +0900 |
| 대표 HWPX | `samples/hwpx/2025년 2분기 해외직접투자 (최종).hwpx` | `e49c69c090fa7abe9d33971f2983839f30c3efd77068d6d24b99db93a3c2872f` | 134,836 bytes, 2026-04-25 10:35:29 +0900 |

smoke 전후 원본과 `build.noindex/task484-stage3/` 복사본의 SHA-256이 각각 일치했다. 앱에서 파일을 열고 내보내기·인쇄 미리보기·취소만 수행했으며 문서를 편집하거나 저장하지 않았다. 저장 패널에서 `cancelled-test.pdf`를 지정한 뒤 취소했을 때 partial destination이 생성되지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 공개 HWP page SVG, 수식 문자열, 표·도형·이미지와 Studio 자산은 변경하지 않았다.
- 실패했던 2쪽의 `Latin Modern Math`, `STIX Two Text/Math`, `Times New Roman`, `Times`, `serif` stack은 수식·ASCII family 순서를 유지하고 Hangul Unicode 범위에서만 앱 소유 `Noto Serif KR`을 앞에 둔다.
- `sans-serif` generic stack도 같은 방식으로 Hangul 범위에서만 `Noto Sans KR`을 사용한다.
- generic fallback이 없는 임의 family는 조용히 대체하지 않고 기존 page 단위 `fontPreparationFailed` 계약으로 종료한다.
- 사용자 PDF 생성 당시의 로컬 글꼴 감지/대체 글꼴 선택은 기록되지 않았다. 따라서 보관된 v0.1.10 빌드 16 앱에서 현재와 같은 대체 글꼴 상태로 다시 생성한 `baseline-reproduced-v0110.pdf`를 시각 기준으로 사용했다. 사용자 PDF와 재현 PDF는 1쪽 raster가 동일하지만 17쪽의 page SVG 콘텐츠 배치가 달라, 서로 다른 글꼴 감지 상태의 PDF를 수정 전후 배치 회귀로 오인하지 않도록 분리했다.
- 동일 조건 v0.1.10 재현본과 새 PDF는 21쪽의 콘텐츠·줄바꿈·수식·표·도형 배치가 일치했다. Noto와 system fallback의 glyph 외형·폭에 따른 픽셀 차이는 평균 2.1056%, 최대 4.4077%(15쪽)였으나 page content 이동, 잘림, baseline 붕괴는 발견되지 않았다.

## PDF 결과

| 결과 | SHA-256 | pages·media box | 크기 |
|------|---------|-----------------|------|
| 사용자 v0.1.10 PDF | `0b5d64c4611555578a70f9b78540775f43f81a2886bda4e91d12db54154acdaf` | 21, 794×1123 pt, rotation 0 | 7,570,926 bytes |
| 동일 조건 v0.1.10 재현본 | `5a9dd8cff58b4ff17906f594cefc97cb4b09ed8457aee2671ef1d4b5e8a38730` | 21, 794×1123 pt, rotation 0 | 7,574,379 bytes |
| toolbar HWP PDF | `c1ebd317d5d5027a125486ce002217fec76a97df075990238332b494d4a0794e` | 21, 794×1123 pt, rotation 0 | 7,540,583 bytes |
| 내부 메뉴 HWP PDF | `03b95404a58419caa911739119ad724690622fafea8f15e5a5c1223ca02b3ed0` | 21, 794×1123 pt, rotation 0 | 7,540,583 bytes |
| toolbar HWPX PDF | `1e4d6d9ce65e53a5edc1d87e880376b477e6f0fa7bf15622ce1e188e0b06fa8b` | 9, 794×1123 pt, rotation 0 | 968,865 bytes |

메뉴와 toolbar HWP PDF는 생성 시각과 subset identifier 때문에 PDF byte hash는 다르지만 `pdftotext -layout` 결과가 byte 단위로 같았다. 1·10·21쪽을 144 dpi로 렌더한 PNG hash도 경로 간 각각 일치했다.

## font resource와 선택성

`pdffonts`의 마지막 세 yes/no 열 중 `uni` 열을 집계했다.

| 결과 | font subset | `uni=yes` | `uni=no` | Noto subset / `uni=yes` | AppleSDGothicNeo subset / `uni=yes` |
|------|-------------|-----------|----------|--------------------------|-------------------------------------|
| 사용자·동일 조건 v0.1.10 | 184 | 79 | 105 | 0 / 0 | 63 / 0 |
| 새 HWP 메뉴·toolbar | 228 | 143 | 85 | 64 / 64 | 43 / 0 |
| 새 대표 HWPX | 63 | 45 | 18 | 32 / 32 | 18 / 0 |

- 새 HWP/HWPX에서 한글을 담당하는 Noto Sans/Serif KR subset은 모두 `/ToUnicode`를 가졌다.
- HWP의 21쪽 모두에서 `PDFPage.string`과 media box rectangle selection이 존재하고 두 문자열 길이가 일치했다.
- HWP PDFKit 검색 결과는 `문1` 22건, `함수` 48건, `값은` 37건, `f ( x )` 50건이었다.
- 대표 HWPX도 9쪽 모두 page string과 rectangle selection 길이가 일치했다.
- `pdftotext -layout`에서 HWP/HWPX 한글 본문이 보존됐고 메뉴·toolbar HWP text는 byte 단위로 같았다.
- macOS 미리보기 1쪽에서 text selection 도구로 `모든 항이 양수이고`를 직접 드래그 선택하고 복사했다. 복사 문자열을 미리보기 검색창에 붙여 넣었을 때 동일 문자열과 `1장의 페이지에서 발견됨`을 확인했다.
- 남은 `uni=no`는 Hangul 범위 밖의 Apple/STIX 등 system font resource다. text 기반 수식은 PDFKit·미리보기에서 가능한 범위로 선택되지만 이미지·스캔·도형 내부 문자는 text layer가 아니며 OCR은 제공하지 않는다.

## 검증 결과

| 명령/검증 | 결과 |
|-----------|------|
| `shasum -a 256 build.noindex/task484-stage3/*.{hwp,hwpx,pdf}` 확정 경로별 실행 | 통과. fixture 원본·복사본 불변과 출력 hash 기록 |
| `pdfinfo` | 통과. HWP 21쪽, HWPX 9쪽, 전부 794×1123 pt·rotation 0 |
| `pdffonts` | 통과. HWP Noto 64/64, HWPX Noto 32/32가 `uni=yes` |
| `pdftotext -layout` | 통과. 한글 본문 보존, 메뉴·toolbar text 동일 |
| `pdftoppm -png -r 144` | 통과. HWP 21쪽·HWPX 9쪽 모두 1588×2246 px·nonblank |
| 대표 raster 육안 확인 | 통과. HWP 1·10·15·17·21쪽, HWPX 1·5·9쪽에 잘림·겹침·수식/표/도형 배치 붕괴 없음 |
| 일반 인쇄 | 통과. macOS 인쇄 패널에 `21페이지 모두`, 1/21·2/21 preview와 portrait 내용 표시, 실제 출력 없이 취소 |
| 저장 취소·초기 오류 | 통과. 취소와 2쪽 font preparation error 모두 partial destination 없음 |
| `xcodebuild ... -scheme HostAppTests ... task484-stage3-tests ... test` | 통과. 150 tests, 0 failures, `TEST SUCCEEDED` |
| `RhwpStudioPagePDFRendererTests` | 통과. 18 tests, 0 failures |
| `xcodebuild ... -scheme HostApp ... task484-stage3-build ... build` | 통과. `BUILD SUCCEEDED` |
| source·built app `scripts/verify-rhwp-studio-assets.sh` | 통과 |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code의 AppKit/UIKit 직접 의존 없음 |
| `git diff --check` | 통과 |

Stage 2 앱의 최초 실파일 내보내기는 2쪽 혼합 수식 stack을 한글 family로 해석하지 못해 typed font preparation error로 중단됐다. Stage 2 계약 안의 소규모 보정으로 generic serif/sans fallback과 명시적 font load를 추가한 뒤 집중 18개와 전체 150개 테스트, 실제 21쪽 내보내기를 모두 통과했다.

## 잔여 위험

- Noto가 아닌 Apple/STIX system resource에는 `uni=no`가 남는다. 이번 범위는 한글 본문 mapping이며, 모든 수식 glyph·Hanja·기호에 대한 완전한 선택을 보장하지 않는다.
- positioned SVG text의 추출 순서는 논리 문단 순서와 다를 수 있고, viewer의 드래그 선택 경계도 PDFKit·미리보기마다 다를 수 있다.
- page별 font subset이 반복되어 새 HWP PDF에 228개 resource가 존재한다. 결과 크기는 동일 조건 v0.1.10보다 33,796 bytes 작아 실사용을 저해하는 증가는 없지만 향후 대형 문서에서는 생성 시간·메모리와 함께 관찰해야 한다.
- 사용자 v0.1.10 PDF의 생성 당시 글꼴 감지 선택을 재구성할 수 없으므로 배치 비교 기준은 동일 bundle·동일 대체 글꼴 상태로 재생성한 v0.1.10 PDF다. 사용자 PDF는 선택 불가 증상과 font dictionary 기준선으로만 유지한다.
- Stage 3 smoke 산출물은 자동 CI fixture가 아니다. deterministic Korean/math 회귀는 Stage 2 test source가 담당한다.

## 다음 단계 영향

Stage 4에서는 다음 내용을 architecture와 필요한 사용자 문서에 반영한다.

- page SVG → 격리 WebView → exact app-owned font readiness → page PDF → PDFKit merge 흐름
- PDF 전용 custom scheme, exact allowlist, CSP·navigation 경계
- `/ToUnicode`, PDFKit selection, `pdftotext`와 실제 미리보기 선택을 함께 보는 검증 기준
- 일반 인쇄와 PDF 저장의 공용 renderer ownership
- positioned SVG reading order, system font `uni=no`, 이미지·스캔·도형/OCR 제한
- 21쪽 HWP와 9쪽 HWPX의 subset·크기·선택성 측정치

그 뒤 clean derived data에서 전체 HostAppTests, HostApp Debug build, built asset, AppKit boundary와 변경 범위를 최종 검증한다.

## 승인 요청

작업지시자는 Stage 3 결과 보고 뒤 `진행해줘`라고 지시해 Stage 3 종료 보고서·단계 커밋과 Stage 4 문서화·최종 검증 진입을 승인했다. 이 보고서와 Stage 3 source/test 보정을 하나의 커밋으로 확정한 뒤 Stage 4에 진입한다.
