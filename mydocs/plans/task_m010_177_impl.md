# Task #177 구현 계획서

수행계획서: `mydocs/plans/task_m010_177.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #177 Sparkle 기반 업데이트 확인과 GitHub Pages appcast 준비
- 마일스톤: M010 (`v0.1`)
- 브랜치: `local/task177`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 주 대상: HostApp Sparkle 통합, GitHub Pages `docs/` 업데이트 안내/appcast, release workflow appcast 생성 연동
- 목표: 첫 public DMG 배포 전에 앱 바이너리와 GitHub Pages에 업데이트 feed 기반을 포함한다.

## 확정 전제

- 업데이트 체계는 Sparkle 2를 기준으로 구현한다. 별도 GitHub Releases API polling updater는 만들지 않는다.
- 첫 배포 앱에는 `SUFeedURL`과 `SUPublicEDKey`가 포함되어야 한다.
- Sparkle private key, Apple credential, GitHub token 값은 저장소에 커밋하지 않는다.
- `project.yml`이 Xcode project 원본이다. `Alhangeul.xcodeproj` 직접 수정은 금지하고, Xcode project 변경은 `project.yml`에 반영한 뒤 `xcodegen generate`로 생성한다.
- 현재 HostApp은 sandboxed app이고 `com.apple.security.network.client` entitlement를 이미 가진다. Sparkle sandbox 설치에 필요한 installer launcher service와 mach lookup exception은 Stage 1에서 공식 문서 기준으로 확인한 뒤 반영한다.
- GitHub Pages는 PR #176 이후 `docs/` 정적 파일을 기준으로 제공된다.
- 실제 signed/notarized DMG 게시, GitHub Release publish, Homebrew Cask 배포 결정은 #166 범위로 남긴다.

## 다운로드 버튼 정책

GitHub Pages의 다운로드 버튼은 GitHub Release 페이지가 아니라 DMG asset 직접 다운로드 URL로 바꿀 수 있다.

후보:

```text
https://github.com/postmelee/alhangeul-macos/releases/latest/download/alhangeul-macos-0.1.0.dmg
https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg
```

판단 기준:

- GitHub 문서상 최신 release asset 직접 다운로드는 `/releases/latest/download/{asset-name}` 형식을 지원한다.
- GitHub latest release는 draft/prerelease가 아닌 published full release 기준이다. 첫 v0.1을 prerelease로 게시하면 `latest/download`가 의도대로 동작하지 않을 수 있다.
- v0.1을 prerelease로 게시할 가능성이 남아 있으면 `releases/download/v0.1.0/...` tag 고정 URL을 우선 검토한다.
- version이 파일명에 포함되므로 `docs/index.html` 버튼은 release workflow가 최종 version에 맞춰 갱신하거나, 첫 release 직전 수동 갱신 대상으로 둔다.
- `alhangeul-macos-latest.dmg` 같은 versionless alias asset은 stable URL을 만들 수 있지만, public checksum/Cask 기준 산출물과 혼동될 수 있어 Stage 1에서 필요성이 확인될 때만 채택한다.

## Stage 1 — Sparkle, Pages, release URL 요구사항 확정

### 목표

- Sparkle 2의 appcast, EdDSA signing, sandboxed app 요구사항을 공식 문서 기준으로 확정한다.
- GitHub Pages feed URL, prerelease/stable feed 정책, 다운로드 버튼 직접 DMG URL 정책을 결정한다.

### 작업

- Sparkle documentation에서 다음 항목을 확인한다.
  - `SUPublicEDKey`
  - `SUFeedURL`
  - `SUEnableInstallerLauncherService`
  - sandboxed app mach lookup entitlement
  - `sparkle:edSignature`
  - release notes link와 appcast XML 구조
- GitHub 문서에서 direct release asset URL과 latest/prerelease 동작을 확인한다.
- 현재 `docs/index.html`의 다운로드 버튼 위치와 href를 확인한다.
- 현재 `release-publish.yml`의 `draft`, `prerelease`, asset filename 정책을 확인한다.
- stable feed와 prerelease feed를 분리할지 결정한다.
- DMG 직접 다운로드 버튼 정책을 확정한다.
- Stage 1 보고서에 결정사항과 Stage 2-4 변경 파일을 확정한다.

### 예상 변경 파일

- `mydocs/working/task_m010_177_stage1.md`
- 필요 시 `mydocs/plans/task_m010_177_impl.md`

### 검증

```bash
git status --short --branch
rg -n "SUFeedURL|SUPublicEDKey|SUEnableInstaller|Sparkle|appcast|releases/latest|download" \
  project.yml Sources/HostApp docs .github/workflows scripts mydocs/manual/release_distribution_guide.md
