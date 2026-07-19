# Task M020 #422 Stage 4 완료보고서

## 단계 목적

`rhwp v0.7.19` bundled studio의 custom scheme Host RPC 회귀를 release blocker로 확정하고 upstream에 이슈화한다. 최종 제품 core/studio provenance를 stable `v0.7.18`로 복원한 뒤 Rust ABI, 앱 세 target, Quick Look/Thumbnail, representative visual과 실제 Host RPC가 다시 통과하는지 검증한다.

## 산출물

| 파일 또는 산출물 | 요약 |
|------------------|------|
| `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock` | dependency를 `v0.7.18` / `93862a4e...`로 복원 |
| `rhwp-core.lock`, `RhwpCoreBuildInfo.swift` | current RustBridge 재빌드 artifact와 release provenance 기록 |
| `Sources/HostApp/Resources/rhwp-studio/**` | bundled studio JS/CSS/WASM/font/manifest를 `v0.7.18`로 복원 |
| core 운영·호환성·architecture 문서 | 현재 stable pin을 `v0.7.18`로 정렬 |
| Task #422 계획서와 구현계획서 | `v0.7.19` blocker 판정 및 `v0.7.18` release handoff로 계획 변경 |
| upstream `edwardkim/rhwp#2396` | custom scheme legacy Host RPC 회귀 보고 |
| `build.noindex/task422-v0718-*` | ignored visual, Quick Look, Thumbnail 검증 산출물 |
| `/private/tmp/task422-v0718-KTX.pdf` | 실제 HostApp `exportHwp` 결과, 1-page PDF |

## v0.7.19 blocker 판정

original `v0.7.19` bundled studio에서 quick visual suite의 CoreGraphics/Skia 10건이 모두 custom scheme readiness timeout됐다. 실제 HostApp은 문서를 표시했지만 PDF 내보내기 요청이 완료되지 않았다.

`v0.7.18..v0.7.19` runtime 변경을 축소한 결과 upstream commit `023041f55febf0e987c947c74cc5f5d67affdf69`에서 MessageChannel origin 검증이 도입됐고, `alhangeul-studio://app` 최상위 문서의 same-window legacy `rhwp-request`까지 폐기하는 것을 확인했다. 임시 진단 asset에서 same-window 예외만 적용하면 같은 visual suite가 10/10 통과해 native core나 renderer가 아닌 bundled studio Host RPC 회귀로 원인을 분리했다.

영향 경로는 문서 열기 이후의 저장, 공유, 인쇄, PDF 내보내기와 자동화 등 macOS Host RPC 기능이다. downstream은 MessageChannel v1을 채택하지 않았고 기존 legacy 요청이 현재 제품 계약이므로, 임시 vendor patch 대신 upstream stable fix를 기다리는 것으로 판정했다.

- upstream issue: https://github.com/edwardkim/rhwp/issues/2396
- Task issue: https://github.com/postmelee/alhangeul-macos/issues/422
- release 판정: `v0.7.19` 미반영, `v0.7.18` 유지

## v0.7.18 provenance 복원

| 항목 | 확정값 |
|------|--------|
| release tag | `v0.7.18` |
| resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| enabled feature | `native-skia` |
| universal archive | 208,707,280 bytes |
| universal archive SHA-256 | `b7029e88c44774d44e4e30c624113eced4b305918a114834acb5725584c8b0a7` |
| generated header SHA-256 | `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5` |
| FFI symbol | 15개, 추가·삭제 없음 |

Stage 2에서 반영했던 `v0.7.19` dependency와 hashed studio asset을 제거하고 Task 시작점의 `v0.7.18` product/provenance를 복원했다. native archive와 lock은 current RustBridge source에서 새로 생성했으므로 artifact hash와 `built_at`은 이번 빌드를 가리킨다. Stage 1~3 보고서와 commit은 회귀를 발견하기까지의 조사 증거로 보존했다.

## Rust와 앱 build 검증

