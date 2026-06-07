# 메인테이너용 public release 실행 runbook

## 목적

이 문서는 `alhangeul-macos` public release 당일에 작업지시자와 에이전트가 순서대로 확인할 실행 runbook이다. 특정 버전의 기록물이 아니라, 매 릴리즈마다 최신 release context를 다시 수집하고 검증하기 위한 반복 절차다.

세부 정책과 배경 설명은 [`release_distribution_guide.md`](release_distribution_guide.md)와 하위 매뉴얼을 따른다. 이 runbook은 어느 문서를 어떤 순서로 읽고, 어떤 값을 확정하고, 어느 gate에서 멈춰야 하는지를 다룬다.

## 사용 시점

다음 요청을 받았을 때 이 문서를 먼저 읽는다.

- 새 public DMG release 준비
- `Release Rehearsal DMG` 또는 `Release Publish DMG` workflow 실행
- GitHub Release asset 게시
- Sparkle stable appcast와 Pages 업데이트
- Homebrew Cask public DMG SHA256 반영
- public release 실패 후 rollback 판단

릴리즈 후보를 만드는 일반 개발 task는 이 문서만으로 시작하지 않는다. 새 기능, 버그 수정, 버전 갱신, release note 준비는 별도 GitHub Issue와 하이퍼-워터폴 절차로 진행한 뒤 이 runbook에 들어온다.

## 권한과 중단 원칙

- public release 실행은 작업지시자의 명시 지시가 있을 때만 시작한다.
- Git tag 생성, `Release Publish DMG` 실행, GitHub Release 게시, Sparkle appcast 갱신, Pages deployment, Homebrew tap 반영은 각각 별도 승인 gate로 본다.
- signed/notarized DMG 설치 smoke는 public publish 전 필수 gate다. `draft=true`, `prerelease=false` 실행은 pre-public 검증이고, `draft=false`, `prerelease=false` 실행은 별도 승인된 official stable publish다.
- workflow 기본값은 stale할 수 있다. `workflow_dispatch` 화면의 기본값을 그대로 사용하지 말고 항상 현재 release context와 대조한다.
- password, app-specific password, App Store Connect API private key, exported signing identity, keychain credential payload, Sparkle private key, GitHub token은 문서, commit, PR, shell history에 남기지 않는다.
- 실행하지 않은 수동 smoke, Intel Mac 실기기 확인, Sparkle 업데이트 확인은 성공으로 기록하지 않는다. 미실행 사유를 release record에 남긴다.
- 어느 gate에서든 기준값이 불명확하거나 산출물 계층이 섞이면 즉시 중단하고 release owner 확인을 받는다.

## 필수 참조 문서

| 문서 | 읽는 시점 |
|------|-----------|
| [`release_distribution_guide.md`](release_distribution_guide.md) | 릴리즈 작업 진입 시 전체 흐름과 체크리스트 확인 |
| [`release_policy_guide.md`](release_policy_guide.md) | 배포 브랜치, 산출물 계층, 사용자 안내 기준 판단 |
| [`ci_workflow_guide.md`](ci_workflow_guide.md) | release workflow input, 권한, artifact, Pages deployment 기준 확인 |
| [`release_packaging_dmg_guide.md`](release_packaging_dmg_guide.md) | release script, rehearsal/public DMG, Finder smoke 확인 |
| [`release_signing_notarization_guide.md`](release_signing_notarization_guide.md) | Developer ID, notarytool, signing preflight, Gatekeeper 검증 확인 |
| [`release_github_pages_sparkle_guide.md`](release_github_pages_sparkle_guide.md) | GitHub Release body, Pages, Sparkle appcast, 포함 PR 분석, delta checklist 확인 |
| [`release_homebrew_cask_guide.md`](release_homebrew_cask_guide.md) | public DMG SHA256 확정 후 Cask 갱신과 tap 검증 확인 |
| [`../tech/release_environment.md`](../tech/release_environment.md) | 비밀이 아닌 운영 식별자와 GitHub Actions variable/secret 이름 확인 |

## Gate 0. Release context 수집

릴리즈를 시작하기 전에 현재 최신 공개 앱 릴리즈, upstream `rhwp`, local candidate 상태를 수집한다. 이 값은 매번 다시 계산한다.

