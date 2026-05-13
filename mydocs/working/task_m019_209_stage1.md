# Task M019 #209 Stage 1 완료 보고

## 단계 목표

`v0.1.2` public DMG URL/SHA256 기준으로 본 저장소 Cask source를 갱신하고, tap 검증 후 공개할 Homebrew 설치 안내를 README/Pages/release note 생성 스크립트에 반영한다.

## 변경 내용

- `Casks/alhangeul-macos.rb`
  - `version "0.1.2"`
  - `sha256 "37a27321f03a84b8b28749b5f839ea5c5833975d20f2479e3b79ebd665811ead"`
  - 단일 universal public DMG URL 형식 유지
- `README.md`
  - `v0.1.2`를 최신 public release로 정리
  - Homebrew 설치 명령 `brew install --cask postmelee/tap/alhangeul-macos` 추가
- `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.2.html`
  - Homebrew Cask 설치 명령 공개 문구 추가
- `scripts/ci/write-release-notes.sh`
  - Homebrew 섹션을 검증 완료 후 설치 명령을 안내하는 문구로 전환
- `mydocs/manual/release_homebrew_cask_guide.md`
  - #209 기준을 `v0.1.2`와 #225 public artifact 확정 흐름으로 정리

## 검증

```bash
curl -fsSL https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.2/alhangeul-macos-0.1.2.dmg.sha256 -o /private/tmp/alhangeul-macos-0.1.2.dmg.sha256
ruby -c Casks/alhangeul-macos.rb
./scripts/update-cask-sha256.sh --dry-run 0.1.2 /private/tmp/alhangeul-macos-0.1.2.dmg.sha256
bash -n scripts/ci/write-release-notes.sh scripts/update-cask-sha256.sh
scripts/ci/write-release-notes.sh 0.1.2 37a27321f03a84b8b28749b5f839ea5c5833975d20f2479e3b79ebd665811ead /private/tmp/alhangeul-release-notes-0.1.2-homebrew.md
scripts/ci/check-release-notes-template.sh /private/tmp/alhangeul-release-notes-0.1.2-homebrew.md
git diff --check
```

결과:

- Cask Ruby syntax OK
- Cask SHA256 dry-run OK
- release note template check OK
- diff whitespace check OK

## 다음 단계

Stage 2에서 `postmelee/homebrew-tap`에 Cask를 반영하고 tap context Homebrew 검증을 수행한다.
