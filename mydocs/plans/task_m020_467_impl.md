# Task M020 #467 구현계획서

수행계획서: `mydocs/plans/task_m020_467.md`

## 작업 개요

- 이슈: #467 `rhwp v0.8.4 RenderNode dirty 제거에 Swift decoder 호환 보정`
- 마일스톤: M020 `v0.2.x Skia Quick Look/Thumbnail Backend`
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task467`
- 게시 브랜치: `publish/task467`
- 차단 대상: PR #466 `Sync rhwp upstream v0.8.4`
- 직접 원인: upstream `RenderNode.dirty` 제거와 Swift 필수 decode key 잔존

작업지시자가 PR 생성까지 진행하도록 승인했으므로 각 Stage의 완료 조건과 검증을 충족한 뒤 다음 Stage로 연속 진행한다. 각 Stage source와 보고서는 분리된 커밋으로 남긴다.

## 구현 전 확인 결과

| 항목 | 현재 상태 | 구현 반영 |
|------|-----------|-----------|
| upstream schema | rhwp v0.8.4 `RenderNode`에 `dirty` 없음 | 제거된 field를 Swift 모델에서도 삭제한다. |
| Swift schema | `dirty: Bool`과 `case dirty`가 자동 `Decodable`의 필수 key | 두 선언을 함께 제거한다. |
| 소비 지점 | 저장소에서 `RenderNode.dirty` 참조 없음 | optional/default 보존 없이 모델을 축소한다. |
| 오류 경로 | 첫 child에서 `keyNotFound(dirty)`, `renderPageTree`는 `try?`로 nil 반환 | `renderPageTree` 오류 계약은 변경하지 않고 schema를 맞춘다. |
| 임시 검증 | 두 선언 제거 시 v0.8.4 native smoke 3종 통과 | 같은 최소 patch를 tracked source에 적용한다. |
| 기존 JSON | JSONDecoder는 선언하지 않은 추가 key를 무시 | `dirty` 포함 fixture로 동작을 고정한다. |
| PR CI | `RenderTree.swift` 변경은 macOS build/render smoke를 실행 | 독립 fixture를 Rust build 전 조기 실행한다. |
| helper 분류 | 일반 `scripts/ci/*`는 release check 대상이지만 render smoke를 보장하지 않음 | 신규 helper/fixture exact path를 renderer trigger로 추가한다. |

## 공통 구현 원칙

1. `Sources/RhwpCoreBridge`에는 Foundation 외 AppKit/UIKit 직접 의존을 추가하지 않는다.
2. Upstream v0.8.4에 없는 속성을 별도 compatibility property로 만들지 않는다.
3. `dirty` 외 schema, renderer, FFI ABI와 `project.yml`은 변경하지 않는다.
4. Fixture는 root와 child의 id, node type, visibility와 child count를 확인한다.
5. Current 형식은 root/child 모두 `dirty`가 없고 legacy 형식은 root/child 모두 `dirty`가 있다.
6. Fixture helper는 `--help`를 지원하고 인자를 받지 않으며 repository 밖 임시 directory만 사용한다.
7. PR CI는 macOS runner에서 Foundation-only fixture를 먼저 실행한다. Ubuntu script job은 shell syntax만 검증한다.
8. Path classification은 source와 신규 fixture/helper 변경에서 `run_macos_build=true`, `run_render_smoke=true`를 보장한다.
9. v0.8.4 smoke 검증은 Task #467 branch의 core pin/artifact를 변경하지 않는 격리 worktree에서 수행한다.
10. PR #466이나 automation branch의 remote 상태는 Task #467에서 변경하지 않는다.

## 판정 규칙

| 결과 | 판정 |
|------|------|
| `dirty` 없는 root/child decode 성공 | 통과 |
| `dirty` 있는 root/child decode 성공 | 통과 |
| Fixture가 legacy `dirty` 존재를 모델 속성으로 요구 | 범위 위반 |
| `RenderNode.dirty` 참조 잔존 | blocking |
| `Sources/RhwpCoreBridge` AppKit/UIKit 검증 실패 | blocking |
| 신규 helper/fixture-only 분류에서 macOS 또는 render gate false | blocking |
| Workflow YAML parse 또는 shell syntax 실패 | blocking |
| v0.8.4 sample 3종 중 render tree nil/비한글/blank bitmap | blocking |
| Task #467 diff에 v0.8.4 core pin이나 bundled asset 포함 | 범위 위반 |
| PR #466 merge/close 또는 공개 release 실행 | 범위 위반 |

## Stage 1. 호환 계약과 CI 경계 확정

### 목표

재현 결과를 tracked source와 upstream schema에 대조하고, retired field 제거가 안전한지와 독립 fixture/CI의 exact contract를 확정한다.

### 대상

- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `scripts/validate-stage3-render.sh`
- `scripts/ci/classify-pr-changes.sh`
- `.github/workflows/pr-ci.yml`
- upstream v0.8.4 `RenderNode` 정의
- `mydocs/working/task_m020_467_stage1.md`
- `mydocs/orders/20260813.md`

### 작업

1. Swift `dirty` 선언과 전체 소비 지점을 재검색한다.
2. Upstream v0.8.2와 v0.8.4 `RenderNode` field 차이를 기록한다.
3. 실제 decode 오류 path와 `try?`에 의한 nil 전환 경로를 기록한다.
4. JSONDecoder unknown-key 허용이 legacy compatibility를 제공하는지 작은 compile/run probe로 확인한다.
5. Fixture JSON, assertion, shell helper output과 failure contract를 확정한다.
6. PR CI 조기 실행 위치와 path classification exact trigger를 확정한다.
7. 제품 source/helper/workflow를 변경하지 않고 조사 보고서를 작성한다.

### 검증

```bash
rg -n "dirty" Sources scripts .github mydocs/manual
rg -n "RenderNode|renderPageTree|validate-stage3-render" Sources scripts .github/workflows/pr-ci.yml
./scripts/check-no-appkit.sh
git diff --check
```

### 완료 조건

- Retired field 제거가 renderer 소비를 바꾸지 않는 근거가 기록돼 있다.
- Current/legacy fixture와 child assertion이 확정돼 있다.
- CI 실행 위치와 classification trigger가 실제 workflow 기준으로 확정돼 있다.
- 제품 source/helper/workflow tracked file은 변경되지 않았다.

### 커밋

```text
Task #467 Stage 1: render tree decoder 호환 계약 확정
```

## Stage 2. Decoder 보정과 회귀 fixture/CI 구현

### 목표

Swift 모델에서 retired `dirty`를 제거하고, current/legacy JSON 양방향 호환을 독립 fixture로 고정해 PR CI에서 조기 검출한다.

### 대상

- `Sources/RhwpCoreBridge/RenderTree.swift`
- 신규 `scripts/ci/render_tree_decoder_fixture.swift`
- 신규 `scripts/ci/test-render-tree-decoder.sh`
- `scripts/ci/classify-pr-changes.sh`
- `.github/workflows/pr-ci.yml`
- `mydocs/working/task_m020_467_stage2.md`
- `mydocs/orders/20260813.md`

### 작업

1. `RenderNode.dirty`와 해당 coding key를 제거하고 legacy extra key 허용 의도를 주석으로 남긴다.
2. Current/legacy 중첩 JSON을 decode하고 root/child 구조를 검증하는 Swift fixture를 추가한다.
3. Foundation-only fixture를 격리 compile/run하는 shell helper를 추가한다.
4. Helper `--help`, unexpected argument와 정상 output contract를 검증한다.
5. PR CI macOS validation의 dependency/Rust build 전에 helper를 실행한다.
6. 신규 helper/fixture를 macOS build와 render smoke trigger로 분류한다.
7. Source와 Stage 2 보고서를 함께 검증·커밋한다.

### 검증

```bash
bash -n scripts/ci/test-render-tree-decoder.sh scripts/ci/classify-pr-changes.sh
bash scripts/ci/test-render-tree-decoder.sh --help
scripts/ci/test-render-tree-decoder.sh
./scripts/check-no-appkit.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
scripts/ci/classify-pr-changes.sh origin/devel HEAD
git diff --check
```

Fixture-only 임시 ref 또는 동등한 입력에서도 `run_macos_build=true`와 `run_render_smoke=true`를 확인한다.

### 완료 조건

- Current/legacy fixture가 모두 성공하고 root/child assertion이 동작한다.
- Swift 모델에 `dirty` 선언이 남지 않는다.
- Helper가 tracked file을 만들거나 변경하지 않는다.
- PR CI가 Rust build 전에 fixture를 실행한다.
- Source와 helper/fixture 변경 모두 필요한 renderer gate를 활성화한다.

### 커밋

```text
Task #467 Stage 2: RenderNode 호환 보정과 decoder fixture 추가
```

## Stage 3. 통합 회귀 검증과 upstream sync handoff

### 목표

Current `devel` 기준 정적·helper 검증과 v0.8.4 candidate 기준 native renderer smoke를 완료해 Task #467 수용 조건과 PR #466 후속 순서를 확정한다.

### 대상

- Task #467 전체 변경
- PR #466 head 또는 동일 v0.8.4 candidate를 사용한 격리 worktree
- `mydocs/working/task_m020_467_stage3.md`
- `mydocs/orders/20260813.md`

### 작업

1. 전체 shell syntax, workflow YAML, shared Swift boundary, build-info/studio verifier를 실행한다.
2. `origin/devel..HEAD` classification에서 macOS·render·release flag를 확인한다.
3. PR #466 v0.8.4 candidate에 Task #467 source patch를 격리 적용한다.
4. v0.8.4 Rust bridge lock verification을 static archive hash skip 범위로 실행한다.
5. 기본 sample 3종 native renderer smoke와 non-blank bitmap 결과를 확인한다.
6. 격리 worktree와 build output을 정리하고 Task #467 working tree 무손실을 확인한다.
7. PR #466을 Task #467 merge 뒤 갱신/재생성해야 한다는 handoff를 기록한다.

### 검증

```bash
for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done
scripts/ci/test-render-tree-decoder.sh
scripts/ci/test-rhwp-core-build-info.sh
scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
scripts/ci/classify-pr-changes.sh origin/devel HEAD
git diff --check
```

격리 v0.8.4 후보:

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock
./scripts/validate-stage3-render.sh build.noindex/task467-v084-smoke
```

### 완료 조건

- 전체 local/static 검증이 통과한다.
- v0.8.4 sample 3종이 render tree, Hangul text/glyph와 non-blank PNG 검증을 통과한다.
- Task #467 diff에 core pin/artifact/bundled asset 변경이 없다.
- 격리 worktree와 임시 output이 정리돼 있다.
- PR #466 후속 재실행 조건과 공개 release 제외 경계가 기록돼 있다.

### 커밋

```text
Task #467 Stage 3: v0.8.4 native renderer 통합 검증 완료
```

## 최종 보고와 PR

Stage 1~3 완료 후 `mydocs/report/task_m020_467_report.md`를 작성하고 오늘할일을 완료 처리한다. 최종 커밋 뒤 `publish/task467`에 push하고 `devel` 대상 Open PR을 생성한다.

PR 본문에는 다음을 포함한다.

- `Closes #467`
- PR #466 실패 재현과 직접 원인
- current/legacy fixture 계약
- v0.8.4 sample 3종 smoke 결과
- path classification과 CI 영향
- Task #467 merge 뒤 PR #466 갱신/재생성 handoff
- 공개 release가 범위 밖이라는 명시
