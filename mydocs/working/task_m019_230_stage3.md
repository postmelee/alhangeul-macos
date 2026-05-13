# Task M019 #230 Stage 3 완료보고서

## 단계 목적

Stage 2에서 만든 `universal`, `arm64-only`, `x86_64-only` Release app bundle을 DMG 형태로 압축했을 때의 download size 후보를 비교했다.

이 단계는 arch별 DMG를 public release 산출물로 만들지 않는다. GitHub Release, Pages, Sparkle appcast, Homebrew Cask, signing, notarization, staple, release 정책 문서는 변경하지 않았다.

## 산출물

- `mydocs/working/task_m019_230_stage3.md`
  - Stage 3 DMG 후보 측정과 배포 운영 영향 비교를 기록한 신규 단계 보고서
- local-only DMG 측정 산출물
  - `build.noindex/task230/dmg-sim-universal/alhangeul-macos-0.1.1-universal-local-only.dmg`
  - `build.noindex/task230/dmg-sim-arm64/alhangeul-macos-0.1.1-arm64-local-only.dmg`
  - `build.noindex/task230/dmg-sim-x86_64/alhangeul-macos-0.1.1-x86_64-local-only.dmg`
- release script rehearsal 입력 산출물
  - `build.noindex/task230/release-universal/Alhangeul.app`

## 본문 변경 정도 / 본문 무손실 여부

- 신규 단계 보고서 1건만 추가했다.
- 제품 source, release script, release policy 문서, GitHub Actions workflow, Homebrew Cask는 수정하지 않았다.
- DMG 산출물은 `build.noindex/` 아래 local-only 측정 입력이며 commit 대상이 아니다.
- `--skip-notarize` rehearsal은 public DMG가 아니며, 이번 단계에서 만든 `*-local-only.dmg`도 public 배포 기준으로 사용하지 않는다.

## 버전 기준

```bash
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
```

결과:

```text
0.1.1
```

## Universal release rehearsal 결과

실행 명령:

```bash
ALHANGEUL_BUILD_ROOT=build.noindex/task230 ./scripts/release.sh --skip-notarize --output build.noindex/task230/release-universal "$(plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist)"
```

결과:

- Rust bridge lock verify 통과
- `xcodegen generate` 통과
- universal Release app build 통과
- HostApp, Preview extension, Thumbnail extension 모두 `x86_64 arm64` slice 확인 통과
- unsigned rehearsal이므로 codesign verification skip 경고 출력
- DMG layout용 read/write image 생성 후 Finder layout AppleScript 단계에서 실패

실패 지점:

```text
Finder에 오류 발생: toolbar visible of container window of disk "Alhangeul 0.1.1"을(를) false(으)로 설정할 수 없습니다. (-10006)
```

해석:

- `scripts/release.sh --skip-notarize`는 Finder 기반 DMG window layout을 강제한다.
- 현재 자동 실행 환경에서는 이 AppleScript 단계가 안정적으로 통과하지 않았다.
- 따라서 `alhangeul-macos-0.1.1-rehearsal.dmg`와 `.sha256` 최종 산출물은 생성되지 않았다.
- build와 universal architecture 검증은 통과했으므로, Stage 3 download size 비교는 같은 app bundle을 이용한 local-only 압축 DMG 시뮬레이션으로 진행했다.

## Local-only DMG 생성 기준

각 DMG root에는 다음만 배치했다.

- `Alhangeul.app`
- `/Applications` symlink

의도적으로 제외한 것:

- Finder window layout
- background image
- Developer ID signing
- notarization
- staple
- public release 파일명

이 기준은 download size 후보 비교용이다. 사용자 설치 UX와 Gatekeeper 신뢰 기준을 대표하지 않는다.

## 측정 결과

### App bundle과 DMG 크기

| variant | arch | app KiB | local-only DMG bytes | local-only DMG KiB | SHA256 |
|---------|------|---------|----------------------|--------------------|--------|
| universal | `x86_64 + arm64` | `192308` | `92949438` | `90771` | `a2fa0e7707e4a9fd24eff5f80ee51cc7fe6a39fe86cdc0d1be7ee44d257b162f` |
| arm64-only | `arm64` | `113660` | `63565461` | `62076` | `7c71feb5b7c972b51f4fd61e16741c9d982058ad7ea8dc9a8603d5a3b8321c22` |
| x86_64-only | `x86_64` | `118240` | `65460538` | `63926` | `27d464f75f5e18a8598c8c13a0659470b3a4f130e98c459152c0cbace9bfadc9` |

### Universal 대비 DMG 절감량

| 후보 | 절감 bytes | 절감 KiB | 절감률 |
|------|------------|----------|--------|
| arm64-only DMG | `29383977` | `28695` | `31.6%` |
| x86_64-only DMG | `27488900` | `26845` | `29.6%` |

