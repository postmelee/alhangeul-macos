# Task M900 #472 Stage 3 완료보고서

## 단계 목적

`v0.1.10 (16)` release candidate가 `rhwp v0.8.4` provenance, Rust/Swift 경계, 세 제품 target, 대표 renderer와 unsigned universal package 기준을 통과하는지 확인하고, 별도 승인된 exact candidate에서 Release Rehearsal DMG의 checksum, integrity와 layout을 검증한다.

## 검증 기준점

| 항목 | 값 |
|------|----|
| candidate branch | `local/task472` / `origin/publish/task472` |
| exact candidate commit | `95800eed4b2a631d2615203c3bed6cc1f7fa5d4e` |
| previous release ref | `v0.1.9` |
| app / extension | `0.1.10 (16)` |
| rhwp core / studio | `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| rehearsal run | [`31681525166`](https://github.com/postmelee/alhangeul-macos/actions/runs/31681525166) |
| 최신 공개 앱 | `v0.1.9`, non-draft / non-prerelease |
| 최신 upstream | `rhwp v0.8.4`, candidate lock과 일치 |

Stage 3 완료 시점에 `v0.1.10` tag와 `publish/task472` source PR은 없다. tracked worktree는 검증 시작 전 clean이었고, 문서 반영 전 검증 종료 시에도 clean이었다.

## Source preflight

### Core와 bundled studio provenance

| 검증 | 결과 |
|------|------|
| `rhwp-core.lock` | `v0.8.4` / `496333b2...` |
| `RustBridge/Cargo.lock` | 같은 upstream tag와 resolved commit |
| `RhwpCoreBuildInfo` | complete lock과 일치 |
| bundled studio manifest/assets | `v0.8.4` / `496333b2...`, ownership guard 포함 검증 통과 |
| upstream root `Cargo.lock` | SHA256 `217783dc...`, bundled manifest fingerprint와 일치 |
| shared Swift boundary | AppKit/UIKit 직접 의존 없음 |

exact upstream checkout은 unrelated Git LFS PDF의 smudge 오류를 냈지만 target commit과 root `Cargo.lock` checkout은 완료됐다. verifier는 checkout HEAD, manifest commit과 root `Cargo.lock` actual hash를 모두 확인해 통과했다. production build-info writer는 실행하지 않았고 verifier와 isolated writer/verifier fixture만 실행했다.

### Strict와 portable artifact 판정

`./scripts/build-rust-macos.sh --verify-lock`은 source, Cargo lock, generated header, FFI symbol과 XCFramework를 검증한 뒤 `Frameworks/universal/librhwp.a`의 byte hash/size 비교에서만 실패했다.

| 항목 | lock reference | local artifact |
|------|----------------|----------------|
| SHA256 | `8c8b831f69c17916fd734fe7aeb018662217ab715fcf7a8e124d930f8c2958be` | `65ee0ff3e4c36175a8d612daf9b138fa3e91c1faa0f19c948837ad89b9a679aa` |
| size | `219,489,584` bytes | `219,502,168` bytes |

local build 환경은 Rust/Cargo `1.94.1`, Xcode `26.6`, macOS `26.5.2`다. lock은 수정하지 않았다. 작업지시자 승인에 따라 문서화된 portable 경계인 다음 명령을 release artifact 기준으로 허용했고 통과했다.

```text
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  ./scripts/build-rust-macos.sh --verify-lock
```

이 옵션은 static archive byte hash/size 비교만 건너뛰며 source provenance, Cargo lock, generated header, FFI symbol과 universal XCFramework 검증은 유지한다. 유효 rehearsal workflow도 같은 경계를 명시적으로 사용했고 `Verify rhwp source, header, and ABI lock` step이 성공했다. strict mismatch는 성공으로 바꾸어 기록하지 않으며 lock reference를 local toolchain 결과로 갱신하지 않는다.

## Rust, Xcode와 renderer 검증

| 검증 | 결과 |
|------|------|
| `cargo fmt --check` | 통과 |
| RustBridge locked tests | `7/7`, 실패 0 |
| build-info fixture | 통과 |
| studio Cargo fingerprint fixture | 통과 |
| current/legacy render-tree decoder fixture | 통과 |
| HostAppTests | `128/128`, 실패 0 |
| ExternalImageTests | `27/27`, 실패 0 |
| `xcodegen generate` 2회 | project SHA256 `7d2246...`, tracked project drift 없음 |
| HostApp Release build | `BUILD SUCCEEDED` |
| QLExtension Release build | `BUILD SUCCEEDED` |
| ThumbnailExtension Release build | `BUILD SUCCEEDED` |
| representative renderer | HWP 4개 + HWPX 1개, page 1 PNG `5/5` |
| Quick Look policy | 대표 HWP/HWPX 3개 통과 |
| Thumbnail policy | 대표 문서 5개 통과 |

첫 Rust locked test 실행은 dependency index network 접근이 제한돼 source compile 전에 중단됐다. 동일 exact source에서 승인된 network 접근으로 다시 실행해 `7/7`이 통과했으므로 제품 또는 source 실패로 판정하지 않는다.

HostAppTests에는 HWP/HWPX format별 저장, 후속 저장, 재열기, page SVG 기반 PDF/인쇄 geometry와 문서 유래 SVG trust boundary 검증이 포함된다.

## Local universal package

`./scripts/package-release.sh 0.1.10`로 만든 local package는 다음과 같다.

| 항목 | 결과 |
|------|------|
| HostApp / Preview / Thumbnail version | 모두 `0.1.10 (16)` |
| HostApp architecture | `x86_64 + arm64` |
| Preview architecture | `x86_64 + arm64` |
| Thumbnail architecture | `x86_64 + arm64` |
| Legal | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` canonical byte 일치 |
| 개발용 zip | `168,266,275` bytes |
| 개발용 zip SHA256 | `77eccb21fab545bb777ea2034c4414c1d25d97d8b73010416f651ca69ec41979` |

