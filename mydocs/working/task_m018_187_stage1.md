# Task M018 #187 Stage 1 보고서

## 단계 목적

Homebrew tap 배포 경로와 Cask 검증 절차를 확정하기 전에 현재 저장소 상태, Homebrew CLI 동작, 공식 문서 기준, 후보 tap 존재 여부를 조사한다.

## 확인한 현황

### 현재 Cask source

`Casks/alhangeul-macos.rb`는 다음 상태다.

- `version "0.1.0"`
- `sha256 :no_check`
- GitHub Release DMG URL 형식: `https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg`
- `depends_on macos: ">= :monterey"`
- `app "Alhangeul.app"`
- caveats는 첫 실행 후 Quick Look/Thumbnail 확장 등록을 안내한다.

이는 v0.1.1 public DMG가 아직 확정되지 않은 상태와 맞다. 다만 public 배포 안내로 쓰려면 v0.1.1 최종 DMG SHA256으로 고정해야 한다.

### 기존 문서 기준

`release_homebrew_cask_guide.md`는 이미 다음 방향을 갖고 있다.

- 저장소 내부 `Casks/alhangeul-macos.rb`는 release 기준 Cask source로 유지한다.
- 실제 brew 배포는 raw path가 아니라 선택한 tap 안에서 검증한다.
- 초기 배포는 `postmelee/homebrew-alhangeul` 또는 `postmelee/homebrew-tap` 같은 maintainer 소유 tap이 단순하다.
- `Homebrew/homebrew-cask` 제출은 장기 후보로 분리한다.
- public DMG가 GitHub Release asset으로 올라가고 SHA256이 확정되기 전에는 Cask를 사용자 설치 경로로 안내하지 않는다.

`release_distribution_guide.md`, `release_policy_guide.md`, `v0.1.1.md`, `write-release-notes.sh`도 Homebrew Cask를 public DMG SHA256 이후 확정하는 항목으로 둔다.

### Homebrew 공식 기준

Homebrew 공식 문서 기준:

- `brew tap <user>/<repo>`는 GitHub의 `https://github.com/<user>/homebrew-<repo>` 저장소를 tap으로 clone한다.
- GitHub one-argument tap form을 쓰려면 repository 이름에 `homebrew-` prefix가 필요하다.
- Cask에는 `version`, `sha256`, `url`, `name`, `desc`, `homepage`, `depends_on` 같은 필수 stanza와 최소 하나의 artifact stanza가 필요하다.
- `sha256 :no_check`는 checksum이 실용적이지 않을 때 쓰는 예외이며, 가능한 경우 checksum을 쓰는 것이 기준이다.
- 아키텍처별 별도 다운로드가 있으면 `arch`, `sha256 arm:/intel:` 등을 쓰지만, #208의 단일 universal DMG 정책이면 아키텍처별 stanza는 필요 없다.

참고:

- https://docs.brew.sh/Taps
- https://docs.brew.sh/Cask-Cookbook

### 후보 tap 존재 여부

GitHub 조회 결과:

- `postmelee/homebrew-alhangeul`: 존재하지 않음
- `postmelee/homebrew-tap`: 존재하지 않음
- `postmelee` 계정의 repository 목록에서 `homebrew` 이름을 포함한 repo 없음

따라서 v0.1.1에서 Homebrew 설치 경로를 공개하려면 새 tap 생성이 필요하다. tap 생성과 push는 저장소 외부 변경이므로 별도 승인 대상이다.

### Homebrew CLI 검증 결과

로컬 Homebrew:

```text
Homebrew 5.1.10-52-g1c3a79e
```

현재 `brew tap` 출력은 비어 있었다. 즉 로컬에 추가 tap이 없다.

검증 명령 결과:

```bash
env HOMEBREW_CACHE=/private/tmp/homebrew-cache HOMEBREW_NO_AUTO_UPDATE=1 brew style --cask Casks/alhangeul-macos.rb
```

결과:

```text
Error: Homebrew requires casks to be in a tap, rejecting:
  Casks/alhangeul-macos.rb
```

