# Task M020 #257 Stage 2 보고서 - Quick Look PNG Skia opt-in 적용

## 단계 개요

- 이슈: #257 Quick Look preview에서 Skia PNG backend 적용과 다중 페이지 PDF fallback 검증
- 단계: Stage 2. Quick Look 단일 페이지 PNG Skia opt-in 적용
- 목표: 단일 페이지 Quick Look PNG reply가 `skiaOptIn` policy를 사용하고, 실제 backend/fallback diagnostics를 로그에 남기도록 한다.

## 변경 내용

### 단일 페이지 PNG reply policy

`Sources/QLExtension/HwpPreviewProvider.swift`의 `pngReply(_:)`에서 첫 페이지 render 호출에 `policy: .skiaOptIn`을 명시했다.

변경 후 단일 페이지 Quick Look PNG reply는 다음 순서로 동작한다.

1. `HwpPreviewPDFRenderer.load(fileURL:)`가 기존처럼 file size, page count, first page size를 검증한다.
2. `HwpPageImageRenderer.renderPage(document:pageIndex:policy: .skiaOptIn)`을 호출한다.
3. #256 Shared renderer가 Skia PNG render를 먼저 시도한다.
4. Skia 실패, 빈 PNG, PNG decode 실패 시 Shared renderer가 CoreGraphics fallback을 수행한다.
5. 최종 `HwpRenderedPage`를 기존처럼 PNG로 encode해 `QLPreviewReply`에 반환한다.

### Diagnostics logging

단일 페이지 PNG render 직후 `HwpRenderedPage.diagnostics`를 로그에 남기는 helper를 추가했다.

로그 필드:

| 필드 | 출처 |
|---|---|
| `policy` | `diagnostics.policy` |
| `backend` | `diagnostics.backendUsed` |
| `fallback` | `diagnostics.fallbackReason`, 없으면 `none` |
| `pixel` | `diagnostics.pixelSize` |
| `pngBytes` | Skia PNG bytes count, 없으면 `none` |
| `totalMs` | 전체 render/decode/fallback 시간 |
| `skiaMs` | Skia render 시간, 없으면 `none` |
| `decodeMs` | PNG decode 시간, 없으면 `none` |
| `coreMs` | CoreGraphics render 시간, 없으면 `none` |

filename은 기존 로그와 동일하게 basename만 public으로 남긴다.

## 보존한 범위

- 다중 페이지 PDF path는 Stage 2에서 변경하지 않았다.
- Quick Look text fallback classifier 흐름은 변경하지 않았다.
- file size guard, empty document, invalid page size 정책은 `HwpPreviewPDFRenderer.load`의 기존 흐름을 유지한다.
- `Sources/RhwpCoreBridge`는 변경하지 않았다.
- Finder thumbnail path는 변경하지 않았다.

## 검증

실행:

```bash
./scripts/check-no-appkit.sh
rg -n "skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs|Preview PNG" Sources/QLExtension Sources/Shared
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

결과:

- `check-no-appkit.sh`: 통과.
- `rg`: `HwpPreviewProvider.pngReply`의 `policy: .skiaOptIn`과 diagnostics 로그, #256 Shared renderer diagnostics 필드를 확인했다.
- `xcodebuild QLExtension Debug`: 최초 sandbox 실행은 Sparkle package fetch가 `Could not resolve host: github.com`으로 실패했다. 동일 명령을 네트워크 허용 재실행해 통과했다.
- `git diff --check`: 통과.

## 리스크와 후속

- 단일 페이지 PNG reply는 아직 Shared renderer의 Skia PNG를 `CGImage`로 decode한 뒤 다시 PNG encode한다. direct PNG reply 최적화는 별도 후속 후보로 남긴다.
- Skia failure를 강제로 만드는 runtime smoke는 Stage 2에서 수행하지 않았다. fallback taxonomy는 #256 Shared renderer contract에 의존한다.
- 다중 페이지 PDF의 page별 Skia opt-in 연결과 page diagnostics summary는 Stage 3에서 처리한다.

## 다음 단계 승인 요청

Stage 3에서 `HwpPreviewPDFRenderer`가 page render policy를 받을 수 있게 하고, Quick Look 다중 페이지 PDF path에 `policy: .skiaOptIn`을 연결한다.
