# Task M050 #222 Stage 4 완료보고서

## 단계 목표

사용자 추가 확인 요청에 따라 `samples/복학원서.hwp`의 좌상단 고려대학교 로고가 preview와 thumbnail 공통 native renderer에서 보이지 않는 원인을 분리하고, 같은 렌더링 경로에서 보이도록 보정한다.

## 원인 분석

좌상단 로고는 render tree에서 누락되지 않았다.

| 항목 | 값 |
|------|----|
| node id | 7 |
| 위치 | `Body > Column` |
| bbox | `x=65.4933, y=49.0133, w=77.0133, h=87.8933` |
| bin data | `bin_data_id=1` |
| text wrap | `BehindText` |
| crop | `[0, 0, 65640, 74940]` |

core SVG에는 해당 로고가 PNG data URL로 변환되어 포함되어 있었다. 반면 Swift native renderer의 `RhwpDocument.imageData(binDataId:)`가 반환하는 원본 `bin_data_id=1`은 `CGImageSource`가 직접 decode하지 못하는 PCX 데이터였다.

확인 결과:

```text
id 1 len 41315 prefix 0A 05 01 01 00 00 00 00 6D 03 E8 03 2C 01 2C 01 decode nil
id 2 len 85760 prefix FF D8 FF E0 00 10 4A 46 49 46 00 01 01 00 00 01 decode 728x729
```

`file` 판정:

```text
PCX ver. 3.0 image data bounding box [0, 0] - [877, 1000], 1-bit colour, 300 x 300 dpi, RLE compressed
```

따라서 좌상단 로고 미표시는 `BehindText` z-order만의 문제가 아니라, ImageIO fallback 없이 unsupported PCX bin data를 조용히 건너뛰던 이미지 decode 문제였다.

## 변경 내용

- `CGTreeRenderer.renderImage`에서 ImageIO decode를 먼저 시도하고, 실패하면 PCX fallback decoder를 사용하도록 분리했다.
- PCX fallback은 HWP bin data에서 확인된 RLE PCX를 처리한다.
  - header 기반 width/height, planes, bits-per-plane, bytes-per-line 파싱
  - PCX RLE scanline decode
  - 1/2/4/8 bpp palette 이미지와 24-bit plane 이미지를 RGBA `CGImage`로 변환
- `Column` 노드는 nested `BehindText` 이미지를 같은 column foreground보다 먼저 그리도록 정렬했다.
- 기존 JPEG/PNG 등 ImageIO 지원 포맷은 기존 경로가 그대로 우선 적용된다.

## 검증

실행 명령:

```bash
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/plans/task_m050_222_impl.md
swiftc -parse-as-library -typecheck -module-cache-path /private/tmp/rhwp-task222-stage4-typecheck/swift-cache -Xcc -fmodules-cache-path=/private/tmp/rhwp-task222-stage4-typecheck/clang-cache -I Frameworks/modulemap Sources/RhwpCoreBridge/RhwpDocument.swift Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/FontFallback.swift Sources/RhwpCoreBridge/FontResourceRegistry.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift -framework CoreGraphics -framework CoreText -framework ImageIO -framework Security -framework CoreFoundation
./scripts/render-debug-compare.sh /private/tmp/rhwp-bokhak-watermark-task222-stage4-final --page 1 samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task222-image-smoke-stage4 --page 1 samples/hwp-img-001.hwp
./scripts/check-no-appkit.sh
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

| 검증 | 결과 |
|------|------|
| `git diff --check` | 통과 |
| Swift typecheck | 통과 |
| `복학원서.hwp` render debug compare | 통과 |
| `hwp-img-001.hwp` image smoke | 통과 |
| `check-no-appkit.sh` | 통과 |
| HostApp Xcode build | 통과 |

`복학원서.hwp` 산출물:

- render tree: `/private/tmp/rhwp-bokhak-watermark-task222-stage4-final/복학원서-page1-render-tree.json`
- native PNG: `/private/tmp/rhwp-bokhak-watermark-task222-stage4-final/복학원서-page1-native.png`
- summary: `/private/tmp/rhwp-bokhak-watermark-task222-stage4-final/복학원서-page1-summary.txt`

native PNG 확인 결과 좌상단 로고가 렌더링된다. 중앙 워터마크 page-level `BehindText` pass도 유지된다.

기존 layout overflow 진단은 동일하게 출력됐다.

```text
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1087.2, bottom=1084.7, overflow=2.5px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1087.2, bottom=1084.7, overflow=2.5px
```

이는 하단 안내 문구 주변의 기존 진단이며 이번 로고 decode 보정과 별개다.

## 판단

- preview와 thumbnail은 모두 `HwpPageImageRenderer -> CGTreeRenderer` 경로를 공유하므로 좌상단 로고 보정은 두 경로에 함께 적용된다.
- 로고는 PCX fallback으로 해결 가능했고, upstream rhwp 릴리즈 갱신을 기다려야 하는 흑백/GrayScale effect 문제와는 별도다.
- 중앙 워터마크의 시각적 검정 표현은 여전히 이미지 effect parity 제한으로 남아 있다.

## 다음 단계

Stage 5에서 최종 보고서와 오늘할일 상태를 정리한다.
