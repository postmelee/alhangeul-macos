# Task #76 Stage 4 완료 보고서

## 단계 목적

Stage 2에서 갱신하고 Stage 3에서 ABI를 검증한 `rhwp` upstream merge commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d` 기준으로 macOS 앱 빌드와 native render use case를 검증한다. 특히 메인테이너 요청인 alhangeul-macos use case 관점에서 render tree decode, 본문 텍스트 smoke, 이미지 `bin_data_id` 기반 `rhwp_image_data` 조회가 유지되는지 확인한다.

## 산출물

- `mydocs/working/task_m010_76_stage4.md`
  - HostApp Debug build, 기본 render smoke, 이미지 샘플 smoke, Swift bridge image data 조회 검증 결과를 기록했다.
- `AlhangeulMac.xcodeproj`
  - `xcodegen generate`로 재생성되었다.
  - generated project는 저장소의 tracked source가 아니며, 원본은 `project.yml`이다.
- `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app`
  - HostApp Debug build 산출물이다.
  - `QLExtension.appex`, `ThumbnailExtension.appex`도 같은 빌드에서 컴파일되었다.
- `output/stage3-render/`
  - 기본 render smoke PNG와 검사 바이너리 산출물이다.
- `output/task76-stage4-image/`
  - 이미지 샘플 render smoke PNG와 검사 바이너리 산출물이다.

`AlhangeulMac.xcodeproj`, `build.noindex/`, `output/`, `Frameworks/`는 generated/ignored artifact로 취급하며 tracked 변경에는 포함하지 않았다. 이번 단계의 tracked 변경은 단계 보고서 추가뿐이다.

## 본문 변경 정도 / 본문 무손실 여부

본문 소스, lock, provenance, bridge 코드는 Stage 2와 Stage 3 커밋 상태를 유지했다. Stage 4는 검증 단계이므로 tracked source 변경 없이 단계 보고서만 추가했다.

## 검증 결과

```bash
xcodegen generate
```

결과: 통과.

```text
Created project at /Users/melee/Documents/projects/rhwp-mac/AlhangeulMac.xcodeproj
```

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: 통과.

```text
** BUILD SUCCEEDED ** [6.135 sec]
```

CoreSimulator/DVT/provisioning 관련 경고가 일부 출력되었지만, signing disabled Debug build는 exit code 0으로 완료했다. HostApp 빌드 과정에서 `QLExtension`과 `ThumbnailExtension` target도 함께 컴파일되었다.

```bash
./scripts/validate-stage3-render.sh
```

결과: 통과.

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=449097 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53220 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=108 hangulRuns=71 hangulScalars=1203 nonWhitePixels=159757 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/exam_kor-page1.png
```

```bash
find samples -name "*.hwp" -o -name "*.hwpx"
```

결과: 통과. 현재 repository sample은 174개다.

대표 출력:

```text
samples/re-mixed-malgun-timesnew-hancom.hwp
samples/tac-img-02.hwp
samples/복학원서.hwp
samples/lseg-06-multisize.hwp
samples/re-02-space-count-empty-hancom.hwp
samples/hwp_table_test-m.hwp
samples/multi-table-001.hwp
samples/re-align-center-hancom.hwp
samples/re-eng-words-batang-arial-empty-hancom.hwp
samples/re-font-gulimche-empty-hancom.hwp
```

이미지 샘플 render smoke:

```bash
./scripts/validate-stage3-render.sh \
  output/task76-stage4-image \
  samples/hwp-img-001.hwp \
  samples/pic-in-head-02.hwp \
  samples/pic-in-table-01.hwp \
  samples/tac-img-02.hwp
```

