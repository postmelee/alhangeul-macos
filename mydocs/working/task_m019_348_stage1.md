# Task M019 #348 Stage 1 완료 보고서

## 단계 목적

현재 `rhwp Upstream Sync PR` workflow가 어디까지 자동화하고 어디서 멈추는지 확인하고, upstream `rhwp` 최신 release를 앱 저장소에 full sync로 반영하려면 어떤 core update 경계를 추가해야 하는지 정리한다.

## 확인 시각

- 2026-06-07 02:32 KST

## 최신 upstream 기준

Stage 1에서 GitHub release와 tag ref를 다시 확인한 결과, 수행계획서 작성 시점의 `v0.7.14`보다 최신인 `v0.7.15`가 공개되어 있었다.

| 항목 | 값 |
|------|----|
| upstream repository | `edwardkim/rhwp` |
| latest release | `v0.7.15` |
| release name | `v0.7.15 — Security patch and equation/HWPX fixes` |
| publishedAt | `2026-06-06T14:59:20Z` |
| release URL | `https://github.com/edwardkim/rhwp/releases/tag/v0.7.15` |
| resolved commit | `aa925a5954f0fd26dfcef2166cbce7877c481f44` |

따라서 #348의 실제 full sync 검증 대상은 `v0.7.14`가 아니라 `v0.7.15`로 보정한다.

## 현재 앱 저장소 기준

| 파일 | 현재 기준 |
|------|-----------|
| `rhwp-core.lock` | `rhwp_release_tag = "v0.7.13"`, `rhwp_commit = "b3e16ef212af81ef37d973ddb86d6816d3804642"` |
| `RustBridge/Cargo.toml` | `rhwp` dependency `tag = "v0.7.13"`, `features = ["native-skia"]` |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | `source_release_tag = "v0.7.13"`, `source_resolved_commit = "b3e16ef212af81ef37d973ddb86d6816d3804642"` |

#346은 `rhwp-studio` only PR로 닫혔고 merge되지 않았으므로, 현재 `devel`은 core와 studio 모두 `v0.7.13` 기준이다. full sync 목표는 이 둘을 같은 upstream release `v0.7.15` 기준으로 맞추는 것이다.

## 현재 workflow 구조

`rhwp Upstream Sync PR` workflow는 현재 다음 흐름을 가진다.

1. `workflow_dispatch` 또는 schedule에서 실행한다.
2. `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 `source_release_tag`, `source_resolved_commit`으로 current 기준을 읽는다.
3. 입력 tag가 없으면 `gh release view`로 upstream latest release tag를 읽는다.
4. upstream checkout 후 `scripts/ci/detect-rhwp-studio-impact.sh`로 viewer impact를 판단한다.
5. `scripts/update-rhwp-core.sh --check --channel stable --tag <target>`로 core API 호환성만 확인한다.
6. upstream Docker/Vite 경로로 `rhwp-studio` asset을 빌드한다.
7. `scripts/sync-rhwp-studio.sh`로 bundled asset을 복사한다.
8. `git add Sources/HostApp/Resources/rhwp-studio`만 수행한 뒤 자동 branch와 PR을 생성한다.

즉 현재 workflow는 의도적으로 `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `Frameworks/*`를 수정하지 않는다. 자동 branch 이름과 PR 제목도 `studio-sync`, `Update bundled rhwp-studio` 기준이다.

## core update 경계

`scripts/update-rhwp-core.sh --check`는 target release fetch와 RustBridge 필수 API 존재 확인만 수행하고 파일을 수정하지 않는다. 반면 `--check` 없이 실행하면 다음 파일을 수정한다.

| 파일 | 변경 내용 |
|------|-----------|
| `RustBridge/Cargo.toml` | `rhwp` dependency를 target `tag` 또는 `rev`로 교체 |
| `RustBridge/Cargo.lock` | `cargo generate-lockfile`로 resolved commit 반영 |
| `rhwp-core.lock` | source provenance skeleton 작성 |

다만 이 단계의 `rhwp-core.lock`은 artifact sha256/size가 비어 있는 skeleton이다. 실제 lock을 완성하려면 이어서 `./scripts/build-rust-macos.sh --update-lock`을 실행해야 한다.

