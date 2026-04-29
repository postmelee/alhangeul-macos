# Issue #84 Stage 2 완료 보고서

## 단계 목적

Stage 1 변경이 HostApp compile/link와 기존 render smoke 경로를 깨지 않았는지 확인한다.

## 검증 사전 준비

분리 worktree `/tmp/rhwp-mac-task84`에는 git ignore 대상인 `Frameworks/` 산출물이 자동으로 포함되지 않았다. 기존 메인 worktree의 로컬 `Frameworks/` 산출물을 복사해 Xcode build와 render debug script가 `Rhwp.xcframework`, modulemap, `librhwp.a`를 찾을 수 있게 했다.

해당 산출물은 `.gitignore` 대상이며 커밋에는 포함하지 않았다.

## 검증 결과

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 통과

- `** BUILD SUCCEEDED **`
- CoreSimulatorService 관련 경고와 provisioning profile 경고가 출력됐지만 macOS Debug build는 성공했다.
- 산출물 위치: `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app`

### 기본 render smoke

```bash
./scripts/validate-stage3-render.sh
```

결과: 통과

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

### 대표 다중 페이지 HWP render debug

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-viewer-first-page-task84 --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp
```

결과: 통과

```text
OK hwp-multi-001.hwp: page=1 renderTreeJSON=/tmp/rhwp-viewer-first-page-task84/hwp-multi-001-page1-render-tree.json coreSVG=/tmp/rhwp-viewer-first-page-task84/hwp-multi-001-page1-core.svg nativePNG=/tmp/rhwp-viewer-first-page-task84/hwp-multi-001-page1-native.png
OK 20250130-hongbo.hwp: page=1 renderTreeJSON=/tmp/rhwp-viewer-first-page-task84/20250130-hongbo-page1-render-tree.json coreSVG=/tmp/rhwp-viewer-first-page-task84/20250130-hongbo-page1-core.svg nativePNG=/tmp/rhwp-viewer-first-page-task84/20250130-hongbo-page1-native.png
```

요약 지표:

| 파일 | PageCount | RenderTreeJSONBytes | CoreSVGBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|-----------|---------------------|--------------|----------------------|----------|------------|---------------------|
| `hwp-multi-001.hwp` | 9 | 468702 | 300489 | 142561 | 277 | 113 | 0 |
| `20250130-hongbo.hwp` | 4 | 92327 | 191701 | 77596 | 58 | 33 | 0 |

`qlmanage` rasterize는 sandbox 실행 환경에서 실패해 pixel diff는 생성되지 않았다. render tree, core SVG, native PNG 생성 자체는 성공했다.

## git 상태 확인

검증 산출물은 `.gitignore` 대상이다.

- `Frameworks/`
- `build.noindex/`
- `output/`

검증 후 `git status --short --branch`는 Stage 2 보고서 추가 전 기준으로 clean이었다.

## 결론

Stage 1의 즉시 unload 제거 변경은 HostApp build와 기존 render smoke 경로를 깨지 않았다. 대표 다중 페이지 `.hwp` 두 개 모두 page 1 render tree, core SVG, native PNG가 정상 생성됐다.

## 다음 단계

Stage 3에서 최종 보고서와 오늘할일 완료 상태를 정리한다.
