# Task M019 #230 Stage 1 완료보고서

## 단계 목적

앱/DMG 용량 최적화 검토의 기준점을 고정하기 위해 현재 release 구조, Rust bridge 링크 방식, 단일 universal DMG 운영 전제, 다음 단계 측정 프로토콜을 정리했다.

이 단계는 조사와 측정 기준 확정만 수행했다. 제품 코드, release script, 정책 문서, Xcode project는 수정하지 않았다.

## 산출물

- `mydocs/working/task_m019_230_stage1.md`
  - Stage 1 조사 결과, 기준 수치, Stage 2 측정 프로토콜을 기록한 신규 단계 보고서
- 조사 기준
  - 브랜치: `local/task230`
  - 기준 커밋: `b80265d`
  - 측정 기준 확정 시각: `2026-05-11 13:29:18 KST`

## 본문 변경 정도 / 본문 무손실 여부

- 신규 보고서 1건만 추가했다.
- 기존 문서 본문, source, build script, workflow, generated Xcode project는 변경하지 않았다.
- public release, Sparkle appcast, Pages deployment, Homebrew Cask 반영은 수행하지 않았다.

## 조사 결과

### Rust bridge 링크 구조

현재 Rust bridge는 staticlib 기반이다.

| 항목 | 확인 내용 |
|------|-----------|
| Rust crate output | `RustBridge/Cargo.toml`의 `[lib] crate-type = ["staticlib"]` |
| universal staticlib | `scripts/build-rust-macos.sh`가 `Frameworks/universal/librhwp.a`를 만든 뒤 `Rhwp.xcframework`로 포장 |
| HostApp 링크 | `project.yml`의 HostApp target이 `Frameworks/Rhwp.xcframework`를 `embed: false`로 링크 |
| Quick Look 링크 | QLExtension target도 같은 `Rhwp.xcframework`를 `embed: false`로 링크 |
| Thumbnail 링크 | ThumbnailExtension target도 같은 `Rhwp.xcframework`를 `embed: false`로 링크 |

따라서 현재 구조에서는 Rust core가 dynamic shared framework로 bundle 내부에 1회 포함되는 방식이 아니라, 각 product executable에 정적으로 링크되는 구조로 보아야 한다. Stage 2에서는 HostApp, Preview appex, Thumbnail appex 실행 파일을 각각 측정해 중복 링크 효과를 수치화한다.

### Universal build 강제 경로

| 경로 | 확인 내용 |
|------|-----------|
| `scripts/package-release.sh` | Release build에 `ARCHS="arm64 x86_64"`와 `ONLY_ACTIVE_ARCH=NO`를 지정하고, 산출 app을 `verify-universal-macos-app.sh`로 검증 |
| `scripts/release.sh` | signing 여부와 무관하게 Release build에 `ARCHS="arm64 x86_64"`와 `ONLY_ACTIVE_ARCH=NO`를 지정 |
| `scripts/ci/verify-universal-macos-app.sh` | HostApp, Preview appex, Thumbnail appex 실행 파일 모두 `arm64 x86_64` slice를 요구 |

현재 release helper 기준으로 arch별 public 산출물을 만들 수 있는 switch는 없다. Stage 2의 arch별 app bundle은 release policy 변경 후보를 검토하기 위한 local-only 측정 산출물로만 만든다.

### 배포 문서의 단일 universal DMG 전제

| 표면 | 현재 기준 |
|------|-----------|
| Release policy | `v0.1.1`부터 public DMG는 앱 본체와 Quick Look/Thumbnail extension 실행 파일이 `arm64 + x86_64` slice를 포함하는 단일 universal DMG여야 함 |
| GitHub Release asset | public release 계층은 `alhangeul-macos-<version>.dmg` 단일 파일과 `.sha256` 기준 |
| Pages 다운로드 | 아키텍처 선택 UI 없이 단일 universal DMG latest URL을 직접 가리키는지 확인하도록 되어 있음 |
| Sparkle appcast | appcast enclosure는 단일 universal DMG URL을 가리키며 arch별 enclosure를 나누지 않음 |
| Homebrew Cask | `on_arm`/`on_intel`로 다른 DMG URL을 나누지 않고 단일 universal DMG URL/SHA256을 사용 |

