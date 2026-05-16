# Task M019 #225 구현계획서

수행계획서: `mydocs/plans/task_m019_225.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다. GitHub Release 게시, stable appcast 갱신, Pages public deployment, tag 생성, `devel-webview -> main` release PR/merge, public 배포 workflow 실행은 해당 단계에서 명시 승인 없이 실행하지 않는다.

## 작업 개요

- 이슈: #225 v0.1.2 업데이트 후 Finder thumbnail refresh와 rhwp v0.7.11 반영
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task225`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 직전 public release: `v0.1.1` build `4`
- 목표 app release: `v0.1.2`
- 목표 `rhwp` release: `v0.7.11`
- 목표 `rhwp` tag commit: `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`
- 목표 DMG: `alhangeul-macos-0.1.2.dmg`
- Sparkle stable feed: `https://postmelee.github.io/alhangeul-macos/appcast.xml`

## 승인된 기준

- `rhwp v0.7.11`을 v0.1.2 core/studio 기준으로 반영한다.
- update maintenance는 build-scoped 1회 실행으로 둔다.
- 앱 내부에서 전역 `qlmanage -r cache`나 Finder 강제 재실행을 자동 수행하지 않는다.
- Finder thumbnail stale cache 대응은 최근 HWP/HWPX 문서 중심의 targeted refresh로 제한한다.
- About 창에는 앱 version/build와 별도로 bundled `rhwp` release tag와 short commit을 표시한다.
- 구현과 로컬/rehearsal 검증은 `local/task225`와 `devel-webview` 통합 전후에서 수행할 수 있다.
- public 배포는 `publish/task225 -> devel-webview` PR merge 후, 릴리즈 시점의 `devel-webview -> main` release PR merge와 `v0.1.2` tag 생성 이후에만 진행한다.
- GitHub Release 게시, stable appcast/Pages 갱신, public release workflow 실행, Homebrew Cask 반영은 별도 명시 승인 후 수행한다.

## 현재 확인 상태

2026-05-11 KST 기준으로 다음을 확인했다.

- `edwardkim/rhwp` GitHub release 목록에서 `v0.7.11`이 latest release다.
- `v0.7.11` release publishedAt은 `2026-05-10T19:50:46Z`다.
- 원격 tag `refs/tags/v0.7.11`은 `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`다.
- 현재 `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, third-party legal 문서는 `v0.7.10` 기준이다.
- 현재 앱/Quick Look/Thumbnail extension `CFBundleShortVersionString`은 `0.1.1`이다.
- #205는 release provenance 표기 정책을 완료했고, #219는 release signing/notarization preflight를 완료했으며, #227은 staticlib byte hash 검증 정책을 완료했다.
- release policy는 `devel-webview`의 검증된 commit을 `main`에 반영한 뒤 Git tag와 GitHub Release를 `main` 기준으로 생성하도록 정한다.

## 구현 원칙

- `Alhangeul.xcodeproj`는 생성물이다. 직접 수정하지 않고 `project.yml`과 source/resource를 기준으로 한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다.
- `rhwp-core.lock`은 core source provenance와 Rust bridge generated artifact metadata의 진실 원천으로 유지한다.
- bundled `rhwp-studio` asset provenance는 `Sources/HostApp/Resources/rhwp-studio/manifest.json`을 기준으로 한다.
- release identity는 앱 버전 `v0.1.2` 하나로 유지하고, bundled `rhwp` 정보는 provenance metadata로 분리한다.
- update maintenance는 앱 실행을 막는 fatal path가 아니다. 실패는 로그로 남기고 앱은 계속 실행한다.
- 파일 접근 권한이 없는 recent document 후보는 조용히 건너뛰고, 파일 내용 또는 사용자 metadata를 변경하지 않는다.
- public release 산출물 checksum, Sparkle EdDSA signature, notarization 결과는 source commit에 미리 확정하지 않는다. 실제 결과는 release workflow 결과와 `mydocs/release/v0.1.2.md`에 기록한다.

## Stage 1. Inventory와 구현 경계 확정

### 목표

`rhwp v0.7.11` 반영 범위, current source 상태, update maintenance 구현 위치, release flow의 main merge/tag/public 배포 게이트를 단계 보고서로 고정한다.

### 작업

- `rhwp v0.7.11` release/tag/latest 상태를 다시 확인한다.
- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, bundled `rhwp-studio` manifest와 legal notice의 현재 provenance를 정리한다.
- `scripts/update-rhwp-core.sh`, `scripts/build-rust-macos.sh`, `scripts/verify-rhwp-studio-assets.sh`, release workflow의 현재 동작을 조사한다.
- About 창, `BuildInfo`, HostApp app lifecycle, recent document 관련 기존 코드 위치를 확인한다.
- `LSRegisterURL`, Quick Look/Thumbnail extension refresh, recent HWP/HWPX 후보 수집에 사용할 API/명령 경계를 확정한다.
- public 배포는 `devel-webview -> main` release PR/merge와 `v0.1.2` tag 이후 진행한다는 게이트를 Stage 1 보고서에 명시한다.

### 예상 변경 파일

- `mydocs/working/task_m019_225_stage1.md`

### 검증

```bash
gh release list --repo edwardkim/rhwp --limit 5 --json tagName,name,publishedAt,isDraft,isPrerelease,isLatest
git ls-remote --tags https://github.com/edwardkim/rhwp.git 'refs/tags/v0.7.11'
rg -n "v0\\.7\\.10|v0\\.7\\.11|CFBundleShortVersionString|CFBundleVersion|rhwp-studio|About|BuildInfo|recent|LaunchServices|QuickLook|Thumbnail" \
  rhwp-core.lock RustBridge Sources scripts .github README.md mydocs/manual mydocs/release
