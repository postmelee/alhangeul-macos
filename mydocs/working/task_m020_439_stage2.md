# Task M020 #439 Stage 2 완료보고서

## 단계 목적

완성된 `rhwp-core.lock`에서 `RhwpCoreBuildInfo.swift`를 deterministic하게 생성하는 writer를 추가하고, 기존 verifier와 lock reader를 fixture 경로에서도 재사용할 수 있게 확장한다. Stable release tag와 Demo/Preview commit pin을 모두 지원하며, isolated fixture test로 정상·불일치·잘못된 입력·반복 실행·production 파일 무손실 계약을 고정한다.

## 산출물

- `scripts/update-rhwp-core-build-info.sh` — 신규, 161줄
  - stable/demo lock을 검증하고 고정된 5줄 Swift source를 생성한다.
  - output과 같은 디렉터리에서 임시 파일을 만들고 verifier 통과 후 원자적으로 교체한다.
  - 생성 결과가 기존 output과 같으면 파일을 교체하지 않는다.
- `scripts/verify-rhwp-core-build-info.sh` — 172줄
  - 기존 no-argument production 호출을 보존한다.
  - `--lock-file`, `--build-info` 명시 경로를 지원한다.
  - stable/demo baseline mapping과 lock 입력 형식을 함께 검증한다.
- `scripts/ci/read-rhwp-core-lock.sh` — 86줄
  - 기존 `<key>` 호출을 보존하면서 `--lock-file FILE`을 추가했다.
  - 누락 key에서 명시적인 오류를 출력하도록 기존 오류 경로를 보정했다.
- `scripts/ci/test-rhwp-core-build-info.sh` — 신규, 224줄
  - 임시 디렉터리에서 writer/verifier/reader contract를 검증한다.
  - production lock과 Swift source의 실행 전후 SHA-256 일치를 확인한다.
- `mydocs/working/task_m020_439_stage2.md`
  - Stage 2 구현 및 검증 결과를 기록했다.
- `mydocs/orders/20260813.md`
  - #439 비고를 `Stage 2 완료 및 Stage 3 승인 대기`로 갱신했다.

## 구현 결과

### Production 호환 interface

기존 호출은 변경 없이 동작한다.

```bash
scripts/ci/read-rhwp-core-lock.sh <key>
./scripts/verify-rhwp-core-build-info.sh
```

명시적인 fixture/생성 interface를 추가했다.

```bash
scripts/ci/read-rhwp-core-lock.sh [--lock-file FILE] <key>
scripts/update-rhwp-core-build-info.sh [--lock-file FILE] [--output FILE]
scripts/verify-rhwp-core-build-info.sh [--lock-file FILE] [--build-info FILE]
```

환경 변수로 production 경로를 암묵 치환하지 않는다. 옵션을 지정하지 않으면 repository root의 `rhwp-core.lock`과 `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`만 사용한다.

### Stable/Demo mapping

- `release-tag`: `rhwp_release_tag`를 `RhwpCoreBuildInfo.releaseTag`로 사용한다.
- `commit`: `rhwp_latest_checked_release_tag`를 stable baseline label로 사용한다.
- 두 ref kind 모두 실제 `rhwp_commit`과 `rhwp_enabled_features`를 사용한다.

lock version은 `2`, ref kind는 `release-tag` 또는 `commit`, commit은 40자리 소문자 hex여야 한다. release baseline과 enabled features는 Swift 문자열 생성에 허용된 형식이어야 한다. 필수 key 누락이나 malformed input은 기존 output을 변경하지 않고 실패한다.

### Deterministic·안전한 쓰기

writer는 다음 순서로 동작한다.

1. lock과 helper 존재 여부를 확인한다.
2. ref kind에 따른 baseline key, commit, enabled features를 읽고 검증한다.
3. output과 같은 디렉터리에 임시 파일을 만든다.
4. 고정된 5줄 형식과 `0644` mode로 Swift source를 생성한다.
5. 임시 source를 기존 verifier로 다시 검증한다.
6. 기존 output과 byte-identical하면 교체하지 않는다.
7. 다를 때만 같은 filesystem 안에서 `mv`로 교체한다.

current production input에서는 `RhwpCoreBuildInfo.swift`를 교체하지 않고 `already up to date`로 종료했다.

### Isolated fixture contract

fixture test가 다음 case를 검증한다.

