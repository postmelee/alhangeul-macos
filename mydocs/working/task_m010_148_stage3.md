# Task #148 Stage 3 완료 보고서: Homebrew Cask와 release 준비 자동화 보강

## 단계 목적

Homebrew Cask 배포 준비 상태를 점검하고, public DMG 생성 후 Cask `version`/`sha256`을 안전하게 갱신하는 최소 자동화를 추가했다. 또한 Homebrew가 raw path Cask 검증을 거부하고 tap context를 요구하는 점을 확인해 release guide에 tap 운영 기준을 보강했다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `scripts/update-cask-sha256.sh` | public DMG `.sha256` 파일에서 `Casks/alhangeul-macos.rb`의 `version`과 `sha256`을 갱신하는 보조 스크립트 추가 |
| `mydocs/manual/release_distribution_guide.md` | Homebrew tap 필요성, Cask sha256 갱신 명령, tap 반영 후 style/audit 검증 기준, checklist 보강 |
| `mydocs/working/task_m010_148_stage3.md` | Stage 3 완료 보고서 추가 |

## 본문 변경 정도 / 본문 무손실 여부

- 기존 Cask URL, app stanza, caveats는 변경하지 않았다.
- public DMG가 아직 생성되지 않았으므로 `Casks/alhangeul-macos.rb`의 `sha256 :no_check`는 유지했다.
- release guide에는 Homebrew 배포 절차를 추가했지만, GitHub Release 게시나 tap push를 자동화하지 않는 기존 권한 원칙은 유지했다.

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
```

결과: 통과.

```bash
./scripts/release.sh --help
```

결과: public release 환경변수와 `--skip-notarize` 옵션 확인.

```bash
./scripts/update-cask-sha256.sh --help
```

결과: usage 출력 확인.

```bash
./scripts/update-cask-sha256.sh --dry-run 0.1.0 /private/tmp/alhangeul-macos-0.1.0.dmg.sha256
```

결과:

```text
Cask: Casks/alhangeul-macos.rb
Version: 0.1.0
SHA256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Dry run: no files changed.
```

negative guard 확인:

```bash
./scripts/update-cask-sha256.sh --dry-run 0.1.0 /private/tmp/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
```

결과:

```text
ERROR: refusing to update Homebrew Cask from rehearsal checksum: alhangeul-macos-0.1.0-rehearsal.dmg.sha256
```

Homebrew 확인:

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew --version
```

결과:

```text
Homebrew 5.1.7-98-gcc2848a
```

raw path style/audit 확인:

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew style --cask Casks/alhangeul-macos.rb
HOMEBREW_NO_AUTO_UPDATE=1 brew audit --cask --new Casks/alhangeul-macos.rb
```

결과:

```text
Error: Homebrew requires casks to be in a tap, rejecting:
  Casks/alhangeul-macos.rb

Error: Calling `brew audit [path ...]` is disabled! Use `brew audit [name ...]` instead.
```

따라서 최종 Homebrew 검증은 tap 대상이 확정된 뒤 cask token 기준으로 수행해야 한다.

문서 정합성 확인:

```bash
rg --line-number 'sha256 :no_check|Homebrew|Cask|brew install|tap|audit|style|alhangeul-macos-.*dmg' \
  README.md mydocs/manual/release_distribution_guide.md Casks/alhangeul-macos.rb scripts
```

결과: Cask placeholder, public DMG 기준, tap 필요성, script 사용법, audit/style 명령을 확인했다.

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- Homebrew tap 대상이 아직 확정되지 않았다.
- public DMG가 아직 없으므로 Cask `sha256`은 실제값으로 고정하지 않았다.
- tap 반영 후 `brew style`/`brew audit`는 아직 실행하지 못했다.
- GitHub Release asset upload와 Homebrew tap push는 작업지시자 별도 승인 후 수행해야 한다.

## 다음 단계 영향

Stage 4에서는 release note, DMG 설치 안내, Homebrew 설치 안내, checksum/Gatekeeper/Quick Look 등록 확인, rollback, App Store 후속 체크리스트 템플릿을 정리한다.

Stage 4 또는 실제 release 실행 전 작업지시자에게 다음 선택이 필요하다.

- 권장: 별도 tap `postmelee/homebrew-alhangeul` 생성 후 `alhangeul-macos` Cask 배포
- 대안: 범용 tap `postmelee/homebrew-tap` 생성 후 여러 formula/cask를 함께 운영
- 장기: `Homebrew/homebrew-cask` 제출은 별도 review 대응 작업으로 분리

## 승인 요청

Stage 3을 완료했다. 이 보고서 기준으로 Stage 4 `배포 안내 문서 템플릿화와 App Store 후속 경로 정리`를 진행할지 승인 요청한다.
