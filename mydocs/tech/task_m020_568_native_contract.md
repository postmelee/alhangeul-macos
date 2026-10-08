# Task M020 #568 — native 글꼴 연결 조사·승인 범위

- 이슈: [#568](https://github.com/postmelee/alhangeul-macos/issues/568), M020, 작업 `local/task568`.
- 기준: Stage 3 `b64732c`, core v0.8.7 / `1a76570e833917d15817415a53c09ad61ab3203f`.
- 승인: 2026-10-09 “Stage 4 진행해줘”. 추가 지시로 먼저 이전 임시 빌드·캐시를 정리했다.
- 상태: 승인된 새 C ABI·Swift wrapper/header/symbol 및 작업별 CoreGraphics/Skia 어댑터의 격리 검증(4.1) 완료. core v0.8.7은 유지했다. 실제 설치/관리 snapshot·선택/lease/budget 연결과 cache/변경 수용은 남아 있으며 Stage 4 완료보고서가 아니다.

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

**승인된 추가 범위**는 앱 소유 RustBridge의 새 C ABI 설계·격리 실험과 연관 Swift wrapper/header/symbol 변경이다. core release pin/원본 upstream 변경·새 공개 이슈/PR·로컬 인증서·Finder 설치/등록·물리 인쇄·제품 릴리스는 포함하지 않는다. 실제 검증을 취합해 범용 upstream 기여 후보를 분리하며 공개 게시 전 별도 범위를 확인한다.

승인 후에는 pointer/length/lifetime·한도와 기존 ABI 회귀, pinned core header/symbol/source 검증, 실제 native Regular/Bold/hash 및 실패/fallback을 수행한다. Stage 4의 정확한 Skia 연결은 검증 결과가 확보된 뒤에만 완료 처리하며, 조사/prototype 또는 CoreGraphics 성공으로 대신하지 않는다.

## 5. Stage 4.1 — 승인 범위의 구현·격리 수용

`RustBridge/src/font_context.rs`의 새 C ABI는 strict JSON v1 metadata와 연속 bytes buffer를 호출 동안만 빌린다. version/unknown field·중복 ID/slot·offset/length overflow/연속성·SHA-256·실제 SFNT PS·family alias·bold/italic를 검사한다. 빈/null/과대 입력과 유효하지 않은 output slot을 구분하고, 성공 PNG는 `rhwp_free_bytes`, 진단 JSON은 `rhwp_free_string`으로 해제한다. 기존 PNG ABI의 선언/상태 번호는 유지했다.

현재 요청 family는 공급 face의 실제 name ID 1/4/6/16 중 하나와 일치해야 한다. 다른 스타일의 PS 이름을 원래 요청으로 유지하는 경우 등 공식 matcher의 별칭 선택 결과 전체를 이 경계에 접합한 것은 아니다. 이 제한과 문서 slot 대응은 다음 실제 snapshot 연결에서 검증·보정한다.

metadata 1 MiB, face 64·요청 2,048·대상 run 256, 입력 64 MiB/face·128 MiB 합계와 slot별 mapping 작업량 128 MiB를 제한한다. portable 어댑터는 core resource/proof의 32 MiB/face·64 MiB/작업 경계를 유지한다. 이 값은 전체 renderer RSS/Skia 내부 할당 상한을 검증한 결과가 아니다. Swift transport는 합친 buffer의 Data slice를 face view로 사용하며 큰 원본을 context 안에서 이중 보관하지 않는 실제 주소 공유를 확인했다.

첫 실험에서 기존 nominal lowerer만 사용하면 실제 HWP/HWPX의 대상 4개 run 중 2개만 재생됐다. Bold와 한 run의 한국어/ASCII 혼합이 제외됐다. 이 제한을 Bold flag 제거·폰트 재명명·OS 등록으로 우회하지 않았다. `font_context/nominal.rs`는 **공개 FontResolver·TextShapeLowerer·EmbeddedTextMeasurer**를 재사용하는 작은 host 어댑터다. private replay helper는 사용하지 않으며 기본 위치 계산을 복제하지 않는다. 원본 TextRun/style은 유지하고, 실제 source의 스타일과 glyph coverage를 검증한 뒤 portable resource와 producer 위치를 연결한다. 한국어 완성형/출력 가능한 ASCII·수평 LTR·같은 face를 쓰는 언어 혼합만 추가 지원한다. 실제 Bold face의 instance는 synthetic bold를 끈다. 구성한 run 전체를 native replay proof로 다시 검사하며 대상 전부가 통과하지 않으면 PNG를 반환하지 않는다.

이 경로는 **정확한 face/glyph program을 기존 producer 위치에 적용하는 PositionAdjusted replay**다. 선택 글꼴로 모든 pagination/kerning을 다시 계산했거나 모든 스크립트·한글 자모·언어별 다른 face·가변/TTC·세로쓰기·글자 효과를 지원한다는 뜻이 아니다. 이런 조건에서의 explicit failure/기존 경로 범위와 CoreGraphics의 별도 지원 범위를 구분한다.

`RhwpNativeFontContext`와 Swift PNG wrapper는 buffer 소유권·한도·정확한 성공 진단을 확인한다. `RhwpCoreTextFontContext`는 검증한 bytes로 CTFont를 구성하고, 문서 charShape/family/style에 적용한다. 같은 key의 언어 mapping이 다른 face이면 거부한다. `CGTreeRenderer`와 `HwpNativePageCompositor`는 작업 종료 시 context를 복원하며 기존 호출은 그대로 유지한다. Shared `HwpPageImageRenderer.renderPage`에 선택 context/identity/face 진단을 연결했다. Skia 미지원 시 같은 선택의 CoreGraphics를 시도하며, 해당 face의 glyph도 없으면 기본 글꼴로 조용히 교체하지 않고 실패한다. 수식·각주 marker·장식 전용 font 경로에는 새 context를 연결했다고 주장하지 않는다.

### 검증 결과

| 검사 | 결과/경계 |
|------|-----------|
| Rust ABI/기존 회귀 | 27개 통과(기존 20 + 신규 7). 원본 Regular/Bold, malformed/hash/PS/style/중복/한도/null, TTC/가변 거부, 진짜 Bold·혼합 run·미지원 scalar 검사 |
| 실제 HWP/HWPX 새 ABI | 각각 Regular 3/3, Bold 1/1, 함께 4/4 run의 resource/typeface proof와 PNG 생성. 사용자 font OS 등록 0, 전후 문서 tree 동일 |
| Swift wrapper/CoreGraphics/Shared 진입 | 실제 두 형식에서 원본 R/B PS·hash, Skia/CG 생성, context 복원과 기본 렌더 회귀 통과. isolated cwd의 bundled process 등록도 0 |
| 양성·실패 대조 | Regular 1/1, missing glyph는 UNSUPPORTED/빈 PNG. Shared CG도 missingGlyph로 실패. PS/hash 오류 거부와 Int.max page 거부 |
| 같은 PS의 다른 bytes | 메모리 padding으로 다른 hash를 적용한 후 원본 context 재사용 확인. 실제 서로 다른 글꼴 버전의 시각/cache 수용은 아님 |
| build/ABI provenance | arm64·x86_64 Rust, macOS 12 target Swift/HostApp·확장 compile/link, header/symbol, portable 및 새 동일 환경 reference의 strict 검증 통과. release pin/commit/features는 동일 |
| 기존 renderer | 기본 3개 sample render smoke, producer golden/Swift decode, 합성 문서 core SVG/native 비교 통과. 새로운 context의 두 backend pixel parity/전체 layout 정확성을 보증하지 않음 |
| 미검증 | 실제 macOS 12/Intel runtime, live installed/managed 공급·충돌·lease/취소/세대 변화, peak RSS·동시 budget, Finder/Quick Look/Thumbnail signed 수용 |

원본 TTF·합성 문서·재생성 binary는 커밋하지 않는다. [수용 결과](../working/assets/task_m020_568_stage4/native-integration-result.json), [Skia HWPX](../working/assets/task_m020_568_stage4/native-skia-hwpx.png), [CoreGraphics HWPX](../working/assets/task_m020_568_stage4/native-cg-hwpx.png), [baseline lowerer 제한](../working/assets/task_m020_568_stage4/native-pre-adapter.json)과 receipt를 보존한다. probe 재현 절차는 `Tests/NativeFontSupplyProbe/README.md`다.

새 ABI에 필요한 bridge direct dependency만 Cargo.lock에 추가했고 다른 package version은 바꾸지 않았다. 생성 reference header/staticlib의 변경 근거를 확인한 뒤 명시 update-lock으로 기록했으며 verify 실패를 숨기기 위한 변경이 아니다. Xcode project는 project.yml에서 재생성했다.

HostApp build가 임시 앱을 LaunchServices에 자동 등록했다. 이번 Debug product 경로만 해제한 뒤 생성 앱/확장·중복 Updater·Python cache를 제거했다. unsigned Updater의 강제 scan은 -10814였으므로 성공으로 기록하지 않고, main 해제 뒤 해당 경로가 전체 등록 dump에 없음을 확인한 후 제거했다. 최종 hygiene에서 제품 provider는 `/Applications/Alhangeul.app`, 개발 등록/앱/issue/warning은 0이다. 다른 승인된 체험 앱과 의존성 checkout/native 캐시는 다음 작업을 위해 보존했다.

## 6. 다음 연결과 upstream 후보

다음 작업은 실제 설치/관리 snapshot에서 공식 matcher가 선택한 face를 native 문서 slot에 대응시키고, 같은 공급/lease·설치 세대 검증·읽기 budget을 붙이는 것이다. 관리 우선/동명 충돌·disabled/원본 상실·취소·cache identity를 실제 소비자 요청에서 수용하기 전 Stage 4를 완료하지 않는다. Finder 등록/서명 수용은 Stage 5의 별도 승인 범위다.

검증한 어댑터에서 upstream에 의미 있는 후보는 **host가 선택한 exact static face/bytes를 native glyph replay로 연결하는 범용 helper**다. 기존 public primitives로 가능한 범위가 확인됐으므로 “upstream 수정 없이는 구현 불가능”으로 등록하지 않는다. source/style 검증·portable resource 생성·동일 face의 언어 혼합·기존 producer 위치와 실패 정책을 core 소유로 통합하면 downstream의 재구현 부담을 줄일 수 있다. 복잡 shaping을 더 지원하거나 기존 guard를 무조건 제거하는 제안과 구분한다.

별도로 custom font path의 family당 첫 face 저장·스타일 선택 문제는 최신 pinned source에서도 확인했다. 이 항목은 아직 독립적인 runtime 재현을 완료하지 않았으므로 이를 버그 수용 증거로 혼동하지 않는다. 범용 helper와 작은 스타일 버그 수정은 독립 이슈/PR 후보로 두고, 우리 작업 완료 결과를 취합한 뒤 범위·중복을 다시 확인한다. C ABI/Swift·CoreText·bookmark/보관함·App Group 정책은 앱 저장소 소유로 남긴다. 공개 이슈/PR·push는 수행하지 않았다.
