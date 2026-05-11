# Task M019 #219 최종 보고서

## 결론

#219는 최신 `devel-webview` 기준으로 #225 전에 완료하는 것이 맞고, 이번 작업 범위의 signing/notarization preflight는 구현 완료로 판단한다.

최신 기준 확인 시점에는 PR #231 merge commit `984cd9cd328b51e618aa3eabe738b7260f5ff2d2`가 `devel-webview`에 포함되어 있었다. 이후 작업 중 PR #232(`#218`)가 `devel-webview`에 추가 merge되어 `local/task219`에 병합했다.

이번 작업으로 `scripts/release.sh` public release path는 app notarization submit 전에 Host app, Quick Look extension, Thumbnail extension, Sparkle framework와 Sparkle nested executable을 개별 검증한다. `--skip-notarize` rehearsal은 unsigned 기본 모드에서 preflight skip을 명시 로그로 남기고, Developer ID identity가 주어진 signed rehearsal에서는 같은 preflight를 실행한다.

## 변경 요약

| 영역 | 내용 |
|------|------|
| Sparkle component discovery | `Sparkle.framework/Versions/Current`를 우선 해석하고, 없거나 불완전하면 `Versions/*` discovery로 required component가 있는 version directory를 찾도록 변경 |
| Sparkle required component | `XPCServices/Downloader.xpc`, `XPCServices/Installer.xpc`, `Updater.app`, `Autoupdate`를 signing/validation 공통 required 목록으로 관리 |
| release signing preflight | notarization submit 전 `verify_release_signing_preflight` 추가 |
| 검증 기준 | Developer ID Application authority, Team ID, secure timestamp, hardened runtime, `get-task-allow` 부재, expected bundle identifier, required Sparkle component 존재 확인 |
| workflow summary | `release-publish.yml`, `release-rehearsal.yml`에 signing preflight 실행/skip 정책 기록 |
| 매뉴얼 | signing/notarization, packaging/DMG, distribution 가이드에 preflight gate와 #225 전 확인 기준 기록 |

## 완료 기준 확인

| 기준 | 결과 | 근거 |
|------|------|------|
| #225 release 실행 전에 #219 선행 필요 여부 판단 | OK | #225는 public release 실행 타스크이므로 notary submit 전 fail-fast gate가 먼저 필요함 |
| 최신 `devel-webview` + PR #231 기준 파악 | OK | PR #231 merge commit 포함 기준에서 #219 미해결 확인 후 진행 |
| Sparkle `Versions/B` 고정 제거 | OK | `Versions/Current` 우선 + discovery fallback 적용 |
| Sparkle nested component 누락을 public path에서 실패 처리 | OK | required component resolver가 누락 시 `fail` 처리 |
| app/extension/Sparkle notarization 전 signing preflight 추가 | OK | `sign_release_app_for_notarization` 후, `notarize_and_staple_app` 전 hook 추가 |
| Developer ID, Team ID, timestamp, runtime, debug entitlement 검증 | OK | component별 `codesign --verify --strict`, metadata, entitlement 확인 |
| unsigned rehearsal skip 조건 명시 | OK | identity 없는 `--skip-notarize`에서 `Skipping release signing preflight...` 경고 출력 |
| 문서와 workflow 연결 | OK | release workflow summary와 release manual 갱신 |

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `bash -n scripts/release.sh` | OK | shell syntax 확인 |
| `bash -n scripts/ci/*.sh` | OK | CI helper shell syntax 확인 |
| `./scripts/release.sh --help` | OK | `APPLE_TEAM_ID` help 노출 확인 |
| `rg -n "preflight\|notarization\|Developer ID\|timestamp\|get-task-allow\|Sparkle.framework/Versions\|hardened runtime\|Versions/Current" scripts .github/workflows mydocs/manual` | OK | 코드, workflow, manual 연결 확인 |
| `git diff --check` | OK | whitespace 오류 없음 |
| `ALHANGEUL_BUILD_ROOT=build.noindex/task219-stage5 ./scripts/release.sh --skip-notarize 0.1.1` | 부분 통과 | 네트워크 제한 해제 재시도 후 build/universal/preflight skip 지점까지 통과, DMG Finder layout 단계에서 실패 |