### 관찰

- Stage 2의 app bundle 기준 절감률은 arm64 `40.9%`, x86_64 `38.5%`였지만, 압축 DMG 기준 절감률은 arm64 `31.6%`, x86_64 `29.6%`로 낮아졌다.
- `Resources`가 arch split으로 줄지 않기 때문에 DMG 압축 후에도 고정 비용이 남는다.
- x86_64-only DMG가 arm64-only DMG보다 약 `1895077 bytes` 크다. Stage 2의 실행 파일 크기 차이가 압축 후에도 유지된다.
- GitHub Release download size만 보면 arch split은 의미 있는 절감 효과가 있다.
- 하지만 현재 public release 정책은 단일 universal DMG를 release, Pages, Sparkle, Homebrew의 공통 기준으로 고정하고 있어 운영 표면 변경이 크다.

## 배포 운영 영향

### GitHub Release asset

현재 기준:

- `alhangeul-macos-<version>.dmg`
- `alhangeul-macos-<version>.dmg.sha256`

arch별 DMG 후보:

- `alhangeul-macos-<version>-arm64.dmg`
- `alhangeul-macos-<version>-arm64.dmg.sha256`
- `alhangeul-macos-<version>-x86_64.dmg`
- `alhangeul-macos-<version>-x86_64.dmg.sha256`

영향:

- release note에 CPU별 선택 기준과 checksum 표가 추가로 필요하다.
- `latest/download/alhangeul-macos-<version>.dmg` 형태의 단일 latest link를 그대로 유지하기 어렵다.
- 단일 universal DMG를 유지하면서 arch별 DMG를 보조 asset으로 추가하는 방식은 compatibility risk가 낮지만, 기본 다운로드 절감 효과는 제한된다.
- arch별 DMG만 제공하면 사용자가 잘못된 asset을 받을 수 있다. Apple Silicon에서 x86_64 build는 Rosetta 의존 가능성이 생기고, Intel Mac은 arm64 build를 실행할 수 없다.

### GitHub Pages

현재 기준:

- Pages 다운로드 버튼은 아키텍처 선택 UI 없이 단일 universal latest URL을 직접 가리킨다.
- Intel Mac과 Apple Silicon Mac이 같은 DMG를 사용한다는 안내를 최신 다운로드 주변에 둔다.

arch별 DMG로 바꿀 때 필요한 변경:

- 다운로드 UI를 `Apple Silicon` / `Intel` 선택으로 분기한다.
- 브라우저에서 CPU architecture를 신뢰성 있게 판별하기 어렵기 때문에 자동 선택은 보조 힌트로만 취급해야 한다.
- 잘못 받은 DMG를 식별하는 안내와 fallback universal DMG 여부를 정해야 한다.
- `docs/updates/index.html`, version별 release page, latest download link 기준을 함께 바꿔야 한다.

### Sparkle appcast

현재 기준:

- stable feed는 하나다: `https://postmelee.github.io/alhangeul-macos/appcast.xml`
- `scripts/ci/write-sparkle-appcast.sh`는 하나의 `<enclosure>`만 생성한다.
- appcast enclosure URL은 tag 고정 단일 universal DMG를 가리킨다.
- guide는 Sparkle appcast가 아키텍처별 enclosure를 나누지 않는다고 명시한다.

arch별 DMG로 바꿀 때 필요한 변경:

- Sparkle update archive를 arch별로 나누는 정책과 client compatibility 검증이 필요하다.
- 하나의 appcast에서 arch별 enclosure를 표현할지, feed를 나눌지, universal feed를 유지할지 결정해야 한다.
- `write-sparkle-appcast.sh` 입력 모델은 `--dmg-url`, `--length`, `--ed-signature`가 단일 값이므로 구조 변경이 필요하다.
- Sparkle EdDSA signature와 length도 arch별 DMG마다 별도로 생성해야 한다.

Stage 3 기준으로는 Sparkle 때문에 public 기본 산출물을 arch별 DMG만으로 즉시 전환하는 것은 위험하다.

### Homebrew Cask

현재 기준:

- `Casks/alhangeul-macos.rb`는 단일 URL `alhangeul-macos-#{version}.dmg`와 단일 `sha256`을 사용한다.
- Homebrew guide는 `on_arm`/`on_intel`로 다른 DMG URL을 나누지 않는다고 명시한다.

arch별 DMG로 바꿀 때 필요한 변경:

- Cask에 `on_arm` / `on_intel` 분기와 arch별 `url`, `sha256`을 도입해야 한다.
- tap context에서 `brew style --cask`, `brew audit --cask`, install/uninstall smoke를 arch별로 검증해야 한다.
- release note와 Pages의 Homebrew 안내가 single universal DMG 전제에서 벗어난다.

### Release policy와 support matrix

