# 릴리스 정책 가이드

## 목적

이 문서는 `alhangeul-macos` public release의 운영 기준, 산출물 계층, 사용자 안내 문구, provenance 공개 기준을 정리한다. 실제 배포 실행 절차는 [`release_distribution_guide.md`](release_distribution_guide.md)에서 필요한 하위 매뉴얼을 따라 진행한다.

## 권한 원칙

- public release 실행, GitHub Release 게시, Sparkle appcast 갱신, Homebrew Cask 반영은 작업지시자의 명시 승인 후 수행한다.
- 버전별 실제 결정, SHA256, 검증 기록은 [`mydocs/release/`](../release/)의 릴리즈별 문서에 남긴다.
- 비밀이 아닌 환경 식별자는 [`release_environment.md`](../tech/release_environment.md)에 기록하고, private key/password/token은 어떤 문서에도 기록하지 않는다.

## 확정된 운영 기준

다음 항목은 현재 release script, Cask, plist에 반영된 기준이다.

- GitHub 저장소: `postmelee/alhangeul-macos`
- 산출물 파일명/Homebrew Cask token: `alhangeul-macos`
- 앱 filesystem bundle name: `Alhangeul.app` (Quick Look/Thumbnail ExtensionKit lookup 안정성을 위해 ASCII 유지)
- 내부 Xcode product name: `Alhangeul`
- bundle identifier: `com.postmelee.alhangeul` 계열
- 사용자 표시명: 한국어 `알한글` (`ko.lproj/InfoPlist.strings`), 영어 `Alhangeul` (`en.lproj/InfoPlist.strings`)
- 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`은 ASCII filesystem name과 동일
- 공개 배포 산출물명: `alhangeul-macos-<version>.dmg`

## 릴리즈 식별자와 bundled rhwp 표기 정책

공식 앱 release identity는 `Alhangeul v<app-version>` 하나로 유지한다. Bundled `rhwp` core와 `rhwp-studio` 버전은 앱 버전과 결합한 새 semver가 아니라 release metadata/provenance로 분리해 표시한다.

앱 버전만 사용하는 항목:

| 표면 | 기준 |
|------|------|
| Git tag | `v<app-version>` |
| `CFBundleShortVersionString` / `CFBundleVersion` | 앱 버전과 앱 build number |
| DMG filename | `alhangeul-macos-<app-version>.dmg` |
| Sparkle appcast version/build | 앱 버전과 앱 build number |
| Homebrew Cask version | 앱 버전 |
| GitHub Release title 기본형 | `Alhangeul v<app-version>` |

GitHub Release title은 기본적으로 `Alhangeul v<app-version>`을 사용한다. Upstream `rhwp` core 또는 bundled `rhwp-studio` 반영이 해당 release의 중심 사용자-facing 변화이고, release note에서 영향과 검증 결과를 명확히 설명할 수 있을 때만 `Alhangeul v<app-version> (rhwp v<rhwp-version>)` 병기를 허용한다.

다음 경우에는 title에 `rhwp` 버전을 병기하지 않는다.

- 앱 자체 버그 수정, DMG UX, CI, 문서, Sparkle/Homebrew 변경이 중심인 release
- bundled `rhwp` 버전이 직전 공개 release와 같은 release
- bundled `rhwp` 변경이 사용자-facing 중심 변화가 아닌 release

GitHub Release body와 내부 release record에는 다음 metadata를 표준으로 노출한다.

```md
## Release metadata

