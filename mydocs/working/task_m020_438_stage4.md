# Task M020 #438 Stage 4 보고서

## 단계 목적

Stage 4의 목적은 current `devel`과 PR #436을 결합한 고정 후보에서 대표 HWP/HWPX 렌더, external sibling image, Quick Look/Thumbnail policy와 실제 설치본 Finder surface를 검증하고, upstream `v0.7.18..v0.8.2` 변화와 잔여 위험을 PR merge 및 public release 절차에 인계하는 것이다.

작업지시자가 별도로 승인한 actual Finder smoke까지 실행했다. 검증용 Release package는 current source version `0.1.8`을 identity로 사용했으며, 다음 public version을 확정하거나 public 서명·공증·배포를 수행하지 않았다.

## 산출물

| 산출물 | 결과 |
|--------|------|
| integration candidate | `/private/tmp/alhangeul-task438.7Mp2aG/integration-v2`, merge ref `2413549de446e63ab5605d5e3590841baea653fa` |
| upstream checkout | `/private/tmp/alhangeul-task438-upstream.nW7rLh/rhwp`, HEAD `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| external fixture copy | candidate의 `build.noindex/task438-external-valid/` |
| representative render | candidate의 `build.noindex/task438-stage4-render/` |
| Quick Look policy 결과 | candidate의 `build.noindex/task438-stage4-quicklook/summary.txt` |
| Thumbnail policy 결과 | candidate의 `build.noindex/task438-stage4-thumbnail/summary.txt` |
| Finder smoke Release app | candidate의 `build.noindex/release/Alhangeul.app` |
| 개발용 zip | candidate의 `build.noindex/release/alhangeul-macos-0.1.8.zip` |
| Finder smoke diagnostics | `/private/tmp/alhangeul-task438-finder-smoke/20260728-194356` |
| 최종 registration diagnostics | `/private/tmp/alhangeul-task438-stage4-registration-terminal/20260728-194949` |
| `mydocs/working/task_m020_438_stage4.md` | renderer, Finder surface, upstream 영향과 release handoff를 기록한다. |
| `mydocs/orders/20260728.md` | #438을 Stage 4 완료 및 최종 보고 승인 대기 상태로 갱신한다. |

`build.noindex/`와 `/private/tmp/` 산출물은 검증 근거이며 commit 대상이 아니다.

## 후보 identity와 무손실 상태

Stage 4 시작과 종료 시 확인한 identity는 다음과 같다.

| 구분 | SHA |
|------|-----|
| current `origin/devel` / candidate parent 1 | `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| corrected PR #436 head / candidate parent 2 | `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041` |
| merge candidate | `2413549de446e63ab5605d5e3590841baea653fa` |
| candidate tree | `cc12016b4feea0320449c6a7c749a400a603bca5` |
| upstream stable commit | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |

Release package 생성 중 `xcodegen generate`가 candidate의 stale tracked project에 Stage 3에서 확인한 151줄 generated diff를 다시 만들었다. 제품 source 변화가 아니며 `Alhangeul.xcodeproj/project.pbxproj` 한 파일만 candidate `HEAD` 원본으로 복구했다.

종료 시 candidate의 다음 출력은 모두 비어 있다.

```bash
git status --short
git diff --check
git diff --cached --check
```

`local/task438`에서는 `xcodegen generate`를 반복해도 변경이 없고 generated project SHA-256은 Stage 3과 같은 `3f54e0aa5bfc789fa8efd747b9cc7e33247f16fd935542acab590356f6514972`다.

## External sibling fixture

upstream `v0.8.2` checkout에서 다음 네 파일을 candidate의 ignored `build.noindex/` 아래로 복사했다. 과거 release fixture로 대체하거나 upstream checkout을 수정하지 않았다.

| 파일 | SHA-256 |
|------|---------|
| `hwp3-sample10-hwpx.hwpx` | `3395e19bebea8b6689f383df1f4ea1ddb253dee91c4320392cc40e90e2e4f191` |
| `oracle.gif` | `464e863dd2c1650fc6997b03a5d96c9413e61bbabaf7337c783db27203cc2761` |
| `rdb02.gif` | `bfadf4cdbbeeb5f3d8632cb54c8c3696977f405204b651f99a7a24c8f39532cf` |
| `s1.jpg` | `77dea18ce7f8f93b0931e133dec222aec642eef0ed87b8f2031b94dcbea5c514` |

Stage 2에서 고정한 upstream 원본 hash와 모두 일치했다.

## Representative renderer smoke

다음 명령을 고정 candidate에서 실행했다.

