# Task M016 #145 구현계획서

수행계획서: `mydocs/plans/task_m016_145.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #145 v0.1 release artifact 구성과 provenance 정리
- 마일스톤: M016 (`v0.1 출시 전 보강`)
- 브랜치: `local/task145`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 주 대상: `mydocs/manual/release_distribution_guide.md`, `scripts/ci/write-release-notes.sh`, release workflow, package/release script의 산출물 기준
- 기준 artifact version: `0.1.0`
- 기준 core provenance: `rhwp-core.lock`, `Sources/HostApp/Resources/rhwp-studio/manifest.json`, `rhwp-ffi-symbols.txt`
- 목표: 개발/검증용 zip, rehearsal DMG, public signed/notarized DMG의 역할과 checksum/provenance 공개 항목을 분리하고, artifact 생성 후 재현 가능한 검증 명령을 남긴다.

## 구현 원칙

- public 사용자 배포 기준은 signed/notarized DMG로 둔다.
- `scripts/package-release.sh` zip은 설치본 smoke와 개발 검증용 Release package로 분리한다.
- `scripts/release.sh --skip-notarize` rehearsal DMG는 layout/checksum rehearsal로만 사용하고 public release, Homebrew Cask, GitHub Release asset 기준으로 쓰지 않는다.
- 이번 작업에서는 #167이 갱신한 `rhwp-core.lock`의 `v0.7.10` pin, Rust bridge ABI, generated framework/header를 변경하지 않는다.
- 현재 publish workflow 기본 `expected_rhwp_tag: v0.7.10`과 current lock `v0.7.10`은 일치한다. Stage 1-2의 `v0.7.9` 불일치 판단은 #167 merge 이전 이력으로 보존하고, Stage 3 이후 기준 문서에는 현재 정합 상태를 반영한다.
- release note와 checksum 공개 항목은 실제 public DMG digest를 기준으로 한다. zip checksum은 smoke/rehearsal 보고용으로만 취급한다.
- signing/notarization credential, Git tag, GitHub Release 생성, Homebrew Cask checksum 교체는 작업지시자 별도 지시 없이는 수행하지 않는다.
- 문서 변경은 한국어로 작성하고, 공개 README에는 운영 절차 전체를 중복하지 않는다.

## Stage 1. release artifact inventory와 provenance 기준 확인

### 목표

- 현재 저장소의 artifact 생성 경로, version 기준, release workflow 기본값, core/studio provenance 기준을 변경 없이 조사한다.
- Stage 2에서 설계할 artifact 구성표와 공개 항목의 입력을 확정한다.

### 작업

- `scripts/package-release.sh`, `scripts/release.sh`, `.github/workflows/release-rehearsal.yml`, `.github/workflows/release-publish.yml`, `scripts/ci/write-release-notes.sh`의 산출물 이름과 checksum 처리 방식을 조사한다.
- HostApp, QLExtension, ThumbnailExtension의 `CFBundleShortVersionString`이 `0.1.0`인지 확인한다.
- `rhwp-core.lock`의 repository/ref kind/tag/commit/artifact hash/size를 확인한다.
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 tag/commit/entrypoint hash를 확인한다.
- `rhwp-ffi-symbols.txt`의 current ABI symbol snapshot을 확인한다.
- publish workflow 기본 `expected_rhwp_tag`, `require_latest_rhwp`와 current lock의 정합성을 기록한다.
- 필요하면 `gh release view -R edwardkim/rhwp --json tagName`으로 upstream latest release를 확인하되, 네트워크 실패 시 latest 확인 실패를 별도 리스크로 기록한다.
- Stage 1 보고서에 inventory 표와 Stage 2 설계 입력을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_145_stage1.md`

### 검증

```bash
git status --short --branch
bash -n scripts/package-release.sh scripts/release.sh scripts/ci/write-release-notes.sh
./scripts/release.sh --help
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
sed -n '1,180p' rhwp-core.lock
sed -n '1,220p' Sources/HostApp/Resources/rhwp-studio/manifest.json
sed -n '1,120p' rhwp-ffi-symbols.txt
rg -n "ZIP_NAME|DMG_NAME|sha256|checksum|expected_rhwp_tag|require_latest_rhwp|write-release-notes|release artifact" \
  scripts/package-release.sh scripts/release.sh scripts/ci/write-release-notes.sh .github/workflows/release-rehearsal.yml .github/workflows/release-publish.yml mydocs/manual/release_distribution_guide.md
git diff --check
```

### 완료 기준

- artifact 생성 경로별 파일명, 산출 위치, checksum 처리, 사용 범위가 보고서에 정리된다.
- current lock/studio provenance와 release workflow 기대값 정합성이 분리된다.
- Stage 2에서 설계할 항목과 Stage 3에서 수정할 후보 파일이 확정된다.

### 커밋 메시지

```text
Task #145 Stage 1: release artifact inventory 정리
```

