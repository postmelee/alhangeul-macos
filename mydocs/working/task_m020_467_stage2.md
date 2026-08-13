# Task M020 #467 Stage 2 완료보고서

## 단계 목적

Swift `RenderNode`에서 upstream v0.8.4에 더 이상 존재하지 않는 `dirty` 필수 decode 계약을 제거하고, current/legacy 중첩 JSON 양방향 호환을 독립 fixture로 고정한다. Fixture를 PR CI에서 Rust build 전에 실행하고 helper-only 변경도 macOS·render gate를 건너뛰지 않도록 분류한다.

## 산출물

- `Sources/RhwpCoreBridge/RenderTree.swift`
  - 사용하지 않는 `dirty` property와 coding key를 제거했다.
  - retired field를 모델에 남기지 않고 legacy unknown key를 허용한다는 의도를 주석으로 기록했다.
- `scripts/ci/render_tree_decoder_fixture.swift`
  - `dirty` 없는 current JSON과 `dirty` 포함 legacy JSON의 root/child decode를 검증한다.
- `scripts/ci/test-render-tree-decoder.sh`
  - `RenderTree.swift`와 fixture를 임시 directory에서 compile/run하고 결과를 정리한다.
- `scripts/ci/classify-pr-changes.sh`
  - 신규 Swift fixture와 shell helper를 macOS build/render smoke trigger에 명시했다.
- `.github/workflows/pr-ci.yml`
  - helper interface 확인과 macOS validation 조기 fixture step을 추가했다.
- `mydocs/working/task_m020_467_stage2.md`
  - 구현과 독립 검증 결과를 기록했다.
- `mydocs/orders/20260813.md`
  - #467 상태를 Stage 2 완료 및 Stage 3 진행으로 갱신했다.

## 구현 결과

### Swift decoder 계약

`RenderNode`에서 아래 두 선언만 제거했다.

```swift
let dirty: Bool
case dirty
```

다른 node field, enum variant, custom decoder와 renderer 코드는 변경하지 않았다. 합성 `Decodable`은 v0.8.4 JSON에서 더 이상 `dirty`를 요구하지 않고, v0.8.2 JSON에 남아 있는 `dirty`는 unknown extra key로 무시한다.

모델 위에는 다음 의도를 남겼다.

- upstream에서 제거된 field를 제품 모델에 호환용 상태로 남기지 않는다.
- 구버전 core JSON의 알 수 없는 추가 key는 계속 수용한다.

### Current/legacy fixture

두 JSON은 모두 `MasterPage` root 아래 `Header` child를 가진다. 실제 PR #466 오류 path인 `children[0]`을 포함해 root/child 양쪽 schema를 검사한다.

| case | `dirty` | assertion |
|------|---------|-----------|
| `current-without-dirty` | root/child 모두 없음 | root id/type/visible, child count, child id/type/visible/empty children |
| `legacy-with-dirty` | root/child 모두 있음 | current와 같은 구조, 추가 key가 decode를 방해하지 않음 |

Fixture failure는 thrown error로 non-zero 종료하며 성공 output은 다음 한 줄로 고정했다.

```text
OK: render tree decoder accepts current JSON without dirty and legacy JSON with dirty
```

### 격리 helper

Shell helper는 argument 없이 실행한다. `--help`/`-h`는 compile 없이 usage를 출력하고, 그 밖의 인자는 exit 2로 거부한다.

실행 시 `mktemp -d`로 binary와 Swift module cache를 만들고 `trap`에서 exact temp root만 제거한다. Repository의 tracked source, `build.noindex/`와 일반 Swift/Clang cache에 산출물을 남기지 않는다.

### PR CI 조기 gate

macOS validation에서 checkout 직후 decoder helper를 실행하도록 배치했다. XcodeGen/cbindgen 설치와 Rust universal artifact build보다 앞서므로 schema-only 회귀는 빠르고 직접적인 fixture 오류로 종료된다.