```bash
./scripts/validate-stage3-render.sh \
  build.noindex/task438-stage4-render \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/복학원서.hwp \
  samples/hwpx/hwpx-01.hwpx \
  samples/hwp-multi-001.hwp
```

| sample | pixel | text runs | Hangul runs | Hangul scalars | non-white pixels | 결과 |
|--------|-------|-----------|-------------|----------------|------------------|------|
| `KTX.hwp` | `1123x794` | 410 | 76 | 209 | 455,222 | PASS |
| `request.hwp` | `567x794` | 102 | 36 | 309 | 70,496 | PASS |
| `복학원서.hwp` | `794x1123` | 102 | 26 | 144 | 279,658 | PASS |
| `hwpx-01.hwpx` | `794x1123` | 269 | 118 | 440 | 130,536 | PASS |
| `hwp-multi-001.hwp` | `794x1123` | 279 | 113 | 409 | 139,569 | PASS |

가로 HWP, 세로 HWP, 다중 페이지 HWP와 HWPX 모두 first-page text/Hangul/non-white sanity를 통과했다.

## Quick Look policy smoke

```bash
./scripts/smoke-quicklook-skia-policy.sh \
  build.noindex/task438-stage4-quicklook \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx \
  build.noindex/task438-external-valid/hwp3-sample10-hwpx.hwpx
```

| sample | reply | pages | CoreGraphics | Skia decode | Skia direct | fallback |
|--------|-------|-------|--------------|-------------|-------------|----------|
| `KTX.hwp` | PNG | 1 | `cg:1` | `skia:1` | `skia:1` | 0 |
| `request.hwp` | PNG | 1 | `cg:1` | `skia:1` | `skia:1` | 0 |
| `hwpx-01.hwpx` | PDF | 9 | `cg:9` | `skia:9` | N/A | 0 |
| `hwp3-sample10-hwpx.hwpx` | PDF | 764 | `cg:764` | `skia:764` | N/A | 0 |

External fixture 결과는 다음과 같다.

| 항목 | 값 |
|------|----|
| document load | OK |
| external state | `attempted` |
| initial refs | 3 |
| injected | 3 |
| already loaded | 0 |
| missing | 0 |
| rejected / too large / permission denied | 모두 0 |
| read / bridge failure | 모두 0 |
| CoreGraphics output | 78,139,004 bytes, 764 pages |
| Skia decode output | 62,119,447 bytes, 764 pages |

764쪽 layout 과정에서 일부 페이지의 `LAYOUT_OVERFLOW` 진단이 반복됐으나 값은 6.3px 수준이고 command exit status, page count, backend, fallback과 external injection gate는 모두 통과했다. upstream source fixture를 수정하지 않았으며 이 진단만으로 사용자-visible 회귀를 식별하지 않았다.

## Thumbnail policy smoke

```bash
./scripts/smoke-thumbnail-skia-policy.sh \
  build.noindex/task438-stage4-thumbnail \
  samples/복학원서.hwp \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx \
  samples/hwp-multi-001.hwp
```

5개 sample에 CoreGraphics와 Skia opt-in 두 정책, 정책별 네 요청을 실행해 총 40개 행이 모두 통과했다.

| gate | 결과 |
|------|------|
| resolver missing/empty/invalid default | `coreGraphicsOnly`, PASS |
| `coreGraphics`, `coreGraphicsOnly` alias | PASS |
| `skia`, `skiaOptIn` alias | PASS |
| first `1024x1024` request | `miss` |
| same-size repeat | `exactHit` |
| `512x512`, `128x128` 후속 요청 | `largerBucketHit(1024x1024)` |
| CoreGraphics backend | 모든 sample `coreGraphics`, fallback 없음 |
| Skia backend | 모든 sample `skia`, fallback 없음 |
| policy cache signature 분리 | 5/5 PASS |

cache signature에는 보정된 `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` provenance가 포함됐다.

## Source-level registration hygiene

source-level smoke 전후 `--check-only` 결과에서 task candidate의 development registration과 legacy candidate는 없었다.

| 시점 | diagnostics | 결과 |
|------|-------------|------|
| smoke 전 | `/private/tmp/alhangeul-task438-stage4-registration-before/20260728-193533` | issue 없음 |
| source smoke 후 | `/private/tmp/alhangeul-task438-stage4-registration-after/20260728-193918` | issue 없음 |

task 전용 Debug app bundle은 `build.noindex/`에 남아 있으나 등록돼 있지 않다.

## Actual Finder smoke

### 실행 전 설치 상태

