# Task M010 #166 Stage 2 보고서

## 단계 목적

`v0.1.0` official release workflow를 실행하기 전에 로컬에서 가능한 release candidate 검증을 수행했다. 이 단계는 lock, bundled asset, Swift boundary, Debug/Release build, native render smoke, Finder integration smoke, unsigned rehearsal DMG 생성까지만 확인했다. `main` 반영, tag 생성, GitHub Release workflow 실행, 공증된 public DMG 게시, Homebrew Cask 변경은 수행하지 않았다.

## 산출물

### 문서 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m010_166_stage2.md` | Stage 2 로컬 검증 결과 기록 |
| `mydocs/orders/20260509.md` | #166 비고를 Stage 2 완료 후 Stage 3 승인 대기로 갱신 |

### 로컬 실행 산출물

| 경로 | 내용 |
|------|------|
| `Frameworks/Rhwp.xcframework` | 새 worktree에서 누락되어 `scripts/build-rust-macos.sh`로 재생성한 로컬 bridge framework |
| `Frameworks/universal/librhwp.a` | universal Rust static library |
| `Frameworks/generated_rhwp.h` | generated C ABI header |
| `build.noindex/release/Alhangeul.app` | Release package 기준 앱 번들 |
| `build.noindex/release/alhangeul-macos-0.1.0.zip` | Finder smoke package zip |
| `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg` | unsigned, not-notarized rehearsal DMG |
| `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256` | rehearsal DMG checksum |
| `/tmp/alhangeul-ql/task151-20260509-023309` | Finder integration smoke output |
| `/tmp/alhangeul-ql/task151-20260509-023309/diagnostics` | Finder integration smoke diagnostics |

## 본문 변경 정도 / 본문 무손실 여부

앱 소스, release workflow, Sparkle 설정, Pages asset, Homebrew Cask는 변경하지 않았다. 이번 단계의 tracked 변경은 Stage 2 보고서와 오늘할일 상태 갱신뿐이다.

새 worktree에는 `Frameworks/` 산출물이 없어서 `scripts/build-rust-macos.sh`를 먼저 실행했다. 이 재생성 결과는 ignored local build artifact이며 커밋 대상이 아니다.

## 검증 결과

### 작업트리 상태

```text
## local/task166...origin/devel-webview [ahead 3]
```

Stage 2 검증 시작 시점에는 Stage 1까지의 문서 커밋 3개만 `origin/devel-webview`보다 앞서 있었다.

### Rust bridge와 asset 검증

`Frameworks/` 누락 상태에서 `./scripts/build-rust-macos.sh`를 먼저 실행했고, 다음 산출물이 생성됐다.

```text
Frameworks/universal/librhwp.a
Frameworks/generated_rhwp.h
Frameworks/Rhwp.xcframework
```

확인된 FFI symbol:

```text
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_size
rhwp_render_page_svg
rhwp_render_page_tree
```

`./scripts/build-rust-macos.sh --verify-lock`는 sandbox 내부에서 Cargo lock write 제한으로 한 번 실패했고, 권한 승인 후 재실행해 성공했다.

```text
Verified: /Users/melee/Documents/projects/rhwp-mac-task166/rhwp-core.lock
```

`scripts/verify-rhwp-studio-assets.sh` 결과는 OK였다.

`./scripts/check-no-appkit.sh` 결과도 OK였다. `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존은 발견되지 않았다.

### Xcode project와 build

`xcodegen generate`는 성공했다.

Debug build:

```text
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [37.108 sec]
```

Release build:

```text
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/DerivedDataRelease CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [45.279 sec]
```

### native render smoke

`./scripts/validate-stage3-render.sh`는 exit code 0으로 완료됐다.

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=454739 png=.../output/stage3-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=69375 png=.../output/stage3-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=174843 png=.../output/stage3-render/exam_kor-page1.png
```

`KTX.hwp` 처리 중 `LAYOUT_OVERFLOW_DRAW`와 `LAYOUT_OVERFLOW` diagnostic log가 출력됐지만 smoke 기준에서는 non-fatal이며 PNG 생성과 pixel 검사는 통과했다.

### Finder integration smoke

기본 실행:

```text
scripts/smoke-finder-integration.sh --version 0.1.0
```

첫 실행은 Release package 생성 후 legacy provider 후보를 발견해 exit code 30으로 중단됐다. 파일 삭제는 수행하지 않았다.

```text
NOTICE: this smoke replaces /Users/melee/Applications/Alhangeul.app
ERROR: legacy app install candidates were found.
diagnostics: /tmp/alhangeul-ql/task151-20260509-023122/diagnostics
```

확인된 legacy 후보에는 `/Users/melee/Applications/AlhangeulMac.app`, 과거 `RhwpMac.app.disabled`, `알한글.app`, Xcode DerivedData 산출물이 포함됐다.

등록 격리 옵션으로 재실행:

```text
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app --unregister-legacy-candidates
```

결과:

```text
OK: Finder integration smoke passed
Installed app: /Users/melee/Applications/Alhangeul.app
Output: /tmp/alhangeul-ql/task151-20260509-023309
Diagnostics: /tmp/alhangeul-ql/task151-20260509-023309/diagnostics
```

생성된 preview PNG:

```text
/tmp/alhangeul-ql/task151-20260509-023309/hwp/KTX.hwp.png:       PNG image data, 512 x 363, 8-bit/color RGBA, non-interlaced
/tmp/alhangeul-ql/task151-20260509-023309/hwpx/hwpx-01.hwpx.png: PNG image data, 363 x 512, 8-bit/color RGBA, non-interlaced
```

수동 preview는 실행하지 않았다. smoke script가 안내한 수동 확인 후보는 다음과 같다.

```text
qlmanage -p /Users/melee/Documents/projects/rhwp-mac-task166/samples/basic/KTX.hwp
qlmanage -p /Users/melee/Documents/projects/rhwp-mac-task166/samples/hwpx/hwpx-01.hwpx
```

### package artifact

```text
111M build.noindex/release/Alhangeul.app
 58M build.noindex/release/alhangeul-macos-0.1.0.zip
```

zip SHA256:

```text
450496d6033301d20592b01bda803d3c6273a7d0bb1ce278141042b3f7ddff7b  build.noindex/release/alhangeul-macos-0.1.0.zip
```

이 zip은 Finder smoke package 산출물이며, official release asset으로 사용하지 않는다.

### rehearsal DMG

실행:

```text
./scripts/release.sh --skip-notarize 0.1.0
```

결과:

```text
WARN: Apple notarization is skipped. This rehearsal artifact is not a public release.
** BUILD SUCCEEDED ** [24.962 sec]
WARN: Skipping codesign verification because this rehearsal build is unsigned.
created: /Users/melee/Documents/projects/rhwp-mac-task166/build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
WARN: Skipping DMG signing because this rehearsal build is unsigned.
INFO: Verifying rehearsal DMG
hdiutil: verify: checksum of "/Users/melee/Documents/projects/rhwp-mac-task166/build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg" is VALID
INFO: Writing sha256 checksum
WARN: Rehearsal artifact complete. Do not use it for public release or Homebrew Cask.
```

checksum 검증:

```text
alhangeul-macos-0.1.0-rehearsal.dmg: OK
```

별도 `hdiutil verify` 재검증:

```text
hdiutil: verify: checksum of "build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg" is VALID
```

크기:

```text
63M build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
```

DMG SHA256:

```text
defb635938cdd5bcd9d94b5bf829e4fee0df30f43d76d77365d55efd0641ef5e  alhangeul-macos-0.1.0-rehearsal.dmg
```

이 DMG는 unsigned, not-notarized rehearsal artifact이며 public release, Sparkle appcast enclosure, Homebrew Cask digest로 사용할 수 없다.

## 잔여 위험

- Stage 1에서 확인한 대로 GitHub Actions `release` environment와 required secrets/variables가 아직 준비되지 않았다. 이 상태에서는 Stage 4 official signed/notarized release가 blocked다.
- `main`은 아직 release source와 정렬되지 않았고, default branch에 release workflow가 노출되지 않은 상태다. Stage 3에서 release source와 `main` 반영 방식을 결정해야 한다.
- 이번 단계의 DMG는 `--skip-notarize` rehearsal 결과다. Developer ID signing, notarization, Sparkle appcast signing, GitHub Release asset 검증은 Stage 4에서만 확인 가능하다.
- legacy Quick Look provider 후보가 로컬 환경에 남아 있었다. smoke 재실행에서는 등록 격리 옵션으로 통과했지만, 파일 삭제나 사용자 환경 정리는 수행하지 않았다.
- 수동 `qlmanage -p` preview 확인은 실행하지 않았다.

## 다음 단계 영향

Stage 2 로컬 build/render/package/Finder smoke/rehearsal 검증은 통과했다. Stage 3에서는 release source commit을 확정하고 `main` 반영 및 `v0.1.0` tag 준비로 넘어갈 수 있다.

Stage 3 진입 전에 결정해야 할 항목은 release source 전략이다. 기본 후보는 Stage 2 보고서 커밋을 포함한 `local/task166` HEAD이며, 이 경우 앱 binary surface는 `origin/devel-webview`와 동일하고 #166 계획/보고 문서만 추가된다. 순수 `origin/devel-webview` commit을 release source로 삼을 수도 있지만, 그러면 #166 Stage 보고서는 release source 밖에 남는다.

## 승인 요청

Stage 2 `release candidate 로컬 검증과 rehearsal`을 완료했다. 다음 단계로 Stage 3 `release ref 확정과 main/tag 준비`를 진행할지 승인 요청한다.
