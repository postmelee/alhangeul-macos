# Task M010 #166 구현계획서

수행계획서: `mydocs/plans/task_m010_166.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다. `main` 반영, tag push, GitHub Release workflow 실행, Homebrew Cask 반영은 외부 상태를 바꾸는 작업이므로 해당 단계 승인만으로도 다시 실행 직전 확인을 남긴다.

## 작업 개요

- 이슈: #166 M16 완료 후 v0.1 첫 공개 배포 실행
- 마일스톤: M010 (`v0.1`)
- 브랜치: `local/task166`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task166`
- 기준 브랜치: `devel-webview`
- release version: `0.1.0`
- release tag: `v0.1.0`
- expected rhwp tag: `v0.7.10`
- 목표: M16과 #177 결과를 확인한 뒤 signed/notarized public DMG를 공식 GitHub Release로 게시하고, Pages appcast/direct download/Homebrew Cask 판단까지 완료한다.

## 구현 원칙

- #167에서 완료한 core update, Rust bridge generated artifact 재생성, bundled `rhwp-studio` asset sync는 반복하지 않는다.
- #177에서 완료한 Sparkle 구조, appcast skeleton, Pages download URL, release workflow appcast 경로는 재구현하지 않는다.
- release 후보는 `devel-webview`의 검증된 commit을 기준으로 삼고, `main` 반영과 `v0.1.0` tag는 별도 승인 후 수행한다.
- public release workflow는 `draft=false`, `prerelease=false`를 공식 완료 기준으로 둔다. 검수용 draft 실행이 필요하면 별도 승인과 별도 단계 보정이 필요하다.
- public DMG digest가 확인되기 전에는 `Casks/alhangeul-macos.rb`의 `sha256 :no_check`를 실제 배포 상태로 보지 않는다.
- credential, private key, GitHub secret 값은 출력하거나 문서화하지 않는다. secret/variable의 존재 여부와 이름만 확인한다.
- `scripts/release.sh --skip-notarize` 산출물과 rehearsal workflow artifact는 public release asset, Homebrew Cask digest, Sparkle appcast enclosure로 사용하지 않는다.
- 각 stage는 실제 실행한 검증만 성공으로 기록한다. 수동 확인이나 실행하지 않은 smoke는 미실행/후속으로 분리한다.

## Stage 1. release readiness preflight

### 목표

- M16과 #177 선행 조건이 실제로 닫혀 있고 release-critical 변경이 `devel-webview`에 반영됐는지 확인한다.
- release workflow를 실행하기 전 필요한 lock, plist, Sparkle, Pages, secret/variable 준비 상태를 점검한다.

### 작업

- `git status`, `git log`, `git branch`, `gh issue view`로 기준 branch와 선행 이슈 상태를 확인한다.
- #148, #145, #151, #150, #149, #146, #167, #177의 CLOSED 상태와 최종 보고서를 대조한다.
- `rhwp-core.lock`, `RustBridge/Cargo.lock`, `Sources/HostApp/Resources/rhwp-studio/manifest.json`이 `v0.7.10` / `62a458aa317e962cd3d0eec6096728c172d57110` 기준인지 확인한다.
- HostApp/QLExtension/ThumbnailExtension `CFBundleShortVersionString`이 `0.1.0`인지 확인한다.
- HostApp `SUFeedURL`, `SUPublicEDKey`, `SUEnableInstallerLauncherService`와 Pages `docs/appcast.xml`, `docs/updates/v0.1.0.html`, direct download URL을 확인한다.
- `.github/workflows/release-publish.yml`의 default input이 `0.1.0`, `v0.7.10`, `require_latest_rhwp=true`, `draft=false`, `prerelease=false`인지 확인한다.
- GitHub Actions release environment에 필요한 secret/variable 이름을 확인한다. 값은 출력하지 않는다.
  - `ALHANGEUL_DEVELOPER_ID_APPLICATION`
  - `ALHANGEUL_DEVELOPER_ID_DMG`
  - `ALHANGEUL_NOTARY_PROFILE`
  - `APPLE_TEAM_ID`
  - `DEVELOPER_ID_APPLICATION_P12_BASE64`
  - `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
  - `NOTARY_APPLE_ID`
  - `NOTARY_APP_SPECIFIC_PASSWORD`
  - `RELEASE_KEYCHAIN_PASSWORD`
  - `SPARKLE_ED_PRIVATE_KEY`
  - `ALHANGEUL_PAGES_BRANCH`
- Stage 1 보고서에 go/no-go 결과와 Stage 2에서 실행할 검증 범위를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m010_166_stage1.md`

