# Task M020 #568 — native 글꼴 연결 조사·승인 범위

- 이슈: [#568](https://github.com/postmelee/alhangeul-macos/issues/568), M020, 작업 `local/task568`.
- 기준: Stage 3 `b64732c`, core v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`.
- 승인: 2026-10-09 “Stage 4 진행해줘”. 추가 지시로 먼저 이전 임시 빌드·캐시를 정리했다.
- 상태: Stage 4 조사·CoreText bytes 실험 완료. 제품 native/Skia 연결은 아직 미구현이며 새 C ABI 범위를 확인한다. Stage 4 완료보고서가 아니다.

## 1. 저장공간 정리

정리 전 `build.noindex`는 약 9.54 GiB, 여유 공간은 약 12.56 GiB였다. 이전 #563–#568의 재생성 가능한 Xcode DerivedData·ModuleCache·중복 시험 앱·Studio node_modules 122개 경로와 추가 module-cache 7개를 정리했다. 의존성 checkout 안의 Sparkle 검증 DMG 35개도 DerivedData와 함께 제거됐다. 시스템에 마운트된 iOS Simulator/Metal toolchain DMG는 제외했다.

삭제 전 소유 앱/appex의 LaunchServices 등록만 해제했고 tracked 파일·원본 테스트 글꼴·현재 core checkout/Frameworks·raw PDF/JSON/PNG 증거는 보존했다. 실행 중인 Stage 3 체험 앱과 #567의 최종 체험 앱도 보존했다. `build.noindex` 밖의 사용자 캐시·문서·다른 저장소의 shared Cargo target은 정리하지 않았다.

삭제 경로의 할당 용량 합계는 약 7.45 GiB이며 최종 여유 공간은 약 19.24 GiB다. APFS 공유/할당 차이와 주변 작업 때문에 할당 합계와 여유 공간 증가량은 다르다. 새 단계의 작은 진단 빌드가 이후 사용한 공간은 별도다. [정리 기록](../working/assets/task_m020_568_stage4/cleanup-summary.json)은 상대 경로·용량·보존 목록을 기록한다. 이전 보고서의 raw 빌드/app 경로 중 일부는 이제 재생성 대상이다.

## 2. 현재 native 경계

| 경계 | 실제 코드 | 판단 |
|------|-----------|------|
| CoreGraphics | `CGTreeRenderer` → `resolveAppleFont` → 정적 family fallback/시스템 이름 조회 | 선택된 관리 원본 bytes·세대/lease와 연결되지 않음 |
| 사용자 font 공급 | `StudioFontSupply.using`의 설치 generation·관리 snapshot/digest·필요 bytes 읽기·release | 소비자별 준비/수명을 재사용할 원천. DTO 열거만으로 실제 적용을 보장하지 않음 |
| native PNG C ABI | `rhwp_render_page_png`, `PngExportOptions.font_paths = Vec::new()` | Swift가 검증한 사용자 bytes/선택을 넘길 입력이 없음 |
| upstream Skia custom | `with_font_paths` → directory의 파일 읽기 → `HashMap<family, Typeface>::entry(...).or_insert(...)` | family당 첫 face만 유지. 같은 family의 Regular/Bold를 둘 다 정확하게 고를 수 없음 |
| upstream Skia system | family/style matching 및 thread-local family/typeface 캐시 | OS 등록만으로 관리 우선·사용 설정·원본 버전/세대와 맞는 선택을 보장하지 않음 |
| upstream portable glyph | public `ResourceArena`, `lower_font_native_glyph_sidecars`, Skia glyph replay proof | bytes를 포함한 정확한 face 재생에 사용할 후보. 일반 host font resolver를 바로 주입하는 API는 아님 |
| preview/thumbnail cache | `HwpPageImageRenderer`와 `HwpThumbnailRenderCache` | 작업별 font identity·실패/설정 변경 반영과 소비자 권한 연결 필요. Finder 수용은 Stage 5 |

Skia family 저장/스타일 문제는 pinned source의 정적 코드 근거다. 이번 조사에서 새 Skia 실행 재현이나 exact bytes 전달을 완료한 결과로 표시하지 않는다. 전체 시스템 디렉터리 주입·임시 OS 전역 등록·원본 폰트의 name table 변경을 해결책으로 사용하지 않는다.

## 3. 완료한 최소 실험

[native bytes probe](../../Tests/NativeFontSupplyProbe/README.md)는 지정한 고운바탕 원본을 CGDataProvider → CGFont → CTFont로 구성했다. Regular/Bold 각각의 PS와 SHA-256, 한글/ASCII glyph 조회, CTLine PNG를 확인했다. arm64/macOS 12 target compile과 최신 macOS 실행을 확인했으며 최소 OS/Intel runtime은 미검증이다. OS 글꼴 등록·AppKit·FFI 변경은 없다. 같은 PS의 다른 메모리 bytes도 독립적으로 구성했다. [결과](../working/assets/task_m020_568_stage4/coretext-result.json)·[시각 대조](../working/assets/task_m020_568_stage4/coretext-bytes.png).

이 결과는 CoreGraphics 작업별 bytes 구성 후보를 검증한 것이다. 실제 문서의 CoreGraphics renderer·사용자 설정·충돌/캐시·관리 lease와 연결되지 않았고 서로 다른 버전의 캐시 일관성 시험도 아니다.

## 4. 다음 변경안과 승인 경계

기존 Stage 4 계획의 “새 FFI/API가 필요하면 Stage 4 구현 전에 승인 범위를 보정” 조건에 해당한다. Skia에 단순 폴더 인자만 추가하면 위 스타일 문제를 해결하지 못하므로, 다음 바이트 기반 경계를 우선 구체화한다.

1. native 작업은 immutable 문서/글꼴 identity와 필요한 face만 소유한다. 관리 snapshot lease·설치 세대/현재 원본·파일 64 MiB/합계 128 MiB·face 64·요청 2,048 제한을 유지한다. 원본 경로/bookmark를 renderer의 외부 입력으로 넓히지 않는다.
2. CoreGraphics에는 이미 검증한 face bytes의 작업별 CTFont context를 주입한다. 같은 PS라도 source/hash/face/style·snapshot identity로 구분하며 renderer/측정·실패 cache에 identity를 반영한다. 기존 glyph·수식·fallback 경로의 지원 범위는 각각 확인한다.
3. 새 C ABI 후보 `rhwp_render_page_png_with_font_context`를 별도 entrypoint로 둔다. 기존 ABI는 그대로 유지하고, 제한된 mapping metadata와 bytes buffer를 caller-owned pointer+length로 호출 동안만 빌려 쓴다. offset/length·최대 크기·중복/누락·null/overflow를 검증하고 call 이후 포인터를 보관하지 않는다. 결과 PNG 및 진단의 Rust allocation은 기존 free 계약을 따른다.
4. Skia의 bytes 적용 후보는 public portable glyph resource/replay API를 재사용하는 좁은 bridge adapter다. 현재 lowerer는 Bold/italic·혼합 언어 등에서 제한이 있으므로 직접 Regular/Bold를 모두 지원한다고 전제하지 않는다. exact face/style/hash와 glyph replay proof를 먼저 격리 재현하고, 불충분하면 CG fallback 또는 추가 upstream API 필요를 보고한다. Bold flag를 지우거나 대체 face를 쓴 결과를 exact 성공으로 표시하지 않는다.
5. 관리 우선·유일 설치 후보·동명/스타일 모호성 거부와 기존 fallback의 경계는 Studio 및 native 실제 선택을 대조해 결정한다. 기존 Studio matcher를 Swift에 무작정 재작성하는 설계로 시작하지 않는다. native 선택·glyph/버전 증거가 다르면 제한/미지원으로 기록한다.

**이번에 필요한 추가 승인**은 앱 소유 RustBridge의 새 C ABI 설계·격리 실험과 연관 Swift wrapper/header/symbol 검토다. core release pin/원본 upstream 변경·새 공개 이슈/PR·로컬 인증서·Finder 설치/등록·물리 인쇄·제품 릴리스는 포함하지 않는다. 실제 격리 실험에서 추가 upstream 수정이 필요하면 별도 초안을 준비하고 먼저 범위를 확인한다.

승인 후에는 pointer/length/lifetime·한도와 기존 ABI 회귀, pinned core header/symbol/source 검증, 실제 native Regular/Bold/hash 및 실패/fallback을 수행한다. Stage 4의 정확한 Skia 연결은 검증 결과가 확보된 뒤에만 완료 처리하며, 조사/prototype 또는 CoreGraphics 성공으로 대신하지 않는다.
