# Task M018 #188 구현계획서

수행계획서: `mydocs/plans/task_m018_188.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다. GitHub Release 공개, Pages/appcast 갱신, tag 생성, 설치본 삭제는 각 단계에서 명시 승인 없이 실행하지 않는다.

## 작업 개요

- 이슈: #188 v0.1.1 patch release 준비와 public 배포 실행
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task188`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 직전 public release: `v0.1.0`
- 목표 release: `v0.1.1`
- 목표 build number: `2` 이상
- 목표 DMG: `alhangeul-macos-0.1.1.dmg`
- Sparkle update source: `https://postmelee.github.io/alhangeul-macos/appcast.xml`

## 확인된 현재 상태

2026-05-10 KST 기준으로 다음을 확인했다.

- `v0.1.1` GitHub Release는 아직 존재하지 않는다.
- M018 milestone에서 #183, #184, #185, #186, #187, #198, #199, #206, #208, #212, #215는 closed 상태다.
- #209는 #188에서 public DMG URL과 SHA256을 확정한 뒤 진행할 Homebrew tap 공개 배포 이슈로 open 상태다.
- `Sources/HostApp/Info.plist`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist`의 `CFBundleShortVersionString`은 아직 `0.1.0`이다.
- `Casks/alhangeul-macos.rb`는 `version "0.1.0"`과 `sha256 :no_check` 상태다.
- `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.1.html`은 `v0.1.1` latest DMG 후보 링크를 이미 포함한다.
- `Release Publish DMG` workflow는 `actions/upload-pages-artifact@v5`와 `actions/deploy-pages@v5` 경로를 갖고 있다.
- repository Pages API는 아직 `build_type=legacy`, source `main` / `/docs`다.
- `github-pages` environment는 custom branch policies를 사용하며 현재 `devel-webview`, `gh-pages`, `main`, `publish/task135` branch만 허용한다. `v*` tag policy는 없다.
- #215 handoff comment에 따라 public DMG 안의 `NSHumanReadableCopyright`와 `Contents/Resources/Legal/{LICENSE,THIRD_PARTY_LICENSES.md,FONTS.md}`를 signed/notarized DMG 기준으로 반복 확인해야 한다.

## 구현 원칙

- public release 실행 전에는 기존 `v0.1.0` 설치본을 삭제하지 않는다.
- version/build 증가와 release communication 변경은 tag 후보 commit에 포함될 source 변경으로 다룬다.
- `Alhangeul.xcodeproj`는 생성물이다. 직접 수정하지 않고 `project.yml`과 source plist/resource를 기준으로 한다.
- `docs/appcast.xml` tracked snapshot과 public Pages appcast를 혼동하지 않는다. official stable appcast 성공 기준은 workflow artifact, `deploy-pages` job, public URL이다.
- public release tag는 release owner가 확정한 commit에만 만든다. 기본 원칙은 #188 변경이 통합 브랜치와 release branch/main 경로에 반영된 commit을 대상으로 한다.
- Pages source `workflow` 전환과 `github-pages` `v*` tag policy 추가는 repository setting 변경이므로 별도 승인 후 실행한다.
- Homebrew tap 공개 배포는 #209 범위다. 이번 작업에서는 Cask SHA256을 확정하고 handoff를 남긴다.
- Sparkle EdDSA private key, Apple credential, GitHub token 등 민감 정보는 문서와 shell output에 기록하지 않는다.

## Stage 1. Release preflight와 repository setting 승인 항목 확정

### 목표

release candidate 작업 전에 선행 이슈, 현재 version/build, Pages/appcast repository setting, 기존 설치본 smoke 순서를 고정하고, public release 전에 필요한 별도 승인 항목을 단계 보고서로 분리한다.

### 작업

- M018 milestone issue 상태와 #188 comment를 다시 확인한다.
- `v0.1.1` GitHub Release/tag 존재 여부를 확인한다.
- 현재 source version/build 값과 release workflow default 입력값을 조사한다.
- Pages source와 `github-pages` environment policy를 GitHub API로 확인한다.
- release tag 대상 원칙을 정리한다.
  - #188 변경이 통합 브랜치와 release branch/main 경로에 반영된 commit이어야 한다.
  - 필요한 경우 `devel-webview -> main` release PR/merge checkpoint를 별도 승인 항목으로 둔다.
- public release 전 별도 승인 필요 항목을 Stage 1 보고서에 명시한다.
  - Pages source `legacy` -> `workflow`
  - `github-pages` environment tag policy `v*`
  - `v0.1.1` tag 생성
  - `Release Publish DMG` workflow `draft=false`, `prerelease=false` 실행
  - 기존 `v0.1.0` 설치본 삭제 범위

### 예상 변경 파일

- `mydocs/working/task_m018_188_stage1.md`

### 검증

```bash
git status --short --branch
gh issue list --repo postmelee/alhangeul-macos --milestone v0.1.1 --state all --json number,title,state
gh issue view 188 --repo postmelee/alhangeul-macos --comments
gh release view v0.1.1 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,url || true
gh api repos/postmelee/alhangeul-macos/pages
gh api repos/postmelee/alhangeul-macos/environments/github-pages
gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies
rg -n "CFBundleShortVersionString|CFBundleVersion|0\\.1\\.0|0\\.1\\.1" \
  Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist \
  .github/workflows README.md docs Casks/alhangeul-macos.rb mydocs/release/v0.1.1.md
