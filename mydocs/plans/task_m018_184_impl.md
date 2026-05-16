# Task M018 #184 구현계획서

수행계획서: `mydocs/plans/task_m018_184.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #184 DMG 설치 창 안내와 첫 실행 안내 개선
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task184`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 선행 상태: #183은 `devel-webview`에 merge된 상태
- 주 대상: `scripts/release.sh`의 DMG layout 생성 경로와 release distribution manual
- 목표: rehearsal/public DMG에서 사용자가 설치 방법과 첫 실행 필요성을 DMG 창 안에서 바로 이해할 수 있게 한다.

## 구현 원칙

- public release 실행, GitHub Release 게시, appcast/Cask 갱신은 수행하지 않는다.
- release script의 signing, notarization, staple, Gatekeeper, checksum 순서는 유지한다.
- rehearsal DMG와 public DMG는 같은 layout 생성 함수를 공유한다.
- 외부 패키지 의존성은 추가하지 않고 macOS 기본 도구(`hdiutil`, Finder metadata, AppleScript, system utilities) 중심으로 구현한다.
- Finder/AppleScript layout 설정이 불안정하다고 판단되면 DMG 내부 README/안내 이미지와 deterministic staging 구조로 범위를 낮춘다.
- `Alhangeul.app` filesystem bundle name은 유지한다.
- Quick Look/Thumbnail extension 구현과 앱 자동 실행/자동 등록은 변경하지 않는다.
- 문구는 한국어 우선으로 작성하고, 필요한 경우 `Applications`, `Quick Look`, `Thumbnail` 같은 시스템 용어만 짧게 병기한다.
- `project.yml`, Xcode project, Swift/Rust source는 이슈 범위 밖으로 간주한다.

## Stage 1. DMG layout 방식 조사와 기준 확정

### 목표

현재 DMG 생성 구조를 확인하고, #184에서 구현할 layout 방식을 하나로 확정한다.

### 작업

- `scripts/release.sh`의 `create_dmg`, `prepare_paths`, signing/notarization 순서를 다시 확인한다.
- 현재 산출 DMG가 `Alhangeul.app`과 `Applications` symlink만 포함하는 구조인지 확인한다.
- 다음 후보를 비교한다.
  - `.background` 이미지와 Finder icon view metadata
  - DMG 내부 `README` 또는 안내 문서
  - 안내 이미지 파일과 icon 배치 조합
  - AppleScript를 통한 Finder 창 bounds, background, icon position 설정
- release machine에서 요구되는 도구와 실패 모드를 정리한다.
- DMG 창 크기, app icon 위치, Applications 위치, 안내 문구 초안을 확정한다.
- Stage 1 보고서에 선택안, 기각안, 확정 기준을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m018_184_stage1.md`

### 검증

```bash
git status --short --branch
bash -n scripts/release.sh
./scripts/release.sh --help
rg -n "create_dmg|hdiutil|Applications|DMG_STAGING_DIR|DMG_OUTPUT" scripts/release.sh mydocs/manual/release_distribution_guide.md
git diff --check
```

### 완료 기준

- Stage 2에서 구현할 DMG layout 방식이 하나로 확정된다.
- 안내 문구 초안과 Finder 창 배치 기준이 기록된다.
- public release 실행을 건드리지 않는 검증 범위가 명확해진다.

### 커밋 메시지

```text
Task #184 Stage 1: DMG layout 방식 확정
```

## Stage 2. DMG layout asset과 release script 구현

### 목표

Stage 1에서 확정한 방식으로 release script가 안내가 포함된 DMG layout을 만들도록 구현한다.

### 작업

- `scripts/release.sh`에 DMG layout staging helper를 추가한다.
- 필요한 경우 background/안내 asset 생성 또는 정적 asset을 추가한다.
- `Alhangeul.app`과 `Applications` symlink 위치를 명시적으로 설정한다.
- 설치 안내와 첫 실행 안내가 DMG 창 안에서 보이도록 배치한다.
- rehearsal/public mode가 동일 layout path를 통과하게 유지한다.
- 기존 signing, notarization, staple, Gatekeeper, checksum 단계와 충돌하지 않도록 `create_dmg` 전후 순서를 보존한다.
- Stage 2 보고서에 변경 파일, layout 값, public release 영향 범위를 기록한다.

### 예상 변경 파일

- `scripts/release.sh`
- `assets/` 또는 `scripts/` 하위 DMG layout asset (필요 시)
- `mydocs/working/task_m018_184_stage2.md`

### 검증

```bash
git status --short --branch
bash -n scripts/release.sh
./scripts/release.sh --help
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.1
git diff --check
```

`0.1.1`이 plist version과 맞지 않아 fail-fast version guard에서 막히면, 현재 source version으로 같은 credential guard를 반복하고 Stage 2 보고서에 조정 이유를 기록한다.

### 완료 기준

- release script syntax와 help 출력이 정상이다.
- credential 누락 public mode가 build 전에 fail-fast 한다.
- layout 구현이 public release signing/notarization 순서를 바꾸지 않는다.
- source 변경 범위가 `scripts/release.sh`와 필요한 asset에 한정된다.

### 커밋 메시지

```text
Task #184 Stage 2: DMG 설치 안내 layout 구현
```

## Stage 3. Rehearsal DMG 생성과 mounted layout smoke

### 목표

`--skip-notarize` rehearsal DMG를 실제 생성하고 mount해 DMG 창 안내가 사용자가 보는 형태로 표시되는지 확인한다.

### 작업

- source plist version을 확인하고 rehearsal version 인자를 결정한다.
- `./scripts/release.sh --skip-notarize <version>`으로 rehearsal DMG를 생성한다.
- `hdiutil verify`와 checksum 검증을 수행한다.
- DMG를 attach하고 mounted volume 내부 구조를 확인한다.
- 가능하면 Finder 창을 열어 다음 항목을 수동 smoke한다.
  - `Alhangeul.app`이 보인다.
  - `Applications` target이 보인다.
  - 앱을 Applications로 드래그하라는 안내가 보인다.
  - 설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail이 활성화된다는 안내가 보인다.
  - 창 크기, 아이콘, 안내 문구가 겹치지 않는다.
- Finder GUI 확인이 sandbox/권한 문제로 막히면 mounted volume 파일 구조와 metadata 확인 결과를 남기고 작업지시자 수동 확인 항목으로 분리한다.
- Stage 3 보고서에 명령, 산출물 경로, smoke 결과, 미수행 한계를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m018_184_stage3.md`