## Stage 2. artifact 구성과 공개 항목 설계

### 목표

- 개발/검증용 zip, rehearsal DMG, public DMG의 책임 경계를 확정한다.
- release note, checksum, provenance 공개 항목의 문서 구조를 정한다.

### 작업

- artifact별 표를 작성한다.
  - `build.noindex/release/Alhangeul.app`
  - `build.noindex/release/alhangeul-macos-0.1.0.zip`
  - `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg`
  - `build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256`
  - `build.noindex/release/alhangeul-macos-0.1.0.dmg`
  - `build.noindex/release/alhangeul-macos-0.1.0.dmg.sha256`
- release note에 포함할 항목을 정한다.
  - 설치 방법
  - DMG 파일명과 SHA256
  - `rhwp` release tag/commit
  - `rhwp-studio` manifest 위치
  - third-party notices 위치
  - smoke/known limitations 후속 보고서 연결
- checksum 공개 기준을 public DMG `.sha256` 파일과 GitHub Release note의 digest로 분리한다.
- `package-release` zip checksum은 Stage 보고서나 smoke report용으로만 남길지 결정한다.
- workflow 기본값과 current lock 정합성을 문서에 남기고, workflow default 조정이 필요한지 판단한다.
- Stage 2 보고서에 Stage 3 실제 변경안을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_145_stage2.md`

### 검증

```bash
git status --short --branch
rg -n "zip|rehearsal|public DMG|SHA256|rhwp-core.lock|manifest.json|release note|Homebrew|Cask|v0.7.9|v0.7.10" \
  mydocs/working/task_m016_145_stage2.md mydocs/plans/task_m016_145.md mydocs/plans/task_m016_145_impl.md
git diff --check
```

### 완료 기준

- artifact별 사용 목적과 public/rehearsal/smoke 구분이 표로 확정된다.
- release note와 checksum 공개 항목이 확정된다.
- Stage 3에서 수정할 파일과 수정하지 않을 파일이 분리된다.

### 커밋 메시지

```text
Task #145 Stage 2: artifact 공개 항목 설계
```

## Stage 3. 스크립트/워크플로우/문서 정합성 보강

### 목표

- Stage 2에서 확정한 artifact 기준과 공개 항목을 실제 문서 또는 script/workflow에 반영한다.
- public signing/notarization 실행 없이도 후속 작업자가 같은 기준으로 검증할 수 있게 한다.

### 작업

- `mydocs/manual/release_distribution_guide.md`의 artifact 종류, checksum, provenance, release note 기준을 보강한다.
- 필요 시 `scripts/ci/write-release-notes.sh`가 `rhwp-core.lock` 외에 `rhwp-studio` manifest/third-party notice/known limitations 연결을 포함하도록 보강한다.
- 필요 시 `.github/workflows/release-rehearsal.yml` summary에 rehearsal artifact의 비공개/비공증 성격과 core provenance를 더 명확히 남긴다.
- 필요 시 `.github/workflows/release-publish.yml` summary 문구를 current artifact 기준과 충돌하지 않게 조정한다. 단, core pin 자체는 변경하지 않는다.
- 필요 시 `scripts/package-release.sh`나 `scripts/release.sh`의 출력 문구 또는 checksum 파일 처리만 최소 보강한다.
- README는 public 사용자가 provenance 위치를 찾기 어렵다고 판단될 때만 짧은 진입점 문구를 추가한다.
- Stage 3 보고서에 변경 파일, 변경하지 않은 파일, public release 전 남은 조건을 기록한다.

### 예상 변경 파일

- `mydocs/manual/release_distribution_guide.md`
- `scripts/ci/write-release-notes.sh` (필요 시)
- `.github/workflows/release-rehearsal.yml` (필요 시)
- `.github/workflows/release-publish.yml` (필요 시)
- `scripts/package-release.sh` (필요 시)
- `scripts/release.sh` (필요 시)
- `README.md` (필요 시)
- `mydocs/working/task_m016_145_stage3.md`

### 검증

```bash
git status --short --branch
bash -n scripts/package-release.sh scripts/release.sh scripts/ci/write-release-notes.sh
./scripts/release.sh --help
scripts/verify-rhwp-studio-assets.sh
rg -n "alhangeul-macos-.*dmg|alhangeul-macos-.*zip|SHA256|rhwp-core.lock|rhwp-studio|manifest.json|THIRD_PARTY_LICENSES|FONTS.md|rehearsal|public release|expected_rhwp_tag" \
  README.md mydocs/manual/release_distribution_guide.md scripts/ci/write-release-notes.sh .github/workflows/release-rehearsal.yml .github/workflows/release-publish.yml scripts/package-release.sh scripts/release.sh
