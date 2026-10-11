# Task #567 Stage 3 — Studio 공개 글꼴 API 연결

## Stage 3.1 완료 — 2026-09-26

사용자가 기존 이슈의 진행 순서·완료 기준 보정과 작업 진행을 승인했다. #562/#566/#567/#568/#569의 기존 본문을 보존하면서 최신 실행 순서와 완료 기준을 추가하고 원격 본문 일치를 재조회했다. 이슈 상태·마일스톤은 유지했다. [재정렬 근거](../tech/task_m020_567_replan.md).

`StudioFontProviderScript`에 공개 `getSnapshot/readFace/subscribe` 계약을 구현했다. 제품 pin/bundle을 바꾸거나 현재 WebView에 주입하지 않았으며, API 부재 시 native 조회 없이 unsupported로 끝난다. 별도 임시 core fork·minified 패치는 없다.

### 구현 결과

- metadata 페이지 조회와 bytes 읽기를 분리했다. native source별 PS 이름·weight/slant 변환, 빈 이름/alias, 미지원·중복 ID·관리 충돌 및 선택 우선순위를 처리한다.
- 글꼴 파일은 native가 확인한 ID로만 요청한다. JS에는 원본 경로·bookmark를 전달하지 않는다. 실제 openFace의 PS/weight와 목록이 다르면 bytes를 게시하지 않는다.
- 2개 동시 transfer/64개 대기열, 256 KiB chunk, 64 MiB face 제한을 적용했다. 다른 창과 공유하는 앱 전체 2개 한도는 native가 유지한다.
- 제한된 busy 재시도, catalog stale 시 handshake 재시작, 일시 실패 캐시의 1회 세대 갱신을 구현했다. 이전 session/revision과 문서 token의 결과를 폐기한다.
- 취소·구독 해제·provider detach 및 늦게 발급된 transfer의 close를 처리한다. 문서 교체의 `refresh`, 종료의 `dispose`와 native reset 호출은 Stage 3.2 coordinator 연결 책임으로 명시했다.
- 실제 Swift raw string을 실행하는 Node 계약 테스트를 기존 font 테스트 스크립트와 CI에 추가했다. 별도 WebKit probe도 macOS CI에서 실행하도록 연결했다. Xcode 프로젝트는 `xcodegen generate`로 갱신했다.

### 검증

