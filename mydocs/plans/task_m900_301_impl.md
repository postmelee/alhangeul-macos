# Task M900 #301 구현계획서

## 개요

이 구현계획서는 `v0.1.4` public release 준비와 배포 실행을 5단계로 나눈다. 확정된 release identity는 `version=0.1.4`, `build=10`, `previous_release_ref=v0.1.3`, `expected_rhwp_tag=v0.7.13`이다.

각 단계는 하이퍼-워터폴 승인 gate를 가진다. Stage 1~2는 release candidate source와 communication 정렬, Stage 3은 source preflight와 rehearsal, Stage 4는 `main` 반영과 public publish gate, Stage 5는 post-publish 확인과 Homebrew gate다.

public publish, GitHub Release 게시, Pages/Sparkle 갱신, Homebrew tap 반영은 이 구현계획 승인만으로 실행하지 않는다. 해당 단계에서 작업지시자의 별도 명시 승인을 받은 뒤 진행한다.

## Stage 1: Release Candidate Source Metadata 정렬

### 목표

`devel`의 release candidate source를 `v0.1.4 (10)`과 `rhwp v0.7.13` 기준으로 맞춘다.

### 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m900_301_stage1.md`

### 작업

1. HostApp, Quick Look, Thumbnail extension의 `CFBundleShortVersionString`을 `0.1.4`로 올린다.
2. 세 target의 `CFBundleVersion`을 `10`으로 올린다.
3. `Release Rehearsal DMG` workflow default를 `version=0.1.4`, `previous_release_ref=v0.1.3`, `expected_rhwp_tag=v0.7.13`으로 갱신한다.
4. `Release Publish DMG` workflow default를 같은 값으로 갱신한다.
5. `rhwp-core.lock`과 bundled `rhwp-studio` manifest가 이미 `v0.7.13` / `b3e16ef212af81ef37d973ddb86d6816d3804642`인지 재확인한다.

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
rg -n "0\\.1\\.3|0\\.1\\.4|v0\\.1\\.2|v0\\.1\\.3|v0\\.7\\.12|v0\\.7\\.13" \
  .github/workflows/release-rehearsal.yml \
  .github/workflows/release-publish.yml \
  Sources/HostApp/Info.plist \
  Sources/QLExtension/Info.plist \
  Sources/ThumbnailExtension/Info.plist
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_301_stage1.md`
- 단계 커밋: `Task #301 Stage 1: release metadata 정렬`

### 승인 요청

Stage 1 완료보고서 기준으로 Stage 2 진행 승인을 요청한다.

## Stage 2: Release Communication 작성

### 목표

사용자-facing release note와 내부 release record를 `v0.1.4`, `rhwp v0.7.13` 기준으로 정리한다.

### 변경 파일

- `README.md`
- `docs/updates/v0.1.4.html`
- `docs/updates/index.html`
- `mydocs/release/index.md`
- `mydocs/release/v0.1.4.md`
- `mydocs/working/task_m900_301_stage2.md`

### 작업

1. `mydocs/release/v0.1.4.md`를 작성한다.
2. 직전 public release `v0.1.3` 대비 변경점을 `rhwp v0.7.13` 반영, 앱 repository 변경, 검증 예정 항목으로 분리한다.
3. GitHub Release body 후보의 `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화` 문구를 사용자-facing 내용으로 보정한다.
4. Pages `docs/updates/v0.1.4.html`을 기존 update page 구조에 맞춰 추가한다.
5. `docs/updates/index.html` 최신 항목과 다운로드 경로가 `v0.1.4`를 가리키게 갱신한다.
6. README 최신 공개 릴리즈 요약을 `v0.1.4` 후보 기준으로 갱신할지 판단하고, 갱신 시 public DMG SHA256 미확정 상태를 명확히 둔다.

### 검증

```bash
scripts/ci/write-release-delta-checklist.sh v0.1.3 HEAD build.noindex/release/delta-checklist-0.1.4.md
scripts/ci/write-release-notes.sh 0.1.4 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.4.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.4.md
rg -n "0\\.1\\.4|v0\\.1\\.4|v0\\.7\\.13|전체 요약|포함된 rhwp 변화|알한글 앱 변화|alhangeul-macos-0\\.1\\.4\\.dmg" \
  README.md docs/updates mydocs/release/v0.1.4.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_301_stage2.md`
