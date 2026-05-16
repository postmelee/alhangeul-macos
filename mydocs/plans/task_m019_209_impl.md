# Task M019 #209 구현계획서

## 구현 목표

`v0.1.2` public DMG 기준 Cask를 본 저장소와 `postmelee/homebrew-tap`에 반영하고, Homebrew tap 설치 경로를 검증한 뒤 사용자 안내를 공개한다.

## 구현 순서

1. `Casks/alhangeul.rb` 갱신
   - `version "0.1.2"`
   - `sha256 "37a27321f03a84b8b28749b5f839ea5c5833975d20f2479e3b79ebd665811ead"`
   - URL은 기존 tag 고정 GitHub Release DMG 형식 유지
2. 사용자-facing 문서 갱신
   - README 설치 섹션에 Homebrew 설치 명령 추가
   - Pages home/update 페이지에 Homebrew 설치 명령 추가
   - release note 생성 스크립트의 Homebrew Cask 섹션을 검증 완료 안내로 전환
3. 내부 기록 갱신
   - `mydocs/release/v0.1.2.md`의 Homebrew 항목을 진행/검증 기준으로 갱신
   - Homebrew 가이드의 #209 기준을 `v0.1.2`로 정리
4. tap 반영
   - `postmelee/homebrew-tap`을 확인/clone/fetch
   - tap의 `Casks/alhangeul.rb`에 동일 Cask 반영
5. 검증
   - 본 저장소 Cask shape와 script dry-run
   - tap context `brew style`, `brew audit`
   - `brew install --cask postmelee/tap/alhangeul`
   - `brew uninstall --cask alhangeul`
6. 보고
   - Stage 보고서와 최종 보고서 작성
   - 본 저장소 PR 게시
   - tap 변경은 별도 commit/push 결과를 보고서에 기록

## 파일별 변경 방침

| 파일 | 방침 |
|------|------|
| `Casks/alhangeul.rb` | public v0.1.2 DMG version/SHA 반영 |
| `README.md` | GitHub Release DMG와 Homebrew 설치 명령을 함께 안내 |
| `docs/index.html`, `docs/updates/*.html` | Pages에 Homebrew 설치 명령 추가 |
| `scripts/ci/write-release-notes.sh` | 이후 release note의 Homebrew 섹션을 검증 완료 시 공개 문구로 갱신 |
| `mydocs/manual/release_homebrew_cask_guide.md` | v0.1.1 잔여 문구를 v0.1.2/#209 기준으로 정리 |
| `mydocs/release/v0.1.2.md` | Homebrew Cask 결과 기록 |

## 검증 명령

```bash
./scripts/update-cask-sha256.sh --dry-run 0.1.2 /private/tmp/alhangeul-macos-0.1.2.dmg.sha256
ruby -c Casks/alhangeul.rb
brew style --cask alhangeul
brew audit --cask alhangeul
brew audit --cask --new alhangeul
brew install --cask postmelee/tap/alhangeul
brew uninstall --cask alhangeul
git diff --check
```
