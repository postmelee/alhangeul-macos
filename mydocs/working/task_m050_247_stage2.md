# Task M050 #247 Stage 2 보고서

## 목적

`origin/devel`을 `local/task247`에 실제 merge하고, 프로젝트 구조와 운영 문서/스크립트 중심 충돌을 정리한다.

이번 단계는 최신 제품 라인의 기반을 `native-viewer-editor` 작업 브랜치에 올리는 작업이다. `Sources/RhwpCoreBridge`의 renderer/font fallback 구현 충돌은 Stage 3에서 별도 수동 통합하기 위해 native 쪽 내용을 보존했다.

## 실행 내용

`local/task247`에서 다음 merge를 실행했다.

```bash
git merge --no-ff origin/devel
```

예상대로 충돌이 발생했으며, Stage 2 범위에 맞춰 다음 원칙으로 해결했다.

| 영역 | 처리 |
|------|------|
| `project.yml` | `origin/devel` 버전 채택. 최신 `Alhangeul` product name, Sparkle package, Legal/rhwp-studio resource 구조를 우선했다. |
| `AlhangeulMac.xcodeproj/project.pbxproj` | 삭제. 최신 제품 라인의 `Alhangeul.xcodeproj` 전환을 따랐다. |
| `Alhangeul.xcodeproj/**` | `origin/devel`에서 추가된 generated project 산출물을 반영했다. Stage 4에서 `xcodegen generate`로 재정렬한다. |
| `.github/workflows/**` | `origin/devel`의 PR CI/release/rhwp upstream workflow를 반영했다. |
| `scripts/**` | `origin/devel`의 release, smoke, visual compare, rhwp-studio sync helper를 반영했다. |
| `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, manual 문서 | #244 이후 `devel` 제품 기본 브랜치 정책을 포함한 최신 제품 라인 문서를 반영했다. |
| `Sources/HostApp/**`, `Sources/Shared/**`, QL/Thumbnail extension | `origin/devel`의 WKWebView shell, 저장/공유/PDF/Quick Look/Thumbnail 제품 변경을 반영했다. |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | `origin/devel` 버전 채택. v0.1 bundle, proprietary font 제외, Source Han Serif K/Latin Modern Math/Happiness Sans 고지가 더 최신이다. |
| `mydocs/tech/font_fallback_strategy.md` | `origin/devel` 버전 채택. #167 이후 WOFF2 35개와 THIRD_PARTY 연결 문맥을 포함한다. |
| `mydocs/report/task_m015_119_report.md` | native 쪽 버전 보존. `devel` 대상 PR에서 HostApp resource에 font directory를 최소 추가했다는 native 라인 기록을 유지했다. |
| `mydocs/orders/20260503.md` | `origin/devel` 버전 채택. 기존 #119 기록을 포함하면서 #135/#140 기록이 추가되어 있다. |
| `mydocs/orders/20260505.md` | 양쪽 기록 통합. `origin/devel`의 M010/M016/백로그에 native 쪽 #123 M050 완료 행을 보존했다. |
| `mydocs/orders/20260506.md` | 양쪽 기록 통합. `origin/devel`의 M010/M016에 native 쪽 #109 M050 완료 행을 보존했다. |
| `mydocs/orders/20260514.md` | 양쪽 기록 통합. `origin/devel`의 #244 M013 완료 행과 `local/task247`의 #247 M050 진행 행을 모두 보존했다. |

## Stage 3로 넘긴 항목

다음 충돌 파일은 merge 완료를 위해 native 쪽 내용을 보존했다. Stage 3에서 `origin/devel`의 변경점과 비교해 수동 통합한다.

| 파일 | Stage 3 작업 |
|------|--------------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | #109 style parity 보강을 보존한 상태에서 `origin/devel`의 renderer 호환 변경을 비교한다. |
| `Sources/RhwpCoreBridge/FontFallback.swift` | #119/#109 fallback chain을 보존한 상태에서 최신 font fallback 보강을 비교한다. |
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | native registry 구현을 보존한 상태에서 `origin/devel`의 Source Han Serif K 등 추가 리소스 정의를 통합한다. |

## 주요 변경 규모

이번 merge로 `origin/devel`의 제품 라인 변경이 대량 반영됐다.

- Xcode project rename: `AlhangeulMac.xcodeproj` -> `Alhangeul.xcodeproj`
- WKWebView HostApp shell과 bundled `rhwp-studio` assets 추가
- 저장/다른 이름 저장/공유/PDF/export 관련 HostApp services 추가
- Quick Look/Thumbnail extension hygiene와 smoke helper 추가
- release/CI/GitHub Pages/Sparkle/Homebrew helper 추가
- README/CONTRIBUTING/AGENTS/manual의 #244 브랜치 정책 반영

## 검증

| 명령 | 결과 |
|------|------|
| `git merge --no-ff origin/devel` | 충돌 후 수동 해결 |
| `rg -n '^(<<<<<<<|=======|>>>>>>>)' ...` | 충돌 marker 없음 |
| `git diff --name-only --diff-filter=U` | 빈 출력 |

Stage 2는 merge와 충돌 해결 중심 단계라 빌드 검증은 아직 수행하지 않았다. `project.yml`과 generated project 재정렬, script syntax, HostApp build는 Stage 4에서 수행한다.

## 다음 단계

Stage 3에서는 `Sources/RhwpCoreBridge` 세 파일과 font resource registry를 실제로 수동 통합한다. 특히 `FontResourceRegistry.swift`는 `origin/devel`의 추가 bundled font 정의를 native registry에 반영해야 한다.
