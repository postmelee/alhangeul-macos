# Task #438 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#438 rhwp v0.8.2 full sync와 최신 devel 통합 검증](https://github.com/postmelee/alhangeul-macos/issues/438) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 작업 브랜치 | `local/task438` |
| upstream sync 후보 | [PR #436 Sync rhwp upstream v0.8.2](https://github.com/postmelee/alhangeul-macos/pull/436) |
| 기준 통합 브랜치 | `devel` |
| 이전 core/studio | `v0.7.18` / `93862a4e16df59834ebce46d91e948cd739208e9` |
| 목표 core/studio | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| 단계 | Stage 1~4 |

PR #429와 PR #435의 중간 upstream sync 후보는 닫힌 상태로 유지하고, 누적 release 범위를 포함한 PR #436만 최신 `devel`과 결합해 검증했다.

핵심 결론:

- PR #436의 core lock, Rust dependency, generated build info와 bundled `rhwp-studio`는 모두 `v0.8.2`의 동일 resolved commit으로 정합화됐다.
- current `devel`의 Task #409 external image 경로와 결합한 Rust/Swift ABI, test, HostApp, Quick Look와 Thumbnail target build가 통과했다.
- representative HWP/HWPX render, CoreGraphics/Skia policy, external source-level injection, Release package 기반 실제 Finder thumbnail과 registration smoke가 통과했다.
- 검증에서 PR #436 merge를 보류할 blocking 회귀를 발견하지 않았다. PR #436은 유일한 upstream sync 후보로 merge 권고한다.
- public release는 아직 실행하지 않았다. PR #436과 Task #438 PR merge, 다음 version/build 확정, signed/notarized DMG와 수동 app/Finder gate는 별도 Release Operations 작업으로 진행해야 한다.

## 변경과 책임 경계

### PR #436

PR #436은 `devel`에 다음 제품 변경을 반영하는 upstream sync PR이다.

- `rhwp-core.lock`
- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`
- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`
- bundled `rhwp-studio` JS/CSS/WASM/font, entrypoint, manifest, service worker
- 신규 bundled runtime asset `print.html`

최종 changed file은 18개이며 PR metadata 기준 `+384 / -226`이다.

Stage 2에서 `RhwpCoreBuildInfo.swift`가 과거 `v0.7.18`에 남아 있는 blocking mismatch를 발견했다. 작업지시자 승인에 따라 release tag와 commit 두 상수만 보정한 commit을 기존 PR branch에 fast-forward push했다.

```text
e8d9b4acef5cc827207cc8fc676ccef7d4ce2041
Task #438 [Stage 2.1]: v0.8.2 core build info 정합화
```

`enabledFeatures`, renderer 동작, lock과 bundled asset은 이 보정에서 변경하지 않았다.

### Task #438

`local/task438`은 PR #436의 제품 diff를 복제하지 않는다. Task #438 PR에 포함할 제품 관련 변경은 Stage 3에서 발견하고 승인받은 generated project 정합화 한 파일이다.

| 파일 | 변경 |
|------|------|
| `Alhangeul.xcodeproj/project.pbxproj` | `project.yml`에 이미 선언된 `ExternalImageTests`와 Task #409 source 연결 생성, 151 additions |

`project.yml`이 진실 원천이며 generated file SHA-256은 `3f54e0aa5bfc789fa8efd747b9cc7e33247f16fd935542acab590356f6514972`다. 실제 Stage 3 test/build에 사용한 candidate generated project와 byte-identical하며 반복 `xcodegen generate` 뒤에도 변경이 없다.

나머지 Task #438 변경은 계획서, 단계 보고서, 최종 보고서와 오늘할일 기록이다.

### Task #438 PR 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Alhangeul.xcodeproj/project.pbxproj` | `project.yml` 기준 `ExternalImageTests` target과 Task #409 source/link 구성을 생성해 tracked project drift 해소 |
| `mydocs/plans/task_m020_438.md` | upstream sync 검증 목적, 범위, 위험과 잠정 단계 |
| `mydocs/plans/task_m020_438_impl.md` | 4단계 구현·검증 명령, 판정 규칙과 승인 경계 |
| `mydocs/working/task_m020_438_stage1.md` | PR/upstream identity, 최신 `devel` 결합과 CI refresh 판정 |
| `mydocs/working/task_m020_438_stage2.md` | core/studio provenance, PR #436 최소 보정, strict/portable artifact와 #439 분리 |
| `mydocs/working/task_m020_438_stage3.md` | Rust/Swift ABI·test, 세 app target build와 generated project 정합화 |
| `mydocs/working/task_m020_438_stage4.md` | renderer/policy, Release package, actual Finder smoke와 release handoff |
| `mydocs/report/task_m020_438_report.md` | Stage 1~4 최종 결과, PR #436 merge 권고와 public release 잔여 gate |
| `mydocs/orders/20260728.md` | #438 작업 등록, 단계 상태와 완료 시각 |

Task #438 PR은 위 9개 파일만 포함하며 PR #436의 18개 core/studio 제품 파일을 중복 포함하지 않는다.

## 최종 후보 identity

| 구분 | SHA |
|------|-----|
| current `devel` / candidate parent 1 | `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| corrected PR #436 head / candidate parent 2 | `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041` |
| local fetched merge ref | `2413549de446e63ab5605d5e3590841baea653fa` |
| candidate tree | `cc12016b4feea0320449c6a7c749a400a603bca5` |
| PR CI merge tree | `cc12016b4feea0320449c6a7c749a400a603bca5` |
| upstream stable commit | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |

GitHub PR CI의 synthetic merge commit과 local fetched merge ref는 commit SHA만 다르고 parent 쌍과 tree가 같다. 따라서 local Stage 2~4와 PR CI는 byte-identical 제품 source tree를 검증했다.

최종 candidate와 upstream checkout은 tracked working tree가 clean하며 candidate의 다음 검사는 모두 통과했다.

```bash
git status --short
git diff --check
git diff --cached --check
```

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행 계획 | `93d50e5` | 이슈·브랜치·오늘할일·검증 범위 등록 |
| 구현 계획 | `584c952` | 4단계 gate, 승인 지점과 release 경계 확정 |
| Stage 1 | `ae5a621` | PR/upstream identity, 최신 `devel` 결합 후보와 CI refresh 필요성 확정 |
| Stage 2 | `1ad4bf4` | core/studio provenance, generated artifact, PR CI 검증과 #439 분리 |
| Stage 3 | `a627fb1` | Rust/Swift ABI·test, 세 app target build와 generated project 정합화 |
| Stage 4 | `b39e133` | renderer/policy, actual Finder smoke와 release handoff |
| 최종 보고 | 이번 커밋 | 최종 결과, PR #436 merge 권고와 public release handoff |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 최종 |
|------|---------|------|
| core/studio release | `v0.7.18` | `v0.8.2` |
| resolved upstream commit | `93862a4e16df59834ebce46d91e948cd739208e9` | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| PR #436 changed files | 자동 생성 후보 17개 | build info 보정 포함 18개 |
| `RhwpCoreBuildInfo` | `v0.7.18` / `93862a4…` | `v0.8.2` / `9b16aa9…` |
| tracked Xcode project | `ExternalImageTests` 생성 항목 누락 | `project.yml`과 byte-stable, 151 additions |
| RustBridge external tests | 최신 core 결합 미검증 | 4/4 PASS |
| Swift ExternalImageTests | 최신 core 결합 미검증 | 24/24 PASS |
| representative renderer | 최신 결합 미검증 | 5/5 PASS |
| Quick Look external source-level | 최신 core 결합 미검증 | refs 3, injected 3, missing 0, 764 pages |
| Thumbnail policy | 최신 core 결합 미검증 | 40/40 PASS, fallback 0 |
| actual Finder thumbnail | 최신 결합 미검증 | 3/3 output, crash 0 |
| current merge-tree PR CI | 과거 base 결과 | current tree 4/4 SUCCESS |
| Task #438 PR 범위 | 없음 | 9 files, 2,572 insertions |

## Core와 bundled studio provenance

### Core source와 Cargo

| gate | 값 | 결과 |
|------|----|------|
| channel | `stable` | PASS |
| release tag | `v0.8.2` | PASS |
| resolved commit | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` | PASS |
| feature | `native-skia` | PASS |
| `RustBridge/Cargo.toml` | `tag = "v0.8.2"` | PASS |
| `RustBridge/Cargo.lock` | `v0.8.2#9b16aa9…` | PASS |
| upstream checkout HEAD | target commit과 동일 | PASS |
| build info | lock의 tag/commit/features와 동일 | PASS |

### Bundled studio

| 항목 | 확인값 |
|------|--------|
| release tag / commit | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| upstream root `Cargo.lock` SHA-256 | `64ff4041c1874c01c7a901b28df2639082836ced44df392cd37b3227d4772279` |
| copied files | 61 |
| copied bytes | 40,176,448 |
| JavaScript | `assets/index-DZp2UYI6.js` |
| stylesheet | `assets/index-CX93BaKm.css` |
| WASM | `assets/rhwp_bg-ftaI0hCm.wasm` |
| additional runtime entry | `print.html` |

manifest file hash, entrypoint, WASM, font, web manifest와 service worker precache graph가 실제 asset과 일치했다. HostApp Debug bundle에 복사된 resource도 같은 verification을 통과했다.

## Generated artifact의 strict/portable 판정

검증 환경:

| 도구 | 값 |
|------|----|
| host | arm64 Mac |
| Rust | `rustc 1.94.1`, `cargo 1.94.1` |
| cbindgen | `0.29.2` |
| Xcode | `26.6`, build `17F113` |

strict `./scripts/build-rust-macos.sh --verify-lock`은 universal library, generated header, 15개 FFI symbol과 XCFramework를 생성한 뒤 `librhwp.a` byte reference 한 항목에서만 실패했다.

| artifact | lock expected | local actual | 판정 |
|----------|---------------|--------------|------|
| `librhwp.a` SHA-256 | `b35e935283f97c20d41f634f559e623ccd510f54f1341ca83d0f2108345a58eb` | `427e4b88300cb732c0c8986889f4ee45859a5a3e1c9a9f06569ac655d980e26f` | byte mismatch |
| `librhwp.a` bytes | 212,505,600 | 212,514,296 | byte mismatch |
| generated header SHA-256 | `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5` | 동일 | PASS |
| generated symbol count | 15 | 15 | PASS |
| generated symbols SHA-256 | `91e21eb4203318fb8e22f8645ed7172d3514a7125429d2b5ae2b8013bf42ca4c` | 동일 | PASS |

같은 local static archive hash/size가 최초 후보와 보정 후보, Release package 시도에서 반복 재현됐다. source provenance, Cargo resolution, generated header와 symbol에는 drift가 없다.

구현계획에서 승인한 판정 규칙에 따라 static archive byte 비교만 제외한 portable gate를 실행했다.

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  ./scripts/build-rust-macos.sh --verify-lock
```

portable source/Cargo/header/FFI/XCFramework gate는 통과했다. lock의 static archive reference를 현재 local toolchain 값으로 임의 갱신하지 않았다.

## ABI, test와 app target

| 검증 | 결과 |
|------|------|
| `cargo fmt --check` | PASS |
| locked RustBridge tests | 4/4 PASS |
| `RhwpCoreBridge` AppKit/UIKit dependency boundary | PASS |
| build info와 core lock | PASS |
| ExternalImageTests | 24/24 PASS |
| HostApp Debug compile/link | PASS |
| QLExtension Debug compile/link | PASS |
| ThumbnailExtension Debug compile/link | PASS |
| HostApp bundled studio copy | PASS |
| embedded Preview/Thumbnail extension | PASS |

ExternalImageTests는 resolver/security policy 18개와 Swift bridge 6개다. status raw value, refs JSON, owned buffer lifetime, basename-only sibling policy, symlink escape, byte limit, privacy-safe summary와 Preview open contract를 포함한다.

HostApp dependency graph에서 Sparkle, Preview와 Thumbnail extension을 함께 compile/link했다. 앱 bundle에 두 `.appex`와 current bundled studio resource가 포함됐다.

## Renderer와 external image

### Representative render

| sample | first page | text runs | Hangul runs | Hangul scalars | non-white pixels |
|--------|------------|----------:|------------:|---------------:|-----------------:|
| `KTX.hwp` | `1123x794` | 410 | 76 | 209 | 455,222 |
| `request.hwp` | `567x794` | 102 | 36 | 309 | 70,496 |
| `복학원서.hwp` | `794x1123` | 102 | 26 | 144 | 279,658 |
| `hwpx-01.hwpx` | `794x1123` | 269 | 118 | 440 | 130,536 |
| `hwp-multi-001.hwp` | `794x1123` | 279 | 113 | 409 | 139,569 |

가로·세로·다중 페이지 HWP와 HWPX 다섯 fixture의 text/Hangul/non-white sanity가 모두 통과했다.

### Quick Look policy

| sample | reply | pages | CoreGraphics | Skia | fallback |
|--------|-------|------:|--------------|------|---------:|
| `KTX.hwp` | PNG | 1 | 1 | 1 | 0 |
| `request.hwp` | PNG | 1 | 1 | 1 | 0 |
| `hwpx-01.hwpx` | PDF | 9 | 9 | 9 | 0 |
| external fixture | PDF | 764 | 764 | 764 | 0 |

upstream `v0.8.2` checkout의 `hwp3-sample10-hwpx.hwpx`, `oracle.gif`, `rdb02.gif`, `s1.jpg`를 같은 candidate `build.noindex/` directory에 둔 source-level Preview smoke 결과:

| 항목 | 결과 |
|------|------|
| external refs | 3 |
| injected | 3 |
| missing | 0 |
| rejected / too large / permission denied | 모두 0 |
| read / bridge failure | 모두 0 |
| CoreGraphics | 764 pages, fallback 0 |
| Skia decode | 764 pages, fallback 0 |

### 실제 등록 Preview와의 경계

위 `3/3/0`은 source-level Preview orchestration 결과다. Task #438 actual Finder 자동 smoke는 headless Thumbnail을 실행했고 GUI `qlmanage -p` 또는 Finder Space Preview를 다시 실행하지 않았다.

Task #409에서 확인한 실제 registered Quick Look sandbox의 sibling access 결과는 macOS 26.5.2에서 `permissionDenied=3`, main document graceful fallback이다. Task #438은 entitlement 확대나 sandbox 우회 범위를 포함하지 않으므로 이 플랫폼 제한을 해결됐다고 표시하지 않는다.

## Thumbnail policy와 actual Finder smoke

### Policy

5개 representative sample에서 CoreGraphics와 Skia opt-in 두 정책, 정책별 네 요청을 실행했다.

| gate | 결과 |
|------|------|
| 전체 행 | 40/40 PASS |
| first large request | `miss` |
| same-size repeat | `exactHit` |
| medium/small after large | `largerBucketHit(1024x1024)` |
| CoreGraphics/Skia backend | 기대값 일치 |
| fallback | 0 |
| policy cache signature 분리 | 5/5 PASS |

cache signature에 보정된 `v0.8.2` / `9b16aa9…` provenance가 포함됐다.

### Release package

portable gate를 적용한 개발/설치본 smoke package 결과:

| 항목 | 결과 |
|------|------|
| HostApp Release build | PASS |
| app/Preview/Thumbnail architecture | 모두 `arm64 + x86_64` |
| app version/build | `0.1.8 (14)` |
| zip bytes | 163,658,186 |
| zip SHA-256 | `f54fe69272d07cb12c2cd38f84cdec71cb6e0df694978da828755d5bc2191e3a` |

이 package는 local Finder smoke 입력이며 public release asset이 아니다.

### 실제 설치본

작업지시자에게 영향을 보고하고 별도 승인받아 `/Users/melee/Applications/Alhangeul.app`에 local signed/sealed candidate를 설치했다. 기존 `/Applications/Alhangeul.app`은 변경하지 않았다.

| sample | output | bytes | 결과 |
|--------|--------|------:|------|
| `KTX.hwp` | `768x544` PNG | 346,047 | 노선도·운임표·한글 정상 |
| `hwpx-01.hwpx` | `543x768` PNG | 188,846 | 제목·본문·표 정상 |
| external fixture | `543x768` PNG | 26,640 | non-empty first page |

최종 상태:

- 설치된 app deep/strict signature verification 통과
- active Preview와 Thumbnail provider는 사용자 Applications 설치본 내부 경로
- smoke 시작 뒤 새 Preview/Thumbnail crash report 0건
- task candidate development registration 없음
- legacy app/extension candidate 없음
- `build.noindex/`의 Debug/Release bundle은 filesystem에만 있고 등록되지 않음

Release build 중 남은 Sparkle nested `Updater.app` LaunchServices record 한 건은 exact task path만 해제했다. 전역 LaunchServices reset, 다른 타스크 등록 변경과 app bundle 삭제는 수행하지 않았다.

## Upstream `v0.7.18..v0.8.2` 영향

PR #436은 `v0.7.19`, `v0.8.0`, `v0.8.1`, `v0.8.2`의 누적 변화를 포함한다.

| 분류 | 주요 변화 | 알한글 영향 |
|------|-----------|-------------|
| bundled editor | 입력 지연·이미지 변환 메모화, 입력 clamp, 외부 연결 그림 표시, HWPX OLE 선택, undo/history 충실도, host save 통지 | WKWebView viewer/editor의 반응성·편집 안정성 개선 후보 |
| parser·저장 | HML open/save, HWPX/HWP5 왕복 속성 보존, 저장 무효화 계약, 손상·과대 입력 방어 | document open/save 안정성 개선 후보 |
| renderer | 표·부동 개체 pagination, font fallback/metric, CanvasKit replay, 차트, HWP3 OLE/WMF, TAC·바탕쪽 배치 | HostApp, native Preview/PDF/Thumbnail 사용자-visible 개선 후보 |
| print/runtime | 누락된 `print.html` 복구, 필수 runtime asset gate | bundled resource와 service worker graph 검증 통과 |
| dependency·provenance | Rust dependency, wasm/toolchain, CI 정비 | core/studio 동일 tag/commit/fingerprint 확인 |
| 알려진 문제 | studio PDF 안내 modal #3450, page-local repaint #3412 | public release 수동 app smoke와 release note 입력으로 유지 |

CLI 전용 신규 기능은 현재 macOS UI에 직접 노출되는 기능과 구분한다. 이번 검증은 대표 회귀 신호이며 3,028개 upstream changed path의 전체 기능 parity를 보증하지 않는다.

## GitHub 최종 상태

### PR #436

| 항목 | 값 |
|------|----|
| state | `OPEN` |
| mergeable | `MERGEABLE` |
| merge state | `CLEAN` |
| base | `devel` / `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| head | `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041` |
| changed files | 18 |
| CI | 4/4 `SUCCESS` |

CI run [30348348728](https://github.com/postmelee/alhangeul-macos/actions/runs/30348348728)의 `Classify changed files`, `Script syntax checks`, `Release helper checks`, `macOS validation`이 모두 성공했다.

### Issue

| 이슈 | 상태 | 용도 |
|------|------|------|
| [#438](https://github.com/postmelee/alhangeul-macos/issues/438) | OPEN | 본 검증 타스크. Task #438 PR merge 뒤 close |
| [#439](https://github.com/postmelee/alhangeul-macos/issues/439) | OPEN | sync workflow의 build info 자동 갱신과 CI/release gate |

#439는 등록까지만 수행했다. 별도 branch, 계획서나 구현은 시작하지 않았다.

## Merge 권고와 순서

현재 근거로 PR #436 merge를 권고한다.

1. 본 최종 보고서 승인 후 `task-final-report` 절차로 `publish/task438`을 push하고 `devel` 대상 Task #438 PR을 생성한다.
2. Task #438 PR은 generated Xcode project correction과 검증 기록만 포함하고 PR #436 제품 diff를 중복 포함하지 않는다.
3. PR #436 actual merge는 작업지시자의 별도 승인 후 수행한다.
4. Task #438 PR도 검토·merge한다.
5. 두 PR merge가 확인된 뒤 별도 Release Operations 이슈에서 public version/build와 release candidate commit을 확정한다.
6. PR #436 merge 확인 전에는 public release tag, signing/notarization 또는 publish workflow를 시작하지 않는다.

PR #429와 PR #435는 닫힌 상태를 유지하며 재개하거나 중간 generated asset을 순차 merge하지 않는다.

## Public release handoff

다음 public release task에서 확인할 gate:

- PR #436과 Task #438 PR merge 및 clean release candidate commit
- 다음 public short version과 build number
- core/studio `v0.8.2` provenance와 portable/static archive 경계
- bundled editor open/edit/save/undo와 HWP/HWPX 대표 문서
- print/PDF UI와 upstream #3450 영향
- 장문서 편집·page-local repaint와 upstream #3412 영향
- Finder Space 또는 `qlmanage -p` 수동 Preview
- registered Preview의 external sibling `permissionDenied` graceful fallback
- signed/notarized public DMG, Gatekeeper와 DMG layout
- Sparkle update 및 extension refresh
- Homebrew Cask checksum/URL
- Intel Mac 실기기 실행 여부

현재 `/Users/melee/Applications/Alhangeul.app`에는 locally signed `0.1.8 (14)` smoke 설치본이 남아 있고 active provider다. public `/Applications` 설치 검증 전 duplicate provider를 피하도록 승인된 cleanup 또는 교체가 필요하다.

기존 `/Applications/Alhangeul.app`은 Task #438 실행 전 `0.1.8 (14)`이었고 code signature가 유효하지 않았다. Task #438은 이 설치본을 변경하지 않았다. public release task는 signed/notarized candidate 설치 영향을 다시 확인해야 한다.

## 범위 밖

- PR #436 actual merge
- Task #438 PR 생성·merge
- Issue #438 close
- upstream `edwardkim/rhwp` source 수정
- #439 자동화 구현
- external image entitlement/broker 또는 renderer placeholder 기능
- 다음 public version/build 결정
- release tag, GitHub Release와 asset upload
- Developer ID signing, notarization, public DMG
- Sparkle appcast, GitHub Pages와 Homebrew Cask

## 잔여 위험

| 항목 | 상태와 처리 |
|------|-------------|
| strict `librhwp.a` reference | local toolchain에서 byte hash/size mismatch. source/header/FFI portable gate 통과. lock을 임의 변경하지 않음 |
| upstream studio #3450 | PDF 안내 modal E2E 알려진 문제. public print/PDF 수동 gate 필요 |
| upstream studio #3412 | page-local repaint 계약 알려진 문제. 장문서 편집 smoke 필요 |
| actual external sibling access | registered Quick Look sandbox에서 Task #409 기준 `permissionDenied=3`; main document fallback 유지 |
| actual Preview visual | Task #438은 headless Thumbnail만 자동 실행. Finder Space/`qlmanage -p`는 release 수동 gate |
| local smoke 설치본 | 사용자 Applications에 남아 active provider. public 설치 검증 전 정리 필요 |
| `/Applications` 기존 설치본 | signature invalid 상태를 관찰했으나 변경하지 않음 |
| sync 재발 방지 | #439가 merge되기 전 `RhwpCoreBuildInfo` 정합성을 수동 확인해야 함 |
| task 임시 산출물 | integration/upstream checkout과 diagnostics는 PR 근거 확인 뒤 exact path로 정리 |

## 최종 상태

Task #438의 계획된 Stage 1~4 검증과 실제 Finder smoke는 완료됐다. PR #436은 current `devel`과 충돌 없이 결합되고 core/studio provenance, ABI, test, app target, representative renderer, external source-level injection, Thumbnail policy와 actual installed surface gate를 통과했다.

따라서 PR #436만 upstream sync 후보로 merge하는 것을 권고한다. public release는 PR merge와 별도 Release Operations 절차가 남아 있으므로 이번 완료 판정에 포함하지 않는다.

로컬 브랜치는 `local/task438`이며 원격 `publish/task438`, Task #438 PR, PR #436 merge와 public 배포는 아직 수행하지 않았다.

## 승인 요청

Task #438 최종 보고서와 PR #436 merge 권고를 검토하고 승인해 주시기 바란다.

승인 후 명시적으로 `task-final-report` 절차를 실행해 `publish/task438` push와 `devel` 대상 Open PR 게시를 진행한다.
