# Task M040 #370 Stage 3 완료보고서

## 단계 목적

`rhwp-studio` sync manifest에 upstream root `Cargo.lock` fingerprint를 기록할 수 있게 하고, asset verify script가 기존 manifest 호환을 유지하면서 새 fingerprint 필드를 검증하도록 보강했다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `scripts/sync-rhwp-studio.sh` | 수정 | upstream root `Cargo.lock` 필수 확인과 `source_cargo_lock_sha256` manifest 기록 추가 |
| `scripts/verify-rhwp-studio-assets.sh` | 수정 | optional `source_cargo_lock_sha256` sha256 형식 검증 추가 |
| `mydocs/working/task_m040_370_stage3.md` | 신규 | Stage 3 변경과 검증 결과 기록 |
| `mydocs/orders/20260624.md` | 수정 | #370 비고를 Stage 3 완료보고서 승인 대기로 갱신 |

## 변경 내용

### sync script

`scripts/sync-rhwp-studio.sh`는 expected commit 확인 후 upstream checkout root의 `Cargo.lock` 존재를 확인한다. 파일이 없으면 sync를 중단한다.

```text
if [ ! -f "$UPSTREAM_DIR/Cargo.lock" ]; then
  fail "missing upstream root Cargo.lock: $UPSTREAM_DIR/Cargo.lock"
fi
source_cargo_lock_sha256="$(shasum -a 256 "$UPSTREAM_DIR/Cargo.lock" | awk '{print $1}')"
```

manifest에는 `source_cargo_lock_sha256` top-level field를 추가했다.

### verify script

`scripts/verify-rhwp-studio-assets.sh`에는 `validate_sha256` helper를 추가했다. 현재 bundled manifest처럼 `source_cargo_lock_sha256`이 없는 경우는 기존 검증을 통과한다. 새 field가 있으면 lowercase 64자 sha256 hex 형식이어야 한다.

```text
if source_cargo_lock_sha256="$(manifest_field "$RESOURCE_DIR/manifest.json" source_cargo_lock_sha256)"; then
  validate_sha256 source_cargo_lock_sha256 "$source_cargo_lock_sha256"
fi
```

## 본문 변경 정도 / 본문 무손실 여부

기존 bundled `Sources/HostApp/Resources/rhwp-studio/manifest.json`은 변경하지 않았다. 따라서 현재 앱 asset provenance는 그대로 `v0.7.16`/`de02159...` 기준이며, 새 field는 다음 sync 산출물부터 기록된다.

## 검증 결과

```text
$ bash -n scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
통과
```

```text
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

현재 bundled manifest에는 `source_cargo_lock_sha256`이 없지만 호환 경로로 기존 asset 검증이 통과했다.

```text
$ git diff --check
통과
```

```text
$ rg -n "source_cargo_lock_sha256|Cargo.lock|manifest" scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
scripts/sync-rhwp-studio.sh:171:if [ ! -f "$UPSTREAM_DIR/Cargo.lock" ]; then
scripts/sync-rhwp-studio.sh:172:  fail "missing upstream root Cargo.lock: $UPSTREAM_DIR/Cargo.lock"
scripts/sync-rhwp-studio.sh:174:source_cargo_lock_sha256="$(shasum -a 256 "$UPSTREAM_DIR/Cargo.lock" | awk '{print $1}')"
scripts/sync-rhwp-studio.sh:240:  "source_cargo_lock_sha256": "$source_cargo_lock_sha256",
scripts/verify-rhwp-studio-assets.sh:140:if source_cargo_lock_sha256="$(manifest_field "$RESOURCE_DIR/manifest.json" source_cargo_lock_sha256)"; then
scripts/verify-rhwp-studio-assets.sh:141:  validate_sha256 source_cargo_lock_sha256 "$source_cargo_lock_sha256"
```

실제 `build.noindex/rhwp-upstream` checkout은 준비되어 있지 않았다. 대신 `/private/tmp/rhwp-mac-task370-stage3-fixture`에 최소 upstream fixture를 만들고 `--check` 경로를 검증했다.

```text
$ scripts/sync-rhwp-studio.sh --check --upstream-dir /private/tmp/rhwp-mac-task370-stage3-fixture --tag v9.9.9 --commit e18631f8b85adb6d3bfc145700b4aaeb8ad1e6db
rsync(...): warning: .../build.noindex/rhwp-studio-check.../fonts: not empty, cannot delete
OK: rhwp-studio assets verified at .../build.noindex/rhwp-studio-check...
OK: rhwp-studio sync check passed for v9.9.9 at e18631f8b85adb6d3bfc145700b4aaeb8ad1e6db
```

`rsync` 경고는 check target이 기존 bundled asset을 복사한 뒤 excluded `fonts` 디렉터리를 보존하면서 발생한 삭제 경고다. 명령은 exit code 0으로 완료했고, 새 manifest field를 포함한 check target verify가 통과했다.

## 잔여 위험

- 새 sync 정책은 upstream root `Cargo.lock`이 없는 checkout에서 실패한다. 이는 #1423 이후 release sync provenance 보강 목적에는 맞지만, 과거 release를 재동기화할 때는 별도 판단이 필요하다.
- 현재 bundled manifest에는 `source_cargo_lock_sha256`이 없으므로, 다음 실제 sync 전까지 release note나 PR body에서 새 fingerprint를 보여주지는 못한다.
- `sync-rhwp-studio.sh --check`의 excluded `fonts` 보존 경고는 기존 rsync delete 동작에서 나온 것으로 이번 task에서 수정하지 않았다.

## 다음 단계 영향

Stage 4에서는 upstream diff/PR body 쪽에서 `Cargo.lock` 변경을 dependency graph/build input 변화로 더 명확히 표시한다. Stage 3에서 추가한 `source_cargo_lock_sha256`은 full sync/studio sync PR checklist에 연결할 수 있다.

## 승인 요청

Stage 3 결과를 승인받은 뒤 Stage 4 — upstream release diff와 PR body 가시성 보강으로 진행한다.
