# Task M900 #441 구현계획서

수행계획서: `mydocs/plans/task_m900_441.md`

이 구현계획서는 승인된 `v0.1.9` public release 수행계획을 6개 Stage로 구체화한다. 각 Stage 완료 후 `task-stage-report` 절차로 변경과 단계 보고서를 함께 검증·커밋하고, 작업지시자 승인을 받은 뒤 다음 Stage로 넘어간다.

이 구현계획 승인만으로 GitHub workflow, PR merge, `main` 변경, tag 생성, GitHub Release, Pages/Sparkle 또는 Homebrew mutation을 실행하지 않는다. 아래에 별도 gate로 표시한 작업은 해당 시점의 대상 ref, 입력과 예상 외부 효과를 다시 제시하고 작업지시자의 명시 승인을 받은 뒤에만 수행한다.

## 작업 개요

| 항목 | 값 |
|------|----|
| Issue | #441 `v0.1.9 public release 준비와 배포 실행` |
| milestone / 문서 코드 | `Release Operations` / M900 |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task441` |
| task 시작 base | `76c86fc76a9e2b7291f80e57b8b85c7c1e1ff525` |
| 수행계획 commit | `a49facd` |
| version / build / tag | `0.1.9` / `15` / `v0.1.9` |
| previous public release | `v0.1.8`, peeled commit `542a35f2179e5499996b2ab7d2b1a94774b544a2` |
| expected rhwp | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| release title | `Alhangeul v0.1.9 (rhwp v0.8.2)` |
| workflow 정책 | `require_latest_rhwp=true`, `include_rhwp_in_title=true` |

2026-07-28 구현계획 작성 시점의 `origin/main`은 `32c1129477dfd3c812f1eac758654f1e591b1888`, `origin/devel`은 `76c86fc76a9e2b7291f80e57b8b85c7c1e1ff525`, 공통 merge base는 `b6ddc23f4bd4d2147144e3fea3b3fb473004994e`다. `main`에는 PR #432 전용 변경이 있고 `devel`에는 PR #431, PR #434, PR #437, PR #436과 PR #440을 포함한 신규 변경이 있다. Stage 4 release PR 전에 양쪽 전용 변경과 tree를 다시 비교하고 `main` 전용 변경을 보존하는 reviewed back-merge 경계를 확정한다.

## 공통 작업 원칙

1. 각 Stage 시작 시 `git status`, 현재 branch, `origin/main`, `origin/devel`, 최신 앱 release와 최신 upstream `rhwp` release를 다시 확인한다.
2. release identity의 진실 원천은 세 app target plist, `rhwp-core.lock`, `RustBridge/Cargo.lock`, `RhwpCoreBuildInfo`, bundled studio manifest와 final tag commit의 교집합이다.
3. candidate SHA가 이동하면 이전 검증을 자동 승계하지 않는다. 새 merge PR, changed path와 재실행해야 할 gate를 먼저 보고한다.
4. Stage 1~3 source와 release communication 변경은 intermediate source PR로 `devel`에 먼저 반영한다. 이 PR merge 전에는 `devel -> main` release PR을 만들지 않는다.
5. `main` 전용 변경을 보존할 필요가 있으면 squash/cherry-pick으로 이력을 다시 쓰지 않고 reviewed `main -> devel` back-merge PR을 사용한다.
6. release PR은 updated `devel` head에서 `main` base로 만들고 merge commit을 유지한다. tag는 merge된 `main` release commit에만 생성한다.
7. strict static archive byte 검증과 portable source/header/FFI 검증을 별개 결과로 기록한다. strict mismatch가 남으면 rehearsal 전에 release artifact 허용 여부를 별도 승인받는다.
8. rehearsal, draft와 official DMG는 별도 artifact 계층이다. rehearsal/draft URL 또는 SHA256을 stable appcast, Pages나 Homebrew 입력으로 사용하지 않는다.
9. 실제 Finder/Preview와 Sparkle smoke에서는 app/extension version뿐 아니라 실행 provider의 절대 경로와 process provenance를 확인한다.
10. 기존 설치본, LaunchServices와 PlugInKit registration을 바꾸기 전 상태를 기록한다. task에서 바꾼 등록만 복원하고 다른 앱이나 다른 작업의 등록을 삭제하지 않는다.
11. secret 값은 조회·출력·문서화하지 않는다. GitHub Actions variable/secret은 이름과 준비 여부, workflow 결과만 기록한다.
12. 실행하지 않은 GUI, Intel Mac, Sparkle 또는 Homebrew smoke는 통과로 기록하지 않고 미실행 사유와 release 위험으로 남긴다.
13. publish 후 사용자-facing 문구나 record 보정은 여러 PR로 쪼개지 않고 runbook의 단일 릴리즈 종료 정리 단계로 모은다.
14. 어느 Stage에서든 제품 기능 수정이 필요하면 현재 release 실행 범위에서 임의 수정하지 않는다. 재현, 영향과 최소 변경 후보를 보고하고 계획 보정 승인을 요청한다.

## 외부 mutation 승인표

| mutation | 최초 가능 시점 | 별도 승인 전 상태 |
|----------|----------------|-------------------|
| Rehearsal workflow 실행 | Stage 3 source preflight 통과 후 | 실행하지 않음 |
| `publish/task441` push와 intermediate source PR 생성 | Stage 3 완료보고 승인 후 | local branch만 유지 |
| source PR merge | source PR CI와 review 통과 후 | Open 상태 유지 |
| `main -> devel` back-merge PR 생성·merge | source PR merge와 branch divergence 확인 후 | 생성·merge하지 않음 |
| `devel -> main` release PR 생성·merge | source와 back-merge gate 통과 후 | 생성·merge하지 않음 |
| annotated `v0.1.9` tag 생성·push | release PR merge commit 확정 후 | tag 없음 |
| draft Publish workflow | tag와 pre-public 입력 재확인 후 | 실행하지 않음 |
| official Publish workflow | signed/notarized draft smoke 통과 후 | draft/public surface 유지 |
| Homebrew tap 반영 | official public DMG URL/SHA256 확정 후 | Cask 변경하지 않음 |
| main 대상 release closeout PR | publish 후 실제 보정 필요 확인 시 | 생성하지 않음 |

## Stage 1. Release context 확정과 source metadata 정렬

### 목표

release 시작 기준을 live 조회로 다시 고정하고, 세 app target과 release workflow default를 승인된 `v0.1.9 (15)`, `v0.1.8`, `rhwp v0.8.2`로 정렬한다.

### 대상 파일

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m900_441_stage1.md`
- `mydocs/orders/20260728.md`

