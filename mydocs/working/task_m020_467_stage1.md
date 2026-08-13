# Task M020 #467 Stage 1 완료보고서

## 단계 목적

PR #466 macOS validation 실패를 upstream/Swift schema와 실제 소비 경로에 다시 대조하고, retired `dirty` field 제거가 안전한지와 current/legacy fixture 및 PR CI 실행 경계를 확정한다.

이번 단계는 제품 source, helper와 workflow를 변경하지 않고 조사와 계약 확정만 수행했다.

## 산출물

- `mydocs/working/task_m020_467_stage1.md`
  - upstream schema 차이, Swift decode 실패 경로, fixture와 CI 계약을 기록했다.
- `mydocs/orders/20260813.md`
  - #467 상태를 Stage 1 완료 및 Stage 2 진행으로 갱신했다.

## 조사 결과

### 직접 원인과 오류 전파

PR #466 head `0672f1b5f9e963ba9198cd3000ba9bce80ae3ae0`에서 v0.8.4 Rust bridge를 lock 기준으로 빌드한 뒤 native renderer smoke를 실행하면 기본 샘플 3종 모두 `render tree is nil`로 실패했다.

동일 후보에서 `renderPageTree`의 `try?`를 임시 진단 코드로 풀어 실제 오류를 출력한 결과는 다음과 같다.

```text
DecodingError.keyNotFound: Key 'dirty' not found
Path: children[0]
```

`RhwpDocument.renderPageTree(at:)`는 `JSONDecoder().decode(RenderNode.self, from:)`를 `try?`로 실행한다. 따라서 첫 child의 필수 key 누락이 throw되면 전체 tree가 `nil`로 축약되고 smoke에서는 원래 decode 오류 대신 `render tree is nil`이 보인다.

Task #467에서는 이 오류 표시 계약이나 `try?`를 변경하지 않는다. 원인이 된 Swift schema만 upstream serialization과 맞춘다.

### Upstream v0.8.2와 v0.8.4 차이

로컬 Cargo git checkout에서 현재 `devel` 기준 v0.8.2 commit `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`와 PR #466 v0.8.4 commit `496333b27d21ddb9114ba9ae340bcb895870c9a7`의 `src/renderer/render_tree.rs`를 직접 비교했다.

v0.8.4 diff는 `RenderNode`의 다음 항목을 제거한다.

- `pub dirty: bool`
- constructor의 `dirty: true`
- `invalidate`, `mark_clean`, `mark_clean_recursive`, `has_dirty_nodes`

Serde JSON에서 `dirty`가 더 이상 생성되지 않는 것은 의도된 upstream schema 변경이다. PR #466의 `rhwp-core.lock`도 위 v0.8.4 commit을 정확히 가리킨다.

### Swift 소비 지점

제품 source, scripts와 workflow에서 `dirty`/`.dirty`를 검색한 결과 실제 항목은 아래 두 선언뿐이다.

```text
Sources/RhwpCoreBridge/RenderTree.swift:16: let dirty: Bool
Sources/RhwpCoreBridge/RenderTree.swift:24: case dirty
```

Renderer, compositor, overlay 처리와 smoke helper 어느 곳도 이 속성을 읽지 않는다. 따라서 optional/default property로 보존할 제품 동작이 없고, upstream에서 제거된 모델 member를 Swift에서도 제거하는 것이 가장 작은 보정이다.

### Legacy JSON 호환성

Swift `JSONDecoder`의 합성 `Decodable`은 `CodingKeys`에 없는 추가 JSON key를 무시한다. Foundation-only probe에서 `id`만 선언한 모델로 `{"id":1,"dirty":true}`를 decode했고 다음 결과를 확인했다.

```text
unknown-key-compatible id=1
```

그러므로 Swift 모델에서 `dirty` member와 coding key를 제거하면 다음 두 계약을 동시에 만족한다.

- v0.8.4 current JSON: key가 없어도 필수 decode 대상이 아니므로 성공
- v0.8.2 legacy JSON: 남아 있는 `dirty`는 unknown extra key로 무시돼 성공

이 기본 동작이 향후 custom decoder 변경으로 깨지지 않게 두 형식을 모두 tracked fixture로 고정한다.

### Fixture exact contract

Stage 2 fixture는 `RenderTree.swift`와 한 개의 Swift main만 Foundation으로 compile한다. Rust library, module map, sample 문서와 Xcode project는 필요하지 않다.