현재 policy는 `v0.1.1`부터 public DMG가 `arm64 + x86_64` slice를 포함하는 단일 universal DMG여야 한다고 규정한다.

arch split을 채택하려면 다음 결정을 먼저 문서화해야 한다.

1. public 기본값을 universal로 유지하고 arch별 DMG를 보조 download로 둘 것인가
2. public 기본값을 arch별 DMG로 바꾸고 universal DMG를 제거할 것인가
3. Sparkle와 Homebrew는 universal을 유지하고 GitHub Release/Pages만 arch별 선택지를 추가할 것인가
4. Intel Mac 지원을 어느 release까지 유지할 것인가
5. 잘못된 architecture 다운로드를 받았을 때의 사용자 안내를 어디에 둘 것인가

## Stage 3 결론

- arch별 DMG는 download size를 약 `29.6-31.6%` 줄인다.
- 절감 효과는 분명하지만 Stage 2 app bundle 절감률보다 낮다.
- 현재 release 운영은 단일 universal DMG를 중심으로 맞춰져 있어, arch별 DMG 전환은 단순 build flag 변경이 아니라 release policy, Pages, Sparkle, Homebrew Cask의 동시 변경이다.
- 특히 Sparkle stable appcast가 단일 enclosure 구조라서, public 기본 산출물을 arch별 DMG만으로 바꾸려면 updater compatibility 검증이 선행되어야 한다.
- 현 시점의 보수적 후보는 `universal DMG 유지 + GitHub Release/Pages 보조 arch별 DMG 추가`다. 다만 이 경우 Sparkle/Homebrew 기본 download size는 줄지 않는다.

## 검증 결과

구현계획서 Stage 3의 검증 명령과 추가 DMG 검증을 실행했다.

```bash
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
ALHANGEUL_BUILD_ROOT=build.noindex/task230 ./scripts/release.sh --skip-notarize --output build.noindex/task230/release-universal "$(plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist)"
find build.noindex/task230 -maxdepth 3 -name "*.dmg" -print -exec stat -f "%N %z" {} \;
rg -n "appcast enclosure|Sparkle|Homebrew|on_arm|on_intel|단일 universal|alhangeul-macos-<version>" mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/release_homebrew_cask_guide.md scripts/ci/write-sparkle-appcast.sh Casks/alhangeul-macos.rb
hdiutil verify build.noindex/task230/dmg-sim-universal/alhangeul-macos-0.1.1-universal-local-only.dmg
hdiutil verify build.noindex/task230/dmg-sim-arm64/alhangeul-macos-0.1.1-arm64-local-only.dmg
hdiutil verify build.noindex/task230/dmg-sim-x86_64/alhangeul-macos-0.1.1-x86_64-local-only.dmg
git diff --check -- mydocs/working/task_m019_230_stage3.md
```

결과:

- plist version 확인: 통과, `0.1.1`
- universal release rehearsal: build와 architecture verify 통과, Finder layout AppleScript 단계 실패
- local-only DMG 생성: 통과
- local-only DMG size 측정: 통과
- release policy / Pages / Sparkle / Homebrew 현행 기준 확인: 통과
- `hdiutil verify`: 세 local-only DMG 모두 checksum valid
- 보고서 `git diff --check`: 통과

## 잔여 위험

- local-only DMG는 signing/notarization/staple 결과를 대표하지 않는다.
- Finder layout과 background image가 빠진 DMG라서 public release DMG와 byte-for-byte 비교할 수 없다.
- `release.sh --skip-notarize`의 Finder AppleScript 실패는 Stage 3 범위에서 수정하지 않았다. 공식 rehearsal automation 안정화는 별도 작업 후보가 될 수 있다.
- Intel Mac 실기기에서 x86_64-only DMG 설치/실행 smoke는 수행하지 않았다.
- Sparkle arch별 update 가능성은 문서와 script 구조를 기준으로 한 운영 영향 분석이며, 실제 Sparkle client matrix 검증은 후속 단계가 필요하다.

## 다음 단계 영향

Stage 4에서는 Rust core 공유 구조와 build setting 관점에서 app/extension 실행 파일 중복을 줄일 수 있는지 검토한다.

우선순위:

1. 현재 `Rhwp.xcframework` staticlib 링크 구조에서 Host/Preview/Thumbnail에 Rust code가 각각 들어가는 정도를 재확인한다.
2. shared dynamic framework 또는 XPC/helper 구조가 가능한지 macOS extension 제약과 함께 비교한다.
3. arch split과 core 공유 구조 중 어떤 접근이 용량/운영 리스크 대비 나은지 Stage 5 의사결정 자료로 넘긴다.

## 승인 요청

Stage 3 결과를 승인하면 Stage 4 `Rust core 공유 구조와 build setting 개선 검토`로 진행한다.
