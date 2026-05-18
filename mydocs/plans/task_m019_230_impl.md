# Task M019 #230 구현계획서

수행계획서: `mydocs/plans/task_m019_230.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #230 앱/DMG 용량 최적화를 위한 아키텍처별 배포와 Rust core 공유 구조 검토
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task230`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 목표: universal DMG 유지, 아키텍처별 DMG 분리, Rust core 공유 구조, strip/LTO/build setting 최적화 후보를 실제 또는 보수적 시뮬레이션 수치와 운영 비용 기준으로 비교하고 `v0.1.x` 적용 권고를 남긴다.

## 현재 전제와 제약

- `v0.1.1` public release부터 앱 본체와 Quick Look/Thumbnail extension 실행 파일은 `arm64 + x86_64` universal binary 기준이다.
- `project.yml`에서 HostApp, QLExtension, ThumbnailExtension이 모두 `Frameworks/Rhwp.xcframework`를 `embed: false`로 링크한다.
- 현재 Rust bridge 산출물은 staticlib 기반 `Rhwp.xcframework`이며, Rust core가 세 실행 파일에 각각 정적으로 포함될 수 있다.
- `scripts/package-release.sh`와 `scripts/release.sh`는 `ARCHS="arm64 x86_64"`와 `ONLY_ACTIVE_ARCH=NO`를 명시한다.
- `scripts/release.sh`는 입력 버전이 HostApp/QLExtension/ThumbnailExtension `CFBundleShortVersionString`과 일치해야 한다.
- release policy, Pages/Sparkle guide, Homebrew Cask guide는 단일 universal DMG를 현재 공식 기준으로 둔다.
- `--skip-notarize` rehearsal DMG와 unsigned/ad-hoc local 산출물은 public release 기준이 아니다.
- public release 실행, GitHub Release 게시, Pages deployment, Sparkle appcast 갱신, Homebrew tap 반영은 하지 않는다.
- `Alhangeul.xcodeproj`는 생성물이고 직접 수정하지 않는다.

## 구현 원칙

- Stage 1은 조사와 측정 프로토콜 확정만 수행하고 제품 코드, release script, 정책 문서는 수정하지 않는다.
- 측정 산출물은 모두 `build.noindex/task230/` 아래에 둔다.
- public `v0.1.1` 수치와 현 브랜치 local 산출물 수치는 같은 표 안에 두되, commit, version, signing/notarization 여부가 다름을 명시한다.
- 같은 commit에서 universal, arm64-only, x86_64-only를 비교할 때는 같은 Xcode version, 같은 DerivedData root, 같은 측정 명령을 사용한다.
- DMG는 public notarized DMG와 local compressed DMG/rehearsal DMG를 구분해 기록한다.
- 산출물 크기 비교와 운영 정책 판단을 분리한다. 크기가 줄어도 Sparkle/Homebrew/Pages/release 운영 비용이 크면 즉시 적용 권고로 보지 않는다.
- dynamic/shared Rust core 구조는 구현하지 않고 feasibility, 예상 절감량, required validation만 문서화한다.

## Stage 1. release 구조 inventory와 측정 프로토콜 확정

### 목표

현재 release 구조와 단일 universal DMG 전제를 조사하고, 이후 단계에서 반복 사용할 측정 항목과 명령을 확정한다.

### 작업

1. `project.yml`에서 HostApp, QLExtension, ThumbnailExtension의 `Rhwp.xcframework` dependency 구조를 정리한다.
2. `scripts/package-release.sh`, `scripts/release.sh`, `scripts/ci/verify-universal-macos-app.sh`에서 universal build와 verification 경로를 정리한다.
3. release policy, Pages/Sparkle guide, Homebrew Cask guide에서 단일 universal DMG 전제와 arch별 분기 금지/제외 기준을 정리한다.
4. 측정 항목을 확정한다.
   - DMG byte size
   - app bundle `du -sk`
   - HostApp/QLExtension/ThumbnailExtension executable byte size
   - `Contents/Resources`, `Contents/Frameworks`, `Contents/PlugIns` breakdown
   - `lipo -info`와 arch별 slice 확인
   - 주요 dylib/framework 의존성 확인
