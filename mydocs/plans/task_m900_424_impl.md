# Task M900 #424 구현계획서

## 개요

이 구현계획서는 `v0.1.8` public release 준비와 배포 실행을 6단계로 나눈다. 확정 후보 release identity는 `version=0.1.8`, `build=14`, `previous_release_ref=v0.1.7`, `expected_rhwp_tag=v0.7.18`이다.

각 단계는 하이퍼-워터폴 승인 gate를 가진다. Stage 1~2는 release candidate source와 communication 정렬, Stage 3은 source preflight와 rehearsal, Stage 4는 `main` 반영과 pre-public signed/notarized draft DMG smoke, Stage 5는 official stable publish와 post-publish surface 및 Homebrew gate, Stage 6은 최종 보고와 cleanup handoff다.

upstream latest는 `rhwp v0.7.19`이지만 Task #422와 upstream Issue `edwardkim/rhwp#2396`에서 public release blocker를 확인했다. 따라서 Publish workflow의 latest guard 기본값은 유지하고, Stage 4와 Stage 5 실행에서만 `require_latest_rhwp=false`를 별도 승인받아 사용한다.

rehearsal, `devel -> main` release PR, tag 생성, pre-public signed/notarized DMG, official stable publish, Pages/Sparkle와 Homebrew 반영은 이 구현계획 승인만으로 실행하지 않는다. 각 단계의 명시된 gate에서 작업지시자의 별도 승인을 받은 뒤 진행한다.

## Stage 1: Release Candidate Source Metadata 정렬

### 목표

`devel`의 release candidate source를 `v0.1.8 (14)`와 `rhwp v0.7.18` 기준으로 맞춘다.

### 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m900_424_stage1.md`

### 작업

1. HostApp, Quick Look, Thumbnail extension의 `CFBundleShortVersionString`을 `0.1.8`로 올린다.
2. 세 target의 `CFBundleVersion`을 `14`로 올린다.
3. `Release Rehearsal DMG` workflow default를 `version=0.1.8`, `previous_release_ref=v0.1.7`, `expected_rhwp_tag=v0.7.18`로 갱신한다.
4. `Release Publish DMG` workflow default를 같은 값으로 갱신한다.
5. `include_rhwp_in_title=true`와 `require_latest_rhwp=true` 기본 안전장치는 유지한다. latest 예외는 workflow 기본값 변경이 아니라 Stage 4/5 실행 인자로만 처리한다.
6. `rhwp-core.lock`과 bundled `rhwp-studio` manifest가 `v0.7.18` / `93862a4e16df59834ebce46d91e948cd739208e9`인지 확인한다.

### 검증

```bash
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/ThumbnailExtension/Info.plist
bash scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag
bash scripts/ci/read-rhwp-core-lock.sh rhwp_commit
scripts/verify-rhwp-studio-assets.sh
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml"); Psych.parse_file(".github/workflows/release-publish.yml")'
rg -n "0\\.1\\.7|0\\.1\\.8|v0\\.1\\.6|v0\\.1\\.7|v0\\.7\\.17|v0\\.7\\.18|require_latest_rhwp|include_rhwp_in_title" \
  .github/workflows/release-rehearsal.yml \
  .github/workflows/release-publish.yml \
  Sources/HostApp/Info.plist \
  Sources/QLExtension/Info.plist \
  Sources/ThumbnailExtension/Info.plist
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_424_stage1.md`
- 단계 커밋: `Task #424 Stage 1: release metadata 정렬`

### 승인 요청

Stage 1 완료보고서 기준으로 Stage 2 진행 승인을 요청한다.

## Stage 2: Release Communication 작성

### 목표

사용자-facing release note와 내부 release record를 `v0.1.8`, `rhwp v0.7.18` 및 HOP UTI 호환 범위에 맞춰 정리한다.

### 변경 파일

- `README.md`
- `docs/updates/v0.1.8.html`
- `docs/updates/index.html`
- `mydocs/release/index.md`
- `mydocs/release/v0.1.8.md`
- `mydocs/working/task_m900_424_stage2.md`

