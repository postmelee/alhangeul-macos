# Task M015 #119 최종 보고서

## 작업 개요

- 이슈: #119 오픈 라이선스 한글 폰트 번들 및 폰트 대체 정책 도입
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `publish/task119-devel`
- 기준 브랜치: `devel`
- 핵심 변경: `rhwp-studio/fonts` WOFF2 34개를 Swift native renderer에서 process-local CoreText font로 등록하고, HWP font family alias를 bundled open-license font 우선 fallback chain으로 정리
- 주 사용자 영향: Quick Look preview / Finder thumbnail 공통 native bitmap renderer

## 완료 내용

기존 Swift native renderer는 HWP font family를 대부분 Apple 기본 폰트로 단순 치환했다. Glyph는 나오지만 원문 문서의 font metric과 분위기가 크게 달라져 #120의 text advance 보정 이후에도 Quick Look/Thumbnail 시각 결과가 흔들릴 수 있었다.

원 작업은 `devel-webview`에 이미 포함된 `rhwp-studio/fonts` WOFF2를 새 resource 중복 없이 재사용했다. 이 `devel` 대상 PR은 WebView bundle 전체를 가져오지 않고, Quick Look/Thumbnail native renderer에 필요한 동일 `rhwp-studio/fonts` 디렉터리만 HostApp resource로 포함한다.

- CoreText WOFF2 process-local registration 가능성 확인
- `HwpBundledFontRegistry` 추가
- HostApp resource와 extension parent app resource lookup 구현
- HWP font alias를 bundled font/system fallback 후보 체인으로 정리
- TextRun/footnote marker가 공통 `resolveAppleFont(..., size:)` 경로를 사용하도록 정리
- font fallback 정책과 resource provenance 문서화
- Release package 산출물 기준 PlugInKit 등록과 `qlmanage -t -x` thumbnail smoke 확인

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | WOFF2 allowlist, font directory lookup, CoreText process-local registration helper |
| `Sources/RhwpCoreBridge/FontFallback.swift` | HWP font family normalization, bundled/system fallback chain, bold/italic face 선택 정책 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | render 시작 시 font registration 보장, TextRun/marker font 선택을 공통 resolver로 통합 |
| `Sources/HostApp/Resources/rhwp-studio/fonts` | `devel` 대상에서 native renderer가 사용할 WOFF2 34개와 `FONTS.md`만 최소 resource로 추가 |
| `project.yml` | HostApp resource에 `rhwp-studio` folder reference 추가, `Sources/HostApp` 중복 포함 방지 |
| `scripts/check-no-appkit.sh` | 새 shared Swift 파일을 AppKit/UIKit 금지 검증 대상에 포함 |
| `scripts/validate-stage3-render.sh` | smoke compile source list에 `FontResourceRegistry.swift` 포함 |
| `scripts/render-debug-compare.sh` | debug compare compile source list에 `FontResourceRegistry.swift` 포함 |
| `AlhangeulMac.xcodeproj/project.pbxproj` | XcodeGen 산출물에 새 source 포함 |
| `mydocs/tech/font_fallback_strategy.md` | native renderer font fallback 정책과 resource provenance 문서화 |
| `mydocs/plans/task_m015_119.md` | 수행 계획 |
| `mydocs/plans/task_m015_119_impl.md` | Stage 1-5 구현 계획 |
| `mydocs/working/task_m015_119_stage1.md` | font asset/native 등록 가능성 조사 |
| `mydocs/working/task_m015_119_stage2.md` | 공통 font registration/resource 배치 구현 결과 |
| `mydocs/working/task_m015_119_stage3.md` | HWP font alias mapping 구현 결과 |
| `mydocs/working/task_m015_119_stage4.md` | Quick Look/Thumbnail render 검증 결과 |
| `mydocs/working/task_m015_119_stage5.md` | 최종 정리/검증 결과 |
| `mydocs/report/task_m015_119_report.md` | 최종 보고서 |
| `mydocs/orders/20260503.md` | 오늘할일 #119 완료 상태 |

`Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 직접 의존을 추가하지 않았다.

## Font 정책

`devel-webview`에서는 새 font 파일을 추가하지 않고 이미 포함된 `Sources/HostApp/Resources/rhwp-studio/fonts` WOFF2 34개를 native renderer에서도 재사용한다. `devel` 대상 PR에서는 같은 폰트 디렉터리와 `FONTS.md`만 최소 HostApp resource로 추가한다.

대표 fallback chain:

- `함초롬바탕`, `한컴바탕`, `바탕`: Noto Serif KR -> Nanum Myeongjo -> Gowun Batang -> AppleMyungjo
- `함초롬돋움`, `맑은 고딕`, `Calibri`, `Tahoma`: Pretendard -> Apple SD Gothic Neo
- `한컴돋움`, `돋움`, `굴림`: Noto Sans KR -> Pretendard -> Nanum Gothic -> Apple SD Gothic Neo
- `돋움체`, `굴림체`, `바탕체`: D2Coding -> Nanum Gothic Coding -> Courier New
- `HY바다L`, `한컴 소망 B`, `한컴 쿨재즈 B`: Cafe24/Happiness Sans 계열 -> Pretendard

Noto 계열은 파일명과 CoreText PostScript name이 달라 Stage 1에서 확인한 이름을 직접 사용했다.

```text
NotoSansKR-Regular.woff2 -> NotoSansKRThin-Regular
NotoSansKR-Bold.woff2 -> NotoSansKRThin-Bold
NotoSerifKR-Regular.woff2 -> NotoSerifKRExtraLight-Regular
NotoSerifKR-Bold.woff2 -> NotoSerifKRExtraLight-Bold
```

## 검증 요약

### 기본 smoke

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
./scripts/validate-stage3-render.sh
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452089
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67667
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=182000
```

