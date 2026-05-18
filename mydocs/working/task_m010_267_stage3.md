# Task M010 #267 Stage 3 완료 보고서

## 단계 목적

앱/extension source version과 release communication source를 `v0.1.3` release candidate 기준으로 맞추고, upstream `rhwp` 변화와 알한글 앱 변화가 분리되어 안내되도록 정리한다.

이번 단계에서는 public DMG, GitHub Release, stable Sparkle appcast, Homebrew Cask digest를 확정하지 않았다. 해당 값은 signed/notarized public workflow와 별도 승인 이후에만 기록한다.

## 산출물

| 파일 | 요약 |
|------|------|
| `Sources/HostApp/Info.plist` | HostApp version/build를 `0.1.3 (9)`로 갱신 |
| `Sources/QLExtension/Info.plist` | Quick Look preview extension version/build를 `0.1.3 (9)`로 갱신 |
| `Sources/ThumbnailExtension/Info.plist` | Finder thumbnail extension version/build를 `0.1.3 (9)`로 갱신 |
| `.github/workflows/release-rehearsal.yml` | default `version=0.1.3`, `previous_release_ref=v0.1.2`, `expected_rhwp_tag=v0.7.12` |
| `.github/workflows/release-publish.yml` | public publish default를 `v0.1.3` / `v0.7.12` 기준으로 갱신 |
| `.github/workflows/pr-ci.yml` | release helper dry-run 입력을 `0.1.3`, build `9`, `v0.1.2..HEAD` 기준으로 갱신 |
| `scripts/release.sh` | usage example을 `0.1.3` 기준으로 갱신 |
| `scripts/smoke-finder-integration.sh` | package smoke 기본 version을 `0.1.3`으로 갱신 |
| `scripts/smoke-clean-quicklook-install.sh` | local visual smoke 기본 version을 `0.1.3`으로 갱신 |
| `README.md` | 최신 release 요약과 bundled `rhwp` provenance를 `v0.1.3` / `v0.7.12` 기준으로 갱신 |
| `docs/index.html` | 최신 DMG link와 FAQ 문구를 `v0.1.3` 기준으로 갱신 |
| `docs/updates/index.html` | `v0.1.3` 릴리즈 노트 항목과 최신 DMG link 추가 |
| `docs/updates/v0.1.0.html`, `docs/updates/v0.1.1.html`, `docs/updates/v0.1.2.html` | 이전 버전 notice를 최신 `v0.1.3` 기준으로 갱신 |
| `docs/updates/v0.1.3.html` | 사용자용 `v0.1.3` Pages 릴리즈 노트 추가 |
| `THIRD_PARTY_LICENSES.md` | root third-party notice의 `rhwp` core/studio provenance를 `v0.7.12` 기준으로 갱신 |
| `Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md` | app bundle legal notice의 `rhwp` core/studio provenance를 `v0.7.12` 기준으로 갱신 |
| `mydocs/release/index.md` | `v0.1.3` 후보 행 추가 |
| `mydocs/release/v0.1.3.md` | 내부 release candidate 기록, GitHub Release 본문 구조 후보, 검증 예정 항목 추가 |
| `mydocs/working/task_m010_267_stage3.md` | Stage 3 수행과 검증 결과 기록 |
| `mydocs/orders/20260518.md` | #267 상태를 Stage 4 승인 대기로 갱신 |

## Version/build 기준

직전 public release는 `v0.1.2` build `8`이다. Sparkle update 비교를 위해 `v0.1.3` 후보 build는 `9`로 설정했다.