5. public `v0.1.1` 이슈 본문 수치를 Stage 1 보고서에 기준선으로 옮기되, 재측정값이 아니라 issue-provided baseline임을 표시한다.
6. Stage 1 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/working/task_m019_230_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "Rhwp.xcframework|ARCHS=\"arm64 x86_64\"|verify-universal|single universal|단일 universal|Sparkle appcast|Homebrew Cask|on_arm|on_intel" \
  project.yml scripts/package-release.sh scripts/release.sh scripts/ci/verify-universal-macos-app.sh \
  mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/release_homebrew_cask_guide.md
git diff --check -- mydocs/working/task_m019_230_stage1.md
```

### 완료 기준

- Stage 1 보고서에 build/release 구조와 단일 universal DMG 전제가 정리된다.
- 이후 측정에 사용할 command set과 표 형식이 확정된다.
- 제품 코드, release script, 정책 문서는 변경하지 않는다.

### 커밋 메시지

```text
Task #230 Stage 1: release 구조와 용량 측정 기준 정리
```

## Stage 2. universal/arch별 app bundle 산출물 측정

### 목표

현 브랜치 같은 commit에서 universal, arm64-only, x86_64-only Release app bundle을 만들고 앱/extension 실행 파일과 bundle breakdown을 측정한다.

### 작업

1. `./scripts/build-rust-macos.sh --verify-lock`으로 Rust bridge 산출물과 lock 정합성을 확인한다.
2. `xcodegen generate`로 project를 재생성한다.
3. `build.noindex/task230/DerivedData-universal`에 universal Release app bundle을 build한다.
4. `build.noindex/task230/DerivedData-arm64`에 arm64-only Release app bundle을 build한다.
5. `build.noindex/task230/DerivedData-x86_64`에 x86_64-only Release app bundle을 build한다.
6. 세 app bundle에서 같은 항목을 측정한다.
   - `Alhangeul.app` bundle `du -sk`
   - `Contents/MacOS/Alhangeul`
   - `Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview`
   - `Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail`
   - `Contents/Resources`, `Contents/Frameworks`, `Contents/PlugIns`
   - `xcrun lipo -info`
   - `otool -L`
7. Stage 2 보고서에 raw command와 측정표를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m019_230_stage2.md`

측정 산출물:

- `build.noindex/task230/DerivedData-universal/`
- `build.noindex/task230/DerivedData-arm64/`
- `build.noindex/task230/DerivedData-x86_64/`

### 검증

```bash
./scripts/build-rust-macos.sh --verify-lock
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build.noindex/task230/DerivedData-universal \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build.noindex/task230/DerivedData-arm64 \
  ARCHS="arm64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build.noindex/task230/DerivedData-x86_64 \
  ARCHS="x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
xcrun lipo -info build.noindex/task230/DerivedData-universal/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
xcrun lipo -info build.noindex/task230/DerivedData-arm64/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
xcrun lipo -info build.noindex/task230/DerivedData-x86_64/Build/Products/Release/Alhangeul.app/Contents/MacOS/Alhangeul
git diff --check -- mydocs/working/task_m019_230_stage2.md
```

### 완료 기준

- 세 build variant의 app bundle과 핵심 실행 파일 크기가 같은 기준으로 측정된다.
- arch별 절감량이 absolute byte/KiB와 universal 대비 percentage로 기록된다.
- build 실패가 있으면 실패 명령, 원인 후보, 시뮬레이션 대체 여부가 기록된다.

### 커밋 메시지

```text
Task #230 Stage 2: universal과 arch별 app bundle 용량 측정
```

## Stage 3. DMG 후보와 배포 운영 영향 비교

### 목표

local-only DMG 후보 또는 시뮬레이션으로 다운로드 크기 차이를 비교하고, 아키텍처별 DMG가 release 운영 표면에 미치는 영향을 정리한다.

