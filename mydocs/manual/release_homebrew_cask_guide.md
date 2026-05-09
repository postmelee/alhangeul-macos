# Homebrew Cask 배포 가이드

## 목적

이 문서는 `alhangeul-macos` Homebrew Cask source, public DMG SHA256 교체, tap 반영, Homebrew 검증 기준을 정리한다. public DMG 생성과 GitHub Release 게시가 먼저 완료되어야 한다.

## 권한 원칙

- Homebrew Cask PR, tap push, Cask SHA256 고정은 작업지시자의 명시 승인 후 수행한다.
- rehearsal DMG 또는 개발용 zip은 Homebrew Cask URL/sha256에 사용하지 않는다.
- public DMG가 GitHub Release asset으로 업로드되고 SHA256이 확정되기 전에는 Cask를 사용자 설치 경로로 안내하지 않는다.
- `v0.1.1`의 실제 Homebrew tap 초기 공개 배포는 #209에서 수행한다. #187은 tap 경로와 검증 기준을 확정하는 작업으로 한정한다.

## Cask source 기준

현재 `Casks/alhangeul-macos.rb`는 초안이다.

중요:

- Homebrew는 raw path의 `Casks/alhangeul-macos.rb`를 그대로 public Cask처럼 audit하지 않는다. 실제 brew 배포에는 tap 안의 cask가 필요하다.
- 이 저장소의 `Casks/alhangeul-macos.rb`는 release 기준 Cask source로 유지하고, public DMG가 GitHub Release에 올라간 뒤 선택한 tap으로 복사하거나 PR을 만든다.
- 초기 배포 tap은 `postmelee/homebrew-tap`을 기준으로 한다. Homebrew one-argument tap 명령은 `brew tap postmelee/tap`이고, 실제 GitHub repository는 `postmelee/homebrew-tap`이다.
- 장기적으로 `Homebrew/homebrew-cask` 제출을 목표로 둘 수 있지만, 별도 review와 더 엄격한 audit 대응이 필요하므로 초기 public DMG 배포와 분리한다.

## 릴리스 전 확인

- `url`이 `https://github.com/postmelee/alhangeul-macos/releases/...`를 가리키는가
- `version`이 Git tag와 일치하는가
- `url`이 public DMG 산출물 `alhangeul-macos-<version>.dmg`와 일치하는가
- `sha256`이 public DMG의 실제 digest와 일치하는가
- cask token이 `alhangeul-macos`인가
- `homepage`이 현재 저장소를 가리키는가
- `app "Alhangeul.app"`이 산출물과 일치하는가
- caveats 문구가 현재 extension 등록 흐름과 일치하는가

운영 기준:

- Cask는 public DMG release가 GitHub Release asset으로 업로드된 뒤에만 배포 경로로 사용한다.
- 실제 public DMG 없이 rehearsal DMG를 가리키도록 수정하지 않는다.
- public DMG sha256이 확정되기 전에는 Cask 초안의 `sha256 :no_check`를 실제 배포 승인으로 간주하지 않는다.
- 사용자-facing Homebrew 설치 명령은 #209에서 tap context 검증이 끝난 뒤에만 README, Pages, GitHub Release/릴리즈 노트에 공개한다.

## Cask sha256 갱신

```bash
./scripts/update-cask-sha256.sh <version>
```

기본 입력은 `build.noindex/release/alhangeul-macos-<version>.dmg.sha256`이다. 다른 경로의 checksum 파일을 사용할 때:

```bash
./scripts/update-cask-sha256.sh <version> /path/to/alhangeul-macos-<version>.dmg.sha256
```

검증만 하고 파일을 수정하지 않을 때:

```bash
./scripts/update-cask-sha256.sh --dry-run <version> /path/to/alhangeul-macos-<version>.dmg.sha256
```

주의:

- `*-rehearsal.dmg.sha256`은 script가 거부해야 한다.
- checksum 파일 안의 DMG 파일명이 `alhangeul-macos-<version>.dmg`와 일치해야 한다.
- script는 GitHub Release upload 또는 Homebrew tap push를 수행하지 않는다.

## tap 반영 절차

`v0.1.1` 기준 실제 공개 절차는 #209에서 진행한다.

1. #188에서 signed/notarized public DMG와 `.sha256` asset을 확정한다.
2. `./scripts/update-cask-sha256.sh <version>`로 이 저장소의 `Casks/alhangeul-macos.rb`를 public DMG SHA256 기준으로 갱신한다.
3. `postmelee/homebrew-tap`의 `Casks/alhangeul-macos.rb`에 같은 내용을 반영한다.
4. tap repository 기준으로 Homebrew 검증을 수행한다.
5. 검증이 통과한 뒤에만 사용자 문서와 release note에 Homebrew 설치 명령을 공개한다.

검증 전 사용자 설치 경로는 GitHub Release DMG와 Pages 다운로드 버튼만 사용한다.

## tap 반영 후 검증

```bash
brew tap postmelee/tap
brew style --cask alhangeul-macos
brew audit --cask alhangeul-macos
brew audit --cask --new alhangeul-macos
brew install --cask postmelee/tap/alhangeul-macos
brew uninstall --cask alhangeul-macos
```

raw path 검증은 Homebrew가 tap context를 요구할 수 있으므로, 최종 검증은 선택한 tap에 Cask를 반영한 뒤 cask token 기준으로 수행한다.

`brew audit --cask --new`는 maintainer tap 운영에 필요한 최소 조건보다 엄격할 수 있다. 실패 시에는 일반 `brew audit --cask`, install smoke, 실패 사유를 함께 기록하고 공개 여부를 작업지시자가 결정한다.
