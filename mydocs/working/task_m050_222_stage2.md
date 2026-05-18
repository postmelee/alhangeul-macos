# Task M050 #222 Stage 2 완료보고서

## 단계 목표

Swift native renderer가 render tree의 `text_wrap: "BehindText"`를 보존하고, page-level `BehindText` 이미지를 본문/foreground보다 먼저 한 번만 렌더하도록 보강한다.

## 변경 파일

- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`

## 구현 내용

`ImageNode`에 `textWrap` 필드를 추가하고 JSON key `text_wrap`을 디코딩하도록 했다. 기존 이미지 필드와 crop/effect/fill mode 경로는 변경하지 않았다.

`CGTreeRenderer`의 page 렌더링을 전용 함수로 분리했다. 새 page pass 순서는 다음과 같다.

1. 기본 흰색 page fill
2. top-level `PageBackground`
3. top-level `Image` 중 `textWrap == "BehindText"`인 노드
4. 나머지 top-level foreground/body/header/footer 노드

일반 foreground pass에서는 `PageBackground`와 이미 선행 pass에서 처리한 `BehindText` 이미지를 건너뛰어 중복 렌더를 막는다. body 내부 이미지처럼 nested node는 기존 parent 순서를 유지한다.

## 의도적으로 제외한 내용

- `GrayScale`, `brightness`, `contrast` 색상 parity 수정은 하지 않았다.
- PageLayerTree 전환은 하지 않았다.
- nested `BehindText` object 전체 재배치는 하지 않았다.
- Quick Look registration 또는 Finder smoke는 수행하지 않았다.

## 검증

실행한 명령:

```bash
git diff --check -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift
./scripts/check-no-appkit.sh
swiftc -parse-as-library -typecheck -module-cache-path /private/tmp/rhwp-task222-stage2-typecheck/swift-module-cache -Xcc -fmodules-cache-path=/private/tmp/rhwp-task222-stage2-typecheck/clang-module-cache -I Frameworks/modulemap Sources/RhwpCoreBridge/RhwpDocument.swift Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/FontFallback.swift Sources/RhwpCoreBridge/FontResourceRegistry.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift scripts/render_debug_compare.swift
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

- diff check 통과
- `check-no-appkit` 통과
- `RhwpCoreBridge`와 render debug helper typecheck 통과
- HostApp Debug build 통과

참고:

- `swift test`는 저장소에 `Package.swift`가 없어 적용할 수 없었다.
- 첫 `xcodebuild`는 sandbox가 SwiftPM/Xcode cache 접근을 막아 실패했고, 같은 명령을 일반 권한으로 다시 실행해 성공했다.
- Xcode가 CoreSimulator out-of-date 경고를 출력했지만 macOS HostApp build는 성공했다.

## 다음 단계

Stage 3에서 `samples/복학원서.hwp`를 대상으로 `render-debug-compare.sh`를 실행하고, 생성된 native PNG에서 중앙 워터마크가 본문 텍스트와 표 아래에 렌더되는지 확인한다.
