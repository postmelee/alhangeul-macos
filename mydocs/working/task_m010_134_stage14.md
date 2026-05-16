# Task M010 #134 Stage 14 보고서

## 목적

macOS 공유 picker가 공유 toolbar 버튼이 아니라 window content view 우상단 임의 좌표에서 표시되는 문제를 보정했다.

## 원인

기존 구현은 `NSSharingServicePicker.show(relativeTo:of:preferredEdge:)`를 호출할 때 실제 `공유` 버튼 view가 아니라 `NSApp.keyWindow?.contentView`를 기준으로 사용했다.

```swift
let anchor = NSRect(
    x: contentView.bounds.maxX - 44,
    y: contentView.bounds.maxY - 44,
    width: 1,
    height: 1
)
picker.show(relativeTo: anchor, of: contentView, preferredEdge: .minY)
```

SwiftUI toolbar는 titlebar 영역에 있고 `contentView`는 문서 표시 영역이므로, 공유 picker가 버튼 위치와 무관한 곳에 표시될 수밖에 없었다.

## 변경 내용

- `SharePresentationAnchorView`를 추가해 SwiftUI toolbar의 `공유` 버튼 label 배경에 보이지 않는 `NSView` anchor를 심었다.
- `SharePresentationAnchor`가 현재 window에 붙어 있는 anchor view를 weak reference로 관리한다.
- 공유 picker 표시 시 먼저 `SharePresentationAnchor.presentationView`를 사용하고, anchor가 없을 때만 기존 `contentView` fallback을 사용하도록 바꿨다.
- anchor view가 매우 작은 zero-size view로 배치되는 경우를 대비해 가까운 visible non-zero ancestor view를 찾아 presentation view로 사용한다.

## 검증

```bash
xcodegen generate
```

결과: 성공. 새 `SharePresentationAnchor.swift` 파일이 Xcode project에 포함됐다.

```bash
git diff --check
```

결과: 성공. whitespace error 없음.

```bash
./scripts/check-no-appkit.sh
```

결과: 성공. `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 없음.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과: 성공. `rhwp-studio` asset bundle 구성 검증 통과.

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED ** [3.254 sec]`.

## 잔여 확인 사항

- SwiftUI toolbar가 macOS 버전 또는 toolbar display mode에 따라 내부 view 계층을 다르게 만들 수 있다. 이번 구현은 anchor view에서 가까운 non-zero ancestor를 찾아 대응하지만, 실제 위치는 수동 QA에서 toolbar 표시 모드별로 확인하는 것이 좋다.