git diff --check
```

### 완료 기준

- Sparkle app integration에 필요한 Info.plist, entitlement, dependency 항목이 확정된다.
- `appcast.xml`과 필요 시 `appcast-prerelease.xml` URL 정책이 확정된다.
- Pages 다운로드 버튼이 직접 DMG로 향하는 방식이 확정된다.

### 커밋 메시지

```text
Task #177 Stage 1: Sparkle 업데이트 요구사항 정리
```

## Stage 2 — HostApp Sparkle 통합

### 목표

- 앱에 Sparkle updater controller와 “업데이트 확인...” 메뉴를 추가한다.
- sandboxed app에서 Sparkle이 update install을 수행할 수 있게 필요한 설정을 반영한다.

### 작업

- `project.yml`에 Sparkle Swift Package dependency와 HostApp dependency를 추가한다.
- `Sources/HostApp/Info.plist`에 Sparkle 설정을 추가한다.
  - `SUFeedURL`
  - `SUPublicEDKey`
  - `SUEnableInstallerLauncherService`
  - 자동 업데이트 확인 관련 기본 정책
- `Sources/HostApp/HostApp.entitlements`에 Sparkle sandbox communication exception을 추가한다.
- `Sources/HostApp/Services/UpdateController.swift` 또는 동등한 작은 service를 추가한다.
- `HostAppCommands`에 “업데이트 확인...” 메뉴를 추가한다.
- placeholder public key를 넣어야 하는 경우, 실제 release key 생성 전임을 명확히 표시하고 Stage 4/문서에서 교체 gate를 둔다. 가능하면 작업지시자가 제공한 real public key를 사용한다.

### 예상 변경 파일

- `project.yml`
- `Sources/HostApp/Info.plist`
- `Sources/HostApp/HostApp.entitlements`
- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Services/UpdateController.swift`
- 필요 시 `Alhangeul.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `mydocs/working/task_m010_177_stage2.md`

### 검증

```bash
git status --short --branch
xcodegen generate
plutil -lint Sources/HostApp/Info.plist Sources/HostApp/HostApp.entitlements
plutil -extract SUFeedURL raw -o - Sources/HostApp/Info.plist
plutil -extract SUPublicEDKey raw -o - Sources/HostApp/Info.plist
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- HostApp이 Sparkle dependency와 함께 compile된다.
- 앱 메뉴에 수동 업데이트 확인 명령이 추가된다.
- Info.plist와 entitlements가 Sparkle sandbox integration 기준을 만족한다.

### 커밋 메시지

```text
Task #177 Stage 2: HostApp Sparkle 통합
```

## Stage 3 — GitHub Pages 업데이트 안내와 직접 다운로드 버튼

### 목표

- GitHub Pages에 업데이트 안내 페이지와 appcast skeleton을 추가한다.
- landing page 다운로드 버튼을 GitHub Release 페이지가 아니라 DMG 직접 다운로드 경로로 바꾼다.

### 작업

- `docs/updates/index.html`을 추가하거나 기존 `docs/index.html` 안에 업데이트 안내 진입점을 추가한다.
- `docs/appcast.xml` skeleton을 추가한다.
- 필요하면 `docs/appcast-prerelease.xml` skeleton을 추가한다.
- `docs/index.html` 다운로드 버튼 href를 Stage 1에서 확정한 direct DMG URL로 변경한다.
- 다운로드 버튼 문구, 보조 안내, fallback link가 mobile/desktop에서 깨지지 않는지 확인한다.
- Pages 정적 사이트에서 appcast XML이 올바른 content path로 접근되는지 로컬 서버로 확인한다.

### 예상 변경 파일

- `docs/index.html`
- `docs/styles.css`
- `docs/appcast.xml`
- 필요 시 `docs/appcast-prerelease.xml`
- 필요 시 `docs/updates/index.html`
- 필요 시 `docs/updates/v0.1.0.html`
- `mydocs/working/task_m010_177_stage3.md`

### 검증

```bash
git status --short --branch
test -f docs/appcast.xml
plutil -lint docs/appcast.xml || xmllint --noout docs/appcast.xml
rg -n "releases/(latest/download|download/v)|appcast|updates" docs/index.html docs/appcast.xml docs
python3 -m http.server 8000 --directory docs
```

로컬 서버 실행 후 별도 터미널 또는 브라우저에서 확인:

```bash
curl -I http://127.0.0.1:8000/
curl -I http://127.0.0.1:8000/appcast.xml
curl -I http://127.0.0.1:8000/updates/
git diff --check
```

### 완료 기준

- Pages에서 사용자가 업데이트 안내를 볼 수 있다.
- Sparkle feed URL로 사용할 `appcast.xml` path가 존재한다.
- 다운로드 버튼이 direct DMG URL을 가리킨다.

### 커밋 메시지

```text
Task #177 Stage 3: Pages 업데이트 경로 추가
```

## Stage 4 — appcast 생성 script와 release workflow 연동

### 목표

- release publish workflow가 DMG asset과 Sparkle signature를 기준으로 appcast XML을 갱신할 수 있게 한다.
- secret 미설정, prerelease, draft, Pages source 갱신 실패를 명확히 분리한다.

