# Task #467 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#467 rhwp v0.8.4 RenderNode dirty 제거에 Swift decoder 호환 보정](https://github.com/postmelee/alhangeul-macos/issues/467) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 기준 통합 브랜치 | `devel` |
| 작업 브랜치 | `local/task467` |
| 게시 브랜치 | `publish/task467` |
| 단계 | Stage 1~3 |
| 차단 대상 | [PR #466 Sync rhwp upstream v0.8.4](https://github.com/postmelee/alhangeul-macos/pull/466) |

Rhwp v0.8.4에서 제거된 `RenderNode.dirty`를 Swift decoder가 계속 필수 key로 요구해 native render tree 전체가 `nil`이 되는 호환성 회귀를 보정했다.

사용하지 않는 Swift property와 coding key를 제거해 v0.8.4 JSON을 수용하고, JSONDecoder의 unknown-key 허용으로 `dirty`가 남은 v0.8.2 JSON도 계속 수용한다. 두 형식을 중첩 node fixture로 고정하고 PR CI에서 Rust build 전에 실행하도록 연결했다. 신규 fixture/helper만 바뀌는 후속 PR도 macOS build와 native render smoke를 건너뛰지 않게 path classification을 보강했다.

PR #466 v0.8.4 candidate에 같은 보정을 격리 적용한 결과 기본 sample 3종의 render tree, Hangul text/glyph와 non-blank PNG smoke가 모두 통과했다. Task #467은 PR #466, upstream automation branch, core pin과 공개 release 상태를 변경하지 않았다.

## 직접 원인과 해결

### 변경 전

Swift 모델은 다음 member를 합성 `Decodable`의 필수 대상으로 포함했다.

```swift
let dirty: Bool
case dirty
```

Upstream v0.8.4 `RenderNode`에서는 `dirty` field와 관련 observer helper가 제거돼 JSON에 key가 존재하지 않는다. 실제 오류는 첫 child에서 발생했다.

```text
DecodingError.keyNotFound: Key 'dirty' not found
Path: children[0]
```

`RhwpDocument.renderPageTree(at:)`가 decode를 `try?`로 실행하므로 이 오류는 전체 tree `nil`로 변환되고, PR #466 native smoke는 sample 3종 모두 `render tree is nil`로 실패했다.

### 변경 후

Swift `RenderNode`에서 사용하지 않는 `dirty` property와 coding key를 제거했다. 다른 field, node type, custom decoder, renderer와 `renderPageTree` 오류 반환 계약은 변경하지 않았다.

합성 `Decodable` 동작은 다음과 같다.

| Producer | JSON 상태 | Swift 결과 |
|----------|-----------|------------|
| rhwp v0.8.4 | `dirty` 없음 | 필수 decode 대상이 아니므로 성공 |
| rhwp v0.8.2 계열 | `dirty` 있음 | unknown extra key로 무시해 성공 |

이 의도를 `RenderTree.swift` 주석과 current/legacy fixture로 함께 고정했다.

## 변경 파일과 영향 범위

| 파일 | 변경 내용 |
|------|-----------|
| `Sources/RhwpCoreBridge/RenderTree.swift` | `dirty` property/CodingKey 제거, retired/legacy field 호환 의도 주석 |
| `scripts/ci/render_tree_decoder_fixture.swift` | Current/legacy root-child JSON decode와 구조 assertion |
| `scripts/ci/test-render-tree-decoder.sh` | Foundation-only 격리 compile/run, help/argument/cleanup contract |
| `scripts/ci/classify-pr-changes.sh` | 신규 fixture/helper를 macOS build와 render smoke trigger로 분류 |
| `.github/workflows/pr-ci.yml` | Helper interface 확인, macOS checkout 직후 조기 decoder fixture 실행 |
| `mydocs/plans/task_m020_467.md` | 목적, 범위, 설계 방향, 3단계와 위험 |
| `mydocs/plans/task_m020_467_impl.md` | Stage별 exact contract, 판정 규칙과 검증 명령 |
| `mydocs/working/task_m020_467_stage1.md` | Upstream schema/소비/CI 경계 조사 |
| `mydocs/working/task_m020_467_stage2.md` | Decoder/fixture/CI 구현과 독립 검증 |
| `mydocs/working/task_m020_467_stage3.md` | Current 회귀와 v0.8.4 통합 smoke, 임시 산출물 정리 |
| `mydocs/report/task_m020_467_report.md` | 최종 수용 결과와 upstream sync handoff |
| `mydocs/orders/20260813.md` | #467 등록, 단계 진행과 완료 시각 |

변경하지 않은 범위:

- `project.yml`, `Alhangeul.xcodeproj`
- `RhwpDocument.renderPageTree`와 Rust FFI ABI
- `rhwp-core.lock`, `Frameworks/`, `RhwpCoreBuildInfo.swift`
- Bundled rhwp-studio asset
- Renderer layout/drawing 동작
- PR #466과 upstream automation remote state
- Signing, notarization, GitHub Release와 배포

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행 계획 | `6bc435e` | Issue #467 범위, branch, 오늘할일과 3단계 검증 경계 등록 |
| 구현 계획 | `d4fe663` | Retired field, fixture, CI와 통합 판정 규칙 확정 |
| Stage 1 | `f60d79f` | Upstream v0.8.2→v0.8.4 schema 차이, 무소비 근거와 CI 경계 확정 |
| Stage 2 | `1b49a87` | `dirty` 제거, current/legacy fixture/helper와 PR CI/classification 구현 |
| Stage 3 | `56497f7` | 전체 회귀, v0.8.4 bridge provenance와 sample 3종 smoke 완료 |
| 최종 보고 | 현재 커밋 | 최종 수용 결과, 오늘할일 완료와 PR #466 handoff 정리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| Swift 필수 `dirty` decode member | property 1개 + CodingKey 1개 | 0개 |
| Decoder compatibility fixture | 없음 | current/legacy 2 case, root/child assertion |
| Fixture helper | 없음 | Foundation-only shell helper 1개 |
| PR CI decoder gate | 실제 native smoke에서 간접 검출 | Rust build 전 독립 fixture + 이후 native smoke |
| Helper-only macOS/render 분류 | 보장 안 됨 | exact path 2개 모두 true |
| Stage 2 source diff | 없음 | 5 files, `+138 / -3` |
| 단계 보고서 | 없음 | Stage 1~3 보고서 3개 |
| 최종 보고 전 전체 diff | 없음 | 11 files, `+928 / -3` |

## Fixture와 CI 계약

### Swift fixture

두 case 모두 `MasterPage` root와 `Header` child를 가진다.

- `current-without-dirty`: root/child 모두 `dirty` 없음
- `legacy-with-dirty`: root/child 모두 `dirty` 있음

각 case에서 root/child id, node type, visible, child count와 empty descendants를 확인한다. 실제 실패 지점이었던 `children[0]`을 포함하므로 top-level-only 검증으로 회귀가 빠져나가지 않는다.

### Shell helper

- Argument 없는 production 실행
- `--help`/`-h` 성공
- Unexpected argument exit 2
- `mktemp -d`의 binary/module cache만 사용
- `trap`으로 exact temp root 정리
- Tracked source와 repository build output 무변경

### PR CI

MacOS validation의 순서는 다음과 같다.

1. Checkout
2. Render tree decoder compatibility fixture
3. Build dependency 설치
4. Rust bridge artifact 준비
5. Shared boundary/build-info/studio asset 검증
6. Xcode project 생성과 HostApp build
7. Native renderer smoke

Schema-only 오류는 비싼 Rust universal build 전에 직접적인 fixture failure로 종료된다. Source/helper/workflow 전체 Task #467 diff의 classification은 `macOS=true`, `render=true`, `release=true`, `Rust verify=false`다. Core provenance 입력이 바뀌지 않았으므로 Rust verify false는 의도한 값이다.

## 검증 결과

### Current branch

```text
전체 shell syntax: 통과
render tree decoder current/legacy fixture: 통과
helper help와 unexpected argument: 통과
shellcheck -e SC2129: 통과
core build-info isolated fixture: 통과
studio Cargo.lock isolated fixture: 통과
shared Swift AppKit/UIKit boundary: 통과
production RhwpCoreBuildInfo verifier: 통과
bundled rhwp-studio asset verifier: 통과
전체 workflow Psych parse: 6개 통과
committed ref PR classification: 기대 flag/reason 통과
git diff --check: 통과
```

### v0.8.4 candidate bridge

| 항목 | 값 |
|------|----|
| release tag | `v0.8.4` |
| resolved commit | `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| feature | `native-skia` |
| PR #466 head | `0672f1b5f9e963ba9198cd3000ba9bce80ae3ae0` |
| universal architectures | `x86_64 arm64` |

`ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1` 정책으로 static archive byte hash/size만 skip하고 source provenance, Cargo.lock, generated header와 FFI symbols를 검증했다. 전체 build와 lock verification이 통과했다.

### v0.8.4 native renderer

| 샘플 | text runs | Hangul runs | Hangul scalars | non-white pixels | 결과 |
|------|-----------|-------------|----------------|------------------|------|
| `KTX.hwp` | 410 | 76 | 209 | 455,342 | 통과 |
| `request.hwp` | 102 | 36 | 309 | 70,619 | 통과 |
| `exam_kor.hwp` | 133 | 86 | 1,368 | 173,827 | 통과 |

세 sample 모두 render tree non-nil, Hangul text/glyph와 non-blank PNG 조건을 통과했다. 기존 layout overlap diagnostic은 failure가 아니며 Task #467에서 layout을 변경하지 않았다.

## 임시 검증 자원 정리

PR #466 detached worktree, 두 architecture의 Cargo target, 209MB universal static library, 209MB XCFramework, sample PNG/module cache와 Stage 1 module cache를 제거했다. 모두 재생성 가능한 임시 산출물이며 원격 상태와 tracked source에는 영향이 없다.

정리 후 주 worktree 하나만 남았고 `local/task467` working tree는 clean이다.

## 잔여 위험과 후속 작업

### Task #467 PR

- Open PR 생성 후 GitHub-hosted `Classify changed files`, `Script syntax checks`, `macOS validation`, `Release helper checks`를 확인한다.
- 모든 필수 check 통과 뒤에만 `devel` merge한다.
- Merge 후 Issue #467 close와 local/publish branch 정리는 `pr-merge-cleanup` 절차로 수행한다.

### PR #466과 upstream sync

Task #467은 [PR #466](https://github.com/postmelee/alhangeul-macos/pull/466)을 수정하거나 merge하지 않았다. 권장 후속 순서는 다음과 같다.

1. Task #467 PR merge
2. 최신 `devel` 기준 upstream sync workflow 재실행 또는 운영 정책에 따른 PR #466 갱신/재생성
3. 새 candidate에서 decoder fixture와 native smoke 성공 확인
4. Build-info와 Cargo.lock provenance gate 확인
5. Upstream sync PR merge
6. 별도 승인으로 release runbook 진행

### 공개 release

Task #467은 signing/notarization, GitHub Release, Pages/Sparkle, Homebrew Cask 작업을 실행하지 않았다. Upstream sync PR merge와 전체 CI 확인 뒤 작업지시자의 별도 release 승인을 받아야 한다.

## 작업지시자 검토 요청

Task #467 PR에서 다음을 중점 확인해 달라.

1. 사용하지 않는 retired `dirty` member를 optional로 남기지 않고 제거한 최소 보정
2. Current/legacy JSON 모두 root/child까지 검증하는 fixture 계약
3. Rust build 전 조기 fixture와 이후 native smoke의 2단계 검출 경계
4. Fixture/helper-only 변경도 macOS/render gate를 활성화하는 path classification
5. PR #466을 직접 수정하지 않고 Task #467 merge 뒤 최신 `devel`에서 갱신하는 handoff
