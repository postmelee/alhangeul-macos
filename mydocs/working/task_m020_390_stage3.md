# Task M020 #390 Stage 3 완료보고서

## 단계 목적

`rhwp v0.7.17` bundled `rhwp-studio` reference 대비 CoreGraphics default와 Skia opt-in native renderer의 visual diff를 같은 샘플 세트로 재측정한다. 이번 단계는 visual direction, `MeanRGBDelta`, `NativeMs`, reference capture failure 여부를 분리해 기록했다.

## 산출물

| 경로 | 내용 |
|------|------|
| `build.noindex/task390-visual-cg/summary.md` | CoreGraphics policy visual diff summary |
| `build.noindex/task390-visual-cg/studio/` | CoreGraphics 비교용 rhwp-studio reference PNG/metadata |
| `build.noindex/task390-visual-cg/native/` | CoreGraphics native renderer PNG/metadata |
| `build.noindex/task390-visual-cg/diff/` | CoreGraphics diff PNG |
| `build.noindex/task390-visual-skia/summary.md` | Skia opt-in policy visual diff summary |
| `build.noindex/task390-visual-skia/studio/` | Skia 비교용 rhwp-studio reference PNG/metadata |
| `build.noindex/task390-visual-skia/native/` | Skia native renderer PNG/metadata |
| `build.noindex/task390-visual-skia/diff/` | Skia diff PNG |
| `mydocs/working/task_m020_390_stage3.md` | Stage 3 측정 결과 보고 |
| `mydocs/orders/20260629.md` | #390 비고를 `Stage 3 완료보고서 승인 대기`로 갱신 |

`build.noindex/` 산출물은 로컬 측정 결과이며 커밋 대상이 아니다.

## 실행 특이사항

처음 sandbox 내부에서 CoreGraphics 명령을 실행했을 때 5개 샘플 모두 reference readiness에서 실패했다.

```text
FAIL ... [phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
Could not create a 'com.apple.gputools.service' sandbox extension
Could not create a 'com.apple.coreservices.launchservicesd' sandbox extension
Could not create a 'com.apple.webinspector' sandbox extension
```

동일 명령을 sandbox 밖에서 재실행하자 CoreGraphics와 Skia opt-in 모두 통과했다. 따라서 첫 실패는 renderer 회귀가 아니라 WebKit/AppKit 실행 환경 제약으로 분리한다.

## CoreGraphics visual diff

실행 명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task390-visual-cg --page 1 \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과:

| 샘플 | Status | StudioCapture | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | NativeBackend | NativeMs |
|------|--------|---------------|----------------|--------------|-------------|------------|---------------|----------|
| `request.hwp` | OK | domComposite | 17.6908% | 10.6210 | 255 | `73,77 1060x1436` | coreGraphics | 1159.8 |
| `KTX.hwp` | OK | domComposite | 30.8921% | 13.4569 | 255 | `30,45 2185x1497` | coreGraphics | 58.7 |
| `복학원서.hwp` | OK | webViewSnapshot | 99.5953% | 214.8923 | 241 | `0,0 1588x2246` | coreGraphics | 43.1 |
| `hwp-multi-001.hwp` | OK | domComposite | 14.1976% | 15.0430 | 255 | `121,159 1345x1981` | coreGraphics | 32.7 |
| `hwpx-01.hwpx` | OK | domComposite | 14.0216% | 15.0624 | 255 | `121,159 1345x1981` | coreGraphics | 27.1 |

## Skia opt-in visual diff

실행 명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task390-visual-skia --page 1 --policy skiaOptIn \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과:

| 샘플 | Status | StudioCapture | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | NativeBackend | NativeMs |
|------|--------|---------------|----------------|--------------|-------------|------------|---------------|----------|
| `request.hwp` | OK | domComposite | 11.6265% | 8.9443 | 255 | `73,76 987x1437` | skia | 55.7 |
| `KTX.hwp` | OK | domComposite | 46.3795% | 20.9833 | 255 | `30,45 2185x1497` | skia | 57.4 |
| `복학원서.hwp` | OK | webViewSnapshot | 99.3883% | 214.3673 | 247 | `0,0 1588x2246` | skia | 68.2 |
| `hwp-multi-001.hwp` | OK | domComposite | 13.9298% | 13.0405 | 255 | `121,159 1345x1982` | skia | 62.5 |
| `hwpx-01.hwpx` | OK | domComposite | 13.8212% | 12.8409 | 255 | `121,159 1345x1982` | skia | 58.0 |

## #259 visual 기준 대비