## Rehearsal 상세

첫 실행은 sandbox 네트워크 제한으로 Sparkle package clone이 실패했다.

```text
fatal: unable to access 'https://github.com/sparkle-project/Sparkle/': Could not resolve host: github.com
```

제한 해제 후 같은 명령을 재실행했고 다음 지점까지 통과했다.

- Rust bridge artifact 검증
- Xcode project 생성
- Release app build
- Host app, Quick Look extension, Thumbnail extension universal architecture 확인
- unsigned rehearsal 경고 출력

확인된 경고:

```text
WARN: Skipping codesign verification because this rehearsal build is unsigned.
WARN: Skipping release signing preflight because this rehearsal build is unsigned.
```

이후 DMG 생성 단계의 기존 Finder layout AppleScript에서 실패했다.

```text
Finder에 오류 발생: toolbar visible of container window of disk "Alhangeul 0.1.1"을(를) false(으)로 설정할 수 없습니다. (-10006)
```

이 실패는 #219에서 추가한 signing preflight validator가 아니라 `create_dmg -> apply_dmg_finder_layout` 단계에서 발생했다. 따라서 #219의 preflight 실행/skip hook 위치는 확인됐지만, local full rehearsal DMG 산출물 생성은 완료하지 못했다.

## 실행하지 않은 항목

- Developer ID signing
- signed rehearsal preflight 실제 실행
- app notarization submit/wait
- DMG signing/notarization/staple
- Gatekeeper public artifact assessment
- GitHub Release asset 업로드
- Pages/appcast/Homebrew Cask 갱신
- #225 release 실행

## #225 Handoff

#225는 이 PR이 `devel-webview`에 merge된 뒤 진행하는 것이 안전하다.

#225에서 반드시 확인할 항목:

- `release-publish.yml` summary의 signing preflight policy가 표시되는지 확인
- public release mode에서 app notarization submit 전에 `Running release signing preflight`가 실행되는지 확인
- preflight 실패 시 notary submit으로 넘어가지 않는지 확인
- `APPLE_TEAM_ID`가 운영 Team ID `XH6JHKYXV8`와 다르면 workflow variable 또는 명령 환경에서 명시
- signed rehearsal 또는 public release 환경에서 Developer ID/timestamp/hardened runtime/get-task-allow 검증을 실제 artifact 기준으로 확인

별도 주의:

- Stage 5 local rehearsal에서 Finder DMG layout AppleScript 실패가 관측됐다.
- 이 문제는 #219 signing preflight 범위 밖이지만, #225 public release에서 재현되면 release packaging blocker로 처리해야 한다.
- #225 시작 전 또는 #225 초반에 `Release Rehearsal DMG` workflow로 DMG 생성 경로를 먼저 확인하는 것이 좋다.

## 커밋 흐름

| 커밋 | 내용 |
|------|------|
| `54ae4ff` | 수행계획서 작성과 오늘할일 갱신 |
| `e2388e8` | 구현계획서 작성 |
| `6def904` | Stage 1 signing preflight inventory 정리 |
| `e816761` | Stage 2 Sparkle component discovery 보강 |
| `37d6b55` | Stage 3 release signing preflight validator 추가 |
| `a99d12e` | 최신 `devel-webview` 병합 |
| `de3932b` | Stage 4 release preflight 문서와 workflow 정리 |

## 최종 판단

#219의 원래 문제였던 "notarization submit 이후에야 signing/timestamp/entitlement 문제를 발견하는 구조"는 해결했다. 이제 public release path는 app notarization submit 전에 필요한 signing prerequisite를 명시 검증한다.

다만 이 최종 보고서는 public release 성공 보고서가 아니다. signed/notarized artifact 생성, GitHub Release 게시, stable appcast, Pages, Homebrew Cask는 #225에서 별도 승인과 release credential이 있는 환경에서 수행해야 한다.
