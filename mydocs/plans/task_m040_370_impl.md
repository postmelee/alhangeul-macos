# Task #370 구현 계획서

본 문서는 [`task_m040_370.md`](task_m040_370.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- Worktree: `/Users/melee/Documents/projects/rhwp-mac`
- Branch: `local/task370`
- 기준 브랜치: `devel`
- 기준 이슈: [#370](https://github.com/postmelee/alhangeul-macos/issues/370)
- 마일스톤: M040 (`v0.4`)
- 범위: upstream `Cargo.lock` 추적 전환을 downstream provenance와 locked build 검증에 반영

## 구현 원칙

- upstream root `Cargo.lock`은 upstream release checkout의 build input fingerprint로만 다룬다.
- downstream native bridge 기준 lock은 계속 `RustBridge/Cargo.lock`이고, `rhwp-core.lock`은 앱 저장소의 source/artifact provenance 기준이다.
- 이번 task에서 `rhwp v0.7.17` 이상으로 core pin, `Rhwp.xcframework`, bundled `rhwp-studio` asset을 갱신하지 않는다.
- manifest schema 보강은 새 sync 결과에 적용하되, 현재 bundled asset 검증이 갑자기 깨지지 않도록 기존 manifest 호환 경로를 설계한다.
- PR body와 delta checklist는 `Cargo.lock` 변경을 사용자-facing 기능 변경이 아니라 dependency graph/build input 변경으로 표현한다.

## Stage 1 — 현재 lock/provenance 경로 조사와 설계 확정

### 목표

- 기존 스크립트와 문서에서 lockfile, source provenance, studio manifest가 어떤 역할을 하는지 정리한다.
- Stage 2~4에서 수정할 파일과 호환성 방침을 확정한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/plans/task_m040_370_impl.md` | 구현계획서 작성 | 현재 단계 산출물 |
| `mydocs/working/task_m040_370_stage1.md` | Stage 1 완료보고서 작성 | 조사 결과와 설계 결정 기록 |

### 확인할 자료

- Issue #370 본문
- `mydocs/plans/task_m040_370.md`
- `scripts/build-rust-macos.sh`
- `scripts/sync-rhwp-studio.sh`
- `scripts/verify-rhwp-studio-assets.sh`
- `scripts/ci/detect-rhwp-studio-impact.sh`
- `scripts/ci/write-rhwp-full-sync-pr-body.sh`
- `scripts/ci/write-rhwp-studio-sync-pr-body.sh`
- `scripts/ci/write-release-delta-checklist.sh`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/tech/core_release_compatibility.md`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`

### 설계 결정 기준

- `scripts/build-rust-macos.sh`의 두 `cargo build` 명령은 `--locked`를 붙여도 dependency graph를 바꾸지 않는다.
- `scripts/sync-rhwp-studio.sh`는 upstream checkout에 root `Cargo.lock`이 있으면 sha256을 manifest에 기록한다.
- 현재 bundled manifest에는 새 필드가 없으므로 `scripts/verify-rhwp-studio-assets.sh`의 기본 검증은 기존 asset을 통과해야 한다.
- sync script가 생성한 새 manifest에 대해서는 `source_cargo_lock_sha256` 누락을 실패로 처리하는 방향을 검토한다.
- impact detection의 `Cargo.lock` reason은 일반 `Rust/core source or build input`보다 명시적인 dependency graph 문구가 적합하다.

### 단계 검증

```bash
git diff --check
rg -n "Cargo.lock|--locked|source_release_tag|source_resolved_commit|impact_reason|rhwp core/viewer provenance" scripts mydocs/manual mydocs/tech Sources/HostApp/Resources/rhwp-studio/manifest.json
```

### 커밋 메시지

```text
Task #370 Stage 1: lock provenance 경로 조사
```

## Stage 2 — RustBridge locked build 검증 보강

### 목표

- RustBridge staticlib build가 `RustBridge/Cargo.lock`을 실제 빌드 gate로 사용하도록 `--locked`를 적용한다.
- 기존 `rhwp-core.lock` provenance 검증과 오류 분류를 유지한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `scripts/build-rust-macos.sh` | `cargo build --locked` 적용 | arm64/x86_64 두 target 모두 |
| `mydocs/working/task_m040_370_stage2.md` | Stage 2 완료보고서 작성 | 적용 범위와 검증 결과 기록 |

### 반영 기준

- `cargo build --release --manifest-path "$BRIDGE_ROOT/Cargo.toml" --target ...` 두 곳에 `--locked`를 추가한다.
- `cargo generate-lockfile`을 수행하는 update script는 그대로 유지한다.
- `--verify-lock`의 source provenance, generated header, FFI symbol 검증 흐름을 바꾸지 않는다.
- 실패 안내가 필요하면 locked build 실패가 lock drift라는 점을 보고서에 설명한다.

### 단계 검증

```bash
bash -n scripts/build-rust-macos.sh
git diff --check
rg -n "cargo build --release --locked" scripts/build-rust-macos.sh
scripts/build-rust-macos.sh --verify-lock
```

### 커밋 메시지

```text
Task #370 Stage 2: RustBridge locked build 검증 적용
```

## Stage 3 — rhwp-studio manifest Cargo.lock provenance 보강

### 목표

- bundled `rhwp-studio`/WASM manifest가 upstream root `Cargo.lock` fingerprint를 기록할 수 있게 한다.
- 현재 저장소에 이미 bundled 된 manifest 검증은 유지하면서, 새 sync 산출물의 provenance 검증을 추가한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `scripts/sync-rhwp-studio.sh` | upstream root `Cargo.lock` sha256 산출과 manifest 필드 기록 | `source_cargo_lock_sha256` 후보 |
| `scripts/verify-rhwp-studio-assets.sh` | manifest field 읽기/검증 보강 | 기존 manifest 호환 고려 |
| `mydocs/working/task_m040_370_stage3.md` | Stage 3 완료보고서 작성 | manifest schema와 호환성 판단 기록 |

### 반영 기준

- sync 대상 upstream checkout이 expected commit과 일치한 뒤 root `Cargo.lock` 존재 여부를 확인한다.
- root `Cargo.lock`이 없으면 새 sync는 실패시키거나 명확한 경고 후 실패로 처리한다. #1423 이후 release를 전제로 하는 sync provenance 보강이므로 실패 쪽을 우선 검토한다.
- manifest에는 `source_cargo_lock_sha256`처럼 source provenance 영역에 가까운 top-level field를 추가한다.
- verify script는 현재 bundled manifest처럼 필드가 없는 경우 기본 검증을 통과시키되, 필드가 있으면 64자 sha256 형식과 비어 있지 않음을 확인한다.
- `sync-rhwp-studio.sh --check`가 만든 새 manifest는 verify script를 통과해야 한다.

### 단계 검증

```bash
bash -n scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh
git diff --check
rg -n "source_cargo_lock_sha256|Cargo.lock|manifest" scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
```

가능하면 upstream checkout이 준비된 환경에서 추가로 실행한다.

```bash
scripts/sync-rhwp-studio.sh --check --upstream-dir build.noindex/rhwp-upstream --tag <target-tag> --commit <target-commit>
```

### 커밋 메시지

```text
Task #370 Stage 3: rhwp-studio Cargo.lock provenance 기록
```

## Stage 4 — upstream release diff와 PR body 가시성 보강

### 목표

- upstream release diff에서 `Cargo.lock` 변경을 dependency graph/build input 변화로 명확히 표시한다.
- full sync와 studio sync PR body, release delta checklist가 새 provenance 정보를 검토 항목으로 보여주게 한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `scripts/ci/detect-rhwp-studio-impact.sh` | `Cargo.lock` impact reason 구체화 | dependency graph 문구 |
| `scripts/ci/write-rhwp-full-sync-pr-body.sh` | PR body 요약/체크리스트 보강 | full sync 경로 |
| `scripts/ci/write-rhwp-studio-sync-pr-body.sh` | PR body 요약/체크리스트 보강 | studio sync 경로 |
| `scripts/ci/write-release-delta-checklist.sh` | release checklist 분류 보강 | downstream release diff |
| `mydocs/working/task_m040_370_stage4.md` | Stage 4 완료보고서 작성 | 출력 예시와 검증 결과 기록 |

### 반영 기준

- `Cargo.lock` path reason은 `Rust dependency graph lockfile`처럼 reviewer가 의미를 바로 알 수 있게 한다.
- PR body에는 manifest tag/commit 확인과 함께 Cargo.lock fingerprint 확인 항목을 추가한다.
- release delta checklist의 `rhwp core/viewer provenance` 분류에 manifest/sync script 변경과 lock provenance 변경이 드러나게 한다.
- changed path 목록의 원문은 유지하고, 자동 분류 결과만 보강한다.

### 단계 검증

```bash
bash -n scripts/ci/detect-rhwp-studio-impact.sh scripts/ci/write-rhwp-full-sync-pr-body.sh scripts/ci/write-rhwp-studio-sync-pr-body.sh scripts/ci/write-release-delta-checklist.sh
git diff --check
rg -n "Cargo.lock|dependency graph|source_cargo_lock_sha256|provenance" scripts/ci
```

fixture를 만들 수 있으면 `Cargo.lock`만 들어 있는 changed paths/impact details 파일로 PR body 생성 스모크를 수행한다.

### 커밋 메시지

```text
Task #370 Stage 4: upstream Cargo.lock diff 가시성 보강
```

## Stage 5 — 문서 검증과 최종 보고

### 목표

- upstream/downstream lockfile 역할 차이를 운영 문서에 반영한다.
- 전체 변경을 검증하고 최종 결과보고서를 작성한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/core_dependency_operation_guide.md` | upstream root lock과 downstream lock 역할 구분 추가 | core 운영 문서 |
| `mydocs/manual/build_run_guide.md` | `--locked` build 기준 보강 | build/run 문서 |
| `mydocs/tech/core_release_compatibility.md` | release compatibility 관점의 lockfile 역할 보강 | tech 기준 |
| `mydocs/report/task_m040_370_report.md` | 최종 결과보고서 작성 | 최종 산출물 |
| `mydocs/orders/20260624.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
git status --short --branch
git diff --check
bash -n scripts/build-rust-macos.sh scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh scripts/ci/detect-rhwp-studio-impact.sh scripts/ci/write-rhwp-full-sync-pr-body.sh scripts/ci/write-rhwp-studio-sync-pr-body.sh scripts/ci/write-release-delta-checklist.sh
scripts/verify-rhwp-studio-assets.sh
scripts/build-rust-macos.sh --verify-lock
rg -n "Cargo.lock|--locked|source_cargo_lock_sha256|dependency graph|provenance" scripts mydocs/manual mydocs/tech
```

### 실제 실행 제외 확인

이번 task에서는 다음을 실행하지 않는다.

- `scripts/update-rhwp-core.sh --channel stable --tag v0.7.17`
- `scripts/build-rust-macos.sh --update-lock`
- bundled `Sources/HostApp/Resources/rhwp-studio` asset 갱신
- release workflow dispatch
- public DMG signing/notarization/Homebrew 반영

### 커밋 메시지

```text
Task #370 Stage 5 + 최종 보고서: Cargo.lock provenance 검증 보강 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다.