### 검증

```bash
git status --short --branch
git log --oneline --max-count=10
gh issue view 148 --repo postmelee/alhangeul-macos --json number,title,state
gh issue view 145 --repo postmelee/alhangeul-macos --json number,title,state
gh issue view 151 --repo postmelee/alhangeul-macos --json number,title,state
gh issue view 150 --repo postmelee/alhangeul-macos --json number,title,state
gh issue view 149 --repo postmelee/alhangeul-macos --json number,title,state
gh issue view 146 --repo postmelee/alhangeul-macos --json number,title,state
gh issue view 167 --repo postmelee/alhangeul-macos --json number,title,state
gh issue view 177 --repo postmelee/alhangeul-macos --json number,title,state
cat rhwp-core.lock
plutil -extract source_release_tag raw -o - Sources/HostApp/Resources/rhwp-studio/manifest.json
plutil -extract source_resolved_commit raw -o - Sources/HostApp/Resources/rhwp-studio/manifest.json
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
plutil -extract SUFeedURL raw -o - Sources/HostApp/Info.plist
plutil -extract SUPublicEDKey raw -o - Sources/HostApp/Info.plist
xmllint --noout docs/appcast.xml
rg -n "0\\.1\\.0|v0\\.7\\.10|draft|prerelease|SPARKLE_ED_PRIVATE_KEY|ALHANGEUL_PAGES_BRANCH|latest/download|appcast" \
  .github/workflows/release-publish.yml docs Sources/HostApp/Info.plist mydocs/manual/release_distribution_guide.md
git diff --check
```

### 완료 기준

- 선행 이슈와 문서/lock/workflow 기준이 release 실행에 충분한지 Stage 1 보고서에 정리된다.
- secret/variable 준비 상태가 이름 기준으로 확인된다.
- Stage 2 실행 전 blocker가 있으면 구현 변경으로 넘어가지 않고 보고된다.

### 커밋 메시지

```text
Task #166 Stage 1: release readiness preflight 정리
```

## Stage 2. release candidate 로컬 검증과 rehearsal

### 목표

- public release workflow 전에 로컬에서 가능한 lock, build, render, package, Finder smoke를 확인한다.
- rehearsal 산출물과 public 산출물의 경계를 다시 검증한다.

### 작업

- Rust bridge lock과 `rhwp-studio` asset manifest를 검증한다.
- shared Swift boundary, Xcodegen, Debug build, Release build를 실행한다.
- `validate-stage3-render.sh`로 native render smoke를 실행한다.
- `scripts/package-release.sh 0.1.0` 또는 `scripts/smoke-finder-integration.sh --version 0.1.0`로 Release package 기준 설치본 smoke를 수행한다.
- legacy provider가 발견되면 파일 삭제 없이 보고하고, 작업지시자 승인 후에만 `--unregister-legacy-candidates` 등록 격리 옵션을 사용한다.
- 승인된 경우 `./scripts/release.sh --skip-notarize 0.1.0`으로 rehearsal DMG layout/checksum을 확인한다.
- Stage 2 보고서에 command, 결과, 산출물 path, SHA256, diagnostics directory, 미실행 수동 preview 항목을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m010_166_stage2.md`

### 검증

```bash
git status --short --branch
./scripts/build-rust-macos.sh --verify-lock
scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
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
scripts/smoke-finder-integration.sh --version 0.1.0
git diff --check
```

선택 rehearsal:

```bash
./scripts/release.sh --skip-notarize 0.1.0
test -f build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
test -f build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
(cd build.noindex/release && shasum -a 256 -c alhangeul-macos-0.1.0-rehearsal.dmg.sha256)
hdiutil verify build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
```

### 완료 기준

- release candidate가 로컬 build/render/package/smoke 기준을 통과하거나, blocker가 명확히 보고된다.
- public release로 대체할 수 없는 rehearsal 결과와 public release에서만 확인할 항목이 분리된다.
- Stage 3에서 release ref를 확정할 수 있는지 go/no-go가 남는다.

### 커밋 메시지

```text
Task #166 Stage 2: release candidate 로컬 검증
```

## Stage 3. release ref 확정과 main/tag 준비

### 목표

- 작업지시자 승인 후 release 기준 commit을 확정하고, `main` 반영과 `v0.1.0` tag 생성 준비를 완료한다.
- GitHub Actions `Release Publish DMG` workflow가 요구하는 “tag에서 실행” 조건을 만족시킨다.

### 작업

- 최신 `origin/devel-webview`와 `origin/main`을 fetch한다.
- Stage 1-2 보고서가 포함된 `local/task166` commit을 release source에 포함할지, 순수 `origin/devel-webview` commit을 release source로 삼을지 작업지시자에게 확인한다.
- 기본 후보는 `local/task166`의 Stage 2 완료 commit이다. 이 경우 release source에는 #166 계획/보고 문서만 추가되고 앱 binary surface는 `devel-webview`와 동일해야 한다.
- `main`과 release source의 차이를 확인한다.
- 작업지시자 승인 후 `main`을 release source commit으로 fast-forward 또는 merge한다. fast-forward가 불가능하면 merge commit 여부를 승인받는다.
- `v0.1.0` tag를 release commit에 생성하고 push한다.
- Stage 3 보고서에 release source commit, main commit, tag object, push 결과를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m010_166_stage3.md`
- 외부 상태: `main` branch, Git tag `v0.1.0`

