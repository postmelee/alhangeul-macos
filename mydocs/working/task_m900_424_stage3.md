# Task M900 #424 Stage 3 완료보고서

## 단계 목적

`v0.1.8 (14)` release candidate가 `rhwp v0.7.18` source provenance, Debug/Release build, native renderer와 release helper 기준을 통과하는지 확인하고, 별도 승인된 unsigned rehearsal DMG의 checksum과 Finder layout을 검증한다.

## 검증 기준점

| 항목 | 값 |
|------|----|
| candidate branch | `local/task424` |
| candidate commit | `2872cd1492cb2a72101f9e9a9bedfd620748d4eb` |
| previous release ref | `v0.1.7` |
| app / extension | `0.1.8 (14)` |
| rhwp core / studio | `v0.7.18` / `93862a4e16df59834ebce46d91e948cd739208e9` |
| rehearsal mode | local `./scripts/release.sh --skip-notarize 0.1.8` |

Stage 3 시작 전과 종료 시 tracked worktree는 clean이었다. 검증 산출물은 `build.noindex/`와 `output/` 아래에만 생성했으며 commit하지 않는다.

## Source preflight

### Core와 bundled studio

다음 검증이 통과했다.

```text
./scripts/build-rust-macos.sh --verify-lock
scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
```

- arm64와 x86_64 Rust static library를 다시 빌드했다.
- universal `librhwp.a`, generated header, FFI symbol set, source/header/ABI/hash와 `rhwp-core.lock`의 strict 일치를 확인했다.
- bundled `rhwp-studio` manifest와 entrypoint asset이 `v0.7.18` / `93862a4e...` 기준과 일치했다.
- shared Swift code에 AppKit/UIKit 직접 의존이 없었다.

### Xcode와 native renderer

`xcodegen generate` 후 tracked project diff가 없었고, 다음 unsigned Debug build가 성공했다.

```text
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task424 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

native renderer smoke 결과:

| 샘플 | 결과 |
|------|------|
| `samples/basic/KTX.hwp` | page 1, text run 410, non-white pixel 455,341 |
| `samples/basic/request.hwp` | page 1, text run 102, non-white pixel 70,188 |
| `samples/basic/exam_kor.hwp` | page 1, text run 133, non-white pixel 173,981 |
| `samples/hwpx/hwpx-01.hwpx` | page 1, text run 269, non-white pixel 134,090 |

HWP 3종과 HWPX 1종 모두 한글 scalar와 non-white pixel 기준을 통과했다.

### Release package

`./scripts/package-release.sh 0.1.8`이 Release configuration 앱과 개발 검증용 zip을 생성했다.

| 항목 | 결과 |
|------|------|
| HostApp version | `0.1.8 (14)` |
| Quick Look version | `0.1.8 (14)` |
| Thumbnail version | `0.1.8 (14)` |
| HostApp architecture | `arm64 + x86_64` |
| Quick Look architecture | `arm64 + x86_64` |
| Thumbnail architecture | `arm64 + x86_64` |
| Legal | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` canonical 일치 |
| local sealed app | `codesign --verify --deep --strict` 통과 |
| 개발용 zip | 153MB, SHA256 `89787a05c35c961fa06d9b0f72b8d5211b10e7a76a3d7a259892df9165c89f49` |

이 zip과 local ad-hoc seal은 개발 검증용이며 public release signing/notarization 근거가 아니다.

### Release helper

Stage 2 commit을 포함한 `HEAD`에서 helper를 다시 생성하고 검증했다.

- PR analysis: `v0.1.7..HEAD`, first-parent merge PR 14개
- delta checklist: previous `v0.1.7`, candidate `2872cd1492cb2a72101f9e9a9bedfd620748d4eb`
- release note template과 GitHub body validator 통과
- Pages release version notice check 통과
- `git diff --check` 통과

최종 Task #424 commit과 `devel -> main` candidate는 Stage 4에서 다시 생성해야 한다.

## Rehearsal DMG

source preflight 결과 보고 후 별도 승인을 받아 다음 명령을 실행했다.

```text
./scripts/release.sh --skip-notarize 0.1.8
hdiutil verify build.noindex/release/alhangeul-macos-0.1.8-rehearsal.dmg
```

산출물:

| 항목 | 값 |
|------|----|
| DMG | `build.noindex/release/alhangeul-macos-0.1.8-rehearsal.dmg` |
| 크기 | 159,624,609 bytes |
| SHA256 | `2dbdf0bfbd20e2a1924450b53b6815a2434b8c515c373f1d126d1fc8cbdeaba9` |
| checksum file | `alhangeul-macos-0.1.8-rehearsal.dmg.sha256` |
| `shasum -a 256 -c` | 통과 |
| `hdiutil verify` | script 내부와 독립 재검증 모두 `VALID` |

### Mounted volume 검증

DMG를 읽기 전용 임시 mount한 뒤 다음을 확인하고 즉시 detach했다.

| 항목 | 결과 |
|------|------|
| visible root | `Alhangeul.app`, `Applications` 2개 |
| Applications link | `/Applications` |
| 별도 설치 안내 파일 | 없음 |
| background | `.background/alhangeul-dmg-background.png`, `720x460` |
| Finder view | icon view |
| toolbar / statusbar | 둘 다 hidden |
| window bounds | `120, 120, 840, 680` |
| icon size | `96` |
| app position | `178, 268` |
| Applications position | `542, 268` |
| mounted app / extension | 모두 `0.1.8 (14)`, `arm64 + x86_64` |
| mounted Legal | canonical 3종 일치 |

첫 AppleScript는 Finder 속성을 한 구조로 직렬화하는 과정에서 `-10000` 오류가 났다. DMG는 정상 detach됐고, 같은 DMG를 다시 mount해 속성을 개별 조회한 결과 위 layout 기준이 모두 일치했다.

작업지시자는 2026-07-19 rehearsal DMG를 Finder에서 직접 열어 배경과 화살표, `Alhangeul.app`과 `Applications` 아이콘 정렬, 텍스트 잘림·겹침 및 불필요한 visible root 항목이 없음을 육안으로 확인했다.

## Registration cleanup

Xcode와 Finder mount가 만든 개발 registration을 종료 시 점검했다.

- PlugInKit provider root는 `/Applications/Alhangeul.app` 하나였다.
- 표준 cleanup helper 실행 후 LaunchServices가 Task #424 부모 앱 경로를 계속 표시했다.
- diagnostics 원문에서 실제 record가 부모 app이 아니라 bundled Sparkle `Updater.app` nested 경로임을 확인했다.
- Task #424 nested `Updater.app` 경로만 `lsregister -u`로 해제했다.
- 최종 `scripts/check-extension-registration-hygiene.sh --check-only` 결과 development registration, legacy app/extension과 issue가 모두 0건이었다.
- 개발 app bundle 파일은 검증 산출물로 남아 있지만 등록되어 있지 않다.

전역 LaunchServices reset이나 설치본 삭제는 수행하지 않았다.

## 미실행 항목

rehearsal은 unsigned local artifact이므로 다음을 성공으로 기록하지 않는다.

- Developer ID signing, notarization submit/wait, staple와 Gatekeeper
- public GitHub Release, stable appcast, Pages deployment와 Homebrew Cask
- Intel Mac 실기기 실행
- installed signed candidate의 HOP exact UTI Finder 후보·open·Quick Look·Thumbnail
- signed candidate의 Host RPC readiness와 SVG/PDF export
- v0.1.7에서 v0.1.8로 Sparkle update와 extension refresh

## 판단

- Gate 2 source preflight와 Gate 3 local rehearsal DMG 기준은 통과했다.
- rehearsal DMG는 layout과 packaging 회귀 확인용으로만 유효하며 public asset, Sparkle enclosure 또는 Homebrew SHA256으로 사용할 수 없다.
- Stage 4 진입 전 Task #424 PR을 `devel`에 merge하고, `devel -> main` release PR, tag, draft publish를 각각 별도 승인 gate로 진행해야 한다.
- upstream latest guard 예외 `require_latest_rhwp=false`도 draft Publish 실행 시 별도 승인이 필요하다.

## 승인 요청

Stage 3 완료 결과를 승인하고 Stage 4 `Main/Tag와 Pre-public Signed Candidate 검증` 진입을 요청한다. Stage 4의 Task #424 PR 게시, `devel -> main` PR, `v0.1.8` tag와 draft Publish workflow는 각각 하이퍼-워터폴 승인 gate를 유지한다.
