# Task M019 #219 Stage 1 완료 보고서

## 단계 목적

최신 `devel-webview` 기준 release script, release workflows, signing/notarization 문서, #188/#227 기록을 대조해 #219의 artifact signing preflight 구현 기준을 확정한다.

확인 기준 커밋: `984cd9cd328b51e618aa3eabe738b7260f5ff2d2` (`origin/devel-webview`, PR #231 merge commit)

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m019_219_stage1.md` | signing/notarization preflight inventory와 Stage 2 구현 기준 기록 |

이번 단계에서 release script, workflow, manual 본문은 수정하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 신규 단계 보고서만 추가했다.
- 기존 source, workflow, manual 문서 본문은 변경하지 않았다.
- public release, notarization, signing, GitHub Release 게시, Pages/appcast 갱신은 실행하지 않았다.

## 최신 기준 확인

현재 `local/task219`는 `origin/devel-webview`에서 분기했고, 작업 시작 전 확인한 `origin/devel-webview`는 PR #231 merge commit `984cd9cd328b51e618aa3eabe738b7260f5ff2d2`였다.

PR #231의 범위는 Rust bridge staticlib 검증 정책, PR CI, release workflow의 source/header/ABI gate 정렬이다. #219가 요구하는 app bundle signing/notarization preflight, Sparkle component discovery, timestamp/runtime/entitlement 검증은 PR #231에서 해결되지 않았다.

## 현재 release script inventory

| 위치 | 현재 동작 | #219 관점 판단 |
|------|-----------|----------------|
| `run_preflight` | tool, signing identity, notary profile, clean worktree, source version 검증 | source/environment preflight이며 app bundle 내부 서명 상태는 확인하지 않음 |
| `build_app` | Developer ID identity가 있으면 Xcode Release build에 Manual signing과 hardened runtime build setting 적용 | build setting만으로 nested component 최종 서명 상태를 보장하지 않음 |
| `codesign_developer_id` | `--options runtime`, `--timestamp`, entitlements 또는 기존 entitlement 보존으로 서명 | 서명 수행 helper이며 결과 검증 helper는 아님 |
| `sign_sparkle_components_for_notarization` | `Sparkle.framework/Versions/B`를 직접 보고 XPC/Updater/Autoupdate가 있으면 서명 | `Versions/B` 고정, component 누락 시 조용히 skip 가능 |
| `sign_app_extension_for_notarization` | appex가 있으면 release entitlements를 expand 후 재서명 | appex 누락 시 조용히 return |
| `verify_universal_app` | app/extension executable의 `arm64 + x86_64` 검증 | architecture 검증이며 signing 검증 아님 |
| `verify_app_signature` | app `codesign --verify --deep --strict`, appex 개별 `codesign --verify --strict` | signer, Team ID, timestamp, hardened runtime, `get-task-allow` 부재를 명시 검증하지 않음 |
| `notarize_and_staple_app` | public mode에서 app notary zip 제출 후 staple | 현재 signing 문제를 notary submit 이후에 발견할 수 있음 |

현재 main flow는 다음 순서다.

```text
run_preflight
-> reset_output
-> build_rust_bridge
-> check_shared_code
-> generate_project
-> build_app
-> sign_release_app_for_notarization
-> verify_universal_app
-> verify_app_signature
-> notarize_and_staple_app
```

#219의 artifact signing preflight는 `sign_release_app_for_notarization` 이후, `notarize_and_staple_app` 이전에 들어가야 한다. 기존 `verify_app_signature`를 확장하거나 새 `verify_release_signing_preflight`를 추가하되, Stage 2/3에서는 이름과 책임을 명확히 분리한다.

## workflow inventory

| Workflow | 관련 step | 현재 동작 | #219 영향 |
|----------|-----------|-----------|-----------|
| `release-publish.yml` | `Build signed and notarized DMG` | `./scripts/release.sh "$VERSION"` 실행 | public path이므로 artifact signing preflight가 반드시 실행되어야 함 |
| `release-publish.yml` | `Record Rust bridge lock policy` | #227 정책에 따라 staticlib hash skip 설명 | #219 summary는 아직 없음 |
| `release-rehearsal.yml` | `Build rehearsal DMG` | `./scripts/release.sh --skip-notarize "$VERSION"` 실행 | 기본 rehearsal은 unsigned/notarization skip이므로 public signing preflight 대상이 아님 |
| `release-rehearsal.yml` | `Record Rust bridge lock policy` | #227 정책에 따라 staticlib hash skip 설명 | signing preflight skip/실행 조건 설명 없음 |

workflow 자체에는 별도 signing validator step이 없다. 따라서 Stage 2/3에서 `scripts/release.sh`에 preflight hook을 넣으면 release-publish는 자동으로 보호된다. Stage 4에서는 workflow summary가 public path와 rehearsal path의 signing preflight 실행/skip 조건을 설명하도록 보강한다.

## #188 실패 기록에서 끌어온 요구사항

#188 Stage 4에서 public release workflow는 다음 계열의 문제를 notary submit 이후에 확인했다.

| 실패 지점 | 원인 | #219에서 선행 검출할 조건 |
|-----------|------|---------------------------|
| app notarization | Sparkle nested XPC/Autoupdate가 ad-hoc signature와 timestamp 없음 | Sparkle framework/nested executable의 Developer ID signer와 secure timestamp |
| app notarization | Quick Look/Thumbnail extension에 `get-task-allow`와 timestamp 없음 | appex entitlement의 `get-task-allow` 부재와 secure timestamp |

따라서 Stage 3 validator는 단순 `codesign --verify` 통과 여부가 아니라 다음 상태를 별도 항목으로 검증해야 한다.

- Developer ID Application signer
- Team ID `XH6JHKYXV8`
- secure timestamp 존재
- hardened runtime option 존재
- `com.apple.security.get-task-allow`가 true가 아님
- required nested component 존재

## 검증 대상 component 정책

### Host app

| 항목 | 기준 |
|------|------|
| path | `build.noindex/release/Alhangeul.app` |
| bundle id | `com.postmelee.alhangeul` |
| signer | `ALHANGEUL_DEVELOPER_ID_APPLICATION` |
| Team ID | `XH6JHKYXV8` |
| runtime | hardened runtime 필요 |
| timestamp | secure timestamp 필요 |
| entitlement | sandbox, user-selected read-write, network client, print, Sparkle mach lookup 유지. `get-task-allow` true 금지 |

### Quick Look extension

| 항목 | 기준 |
|------|------|
| path | `Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex` |
| bundle id | `com.postmelee.alhangeul.QLExtension` |
| signer | `ALHANGEUL_DEVELOPER_ID_APPLICATION` |
| Team ID | `XH6JHKYXV8` |
| runtime | hardened runtime 필요 |
| timestamp | secure timestamp 필요 |
| entitlement | sandbox + user-selected read-only 유지. `get-task-allow` true 금지 |

### Thumbnail extension

| 항목 | 기준 |
|------|------|
| path | `Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex` |
| bundle id | `com.postmelee.alhangeul.ThumbnailExtension` |
| signer | `ALHANGEUL_DEVELOPER_ID_APPLICATION` |
| Team ID | `XH6JHKYXV8` |
| runtime | hardened runtime 필요 |
| timestamp | secure timestamp 필요 |
| entitlement | sandbox + user-selected read-only 유지. `get-task-allow` true 금지 |

### Sparkle framework와 nested executable

| 항목 | 기준 |
|------|------|
| framework | `Alhangeul.app/Contents/Frameworks/Sparkle.framework` |
| version dir | `Versions/Current` 우선, 없으면 `Versions/*` discovery |
| required nested components | `XPCServices/Downloader.xpc`, `XPCServices/Installer.xpc`, `Updater.app`, `Autoupdate` |
| signer | `ALHANGEUL_DEVELOPER_ID_APPLICATION` |
| Team ID | `XH6JHKYXV8` |
| runtime | hardened runtime 필요 |
| timestamp | secure timestamp 필요 |
| entitlement | Sparkle-specific entitlement를 강제하지 않음. `get-task-allow` true 금지 |

Stage 2에서는 signing path와 validation path가 같은 Sparkle component resolver를 쓰도록 한다. public notarization path에서 framework 또는 required nested component가 없으면 skip하지 않고 실패한다.

## 실행 조건 결정

| 모드 | 조건 | artifact signing preflight |
|------|------|----------------------------|
| public release | `SKIP_NOTARIZE=0`, `ALHANGEUL_DEVELOPER_ID_APPLICATION` 필수 | 반드시 실행 |
| signed rehearsal | `SKIP_NOTARIZE=1`, `ALHANGEUL_DEVELOPER_ID_APPLICATION` 제공 | 실행. notarization은 하지 않지만 signing prerequisite 회귀를 조기 확인 |
| unsigned rehearsal | `SKIP_NOTARIZE=1`, `ALHANGEUL_DEVELOPER_ID_APPLICATION` 없음 | 명시 로그 후 skip. public release signing 보증으로 기록하지 않음 |

이 기준을 적용하면 release-publish는 notary submit 전 fail-fast를 얻고, release-rehearsal은 기본 unsigned smoke를 유지한다. 필요 시 작업지시자가 Developer ID identity를 제공한 rehearsal에서 같은 validator를 실행할 수 있다.

## Stage 2 구현 기준

Stage 2에서는 source 변경을 Sparkle resolver와 signing path에 한정한다.

- `Sparkle.framework` 존재 확인 helper 추가
- `Versions/Current` symlink/dir 해석 helper 추가
- `Versions/Current`가 없거나 유효하지 않으면 `Versions/*`에서 required component를 갖춘 directory 탐색
- required component 목록을 배열 또는 helper로 중앙화
- `sign_sparkle_components_for_notarization`이 새 resolver를 사용
- public/signed path에서 required component 누락 시 `fail`
- unsigned path에서는 기존처럼 Sparkle signing helper 자체가 실행되지 않음

Stage 2는 validator parsing을 도입하지 않는다. signer/timestamp/runtime/entitlement 검증은 Stage 3으로 분리한다.

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `git status -sb` | OK | `local/task219`, `origin/devel-webview` 대비 ahead 2 |
| `rg -n "run_preflight\|sign_sparkle_components_for_notarization\|verify_app_signature\|notarize_and_staple_app\|Sparkle.framework/Versions\|ALHANGEUL_DEVELOPER_ID\|skip-notarize" ...` | OK | release script/workflow/manual 현황 확인 |
| `sed -n '1,220p' mydocs/manual/release_signing_notarization_guide.md` | OK | 현재 manual은 대표 수동 검증 위주 |
| `sed -n '1,260p' mydocs/manual/release_packaging_dmg_guide.md` | OK | public/rehearsal 산출물 계층 확인 |
| `sed -n '120,190p' .github/workflows/release-rehearsal.yml` | OK | rehearsal은 `--skip-notarize` 실행 |
| `sed -n '232,270p' .github/workflows/release-publish.yml` | OK | publish는 `./scripts/release.sh "$VERSION"` 실행 |
| `sed -n '72,96p' mydocs/working/task_m018_188_stage4.md` | OK | #188 signing/notary 실패 원인 확인 |
| `rg -n "Team ID\|XH6JHKYXV8\|ALHANGEUL_DEVELOPER_ID\|APPLE_TEAM_ID\|Developer ID" ...` | OK | Team ID와 signing identity 위치 확인 |
| `rg -n "PRODUCT_BUNDLE_IDENTIFIER\|com\\.postmelee\\.alhangeul\|ENABLE_HARDENED_RUNTIME\|entitlements" project.yml Sources` | OK | bundle id와 entitlements source 확인 |
| `plutil -p Sources/*/*.entitlements` | OK | Host/extension entitlement 기준 확인 |

## 실행하지 않은 항목

- `scripts/release.sh` 수정
- workflow 수정
- manual 수정
- `./scripts/release.sh --skip-notarize` 실행
- Developer ID signing
- notarization submit/wait
- public release 관련 외부 작업

## 잔여 위험

- `codesign --display --verbose=4` 출력 parsing은 macOS/Xcode 버전에 따라 달라질 수 있으므로 Stage 3에서 가능한 한 단순하고 실패 로그가 명확한 방식으로 구현해야 한다.
- Sparkle future version에서 nested component 구성이 바뀌면 required component 정책을 갱신해야 한다. 이번 작업은 현재 Sparkle bundle 구조에서 notarization prerequisite을 fail-fast로 검증하는 범위다.
- signed rehearsal은 Developer ID identity가 있는 환경에서만 검증 가능하다. GitHub `release-rehearsal.yml` 기본 path는 unsigned rehearsal이므로 artifact signing preflight 실행을 보장하지 않는다.

## 다음 단계

Stage 2 승인 후 다음을 수행한다.

1. `scripts/release.sh`에 Sparkle framework version directory resolver를 추가한다.
2. `sign_sparkle_components_for_notarization`에서 `Versions/B` 고정 경로를 제거한다.
3. required Sparkle nested component 누락을 public/signed path에서 `fail`로 처리한다.
4. Stage 2 완료보고서와 함께 커밋한다.

## 승인 요청

1. Stage 1 결과 승인
2. Stage 2 `Sparkle component discovery와 signing path 보강` 진입 승인
