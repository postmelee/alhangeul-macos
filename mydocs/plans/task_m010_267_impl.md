# Task M010 #267 구현계획서

수행계획서: `mydocs/plans/task_m010_267.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다. `rhwp` upstream 반영, 앱 버전 갱신, release candidate 검증, PR 게시, tag 생성, GitHub Release 공개, Sparkle appcast/Pages 갱신, Homebrew Cask 공개 반영은 각 단계에서 명시 승인 없이 실행하지 않는다.

## 작업 개요

- 이슈: #267 rhwp v0.7.12 반영과 v0.1.3 public release 준비/배포
- 마일스톤: M010 (`v0.1`)
- 브랜치: `local/task267`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 직전 public app release: `v0.1.2`
- 현재 app source version/build: `0.1.2` / `8`
- 목표 app release 후보: `v0.1.3`
- 목표 build number 후보: `9`
- 현재 bundled `rhwp` 기준: `v0.7.11`, commit `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`
- 목표 bundled `rhwp` 기준: `v0.7.12`, commit `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`
- 목표 DMG: `alhangeul-macos-0.1.3.dmg`
- Sparkle stable feed: `https://postmelee.github.io/alhangeul-macos/appcast.xml`

## 승인된 기준

- 앱 release identity는 `Alhangeul v0.1.3`으로 유지하고, bundled `rhwp` 버전은 release metadata/provenance로 분리한다.
- `rhwp` Stable 기준은 release tag와 resolved commit을 사용한다. branch/floating ref는 배포 기준으로 쓰지 않는다.
- `devel`이 WebView-backed public release line의 기준 브랜치다.
- `Alhangeul.xcodeproj`는 생성물이다. 직접 수정하지 않고 `project.yml`과 source/resource를 기준으로 한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다.
- Homebrew Cask 공개 반영은 public DMG URL과 SHA256이 확정된 뒤 별도 승인으로 진행한다.
- Sparkle EdDSA private key, Apple credential, GitHub token 등 민감 정보는 문서, commit, shell output에 기록하지 않는다.

## 현재 확인 상태

2026-05-18 KST 기준으로 다음을 확인했다.

- `edwardkim/rhwp` 최신 GitHub release는 `v0.7.12`다.
- `v0.7.12` release publishedAt은 `2026-05-17T18:09:16Z`다.
- annotated tag `refs/tags/v0.7.12`는 commit `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`를 가리킨다.
- 현재 `rhwp-core.lock`과 bundled `rhwp-studio` manifest는 `v0.7.11` 기준이다.
- 현재 앱/Quick Look/Thumbnail extension `CFBundleShortVersionString`은 `0.1.2`, `CFBundleVersion`은 `8`이다.
- local tag 목록에는 `v0.1.2`, `v0.1.1`, `v0.1.0`이 있다.
- GitHub Release 최신 public release는 `Alhangeul v0.1.2`다.

## 구현 원칙

- core dependency 갱신은 `scripts/update-rhwp-core.sh --channel stable --tag v0.7.12`와 `scripts/build-rust-macos.sh --update-lock/--verify-lock` 절차를 우선 사용한다.
- `rhwp-core.lock`은 core source provenance와 generated bridge artifact metadata의 진실 원천으로 유지한다.
- bundled `rhwp-studio` asset provenance는 `Sources/HostApp/Resources/rhwp-studio/manifest.json`을 기준으로 한다.
- ABI surface 변화가 있으면 `rhwp-ffi-symbols.txt`, `Frameworks/generated_rhwp.h`, Swift bridge 영향 범위를 단계 보고서에 먼저 기록한다.
- public release 후보 source에는 public workflow 실행 뒤에만 알 수 있는 DMG SHA256, Sparkle EdDSA signature, notarization 결과를 미리 단정하지 않는다.
- PR merge 전에는 `local/task267`에서 단계 산출물과 source 변경을 커밋하고, `publish/task267 -> devel` PR로 통합한다.
- public release 실행은 release candidate commit이 `devel`과 `main` 경로에 반영되고 tag 대상 commit이 확정된 뒤 별도 승인으로 수행한다.

## Stage 1. Upstream release inventory와 compatibility gate 확인

### 목표

`rhwp v0.7.12` release의 실제 tag/commit, upstream 변경 범위, 앱 저장소의 현재 core/studio provenance, release workflow precondition을 조사하고 Stage 2 변경 범위를 고정한다.

### 작업

