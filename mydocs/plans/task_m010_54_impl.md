# Issue #54 구현 계획서

## 작업명

core provenance를 edwardkim/rhwp 기준으로 정합화

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_54.md`를 기준으로 진행한다.
- 이번 작업은 core repository 기준 정합화이며, `Vendor/rhwp` submodule 제거는 후속 Issue #30에서 다룬다.
- `RustBridge/Cargo.toml` dependency source 전환과 `Cargo.lock` 갱신은 이번 범위에서 제외한다.
- 문서는 현재 프로젝트 구조 설명으로 작성하고, 불필요한 변경 이력 설명은 넣지 않는다.
- 앱 저장소 URL, GitHub PR 대상 저장소, bundle identifier는 core repository 정리와 별개이므로 변경하지 않는다.

## Stage 1: core repository 표기와 영향 범위 조사

대상:

- `.gitmodules`
- `rhwp-core.lock`
- `scripts/build-rust-macos.sh`
- `scripts/update-rhwp-core.sh`
- `README.md`
- `AGENTS.md`
- `mydocs/tech/`
- `mydocs/manual/`
- `mydocs/plans/`
- `mydocs/report/`
- `mydocs/working/`

작업:

- 현재 운영 파일과 문서에서 core repository URL, submodule 기준, lock provenance 표기를 조사한다.
- 앱 저장소 URL과 bundle identifier 문맥은 core repository 정리 대상에서 제외해 분류한다.
- 후속 작업에 직접 영향을 주는 문서와 역사 기록으로 남길 문서를 구분한다.
- Stage 2 이후 검색 게이트에서 사용할 패턴을 확정한다.

산출물:

- `mydocs/working/task_m010_54_stage1.md`

검증:

```bash
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git|core submodule|rhwp-core.lock" \
  .gitmodules rhwp-core.lock README.md AGENTS.md RustBridge scripts mydocs/tech mydocs/manual mydocs/plans mydocs/report mydocs/working
git diff --check -- mydocs/plans/task_m010_54_impl.md
```

완료 조건:

- 변경 대상과 보존 대상이 문서로 분리되어 있다.
- Stage 2~4에서 수정할 파일 목록이 확정되어 있다.

## Stage 2: submodule URL, lock, build/update script 정리

대상:

- `.gitmodules`
- `rhwp-core.lock`
- `scripts/build-rust-macos.sh`
- `scripts/update-rhwp-core.sh`

작업:

- `Vendor/rhwp` submodule URL을 `https://github.com/edwardkim/rhwp.git` 기준으로 정리한다.
- `rhwp-core.lock`의 `rhwp_repo`를 같은 기준으로 정리한다.
- `scripts/build-rust-macos.sh`의 lock 생성값을 정리한다.
- `scripts/update-rhwp-core.sh`의 core fetch/update 기준과 안내 메시지를 정리한다.
- 현재 고정 commit `1e9d78a1d40c71779d81c6ec6870cd301d912626`은 유지한다.

산출물:

- `mydocs/working/task_m010_54_stage2.md`

검증:

```bash
bash -n scripts/build-rust-macos.sh
bash -n scripts/update-rhwp-core.sh
git diff --check -- .gitmodules rhwp-core.lock scripts/build-rust-macos.sh scripts/update-rhwp-core.sh
```

완료 조건:

- lock 생성과 update script가 같은 core repository 기준을 사용한다.
- submodule 구조는 유지되고 commit SHA는 변경되지 않는다.

## Stage 3: 운영 문서 정리

대상:

- `README.md`
- `AGENTS.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/release_distribution_guide.md`

작업:

- README의 core dependency 설명, 프로젝트 구조, core provenance 문구를 정리한다.
- AGENTS의 core 운영 규칙과 필수 참조 문서 설명을 정리한다.
- architecture 문서의 소유 경계와 core update 기준을 정리한다.
- build/release/core operation manual의 submodule, lock, release 검증 설명을 정리한다.
- 후속 Issue #30에서 git-rev dependency 전환이 예정되어 있음을 현재 구조와 충돌하지 않는 방식으로 남긴다.

산출물:

- `mydocs/working/task_m010_54_stage3.md`

검증:

```bash
git diff --check -- README.md AGENTS.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/release_distribution_guide.md
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git" \
  README.md AGENTS.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/release_distribution_guide.md
```

완료 조건:

- 현재 운영 문서의 core repository 기준이 일관된다.
- 앱 저장소 URL과 bundle identifier 문맥은 변경되지 않는다.

## Stage 4: 기존 산출 문서와 Issue #30 계획 상태 정리

대상:

- `mydocs/tech/task_m010_28_sample_provenance.md`
- `mydocs/plans/task_m010_30.md`
- 필요 시 `mydocs/plans/task_m050_29.md`
- 필요 시 `mydocs/report/task_m050_29_report.md`
- 필요 시 `mydocs/working/task_m050_29_stage*.md`

작업:

- Issue #28 sample provenance 문서의 source repository 표기를 현재 기준으로 정리한다.
- Issue #29 lock provenance 관련 문서 중 후속 작업자가 읽을 가능성이 큰 문서의 repository 기준을 정리한다.
- Issue #30 수행계획서는 이번 작업 완료 전 구현 진행 금지 상태임을 문서 안에서 명확히 하고, 후속 재작성 지점을 남긴다.
- 과거 완료 보고서 전체를 일괄 재작성하지 않고, 현재 운영 기준으로 계속 참조되는 문서만 좁게 수정한다.

산출물:

- `mydocs/working/task_m010_54_stage4.md`

검증:

```bash
git diff --check -- mydocs/tech/task_m010_28_sample_provenance.md mydocs/plans/task_m010_30.md mydocs/plans/task_m050_29.md mydocs/report/task_m050_29_report.md mydocs/working
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git" \
  mydocs/tech/task_m010_28_sample_provenance.md mydocs/plans/task_m010_30.md mydocs/plans/task_m050_29.md mydocs/report/task_m050_29_report.md mydocs/working
```

완료 조건:

- 후속 Issue #30이 잘못된 core repository 기준으로 이어지지 않는다.
- 현재 운영 기준 문서와 과거 기록 보존 범위가 단계 보고서에 기록되어 있다.

## Stage 5: 전체 검증과 최종 보고

대상:

- 전체 변경 파일
- `mydocs/orders/20260426.md`
- `mydocs/report/task_m010_54_report.md`

작업:

- submodule URL sync와 checkout 검증을 수행한다.
- Rust bridge lock verify, build, Swift/Xcode build, render smoke 검증을 수행한다.
- core repository 표기 검색 게이트를 수행한다.
- 오늘할일 상태를 완료로 갱신한다.
- 최종 결과 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_54_stage5.md`
- `mydocs/report/task_m010_54_report.md`

검증:

```bash
git diff --check
git submodule sync -- Vendor/rhwp
git submodule update --init --recursive Vendor/rhwp
./scripts/build-rust-macos.sh --verify-lock
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git" \
  .gitmodules rhwp-core.lock README.md AGENTS.md RustBridge scripts mydocs/tech mydocs/manual mydocs/plans
git status --short
```

완료 조건:

- core dependency/provenance 기준이 `edwardkim/rhwp`로 일관된다.
- build와 render smoke 검증 결과가 최종 보고서에 기록되어 있다.
- 후속 Issue #30이 새 기준으로 재작성 가능한 상태다.

## 승인 요청

이 구현 계획서 기준으로 Stage 1을 진행할지 승인 요청한다.