Ubuntu `Script syntax checks`는 기존 `scripts/ci/*.sh` 반복으로 shell syntax를 검사하고 helper interface 단계에서 `--help`를 확인한다. 실제 Swift compile/run은 Xcode toolchain이 보장된 macOS validation이 담당한다.

### Path classification

다음 exact path를 기존 renderer/extension pattern에 추가했다.

- `scripts/ci/render_tree_decoder_fixture.swift`
- `scripts/ci/test-render-tree-decoder.sh`

전체 Stage 2 diff를 담은 working tree 무변경 임시 commit object로 classifier를 실행한 결과는 다음과 같다.

| Flag | 결과 |
|------|------|
| `docs_only` | `false` |
| `run_macos_build` | `true` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `true` |
| `run_release_checks` | `true` |

MacOS/render reasons에 source뿐 아니라 신규 Swift fixture와 shell helper가 각각 출력됐다. 따라서 fixture/helper-only 변경도 두 gate를 활성화한다. Core pin/artifact가 바뀌지 않았으므로 `run_rust_verify=false`는 의도한 결과다.

## 본문 변경 정도 / 본문 무손실 여부

- `RenderTree.swift`: `dirty` 선언 2줄 제거와 호환 의도 주석 2줄 추가
- `classify-pr-changes.sh`: 기존 renderer pattern에 exact path 2개만 추가
- `pr-ci.yml`: helper `--help` 1줄과 macOS 조기 실행 step 추가
- 신규 fixture/helper: 총 128줄

Stage 2 source diff는 5 files, `+138 / -3`이다. `project.yml`, Xcode project, Rust FFI, core pin, artifact와 bundled studio asset은 변경하지 않았다.

## 검증 결과

```text
bash -n scripts/ci/test-render-tree-decoder.sh scripts/ci/classify-pr-changes.sh
결과: 통과

bash scripts/ci/test-render-tree-decoder.sh --help
결과: usage 출력 후 성공

scripts/ci/test-render-tree-decoder.sh unexpected
결과: 예상대로 실패

scripts/ci/test-render-tree-decoder.sh
결과: current-without-dirty, legacy-with-dirty 모두 통과

./scripts/check-no-appkit.sh
결과: OK: shared Swift code has no AppKit/UIKit dependencies

ruby Psych.parse_file 전체 workflow
결과: 6개 workflow 모두 parse 통과

shellcheck -e SC2129 신규 helper와 classifier
결과: 통과

scripts/ci/classify-pr-changes.sh origin/devel <stage2-probe-commit>
결과: macOS=true, render=true, release=true, Rust verify=false

git diff --cached --check
결과: 통과
```

## 잔여 위험

- Fixture는 실제 Rust serialization을 호출하지 않는다. Stage 3에서 PR #466 v0.8.4 candidate와 sample 3종으로 통합 확인한다.
- PR CI workflow step은 local YAML parse만 완료했다. GitHub-hosted runner 실행 결과는 PR 생성 뒤 확인해야 한다.
- `RenderTree.swift`의 다른 field도 future upstream에서 바뀔 수 있다. 이번 작업은 실제로 검출된 `dirty` 하나만 다루며 선제 optional 처리는 하지 않는다.
- `run_rust_verify=false`이므로 Task #467 PR은 current v0.8.2 bridge를 재빌드한다. v0.8.4 lock 통합 검증은 Stage 3 격리 worktree에서 별도로 수행한다.

## 다음 단계 영향

Stage 3에서는 source를 확장하지 않고 다음을 검증한다.

1. 전체 shell syntax, helper fixture, workflow YAML과 shared boundary를 다시 실행한다.
2. Production build-info/studio provenance verifier를 확인한다.
3. PR #466 v0.8.4 candidate에 Task #467 source 보정을 격리 적용한다.
4. v0.8.4 Rust bridge lock verification과 native renderer sample 3종 smoke를 실행한다.
5. Temporary worktree/output을 정리하고 PR #466 갱신 handoff를 기록한다.