| 검증 | 결과 |
|------|------|
| `update-rhwp-core.sh --check --channel stable --tag v0.7.18` | tag와 resolved commit 일치 |
| `cargo fmt --check` | 통과 |
| `cargo check --locked` | 통과 |
| `cargo test --locked` | 4 passed, 0 failed |
| `build-rust-macos.sh --update-lock` | arm64/x86_64와 universal archive 재생성 |
| `build-rust-macos.sh --verify-lock` | strict artifact/lock/15-symbol 검증 통과 |
| `check-no-appkit.sh` | Shared/RhwpCoreBridge AppKit/UIKit 의존 없음 |
| `verify-rhwp-core-build-info.sh` | lock/build info 일치 |
| `verify-rhwp-studio-assets.sh` | `v0.7.18/93862a4e...` asset hash 일치 |
| HostApp Debug | BUILD SUCCEEDED |
| QLExtension Debug | BUILD SUCCEEDED |
| ThumbnailExtension Debug | BUILD SUCCEEDED |

RustBridge test는 external reference lookup, Rust-owned JSON lifecycle, filename UTF-8와 injection validation 4건을 모두 통과했다. 별도 clean Cargo target은 sandbox DNS가 Skia dependency를 내려받지 못해 중단됐지만, 기존 worktree target에서 같은 locked graph의 check/test를 성공해 제품 검증 결과에는 영향을 주지 않는다.

## Representative visual 결과

5개 sample을 CoreGraphics production policy와 Skia internal opt-in policy로 실행해 총 10/10이 성공했다. 모든 capture는 `domComposite;ui=clean`, native size drift 0이며 blank, fallback, content loss가 없다.

| Sample | CG changed | Skia changed | Skia-CG | 판정 |
|--------|------------|--------------|---------|------|
| `request.hwp` | 17.6976% | 11.6340% | -6.0636pp | 통과 |
| `KTX.hwp` | 30.7744% | 46.2037% | +15.4293pp | known Skia sentinel |
| `복학원서` | 7.5013% | 7.0360% | -0.4653pp | known layout risk, 내용 보존 |
| `hwp-multi-001` | 14.0349% | 13.9063% | -0.1286pp | 통과 |
| `hwpx-01.hwpx` | 14.0861% | 13.8750% | -0.2111pp | 9-page 내용 보존 |

`KTX.hwp`, 복학원서와 HWPX 결과를 직접 확인했다. 기존 renderer 간 차이는 유지되지만 신규 잘림, blank, 표·이미지·텍스트 소실은 보이지 않았다.

## Quick Look과 Thumbnail

Quick Look smoke는 `request.hwp`, `KTX.hwp`를 1-page PNG로, `hwpx-01.hwpx`를 9-page PDF로 생성했다. CoreGraphics와 Skia decode/direct 경로의 fallback은 모두 0이었다.

Thumbnail smoke는 resolver contract 7건을 모두 통과했다. 세 문서에 policy 2개와 request 4개를 적용한 총 24회 render가 모두 성공했고, 최초 miss, 반복 exact hit, 작은 request의 larger bucket hit 계약이 유지됐다. cache signature는 `v0.7.18/93862a4e...` provenance와 renderer policy를 분리해 기록했다.

## 실제 Host RPC 검증

화면 잠금 해제 후 Debug HostApp에서 `KTX.hwp`를 `alhangeul-studio://app/index.html` custom scheme으로 열었다. 문서는 1페이지로 정상 표시됐고 toolbar의 PDF 내보내기를 실행하자 save panel이 즉시 열렸다. 저장된 479 KiB PDF는 1페이지이며 raster 확인 결과 지도, 표와 텍스트가 비어 있지 않았다.

추가로 repository source를 바꾸지 않은 `/private/tmp` 진단 harness에서 같은 custom scheme WKWebView에 `pageCount`, `getPageSvg(page: 0)`, `exportHwp`를 차례로 호출했다. 세 응답과 SVG/PDF payload 검증이 모두 성공했다. 이 결과로 `v0.7.18` legacy `rhwp-request` 계약이 실제 제품 환경에서 동작함을 확인했다.