### 검증

```bash
git status --short --branch
plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
./scripts/release.sh --skip-notarize <version>
hdiutil verify build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg
shasum -a 256 -c build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg.sha256
hdiutil attach build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg
git diff --check
```

### 완료 기준

- rehearsal DMG 생성, verify, checksum 검증이 통과한다.
- mounted DMG에서 app, Applications target, 설치 안내, 첫 실행 안내를 확인한다.
- 확인 불가한 GUI 항목이 있으면 이유와 #188 handoff 항목이 명확히 남는다.

### 커밋 메시지

```text
Task #184 Stage 3: rehearsal DMG layout smoke 검증
```

## Stage 4. Public release 호환성과 배포 가이드 보강

### 목표

실제 public release를 실행하지 않고 public mode와 공유되는 코드 경로를 검토하고, 배포 가이드에 DMG layout smoke 기준을 추가한다.

### 작업

- public mode에서 layout 생성 후 signing/notarization/staple/checksum 흐름이 유지되는지 코드 순서를 검토한다.
- credential guard가 build 전 fail-fast 하는지 확인한다.
- `release_distribution_guide.md`에 DMG layout smoke 기준을 추가한다.
- #188 public release 실행 시 반복할 확인 항목을 문서화한다.
- 안내 문구가 release note/README/Homebrew caveats의 설치 안내와 충돌하지 않는지 확인한다.
- Stage 4 보고서에 public release 미실행 범위와 #188 handoff를 기록한다.

### 예상 변경 파일

- `mydocs/manual/release_distribution_guide.md`
- `mydocs/working/task_m018_184_stage4.md`

### 검증

```bash
git status --short --branch
bash -n scripts/release.sh
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh <version>
rg -n "DMG layout|설치 창|첫 실행|Quick Look|Thumbnail|Applications" mydocs/manual/release_distribution_guide.md README.md docs Casks
git diff --check
```

### 완료 기준

- 배포 가이드에 DMG layout smoke 기준이 추가된다.
- public signed/notarized DMG에서 반복할 검증 항목이 분리되어 있다.
- release communication 문서와 안내 문구 사이의 모순이 없다.

### 커밋 메시지

```text
Task #184 Stage 4: DMG layout smoke 기준 문서화
```

## Stage 5. 최종 검증과 #188 handoff 정리

### 목표

전체 변경을 재검증하고, #188 `v0.1.1` patch release 실행에서 반복해야 할 항목을 최종 보고서에 남긴다.

### 작업

- Stage 2~4 변경 파일의 최종 diff를 점검한다.
- release script syntax, help, credential guard, rehearsal DMG smoke 결과를 정리한다.
- 필요하면 rehearsal DMG를 한 번 더 생성해 layout 회귀가 없는지 확인한다.
- 오늘할일 상태를 완료로 갱신한다.
- 최종 결과보고서에 변경 내용, 검증 결과, 미수행 public release 항목, #188 handoff를 기록한다.
- PR 게시 전 미커밋 변경이 없도록 정리한다.

### 예상 변경 파일

- `mydocs/orders/20260509.md`
- `mydocs/report/task_m018_184_report.md`

### 검증

```bash
git status --short --branch
bash -n scripts/release.sh
./scripts/release.sh --help
env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh <version>
git diff --check
```

필요 시 반복:

```bash
./scripts/release.sh --skip-notarize <version>
hdiutil verify build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg
shasum -a 256 -c build.noindex/release/alhangeul-macos-<version>-rehearsal.dmg.sha256
```

### 완료 기준

- 최종 보고서가 Stage별 결과와 #188 handoff를 포함한다.
- 오늘할일이 완료 상태로 갱신된다.
- public release 실행 없이 가능한 release script 검증이 통과한다.
- PR 게시 준비 전 작업트리가 정리된다.

### 커밋 메시지

```text
Task #184 Stage 5 + 최종 보고서: DMG 설치 안내 개선 완료
```

## 승인 요청 사항

1. 위 5단계 구현계획 승인
2. Stage 1에서 layout 방식을 확정한 뒤 Stage 2에서 release script와 필요한 asset만 수정하는 진행 승인
3. Stage 3에서 rehearsal DMG 생성과 mounted layout smoke를 수행하는 승인
4. public signed/notarized DMG 생성과 release 게시를 #188 범위로 남기는 승인
5. 다음 단계: 승인 후 Stage 1 진행