### 작업

1. `mydocs/release/v0.1.8.md`를 작성한다.
2. `v0.1.7..candidate` 포함 PR을 사용자-facing, core/studio sync, 운영·배포, 문서 변경으로 분류한다.
3. release note에는 `rhwp v0.7.18`의 실제 노출 변화와 HOP UTI 후보 경로 보강을 사용자 용어로 작성한다.
4. HOP 기본 앱 자동 설정, external linked image 완료, Skia default와 `rhwp v0.7.19` 기능은 주장하지 않는다.
5. `v0.7.19` 제외와 latest guard 예외 근거는 내부 release record와 검증 세부에 기록한다.
6. Pages `docs/updates/v0.1.8.html`, updates index와 README 최신 릴리스 요약을 후보 기준으로 정렬한다.

### 검증

```bash
scripts/ci/write-release-delta-checklist.sh v0.1.7 HEAD build.noindex/release/delta-checklist-0.1.8.md
scripts/ci/write-release-notes.sh 0.1.8 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.8.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.8.md
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
rg -n "0\\.1\\.8|v0\\.1\\.8|v0\\.7\\.18|HOP|다음으로 열기|alhangeul-macos-0\\.1\\.8\\.dmg" \
  README.md docs/updates mydocs/release/v0.1.8.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_424_stage2.md`
- 단계 커밋: `Task #424 Stage 2: release communication 작성`

### 승인 요청

Stage 2 완료보고서 기준으로 Stage 3 진행 승인을 요청한다.

## Stage 3: Source Preflight와 Rehearsal

### 목표

release candidate source가 빌드와 release helper 기준을 통과하는지 검증하고, 승인 시 rehearsal DMG로 layout, checksum과 delta checklist를 확인한다.

### 변경 파일

- `mydocs/release/v0.1.8.md`
- `mydocs/working/task_m900_424_stage3.md`

rehearsal 산출물은 `build.noindex/` 아래에 생성하며 git에 커밋하지 않는다.

### 작업

1. Rust/core lock, bundled `rhwp-studio`, generated header와 FFI symbol 기준을 검증한다.
2. `xcodegen generate`, Debug build와 renderer smoke를 실행한다.
3. Release configuration package와 앱/확장의 universal slice를 검증한다.
4. release helper dry-run, delta checklist와 release note template을 검증한다.
5. 별도 승인 후 local 또는 Actions `Release Rehearsal DMG`를 실행한다.
6. rehearsal DMG SHA256, `hdiutil verify`, previous/candidate ref와 미실행 수동 smoke를 release record에 기록한다.

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
  -derivedDataPath build.noindex/DerivedData-task424 \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
./scripts/package-release.sh 0.1.8
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
./scripts/release.sh --help
```

rehearsal 승인 후:

```bash
./scripts/release.sh --skip-notarize 0.1.8
hdiutil verify build.noindex/release/alhangeul-macos-0.1.8-rehearsal.dmg
```

### 단계 산출물

- `mydocs/working/task_m900_424_stage3.md`
- 보정된 `mydocs/release/v0.1.8.md`
- 단계 커밋: `Task #424 Stage 3: source preflight와 rehearsal 검증`

### 승인 요청

Stage 3 완료보고서 기준으로 Stage 4 진입 승인을 요청한다. `main` PR, tag와 draft publish는 각각 별도 승인 gate다.

## Stage 4: Main/Tag와 Pre-public Signed Candidate 검증

### 목표

검증된 release candidate를 `main`과 `v0.1.8` tag로 확정하고, pre-public signed/notarized draft DMG에서 일반 설치와 v0.1.8 전용 차단 smoke를 수행한다.

### 변경 파일

- `mydocs/release/v0.1.8.md`
- `mydocs/working/task_m900_424_stage4.md`

### 작업

