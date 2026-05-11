# Task M019 #219 구현계획서

## 목적

수행계획서에서 승인된 방향에 따라 release artifact signing/notarization preflight를 구현한다.

본 구현은 public release path에서 `Alhangeul.app`을 app notarization에 제출하기 전에 Host app, Quick Look extension, Thumbnail extension, Sparkle framework와 nested executable의 서명 전제 조건을 명시 검증한다. 목표는 #188 Stage 4에서 notary submit 이후에야 드러났던 Sparkle timestamp 누락과 extension debug entitlement 문제를 app bundle 생성 직후 fail-fast로 잡는 것이다.

## 승인된 기준

- #219는 #225의 v0.1.2 release 실행 전에 끝내는 선행 작업으로 둔다.
- source/environment preflight와 artifact signing preflight를 분리한다.
- artifact signing preflight는 `build_app`와 `sign_release_app_for_notarization` 이후, `notarize_and_staple_app` 전에 실행한다.
- Sparkle component path는 `Sparkle.framework/Versions/B` 고정이 아니라 `Versions/Current` 우선, discovery fallback 방식으로 찾는다.
- public notarization path에서 required Sparkle component가 없거나 잘못 서명되면 skip하지 않고 실패한다.
- unsigned `--skip-notarize` rehearsal은 public notarization prerequisite 검증 대상이 아님을 명확히 로그로 남긴다. Developer ID identity가 제공된 rehearsal에서 validator를 실행할지는 Stage 1 inventory에서 최종 확정한다.
- public release, GitHub Release 게시, Pages/appcast 갱신, Homebrew Cask 반영은 이번 작업에서 수행하지 않는다.

## 전체 단계

### Stage 1: signing/notarization preflight inventory

목표:

- 최신 `devel-webview` 기준 release script와 release workflows의 현재 signing/notarization hook을 inventory로 정리한다.
- 검증 대상 component 목록과 expected policy를 확정한다.
- `--skip-notarize` rehearsal, Developer ID가 있는 rehearsal, public release path의 validator 실행 조건을 결정한다.

예상 변경 파일:

- `mydocs/working/task_m019_219_stage1.md`

검증:

```bash
rg -n "run_preflight|sign_sparkle_components_for_notarization|verify_app_signature|notarize_and_staple_app|Sparkle.framework/Versions|ALHANGEUL_DEVELOPER_ID|skip-notarize" \
  scripts/release.sh .github/workflows/release-publish.yml .github/workflows/release-rehearsal.yml mydocs/manual
git diff --check -- mydocs/working/task_m019_219_stage1.md
```

커밋:

```text
Task #219 Stage 1: signing preflight inventory 정리
```

승인 게이트:

- Stage 1 완료보고서 승인 후 Stage 2 진행

### Stage 2: Sparkle component discovery와 signing path 보강

목표:

- `scripts/release.sh`에서 Sparkle framework version directory를 `Versions/Current` 우선으로 해석하고, 없으면 `Versions/*` discovery로 찾는 helper를 추가한다.
- Sparkle nested component 목록을 한 곳에서 정의해 signing path와 validation path가 같은 resolution을 쓰도록 한다.
- public notarization path에서 Sparkle framework나 required nested component가 누락되면 명확한 오류로 실패하게 한다.

예상 변경 파일:

- `scripts/release.sh`
- `mydocs/working/task_m019_219_stage2.md`

검증:

```bash
bash -n scripts/release.sh
rg -n "resolve_sparkle|Sparkle.framework/Versions|XPCServices|Updater.app|Autoupdate|Versions/Current" scripts/release.sh
git diff --check -- scripts/release.sh mydocs/working/task_m019_219_stage2.md
```

커밋:

```text
Task #219 Stage 2: Sparkle component discovery 보강
```

승인 게이트:

- Stage 2 완료보고서 승인 후 Stage 3 진행

### Stage 3: artifact signing preflight validator 구현

목표:

- app notarization 제출 전 실행되는 `verify_release_signing_preflight` 계열 함수를 추가한다.
- Host app, Quick Look extension, Thumbnail extension, Sparkle framework, Sparkle XPCServices, `Updater.app`, `Autoupdate`에 대해 개별 `codesign --verify --strict`를 수행한다.
- `codesign --display --verbose=4` 출력 또는 안정적인 보조 명령을 사용해 Developer ID Application signer, Team ID, secure timestamp, hardened runtime을 확인한다.
- entitlement 추출 결과에서 `com.apple.security.get-task-allow`가 true이면 실패시킨다.
- 실패 로그는 component label, path, 기대 조건, 확인된 상태를 보여준다.

예상 변경 파일:

- `scripts/release.sh`
- 필요 시 `scripts/ci/` 또는 `scripts/` 하위 helper
- `mydocs/working/task_m019_219_stage3.md`

검증:

```bash
bash -n scripts/release.sh
./scripts/release.sh --help
rg -n "verify_release_signing_preflight|codesign --display|entitlements|get-task-allow|hardened runtime|TeamIdentifier|Timestamp" scripts
git diff --check -- scripts mydocs/working/task_m019_219_stage3.md
```