- 단계 커밋: `Task #301 Stage 2: release communication 작성`

### 승인 요청

Stage 2 완료보고서 기준으로 Stage 3 진행 승인을 요청한다.

## Stage 3: Source Preflight와 Rehearsal

### 목표

release candidate source가 빌드와 release helper 기준을 통과하는지 검증하고, 승인 시 rehearsal DMG로 layout/checksum/delta checklist를 확인한다.

### 변경 파일

- `mydocs/release/v0.1.4.md`
- `mydocs/working/task_m900_301_stage3.md`

rehearsal 산출물은 `build.noindex/` 아래에 생성하며 git에 커밋하지 않는다.

### 작업

1. Rust/core lock, bundled `rhwp-studio`, shared Swift boundary를 검증한다.
2. `xcodegen generate`, Debug build, render smoke를 실행한다.
3. 개발용 package 산출물로 Release configuration bundle과 universal app/extension slice 검증을 실행한다.
4. release helper dry-run과 release note template check를 실행한다.
5. 작업지시자 승인 후 `Release Rehearsal DMG` workflow 또는 `./scripts/release.sh --skip-notarize 0.1.4`를 실행한다.
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
./scripts/package-release.sh 0.1.4
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
./scripts/release.sh --help
```

승인 후 rehearsal:

```bash
./scripts/release.sh --skip-notarize 0.1.4
hdiutil verify build.noindex/release/alhangeul-macos-0.1.4-rehearsal.dmg
```

### 단계 산출물

- `mydocs/working/task_m900_301_stage3.md`
- 보정된 `mydocs/release/v0.1.4.md`
- 단계 커밋: `Task #301 Stage 3: source preflight와 rehearsal 검증`

### 승인 요청

Stage 3 완료보고서 기준으로 Stage 4 진행 승인을 요청한다. Stage 4의 `main` PR, tag 생성, public publish는 별도 승인 gate다.

## Stage 4: Main/Tag/Public Publish Gate

### 목표

검증된 `devel` release candidate를 `main`으로 반영하고, `v0.1.4` tag와 public publish workflow 실행을 준비한다.

### 변경 파일

- `mydocs/release/v0.1.4.md`
- `mydocs/working/task_m900_301_stage4.md`

### 작업

1. `devel` release candidate commit과 포함 PR 범위를 확정한다.
2. release PR 본문에 release record, 검증 결과, known limitations, publish input을 정리한다.
3. 작업지시자 승인 후 `devel -> main` release PR을 만들고 merge한다.
4. 작업지시자 승인 후 `v0.1.4` tag를 정확한 `main` candidate commit에 만든다.
5. 작업지시자 승인 후 `Release Publish DMG` workflow를 실행한다.
6. workflow summary에서 tag/ref 일치, `expected_rhwp_tag`, public DMG, GitHub Release, Pages/Sparkle job 결과를 확인한다.

### 검증

```bash
git status --short --branch
git rev-parse HEAD
gh pr view <release-pr> --repo postmelee/alhangeul-macos --json number,state,mergeCommit,url
gh release view v0.1.4 --repo postmelee/alhangeul-macos --json tagName,name,isDraft,isPrerelease,assets,url
```

publish workflow 승인 입력:

```bash
gh workflow run "Release Publish DMG" --ref v0.1.4 \
  -f version=0.1.4 \
  -f previous_release_ref=v0.1.3 \
  -f expected_rhwp_tag=v0.7.13 \
  -f require_latest_rhwp=true \
  -f include_rhwp_in_title=true \
  -f draft=false \
  -f prerelease=false
```

### 단계 산출물

- `mydocs/working/task_m900_301_stage4.md`
- 보정된 `mydocs/release/v0.1.4.md`
- 단계 커밋: `Task #301 Stage 4: public publish gate 확인`

### 승인 요청