| 샘플 | #259 CG changed | #259 Skia changed | #390 CG changed | #390 Skia changed | #390 Skia-CG delta | 방향 |
|------|-----------------|-------------------|-----------------|-------------------|---------------------|------|
| `request.hwp` | 17.8542% | 12.8683% | 17.6908% | 11.6265% | -6.0643pp | Skia visual 우위 유지, `NativeMs`는 5460.6ms에서 55.7ms로 크게 개선 |
| `KTX.hwp` | 31.1362% | 47.1389% | 30.8921% | 46.3795% | +15.4874pp | Skia visual regression 유지, Stage 2 latency 개선만으로 default 판단 불가 |
| `복학원서.hwp` | 32.0188% | 6.4738% | 99.5953% | 99.3883% | -0.2070pp | reference capture에 로컬 글꼴 감지 overlay가 들어가 이번 visual 판단값은 무효 |
| `hwp-multi-001.hwp` | 14.8327% | 14.3340% | 14.1976% | 13.9298% | -0.2678pp | visual 차이는 유사하나 Skia `NativeMs`는 62.5ms로 CG 32.7ms보다 느림 |
| `hwpx-01.hwpx` | 15.0285% | 14.6452% | 14.0216% | 13.8212% | -0.2004pp | visual 차이는 유사하나 Skia `NativeMs`는 58.0ms로 CG 27.1ms보다 느림 |

## 샘플별 해석

- `request.hwp`: #259와 같이 Skia가 visual diff에서 유리하다. #259의 Skia `NativeMs` 5초대 문제는 이번 측정에서 재현되지 않았고, Stage 2 smoke와 Stage 3 visual diff 모두 Skia가 빠르게 측정됐다.
- `KTX.hwp`: #259와 같이 Skia visual regression이 유지된다. 이번 `NativeMs`는 CG와 Skia가 비슷하지만, changed percent와 mean RGB delta 모두 Skia가 불리하므로 default 전환 blocker로 남긴다.
- `복학원서.hwp`: rhwp-studio reference PNG에 `로컬 글꼴 감지` overlay가 포함되어 CG/Skia 모두 99%대 changed가 됐다. 이번 숫자는 renderer 품질 비교에 사용하지 않고, reference capture contamination으로 분리한다.
- `hwp-multi-001.hwp`, `hwpx-01.hwpx`: Skia changed percent와 mean RGB delta가 CG보다 약간 낮지만, `NativeMs`는 CG보다 느리다. Stage 2의 다중 PDF smoke 결과와 같이 Skia default 전환 근거로는 부족하다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 visual diff 측정 실행, 측정 보고서 작성, 오늘할일 비고 갱신만 수행했다. 제품 Swift/Rust source와 renderer 정책은 수정하지 않았다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| CoreGraphics visual diff harness | sandbox 내부 첫 실행은 readiness timeout으로 실패, sandbox 밖 재실행 통과 |
| Skia opt-in visual diff harness | sandbox 밖 실행 통과 |
| Stage 3 `rg` | 통과: `OK`, `ChangedPercent`, `MeanRGBDelta`, `NativeBackend`, `NativeMs`, readiness failure 기록 확인 |
| `git diff --check` | 통과 |

대표 통과 출력:

```text
OK request.hwp: studioPNG=.../task390-visual-cg/studio/request.hwp-page1-studio.png nativePNG=.../task390-visual-cg/native/request.hwp-page1-native.png diffPNG=.../task390-visual-cg/diff/request.hwp-page1-diff.png
OK KTX.hwp: studioPNG=.../task390-visual-cg/studio/KTX.hwp-page1-studio.png nativePNG=.../task390-visual-cg/native/KTX.hwp-page1-native.png diffPNG=.../task390-visual-cg/diff/KTX.hwp-page1-diff.png
OK request.hwp: studioPNG=.../task390-visual-skia/studio/request.hwp-page1-studio.png nativePNG=.../task390-visual-skia/native/request.hwp-page1-native.png diffPNG=.../task390-visual-skia/diff/request.hwp-page1-diff.png
OK KTX.hwp: studioPNG=.../task390-visual-skia/studio/KTX.hwp-page1-studio.png nativePNG=.../task390-visual-skia/native/KTX.hwp-page1-native.png diffPNG=.../task390-visual-skia/diff/KTX.hwp-page1-diff.png
```

## 잔여 위험

- visual diff harness는 WKWebView를 사용하므로 managed sandbox 내부에서는 readiness timeout이 날 수 있다. Stage 4 이후 반복 측정이 필요하면 sandbox 밖 실행 조건을 명시해야 한다.
- `복학원서.hwp` reference capture가 로컬 글꼴 감지 overlay로 오염됐다. 이 샘플은 Stage 4 readiness 판단에서 visual diff 수치 대신 reference capture issue로 분리해야 한다.
- `KTX.hwp`는 Stage 2 latency가 개선됐지만 Stage 3 visual regression이 유지된다.
- 다중 page 샘플은 visual diff page 1만 비교했다. Stage 4의 readiness 판단은 Stage 2 Quick Look PDF smoke와 함께 해석해야 한다.

## 다음 단계 영향

Stage 4에서는 Stage 2 smoke와 Stage 3 visual diff를 종합해 surface별 readiness 판단을 정리한다. 현재 근거상 Quick Look/Thumbnail default Skia 전환은 `KTX.hwp` visual regression과 `복학원서.hwp` reference capture contamination 때문에 보류 쪽으로 정리될 가능성이 높다.

## 승인 요청

Stage 3 결과에 따라 Stage 4 `package/build gate와 readiness 판단 정리`로 진행해도 되는지 승인 요청한다.
