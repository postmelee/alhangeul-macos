# Task M018 #187 Stage 3 보고서

## 단계 목적

Stage 2에서 문서화한 Homebrew Cask 검증 절차가 실제 Homebrew CLI에서 어떤 결과를 내는지 확인한다. public DMG SHA256, 실제 `postmelee/homebrew-tap` 생성, Cask push, 앱 설치 smoke는 #209 범위로 남긴다.

## 검증 환경

```text
Homebrew 5.1.10-52-g1c3a79e
```

Stage 3 시작 전 로컬 `brew tap` 목록은 비어 있었다. 검증을 위해 `/private/tmp/alhangeul-homebrew-tap`에 임시 Git repository를 만들고 `Casks/alhangeul-macos.rb`를 복사한 뒤, 다음 명령으로 local URL tap을 등록했다.

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew tap postmelee/tap /private/tmp/alhangeul-homebrew-tap
```

검증 후에는 다음 명령으로 정리했고, 다시 `brew tap` 목록이 비어 있음을 확인했다.

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew untap postmelee/tap
```

## Cask와 release helper 검증

| 명령 | 결과 |
|------|------|
| `./scripts/update-cask-sha256.sh --dry-run 0.1.1 /private/tmp/alhangeul-macos-0.1.1.dmg.sha256` | 통과. `version "0.1.1"`과 sample SHA256 적용 계획만 출력하고 파일 미수정 |
| `./scripts/update-cask-sha256.sh --dry-run 0.1.1 /private/tmp/alhangeul-macos-0.1.1-rehearsal.dmg.sha256` | 기대 실패. rehearsal checksum 거부 확인 |
| `ruby -c Casks/alhangeul-macos.rb` | 통과 |
| `scripts/ci/write-release-notes.sh 0.1.1 <sample-sha> /private/tmp/alhangeul-release-notes-stage3-0.1.1.md` | 통과 |
| `scripts/ci/check-release-notes-template.sh /private/tmp/alhangeul-release-notes-stage3-0.1.1.md` | 통과 |
| `rg -n "^## Homebrew Cask\|postmelee/tap\|GitHub Release DMG" /private/tmp/alhangeul-release-notes-stage3-0.1.1.md` | `Homebrew Cask` heading, GitHub Release DMG 우선 안내, #209 이후 공개할 설치 명령 확인 |

## tap context 검증

| 명령 | 결과 |
|------|------|
| `HOMEBREW_CACHE=/private/tmp/homebrew-cache HOMEBREW_NO_AUTO_UPDATE=1 brew style --cask alhangeul-macos` | 통과. `1 file inspected, no offenses detected` |
| `HOMEBREW_CACHE=/private/tmp/homebrew-cache HOMEBREW_NO_AUTO_UPDATE=1 brew audit --cask alhangeul-macos` | 통과. 출력 없음 |
| `HOMEBREW_CACHE=/private/tmp/homebrew-cache HOMEBREW_NO_AUTO_UPDATE=1 brew audit --cask --new alhangeul-macos` | 실패. official cask 신규 제출 기준 이슈 확인 |

`brew audit --cask --new` 실패 내용:

```text
cask token mentions platform
GitHub repository not notable enough (<30 forks, <30 watchers and <75 stars)
```

이 결과는 `Homebrew/homebrew-cask` 공식 제출에는 blocker지만, maintainer tap인 `postmelee/homebrew-tap` 공개 gate로 보지는 않는다. Stage 3에서 `release_homebrew_cask_guide.md`에 maintainer tap gate와 official cask 제출 기준을 분리해 보강했다.

## 수행하지 않은 검증

`brew install --cask postmelee/tap/alhangeul-macos`는 실행하지 않았다.

이유:

- 현재 Cask source는 `version "0.1.0"`과 `sha256 :no_check` 상태다.
- 이번 단계에서 설치하면 v0.1.0 public DMG를 내려받아 사용자 시스템에 앱 설치를 시도한다.
- #209의 실제 목표는 v0.1.1 public DMG URL/SHA256 확정 후 install/uninstall smoke를 수행하는 것이다.

## #209 handoff

#209에서는 다음 순서를 유지한다.

1. #188에서 v0.1.1 public DMG URL과 SHA256을 확정한다.
2. `scripts/update-cask-sha256.sh 0.1.1`로 Cask version/SHA256을 고정한다.
3. `postmelee/homebrew-tap`에 Cask를 반영한다.
4. maintainer tap 공개 gate로 `brew style --cask alhangeul-macos`, `brew audit --cask alhangeul-macos`, install/uninstall smoke를 실행한다.
5. `brew audit --cask --new alhangeul-macos`는 참고 검증으로 실행하되, 위 official submission 기준 이슈가 남으면 `Homebrew/homebrew-cask` 제출 후속 이슈로 분리한다.