- `rhwp v0.7.12` GitHub release, annotated tag, resolved commit을 다시 확인한다.
- `v0.7.11..v0.7.12` upstream diff에서 Rust core, WASM/studio, sample, rendering, FFI 영향 path를 분류한다.
- `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.12`로 compatibility query를 실행한다.
- 현재 `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, bundled `rhwp-studio` manifest의 provenance를 정리한다.
- upstream sync PR 자동화가 이미 `v0.7.12` 후보 PR을 만들었는지 확인한다.
- release workflow input, expected `rhwp` tag, Pages/appcast precondition, tag 생성 경계를 확인한다.
- Stage 1 보고서에 실제 Stage 2 변경 파일 후보와 blocker를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m010_267_stage1.md`

Stage 1에서는 조사 보고서만 작성하고 source/resource는 수정하지 않는다.

### 검증

```bash
gh release view v0.7.12 --repo edwardkim/rhwp --json tagName,name,publishedAt,isDraft,isPrerelease,url
gh api repos/edwardkim/rhwp/git/ref/tags/v0.7.12
gh api repos/edwardkim/rhwp/git/tags/8c24aadd4942abef6c22918c91a0925c53a92706
git ls-remote --tags https://github.com/edwardkim/rhwp.git 'refs/tags/v0.7.12'
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.12
rg -n "v0\\.7\\.11|v0\\.7\\.12|a9dcdee|1899ef9|rhwp_release_tag|rhwp_commit|expected_rhwp_tag|Release Publish DMG" \
  rhwp-core.lock RustBridge Sources/HostApp/Resources/rhwp-studio .github/workflows scripts mydocs/manual mydocs/release README.md
git diff --check -- mydocs/working/task_m010_267_stage1.md
```

### 완료 기준

- Stage 1 보고서에 target release의 resolved commit, current provenance, expected changed areas, blocker가 기록된다.
- `rhwp v0.7.12`를 Stable release tag 기준으로 반영해도 되는지 compatibility check 결과가 기록된다.
- bundled `rhwp-studio` sync 필요 여부를 Stage 2에서 바로 실행할 수 있을 만큼 좁힌다.

### 커밋 메시지

```text
Task #267 Stage 1: rhwp v0.7.12 반영 범위 확정
```

## Stage 2. `rhwp v0.7.12` core와 studio provenance 갱신

### 목표

Rust core dependency, Cargo lock, generated bridge artifact metadata, bundled `rhwp-studio` resource provenance를 `rhwp v0.7.12` 기준으로 갱신하고, ABI/Swift bridge 영향이 있으면 같은 단계에서 적응한다.

### 작업

- `scripts/update-rhwp-core.sh --channel stable --tag v0.7.12`로 `RustBridge/Cargo.toml`과 `rhwp-core.lock` provenance를 갱신한다.
- `scripts/build-rust-macos.sh --update-lock`로 Rust bridge artifact와 lock metadata를 갱신한다.
- `RustBridge/Cargo.lock`의 `rhwp` source와 resolved commit을 확인한다.
- `Frameworks/generated_rhwp.h`, `Frameworks/universal/librhwp.a`, `rhwp-ffi-symbols.txt` 변화 여부를 확인한다.
- `scripts/sync-rhwp-studio.sh` 또는 자동 sync PR 산출물을 기준으로 bundled `rhwp-studio` resource가 `v0.7.12`를 가리키게 한다.
- `scripts/verify-rhwp-studio-assets.sh`로 manifest, entrypoint hash, relative asset path를 검증한다.
- ABI 또는 render tree JSON 변화가 있으면 `Sources/RhwpCoreBridge`와 관련 renderer를 필요한 범위에서 적응한다.
- Stage 2 보고서에 갱신 전/후 provenance matrix와 FFI 변화 판단을 기록한다.

### 예상 변경 파일

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `Frameworks/generated_rhwp.h`
- `Frameworks/universal/librhwp.a`
- `rhwp-ffi-symbols.txt` (변경 시)
- `Sources/HostApp/Resources/rhwp-studio/**`
- `Sources/RhwpCoreBridge/**` (적응 필요 시)
- `Sources/Shared/**` (render smoke 영향 적응 필요 시)
- `mydocs/working/task_m010_267_stage2.md`

### 검증

