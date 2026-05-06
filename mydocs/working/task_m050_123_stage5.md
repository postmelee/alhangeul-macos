# Task M050 #123 Stage 5 보고서

## 단계 목표

- `devel` 기준 Swift native renderer 변경이 공통 renderer 경로에서 compile/link와 smoke 검증을 통과하는지 확인한다.
- Stage 2-4 source 변경 중 `devel-webview`에 선별 적용할 범위를 확정한다.
- Stage 6에서 `devel-webview` 브랜치에 옮길 때 섞으면 안 되는 범위와 보존할 차이를 정리한다.

## 검증 대상

- 기준 브랜치: `local/task123`
- 기준 원격: `origin/devel`
- 작업 위치: `/private/tmp/rhwp-mac-task123`
- 주요 source 변경 파일: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 영향 경로:
  - HostApp native viewer
  - Quick Look preview extension
  - Thumbnail extension
  - PDF/image export에 사용하는 shared renderer 경로

## 실행 명령과 결과

### 작업트리 확인

```bash
git status --short --branch
git log --oneline origin/devel..HEAD
```

결과:

- `local/task123`은 `origin/devel` 대비 `ahead 6`
- Stage 5 시작 시 작업트리 변경 없음
- 포함 커밋:
  - `a3c8138 Task #123: 수행 계획서 작성과 오늘할일 갱신`
  - `a80397e Task #123: 구현 계획서 작성`
  - `4b0ff45 Task #123 Stage 1: body overflow 기준 조사`
  - `3335f99 Task #123 Stage 2: Body overflow replay 구조 추가`
  - `c8dc9d8 Task #123 Stage 3: control replay 대상 보강`
  - `0a14b41 Task #123 Stage 4: TableCell clip 정책 보강`

### shared Swift 경계 검증

```bash
./scripts/check-no-appkit.sh
```

결과:

- 통과
- 출력: `OK: shared Swift code has no AppKit/UIKit dependencies`

`Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존을 추가하지 않았음을 확인했다.

### 기본 smoke 검증

```bash
./scripts/validate-stage3-render.sh
```

결과:

- 통과
- 산출물:
  - `/private/tmp/rhwp-mac-task123/output/stage3-render/KTX-page1.png`
  - `/private/tmp/rhwp-mac-task123/output/stage3-render/request-page1.png`
  - `/private/tmp/rhwp-mac-task123/output/stage3-render/exam_kor-page1.png`
- 핵심 수치:
  - `KTX.hwp`: `size=1123x794`, `textRuns=436`, `hangulRuns=76`, `hangulScalars=209`, `nonWhitePixels=452179`
  - `request.hwp`: `size=567x794`, `textRuns=104`, `hangulRuns=36`, `hangulScalars=309`, `nonWhitePixels=67667`
  - `exam_kor.hwp`: `size=1123x1588`, `textRuns=133`, `hangulRuns=86`, `hangulScalars=1368`, `nonWhitePixels=182000`
- `KTX.hwp`의 기존 core layout overflow 진단은 계속 출력되었다.

### 대표 smoke 검증

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-stage5-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
```

결과:

- 통과
- 산출물:
  - `/private/tmp/rhwp-task123-stage5-smoke/KTX-page1.png`
  - `/private/tmp/rhwp-task123-stage5-smoke/request-page1.png`
  - `/private/tmp/rhwp-task123-stage5-smoke/exam_kor-page1.png`
- 핵심 수치:
  - `KTX.hwp`: `size=1123x794`, `textRuns=436`, `hangulRuns=76`, `hangulScalars=209`, `nonWhitePixels=452179`
  - `request.hwp`: `size=567x794`, `textRuns=104`, `hangulRuns=36`, `hangulScalars=309`, `nonWhitePixels=67667`
  - `exam_kor.hwp`: `size=1123x1588`, `textRuns=133`, `hangulRuns=86`, `hangulScalars=1368`, `nonWhitePixels=182000`

