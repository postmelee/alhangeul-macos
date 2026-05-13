# Task M019 #225 최종 보고서

## 작업 요약

- 이슈: #225 rhwp 최신버전 반영 및 v0.1.2 배포 준비
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task225`, `publish/task225`, `publish/task225-main`
- 기준 브랜치: `devel-webview`, `main`
- 최종 release candidate: `0.1.2 (8)`
- 목표 tag: `v0.1.2`
- 목적: `rhwp v0.7.11` core/studio를 반영하고, Finder Quick Look/Thumbnail update maintenance, About provenance, current/Hancom UTI 정책, release 문서와 workflow helper를 v0.1.2 public release 후보 기준으로 정리한다.

## 결과

`v0.1.2` build `8` release candidate를 만들고 local/rehearsal 검증을 완료했다. #235의 Web viewer runtime 오류 banner UX가 `devel-webview`에 먼저 merge되었으므로, 해당 변경을 #225 후보에 통합한 뒤 build `8`로 respin했다.

이후 PR #237로 `devel-webview`에 반영하고, PR #238로 `main`에 반영했다. `main` merge commit `2c199b24c784c2044dae8473538515c59bd91939`에 tag `v0.1.2`를 생성한 뒤 `Release Publish DMG` workflow run `25774125473`에서 Developer ID signing, notarization, GitHub Release 게시, stable Sparkle appcast, Pages 배포를 완료했다.

## 주요 변경 파일

| 파일 | 내용 |
|------|------|
| `rhwp-core.lock` | `rhwp v0.7.11` release tag와 resolved commit `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` 반영 |
| `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock` | Rust core dependency를 `v0.7.11` 기준으로 갱신 |
| `Frameworks/generated_rhwp.h`, `rhwp-ffi-symbols.txt` | Rust bridge generated header와 FFI symbol metadata 갱신 |
| `Sources/HostApp/Resources/rhwp-studio/**` | bundled `rhwp-studio` asset을 `v0.7.11` 기준으로 갱신 |
| `Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md` | bundled dependency notice 갱신 |
| `Sources/HostApp/Support/BuildInfo.swift`, `Sources/HostApp/Support/RhwpProvenance.swift`, `Sources/HostApp/Views/AboutView.swift` | About 창의 bundled `rhwp` provenance 표시 추가 |
| `Sources/HostApp/Services/LaunchMaintenanceService.swift`, `ExtensionSystemRegistrationRefresher.swift`, `RecentDocumentThumbnailRefresher.swift`, `RecentDocumentStore.swift` | build marker 기반 launch maintenance와 recent document thumbnail refresh 추가 |
| `Sources/HostApp/Info.plist`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist` | 앱/extension version을 `0.1.2 (8)`로 갱신하고 UTI policy를 current `com.postmelee.alhangeul.*` + Hancom 계열로 고정 |
| `.github/workflows/release-rehearsal.yml`, `.github/workflows/release-publish.yml`, `.github/workflows/pr-ci.yml` | v0.1.2 workflow defaults와 release helper dry-run 기준 갱신 |
| `README.md`, `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.2.html` | v0.1.2 사용자-facing release 안내 추가 |
| `mydocs/release/v0.1.2.md` | release decision record와 Stage 5-8 검증 결과 기록 |
| `mydocs/working/task_m019_225_stage*.md` | 단계별 완료 보고 |

## 구현 요약

### `rhwp v0.7.11` 반영

`edwardkim/rhwp` release tag `v0.7.11`의 resolved commit은 `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`다. Rust bridge lock, generated header, FFI symbols, bundled studio asset manifest를 이 기준으로 맞췄다.

About 창에는 앱 버전/build와 별개로 bundled `rhwp v0.7.11 (a9dcdee)` provenance가 표시된다.

### launch maintenance

기존 매 실행 registration refresh는 build marker 기반 maintenance로 바꿨다. 현재 앱의 `CFBundleShortVersionString`/`CFBundleVersion` 조합이 마지막 maintenance marker와 다를 때만 다음 작업을 1회 실행한다.

- 현재 app bundle 기준 LaunchServices/extension registration refresh
- 최근 HWP/HWPX 문서 후보의 targeted thumbnail refresh 요청

전역 `qlmanage -r cache`나 Finder 강제 재실행은 앱 자동 경로에 넣지 않았다. 실패는 로그로 남기고 앱 launch는 계속된다.

### UTI policy

첫 public marketing release 전 기존 사용자가 없다는 전제에 따라 legacy `com.postmelee.rhwpmac.*`와 `com.postmelee.alhangeulmac.*` 지원을 제거했다. 제품 source의 앱 소유 UTI는 `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx`로 고정하고, Hancom 계열 UTI는 계속 지원한다.

지원 UTI:

```text
com.postmelee.alhangeul.hwp
com.postmelee.alhangeul.hwpx
com.hancom.hwp
com.hancom.hwpx
com.haansoft.hancomofficeviewer.mac.hwp
com.haansoft.hancomofficeviewer.mac.hwpx
```

### #235 통합

#235는 문서가 열린 뒤 발생하는 Web viewer runtime 오류를 fatal 화면 대신 non-blocking banner로 표시한다. #235 PR #236이 `devel-webview`에 merge된 뒤 `local/task225`에 통합했고, 이 변경을 포함한 최종 release candidate를 build `8`로 식별했다.

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `88f4b57` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `e9706d8` | 구현 계획서 작성 |
| Stage 1 | `856797f` | v0.1.2 업데이트 범위와 release gate 확정 |
| Stage 2 | `915ac18` | rhwp v0.7.11 core와 studio asset 갱신 |
| Stage 3 | `54a2387` | About provenance와 update maintenance 추가 |
| Stage 4 | `1efd68d` | v0.1.2 release metadata 정리 |
| Stage 5 | `28c0738` | v0.1.2 release candidate 검증 |
| Stage 6 | `a1a044e` | legacy UTI thumbnail routing 보강 |
| Stage 7 | `76ba22c` | v0.1.2 build 7 UTI 정책 respin |
| #235 통합 | `7dc1640` | `devel-webview`의 #235 merge commit 통합 |
| Stage 8 | `385e85b` | #235 통합 build 8 release candidate 검증 |

## 검증

자동/로컬 검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
./scripts/release.sh --skip-notarize 0.1.2
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
scripts/ci/write-sparkle-appcast.sh --version 0.1.2 --build 8 ...
xmllint --noout build.noindex/release/appcast.xml
scripts/ci/write-release-notes.sh 0.1.2 e0c25bd72f64bc4fabbde97c62e92e4f391aad133b0ee9f41dd9a542fa45771b build.noindex/release/release-notes-0.1.2.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast build.noindex/release/appcast.xml --output-dir build.noindex/release/pages-artifact
```

Stage 8 release rehearsal:

```text
e0c25bd72f64bc4fabbde97c62e92e4f391aad133b0ee9f41dd9a542fa45771b  alhangeul-macos-0.1.2-rehearsal.dmg
```

Finder/Quick Look smoke:

```bash
./scripts/smoke-clean-quicklook-install.sh --skip-package --app build.noindex/release/Alhangeul.app --install-app /Users/melee/Applications/Alhangeul.app --sample samples/basic/KTX.hwp --sample samples/hwpx/hwpx-01.hwpx
qlmanage -t -x -s 768 -c com.hancom.hwp ...
qlmanage -t -x -s 768 -c com.haansoft.hancomofficeviewer.mac.hwp ...
qlmanage -t -x -s 768 -c com.hancom.hwpx ...
qlmanage -t -x -s 768 -c com.haansoft.hancomofficeviewer.mac.hwpx ...
./scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.2 --expected-build 8 --app /Users/melee/Applications/Alhangeul.app
/private/tmp/alhangeul-visual-smoke/20260513-102822/check-crashes.command
```

결과:

- Release app, Preview appex, Thumbnail appex 실행 파일 모두 `x86_64 arm64`.
- app/Preview/Thumbnail 모두 `0.1.2 (8)`.
- current `com.postmelee.alhangeul.*` UTI smoke와 Hancom 4종 forced routing thumbnail 생성 성공.
- Sparkle refresh helper 통과, registration repair 미사용.
- smoke 후 `/Users/melee/Applications/Alhangeul.app`를 `/private/tmp/alhangeul-build8-smoke-installed-20260513-103012/Alhangeul.app`로 이동.
- cleanup 후 PlugInKit Preview/Thumbnail no matches, LaunchServices의 임시 Alhangeul/Debug/release staging 경로 미검출.

## 수용 기준별 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `rhwp v0.7.11` core/studio 반영 | OK | lock, Cargo, bundled manifest, asset 검증 |
| About provenance 표시 | OK | Stage 5 GUI About smoke |
| build marker 기반 launch maintenance | OK | Stage 3 구현, Stage 5/8 Sparkle refresh helper |
| recent HWP/HWPX thumbnail refresh | OK | Stage 3 구현, helper smoke |
| app/extension `0.1.2 (8)` metadata | OK | Debug/release plist 확인 |
| legacy UTI 제거와 current/Hancom UTI 지원 | OK | plist search, clean smoke, Hancom forced routing |
| #235 runtime banner 포함 | OK | #236 merge commit 통합, build 8 respin |
| release rehearsal DMG 생성 | OK | `--skip-notarize` DMG와 SHA256 기록 |
| public release 게시 | OK | PR #238 main merge, tag `v0.1.2`, Release Publish DMG run `25774125473` 성공 |

## 미수행 범위

- actual Sparkle update from public v0.1.1
- Intel Mac 실기기 smoke
- Homebrew Cask public SHA256 반영

## release handoff

다음 release 실행 순서를 완료했다.

1. `publish/task225` PR을 `devel-webview`에 merge한다.
2. `devel-webview`의 release candidate commit을 `main`으로 반영하는 release PR을 merge한다.
3. `main`의 최종 release commit에 `v0.1.2` tag를 생성한다.
4. `Release Publish DMG` workflow를 tag `v0.1.2`에서 `draft=false`, `prerelease=false`로 실행한다.
5. signed/notarized public DMG SHA256, GitHub Release latest 상태, stable appcast EdDSA signature, Pages deployment URL을 `mydocs/release/v0.1.2.md`에 보강한다.

public 결과:

```text
GitHub Release: https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.2
Public DMG: alhangeul-macos-0.1.2.dmg
SHA256: 37a27321f03a84b8b28749b5f839ea5c5833975d20f2479e3b79ebd665811ead
Sparkle appcast: https://postmelee.github.io/alhangeul-macos/appcast.xml
Pages release note: https://postmelee.github.io/alhangeul-macos/updates/v0.1.2.html
```

## PR close 전략

PR #237은 `devel-webview`에 merge했고, PR #238은 `main`에 merge했다. 실제 public release 실행 상태까지 확인했으므로 #225는 post-release 기록 commit 후 close한다.

## 잔여 위험

- Finder/Quick Look cache는 macOS 내부 정책이므로 targeted refresh가 모든 과거 파일 thumbnail을 강제로 갱신하지는 않는다.
- Intel Mac 실기기 smoke는 아직 수행하지 못했다.
- #235가 완화한 Web viewer 오류의 root cause는 upstream `edwardkim/rhwp` #850에 남아 있다.
- Homebrew Cask public SHA256 반영은 #209 또는 별도 승인 범위에서 진행해야 한다.