git diff --check
```

### 완료 기준

- Stage 1 보고서에 release preflight 결과와 별도 승인 항목이 기록된다.
- Pages/appcast 실행 전 repository setting blocker가 명확하다.
- 기존 `v0.1.0` 설치본을 아직 보존해야 한다는 점이 stage report에 기록된다.

### 커밋 메시지

```text
Task #188 Stage 1: release preflight와 승인 항목 확정
```

## Stage 2. Version/build와 release communication source 정리

### 목표

release candidate source를 `v0.1.1` 기준으로 고정한다. 앱/extension bundle version, workflow default, README/Pages/release 기록 후보 문구를 public release 직전 상태로 맞춘다.

### 작업

- `Sources/HostApp/Info.plist`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist`를 갱신한다.
  - `CFBundleShortVersionString=0.1.1`
  - `CFBundleVersion=2`
- `Release Publish DMG`와 `Release Rehearsal DMG` workflow default `version`을 `0.1.1`로 갱신하고 `previous_release_ref`는 `v0.1.0` 유지 여부를 확인한다.
- 필요 시 `scripts/smoke-finder-integration.sh` default version과 관련 manual 예시를 `0.1.1` 기준으로 갱신한다.
- README 최신 공개 release 섹션을 `v0.1.1` public candidate 기준으로 보정한다.
- `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.1.html`의 latest URL, 설치 안내, Homebrew 공개 전 안내를 확인하고 필요한 후보 문구를 보정한다.
- `mydocs/release/v0.1.1.md`에 release candidate commit 후보, 선행 PR 상태, Stage 2 변경 사항을 기록한다.
- `Casks/alhangeul-macos.rb`는 public DMG SHA256이 나오기 전까지 고정 SHA를 넣지 않는다. version 변경도 Stage 4의 `scripts/update-cask-sha256.sh`로 처리하는 것을 기본으로 한다.
- Stage 2 보고서에 변경 전/후 version matrix를 기록한다.

### 예상 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `.github/workflows/release-publish.yml`
- `.github/workflows/release-rehearsal.yml`
- `scripts/smoke-finder-integration.sh` (필요 시)
- `README.md`
- `docs/index.html`
- `docs/updates/index.html`
- `docs/updates/v0.1.1.html`
- `mydocs/manual/build_run_guide.md` (필요 시)
- `mydocs/manual/ci_workflow_guide.md` (필요 시)
- `mydocs/release/v0.1.1.md`
- `mydocs/working/task_m018_188_stage2.md`

### 검증

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
bash -n scripts/smoke-finder-integration.sh scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh
scripts/ci/write-release-notes.sh 0.1.1 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.1.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1.md
rg -n "0\\.1\\.0|0\\.1\\.1|CFBundleShortVersionString|CFBundleVersion|previous_release_ref|Homebrew|latest/download" \
  Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist \
  .github/workflows scripts README.md docs mydocs/release/v0.1.1.md
