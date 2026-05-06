# Task M050 #123 Stage 6 보고서

## 단계 목표

- `origin/devel-webview` 기준 별도 worktree에 #123 source 변경을 선별 적용한다.
- `devel-webview`의 WKWebView HostApp 구조와 font resolver 변경을 보존한다.
- `devel`과 `devel-webview` 양쪽 브랜치의 적용 결과와 검증 상태를 최종 보고서에 넘긴다.

## 브랜치와 worktree

### devel 기준

- worktree: `/private/tmp/rhwp-mac-task123`
- branch: `local/task123`
- base: `origin/devel` (`d83253d`)
- Stage 6 시작 시 상태: `origin/devel` 대비 `ahead 8`

### devel-webview 기준

- worktree: `/private/tmp/rhwp-mac-task123-webview`
- branch: `local/task123-webview`
- base: `origin/devel-webview` (`01b439d`)
- 적용 커밋: `1ca3b9e Task #123: native renderer clip 정책 devel-webview 적용`

## devel-webview 적용 내용

`local/task123`의 전체 변경을 merge하지 않고, Stage 2-4의 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 의미 변경만 수동 반영했다.

적용한 source 정책:

- `pageBounds` 저장
- `.body` 렌더링을 `renderBody(_:node:in:)` helper로 분리
- body clip 내부 일반 pass 이후 좌우 overflow control replay pass 실행
- replay 대상은 table, shape, image, group, textBox, equation, formObject 계열로 제한
- text/header/footer/footnote/column/page 구조 계열은 replay 대상에서 제외
- `.tableCell` 렌더링을 `renderTableCell(_:node:in:)` helper로 분리
- `TableCell.clip` 우측 폭에 `4.0pt` 여유 적용

보존한 `devel-webview` 차이:

- `HwpBundledFontRegistry.ensureRegistered()`
- `resolveAppleFont(...)` 기반 TextRun/footnote marker font resolver
- WKWebView HostApp 관련 source/resource 구조
- `rhwp-studio` bundled resource

변경 파일은 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 1개로 제한됐다.

## devel-webview 검증

### 정적 검증

```bash
git diff --check
./scripts/check-no-appkit.sh
```

결과:

- `git diff --check`: 통과
- `check-no-appkit.sh`: `OK: shared Swift code has no AppKit/UIKit dependencies`

### 기본 smoke

```bash
./scripts/validate-stage3-render.sh
```

결과:

- `KTX.hwp`: `size=1123x794`, `textRuns=436`, `hangulRuns=76`, `hangulScalars=209`, `nonWhitePixels=452141`
- `request.hwp`: `size=567x794`, `textRuns=104`, `hangulRuns=36`, `hangulScalars=309`, `nonWhitePixels=67892`
- `exam_kor.hwp`: `size=1123x1588`, `textRuns=133`, `hangulRuns=86`, `hangulScalars=1368`, `nonWhitePixels=175781`
- `KTX.hwp`의 기존 core layout overflow diagnostic은 계속 출력됐다.

### 대표 smoke

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-webview-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
```

결과:

- `KTX.hwp`: 통과, `nonWhitePixels=452141`
- `request.hwp`: 통과, `nonWhitePixels=67892`
- `exam_kor.hwp`: 통과, `nonWhitePixels=175781`

### HostApp Debug build

```bash
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

- `xcodegen generate`: 통과
- `xcodebuild`: `** BUILD SUCCEEDED ** [13.213 sec]`
- `CGTreeRenderer.swift`는 `QLExtension`, `ThumbnailExtension`, `HostApp` target에서 컴파일됐다.
- CoreSimulatorService 관련 경고는 Stage 5와 같은 macOS build 환경성 경고로 분리한다.

## devel 기준 최종 상태

Stage 5 이후 추가로 `qlmanage` 기반 Core SVG raster diff의 Codex sandbox 실패 원인을 문서화했다.

- 커밋: `8cfb2b0 Task #123: qlmanage raster diff 환경 제한 문서화`
- 파일: `mydocs/manual/build_run_guide.md`
- 내용: `sandbox initialization failed: invalid data type of path filter...`는 core/native renderer 회귀가 아니라 `qlmanage` sandbox 초기화 실패로 분리

이 문서화는 다음 렌더링 작업에서 `DiffReason: qlmanage rasterize failed`를 반복 재조사하지 않기 위한 운영 기록이다.

## 산출물 정리

- devel source/docs branch: `local/task123`
- devel-webview source branch: `local/task123-webview`
- devel-webview 적용 commit: `1ca3b9e`
- ignored generated artifact:
  - `/private/tmp/rhwp-mac-task123-webview/Frameworks`
  - `/private/tmp/rhwp-mac-task123-webview/build.noindex`
  - `/private/tmp/rhwp-mac-task123-webview/output`
  - `/private/tmp/rhwp-task123-webview-smoke`

## 남은 리스크

- Body overflow replay는 좌우 overflow control만 다룬다. `samples/복학원서.hwp` 하단 표 overflow 같은 세로 layout overflow는 이번 범위가 아니다.
- replay 후보가 body column의 더 깊은 nested 구조에 있을 때는 현재 후보 탐색만으로 잡히지 않을 수 있다.
- table/group/textBox replay는 children 재렌더링을 동반하므로 특정 문서에서 z-order나 중복 drawing 리스크가 남는다.
- Core SVG raster diff는 Codex sandbox 안에서 `qlmanage` 실패가 반복될 수 있다. 필요하면 별도 SVG rasterizer fallback 작업으로 분리한다.

## 다음 절차

최종 보고서 기준으로 PR 게시 단계에 진입할 수 있다. 두 대상 브랜치가 다르므로 게시 브랜치는 기본 `publish/task123` 하나가 아니라 다음처럼 분리하는 것이 필요하다.

- `publish/task123-devel` -> `devel`
- `publish/task123-webview` -> `devel-webview`