### 대표 render-debug 검증

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage5-bokhak samples/복학원서.hwp
```

결과:

- 통과
- 산출물:
  - RenderTree JSON: `/private/tmp/rhwp-task123-stage5-bokhak/복학원서-page1-render-tree.json`
  - Core SVG: `/private/tmp/rhwp-task123-stage5-bokhak/복학원서-page1-core.svg`
  - Native PNG: `/private/tmp/rhwp-task123-stage5-bokhak/복학원서-page1-native.png`
  - Summary: `/private/tmp/rhwp-task123-stage5-bokhak/복학원서-page1-summary.txt`
- 핵심 summary:
  - `PageSizePt`: `793.7x1122.5`
  - `RenderTreeJSONBytes`: `189498`
  - `CoreSVGBytes`: `380803`
  - `NativePNGSize`: `794x1123`
  - `NativeNonWhitePixels`: `261878`
  - `TextRuns`: `102`
  - `HangulRuns`: `25`
  - `HangulScalars`: `143`
  - `MissingHangulGlyphs`: `0`
- `qlmanage` 기반 Core SVG raster diff는 기존처럼 생성되지 않았다.
  - `DiffReason`: `qlmanage rasterize failed`
- 기존 core layout overflow 진단은 계속 출력되었다.

### Xcode project 생성

```bash
xcodegen generate
```

결과:

- 통과
- 생성 위치: `/tmp/rhwp-mac-task123/AlhangeulMac.xcodeproj`
- `project.yml` 기준으로 재생성했으며 `AlhangeulMac.xcodeproj` 직접 수정은 하지 않았다.

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

- 통과
- 최종 출력: `** BUILD SUCCEEDED ** [12.242 sec]`
- compile/link 확인 대상:
  - `HostApp`
  - `QLExtension`
  - `ThumbnailExtension`
- `CGTreeRenderer.swift`는 세 target에서 모두 컴파일되었다.
- 산출물 위치:
  - `/tmp/rhwp-mac-task123/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app`
  - `/tmp/rhwp-mac-task123/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMacPreview.appex`
  - `/tmp/rhwp-mac-task123/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMacThumbnail.appex`

빌드 로그에는 CoreSimulatorService와 사용자 로그 접근 제한 경고가 출력되었다. macOS app build 자체는 성공했으므로 환경성 경고로 분리한다.

## Stage 1-4 변경 범위 정리

`origin/devel..HEAD` 기준 변경 파일:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/orders/20260505.md`
- `mydocs/plans/task_m050_123.md`
- `mydocs/plans/task_m050_123_impl.md`
- `mydocs/working/task_m050_123_stage1.md`
- `mydocs/working/task_m050_123_stage2.md`
- `mydocs/working/task_m050_123_stage3.md`
- `mydocs/working/task_m050_123_stage4.md`

source 변경은 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 한 파일로 제한된다. Stage 5는 검증과 보고서 작성 단계이므로 source 변경을 추가하지 않았다.

## devel-webview 선별 적용 대상

Stage 6에서 `devel-webview`에 옮길 source 의미 변경은 다음 세 커밋의 `CGTreeRenderer.swift` 변경이다.

- `3335f99 Task #123 Stage 2: Body overflow replay 구조 추가`
- `c8dc9d8 Task #123 Stage 3: control replay 대상 보강`
- `0a14b41 Task #123 Stage 4: TableCell clip 정책 보강`

선별 적용 시 주의할 점:

- `devel-webview`의 `CGTreeRenderer.swift`에는 bundled font registration과 font resolver 쪽 차이가 있으므로 덮어쓰지 않는다.
- 브랜치 전체 merge로 `devel` HostApp native viewer 구조를 `devel-webview`에 섞지 않는다.
- 수동 patch 또는 제한된 cherry-pick 후 충돌이 나면 `devel-webview`의 기존 font 관련 변경을 보존한다.
- `devel-webview`에서도 Quick Look, Thumbnail, PDF export가 shared native renderer를 사용하므로 같은 renderer 검증을 다시 실행한다.

## 남은 리스크

- render-debug summary에는 body overflow replay 후보 수나 table cell clip rect 수치가 포함되어 있지 않다.
- `qlmanage` 기반 Core SVG raster diff 실패는 계속 환경성 제한으로 남아 있다.
- nested table/group/textBox replay 중복 drawing 리스크는 Stage 6의 `devel-webview` 검증에서도 다시 관찰해야 한다.

## 다음 단계

Stage 6에서 다음 작업을 수행한다.

- `/private/tmp/rhwp-mac-task123-webview` worktree 생성
- `origin/devel-webview` 기준 `local/task123-webview` 브랜치 준비
- Stage 2-4 source 변경을 `devel-webview`의 `CGTreeRenderer.swift`에 선별 적용
- `devel-webview` 기준 smoke와 HostApp Debug build 검증
- 양쪽 브랜치 최종 정리와 PR 게시 전략 확정
