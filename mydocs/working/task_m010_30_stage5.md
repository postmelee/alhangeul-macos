# Task #30 Stage 5 완료 보고서

## 단계 목적

Stage 1-4에서 실제 dependency와 lock 기준이 `RustBridge` git dependency로 전환되었으므로, 사용자 문서와 운영 매뉴얼의 active submodule 안내를 현재 기준으로 보정한다.

## 산출물

- `README.md`
  - core 연결 방식을 `Vendor/rhwp` submodule이 아니라 `RustBridge/Cargo.toml` git dependency로 설명
  - 초기 설정에서 `git submodule update --init --recursive` 제거
  - `update-rhwp-core.sh --channel demo --rev`, `--channel stable --tag` 기준으로 core update 절차 보정
  - project structure와 mermaid diagram에서 `Vendor/rhwp` 항목 제거
- `AGENTS.md`
  - core 안정 기준을 Stable release tag + resolved commit, Demo/Preview resolved commit `rev` pin으로 보정
  - `rhwp-core.lock` 설명을 ref kind/commit/산출물 기준으로 보정
- `mydocs/tech/project_architecture.md`
  - core 소유 경계를 `edwardkim/rhwp` git dependency, `Cargo.lock`, `rhwp-core.lock` 기준으로 정리
- `mydocs/manual/core_submodule_operation_guide.md`
  - 파일명은 호환을 위해 유지하되, 본문은 core dependency 운영 가이드로 재작성
- `mydocs/manual/build_run_guide.md`
  - 초기 설정, HostApp 준비, lock verify 대상에서 submodule 준비 단계를 제거
  - `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock` 정합성 기준을 추가
- `mydocs/manual/release_distribution_guide.md`
  - 릴리스 전 확인과 체크리스트를 Cargo git dependency lock 기준으로 보정
- `mydocs/tech/core_release_compatibility.md`
  - Stable/Demo gate의 확인 명령을 현재 `update-rhwp-core.sh`와 `cargo generate-lockfile` 기준으로 보정
  - 과거 전환 예정 표현과 `Vendor/rhwp` 기반 검사 명령 제거
- `mydocs/orders/20260426.md`
  - #30 비고를 Stage 6 승인 대기 상태로 갱신
- `mydocs/working/task_m010_30_stage5.md`
  - Stage 5 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 문서 보정만 수행했다. Rust/Swift source, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`, 생성 산출물은 변경하지 않았다.

과거 작업 이력 문서와 완료 보고서는 수정하지 않았다. `mydocs/tech/task_m010_28_sample_provenance.md`의 `Vendor/rhwp` 경로는 샘플 파일 출처 증빙을 위한 역사 기록이므로 그대로 둔다.

## 검증 결과

diff whitespace:

```text
$ git diff --check
결과: 통과
```

active 구형 표현 검색:

```text
$ rg --line-number --glob '!RustBridge/target/**' --glob '!mydocs/report/**' --glob '!mydocs/working/**' --glob '!mydocs/plans/**' 'Vendor/rhwp|git submodule|submodule' README.md AGENTS.md scripts RustBridge project.yml mydocs/manual mydocs/tech
결과: active 사용자/운영 문서의 submodule 절차 안내는 제거됨
```

남은 검색 결과 분류:

- `AGENTS.md`, `mydocs/tech/project_architecture.md`: 파일명 `core_submodule_operation_guide.md` 링크
- `mydocs/manual/core_submodule_operation_guide.md`: 과거 파일명을 유지한다는 설명
- `scripts/build-rust-macos.sh`: legacy path dependency mode의 방어 메시지
- `mydocs/tech/task_m010_28_sample_provenance.md`: #28 샘플 출처 증빙을 위한 역사 기록

새 기준 키워드 확인:

```text
$ rg --line-number --glob '!RustBridge/target/**' 'git dependency|rev|release tag|resolved commit|Cargo.lock|rhwp-core.lock|demo-commit-pin' README.md AGENTS.md mydocs/tech mydocs/manual scripts rhwp-core.lock RustBridge
결과: README, AGENTS, architecture, build/run, release, core compatibility, core dependency 운영 문서에서 Cargo git dependency와 lock 기준이 확인됨
```

## 잔여 위험

- `scripts/build-rust-macos.sh`에는 Stage 2에서 도입한 legacy path dependency 호환 코드가 남아 있다. 현재 `RustBridge/Cargo.toml`은 git dependency이므로 활성 경로는 아니지만, Stage 6 통합 검증에서 lock verify와 render smoke로 실제 경로를 다시 확인한다.
- 파일명 `core_submodule_operation_guide.md`는 기존 링크 호환을 위해 유지한다. 본문 제목과 내용은 core dependency 운영 기준으로 보정했다.

## 다음 단계 영향

Stage 6에서는 문서와 실제 빌드 경로가 일치하는지 통합 검증한다. 최소 확인 대상은 `build-rust-macos.sh --verify-lock`, `check-no-appkit.sh`, `xcodegen generate`, HostApp Debug build, `validate-stage3-render.sh`, 구형 submodule 참조 최종 검색이다.

## 승인 요청

Stage 5 `사용자 문서와 운영 매뉴얼을 git dependency 기준으로 보정`을 완료했다. 이 보고서 기준으로 Stage 6 `통합 빌드와 smoke 검증`을 진행할지 승인 요청한다.