git diff --check
```

### 완료 기준

- 앱 본체와 두 extension의 version/build가 `0.1.1` / `2`로 일치한다.
- workflow default가 `v0.1.1` release 실행에 맞다.
- README/Pages/release 기록이 Homebrew 공개 전 상태와 단일 universal DMG 기준을 일관되게 안내한다.
- release note template 검증이 통과한다.

### 커밋 메시지

```text
Task #188 Stage 2: v0.1.1 version과 release 문서 정리
```

## Stage 3. Release candidate 로컬 검증

### 목표

public release workflow 실행 전에 source, lock, asset, build, universal slice, legal notice 기준을 로컬에서 가능한 범위까지 확인한다.

### 작업

- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, generated bridge artifact 정합성을 확인한다.
- `rhwp-studio` bundled asset manifest와 실제 resource tree를 확인한다.
- XcodeGen project generation과 Debug/Release build를 수행한다.
- Release build 산출물의 app/extension universal slice를 검증한다.
- Debug 또는 Release app bundle의 `NSHumanReadableCopyright`와 `Contents/Resources/Legal/*` 포함을 확인한다.
- renderer smoke와 Finder integration smoke의 실행 가능 범위를 분리한다.
  - renderer smoke는 source-level local gate로 실행한다.
  - Finder integration은 signed/sealed Release package 또는 public DMG 기준이 필요하므로 Stage 5에서 반복한다.
- 필요 시 rehearsal DMG 또는 package release를 실행하되, public release asset으로 사용하지 않는다.
- Stage 3 보고서에 통과/미실행/대체 사유를 명확히 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m018_188_stage3.md`
- 검증 결과에 따라 `mydocs/release/v0.1.1.md` 보정

### 검증

```bash
git status --short --branch
cat rhwp-core.lock
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
plutil -p build.noindex/DerivedDataRelease/Build/Products/Release/Alhangeul.app/Contents/Info.plist | rg "CFBundleShortVersionString|CFBundleVersion|NSHumanReadableCopyright"
find build.noindex/DerivedDataRelease/Build/Products/Release/Alhangeul.app/Contents/Resources/Legal -maxdepth 1 -type f | sort
git diff --check
```

선택 rehearsal 검증:

```bash
./scripts/release.sh --skip-notarize 0.1.1
hdiutil verify build.noindex/release/alhangeul-macos-0.1.1-rehearsal.dmg
```

### 완료 기준

- source-level release candidate 검증이 통과하거나, 외부 권한/GUI 의존 항목은 Stage 4/5로 명확히 이관된다.
- Release build 산출물에서 app 본체와 Quick Look/Thumbnail extension이 universal slice를 가진다.
- Legal resource와 copyright metadata가 app bundle에 포함된다.
- public release 실행 전 blocker가 stage report에 남는다.

### 커밋 메시지

```text
Task #188 Stage 3: release candidate 로컬 검증
```

## Stage 4. Public release 실행과 공개 URL 검증

### 목표

작업지시자 승인 후 release candidate commit을 공식 release tag로 고정하고, signed/notarized public DMG, GitHub Release, Pages deployment, Sparkle appcast를 공개 URL 기준으로 검증한다.

### 작업

- Stage 3 완료 후 release candidate commit과 tag 대상 commit을 작업지시자와 확정한다.
- 필요하면 `devel-webview -> main` release PR/merge checkpoint를 먼저 진행한다. tag는 release owner가 확정한 commit에만 생성한다.
- 작업지시자 승인 후 repository setting precondition을 반영한다.
  - Pages source `workflow`
  - `github-pages` environment tag policy `v*`
- 작업지시자 승인 후 `v0.1.1` tag를 생성하고 원격에 push한다.
- 작업지시자 승인 후 `Release Publish DMG` workflow를 실행한다.
  - `version=0.1.1`
  - `previous_release_ref=v0.1.0`
  - `expected_rhwp_tag=v0.7.10`
  - `require_latest_rhwp=true` unless release owner approves an exception
  - `draft=false`
  - `prerelease=false`
- workflow run summary와 artifacts를 확인한다.
- GitHub Release `v0.1.1`이 public 상태인지 확인한다.
- DMG asset과 `.sha256`을 내려받아 local verification을 반복한다.
- public appcast URL이 `v0.1.1`, build `2`, Sparkle EdDSA signature, tag 고정 DMG URL, release notes URL을 포함하는지 확인한다.
- Pages latest download button과 release note URL을 확인한다.
- `scripts/update-cask-sha256.sh 0.1.1 <checksum-file>`로 repository Cask source를 public DMG SHA256 기준으로 갱신한다.
- `mydocs/release/v0.1.1.md`에 public DMG SHA256, GitHub Release URL, Pages deployment, appcast, Cask SHA handoff를 기록한다.
- Stage 4 보고서에 release run URL, asset digest, Pages/appcast 검증 결과를 기록한다.

### 예상 변경 파일

- `Casks/alhangeul-macos.rb`
- `mydocs/release/v0.1.1.md`
- `mydocs/working/task_m018_188_stage4.md`

### 검증

```bash
git status --short --branch
gh api repos/postmelee/alhangeul-macos/pages
gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies
git tag --list v0.1.1
gh workflow run "Release Publish DMG" \
  --repo postmelee/alhangeul-macos \
  --ref v0.1.1 \
  -f version=0.1.1 \
  -f previous_release_ref=v0.1.0 \
  -f expected_rhwp_tag=v0.7.10 \
  -f require_latest_rhwp=true \
  -f draft=false \
  -f prerelease=false
gh run list --repo postmelee/alhangeul-macos --workflow "Release Publish DMG" --limit 5
gh release view v0.1.1 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,isLatest,url,assets
gh release download v0.1.1 --repo postmelee/alhangeul-macos --pattern "alhangeul-macos-0.1.1.dmg*" --dir build.noindex/release/public-download
(cd build.noindex/release/public-download && shasum -a 256 -c alhangeul-macos-0.1.1.dmg.sha256)
hdiutil verify build.noindex/release/public-download/alhangeul-macos-0.1.1.dmg
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml -o build.noindex/release/public-download/appcast.xml
xmllint --noout build.noindex/release/public-download/appcast.xml
rg -n "0\\.1\\.1|sparkle:version>2<|edSignature|releases/download/v0\\.1\\.1|updates/v0\\.1\\.1\\.html" build.noindex/release/public-download/appcast.xml
scripts/update-cask-sha256.sh --dry-run 0.1.1 build.noindex/release/public-download/alhangeul-macos-0.1.1.dmg.sha256
scripts/update-cask-sha256.sh 0.1.1 build.noindex/release/public-download/alhangeul-macos-0.1.1.dmg.sha256
git diff --check
```

mounted DMG/app verification:

```bash
mkdir -p build.noindex/release/mount-v0.1.1
hdiutil attach build.noindex/release/public-download/alhangeul-macos-0.1.1.dmg -mountpoint build.noindex/release/mount-v0.1.1 -nobrowse
codesign --verify --deep --strict --verbose=2 build.noindex/release/mount-v0.1.1/Alhangeul.app
xcrun stapler validate build.noindex/release/mount-v0.1.1/Alhangeul.app
spctl --assess --type execute --verbose=4 build.noindex/release/mount-v0.1.1/Alhangeul.app
scripts/ci/verify-universal-macos-app.sh build.noindex/release/mount-v0.1.1/Alhangeul.app
plutil -p build.noindex/release/mount-v0.1.1/Alhangeul.app/Contents/Info.plist | rg "CFBundleShortVersionString|CFBundleVersion|NSHumanReadableCopyright|Taegyu Lee"
find build.noindex/release/mount-v0.1.1/Alhangeul.app/Contents/Resources/Legal -maxdepth 1 -type f | sort
diff -u LICENSE build.noindex/release/mount-v0.1.1/Alhangeul.app/Contents/Resources/Legal/LICENSE
diff -u THIRD_PARTY_LICENSES.md build.noindex/release/mount-v0.1.1/Alhangeul.app/Contents/Resources/Legal/THIRD_PARTY_LICENSES.md
diff -u Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md build.noindex/release/mount-v0.1.1/Alhangeul.app/Contents/Resources/Legal/FONTS.md
hdiutil detach build.noindex/release/mount-v0.1.1
```

### 완료 기준

- `v0.1.1` GitHub Release가 draft/prerelease가 아닌 public release다.
- DMG asset과 `.sha256` 검증이 통과한다.
- signed/notarized/stapled app과 DMG 검증이 통과한다.
- public Pages appcast가 `v0.1.1` item과 EdDSA signature를 제공한다.
- public DMG 안의 app/extension universal slice와 legal notice 검증이 통과한다.
- Cask source가 `version "0.1.1"`과 public DMG SHA256을 사용한다.
- #209에서 tap 공개 배포를 이어받을 수 있는 URL/SHA 정보가 기록된다.

### 커밋 메시지

```text
Task #188 Stage 4: v0.1.1 public release 게시
```

## Stage 5. 설치본 smoke와 Finder 통합 정정

### 목표

작업지시자 Mac의 기존 public `v0.1.0` 설치본에서 Sparkle 업데이트 감지를 확인한 뒤, 승인된 삭제 범위로 기존 설치본을 정리하고 `v0.1.1` public DMG를 새로 설치해 사용자-facing smoke를 완료한다.

### 작업

- 기존 `v0.1.0` 설치본을 유지한 상태로 앱을 실행한다.
- `알한글 > 업데이트 확인...`에서 `v0.1.1` 업데이트 감지 여부를 확인한다.
- Sparkle 업데이트 감지 결과를 screenshot 또는 수동 기록으로 Stage 5 보고서에 남긴다.
- 작업지시자에게 완전 삭제 범위를 다시 확인한다.
  - `/Applications/Alhangeul.app`
  - LaunchServices/PlugInKit registration refresh
  - Quick Look cache reset
  - Sparkle cache/user defaults 삭제 여부
  - 앱 container 또는 user document data 삭제 제외 여부
- 승인된 범위에서 기존 설치본을 제거하고 `v0.1.1` public DMG를 다시 설치한다.
- `v0.1.1` 설치본에서 앱 실행, HWP/HWPX 문서 열기, 창 확대/resize를 확인한다.
- `v0.1.1` 설치본에서 Sparkle 수동 업데이트 확인을 실행하고 최신 상태 판정을 확인한다.
- Finder Quick Look preview와 thumbnail smoke를 수행한다.
- Intel Mac 실기기 smoke 가능 여부를 확인하고, 미실행이면 사유를 기록한다.
- `mydocs/release/v0.1.1.md`, `mydocs/orders/20260510.md`, 최종 보고서에 결과를 반영한다.
- #209 handoff 항목을 최종 보고서에 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m018_188_stage5.md`
- `mydocs/release/v0.1.1.md`
- `mydocs/orders/20260511.md`
- `mydocs/report/task_m018_188_report.md`

### 검증

```bash
mdls -name kMDItemVersion /Applications/Alhangeul.app
plutil -p /Applications/Alhangeul.app/Contents/Info.plist | rg "CFBundleShortVersionString|CFBundleVersion|NSHumanReadableCopyright"
open -a /Applications/Alhangeul.app "$PWD/samples/basic/KTX.hwp"
open -a /Applications/Alhangeul.app "$PWD/samples/hwpx/hwpx-01.hwpx"
pgrep -x Alhangeul
scripts/smoke-finder-integration.sh --skip-package --app /Applications/Alhangeul.app --version 0.1.1
qlmanage -t -x samples/basic/KTX.hwp
qlmanage -t -x samples/hwpx/hwpx-01.hwpx
git diff --check
git status --short --branch
```

수동 확인:

- `v0.1.0` 설치본에서 Sparkle 업데이트 확인이 `v0.1.1`을 감지한다.
- `v0.1.1` 설치본에서 Sparkle 업데이트 확인이 최신 상태 또는 업데이트 없음 상태로 끝난다.
- `samples/basic/KTX.hwp`와 `samples/hwpx/hwpx-01.hwpx`가 열리고 창 확대/resize 후 WebView runtime fallback이 표시되지 않는다.
- Finder icon view에서 HWP/HWPX thumbnail이 생성된다.
- Quick Look preview가 raw error, hang, crash 없이 열린다.

### 완료 기준

- Sparkle update path와 clean install path가 모두 검증된다.
- 앱 실행, 문서 열기, resize, Sparkle 수동 확인, Quick Look/Thumbnail smoke 결과가 최종 보고서에 기록된다.
- `mydocs/release/v0.1.1.md`가 공개 완료 상태와 실제 SHA/URL/검증 결과를 담는다.
- 오늘할일 #188이 완료로 갱신된다.
- #209 Homebrew tap 공개 배포에 필요한 public DMG URL, SHA256, Cask source 상태가 handoff된다.
- PR 생성 전 미커밋 변경이 없다.

### 커밋 메시지

```text
Task #188 Stage 5: 설치본 smoke와 Finder 통합 진단
```

## Stage 6. Quick Look/Thumbnail crash hotfix와 respin 준비

### 목표

public `v0.1.1` 설치본의 Quick Look/Thumbnail extension 크래시 원인을 수정하고, `v0.1.1` respin 전 signed/notarized 설치본 smoke 기준을 확정한다.

### 작업

- DiagnosticReports와 `qlmanage -p/-t` 재현 결과를 Stage 5 정정으로 남긴다.
- `HwpPageImageRenderer`의 bitmap context backing memory ownership을 CoreGraphics 소유 방식으로 바꾼다.
- Quick Look preview와 Thumbnail provider에 OSLog를 추가해 request, PNG/PDF 분기, fallback, failure를 추적할 수 있게 한다.
- 단일 페이지 PNG reply, 다중 페이지 PDF reply 정책을 유지한다.
- source-level Debug/Release build와 renderer smoke를 반복한다.
- 수정본이 아직 설치본에서 실행되지 않았음을 명확히 기록하고, signed/notarized respin smoke를 다음 승인 지점으로 둔다.

### 예상 변경 파일

- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/QLExtension/HwpPreviewProvider.swift`
- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- `mydocs/working/task_m018_188_stage5.md`
- `mydocs/working/task_m018_188_stage6.md`
- `mydocs/release/v0.1.1.md`
- `mydocs/orders/20260511.md`

### 검증

```bash
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
scripts/render-debug-compare.sh /private/tmp/alhangeul-render-debug-after-buffer-fix-all-recheck /Users/melee/Desktop/files/*.hwp
git diff --check
git status --short --branch
```

### 완료 기준

- public `v0.1.1` 실패 원인이 등록 문제가 아니라 extension render crash였음이 문서화된다.
- `HwpPageImageRenderer`가 Swift 배열 backing store에 의존하지 않는다.
- extension 로그가 fallback/failure 진단에 충분한 정보를 제공한다.
- source-level build와 renderer smoke가 통과한다.
- signed/notarized respin 설치본 smoke가 별도 다음 단계로 남는다.

### 커밋 메시지

```text
Task #188 Stage 6: Quick Look crash hotfix
```

## Stage 7. Clean visual smoke 설치와 직접 검증 helper

### 목표

Stage 6 hotfix를 작업지시자가 직접 시각 검증할 수 있도록, 기존 public 설치본, 과거 개발 app copy, PlugInKit/LaunchServices 등록, Quick Look cache가 섞이지 않는 로컬 설치 smoke 절차를 만든다.

### 작업

- visual smoke 전용 설치 스크립트를 추가한다.
- `/Applications/Alhangeul.app`과 `$HOME/Applications/Alhangeul.app` 중복 provider 오염을 방지한다.
- staging app을 ad-hoc runtime 서명으로 재서명하되 release entitlements를 사용해 `get-task-allow`가 남지 않게 한다.
- 기존 PlugInKit/LaunchServices 등록을 해제한 뒤 새 app을 등록한다.
- active provider path가 설치된 app 내부 `.appex`와 일치하는지 검증한다.
- timestamp가 붙은 fresh sample folder를 만들고, forced UTI `qlmanage -t`로 thumbnail 산출물을 생성한다.
- 작업지시자용 `VISUAL_CHECK.md`, `open-preview.command`, `check-crashes.command`를 생성한다.
- local ad-hoc smoke와 public signed/notarized respin 검증을 문서에서 분리한다.

### 예상 변경 파일

- `scripts/smoke-clean-quicklook-install.sh`
- `mydocs/working/task_m018_188_stage7.md`
- `mydocs/release/v0.1.1.md`
- `mydocs/orders/20260511.md`

### 검증

```bash
bash -n scripts/smoke-clean-quicklook-install.sh
scripts/smoke-clean-quicklook-install.sh \
  --skip-package \
  --app build.noindex/release/Alhangeul.app \
  --replace-applications-install \
  --remove-user-application-copy \
  --open-finder
pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension
pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension
find /private/tmp/alhangeul-visual-smoke/<timestamp>/thumbnails -type f -exec file {} \;
/private/tmp/alhangeul-visual-smoke/<timestamp>/check-crashes.command
git diff --check
git status --short --branch
```

### 완료 기준

- 새 설치본의 active provider가 `/Applications/Alhangeul.app` 내부 preview/thumbnail appex만 가리킨다.
- 새 sample folder 기준으로 HWP/HWPX thumbnail PNG가 생성된다.
- 작업지시자가 Finder와 Quick Look으로 직접 볼 수 있는 안내와 helper가 생성된다.
- smoke 이후 새 `AlhangeulPreview`/`AlhangeulThumbnail` crash report가 없다.
- public signed/notarized respin과 Sparkle update extension refresh 검증은 다음 단계의 별도 완료 기준으로 남는다.

### 커밋 메시지

```text
Task #188 Stage 7: Quick Look visual smoke setup
```

## Stage 8. v0.1.1 respin build와 로컬 smoke

### 목표

public `0.1.1 (2)` 설치 사용자가 Sparkle로 hotfix를 받을 수 있도록 같은 short version `0.1.1`에서 build number를 `3`으로 올리고, signed/notarized public workflow 실행 전 로컬 respin 후보를 검증한다.

### 작업

- HostApp, Quick Look preview extension, Thumbnail extension의 `CFBundleVersion`을 `3`으로 올린다.
- PR CI의 Sparkle appcast helper 검증 build 값을 `3`으로 맞춘다.
- README와 `docs/updates/v0.1.1.html`에 Quick Look/Thumbnail crash hotfix와 respin build 기준을 반영한다.
- release 기록에 original public build `2`와 respin candidate build `3`을 구분해 기록한다.
- `scripts/package-release.sh 0.1.1`로 local Release app을 다시 만든다.
- `scripts/smoke-clean-quicklook-install.sh`로 기존 설치/extension 등록을 정리하고 build `3` app을 `/Applications/Alhangeul.app`에 설치한다.
- fresh sample folder에서 thumbnail 생성, active provider path, crash report 부재를 확인한다.

### 예상 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `.github/workflows/pr-ci.yml`
- `README.md`
- `docs/updates/v0.1.1.html`
- `mydocs/working/task_m018_188_stage8.md`
- `mydocs/release/v0.1.1.md`
- `mydocs/orders/20260511.md`

### 검증

```bash
plutil -extract CFBundleVersion raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/ThumbnailExtension/Info.plist
bash -n scripts/smoke-clean-quicklook-install.sh scripts/package-release.sh scripts/ci/write-sparkle-appcast.sh
scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.1 \
  --build 3 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.1/alhangeul-macos-0.1.1.dmg \
  --length 1 \
  --ed-signature dummy-ed-signature \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html \
  --pub-date "Mon, 11 May 2026 00:00:00 +0000" \
  --minimum-system-version 12.0 \
  --output build.noindex/release/appcast-stage8.xml
xmllint --noout build.noindex/release/appcast-stage8.xml
scripts/package-release.sh 0.1.1
scripts/smoke-clean-quicklook-install.sh \
  --skip-package \
  --app build.noindex/release/Alhangeul.app \
  --replace-applications-install \
  --remove-user-application-copy \
  --open-finder
pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension
pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension
find /private/tmp/alhangeul-visual-smoke/<timestamp>/thumbnails -type f -exec file {} \;
/private/tmp/alhangeul-visual-smoke/<timestamp>/check-crashes.command
git diff --check
git status --short --branch
```

### 완료 기준

- app과 두 extension의 build가 모두 `3`으로 일치한다.
- Sparkle appcast helper가 `sparkle:version=3`, `sparkle:shortVersionString=0.1.1` 조합을 생성한다.
- local Release package와 clean visual smoke가 통과한다.
- 작업지시자가 직접 확인할 fresh sample folder와 helper가 생성된다.
- public signed/notarized respin 실행 전 필요한 tag 이동, GitHub Release asset clobber, Pages/appcast 재배포 승인이 분리되어 남는다.

### 커밋 메시지

```text
Task #188 Stage 8: v0.1.1 respin build 준비
```

## 승인 요청 사항

1. 위 8단계 구현계획 승인
2. Stage 1에서 release preflight와 repository setting 승인 항목 확정부터 진행 승인
3. Pages source `workflow` 전환과 `github-pages` `v*` tag policy 추가는 Stage 1 보고 후 별도 승인 지점으로 유지하는 방식 승인
4. 기존 `v0.1.0` 설치본은 Stage 5 Sparkle 업데이트 감지 확인 전까지 삭제하지 않는 방식 승인
