# Issue #54 Stage 1 완료 보고서

## 단계 목적

core repository URL, submodule 기준, lock provenance 표기가 어느 파일과 문서에 남아 있는지 조사하고, 후속 단계에서 수정할 대상과 보존할 역사 기록을 분리한다.

## 조사 범위

다음 경로를 대상으로 검색했다.

- `.gitmodules`
- `rhwp-core.lock`
- `README.md`
- `AGENTS.md`
- `RustBridge`
- `scripts`
- `mydocs/tech`
- `mydocs/manual`
- `mydocs/plans`
- `mydocs/report`
- `mydocs/working`

검색 패턴:

```bash
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git|core submodule|rhwp-core.lock" \
  .gitmodules rhwp-core.lock README.md AGENTS.md RustBridge scripts mydocs/tech mydocs/manual mydocs/plans mydocs/report mydocs/working
```

## 확인한 현재 기준

현재 고정 core commit은 `1e9d78a1d40c71779d81c6ec6870cd301d912626`이다.

확인 결과:

- `git ls-files -s Vendor/rhwp`: gitlink가 `1e9d78a1d40c71779d81c6ec6870cd301d912626`을 가리킨다.
- `git submodule status --recursive`: `Vendor/rhwp`가 같은 commit 기준으로 표시된다.
- `gh api repos/edwardkim/rhwp/commits/1e9d78a1d40c71779d81c6ec6870cd301d912626 --jq '.sha'`: 같은 commit SHA가 조회된다.
- `git ls-remote https://github.com/edwardkim/rhwp.git refs/heads/main refs/heads/devel refs/heads/ios/devel`: 원격 branch refs 조회가 가능하다.

따라서 Stage 2에서는 commit을 바꾸지 않고 repository URL과 provenance 표기만 정리한다.

## 변경 대상 분류

### Stage 2 대상

core dependency와 lock 생성 동작에 직접 영향을 주는 파일이다.

- `.gitmodules`
- `rhwp-core.lock`
- `scripts/build-rust-macos.sh`
- `scripts/update-rhwp-core.sh`

수정 방향:

- submodule URL과 lock의 `rhwp_repo` 값을 `https://github.com/edwardkim/rhwp.git` 기준으로 맞춘다.
- build/update script가 새 lock을 쓸 때 같은 URL을 기록하도록 정리한다.
- 현재 고정 commit SHA는 유지한다.

### Stage 3 대상

현재 운영 문서와 에이전트 규칙이다.

- `README.md`
- `AGENTS.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/release_distribution_guide.md`

수정 방향:

- core source repository와 submodule 운영 기준을 `edwardkim/rhwp` 기준으로 정리한다.
- 앱 저장소 URL과 bundle identifier 문맥은 유지한다.
- 후속 Issue #30의 git-rev dependency 전환 설명은 현재 submodule 구조와 충돌하지 않게 둔다.

### Stage 4 대상

후속 작업자가 다시 읽을 가능성이 큰 산출 문서와 계획 문서다.

- `mydocs/tech/task_m010_28_sample_provenance.md`
- `mydocs/plans/task_m010_30.md`
- `mydocs/plans/task_m050_29.md`
- `mydocs/report/task_m050_29_report.md`
- `mydocs/working/task_m050_29_stage*.md`

수정 방향:

- Issue #28 sample provenance의 source repository 표기를 현재 기준으로 정리한다.
- Issue #29 lock provenance 문서의 repository 기준을 정리한다.
- Issue #30 수행계획서는 현재 기준으로 재작성 전에는 구현으로 이어지지 않도록 상태를 분명히 한다.

## GitHub Issue 본문 영향

Issue #28~#32 본문도 조사했다.

결과:

- #28: `Vendor/rhwp` 기반 설명은 있으나 비대상 core repository URL 직접 표기는 없다.
- #29: lock 예시에 비대상 core repository URL이 들어 있다.
- #30: git dependency 예시에 비대상 core repository URL이 들어 있다.
- #31: `Vendor/rhwp` 구조 설명은 있으나 비대상 core repository URL 직접 표기는 없다.
- #32: core repository URL 직접 표기는 없다.

Stage 4에서 GitHub Issue #29와 #30 본문은 함께 정리하는 것이 맞다. #28, #31은 `Vendor/rhwp`를 submodule 구조 설명으로 유지할지, 후속 #30 이후 설명으로 바꿀지 Stage 4에서 다시 판단한다.

## 보존 대상

다음 문맥은 이번 작업에서 일괄 수정하지 않는다.

- 앱 저장소 URL과 PR 대상 저장소
- bundle identifier와 PlugInKit 검증 로그
- 과거 완료 보고서 중 현재 운영 기준 문서로 다시 읽지 않는 역사 기록
- core repository와 무관한 `postmelee/alhangeul-macos` 링크
- `com.postmelee.alhangeulmac` 계열 identifier

이 분리를 유지하지 않으면 core repository 정리 작업이 앱 식별자 변경 작업으로 번질 수 있다.

## 검색 게이트

Stage 2~5에서 사용할 검색 게이트는 다음으로 확정한다.

```bash
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git" \
  .gitmodules rhwp-core.lock README.md AGENTS.md RustBridge scripts mydocs/tech mydocs/manual mydocs/plans
```

최종 결과에는 `edwardkim/rhwp` 기준 설명만 남아야 한다. `mydocs/report`와 `mydocs/working` 전체는 역사 기록이 섞여 있으므로 Stage 4에서 후속 작업에 영향을 주는 파일만 좁게 정리한다.

## 검증 결과

구현계획서 기준 Stage 1 검증 명령을 실행했다.

```bash
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git|core submodule|rhwp-core.lock" \
  .gitmodules rhwp-core.lock README.md AGENTS.md RustBridge scripts mydocs/tech mydocs/manual mydocs/plans mydocs/report mydocs/working
```

결과: 변경 대상과 보존 대상을 위와 같이 분류했다.

```bash
git diff --check -- mydocs/plans/task_m010_54_impl.md
```

결과: 통과.

추가 확인:

- GitHub Issue #28~#32 본문을 확인했다.
- 결과: #29와 #30에 core repository URL 정리가 필요한 항목이 있음을 확인했다.

## 잔여 위험

- Stage 4에서 GitHub Issue 본문 수정까지 포함할 경우, 구현계획서의 Stage 4 범위를 약간 보강해야 한다.
- `mydocs/report`와 `mydocs/working` 전체를 검색 게이트에 넣으면 과거 기록이 많이 잡힌다. 최종 게이트는 현재 운영 문서와 후속 계획 문서 중심으로 둔다.
- submodule URL 변경 후 로컬 `.git/config`가 이전 URL을 유지할 수 있으므로 Stage 5에서 `git submodule sync -- Vendor/rhwp`가 필요하다.

## 다음 단계 영향

Stage 2에서는 다음 파일만 수정하면 된다.

- `.gitmodules`
- `rhwp-core.lock`
- `scripts/build-rust-macos.sh`
- `scripts/update-rhwp-core.sh`

Stage 2 완료 후에는 shell syntax와 diff whitespace 검증으로 충분하다. 실제 submodule sync와 전체 build 검증은 Stage 5에서 수행한다.

## 승인 요청

이 Stage 1 완료 보고서 기준으로 Stage 2를 진행할지 승인 요청한다.
