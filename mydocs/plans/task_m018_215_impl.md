# Task M018 #215 구현계획서

수행계획서: `mydocs/plans/task_m018_215.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #215 저작권자 정정과 release legal notice 포함 기준 보강
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task215`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 선행 상태: #147에서 `rhwp`, bundled `rhwp-studio`, WOFF2 font provenance 고지 구조를 만들었고, #177에서 Sparkle 2.9.1을 HostApp에 통합했다.
- 목표: 앱 저장소 자체 저작권자, third-party/upstream 저작권 경계, Sparkle 고지, app bundle legal notice resource, 기여 문구를 release 기준으로 정합화한다.

## 현재 전제와 제약

- 작업지시자가 앱 저장소 주 저작권자는 Taegyu Lee라고 확인했다.
- 대화 중 `LICENSE`의 저작권자 1줄은 이미 `Taegyu Lee`로 변경되어 있고, 현재 미커밋 상태다. 이 변경은 Stage 2 범위로 검증하고 커밋한다.
- bundled `rhwp-studio` 내부의 `© 2026 rhwp: Edward Kim` 표기는 upstream `rhwp` 고지이므로 변경하지 않는다.
- `Alhangeul.xcodeproj`는 생성물이고, 원본은 `project.yml`이다.
- 법률 자문 수준의 해석은 하지 않는다. 이번 작업은 저장소와 release artifact의 고지 구조를 명확히 하는 범위다.
- public DMG 생성, signing, notarization, Homebrew 배포 실행은 하지 않는다.

## 구현 원칙

- 루트 `LICENSE`는 Alhangeul macOS 저장소 자체 license와 주 저작권자를 표시한다.
- `THIRD_PARTY_LICENSES.md`는 upstream/third-party attribution과 provenance의 중심 문서로 유지한다.
- README는 사용자/기여자가 찾아갈 수 있는 짧은 진입점으로 두고, 세부 표를 중복하지 않는다.
- `CONTRIBUTING.md`는 외부 기여물의 license 적용과 저작권 보유 원칙을 짧게 명시한다.
- app bundle legal notice는 DMG root에 추가 파일을 노출하지 않고 `Contents/Resources/Legal/` 아래에서 확인 가능하게 한다.
- Legal resource는 가능한 단순한 정적 resource로 둔다. 중복 파일을 둘 경우 Stage 4에서 canonical 문서와의 내용 차이를 검증한다.

## Stage 1. 현황 inventory와 Legal resource 배치 확정

### 목표

현재 license/provenance 관련 파일과 HostApp resource 포함 구조를 확인하고, Legal resource를 어떤 파일 구조로 넣을지 확정한다.

### 작업

- 현재 변경 상태와 이미 반영된 `LICENSE` diff를 기록한다.
- `LICENSE`, README, `THIRD_PARTY_LICENSES.md`, `FONTS.md`, `CONTRIBUTING.md`, `Info.plist`, `project.yml`의 현재 license/copyright 문구를 조사한다.
- `project.yml`의 HostApp resource 포함 방식과 `Sources/HostApp/Resources` 구조를 확인한다.
- bundled `rhwp-studio` 내부 upstream copyright 문구가 어디에 남아 있는지 확인하고 변경 제외 대상으로 기록한다.
- Legal resource 후보 구조를 확정한다.
  - 후보: `Sources/HostApp/Resources/Legal/LICENSE`
  - 후보: `Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md`
  - 후보: `Sources/HostApp/Resources/Legal/FONTS.md`
- Stage 1 보고서에 결정과 근거를 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m018_215_stage1.md`

### 검증

```bash
git status --short --branch
git diff -- LICENSE
rg -n "Edward Kim|Taegyu Lee|Copyright|MIT License|THIRD_PARTY|Sparkle|NSHumanReadableCopyright|Legal|기여하신" \
  LICENSE README.md CONTRIBUTING.md THIRD_PARTY_LICENSES.md Sources/HostApp/Info.plist project.yml Sources/HostApp/Resources/rhwp-studio
find Sources/HostApp/Resources -maxdepth 3 -type f | sort
git diff --check
```

### 완료 기준

- Stage 1 보고서에 현재 책임 경계와 변경 제외 항목이 기록된다.
- Legal resource 파일명과 배치 위치가 확정된다.
- 아직 소스/문서 본문 변경은 Stage 1 보고서 외에는 하지 않는다.

### 커밋 메시지

```text
Task #215 Stage 1: legal notice 현황과 배치 기준 확정
```

## Stage 2. 저장소 license와 문서 고지 보강

### 목표

저장소 자체 license, README, third-party notice, 외부 기여 문구를 앱 저장소 저작권자와 upstream/third-party 경계에 맞춘다.

### 작업

- `LICENSE`의 저작권자 표기를 `Taegyu Lee` 기준으로 확정한다.
- `THIRD_PARTY_LICENSES.md`에 다음 내용을 보강한다.
  - Alhangeul 저장소 자체 license는 root `LICENSE`가 소유한다.
  - 앱 저장소 주 저작권자는 Taegyu Lee다.
  - `rhwp`/`rhwp-studio` upstream 저작권과 license는 third-party 고지로 분리한다.
  - Sparkle 2.9.1, MIT license, package provenance를 추가한다.
- README License 섹션을 보강한다.
  - 앱 저장소 license와 주 저작권자
  - third-party notices 위치
  - upstream `rhwp`/Sparkle/font 고지 위치
- `CONTRIBUTING.md` License 섹션을 보강한다.
  - 기여물은 본 저장소 MIT License로 제공된다.
  - 별도 계약이 없는 한 기여자는 자신의 기여물 저작권을 보유한다.
  - 기여자는 필요한 권리를 가진 기여만 제출해야 한다.
- Stage 2 보고서에 변경 전/후 문구와 제외한 upstream 문구를 기록한다.

### 예상 변경 파일

- `LICENSE`
- `THIRD_PARTY_LICENSES.md`
- `README.md`
- `CONTRIBUTING.md`
- `mydocs/working/task_m018_215_stage2.md`

### 검증

```bash
rg -n "Taegyu Lee|Edward Kim|Sparkle|MIT License|THIRD_PARTY_LICENSES|FONTS.md|기여물|저작권" \
  LICENSE README.md CONTRIBUTING.md THIRD_PARTY_LICENSES.md
