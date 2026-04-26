# Task #32 Stage 4 완료 보고서

## 단계 목적

Stage 3에서 추가한 `scripts/release.sh` 기준으로 release distribution guide, README, Homebrew Cask 정책을 보정한다. 이번 단계에서는 실제 GitHub Release 생성, Homebrew tap PR 생성, signing/notarization 실행은 하지 않는다.

## 변경 파일

- `mydocs/manual/release_distribution_guide.md`
- `README.md`
- `Casks/alhangeul-macos.rb`
- `mydocs/orders/20260426.md`
- `mydocs/working/task_m010_32_stage4.md`

## 변경 요약

### Release Distribution Guide

`scripts/package-release.sh`와 `scripts/release.sh`의 책임을 분리해 문서화했다.

- 개발/검증용 zip package는 `scripts/package-release.sh`가 담당한다.
- public release 기준 산출물은 `scripts/release.sh`가 만드는 signed/notarized DMG로 정리했다.
- Apple Developer Program credential이 없는 환경에서는 public release가 아니라 rehearsal DMG 생성과 credential 누락 검증까지만 가능하다고 명시했다.
- `--skip-notarize` 산출물은 `*-rehearsal.dmg`이며 GitHub Release asset, Homebrew Cask URL/sha256에 사용하지 않는다고 명시했다.
- public mode 환경변수와 산출물 경로를 문서화했다.
- GitHub Release와 Homebrew Cask PR 자동화는 `scripts/release.sh` 범위가 아님을 명시했다.
- 릴리스 체크리스트를 zip 중심에서 public DMG와 public DMG sha256 중심으로 보정했다.

### README

README에는 상세 release 절차를 늘리지 않고 짧은 `Release Packaging` 섹션만 추가했다.

- 개발/검증용 package와 public DMG release pipeline의 차이를 설명했다.
- v0.1.0이 Demo/Preview release 목표임을 반영했다.
- credential 없는 로컬 점검 명령으로 `./scripts/release.sh --skip-notarize 0.1.0`을 안내했다.
- rehearsal DMG는 public release나 Homebrew Cask에 쓰지 않는다고 명시했다.
- 상세 운영 기준은 release guide로 연결했다.

### Homebrew Cask

`Casks/alhangeul-macos.rb`의 URL을 public release 산출물 정책에 맞춰 zip에서 DMG로 변경했다.

```ruby
url "https://github.com/postmelee/alhangeul-macos/releases/download/v#{version}/alhangeul-macos-#{version}.dmg"
```

`sha256 :no_check`는 유지했다. 실제 signed/notarized public DMG가 GitHub Release asset으로 올라간 뒤, 해당 digest로 교체해야 한다.

## 검증 결과

문서 whitespace:

```text
$ git diff --check
결과: 통과
```

Cask syntax:

```text
$ ruby -c Casks/alhangeul-macos.rb
Syntax OK
```

release script help:

```text
$ ./scripts/release.sh --help
결과: Usage와 public release 환경변수 출력 확인
```

credential 누락 검증:

```text
$ env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.0
ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release
```

직접 언급 금지 용어 확인:

```text
$ rg --line-number '<직접 언급 금지 용어>' README.md mydocs/manual/release_distribution_guide.md Casks/alhangeul-macos.rb
결과: 없음
```

## 잔여 위험

- public mode signing/notarization은 아직 Apple Developer Program credential이 없어 실행하지 못했다.
- Cask의 `sha256 :no_check`는 초안 상태다. public DMG가 실제로 생성되고 GitHub Release asset으로 업로드된 뒤 digest로 고정해야 한다.
- GitHub Release 생성 자동화, Homebrew tap PR 자동화, release note template 자동 생성, Finder smoke test report 자동 첨부는 후속 issue 범위로 남아 있다.

## 다음 단계

Stage 5에서는 credential 없이 가능한 최종 검증을 한 번 더 수행하고, script와 문서가 서로 맞는지 확인한다. 실제 signing/notarization은 저장소 소유자의 별도 명시 지시와 Apple Developer Program credential 준비 후에만 수행한다.

## 승인 요청

Stage 4 문서와 Cask 정책 보정을 완료했다. 이 보고서 기준으로 Stage 5 `credential 없이 가능한 최종 검증과 missing credential/rehearsal 동작 확인`을 진행할지 승인 요청한다.