| 항목 | 값 |
|------|----|
| App version | `v<app-version>` |
| rhwp core release tag | `v<rhwp-version>` |
| rhwp core commit | `<commit>` |
| bundled rhwp-studio release tag | `v<rhwp-version>` |
| bundled rhwp-studio commit | `<commit>` |
| core lock | `rhwp-core.lock` |
| studio manifest | `Sources/HostApp/Resources/rhwp-studio/manifest.json` |
```

README 최신 공개 릴리즈 요약과 Pages 릴리즈 노트는 사용자용 안내 표면이다. 필요할 때 `bundled rhwp-studio v<rhwp-version>` 또는 `rhwp v<rhwp-version>` 정도의 짧은 provenance와 upstream release 링크만 표시하고, commit/manifest/checksum 등 긴 내부 기록은 GitHub Release body와 `mydocs/release/v<version>.md`에 둔다.

자동 upstream sync PR 또는 release handoff는 위 기준을 따라 다음 값을 최소 기록한다.

- app version 후보
- `rhwp` core release tag와 commit
- bundled `rhwp-studio` release tag와 commit
- release title에 `(rhwp vX.Y.Z)` 병기가 필요한지에 대한 판단
- `rhwp-core.lock`과 studio manifest 검증 결과

## 배포 브랜치 기준

현재 WebView-backed public release line은 `devel`을 배포 준비 기준 브랜치로 사용한다. 릴리스 후보가 확정되면 `devel`의 검증된 commit을 `main`에 반영하고, Git tag와 GitHub Release는 `main` 기준으로 생성한다.

`native-viewer-editor`는 HostApp native macOS shell, Rust/rhwp Skia renderer 연동, Swift 편집 UI/오버레이 장기 개발 통합 브랜치이므로 배포 직전 기준 브랜치로 사용하지 않는다. `devel`에 merge된 release-critical 변경 중 native 라인에도 필요한 수정은 별도 PR 또는 cherry-pick으로 `native-viewer-editor`에 후속 동기화한다. 퇴역한 `devel-webview`는 배포 기준이나 자동화 기준으로 사용하지 않는다.

브랜치 역할과 native 라인 보존 기준은 [`branch_strategy_webview_native.md`](../tech/branch_strategy_webview_native.md)를 기준으로 판단한다.

## Public 배포 수준

Public release의 기본 배포 수준은 **Developer ID signed + notarized DMG**로 둔다. unsigned 또는 ad-hoc signed artifact를 일반 사용자 배포 기준으로 삼지 않는다.

| 배포 수준 | 운영 판단 | 사용자 영향 | 사용 범위 |
|-----------|-----------|-------------|-----------|
| unsigned app/DMG | public 배포 기준 아님 | Gatekeeper 차단과 수동 우회 안내가 필요하고 신뢰도가 낮다 | 로컬 빌드 실패 분석 등 제한적 개발 확인 |
| ad-hoc signed app/DMG | public 배포 기준 아님 | notarization이 없고 외부 사용자 설치 신뢰 기준을 충족하지 못한다 | CI/로컬 bundle 구조 확인 |
| Developer ID signed, not notarized | public 배포 기준 아님 | 최신 macOS Gatekeeper에서 quarantine 경로 실행이 막힐 수 있다 | notarization 실패 원인 분리 시 임시 확인 |
| Developer ID signed + notarized DMG | public 기본값 | 다운로드 후 일반적인 Gatekeeper 흐름에서 실행 가능해야 한다 | GitHub Release asset, Homebrew Cask 기준 산출물 |
| Mac App Store | 현재 public DMG lane 밖 | App Store signing/export, review, metadata, privacy 준비가 별도로 필요하다 | 후속 배포 lane |

운영 기준:

- public 사용자가 받는 artifact는 `scripts/release.sh <version>` public mode로 생성한 `alhangeul-macos-<version>.dmg`여야 한다.
- `v0.1.1`부터 public DMG는 앱 본체와 Quick Look/Thumbnail extension 실행 파일이 `arm64 + x86_64` slice를 포함하는 단일 universal DMG여야 한다.
- Intel Mac과 Apple Silicon Mac용 DMG를 따로 나누지 않는다. Pages, Sparkle appcast, Homebrew Cask는 같은 public DMG URL을 기준으로 안내한다.
- `--skip-notarize` rehearsal DMG, 개발용 zip, unsigned/ad-hoc 산출물은 GitHub Release public asset 또는 Homebrew Cask URL에 사용하지 않는다.
- public DMG의 `.sha256` 파일을 GitHub Release와 release note에 함께 공개하고, Homebrew Cask `sha256`은 이 digest로 고정한다.

## 사용자 설치 안내 기준

public release note, README, Homebrew caveats에는 다음 기준을 일관되게 적용한다.

- 설치 파일: `alhangeul-macos-<version>.dmg`
- 지원 아키텍처: `arm64 + x86_64` universal app/extension bundle. Intel Mac과 Apple Silicon Mac 모두 같은 DMG를 사용
- 설치 방식: DMG를 열고 `Alhangeul.app`을 `/Applications`로 복사
- DMG 설치 창: root에는 `Alhangeul.app`과 `Applications` symlink만 노출하고, background 안내로 `알한글.app`을 Applications로 드래그해 설치하는 흐름을 보여준다
- 첫 실행: `설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail이 활성화됩니다.` 기준 문구로 안내한다
- Finder 확인: `.hwp` 또는 `.hwpx` 파일을 Finder에서 선택한 뒤 Space로 Quick Look preview를 확인하고, Finder icon view에서 thumbnail 갱신을 확인
- Gatekeeper: notarized DMG 기준으로 일반 실행이 가능해야 하며, 사용자가 임의로 quarantine을 해제하는 안내를 기본 설치 경로로 쓰지 않는다
- checksum: GitHub Release의 `.sha256` 값과 다운로드한 DMG의 SHA256을 비교할 수 있게 안내
- Homebrew: Cask는 GitHub Release에 notarized public DMG가 업로드되고 sha256이 고정된 뒤에만 설치 안내에 포함

Gatekeeper나 quarantine 문제가 보고되면 먼저 다음을 확인한다.

- 사용자가 rehearsal DMG 또는 개발용 zip을 받은 것은 아닌가
- DMG가 GitHub Release의 public asset과 같은 파일명, 같은 sha256인가
- `xcrun stapler validate`와 `spctl` 검증이 release machine에서 통과했는가
- 앱을 `/Applications`에 복사한 뒤 한 번 실행했는가

## Release artifact 구성 기준

Release artifact는 사용 목적을 기준으로 세 계층으로 분리한다.

| 계층 | 기준 산출물 | 목적 | public 사용 |
|------|-------------|------|-------------|
| 개발/설치본 smoke | `build.noindex/release/Alhangeul.app`, `alhangeul-macos-<version>.zip` | Release configuration bundle 구성과 Finder/Quick Look/Thumbnail 설치본 smoke 입력 | 아니오 |
| public release rehearsal | `alhangeul-macos-<version>-rehearsal.dmg`, `.sha256` | DMG layout, checksum 생성, release script path 확인 | 아니오 |
| public release | `alhangeul-macos-<version>.dmg`, `.sha256` | GitHub Release asset, 사용자 배포, Homebrew Cask digest 기준 | 예 |

public release 계층의 DMG는 단일 universal DMG다. 아키텍처별 asset을 추가하지 않는 한 GitHub Release, Pages latest 다운로드, Sparkle enclosure, Homebrew Cask `url`은 같은 DMG 파일명과 SHA256을 기준으로 맞춘다.

checksum 공개 기준:

| checksum | 공개 범위 | 기준 |
|----------|-----------|------|
| zip stdout checksum | 단계 보고서, 설치본 smoke report | 개발/검증용 식별자. GitHub Release asset이나 Cask digest로 쓰지 않는다. |
| rehearsal DMG `.sha256` | rehearsal workflow artifact와 단계 보고서 | public release checksum으로 쓰지 않는다. |
| public DMG `.sha256` | GitHub Release asset, release note, Homebrew Cask 교체 입력 | 사용자 배포 기준 checksum이다. |

provenance 진실 원천:

| 대상 | 진실 원천 | 공개/검증 방식 |
|------|-----------|---------------|
| `rhwp` core release tag/commit | `rhwp-core.lock` | release note에 tag/commit을 직접 표시하고 lock 파일을 검증 기준으로 둔다. |
| Rust bridge staticlib reference metadata | `rhwp-core.lock` | `Frameworks/universal/librhwp.a` hash/size를 기준 환경 reference로 기록한다. GitHub-hosted CI/release에서는 byte hash/size 비교만 skip할 수 있다. |
| Rust bridge generated header hash/size | `rhwp-core.lock` | release 전 `./scripts/build-rust-macos.sh --verify-lock`으로 검증한다. |
| FFI ABI surface | `rhwp-ffi-symbols.txt` | 최종 보고서와 PR에서 변경 여부를 기록한다. |
| bundled `rhwp-studio` asset | `Sources/HostApp/Resources/rhwp-studio/manifest.json` | release note에 manifest 위치와 tag/commit을 표시하고 `scripts/verify-rhwp-studio-assets.sh`로 검증한다. |
| Third Party notices | `THIRD_PARTY_LICENSES.md`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`, `Sources/HostApp/Resources/Legal/*` | release note에서 canonical 문서 위치를 안내하고, public DMG 안의 app bundle `Contents/Resources/Legal/*` 사본 포함 여부와 내용 동일성을 검증한다. |

`ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`은 GitHub-hosted CI/release workflow에서 `Frameworks/universal/librhwp.a` byte hash/size 비교만 제외하는 정책 env다. 이 env를 사용해도 `rhwp` repo/ref/tag/commit, `RustBridge/Cargo.lock`, generated header, FFI symbol 검증은 유지한다. strict staticlib byte hash를 public release gate로 복귀하려면 Rust toolchain, Xcode, macOS runner image, archive tool, build path 또는 CI 기준 lock 생성 환경을 먼저 고정한다.

`LICENSE`, `THIRD_PARTY_LICENSES.md`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`를 수정하면 `Sources/HostApp/Resources/Legal/*` 사본을 같은 변경 범위에서 갱신한다. Public release 전에는 signed/notarized DMG를 mount한 뒤 app bundle의 `Contents/Resources/Legal/{LICENSE,THIRD_PARTY_LICENSES.md,FONTS.md}`와 release candidate commit의 canonical 문서가 같은지 확인한다.

## 렌더링 경로와 알려진 한계 공개 기준

public release note에는 artifact/provenance/checksum뿐 아니라 현재 release line의 렌더링 경로와 알려진 한계를 함께 기록한다.

포함 기준:

- HostApp viewer/editor 화면은 bundled `rhwp-studio`를 WKWebView에서 실행한다.
- PDF 내보내기, Quick Look preview, Finder thumbnail은 Rust bridge와 Swift native render tree 계열 경로를 사용하므로 앱 화면과 표시가 다를 수 있다.
- 인쇄는 `rhwp-studio` page payload를 별도 WKWebView/PDFKit/AppKit 출력 경로로 처리한다.
- Quick Look/Thumbnail 설치본 smoke는 extension 등록과 HWP/HWPX thumbnail 생성 확인이며, preview 수동 확인과 native renderer visual parity를 대체하지 않는다.
- 손상·대용량·미지원 문서 fallback은 파일 복구가 아니라 앱과 extension이 raw error, hang, crash로 끝나지 않게 하는 안전장치다.
- CoreGraphics/CoreText renderer의 style, image effect/fill, text layout, RawSvg/OLE 등 parity 개선은 현행 Quick Look/Thumbnail/PDF fallback/diagnostic 경로에서 계속 다루고, HostApp 장기 경로는 Rust/rhwp Skia renderer와 Swift overlay 결합 방향으로 분리한다.

release note와 release report에서 smoke 결과를 쓸 때는 실제 실행한 항목만 성공으로 기록한다. 실행하지 않은 `qlmanage -p`, Finder Space preview, public DMG Gatekeeper 검증은 수동 확인 또는 후속 확인으로 분리한다.

## 버전 갱신

릴리스 버전은 태그와 앱 plist 버전을 함께 맞춘다.

확인 대상:

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `Casks/alhangeul-macos.rb`
- Git tag: `v<version>`
- GitHub Release 제목과 파일명

현재 버전 필드:

- `CFBundleShortVersionString`
- `CFBundleVersion`

버전 갱신 방식은 별도 자동화가 생기기 전까지 수동으로 검토한다.
