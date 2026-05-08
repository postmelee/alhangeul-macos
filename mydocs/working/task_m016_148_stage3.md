# Task #148 Stage 3 완료 보고서: Homebrew Cask와 release 준비 자동화 보강

## 단계 목적

Homebrew Cask 배포 준비 상태를 점검하고, public DMG 생성 후 Cask `version`/`sha256`을 안전하게 갱신하는 최소 자동화를 추가했다. 또한 Homebrew가 raw path Cask 검증을 거부하고 tap context를 요구하는 점을 확인해 release guide에 tap 운영 기준을 보강했다.

이 보고서는 기존 `task_m010_148_stage3.md`를 2026-05-08 현재 M016 기준으로 이관한 것이다. #148의 원래 범위에 맞춰 이 단계의 의미는 Homebrew 배포 실행이 아니라 public DMG 기준을 Cask에 반영하기 위한 guard 준비로 한정한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `scripts/update-cask-sha256.sh` | public DMG `.sha256` 파일에서 `Casks/alhangeul-macos.rb`의 `version`과 `sha256`을 갱신하는 보조 스크립트 추가 |
| `mydocs/manual/release_distribution_guide.md` | Homebrew tap 필요성, Cask sha256 갱신 명령, tap 반영 후 style/audit 검증 기준, checklist 보강 |
| `mydocs/working/task_m016_148_stage3.md` | Stage 3 완료 보고서 이관 |

## 변경 내용

### Cask sha256 갱신 스크립트

`scripts/update-cask-sha256.sh`를 추가했다.

주요 동작:

- 기본 입력: `build.noindex/release/alhangeul-macos-<version>.dmg.sha256`
- 명시 입력: `./scripts/update-cask-sha256.sh <version> <checksum-file>`
- `--dry-run`으로 파일 수정 없이 검증 가능
- checksum 파일명이 `*rehearsal*`이면 거부
- checksum 파일 안의 DMG 파일명이 `alhangeul-macos-<version>.dmg`와 다르면 거부
- Cask의 `version`과 `sha256` line shape가 예상과 다르면 거부
- GitHub Release upload, Homebrew tap push는 수행하지 않음

### Homebrew tap 기준 문서화

`brew style --cask Casks/alhangeul-macos.rb`와 `brew audit --cask --new Casks/alhangeul-macos.rb`를 실행해 raw path 검증이 현재 Homebrew에서 막히는 것을 확인했다.

release guide에는 다음 기준을 추가했다.

- 이 저장소의 `Casks/alhangeul-macos.rb`는 release 기준 Cask source로 유지
- 실제 brew 배포에는 tap 안의 cask 필요
- public DMG가 GitHub Release에 올라간 뒤 선택한 tap으로 복사 또는 PR 생성
- 초기 배포는 별도 tap이 가장 단순
- `Homebrew/homebrew-cask` 제출은 장기 목표로 둘 수 있으나 v0.1 첫 배포와 분리
- tap 반영 후에는 cask token 기준으로 `brew style --cask alhangeul-macos`, `brew audit --cask --new alhangeul-macos` 실행

## 검증 결과

구현계획서 Stage 3 검증 명령과 추가 스크립트 검증을 실행했다.

```bash
bash -n scripts/release.sh scripts/package-release.sh scripts/update-cask-sha256.sh
./scripts/release.sh --help
./scripts/update-cask-sha256.sh --help
./scripts/update-cask-sha256.sh --dry-run 0.1.0 /private/tmp/alhangeul-macos-0.1.0.dmg.sha256
./scripts/update-cask-sha256.sh --dry-run 0.1.0 /private/tmp/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
HOMEBREW_NO_AUTO_UPDATE=1 brew --version
HOMEBREW_NO_AUTO_UPDATE=1 brew style --cask Casks/alhangeul-macos.rb
HOMEBREW_NO_AUTO_UPDATE=1 brew audit --cask --new Casks/alhangeul-macos.rb
rg --line-number 'sha256 :no_check|Homebrew|Cask|brew install|tap|audit|style|alhangeul-macos-.*dmg' \
  README.md mydocs/manual/release_distribution_guide.md Casks/alhangeul-macos.rb scripts
git diff --check
```

결과:

- shell syntax, help 출력, dry-run update 통과
- rehearsal checksum 입력은 의도대로 거부
- Homebrew raw path style/audit는 tap context 요구로 실패했고, 이를 release guide에 반영
- whitespace 오류 없음

## 잔여 위험

- Homebrew tap 대상은 아직 확정하지 않는다.
- public DMG가 아직 없으므로 Cask `sha256`은 실제값으로 고정하지 않았다.
- tap 반영 후 `brew style`/`brew audit`는 아직 실행하지 못했다.
- GitHub Release asset upload와 Homebrew tap push는 작업지시자 별도 승인 후 수행해야 한다.

## 다음 단계 영향

Stage 4에서는 기존 #148 산출물을 M016 문서명과 현재 `devel-webview` 기준으로 정합화하고, 오래된 `AlhangeulMac.app` 참조와 `task_m010_148*` 경로를 제거한다.
