# Task #375 Stage 2 완료보고서

## 단계 목적

`scripts/verify-rhwp-studio-assets.sh`에 optional target upstream checkout 검증 mode를 추가해 manifest `source_cargo_lock_sha256`과 root `Cargo.lock` 실제 SHA-256을 비교하고, sync writer가 생성 직후 같은 계약으로 self-check하도록 구현했다. Temporary resource/upstream fixture로 compatibility와 strict 오류 분기를 고정했다.

## 산출물

| 파일 | 변경 | 규모/요약 |
|------|------|-----------|
| `scripts/verify-rhwp-studio-assets.sh` | 수정 | 208줄, `--upstream-dir`, actual hash 비교와 구분된 진단 |
| `scripts/sync-rhwp-studio.sh` | 수정 | 286줄, writer 최종 verifier에 `UPSTREAM_DIR` 전달 |
| `scripts/ci/test-rhwp-studio-cargo-lock-verification.sh` | 신규 | 216줄, compatibility/strict/sync/no-mutation fixture |
| `mydocs/working/task_m040_375_stage2.md` | 신규 | 구현과 검증 결과 기록 |
| `mydocs/orders/20260813.md` | 수정 | #375를 Stage 2 완료, Stage 3 진행 상태로 갱신 |

## 변경 내용

### Optional strict verifier interface

기존 positional resource path와 `--resource-dir`, `--tag`, `--commit` interface를 유지하고 다음 option을 추가했다.

```text
--upstream-dir DIR  Compare manifest source_cargo_lock_sha256 with DIR/Cargo.lock.
                    When set, the manifest fingerprint and upstream Cargo.lock are required.
```

Upstream 입력이 없으면 기존과 같이 fingerprint field가 없는 legacy resource를 허용하고, field가 있으면 lowercase 64자 SHA-256 형식을 검사한다.

Upstream 입력이 있으면 다음 조건을 blocking gate로 적용한다.

1. Manifest fingerprint field 존재
2. Fingerprint lowercase 64자 형식
3. Upstream directory 존재
4. Root `Cargo.lock` file 존재
5. Manifest value와 `shasum -a 256` actual value 일치

### Mismatch 진단

Actual hash mismatch는 format 오류와 다른 메시지로 실패하며 세 값을 표시한다.

```text
FAIL: manifest source_cargo_lock_sha256 does not match upstream root Cargo.lock
Manifest value: <manifest sha256>
Actual value:   <computed sha256>
Cargo.lock:     <target checkout path>/Cargo.lock
```

Manifest field 누락, upstream directory 누락, root `Cargo.lock` 누락, `--upstream-dir` option 값 누락도 각각 별도 메시지로 실패한다.

### Sync writer self-check

`scripts/sync-rhwp-studio.sh`는 이미 upstream root `Cargo.lock`을 읽어 manifest에 기록한다. 최종 verifier 호출에 같은 `UPSTREAM_DIR`을 전달해 기록된 값이 실제 source file과 일치하는지 즉시 확인한다.

```text
scripts/verify-rhwp-studio-assets.sh \
  --resource-dir <target> \
  --tag <tag> \
  --commit <commit> \
  --upstream-dir <target checkout>
```

### Isolated fixture

신규 fixture는 `mktemp -d` 아래에 최소 resource와 git upstream checkout을 만들고 다음 case를 확인한다.

| Case | 기대 결과 |
|------|-----------|
| Legacy manifest, resource-only | 성공 |
| Valid fingerprint + matching upstream | 성공, actual compared path 출력 |
| Malformed fingerprint | 형식 오류 실패 |
| Valid fingerprint mismatch | provenance mismatch + expected/actual/path 진단 |
| Strict mode + missing manifest field | field 누락 실패 |
| Missing upstream directory | directory 누락 실패 |
| Missing upstream root Cargo.lock | file 누락 실패 |
| `--upstream-dir` missing value | interface 오류 실패 |
| `sync-rhwp-studio.sh --check` | generated fingerprint actual self-check와 sync check 성공 |
| Production default verifier | 성공, production manifest byte 무변경 |

## 본문 변경 정도 / 본문 무손실 여부

`Sources/HostApp/Resources/rhwp-studio/**`, `rhwp-core.lock`, `RustBridge/**`, `Frameworks/**`는 변경하지 않았다. Fixture는 production manifest를 snapshot한 뒤 기본 verifier를 실행하고 `cmp`로 byte 무변경을 확인한다. Sync 검증도 fixture target에서 `--check` mode로 실행했다.

## 검증 결과

```text
$ bash -n scripts/verify-rhwp-studio-assets.sh \
    scripts/sync-rhwp-studio.sh \
    scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
통과

$ shellcheck scripts/verify-rhwp-studio-assets.sh \
    scripts/sync-rhwp-studio.sh \
    scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
통과

$ scripts/verify-rhwp-studio-assets.sh --help
--upstream-dir DIR interface 확인

$ scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
OK: rhwp-studio Cargo.lock fingerprint verification fixtures passed

$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at .../Sources/HostApp/Resources/rhwp-studio

$ git diff --check
통과
```

## 잔여 위험

- Stage 2 시점에는 신규 fixture가 PR CI와 upstream sync preflight에서 아직 호출되지 않는다. Stage 3에서 연결해야 지속 gate가 된다.
- Full sync workflow의 sync self-check는 새 interface 덕분에 strict하지만, 이어지는 explicit verifier 호출과 verification summary는 아직 resource-only 명령을 표시한다.
- `shasum`은 기존 manifest writer와 같은 계산 계약이다. Ubuntu fixture runner 가용성은 Stage 3 PR CI 연결과 GitHub-hosted check에서 최종 확인한다.

## 다음 단계 영향

Stage 3에서는 신규 fixture를 Ubuntu PR CI와 upstream preflight에 연결하고, full sync explicit verifier에 `--upstream-dir`을 전달한다. PR body checklist는 actual hash 수동 계산 대신 자동 verifier 결과 확인 문구로 정렬한다.

## 승인 요청

작업지시자가 PR 생성까지 진행하도록 승인한 범위에 따라 Stage 3 — sync workflow와 generated PR body 연결로 진행한다.