```bash
./scripts/update-rhwp-core.sh --channel stable --tag v0.7.12
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json
rg -n "v0\\.7\\.11|v0\\.7\\.12|a9dcdee|1899ef9|rhwp_release_tag|rhwp_commit|source_release_tag|source_resolved_commit" \
  rhwp-core.lock RustBridge Sources/HostApp/Resources/rhwp-studio rhwp-ffi-symbols.txt
git diff --check
```

GitHub-hosted CI나 local toolchain 차이로 `Frameworks/universal/librhwp.a` byte hash/size 검증만 실패하면 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1` 정책 적용 가능 여부를 분리해 기록한다. source provenance, Cargo lock, generated header, FFI symbol 검증은 계속 gate로 유지한다.

### 완료 기준

- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`이 `v0.7.12` resolved commit을 일관되게 가리킨다.
- generated header, FFI symbol set, staticlib reference metadata 변화가 의도적으로 기록된다.
- bundled `rhwp-studio` manifest와 resource tree가 `v0.7.12` 기준으로 검증된다.
- Swift/Rust bridge 적응이 필요한 경우 같은 단계에서 빌드 가능한 상태로 반영된다.

### 커밋 메시지

```text
Task #267 Stage 2: rhwp v0.7.12 core와 studio 갱신
```

## Stage 3. v0.1.3 version과 release communication source 정리

### 목표

앱/extension source version과 release communication source를 `v0.1.3` release candidate 기준으로 맞추고, upstream `rhwp` 변화와 알한글 앱 변화가 분리되어 안내되도록 작성한다.

### 작업

- HostApp, Quick Look extension, Thumbnail extension `Info.plist`를 `0.1.3` / build `9` 후보로 갱신한다.
- release rehearsal/publish workflow default와 expected `rhwp` tag 입력값을 `v0.1.3` / `v0.7.12` 기준으로 확인하고 필요한 경우 갱신한다.
- `scripts/ci/write-release-notes.sh` dry-run output을 생성하고 새 변경사항 구분 구조에 실제 후보 내용을 채운다.
- `mydocs/release/v0.1.3.md`를 작성하고 release candidate commit, rhwp core/studio provenance, 검증 예정 항목을 기록한다.
- README와 Pages release note/update index에 `v0.1.3` 공개 전 후보 문구가 필요한지 판단하고, 공개 전 과장 또는 stale URL이 생기지 않게 반영한다.
- public DMG URL, SHA256, GitHub Release URL, Sparkle signature처럼 아직 확정되지 않은 값은 pending 또는 workflow 결과 반영 예정으로 둔다.
- Homebrew Cask는 public DMG SHA256 확정 전까지 최종 digest를 넣지 않는다.
- Stage 3 보고서에 version matrix와 release note/provenance 작성 결과를 기록한다.

### 예상 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `.github/workflows/release-rehearsal.yml` (필요 시)
- `.github/workflows/release-publish.yml` (필요 시)
- `README.md` (필요 시)
- `docs/updates/v0.1.3.html` (필요 시)
- `docs/updates/index.html` (필요 시)
- `docs/index.html` (필요 시)
- `mydocs/release/v0.1.3.md`
- `mydocs/working/task_m010_267_stage3.md`

### 검증

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
bash -n scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh scripts/ci/write-release-delta-checklist.sh scripts/ci/write-sparkle-appcast.sh
scripts/ci/write-release-notes.sh 0.1.3 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.3.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.3.md
rg -n "0\\.1\\.2|0\\.1\\.3|8|9|v0\\.7\\.11|v0\\.7\\.12|a9dcdee|1899ef9|expected_rhwp_tag|전체 요약|포함된 rhwp 변화|알한글 앱 변화" \
  Sources .github/workflows README.md docs mydocs/release/v0.1.3.md build.noindex/release/release-notes-0.1.3.md
