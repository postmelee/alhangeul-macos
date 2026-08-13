# Task M020 #467 Stage 3 완료보고서

## 단계 목적

Task #467 전체 변경의 local/static 회귀를 검증하고, PR #466 v0.8.4 candidate에 Stage 2 decoder 보정을 격리 적용해 실제 Rust producer와 Swift consumer가 native renderer sample 3종에서 다시 연결되는지 확인한다. 검증 뒤 임시 worktree와 build/smoke 산출물을 모두 정리하고 upstream sync 후속 조건을 확정한다.

## 산출물

- `mydocs/working/task_m020_467_stage3.md`
  - 전체 회귀, v0.8.4 bridge provenance와 native smoke 결과, 임시 산출물 정리와 handoff를 기록했다.
- `mydocs/orders/20260813.md`
  - #467 상태를 Stage 1~3와 v0.8.4 통합 smoke 완료로 갱신했다.

Stage 3에서는 제품 source, helper와 workflow를 추가 변경하지 않았다.

## Current branch 전체 검증

`local/task467` HEAD에서 다음 범위를 실행했다.

1. `scripts/*.sh`, `scripts/ci/*.sh` 전체 shell syntax
2. Current/legacy render tree decoder fixture
3. Core build-info writer/verifier isolated fixture
4. Bundled rhwp-studio Cargo.lock provenance isolated fixture
5. Shared Swift AppKit/UIKit boundary
6. Production core build-info와 bundled studio asset verifier
7. 전체 GitHub Actions workflow YAML parse
8. `origin/devel..HEAD` PR change classification
9. `git diff --check`와 clean working tree

모든 명령이 성공했다.

Classification 결과:

| Flag | 결과 | 근거 |
|------|------|------|
| `docs_only` | `false` | source, helper, workflow 변경 |
| `run_macos_build` | `true` | `RenderTree.swift`, decoder fixture/helper |
| `run_rust_verify` | `false` | core pin/artifact/ABI 변경 없음 |
| `run_render_smoke` | `true` | source와 fixture/helper exact renderer path |
| `run_release_checks` | `true` | PR CI와 `scripts/ci/*` 변경 |

MacOS와 render reasons에 `RenderTree.swift`, `render_tree_decoder_fixture.swift`, `test-render-tree-decoder.sh`가 각각 나타났다. 따라서 Stage 2에서 의도한 helper-only 분류 경계도 실제 committed ref 기준으로 확인됐다.

## v0.8.4 격리 검증 구성

원격 branch나 PR #466을 수정하지 않고 다음 방식으로 검증했다.

1. PR #466 head `0672f1b5f9e963ba9198cd3000ba9bce80ae3ae0`을 `build.noindex/task467-v084-worktree` detached worktree로 생성했다.
2. Task #467 Stage 2 commit `1b49a87`을 임시 cherry-pick했다.
3. 오늘할일 문서 한 곳만 충돌해 candidate 쪽 내용을 유지했다. 제품 source, fixture와 workflow는 자동 적용됐다.
4. Decoder fixture를 먼저 실행했다.
5. v0.8.4 bridge를 universal arm64/x86_64로 빌드하고 lock을 검증했다.
6. 기본 sample 3종 native renderer smoke를 실행했다.
7. Worktree가 clean임을 확인한 뒤 worktree 전체와 내부 build/smoke output을 제거했다.

Task #467 branch의 `rhwp-core.lock`, `Frameworks/`, bundled asset과 Git refs는 변경하지 않았다.

## v0.8.4 bridge 검증

사용한 candidate identity:

| 항목 | 값 |
|------|----|
| release tag | `v0.8.4` |
| resolved commit | `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| enabled features | `native-skia` |
| PR head | `0672f1b5f9e963ba9198cd3000ba9bce80ae3ae0` |

명령:

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock
```

첫 sandbox 실행은 rust-skia prebuilt artifact 다운로드 시 DNS 차단으로 실패했다. 코드/lock 오류가 아니므로 네트워크가 허용된 동일 명령으로 재실행했다.

재실행 결과:

- arm64와 x86_64 release static library build 성공
- universal binary architecture `x86_64 arm64` 확인
- cbindgen header check 성공
- FFI symbol 15개 검증 성공
- `Rhwp.xcframework` 생성 성공
- source provenance, Cargo.lock, generated header와 FFI symbols 검증 성공
- PR CI 정책과 동일하게 `Frameworks/universal/librhwp.a` byte hash/size 비교만 skip

