# Task M900 #360 구현계획서

## 개요

이 구현계획서는 `v0.1.6` public release 준비와 배포 실행을 6단계로 나눈다. 확정된 release identity 후보는 `version=0.1.6`, `build=12`, `previous_release_ref=v0.1.5`, `expected_rhwp_tag=v0.7.16`이다.

각 단계는 하이퍼-워터폴 승인 gate를 가진다. Stage 1~2는 release candidate source와 communication 정렬, Stage 3은 source preflight와 rehearsal, Stage 4는 `main` 반영, pre-public signed/notarized DMG smoke, official stable publish gate, Stage 5는 post-publish public surface 확인과 Homebrew gate, Stage 6은 최종 보고와 cleanup handoff다.

pre-public signed/notarized DMG smoke, public publish, GitHub Release 게시, Pages/Sparkle 갱신, Homebrew tap 반영은 이 구현계획 승인만으로 실행하지 않는다. 해당 단계에서 작업지시자의 별도 명시 승인을 받은 뒤 진행한다.

## Stage 1: Release Candidate Source Metadata 정렬

### 목표

`devel`의 release candidate source를 `v0.1.6 (12)`와 `rhwp v0.7.16` 기준으로 맞춘다.

### 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m900_360_stage1.md`

### 작업

1. HostApp, Quick Look, Thumbnail extension의 `CFBundleShortVersionString`을 `0.1.6`으로 올린다.
2. 세 target의 `CFBundleVersion`을 `12`로 올린다.
3. `Release Rehearsal DMG` workflow default를 `version=0.1.6`, `previous_release_ref=v0.1.5`, `expected_rhwp_tag=v0.7.16`으로 갱신한다.
4. `Release Publish DMG` workflow default를 같은 값으로 갱신한다.
5. `rhwp-core.lock`과 bundled `rhwp-studio` manifest가 `v0.7.16` / `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb`인지 재확인한다.

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
python3 -c 'import sys, yaml; [yaml.safe_load(open(p, "r", encoding="utf-8")) for p in sys.argv[1:]]' \
  .github/workflows/release-rehearsal.yml \
  .github/workflows/release-publish.yml
rg -n "0\\.1\\.5|0\\.1\\.6|v0\\.1\\.4|v0\\.1\\.5|v0\\.7\\.15|v0\\.7\\.16" \
  .github/workflows/release-rehearsal.yml \
  .github/workflows/release-publish.yml \
  Sources/HostApp/Info.plist \
  Sources/QLExtension/Info.plist \
  Sources/ThumbnailExtension/Info.plist
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_360_stage1.md`
- 단계 커밋: `Task #360 Stage 1: release metadata 정렬`

### 승인 요청

Stage 1 완료보고서 기준으로 Stage 2 진행 승인을 요청한다.

## Stage 2: Release Communication 작성

### 목표

사용자-facing release note와 내부 release record를 `v0.1.6`, `rhwp v0.7.16` 기준으로 정리한다.

### 변경 파일

- `README.md`
- `docs/updates/v0.1.6.html`
- `docs/updates/index.html`
- `mydocs/release/index.md`
- `mydocs/release/v0.1.6.md`
- `mydocs/working/task_m900_360_stage2.md`

### 작업

1. `mydocs/release/v0.1.6.md`를 작성한다.
2. 직전 public release `v0.1.5` 대비 변경점을 `rhwp v0.7.16` 반영, 앱 repository 변경, 검증 예정 항목으로 분리한다.
3. GitHub Release body 후보의 `변경 요약`, `포함된 rhwp 변화`, `알한글 앱 변화` 문구를 사용자-facing 내용으로 보정한다.
4. Pages `docs/updates/v0.1.6.html`을 기존 update page 구조에 맞춰 추가한다.
5. `docs/updates/index.html` 최신 항목과 다운로드 경로가 `v0.1.6`을 가리키게 갱신한다.
6. README 최신 공개 릴리즈 요약을 `v0.1.6` 후보 기준으로 갱신할지 판단하고, 갱신 시 public DMG SHA256 미확정 상태를 명확히 둔다.

### 검증

```bash
scripts/ci/write-release-delta-checklist.sh v0.1.5 HEAD build.noindex/release/delta-checklist-0.1.6.md
scripts/ci/write-release-notes.sh 0.1.6 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.6.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.6.md
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
rg -n "0\\.1\\.6|v0\\.1\\.6|v0\\.7\\.16|변경 요약|포함된 rhwp 변화|알한글 앱 변화|alhangeul-macos-0\\.1\\.6\\.dmg" \
  README.md docs/updates mydocs/release/v0.1.6.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_360_stage2.md`