| 항목 | 값 |
|------|----|
| Short version | `0.1.3` |
| Build | `9` |
| Previous release ref | `v0.1.2` |
| Expected rhwp tag | `v0.7.12` |
| Expected rhwp commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` |
| Expected DMG name | `alhangeul-macos-0.1.3.dmg` |

## Release communication 정리

`mydocs/release/v0.1.3.md`와 `docs/updates/v0.1.3.html`에는 다음 구분을 반영했다.

| 구분 | 내용 |
|------|------|
| 전체 요약 | `rhwp v0.7.12` 반영, app/extension `0.1.3 (9)`, universal DMG 기준 유지 |
| 포함된 rhwp 변화 | core/studio tag와 commit, upstream tag message 기준 parser/viewer/WMF/HWP3/LTO 변화, FFI symbol set 유지 |
| 알한글 앱 변화 | workflow default, helper dry-run, third-party notices, Pages/README release surface 정리 |

`docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.3.html`의 DMG link는 public release 이후 활성화될 URL을 가리킨다. public GitHub Release asset이 올라가기 전에 Pages가 먼저 배포되면 해당 URL은 아직 유효하지 않을 수 있다.

## 의도적으로 미갱신한 항목

| 항목 | 이유 |
|------|------|
| `docs/appcast.xml` | stable Sparkle appcast는 public DMG length와 EdDSA signature가 있어야 확정 가능 |
| `Casks/alhangeul.rb` | Homebrew Cask는 public DMG SHA256 확정 후 고정해야 함 |
| GitHub Release body | `Release Publish DMG` workflow와 public asset 확정 후 생성해야 함 |
| public DMG SHA256 | signed/notarized public DMG artifact가 아직 없음 |

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist` | OK | 세 plist 모두 OK |
| `plutil -extract CFBundleShortVersionString/CFBundleVersion raw ...` | OK | HostApp, Preview, Thumbnail 모두 `0.1.3` / `9` |
| `ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { ... }'` | OK | 모든 workflow YAML parse 성공. Ruby `ffi-1.13.1` extension 경고만 출력 |
| `bash -n scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh scripts/ci/write-release-delta-checklist.sh scripts/ci/write-sparkle-appcast.sh scripts/release.sh scripts/smoke-finder-integration.sh scripts/smoke-clean-quicklook-install.sh` | OK | shell syntax 확인 |
| `./scripts/verify-rhwp-studio-assets.sh --tag v0.7.12 --commit 1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` | OK | Stage 2 bundled studio provenance 유지 확인 |
| `scripts/ci/write-release-notes.sh 0.1.3 0000...0000 build.noindex/release/release-notes-0.1.3.md` | OK | 64자 placeholder SHA256으로 release note dry-run 생성 |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.3.md` | OK | template check 통과 |
| `scripts/ci/write-release-delta-checklist.sh v0.1.2 HEAD build.noindex/release/delta-checklist-0.1.3.md` | OK | delta checklist dry-run 생성 |
| `scripts/ci/write-sparkle-appcast.sh --version 0.1.3 --build 9 ... --output build.noindex/release/appcast-0.1.3.xml` | OK | appcast helper dry-run 생성 |
| `xmllint --noout build.noindex/release/appcast-0.1.3.xml` | OK | appcast XML parse 통과 |
| `rg -n <version-provenance-pattern> ...` | OK | 변경 대상 표면에서 `0.1.3`, build `9`, `v0.7.12`, `1899ef9...`, release note 구분 heading 확인 |
| `git diff --check` | OK | 공백 오류 없음 |

## 본문 변경 정도 / 본문 무손실 여부

앱 source의 기능 구현 코드는 변경하지 않았다. 변경 범위는 version/build metadata, release workflow/helper 기본값, release communication 문서/Pages, third-party provenance notice에 한정했다.

`docs/updates/v0.1.0.html`, `docs/updates/v0.1.1.html`, `docs/updates/v0.1.2.html`의 기존 릴리즈 본문은 보존하고, 최신 버전 안내 notice와 링크만 `v0.1.3` 기준으로 갱신했다.

## 잔여 위험

- Pages/README의 `v0.1.3` DMG link는 public GitHub Release asset 게시 전에는 아직 유효하지 않을 수 있다.
- generated release note dry-run은 template 구조 검증용이며, GitHub Release 본문은 public workflow에서 실제 DMG SHA256과 release owner 보정 문구를 반영해야 한다.
- signed/notarized package, Debug/Release build, render smoke, Quick Look/Thumbnail installed smoke는 Stage 4 이후에서 확인해야 한다.
- Homebrew Cask는 public DMG SHA256 확정 전까지 `v0.1.2` public 기준을 유지한다.

## 다음 단계 영향

Stage 4에서는 release candidate 로컬 검증과 rehearsal 준비를 진행한다.

필수 확인:

- Rust bridge lock verify, AppKit boundary, bundled studio asset verify 반복
- `xcodegen generate` 후 Debug/Release HostApp build
- Release app/Preview/Thumbnail metadata가 모두 `0.1.3 (9)`인지 확인
- app/preview/thumbnail 실행 파일이 `arm64 + x86_64` universal인지 확인
- `validate-stage3-render.sh` native renderer smoke
- release helper delta checklist와 release note 후보 보정
- 가능 범위의 local rehearsal DMG와 Finder Quick Look/Thumbnail smoke

## 승인 요청

Stage 3 결과를 승인하면 Stage 4 `Release candidate 로컬 검증과 rehearsal 준비`로 진행한다.
