# Task M900 #494 구현계획서

수행계획서: [task_m900_494.md](task_m900_494.md)

2026-09-06 작업지시자가 수행계획을 승인하고 구현계획서 작성을 지시했다. 이 문서는 승인된 범위를 6개 Stage의 변경·검증·산출물로 구체화한다. 현재 작업은 구현계획 작성이며, Stage 1의 실제 version/workflow 변경은 다음 진행 승인 후 시작한다.

## 기준과 공통 원칙

| 항목 | 값 |
|------|----|
| Issue / milestone | [#494](https://github.com/postmelee/alhangeul-macos/issues/494) / `Release Operations` (`M900`) |
| 통합 / 작업 / 게시 브랜치 | `devel` / `local/task494` / `publish/task494` |
| 작업 시작 devel | `eec7869fb958aec8e30df3a4e6cdaf67253c5a5a` |
| 수행계획 최초 commit | `04229a9` |
| 앱 version / build / tag | `0.1.11` / `17` / `v0.1.11` |
| previous_release_ref / commit | `v0.1.10` / `fafed425d4b87162c2188d1384d618adc2211eb6` |
| expected_rhwp_tag / commit | `v0.8.6` / `f1f9c6ae58344ee9368996d3543f76b9345cf227` |
| 제목 / 실행 정책 | `Alhangeul v0.1.11 (rhwp v0.8.6)`, `require_latest_rhwp=true`, `include_rhwp_in_title=true` |
| final candidate | Stage 4에서 main 반영 결과와 tag의 실제 commit으로 확정 |
| 검증 산출물 | `build.noindex/task494/` 아래 단계·산출물 종류별 디렉터리 |

- 각 단계는 승인된 변경과 검증 결과를 `mydocs/working/task_m900_494_stage{N}.md`에 남기고 함께 커밋한다. 새로운 실패·수정이 없으면 통과한 검증을 반복하지 않는다.
- 현재 worktree의 사용자 변경을 보존하며 `local/task494`를 원격에 직접 push하지 않는다. PR 게시에는 `publish/task494`를 사용한다.
- 릴리스 경로에서는 core/build-info/studio writer와 sync를 실행하지 않는다. source identity·Cargo·header·ABI mismatch를 lock 재생성으로 숨기지 않는다.
- 현재 명령과 보호 조건의 진실 원천은 repository script/workflow다. 이전 릴리스 문서의 버전·경로·기본값을 그대로 재사용하지 않는다.
- 이미 승인된 작업은 중복 승인받지 않는다. source PR merge, main merge, tag, rehearsal, draft/official publish, Pages·Sparkle, Homebrew 실행은 구체적인 대상·입력·효과를 제시한 승인 범위에 따라 진행한다.
- 이슈는 public 배포와 최종 기록이 끝날 때까지 유지한다. 중간 source PR 본문에는 `Refs #494`를 사용하고 조기 close keyword를 넣지 않는다.

## Stage 1. Release context와 source identity 정렬

**변경 파일:** 세 target의 `Info.plist`, `.github/workflows/release-rehearsal.yml`, `.github/workflows/release-publish.yml`, Stage 1 보고서와 오늘할일.

**작업:**

1. 최신 public app/upstream release, tag 미사용 상태, `origin/main`, `origin/devel`, 현재 작업 branch와 미커밋 변경을 확인한다. 새 제품 변경이나 upstream 이동이 발견되면 승인된 기준과 차이를 보고한다.
2. main 전용 commit의 parents·tree와 non-merge 변경을 확인한다. 기존 release transport와 PR #477 종료 정리의 내용이 devel에 보존됐는지 PR #478 및 현재 tree와 대조한다. 이력 차이만으로 back-merge하지 않고 실제 누락이 있으면 반영 경로를 제안한다.
3. 세 plist의 `CFBundleShortVersionString=0.1.11`, `CFBundleVersion=17`을 함께 수정한다.
4. 두 workflow의 기본 입력을 `version=0.1.11`, `previous_release_ref=v0.1.10`, `expected_rhwp_tag=v0.8.6`으로 정렬한다. trigger, permissions, environment, concurrency와 draft/prerelease 기본 정책은 변경 범위에 포함하지 않는다.
5. core lock·Cargo·Swift build-info와 bundled manifest의 tag/commit이 승인값과 일치하는지 확인하고 main/devel 판정 근거를 Stage 1 보고서에 기록한다.

**검증:**

```bash
git status --short --branch
git fetch origin --prune --tags
gh release view --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,targetCommitish
gh release view --repo edwardkim/rhwp --json tagName,isDraft,isPrerelease,targetCommitish
git rev-parse origin/main origin/devel 'v0.1.10^{commit}'
git log --format='%H %P %s' origin/devel..origin/main
git log --no-merges --oneline origin/devel..origin/main
git log --first-parent --merges --oneline v0.1.10..HEAD
git ls-remote --tags origin refs/tags/v0.1.11
for task494_target in HostApp QLExtension ThumbnailExtension; do
  plutil -lint "Sources/$task494_target/Info.plist"
  plutil -extract CFBundleShortVersionString raw -o - "Sources/$task494_target/Info.plist"
  plutil -extract CFBundleVersion raw -o - "Sources/$task494_target/Info.plist"
done
ruby -e 'require "psych"; ARGV.each { |p| Psych.parse_file(p) }' \
  .github/workflows/release-rehearsal.yml .github/workflows/release-publish.yml
scripts/verify-rhwp-core-build-info.sh
scripts/verify-rhwp-studio-assets.sh --tag v0.8.6 --commit f1f9c6ae58344ee9368996d3543f76b9345cf227
git diff --check
```

**완료 기준:** 세 target과 workflow 입력이 일치하고, main 전용 content 보존 여부 및 release source 범위가 기록돼 있다. 예상 밖 제품·권한 변경이 없다.

**커밋:** `Task #494 Stage 1: v0.1.11 release identity 정렬`

## Stage 2. 포함 PR 분석과 공개 문서 준비

**변경 파일:** `mydocs/release/v0.1.11.md`, release index, README, `docs/index.html`, updates index, `docs/updates/v0.1.11.html`, 이전 버전 banner 대상 페이지, Stage 2 보고서와 오늘할일.

**작업:**

1. `v0.1.10..candidate`의 PR body·연결 이슈·최종 보고서를 확인하고 표준 9개 column의 `포함 PR 분석` 표를 작성한다. 미완료 Issue #480 항목은 Stage 2 안전 차단만 반영된 후속 이슈로 유지한다.
2. 사용자 변화는 upstream sync PR #491 및 앱 PR #481/#483/#485/#486/#489/#493 변경에서 검증할 동작을 중심으로 작성한다. PR #487/#490 변경은 개발·배포 항목, PR #478 변경은 이전 릴리스 종료 정리로 분류한다.
3. 자동 helper의 오분류를 보정한다. PR #481 변경은 앱 저장 보호, PR #483 변경은 HWP3 변환 안전성이고, PR #493 관련 Issue #6635 항목은 `edwardkim/rhwp` 소속이다. 이전 공개 릴리스에서 해결한 이슈를 새 해결 목록에 다시 넣지 않는다.
4. release record에는 `## GitHub Release 본문 구조 후보` 아래 `변경 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`, `릴리즈 요약에 반영된 PR`, `해결된 Issue`, `참고/연관 Issue`의 여섯 `###` 절을 둔다. 현재 note writer가 이 구조를 읽는다.
5. GitHub Release 첫 본문 section은 `이번 버전의 주요 변경 사항`으로 유지한다. PR/Issue는 제목·링크·한 줄 설명을 포함하고, 설치·지원 환경·첫 실행·업데이트·Homebrew와 기술 세부를 뒤에 둔다.
6. Pages는 사용자용 변화와 설치 경로를 짧게 안내하고, 새 release asset 링크와 이전 버전 banner를 정렬한다. v0.1.10의 과거 저장 한계는 역사적 설명으로 보존한다. Homebrew는 v0.1.11 반영 전 완료로 표시하지 않는다.
7. 아직 실행하지 않은 검증과 digest를 성공·확정으로 쓰지 않는다. 본문 형식 검증용 64자리 0은 ignored 후보 파일에만 사용하고 public 게시 때 실제 artifact digest로 교체한다.

**검증:**

```bash
scripts/ci/write-release-pr-analysis.sh v0.1.10 HEAD build.noindex/task494/stage2/pr-analysis.md
scripts/ci/write-release-delta-checklist.sh v0.1.10 HEAD build.noindex/task494/stage2/delta-checklist.md
scripts/ci/write-release-notes.sh 0.1.11 \
  0000000000000000000000000000000000000000000000000000000000000000 \
  build.noindex/task494/stage2/release-notes-template.md
scripts/ci/check-release-notes-template.sh build.noindex/task494/stage2/release-notes-template.md
scripts/validate-github-body.sh build.noindex/task494/stage2/release-notes-template.md
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
git diff --check
```

추가로 생성한 Pages 문서의 링크·파일명·version과 실제 화면을 확인한다. 공개 appcast를 내려받아 XML 검사 후 `prepare-pages-artifact.sh`에 전달해 로컬 artifact를 만들고, 원본 appcast와 byte가 같은지 확인한다. 저장소의 stale `docs/appcast.xml`로 대체하지 않는다.

**완료 기준:** 모든 공개 요약에 근거 PR/report가 있고 해결·관련 이슈가 구분된다. 본문 구조·링크·banner가 검증됐으며 새 배포 완료를 미리 주장하지 않는다.

**커밋:** `Task #494 Stage 2: v0.1.11 릴리스 문서와 포함 PR 분석 작성`

## Stage 3. Source·앱·package와 rehearsal 검증

**대상:** Stage 1~2 후보 source, core·Studio·ABI, 앱과 테스트. 추적 변경은 검증 기록과 필요한 승인 범위의 보정에 한정한다.

**작업:**

1. exact upstream v0.8.6 checkout을 `build.noindex/task494/upstream-rhwp`에 준비하고 checkout HEAD 및 root Cargo.lock fingerprint를 bundled verifier로 비교한다.
2. `build-rust-macos.sh --verify-lock`의 strict 결과를 기록한다. static archive hash/size만 다르면 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`로 별도 진단하고 source/Cargo/header/symbol 검증과 실패 항목을 구분한다. rehearsal에 사용할 artifact 허용 기준은 근거와 함께 확정한다.
3. core/build-info/studio·decoder fixture, Rust locked tests, HostAppTests와 ExternalImageTests를 실행한다. 문서 fixture 원본 hash·크기·수정 시각을 보존하고 저장 결과는 task 경로에만 둔다.
4. XcodeGen을 실행하고 생성 diff를 검토한다. HostApp Debug와 universal Release를 빌드해 포함된 두 extension까지 검증한다. Debug/Release endpoint가 각 configuration 계약에 맞는지도 확인한다.
5. native renderer와 Quick Look/Thumbnail 정책 smoke를 실행한다. 실제 GUI 검증과 headless 검증 결과를 구분한다.
6. 개발 zip과 승인된 rehearsal 산출물을 별도 디렉터리에 생성한다. package helper는 지정 build root의 release 디렉터리를 정리하므로 다른 산출물 경로를 재사용하지 않는다.
7. workflow rehearsal을 선택하면 승인된 candidate를 `publish/task494`로 게시하고 exact workflow head를 확인한다. 로컬 rehearsal을 사용한 경우 그 근거와 차이를 기록하며 양쪽을 불필요하게 반복하지 않는다.

**기본 검증 명령:**

```bash
scripts/build-rust-macos.sh --verify-lock
cargo test --manifest-path RustBridge/Cargo.toml --locked
scripts/check-no-appkit.sh
scripts/ci/test-rhwp-core-build-info.sh
scripts/verify-rhwp-core-build-info.sh
scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
scripts/verify-rhwp-studio-assets.sh --tag v0.8.6 \
  --commit f1f9c6ae58344ee9368996d3543f76b9345cf227 \
  --upstream-dir build.noindex/task494/upstream-rhwp
scripts/ci/test-render-tree-decoder.sh
scripts/ci/test-app-execution-endpoint-config.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build.noindex/task494/tests CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Alhangeul.xcodeproj -scheme ExternalImageTests \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build.noindex/task494/tests CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/task494/debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build.noindex/task494/release-build \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
scripts/ci/verify-app-execution-endpoint-config.sh \
  --debug-app build.noindex/task494/debug/Build/Products/Debug/Alhangeul.app \
  --release-app build.noindex/task494/release-build/Build/Products/Release/Alhangeul.app
scripts/ci/verify-universal-macos-app.sh build.noindex/task494/release-build/Build/Products/Release/Alhangeul.app
scripts/validate-stage3-render.sh build.noindex/task494/render
scripts/smoke-quicklook-skia-policy.sh build.noindex/task494/quicklook \
  samples/basic/KTX.hwp samples/hwpx/hwpx-01.hwpx
scripts/smoke-thumbnail-skia-policy.sh build.noindex/task494/thumbnail \
  samples/basic/KTX.hwp samples/hwpx/hwpx-01.hwpx samples/복학원서.hwp
ALHANGEUL_BUILD_ROOT="$PWD/build.noindex/task494/package" scripts/package-release.sh 0.1.11
scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
```

strict staticlib mismatch 진단은 기본 검증과 별도로 로그를 남긴다. portable 허용 후 package/rehearsal을 실행하는 경우 해당 환경변수 사용 사실과 계속 검증되는 경계를 보고한다. 개발 앱 등록이 남으면 표준 helper의 개발 경로 정리만 수행하고 기존 설치본 등록은 보존한다.

**별도 승인된 로컬 rehearsal 명령:**

```bash
scripts/release.sh --skip-notarize --output build.noindex/task494/rehearsal 0.1.11
hdiutil verify build.noindex/task494/rehearsal/alhangeul-macos-0.1.11-rehearsal.dmg
```

**완료 기준:** provenance·테스트·build·package의 통과/실패 경계가 명확하고, 실제 rehearsal 결과 또는 미진행 사유가 있다. source 준비 PR 본문에 담을 검증 결과와 미완료 배포 단계가 정리돼 있다.

**커밋:** `Task #494 Stage 3: 릴리스 후보 source와 package 검증`

## Stage 4. Source PR·main·tag와 서명된 draft 검증

**대상:** source 준비 PR, release transport PR, 최종 tag, GitHub draft asset, Stage 4 보고서와 release record.

**작업과 실행 순서:**

1. Stage 1~3 완료 기록과 검증한 body-file로 `publish/task494 → devel` source PR을 게시한다. 최종 완료 보고와 구분하며 `Refs #494`로 남긴다. CI와 검토 결과를 확인하고 승인된 head를 merge한다.
2. main/devel content를 다시 비교해 필요한 반영만 정렬한다. release PR의 예정 merge 결과가 승인된 devel candidate content를 보존하는지 확인한다.
3. `devel → main` PR merge 전에 docs-only Pages의 `Check release asset availability` gate와 public 상태를 확인한다. 현재 gate는 DMG asset 존재를 검사하고 draft 여부는 직접 검사하지 않는다. merge 뒤 생성된 실제 run에서 v0.1.11 asset 부재로 배포가 보류됐는지 확인하고, 그 확인을 마친 뒤 draft 생성으로 넘어간다.
4. 승인된 main merge 후 commit·tree를 확인하고 annotated `v0.1.11` tag 생성·push를 진행한다. final candidate와 tag가 다르면 Publish를 실행하지 않는다.
5. 서명 환경과 필요한 secret 이름의 등록 여부를 확인한다. 비밀 값은 조회·출력하지 않는다. `github-pages`의 main/tag deployment 허용과 `pages-deploy` 직렬화 설정을 확인한다.
6. 아래 입력으로 승인된 draft Publish를 실행한다. run head·tag·upstream identity, 서명·공증·staple·Gatekeeper, asset/checksum을 확인하고 stable appcast·Pages skip을 정상 조건으로 기록한다.
7. draft가 존재하는 동안 docs-only workflow 재실행이나 main docs 변경이 필요해지면 공개 영향부터 다시 확인한다. asset 존재만으로 아직 draft인 새 버전의 Pages가 공개돼도 된다고 판단하지 않는다.
8. draft DMG를 별도 경로에 내려받고 checksum·크기·universal·Legal·copyright·DMG layout을 확인한다. app/extension 및 Sparkle nested component의 서명 경계를 검증한다.
9. 서명된 draft 앱을 직접 지정해 maintainer 앱·Finder 설치 smoke를 수행한다. `--version`만 주어 개발 package를 다시 만드는 경로는 이 검증에 사용하지 않는다. 검증 후 이전 public 설치본과 등록 상태를 복원해 실제 Sparkle 업데이트 기준을 남긴다.

**승인 후 workflow 입력:**

```bash
gh workflow run release-publish.yml --repo postmelee/alhangeul-macos --ref v0.1.11 \
  -f version=0.1.11 -f previous_release_ref=v0.1.10 -f expected_rhwp_tag=v0.8.6 \
  -f require_latest_rhwp=true -f include_rhwp_in_title=true -f draft=true -f prerelease=false
```

**서명된 앱 확보 후 검증:**

```bash
task494_draft_app="$PWD/build.noindex/task494/draft/Alhangeul.app"
scripts/ci/verify-universal-macos-app.sh "$task494_draft_app"
codesign --verify --deep --strict --verbose=2 "$task494_draft_app"
xcrun stapler validate "$task494_draft_app"
spctl --assess --type execute --verbose "$task494_draft_app"
scripts/smoke-finder-integration.sh --app "$task494_draft_app" \
  --output-dir "$PWD/build.noindex/task494/draft-finder"
```

DMG 자체의 SHA256·stapler·Gatekeeper와 layout 검증도 병행한다. maintainer가 실제 HWP/HWPX 열기, 원본 보존 저장, PDF·인쇄, 색상 선택기, Finder preview/thumbnail을 확인한 결과를 기록한다. 자동 renderer 성공으로 수동 확인을 대체하지 않는다. 재현 가능한 후보 결함은 수정 범위를 보고하고, 변경된 후보를 다시 build·draft 검증한다.

**완료 기준:** main/tag와 signed draft가 같은 후보를 가리키고 필수 설치 smoke를 통과한다. public latest·Pages·appcast는 의도한 기존 공개 상태다. 미실행 Intel 실기기 등은 별도 기록한다.

**커밋:** `Task #494 Stage 4: v0.1.11 signed draft 검증과 release 기준 확정`

## Stage 5. Official 공개·업데이트·Homebrew

**대상:** GitHub Release, public DMG, Pages·Sparkle, 실제 설치본, 승인된 Cask 변경과 결과 기록.

**작업:**

1. draft 검증 이후 tag·candidate·본문·Pages source 변경 여부와 최신 upstream을 확인한다. 새 source 변경이 있으면 해당 검증으로 돌아간다.
2. official Publish와 Pages·Sparkle 공개 범위가 승인되면 아래 입력으로 실행한다. 동일 tag라도 workflow가 DMG를 다시 생성하므로 draft와 official checksum을 별도로 기록한다.
3. GitHub Release가 non-draft/non-prerelease이고 public DMG URL·size·SHA256이 workflow summary 및 checksum asset과 일치하는지 확인한다. official DMG 서명·공증·universal도 검증한다.
4. Pages deploy 성공, 최신 다운로드, 업데이트 문서·이전 버전 banner, appcast `0.1.11 (17)`·DMG URL·length·EdDSA signature를 확인한다.
5. 유효한 기존 public `v0.1.10 (16)` 설치본에서 Sparkle download/install/relaunch를 수행한다. extension refresh 기본 모드와 실제 provider를 확인하고 수동 등록 보정으로 통과시킨 결과를 자연 업데이트 성공으로 기록하지 않는다.
6. Homebrew 승인 후 같은 official DMG digest로 repository/tap Cask를 갱신한다. tap context에서 style/audit·install/uninstall을 검증하고 기존 사용자 설치 상태를 복원한다. `audit --new`는 upstream 제출 참고 기준으로 일반 tap 공개 gate와 구분한다.

**승인 후 실행 및 검증:**

```bash
gh workflow run release-publish.yml --repo postmelee/alhangeul-macos --ref v0.1.11 \
  -f version=0.1.11 -f previous_release_ref=v0.1.10 -f expected_rhwp_tag=v0.8.6 \
  -f require_latest_rhwp=true -f include_rhwp_in_title=true -f draft=false -f prerelease=false
gh release view v0.1.11 --repo postmelee/alhangeul-macos --json tagName,isDraft,isPrerelease,assets,url
scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.11 --expected-build 17
scripts/smoke-finder-integration.sh --app /Applications/Alhangeul.app \
  --output-dir "$PWD/build.noindex/task494/public-finder"
```

Homebrew 반영에는 `scripts/update-cask-sha256.sh 0.1.11 <검증한-official-checksum-file>`을 사용하고, `postmelee/tap` 문맥에서 `brew style --cask alhangeul`, `brew audit --cask alhangeul`, fully-qualified install/uninstall을 수행한다. 이전에 받은 승인 범위 내에서 실행하며 새 전역 신뢰 설정을 추가하지 않는다.

**완료 기준:** public Release·DMG·Pages·appcast가 같은 version/build/artifact를 가리키고 실제 업데이트 결과가 있다. Homebrew 결과 또는 미진행 결정, 설치·등록 복원 상태가 기록돼 있다.

**커밋:** `Task #494 Stage 5: v0.1.11 공개 배포와 업데이트 검증`

## Stage 6. 결과 기록과 종료 정리

**변경 파일:** release record/index, `task_m900_494_report.md`, Stage 6 보고서, 계획·orders 상태, 필요 시 README·Pages·Cask 최종 문구.

**작업:**

1. final tag/commit, core/studio provenance, 모든 PR·workflow URL, draft/official digest·size, trust 검증·앱/Finder·Sparkle·Homebrew 결과를 확정한다.
2. 미실행 항목, 실패 후 재검증과 알려진 한계를 사실대로 정리한다. #480 및 upstream 후속을 이 릴리스의 완료 이슈로 닫지 않는다.
3. 공개 문구와 실제 배포가 다르면 GitHub Release body 후보를 검증하고, 필요한 main 문서 정정은 한 종료 정리 PR로 모은다. 본문 갱신과 PR merge는 승인 범위에 따라 실행한다.
4. main closeout Pages run이 기존 public appcast byte를 보존하는지 확인하고 devel에도 필요한 최종 기록을 반영한다. official tag는 다시 지정하지 않는다.
5. 최종 보고 승인과 관련 PR merge 후 Issue #494 완료 처리, 해당 task의 로컬·원격 branch와 임시 worktree를 정리하고 `devel`로 돌아온다. 다음 작업에 필요한 재현 자료는 기록된 경로로 남긴다.

**검증:** release note/body validator, version notice 검사, public 문구·link와 실제 최신 asset 확인, `git diff --check`, 대상 PR diff·CI 및 main/devel 기록 일치 확인. 제품 source가 바뀌지 않은 종료 정리에는 앱 build를 반복하지 않는다.

**완료 기준:** 공개 상태와 저장소 기록이 일치하고 이슈·PR·부산물 정리가 확인된다.

**커밋:** `Task #494 Stage 6 + 최종 보고서: v0.1.11 릴리스 종료 정리`

## 검증 실패와 승인 범위

- 입력 identity나 target SHA가 승인 범위와 다르면 변경 원인을 확인하고 필요한 판단을 요청한다. 단순 문서 커밋으로 HEAD가 이동한 경우 제품 tree와 공개 입력 변화 여부를 함께 설명한다.
- source/header/ABI, bundled asset, Release endpoint, universal, signing/notarization 또는 필수 설치 smoke 실패는 해당 단계에서 해결해야 한다. 관련 없는 검증 성공을 배포 승인 근거로 대체하지 않는다.
- `main` 자동 Pages와 draft/official Publish의 공개 효과를 함께 확인한다. unexpected public 상태가 발견되면 원인과 복구 범위를 정리해 보고한다.
- 단계 승인은 그 단계의 구체적인 작업 범위를 승인한 것으로 적용한다. 추가 외부 실행 승인이 필요한 경우 검증한 후보·명령·효과를 준비한 뒤 요청하고, 이미 받은 승인을 반복해서 요구하지 않는다.

## 구현계획 승인 요청

위 6단계와 검증 기준을 승인하고 **Stage 1: release context 확인 및 세 target version/build·두 workflow 입력 정렬**을 진행한다. 이 요청에는 릴리스 게시나 tag 생성이 포함되지 않는다.

진행 순서는 [타스크 진행 절차 매뉴얼](../manual/task_workflow_guide.md), 배포 순서는 [public release runbook](../manual/public_release_runbook.md)을 따른다. 수행계획 승인은 반영됐으며, 이번 구현계획의 다음 단계 진행 지시를 받은 뒤 Stage 1을 시작한다.