1. `devel` candidate commit과 포함 PR 범위를 확정한다.
2. 별도 승인 후 `devel -> main` release PR을 만들고 merge한다.
3. 별도 승인 후 정확한 `main` candidate commit에 `v0.1.8` tag를 만든다.
4. 별도 승인 후 `require_latest_rhwp=false`, `draft=true`, `prerelease=false`로 Publish workflow를 실행한다.
5. draft DMG의 서명, 공증, staple, Gatekeeper, universal slice, mount와 첫 실행을 확인한다.
6. HOP exact UTI `net.golbin.hop.hwp` 및 `net.golbin.hop.hwpx`에서 Finder 후보, 실제 열기, Quick Look, Thumbnail과 handler diagnostics를 확인한다.
7. custom scheme Host RPC readiness, page count, SVG/PDF export, 저장·공유·인쇄 시작 경로를 확인한다.
8. draft 실행에서 stable appcast와 Pages deployment가 skip됐는지 확인한다.

### 검증

```bash
git status --short --branch
git rev-parse HEAD
gh pr view <release-pr> --repo postmelee/alhangeul-macos --json number,state,mergeCommit,url
gh release view v0.1.8 --repo postmelee/alhangeul-macos --json tagName,name,isDraft,isPrerelease,assets,url
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/alhangeul-macos-0.1.8.dmg
spctl --assess --type execute --verbose build.noindex/release/Alhangeul.app
scripts/smoke-finder-integration.sh --version 0.1.8
scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.8 --expected-build 14
```

draft publish 별도 승인 후:

```bash
gh workflow run "Release Publish DMG" --ref v0.1.8 \
  -f version=0.1.8 \
  -f previous_release_ref=v0.1.7 \
  -f expected_rhwp_tag=v0.7.18 \
  -f require_latest_rhwp=false \
  -f include_rhwp_in_title=true \
  -f draft=true \
  -f prerelease=false
```

### 단계 산출물

- `mydocs/working/task_m900_424_stage4.md`
- 보정된 `mydocs/release/v0.1.8.md`
- 단계 커밋: `Task #424 Stage 4: signed candidate 차단 gate 검증`

### 승인 요청

Stage 4 완료보고서 기준으로 Stage 5 official stable publish 진입 승인을 요청한다.

## Stage 5: Official Publish와 Post-publish Surface 확인

### 목표

signed candidate 차단 gate 통과 후 official stable release를 별도 승인으로 게시하고, public artifact, Pages/Sparkle 및 Homebrew gate를 확인한다.

### 변경 파일

- `README.md`
- `docs/updates/index.html` 또는 `docs/updates/v0.1.8.html`
- `mydocs/release/v0.1.8.md`
- `mydocs/working/task_m900_424_stage5.md`
- Homebrew 승인 시 `Casks/alhangeul.rb` 또는 maintainer tap Cask

### 작업

1. Stage 4 이후 candidate commit, tag, release body와 Pages 문서가 바뀌지 않았는지 확인한다.
2. 별도 승인 후 `require_latest_rhwp=false`, `draft=false`, `prerelease=false`로 official Publish workflow를 실행한다.
3. GitHub Release URL, public DMG URL, SHA256, size와 asset 목록을 확인한다.
4. Pages 최신 다운로드, `updates/v0.1.8.html`, stable appcast item과 Sparkle EdDSA signature를 확인한다.
5. public 설치본에서 Finder, Quick Look, Thumbnail, 문서 열기와 Sparkle update smoke를 확인한다.
6. public DMG URL과 SHA256 확정 후 별도 승인으로 Homebrew Cask를 반영하고 설치/제거 smoke를 수행한다.

### 검증

```bash
gh release view v0.1.8 --repo postmelee/alhangeul-macos --json tagName,name,isDraft,isPrerelease,assets,url
curl -fsSL https://postmelee.github.io/alhangeul-macos/updates/v0.1.8.html >/tmp/alhangeul-v0.1.8-page.html
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml >/tmp/alhangeul-appcast.xml
rg -n "0\\.1\\.8|14|alhangeul-macos-0\\.1\\.8\\.dmg|sparkle:edSignature" /tmp/alhangeul-appcast.xml
scripts/smoke-finder-integration.sh --version 0.1.8
scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.8 --expected-build 14
```

