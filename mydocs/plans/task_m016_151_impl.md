# Task M016 #151 구현계획서

수행계획서: `mydocs/plans/task_m016_151.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #151 Quick Look/Thumbnail 설치본 smoke gate 정리
- 마일스톤: M016 (`v0.1 출시 전 보강`)
- 브랜치: `local/task151`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 주 대상: Finder Quick Look preview / Thumbnail extension의 Release package 설치본 검증 절차
- 기준 artifact version: `0.1.0`
- 목표: `scripts/package-release.sh`로 만든 Release package staging app을 설치본 기준으로 검증하고, 자동 gate와 수동 preview 확인의 경계를 문서와 필요 시 helper script로 고정한다.

## 구현 원칙

- Finder 통합 smoke의 진실 원천은 `CODE_SIGNING_ALLOWED=NO` Debug 산출물이 아니라 Release package staging app이다.
- 표준 설치 경로는 `$HOME/Applications/Alhangeul.app` 하나로 고정한다.
- `.app`과 `.appex` filesystem name은 ASCII로 유지한다. 사용자 표시명은 localized `InfoPlist.strings`와 `LSHasLocalizedDisplayName`으로 확인한다.
- 이전 이름 설치본(`RhwpMac.app`, `AlhangeulMac.app`, `알한글.app`)은 발견만 보고하고, 제거는 작업지시자 별도 승인 후 수행한다.
- 자동 판정 gate는 `qlmanage -t -x` thumbnail smoke 중심으로 둔다.
- `qlmanage -p`와 Finder Space preview는 GUI/user session/cache 영향을 받으므로 자동 pass/fail gate가 아니라 수동 확인 항목과 한계로 기록한다.
- public Developer ID signing, notarization, public DMG, Homebrew Cask 배포는 이번 작업에서 수행하지 않는다.
- Quick Look lazy preview, native renderer parity, 손상/대용량 fallback 구현은 변경하지 않는다.
- 과거 보고서 원문은 보존하고, 현재 운영 문서와 troubleshooting의 현재 기준만 보정한다.

## Stage 1. 현행 Finder 통합 smoke 절차 inventory

### 목표

- 현재 문서와 산출물 기준에서 Quick Look/Thumbnail 설치본 smoke에 필요한 입력을 변경 없이 정리한다.
- Stage 2 설계에서 고칠 오래된 이름, 중복 명령, 판정 기준 혼선을 확정한다.

### 작업

- `build_run_guide.md`, `release_distribution_guide.md`, `finder_integration_validation_pitfalls.md`의 Finder 통합 검증 절차를 대조한다.
- #33, #40, #145 Stage 4 결과에서 재사용할 LaunchServices/PlugInKit, ASCII path, package-release, codesign 기준을 정리한다.
- `project.yml`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist`에서 현재 product name, bundle identifier, `NSExtensionPrincipalClass`, supported content type을 확인한다.
- `scripts/package-release.sh`의 산출물 위치, zip 이름, staging app 이름, `lsregister` 처리 방식을 확인한다.
- `samples/basic/KTX.hwp`, `samples/hwpx/hwpx-01.hwpx`를 대표 HWP/HWPX smoke 입력으로 사용할지 확인한다.
- Stage 1 보고서에 현재 절차 inventory와 Stage 2 설계 입력을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_151_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "Quick Look|Thumbnail|PlugInKit|qlmanage|lsregister|package-release|Alhangeul|AlhangeulMac|RhwpMac|알한글" \
  mydocs/manual/build_run_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/troubleshootings/finder_integration_validation_pitfalls.md \
  mydocs/report/task_m050_33_report.md \
  mydocs/working/task_m050_40_stage4.md \
  mydocs/working/task_m016_145_stage4.md