### 작업

1. latest public app release, upstream latest release, `origin/main`, `origin/devel`, `v0.1.9` tag 미사용 상태와 branch divergence를 조회한다.
2. `v0.1.8..origin/devel` first-parent merge와 현재 열린 release-critical PR을 inventory한다.
3. 세 target의 current version/build가 모두 `0.1.8 (14)`인지 확인한다.
4. 세 target의 `CFBundleShortVersionString`을 `0.1.9`, `CFBundleVersion`을 `15`로 갱신한다.
5. Rehearsal/Publish workflow default를 `version=0.1.9`, `previous_release_ref=v0.1.8`, `expected_rhwp_tag=v0.8.2`로 갱신한다.
6. `require_latest_rhwp=true`, `include_rhwp_in_title=true`, `draft=false`, `prerelease=false` 기본 안전값은 유지한다.
7. `rhwp-core.lock`, RustBridge resolved source, `RhwpCoreBuildInfo`와 bundled studio manifest가 `v0.8.2` / `9b16aa9e...`로 일치하는지 확인한다.
8. repository Cask와 public Pages/appcast의 current `v0.1.8 (14)` 상태를 inventory만 하고 변경하지 않는다.

### 검증

```bash
git status --short --branch
git fetch origin
gh release view --repo postmelee/alhangeul-macos \
  --json tagName,name,isDraft,isPrerelease,publishedAt,url,targetCommitish
gh release view --repo edwardkim/rhwp \
  --json tagName,name,isDraft,isPrerelease,publishedAt,url,targetCommitish
git rev-parse origin/main origin/devel
git rev-list --left-right --count origin/main...origin/devel
git log --first-parent --merges --oneline v0.1.8..origin/devel
git tag --list v0.1.9
plutil -lint \
  Sources/HostApp/Info.plist \
  Sources/QLExtension/Info.plist \
  Sources/ThumbnailExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/ThumbnailExtension/Info.plist
bash scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag
bash scripts/ci/read-rhwp-core-lock.sh rhwp_commit
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh \
  --tag v0.8.2 \
  --commit 9b16aa9e23f476e2b335d7c029fc9f24a199d63c
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml"); Psych.parse_file(".github/workflows/release-publish.yml")'
rg -n "0\\.1\\.8|0\\.1\\.9|v0\\.1\\.7|v0\\.1\\.8|v0\\.7\\.18|v0\\.8\\.2|require_latest_rhwp|include_rhwp_in_title" \
  Sources/HostApp/Info.plist \
  Sources/QLExtension/Info.plist \
  Sources/ThumbnailExtension/Info.plist \
  .github/workflows/release-rehearsal.yml \
  .github/workflows/release-publish.yml
git diff --check
```

### 완료 조건

- latest public app은 `v0.1.8`, upstream latest는 `rhwp v0.8.2`이거나 변경 사실이 보고돼 있다.
- `v0.1.9` tag가 아직 없다.
- 세 app target이 모두 `0.1.9 (15)`다.
- 두 release workflow default가 `0.1.9`, `v0.1.8`, `v0.8.2`로 일치하고 YAML parse가 통과한다.
- core/build info/studio provenance가 같은 `v0.8.2` resolved commit을 가리킨다.
- Stage 1 변경 외의 source diff가 없다.

### 산출물과 커밋

- `mydocs/working/task_m900_441_stage1.md`
- 커밋: `Task #441 Stage 1: v0.1.9 release metadata 정렬`

### 승인 요청

Stage 1 완료보고서와 diff를 제시하고 Stage 2 진행 승인을 요청한다.