git diff --check -- LICENSE README.md CONTRIBUTING.md THIRD_PARTY_LICENSES.md mydocs/working/task_m018_215_stage2.md
```

### 완료 기준

- root `LICENSE`와 README의 앱 저장소 주 저작권자가 Taegyu Lee로 일치한다.
- third-party notice가 `rhwp`, `rhwp-studio`, Sparkle, bundled fonts를 분리해 설명한다.
- 기여 문구가 license 적용과 기여자 저작권 보유 원칙을 명확히 한다.
- upstream `rhwp-studio` build output 내용은 변경하지 않는다.

### 커밋 메시지

```text
Task #215 Stage 2: 저장소 license와 third-party 고지 보강
```

## Stage 3. HostApp metadata와 Legal resource 포함

### 목표

앱 bundle metadata와 resource 안에서 사람이 읽을 수 있는 copyright/license notice를 확인할 수 있게 한다.

### 작업

- `Sources/HostApp/Info.plist`에 `NSHumanReadableCopyright`를 추가한다.
  - 값 후보: `Copyright © 2025-2026 Taegyu Lee`
- `Sources/HostApp/Resources/Legal/` 아래 legal notice 파일을 추가한다.
  - Stage 1에서 확정한 파일 구조를 따른다.
  - root `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` 기준과 내용이 어긋나지 않게 한다.
- 필요 시 `project.yml`에서 HostApp resource 포함 설정을 보강한다.
  - `Sources/HostApp` 경로 포함만으로 Legal resource가 bundle에 들어가면 별도 설정은 추가하지 않는다.
  - 별도 설정이 필요하면 XcodeGen 원본인 `project.yml`만 수정한다.
- app bundle Debug build 또는 XcodeGen-generated project 기준으로 Legal resource 포함 여부를 검증한다.
- Stage 3 보고서에 generated app bundle 내 파일 위치를 기록한다.

### 예상 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/HostApp/Resources/Legal/*`
- `project.yml` (필요 시)
- `mydocs/working/task_m018_215_stage3.md`

### 검증

```bash
plutil -lint Sources/HostApp/Info.plist
xcodegen dump --type parsed-yaml
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
plutil -p build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Info.plist | rg "NSHumanReadableCopyright|Taegyu Lee"
find build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal -maxdepth 1 -type f | sort
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/LICENSE
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/THIRD_PARTY_LICENSES.md
git diff --check
```

### 완료 기준

- HostApp Info.plist에 사람이 읽을 수 있는 copyright metadata가 들어간다.
- Debug app bundle의 `Contents/Resources/Legal/`에서 license와 third-party notice 파일을 확인할 수 있다.
- `Alhangeul.xcodeproj` 직접 수정은 없다.

### 커밋 메시지

```text
Task #215 Stage 3: HostApp legal notice resource 포함
```

## Stage 4. 통합 검증과 최종 정리

### 목표

문서, resource, metadata, build 결과를 통합 검증하고 최종 보고서와 오늘할일을 정리한다.

### 작업

- Stage 1-3 변경 결과를 전체 keyword scan으로 확인한다.
- Legal resource copy를 둔 경우 canonical 문서와의 차이를 확인한다.
- `project.yml` 변경이 있었다면 XcodeGen 재생성 결과를 확인한다.
- Debug build 산출물의 Legal resource와 `NSHumanReadableCopyright`를 다시 확인한다.
- `mydocs/orders/20260510.md`의 #215 상태를 완료로 갱신한다.
- 최종 보고서 `mydocs/report/task_m018_215_report.md`를 작성한다.
- Stage 4 보고서를 작성한다.

### 예상 변경 파일

- `mydocs/orders/20260510.md`
- `mydocs/working/task_m018_215_stage4.md`
- `mydocs/report/task_m018_215_report.md`

### 검증

```bash
plutil -lint Sources/HostApp/Info.plist
xcodegen dump --type parsed-yaml
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
find build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal -maxdepth 1 -type f | sort
rg -n "Taegyu Lee|Edward Kim|Sparkle|THIRD_PARTY_LICENSES|NSHumanReadableCopyright|Legal|기여물|저작권" \
  LICENSE README.md CONTRIBUTING.md THIRD_PARTY_LICENSES.md Sources/HostApp/Info.plist project.yml Sources/HostApp/Resources/Legal mydocs
git diff --check
git status --short
```

### 완료 기준

- license/provenance 문서, app metadata, app bundle resource가 서로 일관된다.
- 검증 명령 결과가 단계 보고서와 최종 보고서에 기록된다.
- 최종 보고서와 오늘할일 갱신이 커밋된다.
- PR 생성 전 미커밋 변경이 없다.

### 커밋 메시지

```text
Task #215 Stage 4 + 최종 보고서: legal notice 보강 완료
```

## 승인 요청 사항

1. 위 4단계 구현계획 승인
2. Stage 1에서 현황 inventory와 Legal resource 배치 확정부터 진행 승인