plutil -p Sources/QLExtension/Info.plist
plutil -p Sources/ThumbnailExtension/Info.plist
rg -n "PRODUCT_NAME|EXECUTABLE_NAME|PRODUCT_BUNDLE_IDENTIFIER|AlhangeulPreview|AlhangeulThumbnail" project.yml
sed -n '1,120p' scripts/package-release.sh
git diff --check
```

### 완료 기준

- 현재 운영 기준과 과거 기록을 분리해 정리한다.
- app/appex 이름, bundle id, principal class, content type, package 산출물 위치가 Stage 1 보고서에 표로 남는다.
- Stage 2에서 설계할 자동 gate와 수동 확인 항목의 입력이 확정된다.

### 커밋 메시지

```text
Task #151 Stage 1: Finder 통합 smoke inventory 정리
```

## Stage 2. smoke gate 판정 기준 설계

### 목표

- 설치본 smoke gate를 bundle 정합성, 시스템 등록, thumbnail 실행 smoke, preview 수동 확인, 실패 로그 수집으로 나누어 확정한다.
- helper script가 책임질 범위와 문서에 남길 범위를 결정한다.

### 작업

- bundle 정합성 체크를 확정한다.
  - `Alhangeul.app`
  - `AlhangeulPreview.appex`
  - `AlhangeulThumbnail.appex`
  - bundle identifier
  - `NSExtensionPrincipalClass`
  - `codesign --verify --deep --strict`
- 시스템 등록 체크를 확정한다.
  - `lsregister -u`
  - `ditto` 설치
  - `lsregister -f -R -trusted`
  - `pluginkit -a`
  - `pluginkit -mAvvv`
- thumbnail 자동 gate를 확정한다.
  - HWP: `samples/basic/KTX.hwp`
  - HWPX: `samples/hwpx/hwpx-01.hwpx`
  - fallback 후보: #149와 충돌하지 않는 범위에서 손상/대용량 입력은 smoke 명령 예시 또는 선택 항목으로 둘지 결정
  - output directory: `/tmp/alhangeul-ql`
- preview 수동 확인 기준을 확정한다.
  - `qlmanage -p` 명령은 수동 확인 후보로 둔다.
  - 자동 gate 실패/성공 판정과 분리한다.
- 실패 로그 수집 후보를 확정한다.
  - `pluginkit -mAvvv`
  - `lsregister -dump`
  - `codesign -dv`
  - `plutil -p`
  - `qlmanage` stderr
  - `log show` 또는 `log stream` predicate 후보
- helper script 설계를 정한다.
  - 기본은 `scripts/smoke-finder-integration.sh` 추가
  - 기본 입력은 기존 `build.noindex/release/Alhangeul.app`
  - `--skip-package` 또는 `--app <path>` 옵션 필요 여부 검토
  - 위험 작업인 `$HOME/Applications/Alhangeul.app` 교체를 명령 실행 전에 명확히 출력
- Stage 2 보고서에 Stage 3 변경안을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_151_stage2.md`

### 검증

```bash
git status --short --branch
rg -n "bundle 정합성|시스템 등록|thumbnail|preview|수동|helper|smoke-finder-integration|AlhangeulPreview|AlhangeulThumbnail|KTX|hwpx-01|log show|log stream" \
  mydocs/working/task_m016_151_stage2.md
git diff --check
```

### 완료 기준

- 자동 pass/fail gate와 수동 확인 항목이 분리된다.
- helper script의 옵션, 기본 경로, 출력, 실패 코드 정책이 확정된다.
- Stage 3에서 수정할 문서와 script 범위가 확정된다.

### 커밋 메시지

```text
Task #151 Stage 2: 설치본 smoke gate 설계
```

## Stage 3. 문서와 helper script 보강

### 목표

- Stage 2에서 확정한 설치본 smoke gate를 운영 문서와 helper script에 반영한다.
- 현재 `Alhangeul` product name 기준으로 오래된 운영 지침을 보정한다.

### 작업

- `scripts/smoke-finder-integration.sh`를 추가한다.
  - strict bash (`set -euo pipefail`) 사용
  - `--version <version>` 기본값 또는 positional version 처리
  - `--app <path>`로 기존 Release package staging app을 입력받는 옵션 검토
  - `--skip-package`로 이미 생성된 app을 재사용하는 옵션 검토
  - bundle 정합성 확인
  - `$HOME/Applications/Alhangeul.app` 설치와 registration
  - `pluginkit -mAvvv` 확인
  - `qlmanage -r`, `qlmanage -r cache`
  - HWP/HWPX thumbnail smoke
  - output directory와 진단 명령 출력
- `build_run_guide.md`의 Finder 통합 확인 섹션을 helper script 중심으로 정리하고, 수동 명령 흐름은 진단용으로 유지한다.
- `release_distribution_guide.md`의 release pipeline smoke 기준을 helper script 또는 새 표준 명령과 연결한다.
- `finder_integration_validation_pitfalls.md`의 현재 product name과 identifier를 `Alhangeul` 기준으로 보정한다.
- README는 필요 시 Finder extension 등록 검증 진입점만 짧게 보강한다.
- 과거 보고서 파일은 수정하지 않는다.
- Stage 3 보고서에 변경 파일, helper script 사용법, preview 수동 확인 한계를 기록한다.

### 예상 변경 파일

- `scripts/smoke-finder-integration.sh`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/troubleshootings/finder_integration_validation_pitfalls.md`
- `README.md` (필요 시)
- `mydocs/working/task_m016_151_stage3.md`

### 검증

```bash
git status --short --branch
bash -n scripts/package-release.sh scripts/smoke-finder-integration.sh
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
rg -n "smoke-finder-integration|Alhangeul.app|AlhangeulPreview.appex|AlhangeulThumbnail.appex|com\\.postmelee\\.alhangeul|qlmanage -t|qlmanage -p|pluginkit|lsregister|수동 확인" \
  README.md \
  mydocs/manual/build_run_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/troubleshootings/finder_integration_validation_pitfalls.md \
  scripts/smoke-finder-integration.sh
