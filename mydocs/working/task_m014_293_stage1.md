# Task M014 #293 Stage 1 보고서 - overlay capture decision 재현

## 단계 목적

`samples/복학원서.hwp`에서 `rhwp-studio` reference PNG가 overlay DOM을 누락하는 현재 상태를 재현하고, harness의 capture decision이 `canvasDataURL`로 가는 조건과 metadata를 정리했다.

이번 단계에서는 production source와 harness script를 수정하지 않았다.

## 산출물

| 구분 | 경로 | 요약 |
|------|------|------|
| Stage 보고서 | `mydocs/working/task_m014_293_stage1.md` | 현행 capture decision, baseline metadata, Stage 2 보정 범위 정리 |
| baseline summary | `build.noindex/task293-stage1-baseline/summary.md` | `복학원서.hwp`, `request.hwp` baseline visual diff 결과 |
| baseline metadata | `build.noindex/task293-stage1-baseline/studio/*-studio.json` | capture mode, overlay count, rect, sample pixel metadata |
| baseline PNG | `build.noindex/task293-stage1-baseline/studio/*-studio.png` | 현행 studio reference PNG |
| sample scan summary | `build.noindex/task293-stage1-sample-scan/summary.md` | overlayCount 0 회귀 기준 후보 확인 |

`build.noindex/`, `Frameworks/`, `RustBridge/target/`는 로컬 검증 산출물이며 커밋하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

- 소스와 script 본문 변경 없음.
- 문서 신규 추가만 수행.
- `Frameworks/` 산출물은 `./scripts/build-rust-macos.sh`로 생성했지만 ignored build artifact로 유지한다.

## 검증 결과

### rhwp-studio asset 검증

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac-task293/Sources/HostApp/Resources/rhwp-studio
```

분리 worktree에는 `Frameworks/universal/librhwp.a`가 없어서 최초 harness 실행은 다음 오류로 중단됐다.

```text
ERROR: missing /Users/melee/Documents/projects/rhwp-mac-task293/Frameworks/universal/librhwp.a
Run: /Users/melee/Documents/projects/rhwp-mac-task293/scripts/build-rust-macos.sh
```

표준 스크립트로 local Frameworks 산출물을 생성했다.

```text
Architectures in the fat file: /Users/melee/Documents/projects/rhwp-mac-task293/Frameworks/universal/librhwp.a are: x86_64 arm64
Done: /Users/melee/Documents/projects/rhwp-mac-task293/Frameworks/Rhwp.xcframework
194M    /Users/melee/Documents/projects/rhwp-mac-task293/Frameworks/universal/librhwp.a
194M    /Users/melee/Documents/projects/rhwp-mac-task293/Frameworks/Rhwp.xcframework
```

### baseline harness

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage1-baseline --page 1 \
  samples/복학원서.hwp samples/basic/request.hwp
```

summary 결과:

| File | Status | StudioSize | ChangedPixels | ChangedPercent | MeanRGBDelta | StudioCapture |
|------|--------|------------|---------------|----------------|--------------|---------------|
| `복학원서.hwp` | OK | `1587x2245` | `1141965/3562815` | `32.0523%` | `42.2623` | `canvasDataURL` |
| `request.hwp` | OK | `1133x1587` | `321031/1798071` | `17.8542%` | `11.0716` | `canvasDataURL` |

`복학원서.hwp` studio metadata:

| 항목 | 값 |
|------|----|
| `captureMode` | `canvasDataURL` |
| `overlayIncluded` | `false` |
| `overlayCount` | `5` |
| `usedOverlayUnion` | `true` |
| `canvasSampleNonWhitePixels` | `1859 / 44250` |
| `snapshotSampleNonWhitePixels` | `44250 / 44250` |
| `canvasRect` | `x=20.09375, y=10, width=793.5, height=1122.5` |
| `rect` | `x=20.09375, y=10, width=793.5, height=1122.5` |
| PNG size | `1587x2245` |

핵심 재현 결과:

- `overlayCount=5`, `usedOverlayUnion=true`가 기록되어 overlay DOM 존재 감지는 이미 되고 있다.
- 그런데 `captureMode=canvasDataURL`, `overlayIncluded=false`라서 최종 PNG는 target canvas export 결과다.
- canvas `toDataURL()`은 DOM overlay layer를 포함할 수 없으므로, 현재 생성된 `복학원서.hwp` studio reference PNG는 좌상단 로고와 중앙 BehindText 워터마크를 포함하지 않는 경로로 생성됐다고 판단한다.

