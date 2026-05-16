# Task #154 구현 계획서

본 문서는 [`task_m010_154.md`](task_m010_154.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- **Worktree**: `/private/tmp/rhwp-mac-task154`
- **Branch**: `local/task154`
- **기준 브랜치**: `devel-webview`
- **기준 이슈**: [#154](https://github.com/postmelee/alhangeul-macos/issues/154)
- **범위**: 첫 public release 전 제품 identity를 `Alhangeul`로 통일

## 확정 전제

- 최종 철자는 `Alhangeul`이다.
- 사용자 표시명, `.app` bundle name, bundle id, Xcode project/product/executable, extension product/appex, Cask `app` stanza는 `Alhangeul` 계열로 변경한다.
- 저장소명, release DMG 파일명, Homebrew Cask token은 `alhangeul-macos`로 유지한다.
- `HostApp`, `QLExtension`, `ThumbnailExtension` target 이름은 역할 기반 이름이므로 `AlhangeulMac` 문자열이 들어 있지 않다. Stage 1에서 변경 필요성이 없으면 유지한다.
- 실제 public release, notarization submission, GitHub Release upload, Homebrew tap 반영은 이 task에서 수행하지 않는다.

## Stage 1 — rename 대상과 호환성 경계 조사

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m010_154_stage1.md` | 전체 rename 대상 목록, 변경/유지/legacy 분류, 위험 정리 | 조사 보고서 |
| `mydocs/plans/task_m010_154_impl.md` | 필요 시 구현계획서 보정 | 조사 중 blocker 발견 시만 |

### 조사 항목

- `project.yml`: project name, product name, executable name, bundle id
- `Sources/**/Info.plist`: default display/name, bundle id placeholder, UTI exported/supported type
- `Sources/**/Resources/*/InfoPlist.strings`: 영어/한국어 localized display name
- Swift 코드: extension bundle id, appex name, domain, dispatch queue label, share directory
- scripts: package/release project/app/appex cleanup/volume name
- Cask: `app "AlhangeulMac.app"`
- docs: build/run/release/architecture/core compatibility/Finder smoke guide
- generated Xcode project 파일이 tracked인지 여부

### 확인 기준

- `AlhangeulMac`/`alhangeulmac` 사용처를 빠짐없이 목록화한다.
- `alhangeul-macos` 유지 대상과 `Alhangeul` 변경 대상을 분리한다.
- UTI identifier를 `com.postmelee.alhangeul.*`로 옮길 때 HostApp, QLExtension, ThumbnailExtension, open panel이 모두 같은 값을 참조하는지 확인한다.
- 기존 설치본/등록 잔여물 처리 필요성을 Stage 4 문서 작업에 넘긴다.

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task154
rg --line-number 'AlhangeulMac|alhangeulmac|AlhangeulMacHost|AlhangeulMacPreview|AlhangeulMacThumbnail|com\.postmelee\.alhangeulmac' \
  project.yml README.md Casks scripts Sources mydocs/manual mydocs/tech .github
git ls-files | rg 'AlhangeulMac\.xcodeproj|Alhangeul\.xcodeproj' || true
git diff --check
```

### 커밋

```
Task #154 Stage 1: Alhangeul rename 대상과 경계 조사
```

## Stage 2 — Xcode project identity와 bundle/UTI 정합화

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `project.yml` | project name, product name, executable name, bundle id를 `Alhangeul` 계열로 변경 | target name은 유지 예상 |
| `Sources/HostApp/Info.plist` | default bundle display/name, exported UTI identifier, document type content type 변경 | `com.hancom.*` 유지 |
| `Sources/QLExtension/Info.plist` | extension default name, supported content type 변경 | 새 app UTI와 일치 |
| `Sources/ThumbnailExtension/Info.plist` | extension default name, supported content type 변경 | 새 app UTI와 일치 |
| `Sources/**/Resources/en.lproj/InfoPlist.strings` | 영어 표시명을 `Alhangeul`, `Alhangeul Preview`, `Alhangeul Thumbnail`로 변경 | 사용자 표시명 |
| 필요 시 `Sources/**/Resources/ko.lproj/InfoPlist.strings` | 한국어 표시명은 유지 또는 필요 최소 보정 | `알한글` 계열 유지 |

### 예상 identity

- app product: `Alhangeul`
- app executable: `Alhangeul`
- app bundle id: `com.postmelee.alhangeul`
- Quick Look product/executable: `AlhangeulPreview`
- Quick Look bundle id: `com.postmelee.alhangeul.QLExtension`
- Thumbnail product/executable: `AlhangeulThumbnail`
- Thumbnail bundle id: `com.postmelee.alhangeul.ThumbnailExtension`
- app UTI: `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx`

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task154
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
rg --line-number 'AlhangeulMac|alhangeulmac|com\.postmelee\.alhangeulmac' \
  project.yml Sources
git diff --check
```

`rg`는 남은 문자열 확인용이다. Stage 2 이후 `Sources`와 `project.yml`에 남은 문자열은 실패로 보고 같은 단계에서 정리한다.

### 커밋

```
Task #154 Stage 2: Xcode identity와 bundle UTI 정합화
```

## Stage 3 — Swift 코드와 script/Cask rename 반영

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/HostApp/Services/ExtensionStatusModel.swift` | extension bundle id와 appex name 변경 | About/진단 표시 |
| `Sources/HostApp/Services/DocumentOpenPanel.swift` | allowed UTI 변경 | Stage 2 UTI와 일치 |
| `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift` | error domain 변경 | bundle id 계열 |
| `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift` | error domain 변경 | bundle id 계열 |
| `Sources/HostApp/Services/DocumentFileActions.swift` | share temp directory 변경 | `AlhangeulShare` 예상 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | queue label 변경 | bundle id 계열 |
| `scripts/package-release.sh` | project/app/appex cleanup 이름 변경 | `Alhangeul.app` |
| `scripts/release.sh` | project/app/DMG volume 이름 변경 | public DMG filename은 유지 |
| `Casks/alhangeul-macos.rb` | `app "Alhangeul.app"`로 변경 | token 유지 |

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task154
bash -n scripts/package-release.sh scripts/release.sh
./scripts/release.sh --help
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
rg --line-number 'AlhangeulMac|alhangeulmac|AlhangeulMacHost|AlhangeulMacPreview|AlhangeulMacThumbnail|com\.postmelee\.alhangeulmac' \
  Sources scripts Casks project.yml
git diff --check
```

`rg`는 남은 문자열 확인용이며, Stage 3 소유 범위 안의 non-legacy 문자열은 같은 단계에서 정리한다.

### 커밋

```
Task #154 Stage 3: Swift 코드와 배포 스크립트 rename 반영
```

## Stage 4 — 문서와 smoke test 기준 갱신

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `README.md` | project/build/run/pluginkit 명령과 앱 경로 변경 | 사용자/기여자 안내 |
| `.github/copilot-instructions.md` | generated Xcode project 이름 변경 | reviewer 기준 |
| `mydocs/manual/build_run_guide.md` | build/run/Finder smoke 명령 변경 | smoke 진실 원천 |
| `mydocs/manual/release_distribution_guide.md` | public DMG 내부 app, Cask app stanza, 검증 명령 변경 | Task #148와 충돌 주의 |
| `mydocs/tech/project_architecture.md` | identity 정책을 새 기준으로 변경 | 기존 유지 정책 제거 |
| `mydocs/tech/core_release_compatibility.md` | release package 설치 경로 예시 변경 | 필요 최소 |
| 필요 시 troubleshooting 문서 | legacy `AlhangeulMac`은 이전 이름으로 명시 | stale scan 결과 기준 |

### 문서 기준

- 새 표준 설치 경로: `$HOME/Applications/Alhangeul.app`
- 새 debug path: `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app`
- 새 process check: `pgrep -x Alhangeul`
- 새 pluginkit grep: `com.postmelee.alhangeul`
- legacy cleanup 문맥에서만 `AlhangeulMac.app` 허용

### 단계 검증

```bash
cd /private/tmp/rhwp-mac-task154
rg --line-number 'AlhangeulMac|alhangeulmac|AlhangeulMacHost|AlhangeulMacPreview|AlhangeulMacThumbnail|com\.postmelee\.alhangeulmac' \
  README.md .github mydocs/manual mydocs/tech
rg --line-number 'Alhangeul\.app|com\.postmelee\.alhangeul|Alhangeul\.xcodeproj|pgrep -x Alhangeul|pluginkit.*com\.postmelee\.alhangeul' \
  README.md .github mydocs/manual mydocs/tech
bash -n scripts/package-release.sh scripts/release.sh
git diff --check
```

첫 번째 `rg`는 legacy 문맥 확인용이다. 남은 문자열은 이전 이름 정리나 호환성 설명처럼 명시적 legacy 문맥이어야 한다.

### 커밋

```
Task #154 Stage 4: 문서와 smoke 기준을 Alhangeul로 갱신
```

## Stage 5 — 최종 검증과 보고서 정리

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m010_154_stage{N}.md` | 단계별 완료 보고서 작성 | 단계별 승인 후 진행 |
| `mydocs/report/task_m010_154_report.md` | 최종 결과 보고서 작성 | 모든 단계 완료 후 |
| `mydocs/orders/20260506.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
cd /private/tmp/rhwp-mac-task154
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
bash -n scripts/package-release.sh scripts/release.sh
./scripts/release.sh --help
./scripts/package-release.sh 0.1.0
rg --line-number 'AlhangeulMac|alhangeulmac|AlhangeulMacHost|AlhangeulMacPreview|AlhangeulMacThumbnail|com\.postmelee\.alhangeulmac' \
  project.yml README.md Casks scripts Sources mydocs/manual mydocs/tech .github
git diff --check
git status --short --branch
```

가능하고 별도 승인이 있으면 release rehearsal도 수행한다.

```bash
./scripts/release.sh --skip-notarize 0.1.0
```

Finder 통합 smoke는 signed/sealed release package 기준으로 수행한다. 기존 `AlhangeulMac.app` 설치본 제거가 필요하면 작업지시자 승인 후 진행한다.

### 실제 실행 제외 확인

다음은 이 구현계획 승인만으로 실행하지 않는다.

- public notarization submission
- GitHub Release 생성 또는 asset upload
- Homebrew tap push 또는 PR 생성
- App Store Connect 제출
- secret 생성, export, 커밋
- 승인 없는 기존 설치본 삭제

### 커밋

```
Task #154 Stage 5 + 최종 보고서: Alhangeul identity 통일 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다.
