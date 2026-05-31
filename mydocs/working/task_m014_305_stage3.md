# Task M014 #305 Stage 3 보고서 - PUA 보정 smoke 검증

## 목적

Stage 2 CoreGraphics PUA 보정이 실제 renderer output과 Quick Look/Thumbnail extension build에서 문제 없이 동작하는지 확인한다.

## 정책 유지 확인

```bash
rg -n "policy: \\.coreGraphicsOnly|skiaOptIn|renderFirstPage|HwpThumbnailRenderCache" \
  Sources/QLExtension Sources/ThumbnailExtension Sources/Shared
```

확인 결과:

- Quick Look 단일 PNG: `Sources/QLExtension/HwpPreviewProvider.swift`에서 `policy: .coreGraphicsOnly` 유지
- Quick Look 다중 PDF: 같은 provider에서 `policy: .coreGraphicsOnly` 유지
- Finder Thumbnail: `HwpThumbnailRenderCache`가 `renderFirstPage` 기본값을 사용하고, 기본 policy는 `.coreGraphicsOnly`
- `skiaOptIn` helper와 diagnostics 경로는 `Sources/Shared/HwpPageImageRenderer.swift`에 그대로 유지

## 렌더 smoke

```bash
./scripts/render-debug-compare.sh build.noindex/task305-stage3 \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/exam_eng.hwp
```

결과:

```text
OK 복학원서.hwp: page=1 renderTreeJSON=... coreSVG=... nativePNG=... summary=...
OK hwp-multi-001.hwp: page=1 renderTreeJSON=... coreSVG=... nativePNG=... summary=...
OK exam_eng.hwp: page=1 renderTreeJSON=... coreSVG=... nativePNG=... summary=...
```

`복학원서.hwp`에서는 Stage 2와 동일하게 native PNG에서 서명란이 `(인)`으로 표시되고 하단 `U+F081C` filler 사각형이 노출되지 않는다.

`LAYOUT_OVERFLOW` 2건은 `복학원서.hwp`에서 Stage 1 baseline과 동일하게 출력되는 기존 layout warning이다.

## 빌드 검증

첫 sandbox 내부 `xcodebuild`는 Sparkle package resolve 중 `github.com` DNS 접근 제한으로 실패했다. 동일 명령을 sandbox 밖에서 재실행해 package graph를 resolve했고, 이후 두 scheme 모두 통과했다.

Quick Look extension:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask305 CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [13.605 sec]
```

Thumbnail extension:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask305 CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [1.676 sec]
```

## 추가 정적 검증

```bash
./scripts/check-no-appkit.sh
git diff --check
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
git diff --check 통과
```

## 산출물

```text
build.noindex/task305-stage3/
build.noindex/DerivedDataTask305/Build/Products/Debug/AlhangeulPreview.appex
build.noindex/DerivedDataTask305/Build/Products/Debug/AlhangeulThumbnail.appex
build.noindex/DerivedDataTask305/Build/Products/Debug/Alhangeul.app
```

`build.noindex/`는 commit 대상이 아니다.

## 결론

CoreGraphics 최소 PUA 보정은 `복학원서.hwp` 목표 증상을 해결했고, Quick Look/Thumbnail 기본 backend 정책을 변경하지 않았다. Stage 4에서는 최종 보고서와 #301 release handoff를 정리한다.