```bash
git status --short --branch
git fetch origin
gh release view --repo postmelee/alhangeul-macos \
  --json tagName,name,isDraft,isPrerelease,publishedAt,url,targetCommitish
gh release view --repo edwardkim/rhwp \
  --json tagName,name,isDraft,isPrerelease,publishedAt,url,targetCommitish
cat rhwp-core.lock
sed -n '1,40p' Sources/HostApp/Resources/rhwp-studio/manifest.json
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
plutil -extract CFBundleVersion raw -o - Sources/ThumbnailExtension/Info.plist
sed -n '1,40p' .github/workflows/release-rehearsal.yml
sed -n '1,50p' .github/workflows/release-publish.yml
sed -n '1,40p' Casks/alhangeul.rb
```

확인해서 release owner에게 보고할 값:

| 항목 | 기록할 값 |
|------|-----------|
| 최신 공개 앱 release | `v<latest-app-version>` |
| 최신 공개 앱 release 상태 | draft/prerelease 여부, publishedAt, URL |
| 직전 public release ref | 보통 `v<latest-app-version>` |
| 최신 upstream `rhwp` release | `v<latest-rhwp-version>` |
| candidate branch/commit | release 후보 branch와 commit hash |
| app/extension version | HostApp, Quick Look, Thumbnail의 short version/build |
| `rhwp-core.lock` | release tag, resolved commit |
| bundled `rhwp-studio` manifest | release tag, resolved commit |
| workflow default | rehearsal/publish의 `version`, `previous_release_ref`, `expected_rhwp_tag` |
| Cask source | repository Cask version/SHA256 |

중단 기준:

- working tree에 의도하지 않은 변경이 있다.
- release candidate commit이 확정되지 않았다.
- app/extension version 또는 build number가 서로 다르다.
- `rhwp-core.lock`과 bundled `rhwp-studio` manifest가 서로 다른 upstream 기준을 가리킨다.
- workflow default가 candidate와 다르지만 release owner가 입력값 override를 확정하지 않았다.
- upstream latest와 candidate lock이 다르고 `require_latest_rhwp=false` 예외 승인이 없다.

## Gate 1. Release identity 확정

release owner가 다음 값을 명시적으로 확정해야 한다.

| 값 | 기준 |
|----|------|
| `version` | 앱 release version. Git tag, DMG filename, Sparkle short version, Homebrew version 기준 |
| `build` | `CFBundleVersion`. 직전 public build보다 커야 한다 |
| `candidate commit` | public release 기준 commit. tag가 가리킬 commit |
| `previous_release_ref` | 포함 PR 분석과 delta checklist 기준 직전 public release tag 또는 commit |
| `expected_rhwp_tag` | `rhwp-core.lock`과 bundled manifest가 가리켜야 할 upstream release tag |
| `require_latest_rhwp` | upstream latest와 lock tag 일치 강제 여부 |
| `include_rhwp_in_title` | GitHub Release title에 `(rhwp vX.Y.Z)`를 병기할지 여부 |
| `draft` / `prerelease` | GitHub Release와 stable appcast/Pages 실행 여부를 결정 |

판정 기준:

- 앱 자체 bugfix, packaging, Pages/appcast, Homebrew, 문서 중심 release는 기본 title `Alhangeul v<version>`을 사용한다.
- upstream `rhwp` 반영이 release의 중심 사용자-facing 변화이면 `Alhangeul v<version> (rhwp v<expected-rhwp-tag>)` 병기를 검토한다.
- `draft=true`, `prerelease=false`는 signed/notarized DMG를 생성해 maintainer 설치 smoke를 수행하는 pre-public 검증 단계로 본다. 이 단계는 stable appcast와 Pages deployment를 성공 조건에 포함하지 않는다.
- `draft=false`, `prerelease=false`일 때만 official stable release로 보고 Sparkle stable appcast와 Pages deployment까지 성공 조건에 포함한다.
- `previous_release_ref`가 틀리면 포함 PR 분석과 delta checklist가 틀리므로 publish 전 반드시 previous/candidate ref를 확인한다.

## Gate 1.5. 포함 PR 분석

release owner가 `previous_release_ref`와 `candidate commit`을 확정한 뒤, release note를 쓰기 전에 포함 PR 분석을 먼저 수행한다.

확인 명령 예시:

```bash
git log --oneline --merges <previous-release-ref>..<candidate-ref>
git log --first-parent --oneline --merges <previous-release-ref>..<candidate-ref>
gh pr view <PR-number> --repo postmelee/alhangeul-macos --json number,title,body,mergedAt,mergeCommit,files,url
find mydocs/report -maxdepth 1 -name 'task_*_<issue>_report.md' -print
```

확인 대상:

| 항목 | 기준 |
|------|------|
| merge PR 목록 | release transport PR과 실제 포함 작업 PR을 구분한다 |
| PR body | title, summary, closing keyword, linked Issue, related/ref Issue를 읽는다 |
| 최종 보고서 | 내부 task PR이면 `mydocs/report/task_*_<issue>_report.md` 후보를 읽는다 |
| 분류 | 사용자-facing, 개발자-facing, 운영/배포, 문서-only, upstream sync 중 하나로 기록한다 |
| 사용자-facing 여부 | GitHub Release와 Pages의 `변경 요약` / `알한글 앱 변화` 근거로 쓸지 release owner가 확정한다 |
| Issue 구분 | 대상 타스크 Issue, closing keyword, release record 완료 확정 항목만 해결된 Issue로 쓰고, 참고/연관 Issue와 분리한다 |

`mydocs/release/v<version>.md`에는 `포함 PR 분석` 표를 남긴다. 표준 column은 `PR`, `제목`, `분류`, `사용자-facing`, `공개 요약 반영`, `해결된 Issue`, `참고/연관 Issue`, `근거 문서`, `비고`다.

중단 기준:

- `previous_release_ref..candidate_ref` 범위가 확정되지 않았다.
- merge PR 목록이 release transport PR만 보여 실제 포함 작업 PR을 놓칠 가능성이 있다.
- 사용자-facing으로 판정한 PR의 최종 보고서 또는 PR body를 확인하지 못했다.
- 해결된 Issue와 참고/연관 Issue가 구분되지 않았다.
- `변경 요약` 또는 `알한글 앱 변화`가 사용자-facing으로 판정되지 않은 운영/문서/source metadata 변경을 주요 앱 변화처럼 설명한다.

## Gate 2. Source preflight

release candidate source가 identity와 일치하는지 확인한다.

```bash
git status --short --branch
bash scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag
bash scripts/ci/read-rhwp-core-lock.sh rhwp_commit
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
```

Release configuration 검증은 [`release_packaging_dmg_guide.md`](release_packaging_dmg_guide.md)를 따른다. public release 산출물은 app과 extension 실행 파일이 `arm64 + x86_64` universal slice를 포함해야 한다.

