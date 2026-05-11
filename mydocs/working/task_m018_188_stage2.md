# Task M018 #188 Stage 2 완료 보고서

## 단계 목적

`v0.1.1` release candidate source를 public release 직전 상태로 정리한다. 앱 본체와 Quick Look/Thumbnail extension의 bundle version/build를 `0.1.1` / `2`로 올리고, release workflow와 release helper 기본 입력·문서 기록을 `v0.1.1` 기준으로 맞춘다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Info.plist` | `CFBundleShortVersionString=0.1.1`, `CFBundleVersion=2` |
| `Sources/QLExtension/Info.plist` | `CFBundleShortVersionString=0.1.1`, `CFBundleVersion=2` |
| `Sources/ThumbnailExtension/Info.plist` | `CFBundleShortVersionString=0.1.1`, `CFBundleVersion=2` |
| `.github/workflows/release-publish.yml` | workflow dispatch default `version=0.1.1` |
| `.github/workflows/release-rehearsal.yml` | workflow dispatch default `version=0.1.1` |
| `scripts/smoke-finder-integration.sh` | Finder smoke helper default version/help text `0.1.1` |
| `scripts/release.sh` | help examples `0.1.1` |
| `README.md` | 최신 공개 릴리즈는 `v0.1.0`으로 유지하고, 다음 패치 후보 설명을 release workflow 정리까지 포함하도록 보정 |
| `mydocs/manual/build_run_guide.md` | public release line의 `release-tag` pin 기준과 `0.1.1` smoke/package 예시 반영 |
| `mydocs/release/v0.1.1.md` | Stage 2 source 상태, 선행 issue/PR merge 상태, 변경점 보강 |
| `mydocs/working/task_m018_188_stage2.md` | Stage 2 완료 보고 |

변경 통계:

```text
10 files changed, 37 insertions(+), 26 deletions(-)
```

위 통계는 단계 보고서 추가 전 source 변경분 기준이다.

## 본문 변경 정도 / 본문 무손실 여부

- 앱/extension plist의 version/build 값만 바꿨고 bundle identifier, document type, Sparkle feed/public key, legal notice는 변경하지 않았다.
- release workflow는 default input만 `0.1.1`로 바꿨고, `previous_release_ref=v0.1.0`, signing/notarization, GitHub Release publish, Sparkle appcast, Pages deployment logic은 변경하지 않았다.
- README는 `v0.1.1`을 최신 공개 릴리즈로 선언하지 않고, 여전히 `v0.1.0`을 최신 공개 릴리즈로 유지했다.
- `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.1.html`은 이미 `v0.1.1` latest DMG 후보 링크와 단일 universal DMG 안내를 포함하고 있어 수정하지 않았다.
- `Casks/alhangeul-macos.rb`는 아직 `version "0.1.0"` / `sha256 :no_check` 상태로 유지했다. public DMG SHA256이 Stage 4에서 확정된 뒤 `scripts/update-cask-sha256.sh`로 갱신한다.
- `docs/appcast.xml` tracked snapshot은 `v0.1.0` 상태로 유지했다. #206 이후 official stable appcast 검증 기준은 public Pages URL과 workflow artifact다.

## 변경 전/후 version matrix

| 대상 | 변경 전 | 변경 후 |
|------|---------|---------|
| HostApp `CFBundleShortVersionString` | `0.1.0` | `0.1.1` |
| HostApp `CFBundleVersion` | `1` | `2` |
| QLExtension `CFBundleShortVersionString` | `0.1.0` | `0.1.1` |
| QLExtension `CFBundleVersion` | `1` | `2` |
| ThumbnailExtension `CFBundleShortVersionString` | `0.1.0` | `0.1.1` |
| ThumbnailExtension `CFBundleVersion` | `1` | `2` |
| Release Publish DMG default `version` | `0.1.0` | `0.1.1` |
| Release Rehearsal DMG default `version` | `0.1.0` | `0.1.1` |
| `previous_release_ref` default | `v0.1.0` | `v0.1.0` 유지 |
| Finder smoke helper default | `0.1.0` | `0.1.1` |

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist` | OK | 세 plist 모두 `OK` |
| `ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'` | OK | Ruby `ffi-1.13.1` extension warning 출력, exit code 0 |
| `ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'` | OK | Ruby `ffi-1.13.1` extension warning 출력, exit code 0 |
| `bash -n scripts/smoke-finder-integration.sh scripts/release.sh scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh` | OK | 출력 없음 |
| `scripts/ci/write-release-notes.sh 0.1.1 000...000 build.noindex/release/release-notes-0.1.1.md` | OK | 64자 zero SHA dry-run |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1.md` | OK | `Release note template check passed` |
| `rg -n "0\\.1\\.0\|0\\.1\\.1\|CFBundleShortVersionString\|CFBundleVersion\|previous_release_ref\|Homebrew\|latest/download" ...` | OK | 의도된 `v0.1.0` 잔존은 직전 release, previous ref, appcast snapshot, Cask 미확정 상태 |
| `plutil -extract CFBundleShortVersionString raw -o - ...` | OK | 앱/extension 모두 `0.1.1` |
| `plutil -extract CFBundleVersion raw -o - ...` | OK | 앱/extension 모두 `2` |
| `git diff --check` | OK | 출력 없음 |

## 잔여 위험

- Stage 2는 source/version 정리 단계이므로 Debug/Release build, universal slice, legal resource bundle 포함은 아직 확인하지 않았다. 이는 Stage 3에서 수행한다.
- GitHub Pages source는 아직 `legacy`이고 `github-pages` environment의 `v*` tag policy도 아직 없다. Stage 4 전 별도 승인/설정 변경이 필요하다.
- `Casks/alhangeul-macos.rb`는 public DMG SHA256 확정 전이므로 아직 `0.1.0` / `sha256 :no_check`이다.
- `docs/appcast.xml`은 tracked `v0.1.0` snapshot이다. public stable appcast는 Stage 4 workflow/Pages URL로 검증한다.
- README는 public release 전 과장 방지를 위해 최신 공개 릴리즈를 `v0.1.0`으로 유지한다. `v0.1.1` 공개 완료 후 최종 보고/릴리즈 기록에서 실제 공개 상태로 보정한다.

## 다음 단계 영향

Stage 3에서는 다음 검증을 진행한다.

- Rust lock과 generated bridge artifact 정합성 확인
- `rhwp-studio` bundled asset 검증
- XcodeGen project generation
- Debug/Release build
- renderer smoke
- Release build 산출물의 app/extension universal slice 확인
- app bundle `NSHumanReadableCopyright`와 `Contents/Resources/Legal/*` 포함 확인

Stage 4 전에는 Stage 1에서 확인한 repository setting blocker를 다시 승인받아야 한다.

## 승인 요청

1. Stage 2 결과 승인
2. Stage 3 `Release candidate 로컬 검증` 진입 승인
3. Cask SHA256과 `docs/appcast.xml` stable item 갱신은 Stage 4 public DMG/appcast 확정 후 처리하는 방향 승인
