# Issue #54 Stage 2 완료 보고서

## 단계 목적

core dependency와 lock 생성 동작에 직접 영향을 주는 파일의 repository 기준을 `edwardkim/rhwp`로 정리한다. 이번 단계에서는 submodule 구조와 고정 commit SHA를 유지했다.

## 산출물

변경 파일:

- `.gitmodules`
  - `Vendor/rhwp` submodule URL을 `https://github.com/edwardkim/rhwp.git`로 변경했다.
- `rhwp-core.lock`
  - `rhwp_repo` 값을 `https://github.com/edwardkim/rhwp.git`로 변경했다.
  - `rhwp_commit`, `built_at`, artifact sha256/size는 변경하지 않았다.
- `scripts/build-rust-macos.sh`
  - `--update-lock`이 생성하는 `rhwp_repo` 값을 같은 기준으로 변경했다.
- `scripts/update-rhwp-core.sh`
  - core update 후 초기화하는 lock template의 `rhwp_repo` 값을 같은 기준으로 변경했다.

변경량:

```text
.gitmodules                 | 2 +-
rhwp-core.lock              | 2 +-
scripts/build-rust-macos.sh | 2 +-
scripts/update-rhwp-core.sh | 2 +-
4 files changed, 4 insertions(+), 4 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 URL literal만 변경했다. 다음 값은 그대로 유지했다.

- `rhwp_branch = "devel"`
- `rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"`
- `built_at`
- `Frameworks/universal/librhwp.a` sha256/size
- `Frameworks/generated_rhwp.h` sha256/size

Submodule 제거, Cargo dependency 전환, lock schema 변경은 수행하지 않았다.

## 검증 결과

구현계획서 기준 Stage 2 검증:

```bash
bash -n scripts/build-rust-macos.sh
```

결과: 통과.

```bash
bash -n scripts/update-rhwp-core.sh
```

결과: 통과.

```bash
git diff --check -- .gitmodules rhwp-core.lock scripts/build-rust-macos.sh scripts/update-rhwp-core.sh
```

결과: 통과.

추가 확인:

```bash
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git" .gitmodules rhwp-core.lock scripts/build-rust-macos.sh scripts/update-rhwp-core.sh
```

결과:

- `.gitmodules`: `https://github.com/edwardkim/rhwp.git`
- `rhwp-core.lock`: `https://github.com/edwardkim/rhwp.git`
- `scripts/build-rust-macos.sh`: `https://github.com/edwardkim/rhwp.git`
- `scripts/update-rhwp-core.sh`: `https://github.com/edwardkim/rhwp.git`

비대상 core repository URL과 사용자가 피하라고 한 표현이 Stage 2 변경 파일에 남지 않았는지 확인했다.

결과: 출력 없음.

## 잔여 위험

- 로컬 `.git/config`의 submodule URL은 `.gitmodules` 변경만으로 자동 갱신되지 않을 수 있다. Stage 5에서 `git submodule sync -- Vendor/rhwp`를 수행한다.
- Stage 3 전까지 README, AGENTS, architecture, manual에는 기존 core repository 표기가 남아 있다.
- Stage 4 전까지 #28/#29/#30 산출 문서와 GitHub Issue 본문 일부는 아직 정리되지 않았다.

## 다음 단계 영향

Stage 3에서는 운영 문서와 에이전트 규칙을 현재 기준에 맞춰 정리한다.

대상:

- `README.md`
- `AGENTS.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/release_distribution_guide.md`

## 승인 요청

이 Stage 2 완료 보고서 기준으로 Stage 3을 진행할지 승인 요청한다.