### 검증

```bash
git fetch origin
git status --short --branch
git rev-parse HEAD
git rev-parse origin/devel-webview
git rev-parse origin/main
git log --oneline --graph --decorate --max-count=20 --all
git diff --stat origin/main...HEAD
```

승인 후 실행 후보:

```bash
git checkout main
git pull --ff-only origin main
git merge --ff-only <release-source-commit>
git tag -a v0.1.0 -m "Alhangeul v0.1.0"
git push origin main
git push origin v0.1.0
git checkout local/task166
```

tag 검증:

```bash
git ls-remote origin refs/tags/v0.1.0
git show --no-patch --decorate v0.1.0
```

### 완료 기준

- `main`이 승인된 release source commit을 가리킨다.
- `v0.1.0` tag가 같은 release commit을 가리키며 원격에 존재한다.
- release workflow 실행 전 tag/ref 조건이 충족된다.

### 커밋 메시지

```text
Task #166 Stage 3: v0.1.0 release ref 확정
```

Stage 3 보고서 커밋은 `local/task166`에서 수행한다. `main` 반영과 tag push는 별도 외부 상태 변경으로 기록한다.

## Stage 4. official GitHub Release publish

### 목표

- 작업지시자 승인 후 `Release Publish DMG` workflow를 `v0.1.0` tag에서 official stable release 입력으로 실행한다.
- signed/notarized DMG, GitHub Release state, SHA256, direct download URL을 검증한다.

### 작업

- workflow 입력을 다시 확인한다.
  - `version=0.1.0`
  - `expected_rhwp_tag=v0.7.10`
  - `require_latest_rhwp=true`
  - `draft=false`
  - `prerelease=false`
- `gh workflow run`으로 release workflow를 tag ref에서 실행한다.
- `gh run watch` 또는 `gh run view --log-failed`로 workflow 완료 상태를 확인한다.
- workflow summary에서 rhwp lock, notarization, DMG SHA256, GitHub Release state, appcast 생성 결과를 확인한다.
- `gh release view v0.1.0`으로 draft/prerelease/latest 상태와 URL을 확인한다.
- release asset을 내려받아 `.sha256` 검증을 실행한다.
- `releases/latest`와 `latest/download/alhangeul-macos-0.1.0.dmg` HTTP 응답을 확인한다.
- Stage 4 보고서에 workflow run URL, release URL, digest, asset size, 실패 시 로그 요약을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m010_166_stage4.md`
- 외부 상태: GitHub Release `v0.1.0`, release assets

### 실행 후보

```bash
gh workflow run "Release Publish DMG" \
  --repo postmelee/alhangeul-macos \
  --ref v0.1.0 \
  -f version=0.1.0 \
  -f expected_rhwp_tag=v0.7.10 \
  -f require_latest_rhwp=true \
  -f draft=false \
  -f prerelease=false
```

검증:

```bash
gh run list --repo postmelee/alhangeul-macos --workflow "Release Publish DMG" --limit 5
gh release view v0.1.0 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,isLatest,url,assets
rm -rf build.noindex/release-check
mkdir -p build.noindex/release-check
gh release download v0.1.0 \
  --repo postmelee/alhangeul-macos \
  --pattern 'alhangeul-macos-0.1.0.dmg*' \
  --dir build.noindex/release-check
