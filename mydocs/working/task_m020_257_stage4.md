# Task M020 #257 Stage 4 보고서 - Quick Look Skia smoke 검증

## 단계 개요

- 이슈: #257 Quick Look preview에서 Skia PNG backend 적용과 다중 페이지 PDF fallback 검증
- 단계: Stage 4. Quick Look smoke와 fallback 검증
- 목표: 대표 샘플에서 Quick Look 단일 PNG와 다중 PDF 경로의 Skia opt-in 결과, fallback 결과, latency/byte 정보를 기록한다.

## 변경 내용

### Quick Look Skia policy smoke helper 추가

다음 task 전용 smoke helper를 추가했다.

- `scripts/smoke-quicklook-skia-policy.sh`
- `scripts/quicklook_skia_policy_smoke.swift`

이 helper는 같은 입력 문서에 대해 Quick Look reply 형태를 기준으로 `.coreGraphicsOnly`와 `.skiaOptIn` policy를 모두 측정한다.

측정 항목:

| 항목 | 의미 |
|---|---|
| `Reply` | 단일 page는 PNG, 다중 page는 PDF |
| `CGBackend` | CoreGraphics policy에서 backend별 page count |
| `SkiaBackend` | Skia opt-in policy에서 backend별 page count |
| `SkiaFallback` | Skia opt-in에서 fallback page count와 첫 fallback reason |
| `CGBytes` / `SkiaBytes` | 최종 reply bytes |
| `SkiaPNGBytes` | upstream Skia PNG bytes 합계 |
| `CGSeconds` / `SkiaSeconds` | helper 기준 전체 생성 시간 |

`output/task257-skia-policy/summary.txt`와 per-file detail을 생성한다. `output/`은 commit 대상이 아니다.

## Smoke 결과

### CoreGraphics baseline

실행:

```bash
./scripts/validate-stage3-render.sh output/task257-stage4 samples/basic/request.hwp samples/basic/KTX.hwp
```

결과:

| 샘플 | 결과 | page | bitmap | Hangul runs | non-white pixels |
|---|---|---:|---:|---:|---:|
| `samples/basic/request.hwp` | OK | 1 | 567x794 | 37 | 69132 |
| `samples/basic/KTX.hwp` | OK | 1 | 1123x794 | 77 | 453754 |

`KTX.hwp`에서 기존 layout overflow diagnostic이 출력됐지만 smoke는 통과했다.

### Quick Look policy smoke

실행:

```bash
./scripts/smoke-quicklook-skia-policy.sh \
  output/task257-skia-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과 요약:

| 샘플 | Reply | Pages | CG backend | Skia backend | Skia fallback | CG bytes | Skia bytes | Skia PNG bytes | CG seconds | Skia seconds |
|---|---|---:|---|---|---:|---:|---:|---:|---:|---:|
| `request.hwp` | png | 1 | cg:1 | skia:1 | 0 | 82129 | 85981 | 88793 | 1.081279 | 0.095356 |
| `KTX.hwp` | png | 1 | cg:1 | skia:1 | 0 | 555392 | 181146 | 165799 | 0.067094 | 0.073160 |
| `복학원서.hwp` | png | 1 | cg:1 | skia:1 | 0 | 233831 | 225105 | 240643 | 0.412763 | 0.062871 |
| `hwp-multi-001.hwp` | pdf | 10 | cg:10 | skia:10 | 0 | 1522638 | 1119989 | 1309516 | 0.404578 | 0.677783 |
| `hwpx-01.hwpx` | pdf | 9 | cg:9 | skia:9 | 0 | 1489442 | 1094246 | 1316036 | 0.353663 | 0.623360 |

관찰:

- 단일 page PNG 3개 모두 Skia opt-in에서 `backendUsed: .skia`, fallback 0으로 성공했다.
- 다중 page PDF 2개 모두 모든 page가 Skia backend로 성공했고 fallback 0이었다.
- 다중 page PDF는 Skia path가 CoreGraphics baseline보다 느렸다. page별 Skia PNG render/decode를 반복하기 때문에 #259에서 readiness gate 입력으로 다뤄야 한다.
- 단일 page `request.hwp`의 CoreGraphics 시간이 다른 단일 샘플보다 높게 나왔는데, helper 첫 실행/캐시 비용 가능성이 있어 절대 수치보다는 backend 성공/fallback 여부와 bytes를 우선 입력으로 본다.

산출:

- `output/task257-skia-policy/summary.txt`
- `output/task257-skia-policy/*-quicklook-skia-policy.txt`

### 기존 Quick Look PDF/SVG 비교

실행:

```bash
./scripts/compare-quicklook-pdf-renderers.sh \
  output/task257-quicklook-pdf \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과:

| 샘플 | Status | Pages | CurrentReply | NativePDFSeconds | NativePDFBytes | CoreSVGSeconds | CoreSVGBytes |
|---|---|---:|---|---:|---:|---:|---:|
| `hwp-multi-001.hwp` | OK | 10 | pdf | 1.459130 | 1522638 | 0.016468 | 3917212 |
| `hwpx-01.hwpx` | OK | 9 | pdf | 0.354921 | 1489442 | 0.014376 | 3664984 |

이 스크립트는 기본 인자 때문에 CoreGraphics PDF path를 측정한다. Skia opt-in 측정은 이번 Stage 4에서 추가한 policy smoke helper를 기준으로 기록했다.

## Build/source 검증

실행:

```bash
./scripts/check-no-appkit.sh
rg -n "smoke-quicklook-skia-policy|quicklook_skia_policy|skiaOptIn|pageDiagnostics|backendUsed|fallbackReason|SkiaOptIn" \
  scripts Sources mydocs/orders/20260521.md
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

결과:

- `check-no-appkit.sh`: 통과.
- `rg`: Skia opt-in provider path, PDF page diagnostics, smoke helper 추가를 확인했다.
- `xcodebuild QLExtension Debug`: 통과.
- `xcodebuild HostApp Debug`: 통과.
- `git diff --check`: 통과.

앞선 Stage 2/3에서 sandbox 내부 xcodebuild가 사용자 Swift/clang cache 쓰기 제한으로 실패한 이력이 있어, Stage 4 build는 sandbox 밖에서 실행했다.

## Known limitations

- Stage 4는 Debug/helper smoke 기준이다. 설치본 Quick Look UI smoke와 LaunchServices/PlugInKit 등록 검증은 별도 release/package smoke로 해석해야 한다.
- Skia fallback을 강제로 유발하는 fixture는 이번 단계에서 만들지 않았다. fallback 동작은 #256 Shared renderer contract와 code path, 그리고 이번 smoke의 fallback count 0 결과로 확인했다.
- 다중 page PDF의 Skia path는 모든 page에서 성공했지만 CoreGraphics baseline보다 느린 샘플이 있어, default 전환 판단은 #259로 넘긴다.
- upstream rhwp 새 release의 PUA/image/watermark 회귀 확인은 #278에서 처리한다.

## 다음 단계 승인 요청

Stage 5에서 최종 보고서와 오늘할일 완료 처리를 수행하고, #258/#259/#278 handoff를 정리한다.