git diff --check
```

### 완료 기준

- 설치본 smoke gate가 문서와 helper script 중복 없이 연결된다.
- 현재 product name과 bundle identifier 기준이 운영 문서에 반영된다.
- `qlmanage -t` 자동 gate와 `qlmanage -p` 수동 확인의 경계가 명확하다.
- helper script가 syntax check를 통과한다.

### 커밋 메시지

```text
Task #151 Stage 3: Finder smoke gate 문서와 스크립트 보강
```

## Stage 4. 설치본 smoke gate 리허설

### 목표

- Release package staging app을 실제 설치 경로에 배치하고 Stage 3 gate가 작동하는지 확인한다.
- 자동 thumbnail smoke와 preview 수동 확인 가능성을 별도 결과로 기록한다.

### 작업

- `./scripts/package-release.sh 0.1.0`으로 Release package를 생성한다.
- `build.noindex/release/Alhangeul.app`의 app/appex 포함과 codesign verify를 확인한다.
- `scripts/smoke-finder-integration.sh` 또는 Stage 3에서 확정한 명령으로 `$HOME/Applications/Alhangeul.app` 설치본 smoke를 수행한다.
- `pluginkit -mAvvv` 결과에서 Preview/Thumbnail extension 등록을 확인한다.
- `qlmanage -t -x`로 HWP/HWPX thumbnail output을 생성한다.
- 가능하면 `qlmanage -p` 또는 Finder Space로 preview를 수동 확인하고, 자동화 한계와 관찰 결과를 기록한다.
- 실패 시 `qlmanage` stderr, `pluginkit`, `lsregister`, `codesign`, `plutil`, log collection 후보를 단계 보고서에 남긴다.
- 이전 이름 설치본이 충돌 후보로 보이면 삭제하지 않고 경로와 증거를 보고한다.

### 예상 변경 파일

- `mydocs/working/task_m016_151_stage4.md`

### 검증

```bash
git status --short --branch
./scripts/package-release.sh 0.1.0
test -d build.noindex/release/Alhangeul.app
test -d build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
test -d build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
git diff --check
```

수동 preview 확인 후보:

```bash
qlmanage -p samples/basic/KTX.hwp
qlmanage -p samples/hwpx/hwpx-01.hwpx
```

### 완료 기준

- Release package staging app이 생성되고 app/appex/codesign 정합성이 확인된다.
- `$HOME/Applications/Alhangeul.app` 설치본에서 PlugInKit 등록이 확인된다.
- 대표 HWP/HWPX sample의 thumbnail smoke가 통과하거나 실패 원인이 분리되어 기록된다.
- preview 수동 확인 결과 또는 자동화 한계가 Stage 4 보고서에 남는다.

### 커밋 메시지

```text
Task #151 Stage 4: 설치본 smoke gate 리허설
```

## Stage 5. 최종 보고와 release gate 연결

### 목표

- #151 결과를 최종 보고서로 정리하고 v0.1 release gate와 #146 known limitations에 넘길 항목을 명확히 한다.

### 작업

- 최종 결과보고서에 설치본 smoke gate의 자동/수동 기준을 정리한다.
- helper script 사용법과 pass/fail 조건을 요약한다.
- 대표 HWP/HWPX thumbnail smoke 결과와 preview 수동 확인 결과를 정리한다.
- 실패 시 로그 수집 경로와 이전 설치본 충돌 처리 원칙을 정리한다.
- public release 전에 남은 항목을 분리한다.
  - Developer ID signing/notarization 이후 public DMG 기준 Gatekeeper 검증
  - #146 렌더 경로 한계 문서화
  - release note에 넣을 smoke 결과 또는 known limitation
- `mydocs/orders/20260508.md`의 #151 상태를 완료로 갱신한다.

### 예상 변경 파일

- `mydocs/report/task_m016_151_report.md`
- `mydocs/orders/20260508.md`

### 검증

```bash
git status --short --branch
rg -n "#151|Quick Look|Thumbnail|smoke-finder-integration|qlmanage|pluginkit|수동 확인|known limitation|완료" \
  mydocs/report/task_m016_151_report.md mydocs/orders/20260508.md
git diff --check
```

### 완료 기준

- 최종 보고서가 smoke gate 절차, 실행 결과, 자동화 한계, 후속 release gate를 포함한다.
- 오늘할일 상태가 완료로 갱신된다.
- PR 생성 전 남은 미커밋 변경이 없다.

### 커밋 메시지

```text
Task #151 Stage 5: 설치본 smoke gate 최종 보고
```

## 승인 요청 사항

1. 위 5단계 구현계획 승인
2. Stage 3에서 `scripts/smoke-finder-integration.sh` helper script를 추가하는 방향 승인
3. Stage 4에서 `$HOME/Applications/Alhangeul.app` 표준 설치 경로를 사용해 smoke 리허설을 수행하는 방향 승인
4. 다음 단계: 승인 후 Stage 1 `현행 Finder 통합 smoke 절차 inventory` 진행