검증 중 font 선택 modal을 오래 유지한 뒤 한 차례 load timeout overlay가 나타났으나 Retry 후 정상 로드됐고 Host RPC 재현에는 영향이 없었다. PDF 내보내기와 직접 harness가 모두 통과했으므로 `v0.7.19`의 일관된 RPC timeout과는 구분한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 기능 코드는 새로 수정하지 않았다.
- Stage 2의 `v0.7.19` dependency/studio/provenance 변경을 `v0.7.18`로 되돌렸다.
- native artifact는 current source에서 재생성했지만 generated header와 15개 ABI는 동일하다.
- 계획·기술 문서는 최종 release candidate와 blocker 경계를 반영했다.
- Stage 1~3 보고서와 commit은 변경하지 않았다.
- generated Xcode project와 build/runtime output은 commit하지 않는다.
- 기존 `/Applications/Alhangeul.app`과 HOP provider는 변경하지 않았다.

검증 후 세 Debug app과 embedded Sparkle Updater의 LaunchServices 등록을 해제했다. `rhwp-mac-task422` 또는 `task422-v0718` 경로의 등록 잔여는 0건이며 PlugInKit에는 `/Applications/Alhangeul.app`의 공개 설치본 Preview/Thumbnail extension만 남아 있다.

## 검증 결과

| Gate | 결과 |
|------|------|
| `v0.7.19` Host RPC regression boundary | upstream `023041f5...`, blocker 확정 |
| upstream 이슈 | `edwardkim/rhwp#2396` OPEN |
| `v0.7.18` core/studio provenance | tag/commit/hash 일치 |
| Rust locked test와 15 ABI | 통과 |
| 앱 세 target build | 모두 BUILD SUCCEEDED |
| representative visual | 10/10 성공, size drift 0, content loss 없음 |
| Quick Look | 3/3 성공, HWP PNG/HWPX 9-page PDF, fallback 0 |
| Thumbnail | 24/24 성공, cache contract 유지 |
| 실제 custom scheme Host RPC | `pageCount`, `getPageSvg`, `exportHwp` 성공 |
| development registration cleanup | Task Debug app/provider/Updater 잔여 0 |

## 잔여 위험

- upstream #2396은 아직 해결되지 않았다. 수정이 포함된 새 stable tag 전까지 `v0.7.19`를 release input으로 사용하면 안 된다.
- `v0.7.19`의 문서 렌더 자체는 동작하므로 단순 open smoke만으로는 같은 회귀를 잡을 수 없다. 이후 studio sync gate에 실제 Host RPC 호출을 유지해야 한다.
- visual changed-percent는 local 단일 환경 측정이며 성능·화질 개선 주장에 사용하지 않는다.
- `KTX.hwp` Skia delta와 복학원서 layout 차이는 기존 known risk로 남는다.
- signed HOP exact UTI와 Finder routing은 public release의 blocking manual gate로 남는다.

## 다음 단계 영향

Stage 5는 release handoff의 expected core/studio를 `v0.7.18` / `93862a4e...`로 고정한다. `v0.7.19` 변경을 release note의 제공 기능으로 포함하지 않고, upstream #2396 해결과 새 stable tag를 다음 core sync의 선행 조건으로 기록한다.

PR #421은 녹색 CI와 관계없이 release blocker가 있는 automation candidate다. Task #422 PR merge가 확인된 뒤 superseded 사유와 upstream issue를 연결해 close하고 automation branch를 정리한다.

## 승인 요청

Stage 4의 `v0.7.19` blocker 판정과 `v0.7.18` release candidate 복원·검증 결과를 승인해 주시면 Stage 5 최종 보고와 `v0.1.8 (14)` release handoff를 작성한다.