환경이 허용되면 추가 검증:

```bash
./scripts/release.sh --skip-notarize 0.1.2
```

Developer ID identity가 없는 환경에서 실패하는 검증은 stage 보고서에 별도 기록하고, 가능한 정적 검증과 unsigned rehearsal 결과를 분리한다.

커밋:

```text
Task #219 Stage 3: release signing preflight validator 추가
```

승인 게이트:

- Stage 3 완료보고서 승인 후 Stage 4 진행

### Stage 4: workflow와 release 문서 연결

목표:

- `release-publish.yml`과 `release-rehearsal.yml` summary가 signing preflight 실행/skip 조건을 설명하도록 보강한다.
- release signing/notarization, packaging, distribution 문서에 preflight gate의 위치와 실패 기준을 기록한다.
- #225 작업자가 v0.1.2 release 실행 전 어떤 preflight가 통과해야 하는지 확인할 수 있게 문서화한다.

예상 변경 파일:

- `.github/workflows/release-publish.yml`
- `.github/workflows/release-rehearsal.yml`
- `mydocs/manual/release_signing_notarization_guide.md`
- `mydocs/manual/release_packaging_dmg_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/working/task_m019_219_stage4.md`

검증:

```bash
rg -n "signing preflight|notarization preflight|Developer ID|timestamp|get-task-allow|Sparkle.framework|release.sh" \
  .github/workflows mydocs/manual
git diff --check -- .github/workflows mydocs/manual mydocs/working/task_m019_219_stage4.md
```

커밋:

```text
Task #219 Stage 4: release preflight 문서와 workflow 정리
```

승인 게이트:

- Stage 4 완료보고서 승인 후 Stage 5 진행

### Stage 5: 통합 검증과 최종 보고

목표:

- shell syntax, release helper, rehearsal path, 문서 검색, diff check를 실행한다.
- 가능하면 unsigned rehearsal DMG를 생성해 preflight skip/실행 로그와 기존 release flow 손상 여부를 확인한다.
- 최종 보고서에 #219 완료 기준 충족 여부, public release 미실행 범위, #225 전 선행 조건을 정리한다.
- 오늘할일 상태를 완료로 갱신한다.

예상 변경 파일:

- `mydocs/report/task_m019_219_report.md`
- `mydocs/orders/20260511.md`

검증:

```bash
bash -n scripts/release.sh
bash -n scripts/ci/*.sh
./scripts/release.sh --help
./scripts/release.sh --skip-notarize 0.1.2
rg -n "preflight|notarization|Developer ID|timestamp|get-task-allow|Sparkle.framework/Versions|hardened runtime|Versions/Current" \
  scripts .github/workflows mydocs/manual
git diff --check
```

Developer ID identity와 notary profile이 있는 환경에서는 추가로 public publish 없이 local signing path에서 artifact signing preflight가 실제로 실행되는지 확인한다. public GitHub Release와 stable appcast는 실행하지 않는다.

커밋:

```text
Task #219 Stage 5 + 최종 보고서: release preflight 검증 정리
```

승인 게이트:

- 최종 보고서 승인 후 `task-final-report` 절차로 PR 게시 진행

## PR close 전략

PR 본문에는 `Closes #219`를 명시한다.

#225는 이번 PR에서 close하지 않는다. 대신 PR 본문과 최종 보고서에 "#225 release 실행 전에 #219 preflight gate가 선행 완료됐다"는 handoff를 남긴다.

이슈 close는 PR merge 전 별도로 수행하지 않는다. merge 전에는 PR closing keyword 또는 최종 보고서 승인 흐름으로만 연결한다.

## 리스크와 보정 기준

- `codesign --display` 출력 parsing이 취약하면 Stage 3에서 helper 함수를 줄이고 `codesign --verify`, `spctl`, `plutil` 등 더 안정적인 명령 조합으로 보정한다.
- Sparkle future version에서 component 구조가 바뀌면 discovery 기준이 과도하게 엄격할 수 있다. 단, public notarization path에서 필요한 현재 component 누락을 skip하지 않는 기준은 유지한다.
- `--skip-notarize` rehearsal에서 Developer ID identity가 없으면 artifact signing preflight를 완전히 재현할 수 없다. 이 경우 public release path에서 실행될 hook 위치와 정적 검증을 보고서에 명확히 기록한다.
- `./scripts/release.sh --skip-notarize 0.1.2`가 source version mismatch로 실패할 수 있다. 그 경우 현재 source version에 맞는 명령으로 대체하거나, 실패가 validator 변경과 무관함을 stage 보고서에 분리한다.
- workflow YAML 변경이 실제 GitHub Actions 실행 없이는 완전 검증되지 않는다. 로컬에서는 문법/검색/스크립트 경로 확인까지 수행하고, PR CI와 release workflow dry path는 PR에서 확인한다.

## 승인 요청 사항

이 구현계획서 승인 후 Stage 1 signing/notarization preflight inventory를 시작한다.