두 case 모두 root와 child를 가진다.

| case | root/child `dirty` | 확인 항목 |
|------|--------------------|-----------|
| current | 모두 없음 | root `MasterPage`, child `Header`, id/visible/children |
| legacy | 모두 있음 | 같은 구조와 값, 추가 key 무시 |

Root만 검사하면 PR #466에서 실제 실패한 `children[0]` 경로를 놓칠 수 있으므로 child node type과 id까지 assert한다. 성공 시 current/legacy 두 case 이름을 포함한 한 줄을 출력하고 decode/assertion 오류는 non-zero로 전파한다.

Shell helper는 다음 계약으로 확정한다.

- `scripts/ci/test-render-tree-decoder.sh`
- no-argument 실행만 지원하고 `--help`/`-h`는 usage 후 성공
- unexpected argument는 usage 후 실패
- `mktemp -d`로 binary와 Swift module cache를 만들고 `trap`으로 정리
- tracked source와 `build.noindex/`에 결과를 남기지 않음

### PR CI와 path classification

현재 `RenderTree.swift` 변경은 `Sources/*` 및 `Sources/RhwpCoreBridge/*` 규칙으로 macOS build와 render smoke를 이미 활성화한다. 반면 신규 `scripts/ci/*`만 변경하면 일반 CI/release automation 규칙으로 release checks만 활성화되고 macOS fixture 실행이 보장되지 않는다.

Stage 2에서 다음 경계를 적용한다.

1. `.github/workflows/pr-ci.yml`의 macOS validation checkout 직후, dependency 설치와 Rust bridge build 전에 decoder fixture를 실행한다.
2. `scripts/ci/test-render-tree-decoder.sh`와 `scripts/ci/render_tree_decoder_fixture.swift` exact path에서 macOS build와 render smoke를 활성화한다.
3. 일반 `scripts/ci/*` release check 분류도 그대로 적용해 CI helper 변경의 기존 검증 범위를 축소하지 않는다.

Fixture만 바뀌는 후속 PR도 macOS fixture와 실제 native smoke를 함께 실행하며, 제품 source 변경 PR은 기존대로 같은 두 gate를 실행한다.

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 신규 조사 보고서와 오늘할일 비고만 변경했다. `Sources/`, `scripts/`, `.github/workflows/`의 tracked 본문은 변경하지 않았다.

## 검증 결과

```text
rg -n "\bdirty\b|\.dirty\b" Sources scripts .github
결과: RenderTree.swift의 property와 CodingKey 두 곳만 확인

upstream git diff v0.8.2..v0.8.4 -- src/renderer/render_tree.rs
결과: dirty field, 초기값과 관련 observer helper 제거 확인

Swift Foundation unknown-key probe
결과: unknown-key-compatible id=1

./scripts/check-no-appkit.sh
결과: OK: shared Swift code has no AppKit/UIKit dependencies

scripts/ci/classify-pr-changes.sh origin/devel HEAD
결과: 문서-only 현재 diff에서 모든 실행 flag false, 기존 분류 기준 확인

git diff --check
결과: 통과
```

## 잔여 위험

- Fixture compile은 serialization producer 자체를 실행하지 않는다. Stage 3에서 실제 v0.8.4 bridge와 sample 3종 smoke로 producer/consumer 통합을 확인한다.
- `JSONDecoder` unknown-key 허용은 기본 동작이지만 custom `init(from:)`가 추가되면 달라질 수 있다. Legacy fixture를 CI에 고정해 회귀를 차단한다.
- 신규 helper가 exact classification에 빠지면 helper-only 변경에서 macOS gate가 skip될 수 있다. Stage 2에서 isolated path classification을 별도로 검증한다.
- PR CI에 조기 step을 추가해도 GitHub-hosted 실행 전에는 runner 환경을 완전히 보장할 수 없다. PR 생성 후 필수 check 결과를 확인한다.

## 다음 단계 영향

Stage 2는 확정한 최소 표면만 변경한다.

1. Swift `RenderNode`에서 `dirty` property와 coding key를 제거한다.
2. Current/legacy 중첩 JSON Swift fixture와 격리 shell helper를 추가한다.
3. PR CI macOS validation의 Rust build 전 조기 fixture step을 추가한다.
4. 신규 helper/fixture exact path를 macOS build와 render smoke trigger로 추가한다.
5. 독립 fixture, shared boundary, workflow parse와 classification을 검증한다.
