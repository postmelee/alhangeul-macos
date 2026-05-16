# Task M019 #219 Stage 4 완료 보고서

## 단계 목적

Stage 3에서 추가한 release signing preflight를 release workflow summary와 release 운영 문서에 연결한다. 작업자가 #225 등 후속 release 실행 전에 preflight 실행/skip 조건, 검증 항목, 실패 기준을 확인할 수 있게 한다.

확인 시각: `2026-05-11 14:09 KST`

## 사전 base 정렬

Stage 4 시작 전 `origin/devel-webview`에 PR #232(`#218`)가 merge되어 `local/task219`이 behind 상태가 됐다. `origin/devel-webview`를 병합했고, `mydocs/orders/20260511.md` 충돌은 #218 완료 행과 #219 진행 행을 모두 보존하는 방식으로 해결했다.

병합 커밋:

```text
Task #219: 최신 devel-webview 병합
```

## 산출물

| 파일 | 내용 |
|------|------|
| `.github/workflows/release-publish.yml` | public release workflow summary에 signing preflight policy 기록 추가 |
| `.github/workflows/release-rehearsal.yml` | rehearsal workflow summary에 unsigned/signed rehearsal signing preflight 조건 기록 추가 |
| `mydocs/manual/release_signing_notarization_guide.md` | notarization 전 signing preflight 검증 위치, 대상, 기준 문서화 |
| `mydocs/manual/release_packaging_dmg_guide.md` | public/rehearsal DMG 수행 항목과 `APPLE_TEAM_ID` 기준 보강 |
| `mydocs/manual/release_distribution_guide.md` | release asset 설명과 최종 체크리스트에 signing preflight 추가 |
| `mydocs/working/task_m019_219_stage4.md` | Stage 4 완료 보고서 |

## 본문 변경 정도 / 본문 무손실 여부

- workflow summary와 release manual만 수정했다.
- `scripts/release.sh`는 Stage 4에서 수정하지 않았다.
- #218 troubleshooting 문서는 복제하지 않고 기존 연결을 유지했다.
- public release, Developer ID signing, notarization submit/wait, GitHub Release 게시, Pages/appcast 갱신은 실행하지 않았다.

## 변경 내용

### Release Publish workflow summary

`release-publish.yml`에 `Record signing preflight policy` step을 추가했다.

summary에 남기는 내용:

- release command: `./scripts/release.sh "$VERSION"`
- expected Team ID
- app notarization submit 전에 Developer ID authority, Team ID, secure timestamp, hardened runtime, `get-task-allow` 부재, Sparkle nested component 존재를 검증한다는 점
- preflight 실패가 notarization submit을 차단한다는 점

### Release Rehearsal workflow summary

`release-rehearsal.yml`에 `Record signing preflight policy` step을 추가했다.

summary에 남기는 내용:

- release command: `./scripts/release.sh --skip-notarize "$VERSION"`
- 기본 rehearsal artifact는 unsigned이며 Developer ID signing preflight를 skip한다는 점
- `ALHANGEUL_DEVELOPER_ID_APPLICATION`을 제공한 signed rehearsal에서는 같은 app/extension/Sparkle signing preflight가 실행된다는 점
- rehearsal artifact는 public release 또는 Homebrew Cask 입력이 아니라는 점

### Signing/notarization guide

`release_signing_notarization_guide.md`에 `Notarization 전 signing preflight` 섹션을 추가했다.

문서화한 항목:

- preflight 실행 위치: 재서명과 universal/codesign verify 이후, app notarization submit 이전
- 검증 대상: Host app, Quick Look extension, Thumbnail extension, Sparkle framework, Sparkle Downloader/Installer XPC, Updater.app, Autoupdate
- 검증 기준: Developer ID authority, Team ID, secure timestamp, hardened runtime, `get-task-allow` 부재, bundle identifier, required Sparkle component 존재
- unsigned rehearsal과 signed rehearsal의 실행/skip 조건

### Packaging/distribution guide

`release_packaging_dmg_guide.md`에는 public mode 수행 항목에 Sparkle/app/extension 재서명과 release signing preflight를 추가했다. rehearsal section에는 Developer ID identity가 제공된 signed rehearsal에서 같은 preflight가 실행되며, unsigned rehearsal skip 결과를 public signing prerequisite 통과로 기록하지 말라는 기준을 추가했다.

`release_distribution_guide.md`에는 `scripts/release.sh` asset 설명과 최종 체크리스트에 app notarization 전 signing preflight 통과 항목을 추가했다.

## Stage 4 기준 대비 결과

| 구현계획 기준 | 결과 |
|---------------|------|
| release-publish summary가 signing preflight 실행 기준 설명 | OK |
| release-rehearsal summary가 signing preflight 실행/skip 조건 설명 | OK |
| signing/notarization 문서에 preflight gate 위치와 실패 기준 기록 | OK |
| packaging/distribution 문서에 #225 release 실행 전 확인 기준 기록 | OK |
| public release 실행 없음 | OK |

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `git status -sb` | OK | Stage 4 전 최신 `origin/devel-webview` 병합 후 진행 |
| `rg -n "signing preflight\|notarization preflight\|Developer ID\|timestamp\|get-task-allow\|Sparkle.framework\|release.sh" .github/workflows mydocs/manual` | OK | workflow/manual 연결 확인 |
| `git diff --check -- .github/workflows mydocs/manual` | OK | whitespace 오류 없음 |
| `git diff --stat` | OK | workflow 2개, manual 3개 변경 확인 |

## 실행하지 않은 항목

- `scripts/release.sh` 추가 수정
- `./scripts/release.sh --skip-notarize` 실행
- Developer ID signing
- signed rehearsal
- notarization submit/wait
- public release 관련 외부 작업

## 잔여 위험

- workflow summary는 GitHub Actions에서 실제 실행해야 최종 렌더링을 확인할 수 있다. 로컬에서는 YAML fragment와 shell echo 구문 수준으로 확인했다.
- signed rehearsal은 Developer ID identity가 있는 환경에서만 preflight 실행을 확인할 수 있다.
- Stage 5에서 가능한 범위의 release helper/rehearsal 검증을 통해 unsigned skip path와 script syntax를 다시 확인해야 한다.

## 다음 단계

Stage 5 승인 후 다음을 수행한다.

1. `bash -n scripts/release.sh`, `bash -n scripts/ci/*.sh`, `./scripts/release.sh --help`를 재실행한다.
2. 가능한 경우 `./scripts/release.sh --skip-notarize <현재 source version>`으로 unsigned rehearsal path를 확인한다.
3. 전체 검색과 `git diff --check`를 실행한다.
4. 최종 보고서와 오늘할일 완료 처리 후 커밋한다.

## 승인 요청

1. Stage 4 결과 승인
2. Stage 5 `통합 검증과 최종 보고` 진입 승인