### 작업

1. 현재 plist version을 읽어 `scripts/release.sh --skip-notarize`가 생성할 rehearsal DMG 이름을 확정한다.
2. 가능하면 `ALHANGEUL_BUILD_ROOT=build.noindex/task230 ./scripts/release.sh --skip-notarize --output build.noindex/task230/release-universal <current-version>`로 universal rehearsal DMG를 생성하고 크기를 측정한다.
3. Stage 2의 arm64/x86_64 app bundle로 local compressed DMG 시뮬레이션을 만든다.
   - public release DMG가 아님을 파일명과 보고서에 명시한다.
   - DMG root에는 app bundle과 `Applications` symlink만 넣어 release layout에 가까운 크기 비교를 한다.
   - Finder layout, signing, notarization, staple은 성공 조건으로 보지 않는다.
4. GitHub Release asset naming 후보를 비교한다.
   - 단일 universal: `alhangeul-macos-<version>.dmg`
   - arch별 후보: `alhangeul-macos-<version>-arm64.dmg`, `alhangeul-macos-<version>-x86_64.dmg`
5. Pages 다운로드 UX, Sparkle appcast enclosure, Homebrew Cask `url`/`sha256`, release notes/support matrix 변경점을 정리한다.
6. 사용자가 잘못된 DMG를 받을 가능성과 이를 줄이기 위한 UX/문서 비용을 기록한다.
7. Stage 3 보고서를 작성한다.

### 예상 변경 파일

- `mydocs/working/task_m019_230_stage3.md`

측정 산출물:

- `build.noindex/task230/release-universal/`
- `build.noindex/task230/dmg-sim-arm64/`
- `build.noindex/task230/dmg-sim-x86_64/`

### 검증

```bash
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
ALHANGEUL_BUILD_ROOT=build.noindex/task230 ./scripts/release.sh --skip-notarize --output build.noindex/task230/release-universal "$(plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist)"
find build.noindex/task230 -maxdepth 3 -name "*.dmg" -print -exec stat -f "%N %z" {} \;
rg -n "appcast enclosure|Sparkle|Homebrew|on_arm|on_intel|단일 universal|alhangeul-macos-<version>" \
  mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/release_homebrew_cask_guide.md \
  scripts/ci/write-sparkle-appcast.sh Casks/alhangeul-macos.rb
git diff --check -- mydocs/working/task_m019_230_stage3.md
```

### 완료 기준

- DMG 수준의 download size 후보가 최소 universal 포함 2개 이상 기록된다.
- arch별 DMG 도입 시 바뀌는 release asset, Pages, Sparkle, Homebrew, support matrix 항목이 정리된다.
- local-only DMG와 public signed/notarized DMG의 차이가 명시된다.

### 커밋 메시지

```text
Task #230 Stage 3: arch별 DMG 절감량과 배포 영향 비교
```

## Stage 4. Rust core 공유 구조와 build setting 최적화 검토

### 목표

Rust core 중복 링크를 줄이는 shared 구조와 strip/LTO/build setting 후보를 구현 없이 검토하고, 예상 절감량과 검증 비용을 정리한다.

### 작업

1. Stage 2의 세 실행 파일 크기와 `Frameworks/universal/librhwp.a` 크기를 기준으로 정적 중복분을 보수적으로 추정한다.
2. `Rhwp.xcframework`를 dynamic framework 형태로 전환할 때 필요한 구조 변경 후보를 정리한다.
   - HostApp embedding 위치
   - app extension에서 framework load 가능 경로
   - `@rpath`/`LC_RPATH`
   - nested framework signing 순서
   - hardened runtime/notarization 검증
   - Sparkle update 후 nested framework signature 유지
