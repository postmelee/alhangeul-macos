# Task #95 Stage 4 완료 보고서

## 단계 목적

`rhwp v0.7.8` Stable tag 기반 Rust bridge artifact가 Swift/macOS 통합 경로에서 동작하는지 확인한다. HostApp build, no-AppKit 규칙, 기본 render smoke, 이미지 포함 샘플의 `bin_data_id` 경로, Quick Look/Thumbnail 관련 smoke를 검증한다.

## 산출물

- `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app`
  - HostApp Debug build 산출물, git tracked 대상 아님
- `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMacPreview.appex`
  - QLExtension Debug build 산출물, git tracked 대상 아님
- `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMacThumbnail.appex`
  - ThumbnailExtension Debug build 산출물, git tracked 대상 아님
- `output/stage3-render/`
  - 기본 render smoke PNG 산출물, git tracked 대상 아님
- `/tmp/rhwp-task95-v078-smoke/`
  - render tree JSON, core SVG, native PNG, summary 산출물
- `/tmp/rhwp-task95-ql/`
  - `hwp-multi-001.hwp` thumbnail PNG 산출물
- `/tmp/rhwp-task95-ql-hongbo/`
  - `20250130-hongbo.hwp` thumbnail PNG 산출물
- `mydocs/working/task_m010_95_stage4.md`
  - Stage 4 검증 결과 기록

## 본문 변경 정도 / 본문 무손실 여부

- 소스, lock, project 원본은 수정하지 않았다.
- `xcodegen generate`를 실행했지만 git diff는 발생하지 않았다.
- Stage 4의 git tracked 변경은 본 보고서 1개뿐이다.

## 검증 결과

```bash
$ ./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

```bash
$ xcodegen generate
```

결과:

```text
Created project at /Users/melee/Documents/projects/rhwp-mac/AlhangeulMac.xcodeproj
```

```bash
$ xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [6.094 sec]
```

빌드 대상 dependency graph에는 `HostApp`, `QLExtension`, `ThumbnailExtension`이 포함됐다. 빌드 중 CoreSimulatorService, provisioning profile, Xcode plist detector 관련 경고가 출력됐지만, macOS Debug build는 성공했다.

```bash
$ ./scripts/validate-stage3-render.sh
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=434 hangulRuns=75 hangulScalars=205 nonWhitePixels=410503
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53220
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=131 hangulRuns=84 hangulScalars=1336 nonWhitePixels=171049
```

```bash
$ ./scripts/render-debug-compare.sh /tmp/rhwp-task95-v078-smoke --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp samples/aift.hwp
```

결과:

```text
OK hwp-multi-001.hwp: page=1 renderTreeJSON=... nativePNG=... summary=...
OK 20250130-hongbo.hwp: page=1 renderTreeJSON=... nativePNG=... summary=...
OK aift.hwp: page=1 renderTreeJSON=... nativePNG=... summary=...
```

각 summary 핵심값:

```text
hwp-multi-001.hwp: PageCount=10, NativePNGSize=794x1123, NativeNonWhitePixels=140721, TextRuns=277, HangulRuns=113, MissingHangulGlyphs=0
20250130-hongbo.hwp: PageCount=4, NativePNGSize=794x1123, NativeNonWhitePixels=83133, TextRuns=60, HangulRuns=35, MissingHangulGlyphs=0
aift.hwp: PageCount=77, NativePNGSize=794x1123, NativeNonWhitePixels=132970, TextRuns=25, HangulRuns=15, MissingHangulGlyphs=0
```

선택적 SVG rasterize/pixel diff는 `qlmanage` sandbox 오류로 생성되지 않았다.

```text
DiffReason: qlmanage rasterize failed; sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

이는 `render_core_native_compare_guide.md`가 설명하는 선택 산출물 실패 유형이며, 필수 산출물인 render tree JSON, core SVG, native PNG, summary는 생성됐다.

이미지 node와 `bin_data_id` 확인:

```bash
$ rg --count-matches 'bin_data_id' /tmp/rhwp-task95-v078-smoke/*.json
```

결과:

```text
/tmp/rhwp-task95-v078-smoke/20250130-hongbo-page1-render-tree.json:3
/tmp/rhwp-task95-v078-smoke/hwp-multi-001-page1-render-tree.json:2
```

```bash
$ rg --count-matches 'Image' /tmp/rhwp-task95-v078-smoke/*.json
```

결과:

```text
/tmp/rhwp-task95-v078-smoke/20250130-hongbo-page1-render-tree.json:3
/tmp/rhwp-task95-v078-smoke/hwp-multi-001-page1-render-tree.json:2
```

따라서 이미지 포함 샘플에서 render tree image node와 `bin_data_id`가 유지되고, native PNG 생성 중 `rhwp_image_data` 조회 실패로 인한 중단은 없었다.

```bash
$ qlmanage -t -x -s 512 -o /tmp/rhwp-task95-ql samples/hwp-multi-001.hwp
```

일반 sandbox에서는 다음 오류로 실패했다.

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

외부 권한으로 재실행한 결과:

```text
* /Users/melee/Documents/projects/rhwp-mac/samples/hwp-multi-001.hwp produced one thumbnail
Done producing thumbnails
```

출력 확인:

```text
/tmp/rhwp-task95-ql/hwp-multi-001.hwp.png: PNG image data, 363 x 512, 8-bit/color RGBA, non-interlaced
```

```bash
$ qlmanage -t -x -s 512 -o /tmp/rhwp-task95-ql-hongbo samples/20250130-hongbo.hwp
```

외부 권한 결과:

```text
* /Users/melee/Documents/projects/rhwp-mac/samples/20250130-hongbo.hwp produced one thumbnail
Done producing thumbnails
```

출력 확인:

```text
/tmp/rhwp-task95-ql-hongbo/20250130-hongbo.hwp.png: PNG image data, 363 x 512, 8-bit/color RGBA, non-interlaced
```

Quick Look preview UI smoke:

- `qlmanage -p`는 GUI preview panel을 여는 대화형 검증이라 이 단계의 자동 검증에서는 실행하지 않았다.
- QLExtension source는 HostApp build dependency로 compile/link 됐다.
- QLExtension preview data path가 사용하는 `HwpPreviewPDFRenderer`와 `HwpPageImageRenderer`의 핵심 render path는 `render-debug-compare.sh`와 `validate-stage3-render.sh`로 검증했다.
- Finder/Quick Look 등록 검증은 signed/sealed Release package 기준이므로, `CODE_SIGNING_ALLOWED=NO` Debug 산출물로 PlugInKit 등록 smoke를 완료 판정하지 않는다.

```bash
$ find samples -name "*.hwp" -o -name "*.hwpx"
```

결과: `samples/` 아래 HWP/HWPX 샘플 목록을 확인했고, Stage 4의 대표 샘플은 계획서의 `hwp-multi-001.hwp`, `20250130-hongbo.hwp`, `aift.hwp`를 사용했다.

```bash
$ git status --short
```

결과: 보고서 작성 전까지 tracked source/project 변경은 없었다.

## 잔여 위험

- `qlmanage -p` 기반 Quick Look preview UI는 자동화하지 않았다. 실제 Finder preview panel 확인은 대화형 UI와 설치/등록 상태에 의존한다.
- `qlmanage -t` thumbnail smoke는 외부 권한에서 PNG 생성을 확인했지만, 현재 Debug build 산출물은 signed/sealed Release package가 아니므로 PlugInKit 등록 검증의 최종 대체물이 아니다.
- render-debug의 선택적 SVG rasterize/pixel diff는 `qlmanage` sandbox 오류로 생성되지 않았다. 필수 native PNG와 summary는 생성됐다.

## 다음 단계 영향

Stage 5에서 현재 기준 문서의 stale 표현을 `v0.7.8` Stable tag pin 상태로 보정한다.

- `mydocs/tech/project_architecture.md`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- 필요 시 `README.md`, `build_run_guide.md`
- 최종 보고서와 오늘할일 완료 처리

## 승인 요청

Stage 4 완료를 승인하고 Stage 5 문서 보정과 최종 결과 정리로 진행할지 승인 요청한다.