이 전제를 바꾸면 단순히 build script의 `ARCHS`만 바꾸는 문제가 아니다. GitHub Release asset naming, Pages UX, Sparkle enclosure 선택 정책, Homebrew Cask URL/SHA256, 사용자 support matrix를 함께 바꾸어야 한다.

### 이슈 제공 기준선

다음 값은 Stage 1에서 재측정한 값이 아니라 이슈 #230 본문에 기록된 public release 기준선이다.

| 항목 | v0.1.0 | v0.1.1 | 증가 |
|------|--------|--------|------|
| Public DMG | `66,111,087` bytes | `91,439,787` bytes | `25,328,700` bytes, 약 `38.3%` |
| mounted `Alhangeul.app` bundle | `113,644 KiB` | `192,680 KiB` | `79,036 KiB`, 약 `69.5%` |

실행 파일 기준선:

| 실행 파일 | v0.1.0 | v0.1.1 | 증가 |
|-----------|--------|--------|------|
| `Contents/MacOS/Alhangeul` | `25,843,056` bytes | `53,380,912` bytes | `27,537,856` bytes |
| `AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` | `24,942,336` bytes | `51,583,744` bytes | `26,641,408` bytes |
| `AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail` | `24,986,832` bytes | `51,692,368` bytes | `26,705,536` bytes |

세 실행 파일이 각각 약 `26.6-27.5 MB` 증가했다는 점은 universal 전환과 Rust staticlib 중복 링크가 주요 원인이라는 이슈 가설과 맞다.

## 측정 프로토콜

Stage 2부터는 같은 commit에서 `universal`, `arm64-only`, `x86_64-only` 산출물을 같은 항목으로 측정한다.

### 산출물 위치

| variant | app bundle 후보 |
|---------|-----------------|
| universal | `build.noindex/task230/DerivedData-universal/Build/Products/Release/Alhangeul.app` |
| arm64-only | `build.noindex/task230/DerivedData-arm64/Build/Products/Release/Alhangeul.app` |
| x86_64-only | `build.noindex/task230/DerivedData-x86_64/Build/Products/Release/Alhangeul.app` |

### 측정 항목

| 항목 | 명령 기준 |
|------|-----------|
| app bundle size | `du -sk <Alhangeul.app>` |
| executable byte size | `stat -f "%N %z" <binary>` |
| resources breakdown | `du -sk <Alhangeul.app>/Contents/Resources` |
| frameworks breakdown | `du -sk <Alhangeul.app>/Contents/Frameworks` |
| plug-ins breakdown | `du -sk <Alhangeul.app>/Contents/PlugIns` |
| arch slice | `xcrun lipo -info <binary>` |
| dynamic dependencies | `otool -L <binary>` |
| DMG byte size | `stat -f "%N %z" <dmg>` |
| DMG checksum 후보 | `shasum -a 256 <dmg>` |

### 비교표 형식

Stage 2 보고서부터 다음 열을 기본으로 사용한다.

| variant | arch | app KiB | DMG bytes | Host exe bytes | Preview exe bytes | Thumbnail exe bytes | Resources KiB | Frameworks KiB | PlugIns KiB | 비고 |
|---------|------|---------|-----------|----------------|-------------------|---------------------|---------------|----------------|-------------|------|

DMG 값은 Stage 3에서 채운다. Stage 2에서는 app bundle과 executable 중심으로 먼저 측정한다.

### 해석 기준