## Stage 2. 포함 PR 분석과 release communication 작성

### 목표

`v0.1.8..candidate`에 실제로 새로 포함되는 변화를 분류하고, 사용자-facing release note, Pages와 내부 release record를 같은 `v0.1.9` identity로 정렬한다.

### 대상 파일

- `README.md`
- `docs/index.html`
- `docs/updates/index.html`
- `docs/updates/v0.1.9.html`
- 필요 시 `docs/updates/v0.1.0.html`부터 `docs/updates/v0.1.8.html`까지의 최신 release notice
- `mydocs/release/index.md`
- `mydocs/release/v0.1.9.md`
- `mydocs/working/task_m900_441_stage2.md`

### 작업

1. `write-release-pr-analysis.sh`와 first-parent log로 candidate 포함 PR 초안을 만든다.
2. 각 PR의 title/body, 연결 Issue, files와 `mydocs/report/task_*_report.md`를 직접 확인한다.
3. release transport/back-merge/직전 release closeout을 신규 사용자-facing 변화와 분리한다.
4. 실제 포함 PR을 사용자-facing, 개발자-facing, 운영/배포, 문서-only, upstream sync로 분류한다.
5. `mydocs/release/v0.1.9.md`에 표준 `포함 PR 분석` 표, release identity, provenance, 승인 gate와 known limitations 초안을 작성한다.
6. GitHub Release 초안의 첫 top-level section을 `이번 버전의 주요 변경 사항`으로 두고 `변경 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`를 구분한다.
7. external sibling sandbox fallback, 실제 Preview/장문서/인쇄/PDF, strict artifact와 Intel Mac 미확정 항목은 검증 세부·알려진 한계로 분리한다.
8. README, Pages home/update index, `v0.1.9` update page와 release index를 candidate 기준으로 갱신한다.
9. 이전 update page의 최신 release notice는 helper 결과를 확인해 필요한 범위만 갱신한다.
10. public 문구에 sample 파일명, source metadata, 단순 version bump나 검증 절차를 주요 사용자 변화처럼 노출하지 않는다.

### 검증

```bash
mkdir -p build.noindex/task441-stage2
scripts/ci/write-release-pr-analysis.sh \
  v0.1.8 HEAD \
  build.noindex/task441-stage2/pr-analysis-v0.1.9.md
scripts/ci/write-release-delta-checklist.sh \
  v0.1.8 HEAD \
  build.noindex/task441-stage2/delta-checklist-v0.1.9.md
scripts/ci/write-release-notes.sh \
  0.1.9 \
  0000000000000000000000000000000000000000000000000000000000000000 \
  build.noindex/task441-stage2/release-notes-v0.1.9.md
scripts/ci/check-release-notes-template.sh \
  build.noindex/task441-stage2/release-notes-v0.1.9.md
scripts/ci/update-release-version-notices.sh \
  --updates-dir docs/updates \
  --check
rg -n "0\\.1\\.9|v0\\.1\\.9|v0\\.8\\.2|v0\\.1\\.8|15|9b16aa9e" \
  README.md \
  docs/index.html \
  docs/updates \
  mydocs/release/index.md \
  mydocs/release/v0.1.9.md
rg -n "^## 포함 PR 분석|사용자-facing|공개 요약 반영|해결된 Issue|참고/연관 Issue" \
  mydocs/release/v0.1.9.md
git diff --check
```

Stage 2의 64자리 0 checksum은 template 구조 검증용이며 public release body에 게시하지 않는다. 실제 SHA256은 Stage 4 draft와 Stage 5 official artifact에서 각각 별도로 기록한다.

### 완료 조건

- previous/candidate ref와 포함 PR 목록이 고정돼 있다.
- 모든 공개 요약 항목에 확인한 PR/Issue/report 근거가 있다.
- 직전 release closeout과 단순 운영 변경이 신규 사용자 변화에서 제외돼 있다.
- README, Pages, release record와 generated release note가 `v0.1.9 (15)` 및 `rhwp v0.8.2`로 일치한다.
- 공개 전 미확정 값은 placeholder 또는 gate로 명확히 표시되고 성공으로 서술되지 않는다.
- release note template과 version notice 검증이 통과한다.

### 산출물과 커밋

- `mydocs/release/v0.1.9.md`
- `mydocs/working/task_m900_441_stage2.md`
- `build.noindex/task441-stage2/` 검증 보조 자료
- 커밋: `Task #441 Stage 2: v0.1.9 release communication 작성`

### 승인 요청

Stage 2 완료보고서와 public communication diff를 제시하고 Stage 3 진행 승인을 요청한다.

## Stage 3. Source preflight와 rehearsal

### 목표

release candidate source와 local universal package가 provenance, ABI/tests, app target, renderer와 release helper 기준을 통과하는지 확인하고, 별도 승인된 경우 exact candidate에서 Rehearsal DMG를 검증한다.

### 대상

- `rhwp-core.lock`
- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`
- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`
- bundled `rhwp-studio` manifest와 assets
- Stage 1~2 source/communication 변경
- `mydocs/release/v0.1.9.md`
- `mydocs/working/task_m900_441_stage3.md`
- `build.noindex/task441-stage3-*`