Stage 4 완료보고서 기준으로 Stage 5 진행 승인을 요청한다.

## Stage 5: Post-publish 확인과 Homebrew Gate

### 목표

public artifact와 update surface를 검증하고, Homebrew는 public DMG SHA256 확정 후 별도 승인으로 반영한다.

### 변경 파일

- `Casks/alhangeul.rb` (Homebrew gate 승인 시)
- `README.md` (Homebrew 안내 공개 조건 충족 시)
- `docs/updates/index.html` 또는 `docs/updates/v0.1.4.html` (post-publish URL/SHA 보정 필요 시)
- `mydocs/release/v0.1.4.md`
- `mydocs/working/task_m900_301_stage5.md`
- `mydocs/report/task_m900_301_report.md`
- `mydocs/orders/20260531.md`

### 작업

1. GitHub Release URL, public DMG URL, SHA256, size, asset 목록을 확인한다.
2. Pages `updates/v0.1.4.html`, latest download, stable appcast item, Sparkle EdDSA signature를 확인한다.
3. release machine에서 가능한 범위의 stapler, `spctl`, universal slice 검증을 반복한다.
4. Finder Quick Look/Thumbnail smoke와 Sparkle extension refresh smoke를 실행하거나 미실행 사유를 기록한다.
5. 작업지시자 승인 후 `./scripts/update-cask-sha256.sh 0.1.4`를 실행하고 maintainer tap 반영/검증을 수행한다.
6. 최종 release record와 최종 결과보고서를 작성한다.

### 검증

```bash
gh release view v0.1.4 --repo postmelee/alhangeul-macos --json tagName,name,isDraft,isPrerelease,assets,url
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/alhangeul-macos-0.1.4.dmg
spctl --assess --type execute --verbose build.noindex/release/Alhangeul.app
spctl --assess --type open --context context:primary-signature --verbose build.noindex/release/alhangeul-macos-0.1.4.dmg
scripts/smoke-finder-integration.sh --version 0.1.4
scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.4 --expected-build 10
```

Homebrew 승인 후:

```bash
./scripts/update-cask-sha256.sh 0.1.4
brew tap postmelee/tap
brew style --cask alhangeul
brew audit --cask alhangeul
brew install --cask postmelee/tap/alhangeul
brew uninstall --cask alhangeul
```

### 단계 산출물

- `mydocs/working/task_m900_301_stage5.md`
- `mydocs/report/task_m900_301_report.md`
- 완료 처리된 `mydocs/orders/20260531.md`
- 단계/최종 커밋: `Task #301 Stage 5 + 최종 보고서: post-publish 확인`

### 승인 요청

최종 결과보고서 기준으로 PR 게시 단계 진행 승인을 요청한다.

## 전체 승인 Gate

| Gate | 승인 없이 진행 금지 항목 |
|------|--------------------------|
| 수행계획 승인 | 구현계획서 작성 이후의 실제 source/release 문서 수정 |
| 구현계획 승인 | Stage 1 source metadata 수정 |
| Stage 1 승인 | Stage 2 release communication 작성 |
| Stage 2 승인 | Stage 3 build/preflight/rehearsal |
| Stage 3 승인 | `devel -> main` release PR, tag 생성, public publish |
| Stage 4 승인 | post-publish smoke, Homebrew gate |
| Homebrew 별도 승인 | Cask SHA 고정, tap 반영, Homebrew 설치 안내 공개 |

## 검증/기록 원칙

- 실행하지 않은 smoke는 성공으로 기록하지 않는다.
- rehearsal DMG와 public DMG SHA256을 섞지 않는다.
- secret 값은 어떤 문서, commit, PR, shell history에도 기록하지 않는다.
- public artifact URL, SHA256, workflow run URL, Pages URL, appcast 결과는 `mydocs/release/v0.1.4.md`에 남긴다.
- GitHub-hosted workflow에서만 생성된 산출물은 workflow summary와 artifact를 기준으로 기록하고, 가능한 검증은 release machine에서 재실행한다.

## 승인 요청 사항

이 구현계획서 기준으로 Stage 1 진행 승인을 요청한다.
