# Task M020 #394 Stage 1 완료보고서

## 구현과 검증

명시 portable/strict와 legacy alias를 분리했다. strict + skip env 충돌과 중복 모드는 build 전 실패한다. portable에서도 artifact 존재와 유효한 hash/size metadata를 요구한다. header를 먼저 검증하여 strict archive mismatch 메시지의 source/header/ABI 통과 주장이 실제 순서와 맞도록 했다. lock은 검증 중 쓰지 않는다.

`python3 scripts/ci/test-rust-verification-modes.py`: 18개 통과. 전체 CLI를 임시 root/fake toolchain으로 실행하여 archive 차이, legacy 호환, 옵션 충돌, commit/features/header/FFI/metadata 손상, lock 불변을 검사했다. 실제 compiler 재현성 검증은 Stage 3에서 구분한다. `bash -n`과 `git diff --check` 통과.

## 선행 PR #462 판정

**현재 초안 병합 보류.** devel `ed325b2`의 renderer에 PR `1993e36`과 같은 guard/defer만 적용한 복사본을 비교했다. 실제 RectangleNode(검정 100×100), Body clip x=10+i/width=80−2i, TextBox 중첩을 사용했다. 두 renderer에는 renderNode 방문 수만 계측했다.

| 깊이 | 현재 방문 | PR 방문 | 현재/PR 채워진 픽셀 |
|---|---:|---:|---:|
| 1 | 4 | 4 | 10000 / 10000 |
| 2 | 10 | 9 | 10000 / 8000 |
| 4 | 46 | 25 | 10000 / 7600 |
| 8 | 766 | 81 | 10000 / 6800 |
| 12 | 12286 | 169 | 10000 / 6000 |

재진입 증폭은 감소하지만 외부 overflow replay 중 내부 Body의 replay가 금지되어 clipping 결과도 달라진다. 실제 upstream 문서에서 어느 출력이 맞는지 이 합성 fixture만으로 확정하지 않는다. 따라서 의도된 중첩 overflow 의미와 출력 기대값을 고정하는 테스트, 최신 devel 재기준화 후 검증이 merge 선행 조건이다. 기존 PR의 macOS CI 성공 기록은 이 사례의 출력 동등성을 보증하지 않는다.

재현 소스·실행 파일·결과는 `build.noindex/pr462-review/`에 보관했다. `bash build.noindex/pr462-review/run.sh`로 재실행할 수 있다. 이번 배치에서는 PR #462의 code/comment/review/state를 변경하지 않았다.