결과: 통과.

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=18446744073709551614 line=0 y=114.6 col_bottom=113.4 overflow=1.2px
OK hwp-img-001.hwp: page=1 size=794x1123 textRuns=66 hangulRuns=35 hangulScalars=190 nonWhitePixels=60108 png=/Users/melee/Documents/projects/rhwp-mac/output/task76-stage4-image/hwp-img-001-page1.png
OK pic-in-head-02.hwp: page=1 size=794x1123 textRuns=101 hangulRuns=57 hangulScalars=444 nonWhitePixels=102441 png=/Users/melee/Documents/projects/rhwp-mac/output/task76-stage4-image/pic-in-head-02-page1.png
OK pic-in-table-01.hwp: page=1 size=794x1123 textRuns=142 hangulRuns=73 hangulScalars=614 nonWhitePixels=465045 png=/Users/melee/Documents/projects/rhwp-mac/output/task76-stage4-image/pic-in-table-01-page1.png
OK tac-img-02.hwp: page=1 size=794x1123 textRuns=19 hangulRuns=6 hangulScalars=31 nonWhitePixels=35496 png=/Users/melee/Documents/projects/rhwp-mac/output/task76-stage4-image/tac-img-02-page1.png
```

`LAYOUT_OVERFLOW_DRAW`는 renderer diagnostic 출력이며 command exit code는 0이었다. 각 이미지 샘플은 non-white pixel smoke를 통과했다.

Swift bridge image data 조회 smoke:

```bash
swiftc -parse-as-library \
  -module-cache-path /tmp/rhwp-task76-swift-module-cache \
  -Xcc -fmodules-cache-path=/tmp/rhwp-task76-clang-module-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  /tmp/rhwp-task76-image-bin-check.swift \
  Frameworks/universal/librhwp.a \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework Security \
  -framework CoreFoundation \
  -o /tmp/rhwp-task76-image-bin-check
```

결과: 통과.

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=18446744073709551614 line=0 y=114.6 col_bottom=113.4 overflow=1.2px
OK hwp-img-001.hwp: imageNodes=4 uniqueBinDataIds=4 bytes=402558
OK pic-in-head-02.hwp: imageNodes=2 uniqueBinDataIds=2 bytes=142248
OK pic-in-table-01.hwp: imageNodes=2 uniqueBinDataIds=2 bytes=277408
OK tac-img-02.hwp: imageNodes=1 uniqueBinDataIds=1 bytes=250638
```

처음에는 Swift module cache가 사용자 홈의 `.cache` 아래에 생성되며 sandbox permission 오류가 발생했다. `/tmp` module cache를 명시한 뒤 같은 검증이 통과했다. 임시 Swift source는 검증 후 삭제했으며 tracked artifact는 남기지 않았다.

Quick Look/Thumbnail end-to-end smoke:

- 별도 `qlmanage` 기반 end-to-end smoke는 실행하지 않았다.
- 이번 단계의 빌드에서 `QLExtension`과 `ThumbnailExtension` target compile은 확인했다.
- `qlmanage` end-to-end는 installed/registered extension 상태와 LaunchServices/Quick Look cache에 의존한다. 현재 단계의 목적은 core pin 갱신 후 native bridge use case 검증이므로, 공통 render path를 사용하는 HostApp build와 script/Swift smoke를 우선 증거로 삼았다.

```bash
git diff --check
```

결과: 출력 없이 통과.

```bash
git status --short --ignored Frameworks build.noindex output
```

결과:

```text
!! Frameworks/
!! build.noindex/
!! output/
```

```bash
git status --short --branch
```

결과:

```text
## local/task76
```

## 잔여 위험

- Quick Look/Thumbnail extension의 실제 Finder/Quick Look registration smoke는 수행하지 않았다. extension target compile과 common render path 검증은 통과했지만, 설치된 app bundle과 macOS extension cache를 통한 end-to-end 동작은 별도 수동 검증 영역으로 남는다.
- 이미지 샘플의 `rhwp_image_data` 조회는 4개 대표 샘플에서 성공했다. 전체 174개 sample 전수 render는 이번 단계 범위에 포함하지 않았다.
- `LAYOUT_OVERFLOW_DRAW` diagnostic은 `hwp-img-001.hwp` 계열 검증에서 계속 출력된다. exit code와 pixel/text smoke는 통과했으므로 이번 core pin 갱신 회귀로 보지 않는다.

## 다음 단계 영향

Stage 5에서는 문서 보정과 upstream 회신용 검증 요약을 정리한다. 특히 다음 내용을 최종 보고서에 반영해야 한다.

- Demo/Preview pin은 upstream PR #385 merge commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d` 기준이다.
- Stable release tag 전환은 latest checked release `v0.7.7`에 `build_page_render_tree`가 없어 blocked 상태다.
- alhangeul-macos use case 검증 결과: HostApp Debug build 통과, 기본 render smoke 통과, 이미지 `bin_data_id` 조회 smoke 통과.
- Quick Look/Thumbnail end-to-end smoke는 설치/등록 상태 의존성 때문에 미실행으로 기록한다.

## 승인 요청

Stage 4 결과를 승인하고 Stage 5: 문서 보정과 upstream 회신용 검증 결과 정리로 진행할지 승인 요청한다.