git diff --check
```

### 완료 기준

- app 본체와 두 extension의 version/build가 `0.1.3` / `9` 후보로 일치한다.
- release record 초안이 `rhwp-core.lock`과 bundled `rhwp-studio` manifest의 `v0.7.12` provenance를 기록한다.
- release note 후보가 `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`를 실제 변경 내용 기준으로 구분한다.
- public release 이후에만 확정되는 값이 source에 미리 단정되지 않는다.

### 커밋 메시지

```text
Task #267 Stage 3: v0.1.3 release metadata 정리
```

## Stage 4. Release candidate 로컬 검증과 rehearsal 준비

### 목표

public release workflow 실행 전에 source, core lock, bundled asset, Debug/Release build, render smoke, universal slice, release helper를 로컬에서 가능한 범위까지 검증한다.

### 작업

- Rust bridge lock verify와 AppKit boundary check를 반복한다.
- bundled `rhwp-studio` asset 검증을 반복한다.
- `xcodegen generate` 후 Debug/Release HostApp build를 수행한다.
- Release build 산출물의 app/extension universal slice를 검증한다.
- `validate-stage3-render.sh`로 native renderer smoke를 수행한다.
- release delta checklist와 release note helper를 `v0.1.2..HEAD` 기준으로 실행한다.
- 가능하면 `Release Rehearsal DMG` workflow 또는 local `./scripts/release.sh --skip-notarize 0.1.3` 후보를 실행한다. 실행하지 않으면 사유와 대체 검증을 기록한다.
- Finder Quick Look/Thumbnail smoke는 unsigned local app, signed rehearsal, public DMG 중 어떤 기준에서 실행했는지 분리해 기록한다.
- Stage 4 보고서에 통과/실패/미실행/다음 단계 이관 항목을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m010_267_stage4.md`
- `mydocs/release/v0.1.3.md` (검증 결과 보강)

### 검증

```bash
git status --short --branch
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
scripts/ci/verify-universal-macos-app.sh build.noindex/DerivedDataRelease/Build/Products/Release/Alhangeul.app
scripts/ci/write-release-delta-checklist.sh v0.1.2 HEAD build.noindex/release/delta-checklist-0.1.3.md
scripts/ci/write-release-notes.sh 0.1.3 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.3.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.3.md
git diff --check
```

선택 rehearsal 검증:

```bash
./scripts/release.sh --skip-notarize 0.1.3
hdiutil verify build.noindex/release/alhangeul-macos-0.1.3-rehearsal.dmg
```

### 완료 기준

- source-level release candidate 검증이 통과하거나, credential/GUI/hardware 의존 항목은 다음 단계로 명확히 이관된다.
- Release build 산출물에서 app 본체와 Quick Look/Thumbnail extension이 `arm64 + x86_64` universal slice를 가진다.
- render smoke와 release helper dry-run 결과가 stage report와 release record에 남는다.
- public release 실행 전 blocker가 명확하다.

### 커밋 메시지

```text
Task #267 Stage 4: v0.1.3 release candidate 검증
```

## Stage 5. 통합 PR handoff와 public release 실행

### 목표

작업지시자 승인 후 `publish/task267 -> devel` PR과 `devel -> main` release PR/tag 경계를 처리하고, protected release workflow로 signed/notarized public DMG, GitHub Release, Sparkle appcast, Pages deployment를 공개 URL 기준으로 검증한다.

### 작업

- Stage 4 결과를 기준으로 release candidate commit과 `devel` 통합 대상 PR 범위를 확정한다.
- `task-final-report` 절차 진입 전에 미커밋 변경이 없고 release record가 최신인지 확인한다.
- 작업지시자 승인 후 `publish/task267 -> devel` PR을 게시하고 PR CI를 확인한다.
- PR merge 확인 후 `devel`의 release candidate commit을 `main`으로 반영하는 release PR을 준비한다.
- 작업지시자 승인 후 `v0.1.3` tag를 생성하고 원격에 push한다.
- 작업지시자 승인 후 `Release Publish DMG` workflow를 실행한다.
  - `version=0.1.3`
  - `previous_release_ref=v0.1.2`
  - `expected_rhwp_tag=v0.7.12`
  - `require_latest_rhwp=true` unless release owner approves an exception
  - `draft=false`
  - `prerelease=false`
- workflow run summary와 artifacts를 확인한다.
- GitHub Release `v0.1.3`이 public 상태인지 확인한다.
- DMG asset과 `.sha256`을 내려받아 checksum, notarization, Gatekeeper, universal slice, legal resource 검증을 반복한다.
- public appcast URL이 `v0.1.3`, build `9`, Sparkle EdDSA signature, tag 고정 DMG URL, release notes URL을 포함하는지 확인한다.
- Pages latest download button과 release note URL을 확인한다.
- Homebrew Cask 공개 반영을 이번 task에서 이어갈지 작업지시자에게 별도 승인받는다.

### 예상 변경 파일

- `mydocs/release/v0.1.3.md`
- `mydocs/working/task_m010_267_stage5.md`
- `Casks/alhangeul-macos.rb` (Homebrew 반영 별도 승인 시)

### 검증

