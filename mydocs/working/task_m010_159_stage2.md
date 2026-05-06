# Task #159 Stage 2 보고서

## 단계 목적

secret 없이 수동으로 실행 가능한 release rehearsal workflow를 추가한다. 이 단계는 public release, notarization, GitHub Release 게시, Homebrew 배포를 수행하지 않고, 기존 `scripts/release.sh --skip-notarize` 경로가 GitHub Actions에서 재사용될 수 있도록 workflow와 lock helper만 추가한다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `.github/workflows/release-rehearsal.yml` | 신규 | 수동 실행 기반 unsigned rehearsal DMG 생성과 artifact 업로드 workflow |
| `scripts/ci/read-rhwp-core-lock.sh` | 신규 | `rhwp-core.lock`의 top-level scalar 값을 읽는 CI helper |
| `mydocs/working/task_m010_159_stage2.md` | 신규 | Stage 2 구현 및 검증 결과 보고서 |

## 본문 변경 정도 / 본문 무손실 여부

- 앱 소스, Rust bridge, `scripts/release.sh`, `scripts/build-rust-macos.sh`, Cask, README, manual은 변경하지 않았다.
- `.github/workflows`와 `scripts/ci` 아래 신규 파일만 추가했다.
- `rhwp-core.lock`은 변경하지 않았다. 현재 lock은 계속 `v0.7.9` 기준이며, M16 완료 후 public 배포 전 upstream `v0.7.10` 반영 여부를 별도로 판단해야 한다.
- M16 병렬 작업에서 주로 다룰 앱 기능, viewer, bridge, 문서 본문과 직접 충돌하는 파일은 건드리지 않았다.

## 구현 내용

### `release-rehearsal.yml`

- `workflow_dispatch` 전용 workflow로 추가했다.
- 입력값:
  - `version`: rehearsal DMG version. 기본값 `0.1.0`
  - `expected_rhwp_tag`: 비어 있지 않으면 `rhwp-core.lock`의 `rhwp_release_tag`와 일치해야 함
- 권한은 `contents: read`로 제한했다.
- `./scripts/build-rust-macos.sh --verify-lock`로 lock 정합성을 먼저 확인한다.
- `./scripts/release.sh --skip-notarize "$VERSION"`으로 unsigned rehearsal DMG를 생성한다.
- 생성된 `*-rehearsal.dmg`와 `.sha256`만 Actions artifact로 업로드한다.
- workflow summary에 core lock tag, core commit, artifact sha256을 남기도록 했다.

### `read-rhwp-core-lock.sh`

- `rhwp-core.lock`의 top-level key를 안전하게 읽는 bash helper를 추가했다.
- key 이름은 `[A-Za-z_][A-Za-z0-9_]*` 형식만 허용한다.
- 누락된 lock file, 잘못된 key, 빈 값은 error로 처리한다.
- Stage 3 publish workflow와 Stage 4 upstream check workflow에서도 같은 helper를 재사용할 수 있다.

## 검증 결과

```text
$ ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release-rehearsal.yml"); puts "ok"'
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
ok
```

Ruby local gem 경고는 현재 로컬 Ruby 환경의 `ffi` extension 경고이며 YAML parse는 성공했다.

```text
$ bash scripts/ci/read-rhwp-core-lock.sh rhwp_release_tag
v0.7.9
```

```text
$ bash scripts/ci/read-rhwp-core-lock.sh rhwp_commit
0fb3e6758b8ad11d2f3c3849c83b914684e83863
```

```text
$ ./scripts/release.sh --help
통과
```

```text
$ ./scripts/build-rust-macos.sh --verify-lock
Verified: /private/tmp/rhwp-mac-task159/rhwp-core.lock
```

검증 중 Xcode/CoreSimulator 경고가 출력됐지만, Rust universal framework 생성과 lock 검증은 완료됐다.

```text
$ ./scripts/release.sh --skip-notarize 0.1.0
hdiutil: create failed - 장치가 구성되지 않았음
```

위 실행은 sandbox 안에서 `hdiutil create`가 device 접근에 실패한 케이스다. 같은 명령을 sandbox 밖 권한으로 재실행해 성공을 확인했다.

```text
$ ./scripts/release.sh --skip-notarize 0.1.0
INFO: Release artifact: /private/tmp/rhwp-mac-task159/build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg
INFO: Checksum: /private/tmp/rhwp-mac-task159/build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg.sha256
WARN: Rehearsal artifact complete. Do not use it for public release or Homebrew Cask.
```

```text
$ shasum -a 256 -c alhangeul-macos-0.1.0-rehearsal.dmg.sha256
alhangeul-macos-0.1.0-rehearsal.dmg: OK
```

```text
$ cat alhangeul-macos-0.1.0-rehearsal.dmg.sha256
d3c236f08b50ef5fb7552bd1b6678d98ab296765ffed65b91153d218262883e0  alhangeul-macos-0.1.0-rehearsal.dmg
```

```text
$ git diff --check
통과
```

```text
$ git status --short --branch
## local/task159...origin/devel-webview [ahead 3]
?? .github/workflows/
?? scripts/ci/
```

## 잔여 위험

- GitHub-hosted `macos-15` runner에서 `xcodegen`, Rust target, Xcode SDK 버전 차이가 있을 수 있다. 실제 workflow 첫 실행 결과로 조정해야 한다.
- rehearsal DMG는 unsigned, unnotarized 산출물이므로 public release asset이나 Homebrew Cask checksum으로 사용하면 안 된다.
- 현재 lock은 `v0.7.9`이므로, Stage 3 publish guard와 Stage 4 upstream check가 추가되기 전까지는 `v0.7.10` stale 상태를 자동으로 막지 않는다.

## 다음 단계 영향

Stage 3에서는 같은 lock helper를 사용해 signed/notarized publish workflow를 추가한다. publish workflow는 `expected_rhwp_tag`와 `require_latest_rhwp` guard를 포함해야 하며, 현재 상태에서는 `expected_rhwp_tag=v0.7.10` 또는 `require_latest_rhwp=true` 조건에서 public publish가 중단되어야 정상이다.

## 승인 요청

Stage 2를 완료했다. Stage 3 `signed/notarized publish workflow 구현`으로 진행할지 승인 요청한다.
