# Task M014 #116 Stage 3 보고서

## 단계 목적

Stage 2에서 정한 설계대로 `bakedWatermark=true` resolved overlay image에 Swift/CoreGraphics image adjustment가 중복 적용되지 않게 최소 구현했다. 이번 단계는 코드 변경과 기본 빌드 검증까지 수행하고, visual diff 수치 비교는 Stage 4에서 별도로 진행한다.

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | overlay image drawing path에서 baked resolved payload의 `effect/brightness/contrast` 후처리 생략 |
| `mydocs/orders/20260530.md` | #116 진행 상태를 Stage 3 구현 완료 기준으로 갱신 |

## 구현 내용

`preparedImage(for:node:)`에 adjustment 적용 여부를 제어하는 기본 인자를 추가했다.

```swift
private func preparedImage(
    for image: CGImage,
    node: ImageNode,
    applyingAdjustments: Bool = true
) -> CGImage {
    let cropped = croppedImage(for: image, crop: node.crop)
    guard applyingAdjustments else { return cropped }
    return adjustedImage(for: cropped, node: node)
}
```

일반 render tree image path는 호출부를 바꾸지 않아 기본값 `true`로 기존 동작을 유지한다.

overlay image path에서는 다음 조건일 때만 adjustment를 생략한다.

```swift
let appliesAdjustments = !(image.bakedWatermark && image.source.data != nil)
```

의미:

- `bakedWatermark=true`: core가 워터마크 visual projection을 끝낸 payload라는 신호
- `image.source.data != nil`: overlay JSON에 실제 resolved image bytes가 포함되어 Swift가 그 bytes를 직접 그리고 있다는 신호

이 두 조건이 모두 참이면 Swift/CoreGraphics는 crop만 적용하고 `effect/brightness/contrast`를 다시 적용하지 않는다.

## 의도적으로 유지한 동작

- `bakedWatermark=false` overlay는 기존 adjustment path를 유지한다.
- overlay JSON bytes가 없어서 `binDataId` fallback으로 원본 문서 리소스를 읽는 경우도 기존 adjustment path를 유지한다.
- render tree fallback path에는 `bakedWatermark` contract가 없으므로 기존 동작을 유지한다.
- JPEG white/near-white transparency fallback은 구현하지 않았다.
- crop, transform, destination rect, fill mode 계산은 변경하지 않았다.

## 검증

### diff check

```bash
git diff --check
```

결과: 통과.

### HostApp Debug build

처음 실행한 sandbox 내부 빌드는 `DerivedData/.../SourcePackages`와 `Logs` 생성 권한 문제로 실패했다. 같은 명령을 sandbox 밖에서 재실행해 실제 컴파일을 확인했다.

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task116-stage3 CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [11.865 sec]
```

### registration hygiene

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
```

결과:

- Issues: none
- Development registrations: none
- Warning: `build.noindex/DerivedData-task116-stage3/.../Alhangeul.app` 개발 bundle은 존재하지만 등록 문제는 없음

## 남은 검증

Stage 4에서 다음을 수행해야 한다.

1. `samples/복학원서.hwp` visual diff 전후 수치 비교
2. 기존 image sample set regression visual diff
3. overlay metadata smoke 재확인
4. 필요 시 native/studio PNG를 직접 열어 중앙 watermark 톤과 gray rectangle 변화를 확인

## Stage 3 결론

코드 변경은 의도한 범위로 제한됐고 HostApp 빌드를 통과했다. 다음 단계에서는 이번 변경이 실제로 `복학원서.hwp` native output을 rhwp-studio reference에 가깝게 만드는지 수치와 PNG artifact로 확인한다.