### 작업

1. source provenance와 tracked source 무손실 상태를 재확인한다.
2. strict `build-rust-macos.sh --verify-lock`을 실행하고 실제 hash/size 결과를 기록한다.
3. strict static archive만 mismatch이면 portable skip mode를 별도로 실행해 source, Cargo, header, FFI와 XCFramework 결과를 기록한다.
4. strict mismatch가 남으면 결과와 release workflow의 portable 환경변수 사용 경계를 제시하고 Rehearsal 실행 전 별도 artifact 판정 승인을 요청한다.
5. Rust formatting/locked tests, shared boundary, build info와 ExternalImageTests를 실행한다.
6. `xcodegen generate`를 두 번 실행해 generated project가 stable인지 확인한다.
7. HostApp, QLExtension, ThumbnailExtension Release compile/link를 실행한다.
8. representative renderer, Quick Look와 Thumbnail policy를 `build.noindex/`의 task 전용 산출물로 검증한다.
9. external sibling source-level fixture는 upstream `v0.8.2` exact checkout에서 task 전용 경로로 복사하고 initial/injected/missing과 render 결과를 확인한다.
10. `package-release.sh 0.1.9`와 universal app 검증을 실행하고 local unsigned package를 public artifact와 구분한다.
11. release PR analysis, delta checklist, release note template과 Legal resource canonical hash를 다시 확인한다.
12. 별도 승인 후 Stage 2까지 commit된 source/communication candidate의 exact head를 원격 `publish/task441`에 push하고 Rehearsal workflow를 실행한다. Stage 3 보고서와 rehearsal 결과는 실행 뒤 별도 단계 커밋으로 남긴다.
13. Rehearsal run head가 승인된 pre-rehearsal candidate SHA와 일치하는지 확인하고 checksum, universal slice, `hdiutil verify`, DMG layout과 stable Pages/appcast 미변경을 기록한다.

### 검증

```bash
git status --short --branch
./scripts/build-rust-macos.sh --verify-lock
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  ./scripts/build-rust-macos.sh --verify-lock
cargo fmt --manifest-path RustBridge/Cargo.toml --check
cargo test --manifest-path RustBridge/Cargo.toml --locked
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh \
  --tag v0.8.2 \
  --commit 9b16aa9e23f476e2b335d7c029fc9f24a199d63c
xcodegen generate
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task441-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedData-task441-release \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedData-task441-release \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedData-task441-release \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh \
  build.noindex/task441-stage3-render \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/복학원서.hwp \
  samples/hwpx/hwpx-01.hwpx \
  samples/hwp-multi-001.hwp
./scripts/smoke-quicklook-skia-policy.sh \
  build.noindex/task441-stage3-quicklook \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx \
  build.noindex/task441-stage3-external/hwp3-sample10-hwpx.hwpx
./scripts/smoke-thumbnail-skia-policy.sh \
  build.noindex/task441-stage3-thumbnail \
  samples/복학원서.hwp \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx \
  samples/hwp-multi-001.hwp
./scripts/package-release.sh 0.1.9
scripts/ci/verify-universal-macos-app.sh \
  build.noindex/release/Alhangeul.app
git diff --check
```

Rehearsal 별도 승인 후:

```bash
git push origin local/task441:publish/task441
gh workflow run "Release Rehearsal DMG" \
  --ref publish/task441 \
  -f version=0.1.9 \
  -f previous_release_ref=v0.1.8 \
  -f expected_rhwp_tag=v0.8.2
```

### 완료 조건

- core/studio/build info가 `v0.8.2` / `9b16aa9e...`로 일치한다.
- strict 및 portable artifact 결과가 서로 구분돼 있고 release owner 판정이 필요한지 명시돼 있다.
- Rust tests와 ExternalImageTests가 전부 통과한다.
- 세 제품 target Release build, representative renderer, Quick Look/Thumbnail policy가 통과한다.
- local package의 app과 extension이 모두 `arm64 + x86_64`다.
- Rehearsal을 승인받아 실행한 경우 exact run head, checksum, DMG integrity/layout과 artifact 계층이 확인돼 있다.
- Rehearsal을 실행하지 않은 경우 미실행 상태와 다음 승인 gate가 보고돼 있다.

### 산출물과 커밋

- 보정된 `mydocs/release/v0.1.9.md`
- `mydocs/working/task_m900_441_stage3.md`
- task 전용 `build.noindex/` 검증 산출물
- 커밋: `Task #441 Stage 3: source preflight와 rehearsal 검증`

### 승인 요청

Stage 3 완료보고서에서 다음 mutation을 분리해 승인 요청한다.

1. strict/portable artifact 결과에 따른 release artifact 허용 판정
2. 필요 시 Rehearsal workflow 실행
3. `publish/task441` source PR 생성
4. source PR CI 통과 뒤 merge
5. Stage 4의 `main` back-merge/release PR 준비 진입

## Stage 4. Source 반영, main/tag와 pre-public signed candidate

### 목표