official publish 별도 승인 후:

```bash
gh workflow run "Release Publish DMG" --ref v0.1.8 \
  -f version=0.1.8 \
  -f previous_release_ref=v0.1.7 \
  -f expected_rhwp_tag=v0.7.18 \
  -f require_latest_rhwp=false \
  -f include_rhwp_in_title=true \
  -f draft=false \
  -f prerelease=false
```

Homebrew 별도 승인 후:

```bash
./scripts/update-cask-sha256.sh 0.1.8
brew style --cask alhangeul
brew audit --cask alhangeul
brew install --cask postmelee/tap/alhangeul
brew uninstall --cask alhangeul
```

### 단계 산출물

- `mydocs/working/task_m900_424_stage5.md`
- 보정된 `mydocs/release/v0.1.8.md`
- Homebrew 승인 시 Cask 변경과 검증 기록
- 단계 커밋: `Task #424 Stage 5: official publish와 public surface 확인`

### 승인 요청

Stage 5 완료보고서 기준으로 Stage 6 진행 승인을 요청한다.

## Stage 6: 최종 보고와 Cleanup Handoff

### 목표

release 실행 결과를 최종 보고서로 정리하고 merge 후 cleanup 절차로 넘길 수 있게 한다.

### 변경 파일

- `mydocs/release/v0.1.8.md`
- `mydocs/report/task_m900_424_report.md`
- 실제 작업일의 `mydocs/orders/{yyyymmdd}.md`

### 작업

1. release record의 placeholder를 실제 결과 또는 미실행 사유로 보정한다.
2. 최종 보고서에 release identity, latest 예외 승인, signed HOP/Host RPC gate, public artifact, Pages/Sparkle, Homebrew와 잔여 위험을 정리한다.
3. 오늘할일 #424 행을 `완료`와 완료 시각으로 갱신한다.
4. PR 게시 전 최종 diff와 검증 결과를 확인한다.
5. merge 후 `pr-merge-cleanup` 절차로 이슈, 브랜치와 worktree를 정리할 수 있게 handoff한다.

### 검증

```bash
git status --short --branch
git diff --check
rg -n "v0\\.1\\.8|0\\.1\\.8|14|v0\\.7\\.18|require_latest_rhwp|HOP|Host RPC|SHA256|Homebrew|Sparkle|Pages" \
  mydocs/release/v0.1.8.md \
  mydocs/report/task_m900_424_report.md
```

### 단계 산출물

- `mydocs/report/task_m900_424_report.md`
- 최종 보정된 `mydocs/release/v0.1.8.md`
- 완료 처리된 orders 문서
- 단계 커밋: `Task #424 Stage 6 + 최종 보고서: v0.1.8 release 실행 정리`

### 승인 요청

Stage 6 완료보고서와 최종 결과보고서 기준으로 `publish/task424` push와 PR 생성을 요청한다.

## 공통 중단 기준

- working tree에 의도하지 않은 변경이 있다.
- app/extension version 또는 build number가 서로 다르다.
- `rhwp-core.lock`과 bundled `rhwp-studio` manifest가 `v0.7.18` / `93862a4e...` 쌍과 다르다.
- Publish 실행에서 upstream latest와 candidate lock이 다른데 `require_latest_rhwp=false` 예외 승인이 없다.
- source preflight, bundled asset, generated header, FFI symbol, release note template 또는 universal slice 검증이 실패한다.
- signed draft에서 HOP exact UTI 또는 custom scheme Host RPC 차단 gate가 실패한다.
- release owner 승인 없이 `main`, tag, publish, Pages/Sparkle 또는 Homebrew 단계로 넘어가야 한다.
- 실행하지 않은 manual smoke를 성공으로 기록해야 한다.

## 승인 요청 사항

승인된 수행계획에 따라 이 구현계획서 기준으로 Stage 1 `Release Candidate Source Metadata 정렬`을 진행한다. Stage 1 종료 후 완료보고서와 검증 결과를 제시하고 Stage 2 승인을 요청한다.