git diff --check
```

### 완료 기준

- public DMG, rehearsal DMG, zip의 책임 경계가 운영 문서 또는 script/workflow 출력과 일치한다.
- release note skeleton이 checksum과 provenance 공개 항목을 포함한다.
- current lock과 publish workflow 기대값 정합성이 숨겨지지 않고 명확히 처리된다.

### 커밋 메시지

```text
Task #145 Stage 3: release artifact 기준 보강
```

## Stage 4. artifact 생성 리허설과 bundle 포함 검증

### 목표

- 승인된 범위에서 실제 Release package 또는 rehearsal DMG를 만들어 산출물 구조, checksum, bundle 포함 상태를 확인한다.
- public signing/notarization 없이 검증 가능한 범위와 불가능한 범위를 보고서에 분리한다.

### 작업

- 기본으로 `./scripts/package-release.sh 0.1.0`을 실행해 Release package zip과 staging app을 만든다.
- 승인되면 `./scripts/release.sh --skip-notarize 0.1.0`으로 rehearsal DMG와 `.sha256`을 만든다.
- zip 또는 rehearsal DMG checksum을 확인한다.
- `Alhangeul.app` 내부 `Contents/PlugIns`에 Quick Look/Thumbnail extension이 포함되는지 확인한다.
- `Alhangeul.app` 내부 `Contents/Resources/rhwp-studio`에 `index.html`, WASM, JS, CSS, fonts가 포함되는지 확인한다.
- `plutil`로 HostApp/appex bundle identifier와 version을 확인한다.
- public signing, notarization, Gatekeeper, GitHub Release upload는 실행하지 않았음을 명확히 기록한다.
- Stage 4 보고서에 산출물 path, size, checksum, bundle 포함 검증 결과를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m016_145_stage4.md`

### 검증

```bash
git status --short --branch
./scripts/package-release.sh 0.1.0
test -d build.noindex/release/Alhangeul.app
test -f build.noindex/release/alhangeul-macos-0.1.0.zip
shasum -a 256 build.noindex/release/alhangeul-macos-0.1.0.zip
test -f build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
test -f build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm
test -d build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulQuickLook.appex
test -d build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
plutil -extract CFBundleIdentifier raw -o - build.noindex/release/Alhangeul.app/Contents/Info.plist
plutil -extract CFBundleShortVersionString raw -o - build.noindex/release/Alhangeul.app/Contents/Info.plist
git diff --check
```

선택 rehearsal DMG 검증:

```bash
./scripts/release.sh --skip-notarize 0.1.0
test -f build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
test -f build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
(cd build.noindex/release && shasum -a 256 -c alhangeul-macos-0.1.0-rehearsal.dmg.sha256)
hdiutil verify build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
```

### 완료 기준

- Release package 산출물이 `build.noindex/release` 아래에 생성되고 checksum이 기록된다.
- app bundle에 HostApp, Quick Look, Thumbnail, `rhwp-studio` 필수 asset이 포함된다.
- public release에서만 가능한 검증 항목과 rehearsal로 확인한 항목이 분리된다.

### 커밋 메시지

```text
Task #145 Stage 4: release artifact 리허설 검증
```

## Stage 5. 최종 보고와 후속 gate 연결

### 목표

- #145 결과를 최종 보고서로 정리하고 #151, #146이 이어받을 artifact/smoke/known limitation 입력을 명시한다.

### 작업

- 최종 결과보고서에 artifact 구성표, checksum/provenance 공개 항목, 검증 명령, 산출물 결과를 정리한다.
- release note 초안 또는 skeleton 변경 결과를 요약한다.
- public release 전에 남은 조건을 분리한다.
  - #150 WKWebView asset loading fallback
  - #149 손상/대용량 opening fallback
  - #151 설치본 smoke gate
  - #146 렌더 경로 한계 문서화
  - current `v0.7.10` 기준이 release 시점에도 upstream latest인지 확인
- `mydocs/orders/20260506.md`의 #145 상태를 완료로 갱신한다.
- PR 게시 전 working tree 상태와 최종 검증을 확인한다.

### 예상 변경 파일

- `mydocs/working/task_m016_145_stage5.md`
- `mydocs/report/task_m016_145_report.md`
- `mydocs/orders/20260506.md`

### 검증

```bash
git status --short --branch
rg -n "alhangeul-macos-0.1.0|SHA256|rhwp-core.lock|rhwp-studio|manifest.json|rehearsal|public DMG|#150|#149|#151|#146|v0.7.10" \
  mydocs/working/task_m016_145_stage5.md mydocs/report/task_m016_145_report.md mydocs/orders/20260506.md mydocs/manual/release_distribution_guide.md
git diff --check
```

### 완료 기준

- #145 최종 보고서에 artifact 구성, checksum/provenance 공개 기준, 검증 결과, 잔여 조건이 남는다.
- 오늘할일이 완료 상태로 갱신된다.
- PR 게시 전 working tree가 clean 상태다.

### 커밋 메시지

```text
Task #145 Stage 5 + 최종 보고서: release artifact 기준 정리 완료
```