(cd build.noindex/release-check && shasum -a 256 -c alhangeul-macos-0.1.0.dmg.sha256)
curl -L -I https://github.com/postmelee/alhangeul-macos/releases/latest
curl -L -I https://github.com/postmelee/alhangeul-macos/releases/latest/download/alhangeul-macos-0.1.0.dmg
```

### 완료 기준

- GitHub Release `v0.1.0`이 draft가 아니고 prerelease도 아니다.
- public DMG와 `.sha256` asset이 존재하고 checksum 검증이 통과한다.
- `releases/latest`와 direct download URL이 `v0.1.0` public DMG로 이어진다.
- workflow가 signed/notarized/stapled public artifact를 생성했다는 증거가 summary와 release asset으로 확인된다.

### 커밋 메시지

```text
Task #166 Stage 4: official GitHub Release 게시 검증
```

## Stage 5. appcast, 설치본, Homebrew Cask, 최종 보고

### 목표

- official release 이후 Sparkle appcast, Pages 다운로드, 설치본 smoke, Homebrew Cask 판단을 완료한다.
- 최종 결과보고서와 오늘할일 완료 처리를 정리하고 PR 준비 상태를 만든다.

### 작업

- Pages appcast를 내려받아 XML 유효성과 `v0.1.0` item을 확인한다.
- appcast enclosure가 tag 고정 DMG URL, byte length, `sparkle:edSignature`, release notes URL을 포함하는지 확인한다.
- Pages 다운로드 버튼과 업데이트 안내 페이지가 `latest/download/alhangeul-macos-0.1.0.dmg`를 가리키는지 확인한다.
- 가능하면 설치된 앱에서 `알한글 > 업데이트 확인...` smoke를 수행하고, 불가능하면 미실행 사유를 기록한다.
- public DMG 또는 release-check 산출물 기준으로 Cask digest dry-run을 실행한다.
- 작업지시자 승인 시 `scripts/update-cask-sha256.sh 0.1.0 <checksum-file>`로 `Casks/alhangeul-macos.rb`의 `sha256`을 고정한다.
- Homebrew tap 배포 여부를 결정한다. tap push나 PR 생성은 별도 승인 없이는 수행하지 않는다.
- 최종 보고서에 release URL, DMG SHA256, rhwp tag/commit, appcast URL, direct download URL, smoke 결과, Homebrew 판단, 잔여 위험을 기록한다.
- `mydocs/orders/20260509.md`를 완료 상태로 갱신한다.

### 예상 변경 파일

- `mydocs/working/task_m010_166_stage5.md`
- `mydocs/report/task_m010_166_report.md`
- `mydocs/orders/20260509.md`
- `Casks/alhangeul-macos.rb` (승인 시)
- 필요 시 `docs/appcast.xml` 또는 `docs/updates/v0.1.0.html` 보정 문서 변경

### 검증

```bash
git status --short --branch
curl -L https://postmelee.github.io/alhangeul-macos/appcast.xml -o build.noindex/release-check/appcast.xml
xmllint --noout build.noindex/release-check/appcast.xml
rg -n "v0\\.1\\.0|alhangeul-macos-0\\.1\\.0\\.dmg|sparkle:edSignature|sparkle:version|releaseNotesLink" \
  build.noindex/release-check/appcast.xml
curl -L -I https://postmelee.github.io/alhangeul-macos/updates/v0.1.0.html
curl -L -I https://github.com/postmelee/alhangeul-macos/releases/latest/download/alhangeul-macos-0.1.0.dmg
./scripts/update-cask-sha256.sh --dry-run 0.1.0 build.noindex/release-check/alhangeul-macos-0.1.0.dmg.sha256
git diff --check
```

승인 시 Cask 반영:

```bash
./scripts/update-cask-sha256.sh 0.1.0 build.noindex/release-check/alhangeul-macos-0.1.0.dmg.sha256
```

문서 검증:

```bash
rg -n "#166|v0\\.1\\.0|SHA256|GitHub Release|appcast|Homebrew|완료|known|Quick Look|Thumbnail" \
  mydocs/working/task_m010_166_stage5.md mydocs/report/task_m010_166_report.md mydocs/orders/20260509.md Casks/alhangeul-macos.rb
```

### 완료 기준

- Sparkle appcast가 official `v0.1.0` item과 EdDSA signature를 포함한다.
- Pages direct download와 release latest URL이 public DMG로 이어진다.
- public DMG SHA256이 최종 보고서에 기록된다.
- Homebrew Cask 배포 여부와 digest 반영 여부가 확정된다.
- 최종 보고서와 오늘할일 완료 처리가 커밋된다.

### 커밋 메시지

```text
Task #166 Stage 5 + 최종 보고서: v0.1 첫 공개 배포 완료
```

## 승인 요청

이 구현계획서 기준으로 Stage 1 `release readiness preflight`를 시작할지 승인 요청한다. Stage 1은 조사와 보고서 작성만 수행하며, `main` 반영, tag 생성, GitHub Release workflow 실행, Homebrew Cask 변경은 수행하지 않는다.