### 작업

- `scripts/ci/write-sparkle-appcast.sh`를 추가한다.
  - 입력: version, build number, DMG URL, DMG path 또는 size, signature, release notes URL, output file
  - 출력: Sparkle appcast XML
  - secret 값은 출력하지 않는다.
- Sparkle `sign_update` 또는 `generate_appcast` 사용 가능성을 검토하고, GitHub Actions에서 재현 가능한 경로를 선택한다.
- `.github/workflows/release-publish.yml`에 appcast 생성 단계를 추가한다.
- Pages source인 `docs/` 갱신 방식은 다음 중 하나로 Stage 1 결정에 맞춰 구현한다.
  - release PR 전에 appcast skeleton만 두고, #166에서 release asset 확정 후 별도 커밋으로 갱신
  - release workflow가 bot commit/PR로 `docs/appcast.xml` 갱신
  - appcast를 별도 branch/artifact로 배포
- 직접 다운로드 버튼의 version 갱신 방식도 workflow 또는 release 전 수동 gate로 연결한다.
- secret/variable 목록을 release distribution guide에 문서화한다.

### 예상 변경 파일

- `scripts/ci/write-sparkle-appcast.sh`
- `.github/workflows/release-publish.yml`
- 필요 시 `.github/workflows/release-rehearsal.yml`
- 필요 시 `scripts/ci/write-release-notes.sh`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/working/task_m010_177_stage4.md`

### 검증

```bash
git status --short --branch
bash -n scripts/ci/write-sparkle-appcast.sh
bash scripts/ci/write-sparkle-appcast.sh --help
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release-publish.yml"); puts "ok"'
./scripts/release.sh --help
git diff --check
```

가능하면 fixture 값으로 appcast 생성:

```bash
bash scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.0 \
  --build 1 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.0/alhangeul-macos-0.1.0.dmg \
  --length 123456 \
  --ed-signature TEST_SIGNATURE \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.0.html \
  --output /tmp/appcast.xml
xmllint --noout /tmp/appcast.xml
```

### 완료 기준

- appcast 생성 script가 deterministic XML을 만든다.
- release workflow가 appcast 생성/갱신 책임을 명확히 가진다.
- Sparkle private key와 CI secret 운영 기준이 문서화된다.

### 커밋 메시지

```text
Task #177 Stage 4: Sparkle appcast 생성 자동화
```

## Stage 5 — 통합 검증과 최종 보고

### 목표

- HostApp build, Pages 정적 파일, appcast XML, release workflow 문법을 통합 검증한다.
- #166이 이어받을 release 전 gate를 명확히 남긴다.

### 작업

- `xcodegen generate` 후 HostApp Debug build를 실행한다.
- `Info.plist`, entitlement, appcast XML lint를 실행한다.
- `docs/` 로컬 서버로 `index.html`, `appcast.xml`, `updates/` 접근을 확인한다.
- release workflow YAML을 정적 검증한다.
- Sparkle key/secret, 직접 다운로드 버튼, prerelease/stable feed 정책의 남은 작업을 최종 보고서에 정리한다.
- 오늘할일 상태를 완료로 갱신한다.

### 예상 변경 파일

- `mydocs/working/task_m010_177_stage5.md`
- `mydocs/report/task_m010_177_report.md`
- `mydocs/orders/20260508.md`

### 최종 검증

```bash
git status --short --branch
git diff --check
xcodegen generate
plutil -lint Sources/HostApp/Info.plist Sources/HostApp/HostApp.entitlements
test -f docs/appcast.xml
xmllint --noout docs/appcast.xml
ruby -e 'require "yaml"; Dir[".github/workflows/*.yml"].each { |f| YAML.load_file(f); puts f }'
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

정적 사이트 확인:

```bash
python3 -m http.server 8000 --directory docs
curl -I http://127.0.0.1:8000/
curl -I http://127.0.0.1:8000/appcast.xml
curl -I http://127.0.0.1:8000/updates/
```

### 실제 실행 제외 확인

다음은 이 task 완료만으로 실행하지 않는다.

- public notarization submission
- GitHub Release publish
- Homebrew Cask 배포
- Apple credential 또는 Sparkle private key 생성값 커밋
- #166 release 기준 tag 생성

### 완료 기준

- 첫 출시 앱에 Sparkle feed 설정과 public key가 들어간다.
- GitHub Pages에서 appcast와 업데이트 안내 경로가 제공된다.
- 다운로드 버튼이 DMG 직접 다운로드 경로를 가리킨다.
- release workflow가 appcast 생성 또는 갱신 절차를 가진다.
- #166이 release 실행만 이어받을 수 있도록 남은 gate가 최종 보고서에 정리된다.

### 커밋 메시지

```text
Task #177 Stage 5 + 최종 보고서: Sparkle 업데이트 경로 정리
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다.