```bash
env HOMEBREW_CACHE=/private/tmp/homebrew-cache HOMEBREW_NO_AUTO_UPDATE=1 brew audit --cask Casks/alhangeul-macos.rb
```

결과:

```text
Error: Calling `brew audit [path ...]` is disabled! Use `brew audit [name ...]` instead.
```

`brew audit --cask --new Casks/alhangeul-macos.rb`는 parallel 실행 중 Bundler lock/gem 교체 경합으로 실패했다. 별도 tap context가 없는 상태에서는 path audit 자체도 부적절하므로, Stage 2에서는 raw path audit을 공식 검증으로 쓰지 않는다.

## 결정안

### 권장 tap

초기 v0.1.1 공개 후보는 `postmelee/homebrew-tap`을 권장한다.

이유:

- Homebrew one-argument tap 규칙에 맞는 실제 GitHub repository 이름은 `postmelee/homebrew-tap`이고, 사용자 명령은 `brew tap postmelee/tap`이 된다.
- 향후 `alhangeul-macos` 외 다른 배포물이 생겨도 같은 tap에 둘 수 있다.
- `postmelee/homebrew-alhangeul`은 제품 전용성이 높지만, 사용자 명령이 `brew tap postmelee/alhangeul`로 보이므로 앱 저장소명 `alhangeul-macos`와 약간 다르다.
- `Homebrew/homebrew-cask`는 장기 후보로 유지하되, v0.1.1 patch release의 선행 작업으로 넣기에는 review와 audit 요구가 크다.

### v0.1.1 공개 조건

v0.1.1에서 Homebrew 설치 안내를 공개하려면 다음 조건을 모두 만족해야 한다.

1. #208에서 v0.1.1 public DMG가 단일 universal DMG임을 검증한다.
2. #188에서 signed/notarized public DMG와 `.sha256`이 GitHub Release asset으로 확정된다.
3. `scripts/update-cask-sha256.sh 0.1.1`로 `Casks/alhangeul-macos.rb`를 `version "0.1.1"`과 실제 SHA256으로 갱신한다.
4. 선택한 tap의 `Casks/alhangeul-macos.rb`에 같은 내용을 반영한다.
5. tap context에서 다음 검증을 수행하고 결과를 release report에 기록한다.
   - `brew style --cask alhangeul-macos`
   - `brew audit --cask alhangeul-macos`
   - 필요 시 `brew audit --cask --new alhangeul-macos`
   - `brew install --cask postmelee/tap/alhangeul-macos` 또는 동등한 tap-qualified install smoke

조건을 만족하지 못하면 v0.1.1 release note에는 Homebrew 설치 명령을 공개하지 않고, GitHub Release DMG와 Pages 다운로드 경로만 안내한다.

### Stage 2 반영 방향

Stage 2에서는 다음을 문서와 template에 반영한다.

- `postmelee/homebrew-tap`을 권장 tap으로 기록한다.
- 새 tap 생성과 push는 작업지시자 명시 승인 후 수행한다고 분리한다.
- v0.1.1 release note template에는 Homebrew가 아직 공개되지 않았을 때와 공개 완료 후를 구분하는 문구를 둔다.
- `release_homebrew_cask_guide.md`에는 tap context 검증 명령을 raw path 검증과 명확히 구분해 기록한다.
- `v0.1.1.md`에는 #187 결정 사항과 #188 handoff 항목을 추가한다.

## 잔여 질문

- v0.1.1에서 Homebrew 설치 안내를 실제로 공개할지, 아니면 tap 준비까지만 하고 DMG 배포를 우선할지 #188에서 최종 결정해야 한다.
- `postmelee/homebrew-tap` repository를 이번 task에서 생성할지, 아니면 #188 public DMG SHA256 확정 후 생성할지 작업지시자 승인이 필요하다.

## Stage 2 승인 요청

Stage 2에서는 위 결정안을 기준으로 release manual, v0.1.1 release record, release note template을 수정한다. 실제 tap repository 생성, tap push, public install 명령 공개는 아직 수행하지 않는다.