- 단계 커밋: `Task #360 Stage 2: release communication 작성`

### 승인 요청

Stage 2 완료보고서 기준으로 Stage 3 진행 승인을 요청한다.

## Stage 3: Source Preflight와 Rehearsal

### 목표

release candidate source가 빌드와 release helper 기준을 통과하는지 검증하고, 승인 시 rehearsal DMG로 layout/checksum/delta checklist를 확인한다.

### 변경 파일

- `mydocs/release/v0.1.6.md`
- `mydocs/working/task_m900_360_stage3.md`

rehearsal 산출물은 `build.noindex/` 아래에 생성하며 git에 커밋하지 않는다.

### 작업

1. Rust/core lock, bundled `rhwp-studio`, shared Swift boundary를 검증한다.
2. `xcodegen generate`, Debug build, render smoke를 실행한다.
3. 개발용 package 산출물로 Release configuration bundle과 universal app/extension slice 검증을 실행한다.
4. release helper dry-run과 release note template check를 실행한다.
5. 작업지시자 승인 후 `Release Rehearsal DMG` workflow 또는 `./scripts/release.sh --skip-notarize 0.1.6`을 실행한다.
6. rehearsal DMG SHA256, `hdiutil verify`, delta checklist previous/candidate ref를 release record에 기록한다.

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
./scripts/validate-stage3-render.sh
./scripts/package-release.sh 0.1.6
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
./scripts/release.sh --help
```

승인 후 rehearsal:

```bash
./scripts/release.sh --skip-notarize 0.1.6
hdiutil verify build.noindex/release/alhangeul-macos-0.1.6-rehearsal.dmg
```

### 단계 산출물

- `mydocs/working/task_m900_360_stage3.md`
- 보정된 `mydocs/release/v0.1.6.md`
- 단계 커밋: `Task #360 Stage 3: source preflight와 rehearsal 검증`

### 승인 요청

Stage 3 완료보고서 기준으로 Stage 4 진행 승인을 요청한다. Stage 4의 `main` PR, tag 생성, pre-public signed/notarized DMG smoke, official stable publish는 별도 승인 gate다.

## Stage 4: Main/Tag/Pre-public Smoke와 Official Publish Gate

### 목표

검증된 `devel` release candidate를 `main`으로 반영하고, `v0.1.6` tag 생성, pre-public signed/notarized DMG smoke, official stable publish workflow 실행을 승인 gate별로 준비한다.

### 변경 파일

- `mydocs/release/v0.1.6.md`
- `mydocs/working/task_m900_360_stage4.md`

### 작업

1. `devel` release candidate commit과 포함 PR 범위를 확정한다.
2. release PR 본문에 release record, 검증 결과, known limitations, publish input을 정리한다.
3. 작업지시자 승인 후 `devel -> main` release PR을 만들고 merge한다.
4. 작업지시자 승인 후 `v0.1.6` tag를 정확한 `main` candidate commit에 만든다.
5. 작업지시자 승인 후 `Release Publish DMG` workflow를 `draft=true`, `prerelease=false`로 실행해 signed/notarized DMG를 생성한다.
6. maintainer가 draft release asset 또는 Actions artifact DMG를 직접 설치 smoke하고, stable appcast와 Pages deployment가 skip된 것을 확인한다.
7. draft smoke 통과 후 GitHub Release body, Pages 업데이트 문서, README 최신 요약, 내부 release record를 최종 candidate 기준으로 다시 검토한다.
8. 작업지시자 별도 승인 후 `Release Publish DMG` workflow를 `draft=false`, `prerelease=false` official stable 기준으로 실행한다.
9. workflow summary에서 tag/ref 일치, `expected_rhwp_tag`, public DMG, GitHub Release, Pages/Sparkle job 결과를 확인한다.

### 검증

```bash
git status --short --branch
git rev-parse HEAD
gh pr view <release-pr> --repo postmelee/alhangeul-macos --json number,state,mergeCommit,url
gh release view v0.1.6 --repo postmelee/alhangeul-macos --json tagName,name,isDraft,isPrerelease,assets,url
```

pre-public draft smoke 승인 입력:

```bash
gh workflow run "Release Publish DMG" --ref v0.1.6 \
  -f version=0.1.6 \
  -f previous_release_ref=v0.1.5 \
  -f expected_rhwp_tag=v0.7.16 \
  -f require_latest_rhwp=true \
  -f include_rhwp_in_title=true \
  -f draft=true \
  -f prerelease=false
```

