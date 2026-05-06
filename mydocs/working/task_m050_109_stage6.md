# Task M050 #109 Stage 6 보고서

## 단계 목적

Stage 1-5에서 보강한 Swift native renderer style 변경을 통합 검증했다. Stage 6에서는 source code를 추가 수정하지 않고, AppKit/UIKit 의존 경계, 대표 render smoke, `xcodegen generate`, HostApp Debug build를 확인했다.

## 산출물

| 파일 | line count | 변경 요약 |
| --- | ---: | --- |
| `mydocs/working/task_m050_109_stage6.md` | 신규 | 통합 검증 결과, 지원/fallback 요약, `devel-webview` 영향 범위를 기록했다. |

## 지원 항목 요약

| 단계 | 지원 항목 |
| --- | --- |
| Stage 2 | line/path dash normalization, line/connector arrow, `PathCommand.arcTo` cubic curve 변환 |
| Stage 3 | shape/line/path shadow, pattern fill type 0-5 hatch/cross 근사 |
| Stage 4 | text shadow, superscript/subscript, emphasis dot, tab leader fill type 1-11 근사 |
| Stage 5 | `TextRunNode.rotation` bbox 중심 회전, `isVertical` run 중심 정렬 |

## fallback / 후속 항목 요약

- 실제 pattern/shadow/rotation/vertical style을 포함한 저장소 샘플 fixture가 부족하다. upstream/repo 공용 fixture 생성은 별도 GitHub Issue로 등록해 진행한다.
- pattern line spacing, text emphasis dot 위치, tab leader 세부 굵기, CoreGraphics shadow blur는 WebCanvas와 픽셀 단위 완전 일치를 보장하지 않는다.
- rotated/vertical text의 underline, strike, tab leader는 제한 구현이다. 실제 fixture 확보 후 별도 조정이 필요하다.
- Swift native renderer가 vertical text layout을 새로 계산하지 않는다. upstream render tree가 문자 단위 `TextRun`과 필요한 `rotation`을 제공하는 계약을 소비한다.

## `devel-webview` 영향 판단

이번 #109 작업은 `devel`의 native viewer/Quick Look/Thumbnail 공용 renderer인 `CGTreeRenderer` 중심 변경이다. `devel-webview` HostApp 문서 화면은 WKWebView/rhwp-studio bundle을 사용하므로 이번 변경을 `devel`에만 두는 한 직접 영향은 없다.

다만 `devel-webview`로 cherry-pick/backport하면 HostApp WKWebView 화면은 그대로여도 Finder Quick Look preview와 Thumbnail extension의 native bitmap 결과가 바뀐다. 백포트가 필요하면 별도 승인 후 Quick Look/Thumbnail smoke를 수행해야 한다.

## 검증 결과

| 명령 | 결과 |
| --- | --- |
| `git status --short --branch` | Stage 6 시작 시 `/private/tmp/rhwp-mac-task109`에서 `local/task109`, clean 상태 확인 |
| `find . -name '*.xcworkspace' -o -name '*.xcodeproj' -o -name 'Package.swift'` | `AlhangeulMac.xcodeproj`, `AlhangeulMac.xcodeproj/project.xcworkspace` 확인 |
| `xcodebuild -list -project AlhangeulMac.xcodeproj` | schemes `HostApp`, `QLExtension`, `ThumbnailExtension` 확인. CoreSimulator/DerivedData 기본 로그 경로 권한 경고는 있었지만 목록 조회 성공 |
| `./scripts/check-no-appkit.sh` | 통과: shared Swift code AppKit/UIKit 직접 의존 없음 |
| `./scripts/validate-stage3-render.sh` | 통과. 기본 stage3 render smoke PNG 생성 성공 |
| `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-final-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp` | 통과. BookReview/KTX/request/exam_kor 모두 PNG 생성 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-final-bokhak samples/복학원서.hwp` | 통과. native PNG 794x1123, non-white pixels 261878, TextRuns 102, MissingHangulGlyphs 0 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-final-hongbo samples/20250130-hongbo.hwp` | 통과. native PNG 794x1123, non-white pixels 91412, TextRuns 60, MissingHangulGlyphs 0 |
| `xcodegen generate` | 통과. project 생성 후 git diff 없음 |
| `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | 통과. `AlhangeulMac.app`, `AlhangeulMacPreview.appex`, `AlhangeulMacThumbnail.appex` 생성, `** BUILD SUCCEEDED ** [14.146 sec]` |
| `git diff --check` | 통과 |

`render-debug-compare.sh`의 core SVG raster diff는 `qlmanage rasterize failed`로 생성되지 않았다. native PNG 생성, render tree/core SVG 생성, text/glyph 통계 확인은 모두 성공했다.

## 빌드 산출물

| 산출물 | 경로 |
| --- | --- |
| HostApp | `/private/tmp/rhwp-mac-task109/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app` |
| QLExtension | `/private/tmp/rhwp-mac-task109/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMacPreview.appex` |
| ThumbnailExtension | `/private/tmp/rhwp-mac-task109/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMacThumbnail.appex` |

## 잔여 위험

- 자동 검증은 renderer output과 build/link를 확인했다. Finder Quick Look/Thumbnail 실제 UI 등록 및 캐시 동작은 Stage 6 범위에서 실행하지 않았다.
- style fixture 부족으로 Stage 2-5의 일부 항목은 synthetic PNG와 code path 검증에 의존한다.
- `xcodebuild` 중 CoreSimulatorService 관련 경고가 출력됐지만 macOS Debug build는 성공했다. 시뮬레이터 서비스 경고는 이번 변경의 blocker가 아니다.

## 다음 단계 영향

Stage 6 기준으로 #109 구현과 통합 검증은 완료됐다. 다음 단계는 작업지시자 승인 후 최종 보고서 작성, 오늘할일 완료 처리, 최종 커밋, `publish/task109` 게시와 `devel` 대상 draft PR 준비 절차다.

## 승인 요청

Stage 6 통합 검증과 결과 정리를 완료했다. 다음 단계로 최종 보고서 작성 및 PR 게시 준비 절차를 진행하려면 작업지시자 승인이 필요하다.