승인된 Stage 1~3 source와 communication을 `devel`에 반영하고, main-only 변경을 보존한 final release candidate를 `main`과 annotated tag로 확정한 뒤 signed/notarized draft DMG의 차단 smoke를 수행한다.

### 대상

- `publish/task441` intermediate source PR
- `origin/main`, `origin/devel`과 양쪽 전용 commit/tree
- 필요 시 `main -> devel` back-merge PR
- `devel -> main` release PR
- annotated `v0.1.9` tag
- draft `Release Publish DMG` run과 artifact
- `mydocs/release/v0.1.9.md`
- `mydocs/working/task_m900_441_stage4.md`

### 작업

1. Stage 3 승인 후 `local/task441`을 `publish/task441`로 push하고 검증된 body-file로 `devel` 대상 intermediate source PR을 만든다.
2. source PR의 exact head SHA, 3개 PR CI gate와 release helper 결과를 확인하고 별도 승인 후 merge commit 방식으로 merge한다.
3. source PR merge 뒤 local branch를 새 `origin/devel`에 fast-forward하고 remote publish branch를 다음 게시 전까지 정리한다.
4. `origin/main...origin/devel` left/right commit, file diff와 merge tree를 다시 계산한다.
5. `main` 전용 PR #432 또는 새 main-only closeout이 남아 있으면 별도 reviewed `main -> devel` back-merge PR로 보존한다.
6. back-merge 뒤 local task branch를 새 `origin/devel`에 fast-forward하고 core/studio provenance, source identity, release communication과 CI를 다시 확인한다.
7. 정확한 updated `devel` head에서 `main` 대상 release PR을 만들고 title/body, included commits, tree와 branch protection check를 검증한다.
8. 별도 승인 후 release PR을 merge commit 방식으로 merge한다.
9. merge된 `main` release commit과 tree를 확인하고 별도 승인 후 annotated `v0.1.9` tag를 생성·push한다.
10. tag가 exact release commit을 가리키고 upstream latest가 여전히 `v0.8.2`인지 재확인한다.
11. 별도 승인 후 `require_latest_rhwp=true`, `draft=true`, `prerelease=false`로 Publish workflow를 실행한다.
12. draft DMG의 checksum, signing, notarization, staple, Gatekeeper, universal slice, Legal resource와 mounted layout을 확인한다.
13. signed candidate를 기존 public `/Applications` 설치본과 분리된 경로에 설치하고 실제 HWP/HWPX 앱 열기, Finder Quick Look/Thumbnail과 provider path를 확인한다.
14. external sibling 문서의 registered Quick Look 접근 결과와 main document fallback을 확인한다.
15. bundled editor에서 대표 HWP/HWPX, 장문서 후반 page repaint, 인쇄 preview와 PDF export 시작 경로를 확인한다.
16. draft 실행에서 stable appcast와 Pages deployment가 skip되고 기존 public `v0.1.8` surface가 유지되는지 확인한다.
17. 검증 중 변경한 registration과 임시 설치 상태를 원상 복구하고 새 crash를 확인한다.

### 검증

생성 결과의 exact 번호를 `TASK441_SOURCE_PR`, `TASK441_BACKMERGE_PR`, `TASK441_RELEASE_PR`에 넣어 다음 검증을 실행한다. back-merge가 불필요하다고 판정된 경우 해당 조회는 생략하고 근거를 Stage 보고서에 기록한다.

```bash
gh pr view "$TASK441_SOURCE_PR" --repo postmelee/alhangeul-macos \
  --json number,state,baseRefName,headRefName,headRefOid,mergeCommit,statusCheckRollup,url
git fetch origin --prune
git rev-list --left-right --count origin/main...origin/devel
git log --left-right --cherry-pick --oneline origin/main...origin/devel
git diff --stat origin/main...origin/devel
gh pr view "$TASK441_BACKMERGE_PR" --repo postmelee/alhangeul-macos \
  --json number,state,mergeable,mergeStateStatus,mergeCommit,statusCheckRollup,url
gh pr view "$TASK441_RELEASE_PR" --repo postmelee/alhangeul-macos \
  --json number,state,mergeable,mergeStateStatus,mergeCommit,statusCheckRollup,url
git rev-parse origin/main
git rev-list -n 1 v0.1.9
git cat-file -t v0.1.9
gh release view v0.1.9 --repo postmelee/alhangeul-macos \
  --json tagName,name,isDraft,isPrerelease,assets,url
```

draft Publish 별도 승인 후:

```bash
gh workflow run "Release Publish DMG" \
  --ref v0.1.9 \
  -f version=0.1.9 \
  -f previous_release_ref=v0.1.8 \
  -f expected_rhwp_tag=v0.8.2 \
  -f require_latest_rhwp=true \
  -f include_rhwp_in_title=true \
  -f draft=true \
  -f prerelease=false

shasum -a 256 -c \
  build.noindex/release/alhangeul-macos-0.1.9.dmg.sha256
hdiutil verify build.noindex/release/alhangeul-macos-0.1.9.dmg
scripts/ci/verify-universal-macos-app.sh \
  build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/Alhangeul.app
xcrun stapler validate \
  build.noindex/release/alhangeul-macos-0.1.9.dmg
spctl --assess --type execute --verbose \
  build.noindex/release/Alhangeul.app
spctl --assess --type open \
  --context context:primary-signature \
  --verbose build.noindex/release/alhangeul-macos-0.1.9.dmg
scripts/smoke-finder-integration.sh --version 0.1.9
```

