# Task M019 #214 Stage 3 완료 보고서

## 단계 목적

release-driven Pages deployment와 docs-only Pages deployment가 같은 Pages site를 동시에 덮어쓰지 않도록 concurrency 기준을 맞추고, PR CI가 workflow YAML parse를 수행하도록 보강한다.

## 산출물

- `.github/workflows/release-publish.yml`: release `deploy-pages` job에 `pages-deploy` concurrency 추가
- `.github/workflows/pr-ci.yml`: workflow YAML parse 검증 추가
- `mydocs/working/task_m019_214_stage3.md`: Stage 3 완료 보고서

## 변경 내용

### Release workflow concurrency

`Release Publish DMG` workflow의 `deploy-pages` job에 job-level concurrency를 추가했다.

```yaml
concurrency:
  group: pages-deploy
  cancel-in-progress: false
```

선택 이유:

- workflow-level `release-publish-${{ inputs.version }}` concurrency는 release version 단위 실행 제약을 유지한다.
- Pages deployment만 docs-only workflow와 같은 `pages-deploy` group으로 직렬화한다.
- `cancel-in-progress: false`로 official release Pages deployment와 docs-only deployment를 취소하지 않고 순서대로 처리한다.

### PR CI workflow parse

`PR CI`의 `script-checks` job에 workflow YAML parse 검증을 추가했다.

```bash
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
```

이제 새 `.github/workflows/pages-docs-deploy.yml`을 포함한 repository workflow 파일들이 PR CI에서 parse된다.

## 본문 변경 정도 / 본문 무손실 여부

기존 workflow의 release publish, signing/notarization, appcast 생성, Pages artifact upload/deploy 동작은 바꾸지 않았다. 변경은 release Pages deploy job의 concurrency와 PR CI의 syntax 검증 확장에 한정했다.

## 검증 결과

실행한 검증:

```bash
git status --short --branch
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
scripts/ci/classify-pr-changes.sh devel HEAD
bash -n scripts/ci/*.sh
rg -n "concurrency:|pages-deploy|cancel-in-progress|Psych.parse_file|pages-docs-deploy|run_release_checks" .github/workflows scripts/ci
git diff --check
git diff --name-only devel
```

결과:

- workflow YAML parse 통과.
- Ruby 실행 시 기존 로컬 gem 경고(`ffi-1.13.1`)가 출력됐지만 exit code는 0이었다.
- `bash -n scripts/ci/*.sh` 통과.
- `scripts/ci/classify-pr-changes.sh devel HEAD` 결과 `run_release_checks=true`, `run_macos_build=false`, `run_rust_verify=false`, `run_render_smoke=false`.
- `git diff --name-only devel` 기준 변경 파일에 `.github/workflows/pages-docs-deploy.yml`, `.github/workflows/pr-ci.yml`, `.github/workflows/release-publish.yml`이 포함되어 workflow 변경 범위임을 확인했다.
- `git diff --check` 통과.

## 잔여 위험

- GitHub Actions의 실제 job-level concurrency 동작은 로컬에서 재현할 수 없다. PR merge 후 release/docs-only workflow run에서 `pages-deploy` group이 기대대로 직렬화되는지 확인해야 한다.
- PR CI workflow parse는 YAML syntax 수준 검증이다. GitHub Actions expression 의미 검증이나 environment policy 검증을 대체하지 않는다.

## 다음 단계 영향

Stage 4에서는 운영 매뉴얼에 다음 기준을 반영한다.

- release workflow는 generated appcast를 배포한다.
- docs-only workflow는 public latest appcast를 보존한다.
- 두 Pages deployment 경로는 `pages-deploy` concurrency group을 공유하고 취소 없이 직렬화한다.
- PR CI는 workflow YAML parse를 수행한다.

## 승인 요청

Stage 3 결과를 승인하면 Stage 4로 진행해 CI/Release/Pages 운영 매뉴얼을 갱신한다.
