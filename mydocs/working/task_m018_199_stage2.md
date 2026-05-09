# Task M018 #199 Stage 2 완료 보고서

## 단계 목적

Thumbnail extension의 CoreGraphics 렌더 경로가 Finder/Quick Look 요청에서 멈추지 않도록 최소 변경을 적용했다.

## 변경 내용

| 파일 | 변경 |
|------|------|
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | thumbnail render worker queue를 concurrent에서 serial로 변경 |
| `Sources/Shared/HwpPageImageRenderer.swift` | bitmap page background fill을 `CGColor(gray:)`에서 RGB direct setter로 변경 |
| `Sources/Shared/HwpPreviewPDFRenderer.swift` | PDF page background fill을 RGB direct setter로 변경 |
| `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | QL reply drawing/fallback fill과 stroke를 RGB direct setter로 변경 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | page/open shape white fill을 RGB direct setter로 변경 |

## 구현 상세

`HwpThumbnailRenderCache`의 worker queue는 다음처럼 serial queue로 제한했다.

```swift
private let workerQueue = DispatchQueue(
    label: "com.postmelee.alhangeul.thumbnail-render",
    qos: .utility
)
```

`CGColor(gray:alpha:)`로 생성하던 흰색/회색은 다음 형태로 바꿨다.

```swift
context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
```

이 변경은 렌더 결과 색상은 유지하면서, RGB bitmap context에서 gray color space를 변환하는 경로를 피한다.

## 범위 통제

- `project.yml`과 `Alhangeul.xcodeproj`는 수정하지 않았다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않았다.
- `rhwp` core dependency와 parser/renderer ABI는 변경하지 않았다.
- #184 DMG 안내 작업과 섞지 않았다.

## 정적 확인

회색조 `CGColor` 직접 생성은 제거됐다.

```bash
rg -n "CGColor\\(gray:" Sources
```

결과: 출력 없음.