| 경로 | 상태 |
|------|------|
| `/Applications/Alhangeul.app` | `0.1.8 (14)`, 기존 설치본, code signature invalid |
| `/Users/melee/Applications/Alhangeul.app` | 없음 |

작업지시자에게 replacement와 registration 영향을 보고하고 별도 승인을 받은 뒤 사용자 Applications 경로만 smoke 대상으로 선택했다. `/Applications/Alhangeul.app`은 unregister, 교체 또는 삭제하지 않았다.

### Release package

계획 명령의 첫 strict 실행은 Stage 2와 동일하게 `librhwp.a` byte reference 한 항목에서 중단됐다.

| 항목 | lock expected | local actual |
|------|---------------|--------------|
| `librhwp.a` SHA-256 | `b35e935283f97c20d41f634f559e623ccd510f54f1341ca83d0f2108345a58eb` | `427e4b88300cb732c0c8986889f4ee45859a5a3e1c9a9f06569ac655d980e26f` |
| bytes | 212,505,600 | 212,514,296 |

generated header hash/size와 15개 FFI symbol은 일치했다. 구현계획에서 승인한 portable 판정에 따라 정적 아카이브 byte 비교만 제외해 개발/설치본 smoke package를 다시 생성했다.

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  ./scripts/package-release.sh 0.1.8
```

| 항목 | 결과 |
|------|------|
| source/Cargo/header/FFI verification | PASS |
| HostApp Release build | PASS, 34.042초 |
| HostApp architecture | `arm64 + x86_64` |
| Preview extension architecture | `arm64 + x86_64` |
| Thumbnail extension architecture | `arm64 + x86_64` |
| app version/build | `0.1.8 (14)` |
| zip bytes | 163,658,186 |
| zip SHA-256 | `f54fe69272d07cb12c2cd38f84cdec71cb6e0df694978da828755d5bc2191e3a` |

이 zip과 app은 개발/설치본 smoke 산출물이며 public GitHub Release, Sparkle enclosure 또는 Homebrew Cask 입력이 아니다.

### 설치와 headless thumbnail

```bash
./scripts/smoke-clean-quicklook-install.sh \
  --skip-package \
  --app build.noindex/release/Alhangeul.app \
  --install-app /Users/melee/Applications/Alhangeul.app \
  --output-dir /private/tmp/alhangeul-task438-finder-smoke \
  --sample samples/basic/KTX.hwp \
  --sample samples/hwpx/hwpx-01.hwpx \
  --sample build.noindex/task438-external-valid/hwp3-sample10-hwpx.hwpx
```

| sample | output | bytes | SHA-256 | 시각 확인 |
|--------|--------|-------|---------|-----------|
| `KTX.hwp` | `768x544` PNG | 346,047 | `cb8b3b3f40872d1b2658e1ce0ccb3ec628b205cd1a5a5fdfb7e0e951b0e4f1bf` | 노선도·운임표·한글 정상 |
| `hwpx-01.hwpx` | `543x768` PNG | 188,846 | `5d43725798a96458ed7535e54e67e810b34f5919643e57002563d756ac9d948d` | 제목·본문·표 정상 |
| external fixture | `543x768` PNG | 26,640 | `c359449491c2a8aeaa5e4c907c5f2c245a1f3edf193cf1891f6324fb4e886394` | non-empty text first page |

표준 helper는 fresh sample directory에 지정한 문서만 복사하므로 external fixture의 sibling image 세 개는 최초 thumbnail 입력에 포함되지 않았다. 같은 fresh directory에 `oracle.gif`, `rdb02.gif`, `s1.jpg`를 추가하고 cache reset 후 새 output directory에서 한 번 더 생성했다. 첫 페이지 PNG hash는 동일했다.

이 결과는 actual Thumbnail surface의 non-empty first-page output을 확인한 것이다. External reference 3건의 실제 injection/loaded/missing 계수는 instrumented Quick Look policy smoke에서 `3/3/0`으로 별도 확인했다. GUI `qlmanage -p`와 Finder Space preview는 자동 실행하지 않았으므로 public release의 수동 preview 확인을 대체하지 않는다.

설치된 `/Users/melee/Applications/Alhangeul.app`은 deep/strict codesign verification을 통과했다. smoke 시작 이후 `AlhangeulPreview`와 `AlhangeulThumbnail` 새 crash report는 0건이다.

### 활성 provider와 cleanup

최종 active provider는 다음 두 경로다.

```text
/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
/Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

Release build 과정에서 제거된 `build.noindex/release/xcodebuild/Alhangeul.app` 아래 Sparkle `Updater.app`의 LaunchServices 기록이 한 건 남았다. 표준 cleanup helper는 HostApp과 `.appex`를 해제하지만 삭제된 nested updater record는 제거하지 못했다.