### 완료 조건

- Stage 1~3 source PR이 `devel`에 merge되고 source branch와 merge commit이 기록돼 있다.
- main-only 변경 보존 여부가 명시돼 있고 필요한 back-merge가 CI/review 후 완료됐다.
- release PR merge commit, annotated tag와 checked-out release tree가 같은 candidate다.
- draft workflow가 exact tag에서 성공하고 stable appcast/Pages는 갱신되지 않았다.
- draft DMG가 signing/notarization/staple/Gatekeeper/universal/layout gate를 통과한다.
- signed candidate의 실제 app/Finder provider provenance, HWP/HWPX, external fallback과 editor 수동 gate가 결과 또는 미실행 사유로 기록돼 있다.
- 검증용 registration이 복원되고 다른 설치본을 의도치 않게 변경하지 않았다.

### 산출물과 커밋

- source/back-merge/release PR과 merge commit URL
- annotated `v0.1.9` tag와 release commit
- draft workflow run, DMG URL/SHA256와 수동 smoke 기록
- 보정된 `mydocs/release/v0.1.9.md`
- `mydocs/working/task_m900_441_stage4.md`
- 커밋: `Task #441 Stage 4: signed candidate 차단 gate 검증`

### 승인 요청

Stage 4 완료보고서와 draft smoke 판정 기준으로 Stage 5 진입 승인을 요청한다. Official Publish와 Homebrew는 Stage 5 안에서도 각각 별도 승인받는다.

## Stage 5. Official stable publish와 public surface

### 목표

draft signed candidate 차단 gate를 통과한 exact tag를 official stable release로 게시하고, public DMG, Pages/Sparkle, 실제 update/Finder와 승인된 Homebrew surface를 확인한다.

### 대상

- official `Release Publish DMG` run
- GitHub Release `v0.1.9`와 public DMG/checksum
- Pages home와 `updates/v0.1.9.html`
- stable Sparkle appcast
- 기존 official `v0.1.8 (14)` 설치본과 update path
- 필요 시 `Casks/alhangeul.rb` 및 `postmelee/homebrew-tap`
- `mydocs/release/v0.1.9.md`
- `mydocs/working/task_m900_441_stage5.md`

### 작업

1. Stage 4 이후 candidate commit, tag, release body, Pages 문서와 draft smoke 결과가 바뀌지 않았는지 확인한다.
2. upstream latest가 `v0.8.2`이고 release environment의 필요한 variable/secret 이름이 준비돼 있는지 값 노출 없이 확인한다.
3. 별도 승인 후 `require_latest_rhwp=true`, `draft=false`, `prerelease=false`로 official Publish workflow를 실행한다.
4. release job과 Pages deploy job의 exact head, status, summary와 artifact를 확인한다.
5. GitHub Release가 non-draft, non-prerelease, latest이고 public DMG/checksum asset을 제공하는지 확인한다.
6. public DMG URL, SHA256, size, universal slice, signing/notarization/staple/Gatekeeper와 Legal resource를 기록한다.
7. Pages home, `updates/v0.1.9.html`, 이전 update notice와 stable appcast가 같은 version/build/public DMG를 가리키는지 확인한다.
8. existing `/Applications/Alhangeul.app`의 `v0.1.8 (14)` baseline signature와 provider를 먼저 검증한다. baseline이 invalid이면 official v0.1.8 재설치 또는 다른 clean baseline 사용을 별도 승인받는다.
9. clean official baseline에서 실제 Sparkle `v0.1.8 -> v0.1.9` update와 app/Preview/Thumbnail provider refresh를 확인한다.
10. public 설치본의 HWP/HWPX open, Quick Look와 Thumbnail을 실제 provider process 기준으로 확인한다.
11. 새 crash, registration repair 사용 여부와 설치본 복구 상태를 기록한다.
12. public DMG URL/SHA256 확정 뒤 별도 승인으로 repository/tap Cask를 갱신하고 style/audit/install/uninstall smoke를 실행한다.
13. Homebrew를 실행하지 않으면 미진행 상태와 후속 gate를 release record에 남긴다.

### 검증

Official Publish 별도 승인 후:

```bash
gh workflow run "Release Publish DMG" \
  --ref v0.1.9 \
  -f version=0.1.9 \
  -f previous_release_ref=v0.1.8 \
  -f expected_rhwp_tag=v0.8.2 \
  -f require_latest_rhwp=true \
  -f include_rhwp_in_title=true \
  -f draft=false \
  -f prerelease=false

gh release view v0.1.9 --repo postmelee/alhangeul-macos \
  --json tagName,name,isDraft,isPrerelease,publishedAt,assets,url
curl --fail --silent --show-error \
  --output /private/tmp/alhangeul-v0.1.9-page.html \
  https://postmelee.github.io/alhangeul-macos/updates/v0.1.9.html
curl --fail --silent --show-error \
  --output /private/tmp/alhangeul-v0.1.9-appcast.xml \
  https://postmelee.github.io/alhangeul-macos/appcast.xml
xmllint --noout /private/tmp/alhangeul-v0.1.9-appcast.xml
rg -n "0\\.1\\.9|15|alhangeul-macos-0\\.1\\.9\\.dmg|sparkle:edSignature" \
  /private/tmp/alhangeul-v0.1.9-appcast.xml
scripts/smoke-finder-integration.sh --version 0.1.9
scripts/smoke-sparkle-extension-refresh.sh \
  --expected-version 0.1.9 \
  --expected-build 15
```

Homebrew 별도 승인 후:

```bash
./scripts/update-cask-sha256.sh 0.1.9
brew style --cask alhangeul
brew audit --cask alhangeul
brew audit --cask --new alhangeul
brew install --cask postmelee/tap/alhangeul
brew uninstall --cask alhangeul
```

### 완료 조건

- official workflow의 release와 Pages jobs가 exact tag에서 성공한다.
- GitHub Release는 public stable이고 public DMG URL/SHA256/size가 확정돼 있다.
- DMG와 app/extension의 signing, notarization, staple, Gatekeeper와 universal gate가 통과한다.
- Pages와 appcast가 `0.1.9 (15)` 및 같은 public universal DMG를 가리킨다.
- clean v0.1.8 baseline에서 Sparkle update와 extension refresh 결과 또는 명확한 미실행 사유가 있다.
- public app/Finder smoke와 provider provenance가 확인돼 있다.
- Homebrew 승인 시 tap-context 검증이 통과하고, 미승인 시 미진행 상태가 남아 있다.

### 산출물과 커밋

- official workflow/GitHub Release/Pages/appcast URL
- public DMG URL/SHA256/size와 설치 smoke 기록
- Homebrew 결과 또는 미진행 사유
- 보정된 `mydocs/release/v0.1.9.md`
- `mydocs/working/task_m900_441_stage5.md`
- 커밋: `Task #441 Stage 5: official publish와 public surface 확인`

### 승인 요청

Stage 5 완료보고서 기준으로 Stage 6 release record·최종 보고와 종료 정리 진행 승인을 요청한다. Homebrew가 남아 있으면 Stage 6 진입 전 포함 여부를 별도로 확인한다.

## Stage 6. Release record, 최종 보고와 종료 정리

### 목표

모든 실제 release 결과를 placeholder 없이 기록하고, public `main`과 integration `devel`의 필요한 종료 기록을 최소 PR로 정렬한 뒤 Task #441 최종 보고·cleanup으로 넘긴다.

### 대상 파일

- `mydocs/release/v0.1.9.md`
- `mydocs/release/index.md`
- 필요 시 `README.md`, `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.9.html`
- `mydocs/report/task_m900_441_report.md`
- 실제 작업일 `mydocs/orders/{yyyymmdd}.md`
- `mydocs/working/task_m900_441_stage6.md`가 필요한 경우 해당 단계 보고서

### 작업

1. release identity, final tag/commit, source/back-merge/release PR, workflow run과 모든 public URL을 확정한다.
2. public DMG filename, URL, SHA256, size, signing/notarization, appcast와 Homebrew 결과 또는 미실행 사유를 release record에 반영한다.
3. draft/official install, Finder/Preview, external fallback, editor, Sparkle와 Intel Mac smoke의 실제 실행 여부를 구분한다.
4. 최종 보고서에 Stage 1~5 결과, 승인 이력, blocking/non-blocking 결과, known limitations와 후속 이슈를 정리한다.
5. public publish 후 release communication 또는 record 보정이 `main`에 필요하면 exact file diff만 포함하는 단일 main 대상 closeout PR을 별도 승인으로 준비한다.
6. main closeout PR을 만들면 merge 전 public Pages/appcast 영향과 `main` 대상 외 변경 부재를 확인하고 별도 승인 후 merge한다.
7. integration `devel`에도 필요한 운영 기록을 standard Task #441 최종 PR로 반영한다. main/devel 양쪽 이력을 섞어 불필요한 제품 diff가 생기면 PR을 만들지 않고 branch 전략을 재확인한다.
8. 오늘할일 #441 행을 `완료`와 실제 완료 시각으로 갱신한다.
9. 최종 보고서 승인 후 `task-final-report` 적용 가능 범위를 확인해 `publish/task441` push와 대상 PR을 게시한다.
10. 모든 PR merge와 Issue close 승인 뒤 `pr-merge-cleanup`으로 remote/local branch와 worktree를 정리한다.

### 검증

main 대상 closeout이 필요한 경우 exact branch와 PR을 `TASK441_CLOSEOUT_HEAD`, `TASK441_CLOSEOUT_PR`에 넣어 검증한다. closeout이 불필요하면 이 두 검증은 생략하고 public/repository 상태가 이미 일치하는 근거를 기록한다.