git diff --check -- mydocs/working/task_m019_225_stage1.md
```

### 완료 기준

- Stage 1 보고서에 core/studio update 대상, code touchpoint, release gate, 검증 blocker가 기록된다.
- 다음 단계에서 실제 core/studio update를 수행할 명령과 expected output이 확정된다.

### 커밋 메시지

```text
Task #225 Stage 1: v0.1.2 업데이트 범위와 release gate 확정
```

## Stage 2. `rhwp v0.7.11` core와 studio asset 갱신

### 목표

Rust core dependency, generated Rust bridge artifact, lock/provenance, bundled `rhwp-studio` static asset을 `rhwp v0.7.11` 기준으로 갱신한다.

### 작업

- `scripts/update-rhwp-core.sh --channel stable --tag v0.7.11` 또는 동등한 documented 절차를 사용해 core dependency와 artifact를 갱신한다.
- `RustBridge/Cargo.toml`의 `rhwp` git tag와 `RustBridge/Cargo.lock` resolved source를 확인한다.
- `Frameworks/generated_rhwp.h`, `Frameworks/universal/librhwp.a`, `rhwp-ffi-symbols.txt`, `rhwp-core.lock` 정합성을 확인한다.
- bundled `rhwp-studio/dist` asset을 `v0.7.11` 기준으로 복사하고 manifest를 갱신한다.
- `THIRD_PARTY_LICENSES.md`, README의 bundled `rhwp` provenance, 필요 시 release record 초안을 `v0.7.11` 기준으로 맞춘다.

### 예상 변경 파일

- `rhwp-core.lock`
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `Frameworks/generated_rhwp.h`
- `Frameworks/universal/librhwp.a`
- `rhwp-ffi-symbols.txt`
- `Sources/HostApp/Resources/rhwp-studio/**`
- `Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md`
- `README.md` (필요 시)
- `mydocs/release/v0.1.2.md` (초안 또는 provenance 항목)
- `mydocs/working/task_m019_225_stage2.md`

### 검증

```bash
./scripts/update-rhwp-core.sh --channel stable --tag v0.7.11
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json
rg -n "v0\\.7\\.10|v0\\.7\\.11|a9dcdee|rhwp_release_tag|rhwp_commit" \
  rhwp-core.lock RustBridge Sources/HostApp/Resources README.md mydocs/release
git diff --check
```

환경 또는 deterministic staticlib hash 정책 때문에 `librhwp.a` byte hash 비교가 실패하면 #227 정책에 따라 source/header/ABI 검증과 hash skip 조건을 분리해 stage 보고서에 기록한다.

### 완료 기준

- `rhwp-core.lock`과 Cargo lock이 `v0.7.11` resolved commit을 가리킨다.
- Rust bridge generated header, FFI symbol set, staticlib artifact provenance가 현재 source와 맞다.
- bundled `rhwp-studio` manifest와 asset 검증이 통과한다.
- 잔여 `v0.7.10` 표기가 intentionally historical한 문서인지, 갱신 누락인지 분리된다.

### 커밋 메시지

```text
Task #225 Stage 2: rhwp v0.7.11 core와 studio asset 갱신
```

## Stage 3. About provenance와 update maintenance 구현

### 목표

About 창에 bundled `rhwp` provenance를 표시하고, 앱 업데이트 후 새 build 최초 실행 시 LaunchServices/extension registration refresh와 recent HWP/HWPX targeted thumbnail refresh를 실행한다.

### 작업

- `BuildInfo` 또는 새 provenance loader에서 bundled `rhwp` release tag와 commit을 읽을 수 있게 한다.
- `AboutView`에 `rhwp v0.7.11 (a9dcdee)` 형식의 짧은 row를 추가한다.
- HostApp launch path에 build-scoped maintenance marker를 추가한다.
- 현재 앱 bundle 기준 LaunchServices/extension registration refresh를 수행하는 service를 추가한다.
- 최근 HWP/HWPX 문서 후보를 수집하고, 접근 가능한 파일만 대상으로 thumbnail refresh를 유도한다.
- maintenance 실패가 앱 실행을 막지 않도록 error logging과 fallback을 둔다.
- 단위 테스트 또는 최소한 deterministic helper 테스트가 가능한 로직은 테스트로 분리한다.

### 예상 변경 파일

- `Sources/HostApp/Support/BuildInfo.swift`
- `Sources/HostApp/Views/AboutView.swift`
- `Sources/HostApp/HostApp.swift`
- 신규 또는 기존 `Sources/HostApp/Services/*Maintenance*.swift`
- 신규 또는 기존 `Sources/HostApp/Services/*RecentDocument*.swift`
- 테스트 target이 이미 적합하면 관련 test file
- `mydocs/working/task_m019_225_stage3.md`

### 검증

```bash
rg -n "BuildInfo|AboutView|rhwp|LaunchServices|LSRegister|QuickLookThumbnailing|NSDocumentController|recent|maintenance" Sources
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

환경이 허용되면 추가 GUI smoke:

```bash
open build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app
```

`open`은 GUI 실행이므로 별도 승인 후 수행한다. About 창 표시와 maintenance log 확인 결과는 stage 보고서에 기록한다.

### 완료 기준

- About 창에서 앱 version/build와 bundled `rhwp` provenance가 분리되어 보인다.
- maintenance marker가 같은 build에서 반복 실행을 막는다.
- registration refresh와 targeted thumbnail refresh가 실패해도 앱 launch가 계속된다.
- 전역 Quick Look cache reset과 Finder 강제 재실행이 자동 path에 들어가지 않는다.

### 커밋 메시지

```text
Task #225 Stage 3: About provenance와 update maintenance 추가
```

## Stage 4. v0.1.2 release metadata와 사용자 문서 정리

### 목표

source-level version, workflow default, release note/Pages/README/release record를 v0.1.2 candidate 기준으로 정리한다.

### 작업

- HostApp, Quick Look extension, Thumbnail extension `Info.plist`의 short version/build를 v0.1.2 release 후보 기준으로 갱신한다.
- release rehearsal/publish workflow default와 expected `rhwp` tag 입력값을 v0.1.2/v0.7.11 기준으로 확인하고 필요한 경우 갱신한다.
- `scripts/ci/write-release-notes.sh` dry-run 출력이 `rhwp-core.lock`과 `rhwp-studio` manifest의 v0.7.11 provenance를 반영하는지 확인한다.
- `docs/updates/v0.1.2.html`, `docs/updates/index.html`, `README.md`, `mydocs/release/v0.1.2.md`를 release candidate 기준으로 작성한다.
- public DMG URL, SHA256, GitHub Release URL처럼 아직 확정되지 않은 값은 candidate 또는 pending 상태로 명확히 둔다.
- Homebrew Cask는 public DMG SHA256 확정 전에는 최종 고정값으로 반영하지 않는다.

### 예상 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `scripts/ci/write-release-notes.sh` (필요 시)
- `README.md`
- `docs/updates/v0.1.2.html`
- `docs/updates/index.html`
- `mydocs/release/v0.1.2.md`
- `mydocs/working/task_m019_225_stage4.md`

### 검증

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
bash -n scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh scripts/ci/write-release-delta-checklist.sh scripts/ci/write-sparkle-appcast.sh
scripts/ci/write-release-notes.sh 0.1.2 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.2.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md
rg -n "0\\.1\\.1|0\\.1\\.2|v0\\.7\\.10|v0\\.7\\.11|a9dcdee|expected_rhwp_tag|previous_release_ref|latest/download" \
  Sources .github/workflows scripts README.md docs mydocs/release/v0.1.2.md
git diff --check
```

### 완료 기준

- app/extension source version이 v0.1.2 release 후보와 일치한다.
- release communication 문서가 bundled `rhwp v0.7.11`을 짧고 일관되게 표시한다.
- release note template 검증이 통과한다.
- public release 이후에만 확정되는 값이 source에 미리 단정되지 않는다.

### 커밋 메시지

```text
Task #225 Stage 4: v0.1.2 release metadata 정리
```

## Stage 5. 통합 빌드와 Finder/Sparkle smoke

### 목표

`local/task225` source와 PR 후보가 v0.1.2 release candidate로 빌드되고, Quick Look/Thumbnail, Sparkle update, release helper가 가능한 범위에서 검증되는지 확인한다.

### 작업

- Rust bridge, no-AppKit guard, asset manifest, Swift/Xcode build를 실행한다.
- Debug/Release app build와 universal slice 검증을 수행한다.
- renderer smoke와 Finder integration smoke를 실행한다.
- release rehearsal DMG를 생성하고 checksum/layout/app bundle metadata를 확인한다.
- 가능한 경우 v0.1.0 또는 v0.1.1 설치본에서 v0.1.2 candidate로 Sparkle 업데이트 smoke를 수행한다.
- `scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.2` 계열 smoke가 있으면 사용하고, 없으면 수동 절차와 결과를 stage 보고서에 남긴다.
- `devel-webview` 대상 PR 생성 전 남은 blocker와 main release PR 이전 조건을 정리한다.

### 예상 변경 파일

- 검증 결과에 따른 source/script 보정 파일
- `mydocs/working/task_m019_225_stage5.md`
- `mydocs/release/v0.1.2.md` 검증 기록 보강

### 검증

```bash
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
bash -n scripts/release.sh scripts/smoke-finder-integration.sh scripts/smoke-sparkle-extension-refresh.sh
./scripts/release.sh --skip-notarize 0.1.2
hdiutil verify build.noindex/release/alhangeul-macos-0.1.2-rehearsal.dmg
git diff --check
```

수동/환경 의존 smoke:

- clean install v0.1.2 candidate 후 HWP/HWPX Quick Look preview 확인
- clean install v0.1.2 candidate 후 Finder thumbnail 확인
- v0.1.0 설치본에서 v0.1.2 candidate 업데이트 후 stale thumbnail refresh 확인
- v0.1.1 build 4 설치본에서 v0.1.2 candidate 업데이트 후 stale thumbnail refresh 확인
- About 창에서 app version/build와 bundled `rhwp v0.7.11` short commit 표시 확인

### 완료 기준

- source-level build와 release helper 검증이 통과한다.
- unsigned/rehearsal 환경에서 수행 가능한 Finder/Sparkle smoke 결과가 기록된다.
- public release 전에 필요한 Developer ID/notary/Pages/appcast 승인 항목이 명확하다.

### 커밋 메시지

```text
Task #225 Stage 5: v0.1.2 release candidate 검증
```

## Stage 6. 최종 보고, PR 게시, main release handoff와 public 배포

### 목표

최종 보고서를 작성하고 `publish/task225 -> devel-webview` PR을 만든다. PR merge 후 release owner 승인에 따라 `devel-webview -> main` release PR, `v0.1.2` tag, protected release workflow, public 배포 검증을 진행한다.

### 작업

- `mydocs/report/task_m019_225_report.md`를 작성하고 `mydocs/orders/20260511.md` 상태를 갱신한다.
- 최종 보고서에 Stage별 commit, 검증 결과, 미실행 사유, public release 전 조건, `main` merge/tag 필요성을 기록한다.
- `task-final-report` 절차로 최종 커밋, `publish/task225` push, `devel-webview` 대상 PR을 생성한다.
- PR 본문에는 `Closes #225`와 release handoff를 명시한다.
- PR merge 확인 후에는 `pr-merge-cleanup` 절차를 적용하되, #225를 public release 결과까지 포함해 닫을지 여부는 작업지시자 승인으로 확정한다. public release까지 #225 범위에 포함하면 이슈 close는 release workflow와 smoke 검증 완료 후 수행한다.
- public 배포를 계속 진행하라는 별도 승인 후, `devel-webview -> main` release PR을 생성/merge한다.
- `main` 기준 `v0.1.2` tag를 생성하고 protected `Release Publish DMG` workflow를 official release 입력으로 실행한다.
- signed/notarized DMG, GitHub Release, Pages deployment, stable appcast, Sparkle update, Quick Look/Thumbnail smoke를 public URL 기준으로 확인한다.
- public release 결과는 `mydocs/release/v0.1.2.md`와 최종 또는 후속 release report에 기록한다.

### 예상 변경 파일

- `mydocs/report/task_m019_225_report.md`
- `mydocs/orders/20260511.md`
- `mydocs/release/v0.1.2.md`
- PR body 임시 파일
- public release 승인 후 필요 시 release result 기록 보정

### 검증

PR 게시 전:

```bash
git status --short --branch
git diff --check
git log --oneline --decorate -10
```

main merge/tag/public 배포 승인 후:

```bash
gh pr view <task-pr-number> --repo postmelee/alhangeul-macos --json state,mergedAt,baseRefName,headRefName,url
gh pr create --base main --head devel-webview --title "Release: Alhangeul v0.1.2"
gh workflow run release-publish.yml --repo postmelee/alhangeul-macos --ref v0.1.2 \
  -f version=0.1.2 \
  -f previous_release_ref=v0.1.1 \
  -f expected_rhwp_tag=v0.7.11 \
  -f require_latest_rhwp=true \
  -f draft=false \
  -f prerelease=false
gh release view v0.1.2 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,url,assets
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml
```

위 public 배포 명령은 승인 전 실행하지 않는다. 실제 workflow run id, DMG SHA256, appcast signature, Pages URL, smoke 결과는 release 기록에 남긴다.

### 완료 기준

- `publish/task225 -> devel-webview` PR이 생성되고 리뷰 가능한 상태가 된다.
- PR merge 후 branch cleanup 범위와 이슈 close 시점이 확정된다.
- 별도 승인 시 `devel-webview -> main` release PR merge, `v0.1.2` tag, official release workflow가 완료된다.
- GitHub Release, Pages, stable appcast, Sparkle update, Quick Look/Thumbnail smoke가 public 기준으로 검증된다.

### 커밋 메시지

최종 보고서 커밋:

```text
Task #225 Stage 6 + 최종 보고서: v0.1.2 release handoff 정리
```

public release 결과를 같은 task에서 승인 후 이어서 기록하는 경우:

```text
Task #225: v0.1.2 public release 결과 기록
```

## PR close 전략

`publish/task225 -> devel-webview` PR 본문에 `Closes #225`를 명시한다.

이슈 close는 PR merge 확인 후 또는 PR closing keyword로 처리한다. public 배포가 `main` merge/tag 이후 별도 승인 단계로 이어지는 경우, #225 close 시점은 작업지시자와 Stage 6에서 확정한다. public release 실행 결과까지 #225에 포함하기로 하면 release workflow와 smoke 검증 완료 후 close한다.

## 리스크와 보정 기준

- `rhwp v0.7.11`에서 Rust API 또는 WASM/static asset 구조가 바뀌면 Stage 2에서 FFI wrapper나 resource validation 보정이 필요할 수 있다.
- staticlib byte hash가 환경 차이로 재현되지 않으면 #227 정책에 따라 byte hash와 source/header/ABI 검증을 분리한다.
- LaunchServices/Quick Look registration refresh는 macOS 버전별 반영 시간이 달라 smoke에서 대기/재시도 기준이 필요할 수 있다.
- targeted thumbnail refresh가 Finder cache를 직접 삭제하지 않으므로 recent 후보 밖 파일의 stale thumbnail은 해결되지 않을 수 있다. 이 제한은 release note와 report에 남긴다.
- Sparkle update smoke는 public v0.1.0/v0.1.1 설치본, appcast, signing 상태에 의존한다. 재현이 어려우면 rehearsal 결과와 미실행 사유를 분리한다.
- `main` release PR과 tag 생성은 repository state를 바꾸는 release operation이다. Stage 6에서 별도 승인 없이 수행하지 않는다.
- official release workflow는 GitHub Release, Pages, stable appcast를 외부에 공개한다. 입력값과 draft/prerelease 값을 stage report에서 확인한 뒤 승인받는다.

## 승인 요청 사항

이 구현계획서 승인 후 Stage 1 inventory와 구현 경계 확정 작업을 시작한다.
