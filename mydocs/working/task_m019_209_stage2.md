# Task M019 #209 Stage 2 완료 보고

## 단계 목표

`postmelee/homebrew-tap`에 `v0.1.2` public DMG 기준 Cask를 반영하고, tap context에서 Homebrew 검증과 설치 smoke를 수행한다.

## 변경 내용

- `postmelee/homebrew-tap`
  - Cask token을 앱 이름 기준 `alhangeul`로 확정
  - `Casks/alhangeul.rb` 추가
  - tap commit: `4df9f12 Add alhangeul cask`
- 본 저장소
  - release 기준 Cask source를 `Casks/alhangeul.rb`로 정리
  - `scripts/update-cask-sha256.sh`의 Cask path를 `Casks/alhangeul.rb`로 갱신
  - README, Pages, release note template의 설치 명령을 `brew install --cask postmelee/tap/alhangeul`로 정리
- GitHub Release
  - `v0.1.2` release body의 Homebrew Cask 섹션을 검증 완료 안내와 설치 명령 기준으로 갱신
- GitHub Issue
  - #209 본문을 `alhangeul` Cask token과 실제 검증 명령 기준으로 갱신

## 검증

```bash
brew tap postmelee/tap /private/tmp/homebrew-tap-task209
ruby -c Casks/alhangeul.rb
brew style --cask alhangeul
brew audit --cask alhangeul
brew audit --cask --new alhangeul
git push origin main
brew untap postmelee/tap
brew tap postmelee/tap
brew install --cask --appdir=/private/tmp/alhangeul-cask-appdir postmelee/tap/alhangeul
brew uninstall --cask alhangeul
scripts/ci/write-release-notes.sh 0.1.2 37a27321f03a84b8b28749b5f839ea5c5833975d20f2479e3b79ebd665811ead /private/tmp/alhangeul-release-notes-0.1.2-homebrew.md
scripts/ci/check-release-notes-template.sh /private/tmp/alhangeul-release-notes-0.1.2-homebrew.md
```

결과:

- `ruby -c Casks/alhangeul.rb`: OK
- local path tap 등록: `Tapped 1 cask and 1 formula`
- `brew style --cask alhangeul`: no offenses
- `brew audit --cask alhangeul`: OK
- `brew audit --cask --new alhangeul`: `GitHub repository not notable enough`만 실패. 이는 `Homebrew/homebrew-cask` 공식 신규 제출 기준이며, maintainer 소유 tap 공개 gate로 취급하지 않음
- remote tap push: `postmelee/homebrew-tap` `main`에 `4df9f12` 반영
- remote tap 등록 후 HEAD: `4df9f12`
- remote tap 기준 `brew style --cask alhangeul`, `brew audit --cask alhangeul`: OK
- 기본 appdir 설치 smoke는 `/Applications/Alhangeul.app`이 이미 존재해 Homebrew가 overwrite를 거부함. 기존 앱은 `0.1.2 (8)`로 확인했고, 이를 삭제하지 않기 위해 임시 appdir smoke로 전환
- 임시 appdir install smoke: `/private/tmp/alhangeul-cask-appdir/Alhangeul.app` 설치 성공, bundle `0.1.2 (8)` 확인
- uninstall smoke: 임시 appdir `Alhangeul.app` 제거, `brew list --cask alhangeul` 미설치 상태 확인
- `scripts/ci/check-release-notes-template.sh`: OK

## 잔여 사항

- `Homebrew/homebrew-cask` 공식 저장소 제출은 repository notability 기준을 충족한 뒤 별도 이슈로 다룬다.
- 수동 DMG 설치본이 `/Applications/Alhangeul.app`에 이미 있으면 Homebrew는 기본 appdir 설치에서 overwrite를 거부한다. 이는 Cask 오류가 아니라 Homebrew의 일반적인 보호 동작이다.