### overlayCount 0 기준 후보 확인

`request.hwp`도 현행 detector 기준으로 `overlayCount=1`, `usedOverlayUnion=true`가 나와 overlay 없는 회귀 기준으로 쓰기 어렵다. Stage 1에서 추가 sample scan을 실행했다.

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage1-sample-scan --page 1 \
  samples/hwpx/hwpx-01.hwpx samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

sample scan 결과:

| File | Status | StudioCapture | overlayCount | usedOverlayUnion | overlayIncluded |
|------|--------|---------------|--------------|------------------|-----------------|
| `hwpx-01.hwpx` | OK | `canvasDataURL` | `1` | `true` | `false` |
| `tac-img-02.hwp` | OK | `canvasDataURL` | `0` | `false` | `false` |
| `tac-img-02.hwpx` | OK | `canvasDataURL` | `1` | `true` | `false` |
| `hwp-img-001.hwp` | OK | `canvasDataURL` | `1` | `true` | `false` |
| `img-start-001.hwp` | OK | `canvasDataURL` | `1` | `true` | `false` |

Stage 2의 canvas-only 회귀 기준은 `request.hwp`가 아니라 `samples/tac-img-02.hwp`로 잡는 것이 더 정확하다.

### capture decision 원인

현재 `StudioReferenceRenderer.capture`의 decision은 다음 순서다.

```swift
if pageState.canvasSampleNonWhitePixels > 0 {
    png = try exportCanvasPNG(pageNumber: pageNumber)
    if let snapshotPNG = try? captureSnapshotPNG(rect: snapshotRectMetadata.cgRect) {
        snapshotSampleNonWhitePixels = snapshotPNG.sampleNonWhitePixels
        snapshotSamplePixels = snapshotPNG.samplePixels
    }
} else {
    png = try captureSnapshotPNG(rect: snapshotRectMetadata.cgRect)
    captureMode = "webViewSnapshot"
    overlayIncluded = true
    snapshotSampleNonWhitePixels = png.sampleNonWhitePixels
    snapshotSamplePixels = png.samplePixels
}
```

따라서 overlay DOM이 있어도 canvas에 non-white pixel이 있으면 canvas export가 우선된다. `pageStateScript`는 overlay DOM을 세고 `usedOverlayUnion`을 설정하지만, 그 값이 capture decision에 사용되지 않는다.

### 명령 검증

```text
git diff --check
```

통과했다.

## 잔여 위험

- 현재 overlay detector는 여러 일반 sample에서 `overlayCount=1`을 기록한다. Stage 2에서 `overlayCount > 0`만으로 snapshot을 강제하면 생각보다 많은 sample이 snapshot path로 바뀔 수 있다.
- `request.hwp`, `hwpx-01.hwpx`, `tac-img-02.hwpx`, `hwp-img-001.hwp`, `img-start-001.hwp`의 `overlayCount=1`이 실제 overlay인지, page wrapper/DOM artifact 과검출인지 Stage 2에서 selector 또는 classification을 점검해야 한다.
- `snapshotSampleNonWhitePixels`가 `snapshotSamplePixels`와 같은 값으로 기록되는 sample이 많다. snapshot sampling이 배경/투명/white 판단과 다른 좌표계 영향을 받는지 Stage 2에서 해석을 조심해야 한다.
- WebView snapshot은 viewport와 scroll alignment에 민감하므로, Stage 2에서 snapshot 실패를 canvas fallback으로 숨기지 않아야 한다.

## 다음 단계 영향

Stage 2 최소 변경 범위는 다음으로 확정한다.

1. `pageState.usedOverlayUnion == true` 또는 의미 있는 overlay classification이 확인된 경우 canvas export보다 WebView snapshot을 우선한다.
2. `samples/tac-img-02.hwp`는 `overlayCount=0`, `usedOverlayUnion=false` 기준으로 canvas-only path 유지 여부를 검증한다.
3. `request.hwp` 등 `overlayCount=1` sample은 과검출 가능성이 있으므로, 단순 count 기준 변경이 과도하게 snapshot을 선택하는지 별도 관찰한다.
4. `복학원서.hwp`는 Stage 2 완료 기준상 `captureMode=webViewSnapshot`, `overlayIncluded=true`가 되어야 한다.

## 승인 요청

Stage 1은 현행 capture decision 재현과 원인 inventory를 완료했다. Stage 2에서 `scripts/preview_visual_diff_harness.swift`의 overlay-aware snapshot 선택 보강으로 진행해도 되는지 승인 요청한다.