최종 output은 `Verified: .../rhwp-core.lock`으로 종료했다.

## v0.8.4 native renderer smoke

명령:

```bash
./scripts/validate-stage3-render.sh build.noindex/task467-v084-smoke
```

결과:

| 샘플 | 크기 | text runs | Hangul runs | Hangul scalars | non-white pixels | 판정 |
|------|------|-----------|-------------|----------------|------------------|------|
| `KTX.hwp` | 1123×794 | 410 | 76 | 209 | 455,342 | 통과 |
| `request.hwp` | 567×794 | 102 | 36 | 309 | 70,619 | 통과 |
| `exam_kor.hwp` | 1123×1588 | 133 | 86 | 1,368 | 173,827 | 통과 |

세 문서 모두 다음 조건을 통과했다.

- 문서 open과 첫 page size 조회
- render tree non-nil
- text run과 Hangul run/scalar 존재
- native PNG 생성
- non-blank bitmap

KTX와 exam_kor 실행 중 기존 layout overlap diagnostic이 출력됐지만 smoke failure 조건이 아니며, 세 결과 모두 `OK`로 종료했다. Task #467의 범위는 decode 호환이므로 기존 layout diagnostic은 변경하지 않는다.

## 임시 산출물 정리

검증 뒤 다음을 제거했다.

- `build.noindex/task467-v084-worktree` detached worktree
- Worktree 내부 arm64/x86_64 Cargo target
- 209MB universal static library와 209MB XCFramework
- Sample 3종 smoke PNG와 module cache
- `build.noindex/task467-stage1-module-cache`

정리 후 `git worktree list`에는 주 작업 경로 `local/task467` 하나만 남았고, `git status --short --branch`는 `## local/task467`로 clean이다. 삭제한 항목은 모두 재생성 가능한 임시 build/검증 산출물이다.

## 본문 변경 정도 / 본문 무손실 여부

Stage 3의 tracked 변경은 신규 완료보고서와 오늘할일 비고뿐이다. Stage 2 source/helper/workflow는 검증만 수행했고 추가 수정하지 않았다.

## 검증 결과 요약

```text
전체 shell syntax: 통과
render tree decoder fixture: 통과
core build-info fixture: 통과
studio Cargo.lock fixture: 통과
shared Swift boundary: 통과
production build-info verifier: 통과
bundled studio asset verifier: 통과
전체 workflow Psych parse: 6개 통과
PR classification: macOS=true, render=true, release=true, Rust=false
v0.8.4 bridge build/provenance: 통과
v0.8.4 native renderer sample 3종: 통과
git diff --check: 통과
임시 worktree/cache 정리: 완료
main working tree: clean
```

## 잔여 위험

- Local v0.8.4 통합 검증은 성공했지만 Task #467 PR의 GitHub-hosted macOS/release checks는 PR 생성 후 확인해야 한다.
- PR #466 자체의 기존 실패 check는 Task #467 merge만으로 자동 갱신되지 않는다. 최신 `devel`을 반영하거나 workflow를 다시 실행해 새 candidate check를 만들어야 한다.
- Fixture는 현재 검출된 `dirty` retired field만 고정한다. Future upstream schema 변화는 같은 방식으로 명시적으로 조사·보정해야 한다.
- KTX/exam_kor의 layout overlap diagnostic은 기존 renderer 상태이며 Task #467 acceptance를 막지 않는다.

## Upstream sync handoff

Task #467은 PR #466이나 automation branch를 변경하지 않았다. 권장 후속 순서는 다음과 같다.

1. Task #467 PR의 GitHub-hosted CI 확인
2. Task #467 PR merge
3. `pr-merge-cleanup`으로 Issue #467과 local/publish branch 정리
4. 최신 `devel` 기준 upstream sync workflow 재실행 또는 정책에 따른 PR #466 갱신/재생성
5. 새 candidate에서 decoder fixture, v0.8.4 native smoke와 build-info/Cargo.lock provenance gate 확인
6. Upstream sync PR merge 뒤 별도 승인으로 release 작업 진행

PR #466 merge와 공개 release는 계속 Task #467 범위 밖이다.
