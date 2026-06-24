# Task M040 #370 Stage 4 완료보고서

## 단계 목적

upstream release diff와 자동 PR body에서 root `Cargo.lock` 변경을 dependency graph/build input 변화로 명확히 표시하고, Stage 3에서 추가한 `source_cargo_lock_sha256` provenance를 reviewer checklist에 연결했다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `scripts/ci/detect-rhwp-studio-impact.sh` | 수정 | `Cargo.lock` impact reason을 `Rust dependency graph lockfile`로 구체화 |
| `scripts/ci/write-rhwp-full-sync-pr-body.sh` | 수정 | full sync scope와 maintainer checklist에 upstream root `Cargo.lock` fingerprint 확인 추가 |
| `scripts/ci/write-rhwp-studio-sync-pr-body.sh` | 수정 | bundled studio sync checklist에 `source_cargo_lock_sha256` 확인 추가 |
| `scripts/ci/write-release-delta-checklist.sh` | 수정 | sync/provenance helper 변경을 `rhwp core/viewer provenance`로 분류하고 release owner 보정 항목 추가 |
| `mydocs/working/task_m040_370_stage4.md` | 신규 | Stage 4 변경과 검증 결과 기록 |
| `mydocs/orders/20260624.md` | 수정 | #370 비고를 Stage 4 완료보고서 승인 대기로 갱신 |

## 변경 내용

### upstream impact reason

`scripts/ci/detect-rhwp-studio-impact.sh`에서 root `Cargo.lock`을 일반 Rust/core build input과 분리했다.

```text
Cargo.lock)
  echo "Rust dependency graph lockfile"
  return 0
  ;;
```

이제 upstream diff에 `Cargo.lock`만 바뀐 경우 reviewer가 dependency graph lockfile 변화임을 바로 볼 수 있다.

### PR body checklist

full upstream sync PR body에는 bundled `rhwp-studio` manifest가 target upstream root `Cargo.lock` fingerprint를 기록한다는 scope 문구와 maintainer checklist를 추가했다.

studio-only sync PR body에는 manifest의 `source_cargo_lock_sha256` 값이 target upstream root `Cargo.lock`과 맞는지 확인하는 checklist를 추가했다.

### release delta checklist

`scripts/ci/write-release-delta-checklist.sh`의 `rhwp core/viewer provenance` 분류에 다음 helper 변경을 포함했다.

- `scripts/ci/detect-rhwp-studio-impact.sh`
- `scripts/ci/write-rhwp-full-sync-pr-body.sh`
- `scripts/ci/write-rhwp-studio-sync-pr-body.sh`

release owner 보정 항목에는 `Cargo.lock` 또는 `source_cargo_lock_sha256` 관련 변경이 dependency graph/provenance 변화인지 확인하라는 문구를 추가했다.

## 본문 변경 정도 / 본문 무손실 여부

changed path 원문과 impact path 목록은 유지했다. 자동 분류 사유와 reviewer checklist만 보강했으며, upstream diff path 자체를 필터링하거나 숨기지 않는다.

## 검증 결과

```text
$ bash -n scripts/ci/detect-rhwp-studio-impact.sh scripts/ci/write-rhwp-full-sync-pr-body.sh scripts/ci/write-rhwp-studio-sync-pr-body.sh scripts/ci/write-release-delta-checklist.sh
통과
```

```text
$ git diff --check
통과
```

```text
$ rg -n "Cargo.lock|dependency graph|source_cargo_lock_sha256|provenance" scripts/ci
Cargo.lock reason, PR body checklist, release delta provenance 분류 문구 확인
```

fixture upstream repo에서 `Cargo.lock`만 바뀐 commit delta를 만들고 impact detection을 실행했다.

```text
$ scripts/ci/detect-rhwp-studio-impact.sh --upstream-dir /private/tmp/rhwp-mac-task370-stage3-fixture --current-tag v9.9.8 --current-commit e18631f8b85adb6d3bfc145700b4aaeb8ad1e6db --target-tag v9.9.9 --target-commit b21da106ef4e4e6c6f34ce34994aa015a322b947 --output-dir /private/tmp/rhwp-mac-task370-stage4-impact
INFO: rhwp-studio impact paths:
INFO:   Cargo.lock (Rust dependency graph lockfile)
OK: wrote rhwp-studio impact analysis to /private/tmp/rhwp-mac-task370-stage4-impact
```

생성된 impact 파일을 입력으로 full sync/studio sync PR body smoke를 실행했다.

```text
$ scripts/ci/write-rhwp-full-sync-pr-body.sh --output /private/tmp/rhwp-mac-task370-stage4-full-body.md ...
통과

$ scripts/ci/write-rhwp-studio-sync-pr-body.sh --output /private/tmp/rhwp-mac-task370-stage4-studio-body.md ...
통과
```

생성된 PR body에서 새 문구가 확인됐다.

```text
/private/tmp/rhwp-mac-task370-stage4-full-body.md:23:- Bundled `rhwp-studio` manifest records the target upstream root `Cargo.lock` fingerprint.
/private/tmp/rhwp-mac-task370-stage4-full-body.md:28:- `Cargo.lock` - Rust dependency graph lockfile
/private/tmp/rhwp-mac-task370-stage4-full-body.md:46:- [ ] bundled `rhwp-studio` manifest `source_cargo_lock_sha256` matches the target upstream root `Cargo.lock`.
/private/tmp/rhwp-mac-task370-stage4-studio-body.md:19:- `Cargo.lock` - Rust dependency graph lockfile
/private/tmp/rhwp-mac-task370-stage4-studio-body.md:36:- [ ] bundled `rhwp-studio` manifest의 `source_cargo_lock_sha256`이 target upstream root `Cargo.lock`과 맞는지 확인
```

## 잔여 위험

- release delta checklist는 path 기반 자동 분류 초안이므로 실제 release owner 보정이 계속 필요하다.
- 이번 단계는 PR body와 checklist 문구를 보강했을 뿐, upstream sync workflow를 실제 원격 release에 대해 실행하지 않았다.
- `source_cargo_lock_sha256` 값 자체의 실제 hash 일치 여부는 Stage 3 sync 산출물과 다음 실제 sync review에서 확인한다.

## 다음 단계 영향

Stage 5에서는 upstream root `Cargo.lock`, `RustBridge/Cargo.lock`, `rhwp-core.lock`, bundled manifest fingerprint의 역할 차이를 운영 문서에 반영하고 최종 검증/보고서 작성을 진행한다.

## 승인 요청

Stage 4 결과를 승인받은 뒤 Stage 5 - 문서 검증과 최종 보고로 진행한다.