`scripts/build-rust-macos.sh --update-lock`는 다음 조건이 필요하다.

- `cargo`, `rustup`, `cbindgen`, `xcodebuild`, `xcrun`, `shasum`, BSD `stat`
- Rust target `aarch64-apple-darwin`, `x86_64-apple-darwin`
- `xcrun lipo`로 universal staticlib 생성
- `Frameworks/generated_rhwp.h`, `Frameworks/universal/librhwp.a`, `rhwp-ffi-symbols.txt` 검증

따라서 full sync 자동 PR이 core artifact metadata까지 갱신하려면 macOS runner 단계가 필요하다.

`v0.7.15`에 대한 check-only 검증은 통과했다.

```bash
scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.15
```

결과:

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.15
  commit:  aa925a5954f0fd26dfcef2166cbce7877c481f44
```

## PR CI 경계

현재 PR CI는 `pull_request` event로만 실행된다. 변경 분류 기준은 이미 full sync 산출물을 CI 대상으로 인식한다.

| 변경 path | PR CI 결과 |
|-----------|------------|
| `Sources/HostApp/Resources/rhwp-studio/*` | macOS build, Rust verify, release checks |
| `RustBridge/*`, `rhwp-core.lock`, `Frameworks/*` | macOS build, Rust verify |
| `.github/workflows/*`, `scripts/ci/*` | release checks |

`run_rust_verify=true`이면 macOS validation에서 `./scripts/build-rust-macos.sh --verify-lock`을 실행한다. CI는 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`로 staticlib byte hash만 skip하고, source provenance, Cargo lock, generated header, FFI symbol 검증은 유지한다.

다만 #346 검증에서 확인했듯이 `github.token`으로 생성한 자동 PR에는 일반 `pull_request` checks가 자동으로 붙지 않았다. PR CI를 동일하게 동작시키려면 Stage 2에서 다음 중 하나를 선택해야 한다.

- GitHub App installation token으로 branch push와 PR 생성
- 제한된 fine-grained PAT 사용
- 자동 PR 생성 후 별도 `repository_dispatch` 또는 `workflow_dispatch` 검증 workflow 호출

## 문서 drift

`mydocs/manual/core_dependency_operation_guide.md`에는 현재 core 기준이 `v0.7.11`이라고 남아 있다. 실제 `devel` 기준은 `v0.7.13`이므로, #348의 문서 보강 단계에서 이 drift를 같이 정리해야 한다.

## 결론

이번 작업의 목표는 upstream `rhwp` 최신 stable release를 우리 앱에 완전히 적용하는 자동 PR 후보를 만드는 것이다. 현재 최신 기준은 `v0.7.15`이며, full sync의 완료 기준은 `rhwp-studio` manifest와 native RustBridge/core provenance가 같은 release tag와 resolved commit을 가리키는 상태다.

현재 workflow는 studio-only sync이므로 #348 구현에서는 다음 확장이 필요하다.

- current 기준을 `rhwp-studio` manifest뿐 아니라 `rhwp-core.lock`도 함께 읽도록 변경
- automation branch 이름, PR 제목, PR body를 full sync 기준으로 변경
- `scripts/update-rhwp-core.sh --channel stable --tag <target>` 실행 경로 추가
- macOS runner에서 `scripts/build-rust-macos.sh --update-lock` 실행
- `git add` 범위를 `Sources/HostApp/Resources/rhwp-studio`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`, 필요한 `Frameworks/*` 산출물까지 확장
- 자동 생성 PR에 PR CI가 붙는 token/dispatch 구조 선택

## 다음 단계

Stage 2에서는 full sync workflow 구조와 PR CI 트리거 방식을 비교해 최종 설계를 고정한다. 특히 Ubuntu job과 macOS job을 분리할지, macOS 단일 job으로 단순화할지, 자동 PR 생성 token을 어떤 운영 권한으로 둘지 결정해야 한다.

## 승인 요청 사항

Stage 1 보고서를 승인하면 Stage 2 `full sync 설계와 PR CI 트리거 설계 확정`으로 진행한다.