- `v0.1.1` public 수치와 현 브랜치 local 수치는 직접 동일 조건 비교로 보지 않는다.
- 같은 commit 안의 `universal` 대 `arm64-only`/`x86_64-only` 차이를 주 판단 근거로 둔다.
- `CODE_SIGNING_ALLOWED=NO` build는 compile/link와 size 비교용이며 public 배포 기준이 아니다.
- `--skip-notarize` rehearsal DMG는 download size 후보 비교에는 사용할 수 있지만 public DMG 성공으로 기록하지 않는다.
- arch별 DMG 후보는 policy 변경 전까지 GitHub Release, Pages, Sparkle, Homebrew에 사용할 수 없다.

## 검증 결과

구현계획서 Stage 1의 검증 명령을 `/private/tmp/rhwp-mac-task230` worktree에서 실행했다.

```bash
git status --short --branch
```

결과:

```text
## local/task230
```

```bash
rg -n "Rhwp\\.xcframework|ARCHS=\"arm64 x86_64\"|verify-universal|단일 universal|Sparkle appcast|Homebrew Cask|on_arm|on_intel|arm64 \\+ x86_64|x86_64 \\+ arm64" \
  project.yml scripts/package-release.sh scripts/release.sh scripts/ci/verify-universal-macos-app.sh \
  mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/release_homebrew_cask_guide.md
```

확인된 핵심 결과:

- `project.yml`의 HostApp/QLExtension/ThumbnailExtension이 모두 `Frameworks/Rhwp.xcframework`를 참조한다.
- `scripts/package-release.sh`와 `scripts/release.sh`가 `ARCHS="arm64 x86_64"`를 사용한다.
- `scripts/ci/verify-universal-macos-app.sh`가 세 실행 파일의 universal slice를 검증한다.
- release policy는 `v0.1.1`부터 단일 universal DMG를 public 기준으로 둔다.
- Sparkle appcast와 Homebrew Cask 문서는 arch별 URL 분기를 현재 기준에서 금지한다.

추가 확인:

```bash
rg -n "staticlib|librhwp|Rhwp\\.xcframework|Frameworks/universal/librhwp\\.a|embed: false" \
  README.md mydocs/tech/project_architecture.md mydocs/tech/core_release_compatibility.md \
  RustBridge/Cargo.toml scripts/build-rust-macos.sh project.yml
```

확인된 핵심 결과:

- `RustBridge/Cargo.toml`의 crate type은 `staticlib`다.
- `scripts/build-rust-macos.sh`는 `Frameworks/universal/librhwp.a`와 `Rhwp.xcframework`를 생성한다.
- `project.yml`은 세 target에서 `Rhwp.xcframework`를 `embed: false`로 참조한다.

보고서 작성 후 확인:

```bash
git diff --check -- mydocs/working/task_m019_230_stage1.md
```

결과: 통과.

## 잔여 위험

- Stage 1의 inventory는 keyword scan과 핵심 파일 확인 기준이다. Stage 2-3에서 실제 build/DMG 산출물이 나오면 script behavior와 문서 기준 사이의 추가 차이가 드러날 수 있다.
- `v0.1.1` 기준선은 이슈 본문 수치를 옮긴 값이다. public asset 재다운로드나 mount 재측정은 Stage 1 범위에서 수행하지 않았다.
- local unsigned app bundle과 public signed/notarized DMG는 code signature, staple, compression 결과가 달라질 수 있다.
- arch별 산출물 build가 Xcode/Cargo cache, Rust target 설치 상태, code signing 설정에 영향을 받을 수 있다.

## 다음 단계 영향

Stage 2에서는 이 보고서의 측정 프로토콜에 따라 `build.noindex/task230/` 아래에서 다음 세 variant를 만든다.

- universal Release app bundle
- arm64-only Release app bundle
- x86_64-only Release app bundle

Stage 2 완료 전에는 DMG 운영 정책이나 Rust core 공유 구조에 대한 결론을 내리지 않는다.

## 승인 요청

Stage 1 결과를 승인하면 Stage 2 `universal/arch별 app bundle 산출물 측정`으로 진행한다.