3. shared embedded framework를 app과 appex가 함께 사용할 때의 배포 검증 범위를 정리한다.
4. strip/LTO/build setting 후보를 조사한다.
   - Swift/Xcode `DEPLOYMENT_POSTPROCESSING`, `STRIP_INSTALLED_PRODUCT`, `COPY_PHASE_STRIP`
   - Rust release profile LTO/codegen-units/panic/symbol stripping 후보
   - symbolication/debuggability 영향
5. 즉시 적용 가능한 저위험 build setting 후보와 구조 변경이 필요한 고위험 후보를 분리한다.
6. Stage 4 보고서를 작성한다.

### 예상 변경 파일

- `mydocs/working/task_m019_230_stage4.md`

### 검증

```bash
stat -f "%N %z" Frameworks/universal/librhwp.a
find build.noindex/task230 -path "*/Alhangeul.app/Contents/MacOS/Alhangeul" -print -exec stat -f "%N %z" {} \;
find build.noindex/task230 -path "*/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview" -print -exec stat -f "%N %z" {} \;
find build.noindex/task230 -path "*/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail" -print -exec stat -f "%N %z" {} \;
rg -n "staticlib|lto|panic|strip|crate-type|Rhwp.xcframework|librhwp" RustBridge Frameworks scripts mydocs/tech mydocs/manual
git diff --check -- mydocs/working/task_m019_230_stage4.md
```

### 완료 기준

- Rust core 공유 구조의 예상 절감량과 required validation이 문서화된다.
- strip/LTO/build setting 후보가 저위험/고위험으로 분류된다.
- 실제 source/build setting 변경은 하지 않는다.

### 커밋 메시지

```text
Task #230 Stage 4: Rust core 공유 구조와 빌드 최적화 후보 검토
```

## Stage 5. 권고안, 최종 검증, 보고

### 목표

측정 수치와 운영 비용을 종합해 `v0.1.x`에서 유지할 배포 형태와 후속 작업 후보를 권고한다.

### 작업

1. Stage 1-4 결과를 하나의 비교표로 통합한다.
2. 다음 선택지를 같은 기준으로 비교한다.
   - 단일 universal DMG 유지
   - 단일 universal DMG 유지 + 저위험 strip/build setting 최적화
   - 아키텍처별 DMG 분리
   - Rust core shared/dynamic 구조 전환
   - hybrid 접근
3. `v0.1.x` 즉시 적용 여부와 `v0.2+` 또는 native viewer 구조 개선과 묶을 후보를 분리한다.
4. 필요한 후속 GitHub Issue 후보를 제목/범위 수준으로 정리한다. 이슈 생성은 별도 승인 전에는 하지 않는다.
5. `mydocs/orders/20260511.md`의 #230 상태를 완료로 갱신한다.
6. 최종 보고서 `mydocs/report/task_m019_230_report.md`를 작성한다.
7. Stage 5 완료보고서를 작성한다.

### 예상 변경 파일

- `mydocs/orders/20260511.md`
- `mydocs/working/task_m019_230_stage5.md`
- `mydocs/report/task_m019_230_report.md`

### 검증

```bash
test -f mydocs/report/task_m019_230_report.md
rg -n "단일 universal|아키텍처별|Rust core|Rhwp.xcframework|Sparkle|Homebrew|권고|후속" \
  mydocs/working/task_m019_230_stage*.md mydocs/report/task_m019_230_report.md
git diff --check
git status --short
```

### 완료 기준

- 최종 보고서에 크기 측정표, 운영 영향 비교, 구조 리스크, 권고안이 포함된다.
- public release, Sparkle, Pages, Homebrew 변경을 실제로 수행하지 않았음이 명시된다.
- 후속 이슈 후보가 필요한 경우 생성 전 승인 대상으로 분리된다.
- PR 생성 전 미커밋 변경이 없다.

### 커밋 메시지

```text
Task #230 Stage 5 + 최종 보고서: 앱 DMG 용량 최적화 권고 정리
```

## 승인 요청 사항

1. 위 5단계 구현계획 승인
2. Stage 1에서 release 구조 inventory와 측정 프로토콜 확정부터 진행 승인
