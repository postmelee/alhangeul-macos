# Task M010 #134 Stage 10 보고서

## 단계 목표

HostApp viewer 하단의 중복 상태 footer를 제거한다.

## 변경 배경

`rhwp-studio` 임베드 페이지 자체가 파일명, 페이지, 확대/축소 등 viewer 상태 정보를 표시한다. HostApp shell의 하단 `StatusBarView`는 같은 정보를 중복 표시하고 WKWebView 표시 영역을 줄이므로 제거한다.

## 변경 내용

- `DocumentViewerView`의 bottom `safeAreaInset`을 제거했다.
- 더 이상 사용하지 않는 `StatusBarView` private subview를 삭제했다.
- `DocumentViewerStore`의 상태 값은 menu enablement와 viewer loading/error 흐름에서 계속 사용하므로 유지했다.

## 검증

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

결과: 성공. `** BUILD SUCCEEDED ** [2.546 sec]`.

## 남은 확인 사항

- 하단 footer 제거 후 화면 하단 여백과 embedded status bar 노출은 실행 앱에서 육안 확인이 필요하다.