| 검증 | 결과 | 실행 범위 |
|---|---|---|
| `node --test scripts/ci/test-studio-font-provider.cjs` | 20 PASS | metadata-only/페이지·출처별 style/우선순위·충돌/queue 한도/busy·stale/취소·늦은 응답/bytes·세대·구독/API 부재 |
| `scripts/test-font-library.sh` | JS 20 PASS + XCTest 100 PASS | 기존 관리·설치 service·native 공급 회귀, 새 Swift 소스 컴파일 |
| `bash scripts/probe-studio-font-provider.sh` | PASS | 실제 WKWebView custom origin → 응답형 handler → 기존 native session → 새 JS adapter, fixture 1,124 bytes 전체 일치·faceIndex 0 |
| HostApp Debug `xcodebuild`, `CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED | 기존 고정 core/Studio 사용, macOS 12 target |
| `scripts/check-no-appkit.sh` | PASS | 공통 Swift 계층의 AppKit/UIKit 금지 유지 |
| `git diff --check`·문서 상대 링크 검사 | PASS | 변경 문서·소스 형식·링크 |

로그: `build.noindex/task567/stage3-1/{adapter-tests,font-tests,webkit-probe,host-build}.log`. 별도 probe 코드는 `Tests/StudioFontProviderProbe/main.swift`, 실행/재현 도구는 `scripts/probe-studio-font-provider.sh`다. fixture는 저장소의 공개 시험용 `Tests/FontLibraryTests/Fixtures/regular.ttf`이며 사용자 설치 글꼴·문서는 사용하지 않았다.

이전 upstream 검증 보고·재현 자료도 함께 보존했다. 원시 `probe-build.log`에 도구가 출력한 trailing space 한 곳은 증적 해시 유지를 위해 수정하지 않고 해당 파일만 `.gitattributes`의 whitespace 검사에서 제외했다. 코드·문서의 공백 검사는 유지하며 증적 47개 SHA-256을 대조했다.

초기 제한 환경 빌드는 Sparkle 다운로드의 DNS 제한으로 실패하여 승인된 권한으로 재실행했다. 처음 WebKit 검증을 XCTest에 넣었을 때에는 byte 테스트에 도달하기 전 xctest의 NSApplication 중복 생성(SIGTRAP)으로 종료되었고 단독 실행도 같았다. 해당 UI 테스트를 일반 XCTest에서 제거하고 정상 NSApplication 초기화를 하는 독립 probe로 분리했다. probe의 누락된 컴파일 입력과 throwing 호출을 수정한 후 위 최종 실행이 통과했다. 실패를 통과로 집계하지 않는다.

Xcode가 자동 등록한 이번 개발용 HostApp 경로는 `lsregister -u`로 해제했다. probe는 종료 trap에서 자기 경로를 해제한다. Quick Look/Thumbnail 개발 등록·OS 글꼴 설치·사용자 권한 변경은 수행하지 않았다.

### 한계와 다음 단계

이 단계는 어댑터 준비 완료이며 **#567 전체 완료나 현재 제품의 글꼴 적용 지원이 아니다.** probe의 Studio API는 공개 계약을 따르는 작은 mock이고 실제 native handler/session과 WebKit transport를 사용한다. upstream main/renderer/toolbar와의 제품 연결은 아직 하지 않았다. 이전 #7405의 29개 검증은 이전 head의 별도 증거로 보존한다.

알 수 없는 installed style은 보수적으로 제외하고 실제 읽은 weight/PS가 목록과 다른 경우 실패 처리한다. 모든 지역화된 글꼴 스타일·TTC·가변 지원을 주장하지 않는다. 화면 변경이 없어 새 제품 스크린샷은 없다. 실제 최소 OS 실행·signed sandbox·OS 권한 복원·다중 창 전체 수용·실문서 편집/저장·PDF/인쇄/Finder 확장은 미검증이다.

Stage 3.2는 API가 포함된 정식 릴리즈와 해당 단계 승인 후 진행한다. 기존 sync PR 여부를 확인해 core/Studio provenance·ABI·자산을 갱신하고, coordinator의 API 준비 시점·문서 token 교체·dispose를 연결한다. 실제 renderer 및 편집 글꼴 메뉴를 각각 검증한 뒤 Stage 4/5로 진행한다. 현재 제품 v0.8.6 pin과 준비 중 안내는 유지했다.

## Stage 3.2 완료 — 2026-10-07

사용자가 upstream [v0.8.7](https://github.com/edwardkim/rhwp/releases/tag/v0.8.7) 반영과 로컬 글꼴 연결 재개를 지시했다. 기존 `local/task567`에서 최신 devel `17dad15`를 병합(`e99b1ee`)했으며, 동일 릴리즈 sync PR은 조회 당시 없었다. 앞 절의 v0.8.6 유지·연결 미완료 상태는 Stage 3.1의 이력이다.

### 정식 릴리즈 반영

- stable v0.8.7은 2026-10-06 07:54:34 UTC 게시되었다. resolved commit은 `1a76570e833917d15817415a53c09ad61ab3203f`이며 #7405 병합 `aeb9f489e1d5e297c1e98cf1ca8ff84532270aca`를 포함한다.
- `RustBridge/Cargo.toml`은 공식 git URL + tag, Cargo.lock은 같은 commit으로 고정했다. arm64/Intel native-skia staticlib, XCFramework, header/FFI 검증 후 `rhwp-core.lock` 산출물 metadata와 build info를 갱신했다. FFI header hash/size는 이전과 동일하다. 같은 환경의 strict source·ABI·archive 검증도 통과했다.
- 동일 태그의 WASM을 upstream 공식 locked wrapper와 Rust 1.93.1로 fresh build하고, `npm ci`, `npx tsc`, `npx vite build --base ./` 후 sync했다. root Cargo.lock 무변경과 manifest source lock fingerprint를 대조했다. WASM SHA256은 `d6a00eb16a7155607b7a81641ef33ba5414a032f74091c72c1c1d351b7086cdf`다.
- native bridge는 앱의 Rust 1.94.1을 사용했다. 공유 upstream target cache에 임시 `RustBridge/target` symlink를 두어 재사용했고, 단계 종료 때 symlink만 제거했다. 공유 캐시는 삭제/초기화하지 않았다.
- producer golden의 core provenance와 실제 출력이 갱신되었다. 이전 대비 page bbox, 순서대로 추출한 text와 TextRun 103/Table 4/TextLine 65 개수는 동일하고 선 두께·위치 등 수치는 바뀌었다. Swift 전체 decode와 동일 producer 재검증을 통과했다. 이를 모든 문서의 시각 정합성 보장으로 확대하지 않는다.
- README 포함 버전 배지도 기존 helper로 갱신했다. upstream 소스/생성 JS를 수동 패치하지 않았다.

### 제품 연결·선택 UI

`StudioFontProviderScript.bootstrapSource`를 제품의 document-end user script에 연결했다. 공개 `window.rhwpStudio.fonts` 준비 후 provider를 등록하며, 연결 상태와 제한된 실패 복구를 관리한다. 문서 epoch 교체에서는 native begin과 provider refresh, navigation/pagehide·fatal failure·view 해제에서는 dispose/reset을 처리한다. 늦은 dispose가 새 page에 적용되지 않도록 native load token을 확인한다.

host catalog는 upstream toolbar 목록에 자동 추가되지 않는다. 공개 automation extension command/menu로 **서식 → 로컬 글꼴 선택…**을 추가했다. 앱 소유 선택 창은 family 검색·중복 제거·선택 후 적용을 제공하며 원래 family를 `findOrCreateFontId`와 기존 `applyCharPropsToRange`에 전달한다. 외부 matcher·편집 엔진을 복제하지 않는다. 현재 선택 창은 글자를 선택한 상태에서 열며, 커서 위치에서 새로 입력할 글꼴의 전체 수용은 Stage 5에 남긴다. 선택 영역이 없는 메뉴를 비활성화하고 읽기 전용·양식 제한·객체 선택과 창을 연 뒤의 문서/입력 handler/목록 변경을 검사하고, Escape·취소·dispose로 창과 자신이 등록한 command를 정리한다.

테스트 공급과 observer를 주입할 수 있는 Coordinator/handler 초기화 경로를 추가했다. 제품 기본 공급·observer 동작은 유지했다. 격리 probe에서는 live observer를 끄고 승인된 시험 글꼴만 공급한다.

### 최종 검증

| 검증 | 결과 | 실제 범위 |
|---|---|---|
| `build-rust-macos.sh --update-lock` 및 `--verify-strict` | PASS | v0.8.7 source/Cargo/header/FFI/arm64+Intel archive 및 XCFramework |
| core build info·README badge·Studio strict asset/Cargo provenance | PASS | native와 Studio 모두 공식 태그·동일 SHA |
| producer golden update/verify | PASS | pinned native producer 및 Swift 전체 decode |
| `scripts/test-font-library.sh` | Node 27 + XCTest 100 PASS | 실제 Swift JS 소스 실행, 설치/관리 공급·보안·수명 회귀 |
| upstream host-font/host-canvas/renderer-session tests | 27 PASS | v0.8.7 태그의 실제 테스트. 이전 PR head의 29개와 구분 |
| checkout reuse 및 Studio sync fixture | PASS | annotated tag/linked worktree, dirty/stale/non-Git/API 거부, 원본 보존 |
| HostApp Debug build | BUILD SUCCEEDED | macOS 12 target, `CODE_SIGNING_ALLOWED=NO` |
| native render smoke | 3 PASS | KTX/request/exam_kor의 tree·한글 glyph·비어 있지 않은 PNG |
| 제품 SwiftUI 문서 lifecycle smoke | 43 PASS | 새 문서·저장·재열기·내보내기·취소/실패·종료 및 font IPC |
| 실제 제품 Coordinator + 실제 bundled Studio probe | PASS | 아래 renderer·선택·저장 증거 |
| no-AppKit·변경 shell/JS/YAML·diff 형식 | PASS | 공통 계층 경계와 변경 파일 검사 |

실행 환경: macOS 26.5.2 (25F84), Xcode 26.6 (17F113), native Rust 1.94.1, Node 24.15.0. macOS 12는 compile target이며 실제 최소 OS 실행 결과가 아니다. Intel도 build 결과이며 실제 Intel 기기 실행은 하지 않았다.

### 실제 Studio 증거

승인된 Google Fonts 고운바탕 static Regular/Bold를 사용했다. 사용자 글꼴의 OS 설치·설정·권한을 변경하지 않고 메모리 기반 시험 공급을 제품 Coordinator에 주입했다. 실제 native handler/session과 실제 v0.8.7 Studio/WASM을 사용하며 Studio API mock은 사용하지 않았다.

- HWP/Canvas2D와 HWPX/Canvas2D 각각에서 해당 문서 generation의 정확한 Regular/Bold PS bytes 요청 및 실제 `fillText`의 host face alias를 확인했다.
- HWPX/CanvasKit은 `effectiveBackend=canvaskit`, no fallback, Apple GPU/WebGL 2.0, local typeface 2개·load failure 0개·render complete를 확인했다. Canvas2D 성공을 대신 근거로 쓰지 않았다.
- 다른 글꼴(돋움)이 사용된 마지막 ‘확인’을 포함한 합성 문서에서 실제 메뉴의 선택 창을 열어 고운바탕을 적용했다. dirty 변경, 새 document revision의 완료된 CanvasKit repaint와 실제 화면 변화를 확인했다.
- 적용 결과를 HWP/HWPX로 저장하고 실제 bundled WASM으로 다시 열었다. 처음 Regular·중간 Bold·마지막 바뀐 글꼴 모두 원래 `Gowun Batang` 이름과 굵기를 유지하며 portable SVG에 내부 renderer alias가 없다.
- 한글 본문은 실제 렌더 검증에 포함된다. 이 무료 글꼴의 name table은 영문 family/PS만 제공하므로 실제 한글 family/지역화 이름의 전체 수용을 주장하지 않는다. alias 정규화·한국어 문자열은 계약 테스트에서 검증하며 다른 실제 글꼴의 수용은 Stage 5에 남긴다.

작은 증거와 화면은 [Stage 3.2 재현 자료](assets/task_m020_567_stage3/REPRODUCE.md), 원시 로그/산출물은 `build.noindex/task567/stage3-2/`에 있다. lifecycle 원시 자료는 `build.noindex/studio-lifecycle-cq2zaz7b/`다. `scripts/probe-studio-font-integration.py --interactive --skip-build`로 격리 창을 직접 조작할 수 있다. 일반 실행은 자동 검증 종료 후 자신의 앱 경로를 등록 해제하고, 직접 조작 모드는 창 닫기 시 provider/lease를 정리하고 자신의 등록 해제를 실행한다.

### 중간 실패·환경 정리

초기 중복 upstream fetch는 필요한 태그 조회로 줄였다. Cargo 캐시가 없어서 git 다운로드를 한 번 수행했고, 디스크 부족으로 첫 full checkout이 실패했다. 해당 실패 checkout만 제거해 공간을 복구하고 재실행했다. 완료된 해당 checkout은 검증된 source 경로의 sparse checkout으로 줄여 불필요한 PDF/문서 복사본을 제거했으며 core/lock Git diff는 없다. cache의 동일 pack은 이미 hardlink라 추가 중복 제거량은 0이었다. offline 첫 조회의 tag ref 부재 및 svg2pdf registry 부재는 해소한 뒤 공식 Cargo lock 갱신을 성공시켰다. 실패한 updater는 manifest/lock을 자동 복원했다.

첫 UI probe는 선택 영역을 만들지 않아 창 목록을 확인하지 못했다. 실제 select-all 흐름으로 수정했다. 선택 후 화면을 즉시 캡처한 결과에는 이전 paint가 보였고, render count 증가를 기다리는 보강은 편집 시 count가 초기화되어 시간 초과됐다. 새 document revision의 render complete를 검사하도록 고친 뒤 실제 glyph 변화와 저장·재열기를 모두 재검증했다. 실패를 통과로 집계하지 않는다.

이번 HostApp Debug 경로는 `lsregister -u`로 해제했다. 전체 읽기 전용 등록 위생 helper는 과거 개발 경로 잔존 때문에 FAIL이며 Finder 통합 성공으로 기록하지 않는다. 특히 과거 `build.noindex/font-library-tests/.../Alhangeul.app` 경로는 실제 파일이 없어 개별 해제 시 -10814였다. 다른 worktree/설치 앱이나 전역 등록 DB는 변경하지 않았다. CUA로 격리 창을 확인하는 시도도 timeout이어서 CUA 조작 검증으로 주장하지 않으며, 실제 WK snapshot과 정상 NSWindow 실행을 증거로 사용한다. Quick Look/Thumbnail 수동 개발 등록은 하지 않았다.

### 다음 단계

이 단계의 정식 릴리즈 의존은 해소됐다. 추가 upstream 릴리즈를 기다리지 않고 Stage 4로 진행할 수 있다. Stage 4는 설정 변경·권한/원본 상태 변화·열린 문서 캐시 갱신·재실행·지원 안내, Stage 5는 signed sandbox·실제 OS 설치·다양한 실제 문서/글꼴·성능/다중 창 수용이다. 현재 사용 설정 기본값과 준비 중 안내는 Stage 4의 정책·수용 검증 대상으로 유지했다.

#567 전체 완료·PR·제품 v0.2 배포는 아직 아니다. PDF/인쇄/native/Finder(#568) 및 Windows 입력(#566)은 별도 책임으로 유지한다. 다음 단계는 저장소의 단계 승인 절차를 따른다.

## Stage 3.3 완료 — 2026-10-07

사용자가 기존 글꼴 목록의 전체/시스템 범주에 로컬 글꼴을 연결하고 별도 팝업을 제거하는 제안에 “그렇게 진행해줘”라고 지시했다. 이 범위를 #567의 Stage 3.3으로 보정하고 구현했다. Stage 3.2의 별도 선택 창은 이력이며 현재 제품 소스에는 남아 있지 않다.

### 변경과 경계

- `StudioFontPickerScript`와 전용 automation 명령/서식 메뉴를 제거했다. 제품 bootstrap은 공개 host provider 연결·수명만 담당한다. Xcode 프로젝트는 `project.yml`에서 `xcodegen`으로 재생성했다.
- 앱 소유 `studio-font-menu-adapter.mjs`는 빌드 시 원본 Studio의 `getLocalFonts()`와 toolbar 변경 구독 두 곳을 변환한다. host provider가 활성일 때 공급 가능한 원래 family를 반환한다. Regular/Bold는 family 한 항목으로 표시하며 굵기·face 선택은 기존 renderer matcher가 처리한다. 해제 시 기존 browser 목록을 반환한다. 같은 함수를 사용하는 글자 모양/글꼴 세트 UI도 같은 목록을 받는다.
- host invalidation 시 열린 이전 메뉴를 닫고, 새 snapshot 완료 후 현재 세대의 새 메뉴만 갱신한다. 문서 선택 범위·현재 이름은 유지한다. 메뉴 선택은 기존 toolbar `format-char`/input handler 경로를 사용하므로 선택 영역과 커서 입력을 모두 지원한다. 편집·읽기 전용 정책과 renderer/bytes 공급 구현은 복제하지 않았다.
- `build-rhwp-studio.mjs`는 변환 소스의 격리 사본을 upstream에 고정된 TypeScript CLI로 검사하고 Vite plugin으로 빌드한다. 원본 checkout의 tracked 소스는 변경하지 않았다. minified 산출물을 직접 패치하지 않는다. native core·WASM pin/bytes는 Stage 3.2와 동일한 공식 v0.8.7이다.
- 빌드 증명은 builder/adapter·원본/변환 소스 SHA256과 upstream commit을 기록한다. sync는 증명을 요구하고 verifier는 manifest·helper·source fingerprint를 대조한다. 다음 자동 sync도 같은 helper를 사용하며 소스 형태 변경·누락/오래된 증명은 실패한다. CI 변경 분류에 builder/adapter도 등록했다.

### 검증과 실제 화면

| 검증 | 결과 |
|---|---|
| 변환된 TypeScript typecheck + 실제 Vite/PWA build | PASS |
| strict Studio asset/Cargo/adapter provenance, 원본 tracked Git diff | PASS / 무변경 |
| `scripts/test-font-library.sh` | Node 24 + XCTest 100 PASS |
| Studio source lock/sync fixtures | PASS: linked worktree·stale/dirty 경계·증명 누락 거부, 원본 보존 |
| HostApp Debug/macOS 12 target | BUILD SUCCEEDED |
| 실제 WKWebView·제품 Coordinator·공식 Studio 검증 | 27 PASS |
| 실제 HWP/HWPX 저장 후 bundled WASM 재열기 | 8 위치 PASS, 7개 언어 원래 이름·Regular/Bold·입력 내용·alias 미유출 |
| README badge fixture 10건, 변경 shell/Node/Python/YAML·no-AppKit·diff | PASS |

고운바탕 Regular/Bold를 격리 fixture로 공급하고 HWP/Canvas2D, HWPX/Canvas2D, HWPX/CanvasKit을 확인했다. 기존 메뉴를 열어도 추가 bytes 읽기가 없고, 전체/시스템에서 family 중복이 없다. 이전 별도 명령이 없음을 확인했다. catalog refresh로 이전 메뉴를 폐기한 뒤에도 문서 선택을 유지하고, 실제 선택으로 마지막 돋움을 고운바탕으로 변경했다. 커서에서는 메뉴로 돋움→고운바탕을 선택한 뒤 실제 input 이벤트로 ` 입력`을 추가했다. 선택과 입력 각각 새 document revision의 CanvasKit repaint 완료를 기다렸으며 저장·재열기도 대조했다.

[현재 화면·재현 자료](assets/task_m020_567_stage3_3/REPRODUCE.md)에 드롭다운/입력 결과와 빌드 증명을 보존했다. 원시 자료는 `build.noindex/task567/stage3-3/`, 최종 paint 검증은 그 아래 `final/`에 있다. **알한글 — 고운바탕 연결 체험 · 테스트 문서** 창은 직접 조작하도록 유지한다. 메뉴의 한 항목은 고운바탕 family의 두 굵기이며 실제 OS 전체 목록을 의미하지 않는다.

### 중간 보정·등록 정리와 제한

초기 builder는 TypeScript JS compiler API를 기대했지만 실제 pin의 TypeScript 7 CLI에는 해당 API가 없어 실패했다. 변환 소스 격리 사본+동일 pinned CLI로 검사하도록 수정했다. sync fixture는 HEAD 전환 뒤 오래된 증명을 갖고 있어 실패했으며 의도한 source commit으로 갱신했다. 저장 검증에서 native WASM에 없는 `getParagraphText`를 호출한 오류는 실제 `getTextRange`로 고쳤다. 첫 입력 직후 snapshot은 이전 paint였으므로 입력 후 revision/render complete까지 기다리도록 보강하고 현재 glyph를 재확인했다. 최종 표에는 수정 후 결과만 집계한다.

첫 sandbox 내 GUI 실행/등록 해제와 Xcode 캐시 접근은 권한 경계 때문에 실패했다. 승인된 격리 GUI와 기존 Xcode cache 접근으로 재실행해 통과했다. 이번 HostApp 개발 산출물의 정확한 경로에 `lsregister -u`를 실행해 종료 코드 0을 확인했고 자동 probe도 자신의 앱 경로만 해제했다. 글꼴 테스트 DerivedData에는 Alhangeul.app이 없어 해제할 대상이 없었다. 전체 등록 위생 조회는 같은 과거 개발 경로가 LaunchServices에 잔존해 FAIL이다. 전역 등록·다른 worktree·사용자 설치본은 변경하지 않았고 Finder 성공으로 집계하지 않는다.

Stage 4/5는 아직 진행하지 않았다. 설정 기본값/준비 중 안내, 실제 OS 설치·권한/원본 변화와 새 프로세스 복원, signed sandbox·다양한 실제 문서/다중 창/대규모 성능은 남는다. 이번 창은 사용자 글꼴 설정·OS 설치를 변경하지 않는 격리 시험이다. #567 close·PR 게시·릴리스는 하지 않았다.