```bash
git status --short --branch
gh pr view --repo postmelee/alhangeul-macos --json number,state,mergeStateStatus,baseRefName,headRefName,url
gh workflow run "Release Publish DMG" \
  --repo postmelee/alhangeul-macos \
  --ref v0.1.3 \
  -f version=0.1.3 \
  -f previous_release_ref=v0.1.2 \
  -f expected_rhwp_tag=v0.7.12 \
  -f require_latest_rhwp=true \
  -f draft=false \
  -f prerelease=false
gh run list --repo postmelee/alhangeul-macos --workflow "Release Publish DMG" --limit 5
gh release view v0.1.3 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,isLatest,url,assets
gh release download v0.1.3 --repo postmelee/alhangeul-macos --pattern "alhangeul-macos-0.1.3.dmg*" --dir build.noindex/release/public-download
shasum -a 256 -c build.noindex/release/public-download/alhangeul-macos-0.1.3.dmg.sha256
hdiutil verify build.noindex/release/public-download/alhangeul-macos-0.1.3.dmg
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml -o build.noindex/release/public-download/appcast.xml
xmllint --noout build.noindex/release/public-download/appcast.xml
rg -n "0\\.1\\.3|sparkle:version>9<|edSignature|releases/download/v0\\.1\\.3|updates/v0\\.1\\.3\\.html" build.noindex/release/public-download/appcast.xml
git diff --check
```

mounted DMG/app verification:

```bash
mkdir -p build.noindex/release/mount-v0.1.3
hdiutil attach build.noindex/release/public-download/alhangeul-macos-0.1.3.dmg -mountpoint build.noindex/release/mount-v0.1.3 -nobrowse
codesign --verify --deep --strict --verbose=2 build.noindex/release/mount-v0.1.3/Alhangeul.app
xcrun stapler validate build.noindex/release/mount-v0.1.3/Alhangeul.app
spctl --assess --type execute --verbose=4 build.noindex/release/mount-v0.1.3/Alhangeul.app
scripts/ci/verify-universal-macos-app.sh build.noindex/release/mount-v0.1.3/Alhangeul.app
plutil -p build.noindex/release/mount-v0.1.3/Alhangeul.app/Contents/Info.plist | rg "CFBundleShortVersionString|CFBundleVersion|NSHumanReadableCopyright"
find build.noindex/release/mount-v0.1.3/Alhangeul.app/Contents/Resources/Legal -maxdepth 1 -type f | sort
diff -u LICENSE build.noindex/release/mount-v0.1.3/Alhangeul.app/Contents/Resources/Legal/LICENSE
diff -u THIRD_PARTY_LICENSES.md build.noindex/release/mount-v0.1.3/Alhangeul.app/Contents/Resources/Legal/THIRD_PARTY_LICENSES.md
diff -u Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md build.noindex/release/mount-v0.1.3/Alhangeul.app/Contents/Resources/Legal/FONTS.md
hdiutil detach build.noindex/release/mount-v0.1.3
```

### 완료 기준

- `publish/task267 -> devel` PR이 merge되고, release candidate commit이 `main`과 `v0.1.3` tag 기준으로 고정된다.
- `v0.1.3` GitHub Release가 draft/prerelease가 아닌 public release다.
- public DMG asset과 `.sha256` 검증이 통과한다.
- signed/notarized/stapled app과 DMG 검증이 통과한다.
- public Pages appcast가 `v0.1.3` item과 EdDSA signature를 제공한다.
- Pages latest download와 release notes URL이 public DMG asset을 가리킨다.
- Homebrew 공개 반영 여부와 handoff 정보가 기록된다.

### 커밋 메시지

```text
Task #267 Stage 5: v0.1.3 public release 게시
```

## Stage 6. 설치본 smoke, 최종 보고, 정리

### 목표

public `v0.1.3` 설치본을 사용자-facing 경로에서 확인하고, release record와 최종 결과보고서를 실제 결과 기준으로 정리한다.

### 작업

