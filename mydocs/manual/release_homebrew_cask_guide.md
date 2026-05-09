# Homebrew Cask 배포 가이드

## 목적

이 문서는 `alhangeul-macos` Homebrew Cask source, public DMG SHA256 교체, tap 반영, Homebrew 검증 기준을 정리한다. public DMG 생성과 GitHub Release 게시가 먼저 완료되어야 한다.

## 권한 원칙

- Homebrew Cask PR, tap push, Cask SHA256 고정은 작업지시자의 명시 승인 후 수행한다.
- rehearsal DMG 또는 개발용 zip은 Homebrew Cask URL/sha256에 사용하지 않는다.
- public DMG가 GitHub Release asset으로 업로드되고 SHA256이 확정되기 전에는 Cask를 사용자 설치 경로로 안내하지 않는다.

## Cask source 기준

현재 `Casks/alhangeul-macos.rb`는 초안이다.

중요:

- Homebrew는 raw path의 `Casks/alhangeul-macos.rb`를 그대로 public Cask처럼 audit하지 않는다. 실제 brew 배포에는 tap 안의 cask가 필요하다.
- 이 저장소의 `Casks/alhangeul-macos.rb`는 release 기준 Cask source로 유지하고, public DMG가 GitHub Release에 올라간 뒤 선택한 tap으로 복사하거나 PR을 만든다.
- 초기 배포는 별도 tap을 쓰는 방식이 가장 단순하다. 예: `postmelee/homebrew-alhangeul` 또는 `postmelee/homebrew-tap`.
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

## tap 반영 후 검증

```bash
brew style --cask alhangeul-macos
brew audit --cask --new alhangeul-macos
```

raw path 검증은 Homebrew가 tap context를 요구할 수 있으므로, 최종 검증은 선택한 tap에 Cask를 반영한 뒤 cask token 기준으로 수행한다.