task 전용 build 경로를 임시로 복원해 해당 nested `Updater.app` path만 `lsregister -u`로 해제하고 임시 복사본을 즉시 삭제했다. 전역 LaunchServices reset, 다른 타스크 등록 변경, 설치본 삭제는 수행하지 않았다.

최종 hygiene 결과:

| 항목 | 결과 |
|------|------|
| active provider root | `/Users/melee/Applications/Alhangeul.app` 한 곳 |
| task candidate development registration | 없음 |
| legacy app/extension candidate | 없음 |
| hygiene issue | 없음 |
| task Debug/Release bundle 파일 | `build.noindex/`에 존재, 등록되지 않음 |

## Upstream 변화 분류

PR #436은 기존 `v0.7.18`에서 `v0.8.2`로 이동하므로 `v0.7.19`, `v0.8.0`, `v0.8.1`, `v0.8.2` 누적 변화를 release handoff 대상으로 분류했다.

| 분류 | 주요 변화 | 알한글 영향 |
|------|-----------|-------------|
| bundled editor | 입력 지연·이미지 변환 메모화, 입력 clamp, 외부 연결 그림 표시, HWPX OLE 선택, undo/history 충실도, host save 완료 통지 | WKWebView viewer/editor의 반응성·편집 안정성 개선 후보. 저장·undo·OLE는 public release 수동 app smoke가 필요하다. |
| parser·import/export | HML open/save, HWPX/HWP5 왕복 속성 보존, 저장 무효화 계약, 손상 입력·과대 할당 방어, external image export 정합 | 문서 open과 변환 안정성 개선. CLI 전용 명령은 현재 macOS UI에 직접 노출되지 않는 범위를 구분한다. |
| renderer | 표·부동 개체 pagination, font fallback/metric, CanvasKit replay, 차트, HWP3 OLE/WMF, TAC와 바탕쪽 배치 정정 | HostApp, native Quick Look/PDF/Thumbnail에서 사용자-visible 개선 후보이며 대표 smoke는 통과했다. 전체 parity를 보증하지 않는다. |
| print/runtime asset | `print.html` 복구, 필수 runtime asset 누락 시 build fail gate | bundled app resource에 `print.html`이 포함되고 Stage 2~3 asset verification을 통과했다. 실제 app print/PDF UI는 release 수동 gate로 남긴다. |
| dependency·provenance | Rust dependency 갱신, wasm/toolchain·CI 정비, root `Cargo.lock` 변화 | core와 bundled studio가 동일 `v0.8.2` commit 및 lock fingerprint를 사용하는지 Stage 2에서 확인했다. |
| 알려진 upstream 문제 | studio PDF 안내 modal #3450, page-local repaint 계약 #3412 | 이번 native render/Finder smoke 범위에서 재현되지 않았으나 editor print/PDF와 장시간 편집 repaint 수동 확인 항목으로 유지한다. |

## PR #436 최종 상태와 권고

최종 GitHub 조회 결과:

| 항목 | 값 |
|------|----|
| state | `OPEN` |
| mergeable | `MERGEABLE` |
| merge state | `CLEAN` |
| base | `devel` / `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| head | `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041` |
| PR CI | 4개 job 모두 `SUCCESS` |

성공한 job은 `Classify changed files`, `Script syntax checks`, `macOS validation`, `Release helper checks`이며 workflow run은 `30348348728`이다.

Stage 1~4의 provenance, ABI/test, app target build, representative renderer, external injection, policy, 실제 Finder thumbnail과 registration 결과에서 PR #436을 보류할 blocking 회귀를 발견하지 않았다. 따라서 다음 경계로 권고한다.

1. PR #429와 PR #435는 닫힌 상태를 유지하고 PR #436만 upstream sync 후보로 merge한다.
2. PR #436 actual merge는 Task #438 최종 보고와 별도의 작업지시자 승인을 받은 뒤 수행한다.
3. Stage 3의 generated project correction은 PR #436에 넣지 않았으므로 Task #438 PR을 통해 `devel`에 별도 반영한다.
4. PR #436과 Task #438 PR merge가 모두 확인된 뒤 별도 Release Operations 이슈에서 다음 public version/build를 확정한다.

## 본문 변경 정도와 무손실 여부

Stage 4의 repository 변경은 다음 두 운영 문서로 제한된다.

| 파일 | 변경 |
|------|------|
| `mydocs/working/task_m020_438_stage4.md` | Stage 4 검증과 release handoff 신규 보고 |
| `mydocs/orders/20260728.md` | Stage 4 완료·최종 보고 승인 대기 상태 |

Swift/Rust source, project 설정, bundled asset, lock과 PR #436 head는 Stage 4에서 변경하지 않았다. 실제 제품 관련 tracked diff는 Stage 3에서 승인·커밋한 generated `Alhangeul.xcodeproj/project.pbxproj` 한 파일뿐이다.

## 검증 결과

| gate | 결과 |
|------|------|
| candidate base/head/tree identity | PASS |
| candidate/upstream tracked hygiene | PASS |
| representative first-page render | 5/5 PASS |
| Quick Look CoreGraphics/Skia policy | 4/4 sample PASS |
| external refs injected/missing | 3/0, PASS |
| external CoreGraphics/Skia 764 pages | PASS, fallback 0 |
| Thumbnail policy rows | 40/40 PASS |
| Thumbnail cache signature separation | 5/5 PASS |
| strict static archive reference | byte hash/size만 mismatch |
| portable source/header/FFI verification | PASS |
| Release universal app/extensions | 3/3 PASS |
| actual Finder thumbnail | 3/3 output 생성 |
| actual thumbnail visual sanity | 3/3 non-empty |
| installed app deep signature | PASS |
| new extension crash report | 0 |
| active provider | user Applications 한 곳 |
| final task development registration | 없음 |
| PR #436 current checks | 4/4 SUCCESS |
| PR #436 current merge state | `MERGEABLE` / `CLEAN` |

구현계획에서 blocking으로 정의한 source provenance, Cargo resolution, generated header/FFI, bundled asset, compile/link, test, renderer와 registration gate는 모두 통과했다. strict static archive 차이는 계획에서 허용한 non-blocking 조건에 정확히 한정되며 expected/actual 값을 release handoff에 유지한다.

## 잔여 위험과 public release handoff

- `librhwp.a` strict reference는 현재 local Rust/Xcode/build path에서 계속 다르다. lock을 임의 갱신하지 않으며 public workflow에서는 문서화된 portable gate와 exact source/header/FFI 결과를 함께 확인해야 한다.
- upstream #3450과 #3412는 이번 native/Finder smoke가 직접 다루지 않는다. public release 전 bundled editor의 open/edit/save/undo, print/PDF와 장문서 repaint 수동 smoke가 필요하다.
- actual smoke는 headless `qlmanage -t -x` thumbnail을 확인했다. Finder Space 또는 `qlmanage -p` preview 수동 확인은 실행하지 않았다.
- signed/notarized public DMG, Gatekeeper, DMG layout, Sparkle update, Homebrew Cask와 Intel 실기기 실행은 별도 release task의 gate다.
- `/Users/melee/Applications/Alhangeul.app`에는 locally signed `0.1.8 (14)` smoke 설치본이 남아 있고 현재 active provider다. public `/Applications` 설치본 검증 전 duplicate provider를 피하도록 별도 승인된 cleanup 또는 교체가 필요하다.
- 기존 `/Applications/Alhangeul.app`은 변경하지 않았고 실행 전 검사에서 signature invalid였다. public release task는 이 설치본을 signed/notarized candidate로 교체하는 절차와 영향을 다시 확인해야 한다.
- task 전용 integration/upstream checkout과 smoke diagnostics는 최종 보고와 PR 근거 확인에 필요하므로 아직 유지한다. Task #438와 PR #436 처리 완료 후 exact 경로를 확인해 정리한다.
- 자동 sync에서 `RhwpCoreBuildInfo` 누락을 막는 gate는 후속 Issue #439가 구현되기 전까지 수동 확인에 의존한다.

## 다음 단계 영향

Stage 4 승인 후 `mydocs/report/task_m020_438_report.md`에 Stage 1~4 전체 결과와 PR #436 merge 권고를 작성한다. 오늘할일 완료 시각은 최종 보고서 단계에서만 기록한다.

최종 보고서 승인 후 `task-final-report` 절차로 `publish/task438`을 push하고 `devel` 대상 Task #438 PR을 생성한다. Task #438 PR은 검증 문서와 generated project correction만 포함하며 PR #436의 core/studio product diff를 중복 포함하지 않는다.

Task #438 PR 게시, PR #436 actual merge, Task #438 PR merge와 public release 시작은 각각 계획서의 별도 승인 경계를 유지한다.

## 승인 요청

Stage 4 `Renderer·Finder surface 회귀와 release handoff`는 완료됐다.

PR #436 merge 권고와 public release handoff를 포함한 본 보고서를 검토하고, Task #438 최종 결과보고서 작성 단계 진입 승인을 요청한다.