```bash
git status --short --branch
git diff --check
rg -n "v0\\.1\\.9|0\\.1\\.9|15|v0\\.8\\.2|9b16aa9e|SHA256|Sparkle|Pages|Homebrew|Intel Mac" \
  mydocs/release/v0.1.9.md \
  mydocs/report/task_m900_441_report.md
git fetch origin --prune
git rev-list --left-right --count origin/main...origin/devel
git diff --name-status origin/main..."$TASK441_CLOSEOUT_HEAD"
gh pr view "$TASK441_CLOSEOUT_PR" --repo postmelee/alhangeul-macos \
  --json number,state,baseRefName,headRefName,headRefOid,mergeable,mergeStateStatus,statusCheckRollup,url
gh release view v0.1.9 --repo postmelee/alhangeul-macos \
  --json tagName,name,isDraft,isPrerelease,publishedAt,assets,url
```

### 완료 조건

- release record와 최종 보고서에 placeholder 없이 실제 값 또는 미실행 사유가 있다.
- public GitHub Release, Pages/appcast와 repository communication이 일치한다.
- main closeout이 필요하면 한 PR에 모였고, 불필요하면 생성하지 않은 근거가 기록돼 있다.
- Task #441 최종 PR은 목표 base와 exact file diff가 확인돼 있다.
- 오늘할일이 완료 처리되고 final working tree가 clean하다.
- Issue close와 branch/worktree cleanup 대상이 exact하게 정리돼 있다.

### 산출물과 커밋

- 최종 `mydocs/release/v0.1.9.md`
- `mydocs/report/task_m900_441_report.md`
- 완료된 orders 문서
- 필요 시 단일 main 대상 release closeout PR
- 커밋: `Task #441 Stage 6 + 최종 보고서: v0.1.9 release 실행 정리`

### 승인 요청

Stage 6 완료보고서와 최종 보고서 승인을 받은 뒤 필요한 closeout PR과 Task #441 최종 PR을 게시한다. PR merge 후 Issue #441 close와 cleanup은 다시 별도 승인받는다.

## 공통 중단 기준

- working tree에 의도하지 않은 변경이 있다.
- latest public app, upstream latest, candidate commit이나 previous release ref가 승인된 값과 달라졌다.
- app/extension version 또는 build가 서로 다르다.
- `rhwp-core.lock`, Cargo resolved source, `RhwpCoreBuildInfo`와 bundled studio manifest가 같은 `v0.8.2` commit을 가리키지 않는다.
- strict artifact mismatch가 남았는데 portable 결과와 release owner 허용 판정 없이 Rehearsal로 넘어가야 한다.
- generated header/FFI, Rust/Swift tests, app target, renderer, release helper, universal slice 또는 release note 검증이 실패한다.
- source PR이 merge되지 않았거나 main-only 변경 보존 판단 없이 release PR로 넘어가야 한다.
- release PR/tag/tree가 서로 다른 candidate를 가리킨다.
- tag 생성, draft/official Publish, Pages/Sparkle, Homebrew 또는 PR merge를 별도 승인 없이 실행해야 한다.
- signed draft의 notarization, staple, Gatekeeper, app/Finder/provider 또는 핵심 editor smoke가 실패한다.
- draft workflow에서 stable appcast나 Pages가 의도치 않게 갱신됐다.
- official workflow에서 GitHub Release, Pages, appcast 또는 public DMG identity가 서로 다르다.
- 기존 설치본이 invalid한데 clean baseline 없이 Sparkle update 결과를 성공으로 기록해야 한다.
- 실행하지 않은 Finder GUI, Sparkle update, Homebrew 또는 Intel Mac 검증을 통과로 기록해야 한다.
- secret 또는 credential 값을 출력·기록해야 한다.

## 구현계획 승인 요청 사항

1. 이 구현계획의 6개 Stage와 각 Stage 완료보고 승인 순서를 사용한다.
2. Stage 1~3 source/communication은 intermediate `devel` PR로 먼저 반영한다.
3. current `main` 전용 변경은 Stage 4에서 reviewed `main -> devel` back-merge로 보존한 뒤 `devel -> main` release PR을 진행한다.
4. strict static archive mismatch가 남으면 Rehearsal 전에 strict/portable 근거와 release artifact 허용 여부를 별도로 승인받는다.
5. Rehearsal, source PR merge, back-merge, release PR merge, tag, draft Publish, official Publish, Homebrew와 main closeout은 외부 mutation 승인표대로 각각 별도 승인받는다.
6. signed draft에서 실제 app/Finder provider, external fallback, 장문서 repaint와 인쇄/PDF를 official publish 전 차단 gate로 검증한다.
7. clean official v0.1.8 baseline에서 Sparkle update를 검증하고, baseline이 invalid하면 재설치 또는 대체 경로를 먼저 승인받는다.
8. publish 후 보정이 필요하면 main 대상 종료 정리 PR 하나로 모으고, 최종 Task #441 기록은 `devel`에도 일관되게 반영한다.

이 구현계획 승인 전에는 Stage 1 source metadata 수정, workflow 실행, PR 생성·merge, tag 또는 release 배포를 시작하지 않는다.