확인 대상:

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `rhwp-core.lock`
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-ffi-symbols.txt`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- README 최신 release 요약
- `docs/updates/v<version>.html`
- `docs/updates/index.html`
- `mydocs/release/v<version>.md`
- `THIRD_PARTY_LICENSES.md`
- `Sources/HostApp/Resources/Legal/*`
- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`

중단 기준:

- lock/source/header/ABI 검증이 실패한다.
- bundled `rhwp-studio` manifest 검증이 실패한다.
- app/extension version/build가 확정값과 다르다.
- release note, Pages, README가 아직 이전 release를 latest로 안내한다.
- public DMG에 포함될 Legal 문서가 canonical 문서와 다르다.

## Gate 3. Rehearsal DMG

public publish 전에 rehearsal이 필요하면 release owner 승인 후 `Release Rehearsal DMG` workflow 또는 로컬 rehearsal mode를 사용한다.

GitHub Actions 예시:

```bash
gh workflow run "Release Rehearsal DMG" \
  --ref <candidate-ref> \
  -f version=<version> \
  -f previous_release_ref=<previous-release-ref> \
  -f expected_rhwp_tag=<expected-rhwp-tag>
```

로컬 예시:

```bash
./scripts/release.sh --skip-notarize <version>
```

확인 항목:

- rehearsal workflow summary의 `rhwp core`, `Release delta checklist`, `Rehearsal artifact`
- artifact의 previous ref와 candidate ref
- rehearsal DMG와 `.sha256`
- `hdiutil verify`
- rehearsal app/extension universal slice
- DMG layout smoke

주의:

- rehearsal DMG는 public GitHub Release asset, Sparkle appcast enclosure, Homebrew Cask URL/SHA256으로 사용하지 않는다.
- unsigned rehearsal 결과는 signing/notarization 통과로 기록하지 않는다.
- rehearsal에서 생성된 delta checklist는 초안이다. release owner가 누락/과잉 항목을 보정해야 한다.

## Gate 4. Pre-public signed/notarized DMG smoke

signed/notarized DMG smoke는 public publish 전에 통과해야 하는 blocking gate다. 이 gate는 GitHub Release를 official stable release로 공개하거나 stable appcast/Pages를 갱신하기 위한 단계가 아니다.

사전 조건:

- release candidate commit이 `main`에 반영되어 있다.
- `v<version>` tag가 정확한 candidate commit을 가리킨다.
- GitHub Release body, Pages 업데이트 문서, README 최신 요약, 내부 release record가 마지막 candidate commit 기준으로 다시 검토되어 있다.
- `release` environment의 GitHub Actions variable/secret이 준비되어 있다.
- release owner가 `draft=true`, `prerelease=false` 입력으로 pre-public DMG smoke 실행을 승인했다.

사용자-facing release note 최종 확인:

- `변경 요약`은 특정 샘플 문서명이나 issue 번호가 아니라 사용자가 보는 증상과 개선 결과로 일반화되어 있다.
- `변경 요약`과 `알한글 앱 변화`는 `포함 PR 분석` 표에서 사용자-facing으로 판정된 항목만 기준으로 작성되어 있다.
- GitHub Release body의 첫 top-level section은 `이번 버전의 주요 변경 사항`이다.
- GitHub Release body에는 `이번 릴리즈 관련 PR과 Issue` section이 있고, 릴리즈 요약에 반영된 PR, 해결된 Issue, 참고/연관 Issue가 분리되어 있다.
- GitHub Release body의 PR/Issue 항목은 `#<number>`만 단독으로 두거나 inline code로 감싸지 않고, `[#<number>: 제목](URL) - 한 줄 설명` 형식으로 작성되어 있다.
- 해결된 Issue는 대상 타스크 Issue, PR body closing keyword, 또는 release record 완료 확정 항목만 포함한다.
- `Related`, `Refs`, 선행/연관, 단순 참고 Issue는 참고/연관 Issue로 분리한다.
- 이전 public release에서 이미 해결된 Issue는 public GitHub Release body에 다시 나열하지 않고 `포함 PR 분석` 표의 PR별 참고 근거로만 둔다.
- `다운로드 및 설치`는 `다운로드`, `지원 환경`, `설치 후 첫 실행`, `업데이트 확인`, `Homebrew` 하위 section으로 구분되어 있다.
- `알한글 앱 변화`는 HostApp, Quick Look preview, Finder thumbnail, 설치, 업데이트처럼 앱 저장소가 소유한 사용자-visible 변화를 먼저 설명한다. 앱 자체 신규 기능이 크지 않으면 1~2개 bullet로 짧게 쓰고, source metadata, workflow default, README/Pages 정렬, 단순 version bump를 사용자-facing 변화처럼 나열하지 않는다.
- GitHub Release body에는 `mydocs/release/v<version>.md` 같은 실제 조회 가능한 상세 문서를 GitHub blob URL로 링크한다.
- 구현 용어는 사용자 용어로 번역되어 있다. 예를 들어 PUA는 특수 문자/기호 표시, shade sentinel은 텍스트 배경/음영 표시처럼 설명한다.
- GitHub Release에 샘플 파일명, PUA, sentinel, CoreGraphics, PR/Issue 같은 개발자/검증자용 정보가 필요하면 `기술 세부` 또는 `검증 세부` section으로 분리되어 있고, 요약보다 뒤에 있다.
- Pages 업데이트 문서에는 기술 세부 section을 두지 않고, 해당 정보는 GitHub Release의 기술 세부 또는 내부 release record로 연결된다.
- workflow default, manifest, checksum, release record 정렬 같은 운영 정보는 주요 변경 요약이 아니라 상세 기록 또는 내부 release record에 둔다.
- `릴리즈 delta 기반 추가 확인 항목`처럼 release owner용 절차 문구는 public GitHub Release body에 두지 않고 내부 release record와 workflow artifact로 분리한다.

GitHub Actions 예시:

```bash
gh workflow run "Release Publish DMG" \
  --ref v<version> \
  -f version=<version> \
  -f previous_release_ref=<previous-release-ref> \
  -f expected_rhwp_tag=<expected-rhwp-tag> \
  -f require_latest_rhwp=<true-or-false> \
  -f include_rhwp_in_title=<true-or-false> \
  -f draft=true \
  -f prerelease=false
```

workflow가 확인해야 하는 것:

- tag ref와 checkout HEAD 일치
- `rhwp-core.lock`의 `expected_rhwp_tag` 일치
- `require_latest_rhwp=true`인 경우 upstream latest 일치
- Developer ID certificate import
- notarytool credential store
- `./scripts/release.sh <version>` public mode 성공
- signed/notarized DMG와 `.sha256` 생성
- GitHub draft release asset 또는 Actions artifact upload
- stable appcast 생성과 Pages artifact deploy skip

중단 기준:

- tag가 candidate commit과 다르다.
- signed/notarized DMG 생성, staple, Gatekeeper 검증 중 하나라도 실패한다.
- GitHub Release가 의도와 다르게 non-draft official release로 공개됐다.
- draft/prerelease 실행인데 stable appcast 또는 Pages deployment가 갱신됐다.
- draft DMG SHA256이 workflow summary, asset, release record 입력과 일치하지 않는다.

maintainer smoke:

- draft release asset 또는 Actions artifact DMG를 release machine에 내려받는다.
- DMG mount layout, app first launch, Finder Quick Look preview, Finder thumbnail을 확인한다.
- 가능한 경우 다음 명령으로 Gatekeeper, universal slice, Sparkle extension refresh를 확인한다.

```bash
shasum -a 256 -c build.noindex/release/alhangeul-macos-<version>.dmg.sha256
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/alhangeul-macos-<version>.dmg
spctl --assess --type execute --verbose build.noindex/release/Alhangeul.app
spctl --assess --type open --context context:primary-signature --verbose build.noindex/release/alhangeul-macos-<version>.dmg
scripts/smoke-finder-integration.sh --version <version>
scripts/smoke-sparkle-extension-refresh.sh \
  --expected-version <version> \
  --expected-build <build>
```

주의:

- draft DMG는 Homebrew Cask URL/SHA256, Sparkle enclosure, public Pages 다운로드 링크로 사용하지 않는다.
- 실행하지 못한 smoke는 성공으로 쓰지 않고 release record에 미실행 사유를 남긴다.
- draft smoke 이후 bugfix, tag 재지정, candidate commit 변경이 있으면 Gate 2 또는 Gate 4로 돌아가 사용자-facing 주요 변경 사항과 산출물을 다시 확인한다.

## Gate 5. Official stable publish

official stable publish는 Gate 4의 signed/notarized draft DMG smoke가 통과한 뒤, release owner가 `draft=false`, `prerelease=false` 실행을 별도로 승인한 경우에만 진행한다.

사전 조건:

- Gate 4 draft signed/notarized DMG smoke가 통과했다.
- GitHub Release body, Pages 업데이트 문서, README 최신 요약, 내부 release record가 draft smoke 이후 최종 candidate 기준으로 다시 검토되어 있다.
- `github-pages` environment가 release tag deployment를 허용한다.
- `SPARKLE_ED_PRIVATE_KEY` secret이 stable appcast signing에 사용할 수 있게 등록되어 있다.

GitHub Actions 예시:

```bash
gh workflow run "Release Publish DMG" \
  --ref v<version> \
  -f version=<version> \
  -f previous_release_ref=<previous-release-ref> \
  -f expected_rhwp_tag=<expected-rhwp-tag> \
  -f require_latest_rhwp=<true-or-false> \
  -f include_rhwp_in_title=<true-or-false> \
  -f draft=false \
  -f prerelease=false
```

workflow가 확인해야 하는 것:

- tag ref와 checkout HEAD 일치
- `rhwp-core.lock`의 `expected_rhwp_tag` 일치
- `require_latest_rhwp=true`인 경우 upstream latest 일치
- signed/notarized DMG와 `.sha256` 생성
- GitHub Release asset upload
- non-draft/non-prerelease 상태 검증
- Sparkle appcast 생성과 Pages artifact deploy

중단 기준:

- Gate 4 이후 candidate commit, tag, release body가 바뀌었는데 draft smoke를 반복하지 않았다.
- GitHub Release가 의도와 다르게 draft/prerelease 상태다.
- appcast signing 또는 Pages deployment가 실패한다.
- official stable public DMG SHA256이 release note, asset, Cask 반영 입력과 일치하지 않는다.

## Gate 6. Public artifact 확인

workflow 완료 후 다음을 확인한다.

```bash
gh release view v<version> --repo postmelee/alhangeul-macos \
  --json tagName,name,isDraft,isPrerelease,assets,url
shasum -a 256 -c build.noindex/release/alhangeul-macos-<version>.dmg.sha256
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/Alhangeul.app
xcrun stapler validate build.noindex/release/alhangeul-macos-<version>.dmg
spctl --assess --type execute --verbose build.noindex/release/Alhangeul.app
spctl --assess --type open --context context:primary-signature --verbose build.noindex/release/alhangeul-macos-<version>.dmg
```

GitHub-hosted workflow에서만 산출물이 있는 경우에는 workflow artifact와 step summary를 기준으로 확인하고, 가능한 항목은 release machine에서 다시 내려받아 검증한다.

record에 남길 값:

- GitHub Release URL
- workflow run URL
- tag와 commit
- public DMG filename
- public DMG URL
- public DMG SHA256
- DMG size
- app/extension universal slice 확인 결과
- signing/notarization/staple/Gatekeeper 결과
- 실행하지 않은 수동 확인 항목과 사유

## Gate 7. Pages와 Sparkle 확인

official stable release일 때만 수행한다.

확인 항목:

- `Release Publish DMG` workflow의 `deploy-pages` job 성공
- `page_url`이 `https://postmelee.github.io/alhangeul-macos/`를 가리킴
- `https://postmelee.github.io/alhangeul-macos/updates/v<version>.html` 접근 가능
- 최신 버전보다 낮은 `updates/v<previous>.html` 페이지에 최신 릴리즈 안내 banner가 보이고, banner가 `updates/v<version>.html`과 GitHub latest release로 연결됨
- Pages 다운로드 버튼이 tag 고정 또는 latest 정책에 맞는 public DMG URL을 가리킴
- `https://postmelee.github.io/alhangeul-macos/appcast.xml`이 새 stable item을 제공
- appcast의 `sparkle:shortVersionString`이 `<version>`과 일치
- appcast의 `sparkle:version`이 `<build>`와 일치
- appcast enclosure URL이 tag 고정 universal DMG URL을 가리킴
- EdDSA signature가 존재

docs-only Pages workflow는 Sparkle appcast를 새로 만들지 않는다. release 직후 docs-only Pages 배포가 필요하면 public appcast 보존 기준을 확인한다.

## Gate 8. 설치본과 Finder smoke

실제 설치본 기준 smoke는 release record에 실행 여부를 명확히 남긴다.

기본 확인:

```bash
scripts/smoke-finder-integration.sh --version <version>
scripts/smoke-sparkle-extension-refresh.sh \
  --expected-version <version> \
  --expected-build <build>
```

수동 확인 후보:

- DMG mount layout
- `/Applications` 복사 후 첫 실행
- 앱 About 또는 provenance 표시
- `.hwp` Quick Look preview
- `.hwpx` Quick Look preview
- Finder icon view thumbnail
- 문서 열기와 기본 viewer 동작
- Sparkle `업데이트 확인...`
- Intel Mac 실기기 smoke

주의:

- `qlmanage -t -x` headless 확인은 GUI preview 확인을 대체하지 않는다.
- Intel Mac 실기기 smoke를 실행하지 않았으면 성공으로 쓰지 않는다.
- 이전 설치본이나 PlugInKit 캐시로 false positive가 의심되면 [`release_packaging_dmg_guide.md`](release_packaging_dmg_guide.md)의 registration hygiene 옵션을 따른다.

## Gate 9. Homebrew Cask

Homebrew는 public DMG asset과 SHA256이 확정된 뒤 별도 승인으로 진행한다.

사전 조건:

- GitHub Release의 public DMG URL이 확정되어 있다.
- public DMG SHA256이 확정되어 있다.
- GitHub Release, Pages, Sparkle이 같은 universal DMG를 가리킨다.
- release owner가 Homebrew tap 반영을 별도로 승인했다.

repository Cask source 갱신:

```bash
./scripts/update-cask-sha256.sh <version>
```

tap 반영 후 검증:

```bash
brew tap postmelee/tap
brew style --cask alhangeul
brew audit --cask alhangeul
brew audit --cask --new alhangeul
brew install --cask postmelee/tap/alhangeul
brew uninstall --cask alhangeul
```

주의:

- `*-rehearsal.dmg.sha256`은 Cask에 사용하지 않는다.
- `sha256 :no_check`를 public 배포 완료로 간주하지 않는다.
- `brew audit --cask --new`는 upstream Homebrew 제출 수준 참고 검증이며, maintainer tap 공개 gate와 구분한다.
- Homebrew 안내 문구는 tap context 검증이 끝난 뒤 README, Pages, GitHub Release/릴리즈 노트에 일관되게 반영한다.

## Gate 10. Release record와 최종 보고

릴리즈 완료 후 다음 파일을 갱신하거나 확인한다.

- `mydocs/release/v<version>.md`
- 최종 release report
- 오늘할일 문서
- 필요 시 README 최신 공개 릴리즈 요약
- 필요 시 Pages release note
- 필요 시 Homebrew 안내 문구

release record 필수 항목:

- release identity: version, build, tag, commit
- `rhwp` core tag/commit
- bundled `rhwp-studio` tag/commit
- public DMG URL/SHA256/size
- GitHub Release URL
- workflow run URL
- Pages release note URL
- Sparkle appcast 확인 결과
- Homebrew 반영 여부와 검증 결과 또는 미진행 사유
- signing/notarization/Gatekeeper 결과
- Finder Quick Look/Thumbnail smoke 결과
- Sparkle update smoke 결과
- Intel Mac 실기기 smoke 결과 또는 미실행 사유
- 알려진 한계와 후속 이슈

### 릴리즈 종료 정리 PR 원칙

public publish 이후 release note 문구, Pages 문구, GitHub Release 본문, release record, 최종 보고서를 보정해야 하면 `릴리즈 종료 정리` 단계로 묶는다.

- 같은 릴리즈의 문구 정정, 사용자-facing 표현 보정, 기술 세부 section 추가, 이전 버전 안내 banner 정규화, release record/final report 갱신은 별도 PR로 쪼개지 않고 하나의 종료 정리 PR에 모은다.
- publish 전 candidate를 바꾸는 수정은 release 기준 통합 브랜치에서 처리하고, publish 후 public surface 정정은 public Pages와 release record를 갱신할 수 있는 `main` 대상 종료 정리 PR 하나로 처리한다.
- GitHub Release 본문처럼 GitHub API로 직접 바꾸는 public 상태 변경은 같은 종료 정리 단계의 release record와 최종 보고서에 실제 변경 내용을 남긴다.
- 급한 차단 오류로 public 안내를 먼저 고쳐야 하는 경우에도 후속 문서/record 정리는 같은 종료 정리 PR에 합쳐 최종 상태를 한 번에 기록한다.
- 종료 정리 PR 본문에는 이번 릴리즈에서 실제로 생성된 PR 목록을 묶어 기록하고, PR 수가 늘어난 원인이 있으면 다음 릴리즈 운영 규칙으로 환류한다.

## Rollback

문제가 확인되면 먼저 배포 표면을 줄이고, 그 다음 원인을 기록한다.

1. GitHub Release asset 또는 release 상태를 확인하고 필요한 경우 숨기거나 삭제한다.
2. stable appcast가 문제 release를 가리키면 Pages/appcast 복구 또는 새 patch release 경로를 결정한다.
3. Homebrew Cask가 공개된 경우 해당 version 설치 경로를 중단하거나 새 patch release로 교체한다.
4. 사용자 영향이 있으면 GitHub Issue를 등록한다.
5. 원인, 영향 범위, 재현 조건, 복구 절차를 `mydocs/troubleshootings/`에 기록한다.
6. 수정 PR을 release 기준 통합 브랜치로 merge한 뒤 새 release candidate를 만든다.

rollback 중에도 secret 값은 기록하지 않는다. 실패한 command, 대상 파일, 공개 URL, 오류 요약, workflow run URL만 기록한다.