- 기존 public 설치본에서 Sparkle 수동 업데이트 감지와 update 후 version/build를 확인한다.
- public DMG clean install 경로에서 앱 실행, 문서 열기, 창 resize, About provenance 표시를 확인한다.
- Finder Quick Look preview와 thumbnail smoke를 public installed app 기준으로 수행한다.
- `scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.3 --expected-build 9` 기본 모드 실행 가능 여부를 확인하고 결과를 기록한다.
- Intel Mac 실기기 smoke 가능 여부를 확인하고, 미실행이면 사유를 기록한다.
- `mydocs/release/v0.1.3.md`에 public DMG SHA256, GitHub Release URL, Pages/appcast 결과, smoke 결과, 잔여 위험을 기록한다.
- `mydocs/report/task_m010_267_report.md`를 작성한다.
- `mydocs/orders/20260518.md`의 #267 상태를 완료 또는 다음 승인 대기 상태로 갱신한다.
- PR merge 후에는 `pr-merge-cleanup` 절차로 issue close, branch/worktree 정리를 수행한다.

### 예상 변경 파일

- `mydocs/working/task_m010_267_stage6.md`
- `mydocs/release/v0.1.3.md`
- `mydocs/report/task_m010_267_report.md`
- `mydocs/orders/20260518.md`

### 검증

```bash
mdls -name kMDItemVersion /Applications/Alhangeul.app
plutil -p /Applications/Alhangeul.app/Contents/Info.plist | rg "CFBundleShortVersionString|CFBundleVersion|NSHumanReadableCopyright"
open -a /Applications/Alhangeul.app "$PWD/samples/basic/KTX.hwp"
open -a /Applications/Alhangeul.app "$PWD/samples/hwpx/hwpx-01.hwpx"
pgrep -x Alhangeul
scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.3 --expected-build 9
scripts/smoke-finder-integration.sh --skip-package --app /Applications/Alhangeul.app --version 0.1.3
qlmanage -t -x samples/basic/KTX.hwp
qlmanage -t -x samples/hwpx/hwpx-01.hwpx
git diff --check
git status --short --branch
```

수동 확인:

- 기존 `v0.1.2` 설치본에서 Sparkle 업데이트 확인이 `v0.1.3`을 감지한다.
- `v0.1.3` 설치본에서 Sparkle 업데이트 확인이 최신 상태 또는 업데이트 없음 상태로 끝난다.
- `samples/basic/KTX.hwp`와 `samples/hwpx/hwpx-01.hwpx`가 열리고 창 resize 후 fatal fallback이 표시되지 않는다.
- Finder icon view에서 HWP/HWPX thumbnail이 생성된다.
- Quick Look preview가 raw error, hang, crash 없이 열린다.

### 완료 기준

- public installed app 기준 smoke 결과가 release record와 최종 보고서에 기록된다.
- `rhwp-core.lock`과 bundled `rhwp-studio` manifest의 `v0.7.12` provenance가 release body/record와 일치한다.
- GitHub Release, Pages latest download, Sparkle appcast가 같은 public universal DMG URL과 SHA256 기준으로 맞다.
- Homebrew Cask 공개 반영을 진행하지 않았다면 후속 승인/이슈 또는 handoff가 명확하다.
- 오늘할일 #267 상태가 실제 완료/후속 대기 상태와 일치한다.

### 커밋 메시지

```text
Task #267 Stage 6 + 최종 보고서: v0.1.3 release 완료
```

## 공통 주의사항

- 단계 승인 없이 다음 단계로 넘어가지 않는다.
- `Alhangeul.xcodeproj` 직접 수정은 하지 않는다.
- `build.noindex/`, `RustBridge/target/`, release download/mount 산출물은 git 추적 대상으로 넣지 않는다.
- local path Cargo override는 커밋하지 않는다.
- public release workflow, tag push, Pages/appcast deployment, 설치본 삭제, Homebrew Cask 공개 반영은 해당 단계에서 작업지시자 명시 승인 후 실행한다.
- 실패한 검증은 같은 단계 안에서 회복하고, 회복 전에는 단계 보고서와 커밋을 만들지 않는다.
- 이미 배포된 public release asset을 덮어써야 하는 상황이 생기면 즉시 중단하고 작업지시자에게 rollback 또는 respin 방향을 확인한다.

## 승인 요청 사항

1. 위 6단계 구현계획 승인
2. Stage 1 `Upstream release inventory와 compatibility gate 확인` 진행 승인
3. `v0.1.3` / build `9`를 release candidate 후보로 두고, Stage 3에서 실제 version/build source를 갱신하는 방향 승인
4. public release workflow와 tag 생성은 Stage 5에서 별도 승인 지점으로 유지하는 방향 승인
5. Homebrew Cask 공개 반영은 public DMG SHA256 확정 후 별도 승인 지점으로 유지하는 방향 승인