이 package와 zip은 local unsigned 검증 산출물이며 public DMG, Sparkle enclosure 또는 Homebrew 입력이 아니다.

## Release helper

exact candidate `95800ee...`에서 다음 ignored 산출물을 다시 생성했다.

- `build.noindex/task472-stage3-release/pr-analysis-v0.1.10.md`
- `build.noindex/task472-stage3-release/delta-checklist-v0.1.10.md`
- `build.noindex/task472-stage3-release/release-notes-v0.1.10.md`

결과:

- previous release `v0.1.9`, candidate `95800ee...`로 고정
- merge PR 9개를 분석하고 PR #451 release transport를 신규 변화에서 분리
- release note template과 GitHub body validator 통과
- latest release notice와 version notice 통과
- `git diff --check` 통과

final `devel -> main` candidate가 Stage 4에서 이동하므로 PR analysis와 delta checklist는 release PR과 tag 직전에 다시 생성한다.

## Release Rehearsal DMG

별도 승인으로 exact commit `95800ee...`를 `origin/publish/task472`에 push하고 `Release Rehearsal DMG` workflow를 실행했다.

| 항목 | 값 |
|------|----|
| run | [`31681525166`](https://github.com/postmelee/alhangeul-macos/actions/runs/31681525166) |
| workflow / job | `Release Rehearsal DMG` / `Build rehearsal DMG` |
| conclusion | `success`, 12분 37초 |
| head branch / SHA | `publish/task472` / `95800eed4b2a631d2615203c3bed6cc1f7fa5d4e` |
| inputs | `0.1.10`, `v0.1.9`, `v0.8.4` |
| runner / Xcode | `macos-15-arm64` / Xcode `16.4` |
| DMG | `alhangeul-macos-0.1.10-rehearsal.dmg` |
| DMG size | `167,711,221` bytes |
| DMG SHA256 | `ee9a25bf882d5d37489efd67f0a73092070572bdf9964bc2ee19a2cbccd0dfdc` |
| `hdiutil verify` | `VALID`, CRC32 `$26E2ED5F`, 독립 재검증 통과 |
| app / extensions | 모두 `0.1.10 (16)`, `x86_64 + arm64` |
| signing | unsigned rehearsal, signing/notarization 근거로 사용하지 않음 |

Artifact [`9174001359`](https://github.com/postmelee/alhangeul-macos/actions/runs/31681525166/artifacts/9174001359)는 2026-08-27까지 14일 보관된다. GitHub Actions artifact archive digest `e2dbb675092fc59d90ba132f97676c3140cf53a8feda4a2cbbcad621b77bc8ba`는 DMG digest와 구분해 기록한다. artifact의 `.sha256`을 DMG actual hash와 독립 대조했고 `hdiutil verify`와 mounted layout을 다시 확인했다.

Mounted layout 확인:

| 항목 | 결과 |
|------|------|
| visible root | `Alhangeul.app`, `Applications` |
| Applications link | `/Applications` |
| background | `.background/alhangeul-dmg-background.png`, `720x460` |
| app/extension universal | 모두 통과 |
| 별도 설치 안내 파일 | 없음 |

rehearsal workflow에는 GitHub Release, Pages 또는 stable appcast deploy job이 없다. 실행 뒤에도 latest GitHub Release, public Pages 다운로드 링크와 Sparkle appcast는 `v0.1.9 (15)`를 유지했다.

## Extension registration hygiene

표준 cleanup으로 과거 개발 산출물 registration 제거를 시도하고 LaunchServices garbage collection을 실행했다. 일부 존재하는 `build.noindex` 경로의 inactive record는 `lsregister`가 `-10814`를 반환해 남아 있지만, 활성 PlugInKit provider는 `/Applications/Alhangeul.app`의 public `v0.1.9`이고 legacy app/extension provider는 없다.

전역 LaunchServices reset이나 설치본 삭제는 수행하지 않았다. clean GitHub Actions runner에서 생성한 rehearsal artifact의 provenance와 검증에는 이 local inactive record가 관여하지 않는다.

## 미실행 항목

rehearsal은 unsigned artifact이므로 다음을 성공으로 기록하지 않는다.

- Developer ID signing, notarization submit/wait, staple와 Gatekeeper
- draft 또는 official GitHub Release asset
- signed candidate의 registered Finder Quick Look/Thumbnail provider provenance
- HWP/HWPX 저장·재열기와 PDF·인쇄 수동 smoke
- `v0.1.9 -> v0.1.10` Sparkle update와 extension refresh
- official stable Pages/appcast와 Homebrew Cask
- Intel Mac 실기기 설치·실행

위 항목 중 signed candidate 수동 gate는 Stage 4, official public surface와 update는 Stage 5에서 별도 승인 후 수행한다.

## 판정

- Gate 2 source preflight와 Gate 3 Release Rehearsal 기준은 통과했다.
- exact candidate `95800ee...`와 run `31681525166`만 Stage 4 인계 근거로 사용한다.
- strict static archive mismatch는 숨기지 않고 승인된 portable source/Cargo/header/FFI/XCFramework 경계로 판정했다.
- source provenance, Rust/Swift tests, 세 target build, renderer와 local/rehearsal universal package가 통과했다.
- public GitHub Release, Pages와 stable appcast는 `v0.1.9 (15)`를 유지했다.
- Stage 4 진입을 막는 미해결 Stage 3 blocker는 없다.

## 승인 요청

Stage 3 완료 결과를 승인하고 다음 mutation인 Stage 3 보고 commit의 `publish/task472` push와 `devel` 대상 intermediate source PR 생성을 요청한다.

이후에도 다음 mutation은 각각 별도 승인 gate를 유지한다.

1. source PR CI/review 통과 뒤 merge
2. 필요 시 `main -> devel` back-merge PR 생성·merge
3. `devel -> main` release PR 생성·merge
4. exact release commit의 annotated `v0.1.10` tag 생성·push
5. `draft=true`, `prerelease=false` Publish workflow 실행