### 대표 샘플 smoke

```text
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task119-final-smoke samples/basic/BookReview.hwp samples/복학원서.hwp samples/20250130-hongbo.hwp
OK BookReview.hwp: page=1 size=794x1123 textRuns=66 hangulRuns=28 hangulScalars=209 nonWhitePixels=386919
OK 복학원서.hwp: page=1 size=794x1123 textRuns=102 hangulRuns=25 hangulScalars=143 nonWhitePixels=261878
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=91412
```

### Debug build

```text
xcodegen generate
Created project at /tmp/rhwp-mac-task119/AlhangeulMac.xcodeproj
```

```text
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [6.009 sec]
```

### Release / Finder integration smoke

Stage 4에서 Release package 산출물을 생성해 설치본 기준으로 검증했다.

```text
ALHANGEUL_BUILD_ROOT=/private/tmp/rhwp-mac-task119/build.noindex ./scripts/package-release.sh 0.1.0-task119-stage4
** BUILD SUCCEEDED ** [19.416 sec]
ec912bcb4773c213b7fbea9a64c3ef9f9e24dd9ecf1ea027a7a63991b3bc8d52  alhangeul-macos-0.1.0-task119-stage4.zip
```

```text
pluginkit -mAvvv | rg "com\\.postmelee\\.alhangeulmac|AlhangeulMac"
+    com.postmelee.alhangeulmac.QLExtension(0.1.0)
+    com.postmelee.alhangeulmac.ThumbnailExtension(0.1.0)
```

```text
codesign --verify --deep --strict --verbose=2 "$HOME/Applications/AlhangeulMac.app"
/Users/melee/Applications/AlhangeulMac.app: valid on disk
/Users/melee/Applications/AlhangeulMac.app: satisfies its Designated Requirement
```

```text
qlmanage -t -x -s 512 -o /tmp/alhangeul-task119-thumbnail samples/20250130-hongbo.hwp
* /private/tmp/rhwp-mac-task119/samples/20250130-hongbo.hwp produced one thumbnail
```

### Before / After 이미지

PR 본문 첨부용 PNG를 로컬에 생성했다. 이미지는 저장소에 커밋하지 않았다.

```text
/private/tmp/rhwp-task119-preview-compare/BookReview-before.png
/private/tmp/rhwp-task119-preview-compare/BookReview-after.png
/private/tmp/rhwp-task119-preview-compare/20250130-hongbo-before.png
/private/tmp/rhwp-task119-preview-compare/20250130-hongbo-after.png
/private/tmp/rhwp-task119-preview-compare/BookReview-before-after.png
/private/tmp/rhwp-task119-preview-compare/20250130-hongbo-before-after.png
```

PR 본문에는 실제 이미지 업로드 후 아래 placeholder의 `UPLOAD_*` 값을 GitHub 첨부 URL로 치환한다.

```markdown
## 스크린샷

| Before | After |
|--------|-------|
| ![BookReview before](UPLOAD_BOOKREVIEW_BEFORE_PNG) | ![BookReview after](UPLOAD_BOOKREVIEW_AFTER_PNG) |
| ![20250130-hongbo before](UPLOAD_HONGBO_BEFORE_PNG) | ![20250130-hongbo after](UPLOAD_HONGBO_AFTER_PNG) |
```

## 제한 사항

- #119는 font resource registration과 fallback 정책 보강이다. 도형 shadow, arrow, dash, pattern fill, text shadow/rotation/vertical text 같은 style parity는 #109 범위다.
- `qlmanage -p` GUI preview smoke는 자동화 환경 정책상 실행하지 않았다.
- core SVG raster diff PNG는 로컬 `qlmanage` SVG rasterize 실패로 생성되지 않는 경우가 있었다. render tree JSON, native PNG, summary는 생성됐다.
- proprietary font 파일은 포함하지 않는다. 한컴/HY/Microsoft font family는 오픈 라이선스 bundled font 또는 시스템 font로 대체한다.

## 후속 #109 연결점

#109 `Swift native renderer 도형·텍스트 스타일 1차 parity 보강`은 #119 이후 바로 이어가기 좋다. #119에서 font registration/fallback 변수를 줄였으므로, #109에서는 도형 shadow, line arrow/dash/pattern, text shadow/rotation/vertical text, superscript/subscript 같은 style 누락을 더 명확히 볼 수 있다.

## 결론

Issue #119의 목표였던 오픈 라이선스 한글 폰트 재사용과 Swift native renderer font fallback 정책 도입은 완료됐다.

Quick Look/Thumbnail 공통 native renderer는 `rhwp-studio` WOFF2 자산을 CoreText에 process-local 등록하고, 주요 HWP proprietary font family를 문서화된 bundled/system fallback chain으로 해석한다. 대표 샘플 render smoke, HostApp Debug build, Release package 기반 PlugInKit/thumbnail smoke도 통과했다.