official stable publish 승인 입력:

```bash
gh workflow run "Release Publish DMG" --ref v0.1.6 \
  -f version=0.1.6 \
  -f previous_release_ref=v0.1.5 \
  -f expected_rhwp_tag=v0.7.16 \
  -f require_latest_rhwp=true \
  -f include_rhwp_in_title=true \
  -f draft=false \
  -f prerelease=false
```

### 단계 산출물

- `mydocs/working/task_m900_360_stage4.md`
- 보정된 `mydocs/release/v0.1.6.md`
- 단계 커밋: `Task #360 Stage 4: pre-public smoke와 official publish gate 확인`

### 승인 요청

Stage 4 완료보고서 기준으로 Stage 5 진행 승인을 요청한다.

## Stage 5: Post-publish Public Surface 확인과 Homebrew Gate

### 목표

official stable publish 이후 public artifact와 update surface를 검증하고, Homebrew는 public DMG SHA256 확정 후 별도 승인으로 반영한다.

### 변경 파일

- `Casks/alhangeul.rb` (Homebrew gate 승인 시)
- `README.md` (Homebrew 안내 공개 조건 충족 시)
- `docs/updates/index.html` 또는 `docs/updates/v0.1.6.html` (post-publish URL/SHA 보정 필요 시)
- `mydocs/release/v0.1.6.md`
- `mydocs/working/task_m900_360_stage5.md`

### 작업

1. GitHub Release URL, official stable public DMG URL, SHA256, size, asset 목록을 확인한다.
2. Pages `updates/v0.1.6.html`, latest download, stable appcast item, Sparkle EdDSA signature를 확인한다.
3. release machine에서 가능한 범위의 stapler, `spctl`, universal slice 검증을 반복한다.
4. Finder Quick Look/Thumbnail smoke와 Sparkle extension refresh smoke를 실행하거나 미실행 사유를 기록한다.
5. 작업지시자 승인 후 `./scripts/update-cask-sha256.sh 0.1.6`을 실행하고 maintainer tap 반영/검증을 수행한다.

### 검증

```bash
gh release view v0.1.6 --repo postmelee/alhangeul-macos --json tagName,name,isDraft,isPrerelease,assets,url
curl -fsSL https://postmelee.github.io/alhangeul-macos/updates/v0.1.6.html >/tmp/alhangeul-v0.1.6-page.html
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml >/tmp/alhangeul-appcast.xml
rg -n "0\\.1\\.6|12|alhangeul-macos-0\\.1\\.6\\.dmg|sparkle:edSignature" /tmp/alhangeul-appcast.xml
scripts/smoke-finder-integration.sh --version 0.1.6
scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.6 --expected-build 12
```

Homebrew gate 승인 후:

```bash
./scripts/update-cask-sha256.sh 0.1.6
```

### 단계 산출물

- `mydocs/working/task_m900_360_stage5.md`
- 보정된 `mydocs/release/v0.1.6.md`
- Homebrew gate 승인 시 `Casks/alhangeul.rb`
- 단계 커밋: `Task #360 Stage 5: public surface와 Homebrew gate 확인`

### 승인 요청

Stage 5 완료보고서 기준으로 Stage 6 진행 승인을 요청한다.

## Stage 6: 최종 보고와 Cleanup Handoff

### 목표

릴리즈 작업 결과, 검증 범위, 승인 gate, 잔여 위험, 후속 정리 항목을 최종 보고서로 남긴다.

### 변경 파일

- `mydocs/release/v0.1.6.md`
- `mydocs/report/task_m900_360_report.md`
- `mydocs/orders/20260621.md`

### 작업

1. release record의 완료 상태, public URLs, SHA256, 검증 결과를 최신화한다.
2. 미실행 smoke, Homebrew 보류 여부, 남은 follow-up을 명확히 적는다.
3. 최종 보고서를 작성하고 오늘할일 상태를 완료로 바꾼다.
4. PR merge 후 `pr-merge-cleanup` 절차로 branch/worktree/Issue 정리를 넘긴다.

### 검증

```bash
scripts/validate-github-body.sh mydocs/report/task_m900_360_report.md
git diff --check
git status --short --branch
```

### 단계 산출물

- `mydocs/report/task_m900_360_report.md`
- 최종 커밋: `Task #360 Stage 6 + 최종 보고서: v0.1.6 릴리즈 기록 정리`

### 승인 요청

최종 보고서 기준으로 PR 게시 또는 release cleanup 절차 진행 승인을 요청한다.
