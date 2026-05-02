# Sources 구조

`Sources/`는 macOS 제품 타깃과 공통 Swift 계층을 소유한다. 실제 target 포함 범위는 `project.yml`이 원본이다.

```text
Sources/
├── HostApp/                  # 사용자가 직접 여는 macOS WKWebView viewer app
├── QLExtension/              # Finder Quick Look preview extension
├── ThumbnailExtension/       # Finder thumbnail extension
├── Shared/                   # HostApp/extension 공통 macOS helper
└── RhwpCoreBridge/           # AppKit/UIKit 없는 Swift FFI wrapper + render tree renderer
```

## 타깃별 역할

| 디렉터리 | 역할 | 포함 target |
|------|------|------|
| `HostApp/` | 파일 열기, 보안 범위 접근, `rhwp-studio` WKWebView viewer 상태, 내부 document scheme bridge | `HostApp` |
| `QLExtension/` | Finder Quick Look preview provider | `QLExtension` |
| `ThumbnailExtension/` | Finder thumbnail provider와 thumbnail render cache | `ThumbnailExtension` |
| `Shared/` | page bitmap 렌더링과 Quick Look 표시용 PNG/PDF preview 등 HostApp/extension 공통 macOS helper | `HostApp`, `QLExtension`, `ThumbnailExtension` |
| `RhwpCoreBridge/` | `Rhwp` C module 호출, 문서 핸들 수명, render tree 디코딩, CoreGraphics/CoreText renderer | `HostApp`, `QLExtension`, `ThumbnailExtension` |

## 경계 규칙

- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 넣지 않는다.
- WKWebView/AppKit bridge와 SwiftUI viewer 상태는 `Sources/HostApp`이 소유한다.
- native render tree 기반 bitmap 렌더링은 Quick Look/Thumbnail 경로에 필요한 범위에서 `Sources/Shared`와 `Sources/RhwpCoreBridge`가 소유한다.
- Finder/Quick Look entrypoint는 각 extension 디렉터리가 소유한다.
- 여러 타깃이 공유하지만 macOS/Finder 호출 방식에 가까운 helper는 `Sources/Shared`에 둔다.
- source 포함 범위, bundle identifier, extension embedding을 바꿀 때는 `project.yml`을 수정하고 `xcodegen generate`를 실행한다.

관련 상세 문서:

- `mydocs/tech/project_architecture.md`
- `mydocs/manual/swift_macos_code_rules_guide.md`
- `mydocs/manual/build_run_guide.md`
