# Task #375 Stage 1 완료보고서

## 단계 목적

`source_cargo_lock_sha256`의 생성·검증과 upstream sync workflow 호출 경로를 조사하고, 실제 target root `Cargo.lock` 비교를 추가해도 기존 app/release 검증을 깨뜨리지 않는 strict/compatibility 계약을 확정했다. 이 단계에서는 제품·helper·workflow를 수정하지 않았다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/plans/task_m040_375_impl.md` | 신규 | 4단계 구현계획, verifier mode, failure taxonomy와 수용 기준 |
| `mydocs/working/task_m040_375_stage1.md` | 신규 | 현행 provenance 호출 graph와 설계 결정 기록 |
| `mydocs/orders/20260813.md` | 수정 | #375를 Stage 1 완료, Stage 2 진행 상태로 갱신 |

## 조사 결과

### Manifest 생성과 현재 bundled 기준

- `scripts/sync-rhwp-studio.sh`는 target checkout `HEAD`가 expected commit인지 확인한 뒤 root `Cargo.lock` 존재를 요구한다.
- 같은 script가 `shasum -a 256 "$UPSTREAM_DIR/Cargo.lock"` 값을 manifest top-level `source_cargo_lock_sha256`으로 기록한다.
- 기록 후 `scripts/verify-rhwp-studio-assets.sh`를 실행하지만 현재는 `--upstream-dir` 입력이 없어 64자 lowercase 형식만 self-check한다.
- 현재 bundled manifest는 `v0.8.2`, commit `9b16aa9e...`, fingerprint `64ff4041...`을 기록한다. Task #375에서는 이 production 값과 asset을 변경하지 않는다.

### Verifier 호출 graph

Repository에서 `verify-rhwp-studio-assets.sh` 호출은 workflow/helper/smoke에 걸쳐 10곳 확인됐다.

| 호출 경로 | Upstream checkout | 필요한 mode |
|----------|-------------------|-------------|
| `sync-rhwp-studio.sh` 최종 self-check | 있음 | strict actual hash 비교 |
| `rhwp-upstream-sync-pr.yml` create candidate | 있음 | strict actual hash 비교 |
| PR CI macOS validation | 없음 | resource-only compatibility |
| Release/app bundle/public runbook | 없음 | resource-only compatibility |
| Visual/fallback smoke helper | 없음 | resource-only compatibility |

따라서 upstream 입력을 전역 필수화하면 app bundle과 일반 PR CI가 깨진다. Optional `--upstream-dir`을 strict mode opt-in으로 두는 것이 호출자 책임과 일치한다.

### Workflow checkout lifecycle

현재 `.github/workflows/rhwp-upstream-sync-pr.yml`에는 studio-only PR job이 없고 full sync candidate 경로 하나가 있다.

1. `resolve-target`이 target checkout을 clone해 impact를 조사한다.
2. `build-studio-assets`가 별도 checkout에서 WASM/studio를 만들고 `pkg`, `rhwp-studio/dist`만 artifact로 올린다.
3. `create-full-sync-pr`이 target commit을 다시 clone해 checkout 전체를 복원한 뒤 build artifact를 덮어쓴다.
4. 따라서 create job의 `upstream_dir`에는 root `Cargo.lock`, `.git`, built `pkg/dist`가 모두 존재한다.
5. 이 job은 `sync-rhwp-studio.sh --upstream-dir`에는 경로를 전달하지만 그 다음 explicit verifier에는 전달하지 않는다.

Strict comparison은 새 checkout이나 artifact 추가 없이 create job과 sync self-check 두 지점에 연결할 수 있다.

### PR body와 CI 경계

- Full/studio PR body helper는 `source_cargo_lock_sha256` 실제 일치를 maintainer 수동 checkbox로 요구한다.
- Full sync workflow verification file은 resource verifier 성공을 표시하지만 현재 명령 문자열에 target checkout 비교가 드러나지 않는다.
- General PR CI의 macOS verifier는 candidate branch에 upstream checkout이 없으므로 actual hash 비교의 진실 원천이 될 수 없다.
- 대신 Ubuntu `script-checks`에서 isolated fixture를 실행하면 helper contract 회귀를 모든 PR에서 조기에 차단할 수 있다.
- 신규 fixture는 `scripts/ci/**` 분류로 release checks는 켜지지만 macOS/Rust gate는 자동으로 켜지지 않으므로 core provenance explicit path에 추가해야 한다.

### 선행 작업과 후속 경계

- Task #370/PR #374는 fingerprint 기록과 optional 형식 검증까지만 소유했다.
- Task #439/PR #464는 core build-info canonical gate를 먼저 merge했다.
- 열린 PR #463은 두 gate 완료 전 생성된 v0.8.4 candidate이며 Task #375에서 수정·close하지 않는다. Task #375 merge 후 별도 승인으로 정리하고 workflow를 재실행한다.

## 설계 결정

1. `verify-rhwp-studio-assets.sh`에 optional `--upstream-dir DIR`을 추가한다.
2. Upstream 입력이 없으면 fingerprint field 부재를 허용하고, 있으면 형식만 검증하는 기존 mode를 유지한다.
3. Upstream 입력이 있으면 directory, root `Cargo.lock`, manifest field 존재, 형식, actual hash 일치를 모두 요구한다.
4. Checkout HEAD/tag 검증은 sync script가 계속 소유하며 asset verifier는 Cargo.lock file provenance에 집중한다.
5. Mismatch는 manifest value, actual value, Cargo.lock path를 구분해 출력한다.
6. Sync writer 최종 verifier와 full sync explicit verifier 모두 같은 target directory를 넘긴다.
7. Full/studio PR body는 수동 hash 재계산 대신 automatic verifier result 확인을 요구한다.
8. Minimal temporary resource/upstream fixture를 신규 CI test로 두고 production resource의 전후 byte 무손실을 확인한다.

## 본문 변경 정도 / 본문 무손실 여부

Stage 1에서는 계획서·보고서·오늘할일만 변경했다. `scripts/**`, `.github/workflows/**`, `Sources/**`, `RustBridge/**`, `rhwp-core.lock`, bundled `rhwp-studio` manifest/asset은 변경하지 않았다.

## 검증 결과

```text
$ rg -n "source_cargo_lock_sha256|verify-rhwp-studio-assets|sync-rhwp-studio|upstream_dir" ...
73 matching lines recorded

$ rg -n "scripts/verify-rhwp-studio-assets.sh" .github/workflows scripts | wc -l
10

$ git diff --check
통과
```

구현계획서는 Stage 1~4, strict/compatibility mode 표, failure taxonomy, 단계별 수용 기준과 최종 PR 절차를 포함한다.

## 잔여 위험

- Writer와 verifier가 같은 `shasum` 계약을 사용하더라도 비교 대상 path가 달라지면 잘못된 mismatch가 발생할 수 있어 fixture에서 실제 path를 고정해야 한다.
- Strict mode에서 field 부재를 호환 성공으로 처리하면 candidate provenance 누락이 계속 통과하므로 upstream 입력 시 field를 필수화해야 한다.
- `write-rhwp-studio-sync-pr-body.sh`는 현재 workflow에서 직접 호출되지 않지만 재사용 가능한 helper 계약이므로 full helper와 함께 문구를 정렬해야 한다.

## 다음 단계 영향

Stage 2에서는 verifier interface와 strict 비교, sync self-check 전달, isolated fixture만 구현한다. Workflow, PR body, classification은 Stage 3까지 변경하지 않는다.

## 승인 요청

작업지시자가 PR 생성까지 진행하도록 승인한 범위에 따라 Stage 2 — verifier 실제 비교와 isolated fixture 구현으로 진행한다.
