# Task M040 #370 Stage 1 완료보고서

## 단계 목적

현재 downstream 앱의 lock/provenance 경로를 조사하고, upstream root `Cargo.lock` 추적 전환을 어느 지점에 반영할지 확정했다. 이 단계에서는 코드와 스크립트를 수정하지 않고 Stage 2~4 구현 기준만 정리했다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/working/task_m040_370_stage1.md` | 신규 | lock/provenance 경로 조사 결과와 설계 결정 기록 |
| `mydocs/orders/20260624.md` | 수정 | #370 비고를 Stage 1 완료보고서 승인 대기로 갱신 |

## 조사 결과

### RustBridge lock/provenance

- `scripts/build-rust-macos.sh`는 `CARGO_LOCK="$BRIDGE_ROOT/Cargo.lock"`과 `LOCK_FILE="$ROOT/rhwp-core.lock"`을 별도 기준으로 둔다.
- `RustBridge/Cargo.lock`의 `rhwp` package source에서 repo, ref query, resolved commit을 추출하고, `rhwp-core.lock`의 repo/ref kind/tag/commit과 대조한다.
- `--verify-lock`은 source provenance, enabled feature, `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h` reference metadata를 검증한다.
- 실제 staticlib build 명령은 현재 `cargo build --release --manifest-path ... --target ...` 형태이며 `--locked`가 없다. Stage 2에서는 이 두 build 명령에 `--locked`를 추가하는 것이 적절하다.

### core update 경로

- `scripts/update-rhwp-core.sh`는 target ref 확인 후 `cargo generate-lockfile --manifest-path "$CARGO_TOML"`로 downstream `RustBridge/Cargo.lock`을 갱신한다.
- 이후 `RustBridge/Cargo.lock`의 repo/commit/tag를 target과 대조하고, `rhwp-core.lock` skeleton을 갱신한다.
- 따라서 upstream root `Cargo.lock`은 이 경로의 대체 입력이 아니다. downstream native bridge lock은 계속 `RustBridge/Cargo.lock`이다.

### rhwp-studio/WASM sync 경로

- `scripts/sync-rhwp-studio.sh`는 upstream checkout의 `HEAD`가 expected commit과 일치하는지 확인하고, `pkg/rhwp.js`, `pkg/rhwp_bg.wasm`, `rhwp-studio/dist/index.html` 존재를 요구한다.
- manifest에는 `source_release_tag`, `source_resolved_commit`, build command, entrypoint asset sha256이 기록된다.
- 현재 manifest에는 upstream root `Cargo.lock` fingerprint가 없다.
- Stage 3에서는 sync 시 upstream root `Cargo.lock` sha256을 산출해 manifest top-level field로 기록한다.

### bundled asset 검증 경로

- `scripts/verify-rhwp-studio-assets.sh`는 manifest에서 `source_release_tag`, `source_resolved_commit`, build command 필드를 읽어 검증한다.
- 현재 bundled `Sources/HostApp/Resources/rhwp-studio/manifest.json`은 `v0.7.16`/`de02159...` 기준이고, 새 Cargo.lock fingerprint 필드는 없다.
- 따라서 Stage 3의 verify script 보강은 기존 bundled manifest를 통과시키는 호환 경로를 유지해야 한다. 새 sync 산출물에는 필드를 기록하고 형식 검증을 추가한다.

### upstream impact/PR body/release checklist

- `scripts/ci/detect-rhwp-studio-impact.sh`는 이미 root `Cargo.lock`을 impact path로 분류하지만 reason은 `Rust/core source or build input`으로 넓다.
- full sync와 studio sync PR body는 impact details를 그대로 bullet로 출력한다.
- full sync checklist는 `rhwp-core.lock`, `RustBridge/Cargo.lock`, bundled manifest tag/commit 확인을 요구하지만, upstream root `Cargo.lock` fingerprint 확인은 없다.
- release delta checklist의 `rhwp core/viewer provenance` 분류는 downstream 파일 중심이다. Stage 4에서는 `Cargo.lock` 변경 reason과 PR checklist를 dependency graph/provenance 관점으로 좁힌다.

### 문서 기준

- `build_run_guide.md`, `core_dependency_operation_guide.md`, `core_release_compatibility.md`는 downstream `RustBridge/Cargo.lock`과 `rhwp-core.lock` 정합성을 중심으로 설명한다.
- Stage 5 문서 보강은 upstream root `Cargo.lock`을 downstream lock 대체물로 쓰지 않는다는 점을 명확히 해야 한다.

## 설계 결정

1. `--locked` 적용 위치는 `scripts/build-rust-macos.sh`의 arm64/x86_64 staticlib build 두 곳으로 제한한다.
2. `scripts/update-rhwp-core.sh`의 `cargo generate-lockfile` 흐름은 유지한다.
3. 새 manifest field 이름은 `source_cargo_lock_sha256`을 우선 후보로 사용한다.
4. `scripts/sync-rhwp-studio.sh`가 새 manifest를 생성할 때 upstream root `Cargo.lock`이 없으면 실패시키는 방향으로 구현한다.
5. `scripts/verify-rhwp-studio-assets.sh`는 기존 manifest 호환을 위해 field가 없으면 기본 검증을 통과시키되, field가 있으면 64자 sha256 형식을 검증한다.
6. impact reason과 PR checklist는 `Cargo.lock`을 dependency graph/build input 변화로 설명한다.
7. 이번 task에서 core pin, `Rhwp.xcframework`, bundled `rhwp-studio` asset은 갱신하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

소스와 기존 운영 문서 본문은 변경하지 않았다. 이번 단계에서 새로 추가한 본문은 Stage 1 완료보고서뿐이며, 오늘할일 문서는 상태 비고만 갱신한다.

## 검증 결과

```text
$ git diff --check
통과
```

```text
$ rg -n "Cargo.lock|--locked|source_release_tag|source_resolved_commit|impact_reason|rhwp core/viewer provenance" scripts mydocs/manual mydocs/tech Sources/HostApp/Resources/rhwp-studio/manifest.json
관련 경로 확인:
- Sources/HostApp/Resources/rhwp-studio/manifest.json: source_release_tag/source_resolved_commit
- scripts/build-rust-macos.sh: Cargo.lock mismatch, Cargo.lock 검증 경로
- scripts/sync-rhwp-studio.sh: source_release_tag/source_resolved_commit manifest 생성
- scripts/verify-rhwp-studio-assets.sh: manifest tag/commit 검증
- scripts/ci/detect-rhwp-studio-impact.sh: impact_reason, Cargo.lock path 분류
- scripts/ci/write-release-delta-checklist.sh: rhwp core/viewer provenance 분류
- mydocs/manual, mydocs/tech: RustBridge/Cargo.lock과 rhwp-core.lock 기준 문서
```

## 잔여 위험

- `source_cargo_lock_sha256` 필드가 현재 bundled manifest에는 없으므로, verify script에서 필수화하면 기존 asset 검증이 깨질 수 있다.
- upstream root `Cargo.lock`이 없는 과거 release checkout을 대상으로 sync check를 실행하면 새 정책과 충돌할 수 있다.
- `--locked` 적용 후 개발자가 `Cargo.toml`만 바꾼 상태에서 build script를 실행하면 실패한다. 이는 의도된 drift 감지이지만 오류 설명이 불충분할 수 있다.

## 다음 단계 영향

Stage 2에서는 `scripts/build-rust-macos.sh`의 두 `cargo build` 명령에 `--locked`를 적용한다. Stage 3에서는 manifest provenance field를 추가하되 기존 bundled manifest 검증 호환을 유지한다. Stage 4에서는 `Cargo.lock` impact reason과 PR checklist 문구를 보강한다.

## 승인 요청

Stage 1 결과를 승인받은 뒤 Stage 2 — RustBridge locked build 검증 보강으로 진행한다.