- stable 정상 생성, 예상 source와 byte diff, verifier 통과
- demo baseline tag, 실제 commit, 복수 enabled features 생성과 verifier 통과
- stable writer 반복 실행 결과 SHA-256 동일
- stale release tag, commit, enabled features 각각 verifier 실패 후 writer로 수렴
- 지원하지 않는 lock version/ref kind 거부
- stable tag, demo latest checked tag, commit, enabled features 누락 거부
- malformed tag, commit, enabled features 거부
- writer/verifier unknown argument와 reader option 누락 오류 문구 확인
- 모든 잘못된 lock에서 기존 output hash 유지
- 전체 fixture 실행 전후 production lock/build info hash 유지

테스트 작성 중 기존 reader가 누락 key에서 내부 `awk` 종료 상태 때문에 의도한 오류 문구를 출력하지 못하는 경로를 발견했다. assignment 상태를 명시적으로 처리해 `ERROR: missing lock key: <key>`를 출력하도록 보정하고 fixture로 고정했다.

## 본문 변경 정도 / 본문 무손실 여부

helper 2개를 추가하고 기존 helper 2개의 argument/validation contract를 확장했다. 제품 Swift/Rust source, workflow, `rhwp-core.lock` 본문은 변경하지 않았다.

`./scripts/update-rhwp-core-build-info.sh` 실행 결과 production Swift source가 이미 최신으로 판정됐고, 다음 명령으로 production source와 lock에 diff가 없음을 확인했다.

```bash
git diff --exit-code -- Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift rhwp-core.lock
```

fixture test도 두 production 파일의 실행 전후 SHA-256을 비교해 무손실을 확인했다.

## 검증 결과

구현계획서의 Stage 2 검증 명령을 fail-fast shell에서 실행했다.

```text
bash -n scripts/update-rhwp-core-build-info.sh \
  scripts/verify-rhwp-core-build-info.sh \
  scripts/ci/test-rhwp-core-build-info.sh
결과: 통과

bash -n scripts/ci/read-rhwp-core-lock.sh
결과: 통과

scripts/update-rhwp-core-build-info.sh --help
scripts/verify-rhwp-core-build-info.sh --help
결과: usage와 명시 경로 option 출력 후 정상 종료

scripts/ci/test-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo writer and verifier fixtures passed

./scripts/update-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo is already up to date: .../RhwpCoreBuildInfo.swift

./scripts/verify-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo matches rhwp-core.lock

git diff --exit-code -- Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift rhwp-core.lock
결과: 통과, production 파일 diff 없음

git diff --check
결과: 통과
```

추가 정적 검증:

```text
shellcheck scripts/ci/read-rhwp-core-lock.sh \
  scripts/update-rhwp-core-build-info.sh \
  scripts/verify-rhwp-core-build-info.sh \
  scripts/ci/test-rhwp-core-build-info.sh
shellcheck: OK
```

## 잔여 위험

- helper는 아직 upstream sync workflow에서 호출되지 않으므로 현재 자동 생성 PR은 build info를 갱신·stage하지 않는다. Stage 3에서 연결해야 한다.
- PR CI와 release rehearsal/publish도 아직 verifier를 호출하지 않으므로 repository drift를 자동 차단하지 않는다. Stage 3 완료 전에는 maintainer가 verifier를 수동 실행해야 한다.
- `releaseTag`가 demo에서 stable baseline label이라는 의미는 아직 운영 문서에 반영되지 않았다. Stage 4에서 문서화한다.
- tag와 enabled features의 허용 형식이 확장되어야 하는 upstream 변경이 생기면 writer와 verifier의 동일 validation을 함께 갱신하고 fixture를 추가해야 한다.
- #375의 Cargo.lock fingerprint와 PR #463 상태는 변경하지 않았다.

## 다음 단계 영향

Stage 3에서는 이번 단계의 production no-argument helper를 workflow에 연결한다.

1. upstream sync에서 complete lock 생성 직후 writer와 verifier를 실행한다.
2. `RhwpCoreBuildInfo.swift`를 generated candidate의 명시 stage 목록에 추가한다.
3. generated verification summary와 PR body checklist에 build info 결과를 추가한다.
4. helper/build info 변경이 core gate를 skip하지 않도록 path classification을 갱신한다.
5. PR CI에서는 fixture test와 verifier를 실행하되 writer로 drift를 수정하지 않는다.
6. release rehearsal/publish source preflight에 verifier를 추가한다.
7. workflow YAML, embedded shell, classification과 generated body를 정적으로 검증한다.

## 승인 요청

Stage 2 결과에 따라 Stage 3로 진행해도 되는지 승인 요청한다.

Stage 3에서는 sync·PR CI·release workflow와 관련 classification/PR body helper만 연결하고, 완료 시 source와 Stage 3 보고서를 함께 검증·커밋한 뒤 Stage 4 승인 대기에서 멈춘다.
