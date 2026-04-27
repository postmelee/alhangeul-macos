# Issue #54 Stage 3 완료 보고서

## 단계 목적

운영 문서와 에이전트 규칙의 core repository 기준을 `edwardkim/rhwp`로 정리한다. 현재 submodule 구조는 유지하되, 후속 Issue #30에서 릴리즈 태그 기반 dependency 전환을 진행할 수 있도록 문구를 맞췄다.

## 산출물

변경 파일:

- `AGENTS.md`
  - 프로젝트 개요와 core 최신화 규칙을 `edwardkim/rhwp` 기준으로 정리했다.
  - `build.noindex` 규칙의 Spotlight 문구를 검색 혼선 방지 표현으로 정리했다.
- `README.md`
  - 프로젝트 소개, v0.1.0 이정표, Core Bridge 설명, core update 설명, Project Structure를 `edwardkim/rhwp` 기준으로 정리했다.
  - 후속 dependency 전환 단계에서 `edwardkim/rhwp` 릴리즈 태그와 resolved commit을 함께 고정한다는 방향을 남겼다.
- `mydocs/tech/project_architecture.md`
  - 상위 구조와 core/app 소유 경계를 `edwardkim/rhwp` 기준으로 정리했다.
  - `Vendor/rhwp` 제거와 릴리즈 태그 기반 dependency 전환이 후속 작업임을 명시했다.
- `mydocs/manual/build_run_guide.md`
  - 초기 설정에서 현재 core source repository 기준을 명시했다.
  - `rhwp_repo`는 verify 직접 대상이 아니라 provenance 기록 항목임을 분리해 적었다.
- `mydocs/manual/core_submodule_operation_guide.md`
  - 현재 submodule 단계의 사용 기준을 `edwardkim/rhwp` `devel`로 정리했다.
  - 최신 릴리즈는 후속 git dependency 전환 기준으로 분리했다.
- `mydocs/manual/release_distribution_guide.md`
  - release note와 lock 설명에서 `edwardkim/rhwp` core commit 기준을 명확히 했다.

변경량:

```text
AGENTS.md                                       |  6 +++---
README.md                                       | 12 ++++++------
mydocs/manual/build_run_guide.md                |  6 +++++-
mydocs/manual/core_submodule_operation_guide.md | 10 +++++-----
mydocs/manual/release_distribution_guide.md     |  6 +++---
mydocs/tech/project_architecture.md             |  7 ++++---
6 files changed, 26 insertions(+), 21 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 운영 문서의 core repository 기준과 후속 dependency 전환 방향을 정리한 문서 변경이다.

유지한 내용:

- 현재 `Vendor/rhwp` submodule 구조
- `rhwp-core.lock` provenance lock 정책
- 앱 저장소 URL과 PR 대상 저장소
- bundle identifier와 LaunchServices/PlugInKit 검증 기준
- build, render, release 검증 명령 구조

변경하지 않은 범위:

- 코드와 script
- submodule URL과 lock 파일
- Cargo dependency
- GitHub Issue 본문
- #28/#29/#30 산출 문서

## 검증 결과

구현계획서 기준 Stage 3 검증:

```bash
git diff --check -- README.md AGENTS.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/release_distribution_guide.md
```

결과: 통과.

```bash
rg -n "github.com/[^/]+/rhwp|[^A-Za-z]rhwp.git" \
  README.md AGENTS.md mydocs/tech/project_architecture.md mydocs/manual/build_run_guide.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/release_distribution_guide.md
```

결과: `README.md`의 `edwardkim/rhwp` 링크만 남았다.

추가 확인:

- 비대상 core repository URL과 사용자가 피하라고 한 표현이 Stage 3 운영 문서에 남지 않았는지 확인했다.
- 결과: 출력 없음.

## 잔여 위험

- Stage 4 전까지 #28 sample provenance, #29 lock provenance 문서, #30 수행계획서에는 아직 이전 기준 문구가 남아 있을 수 있다.
- GitHub Issue #29와 #30 본문은 아직 정리하지 않았다.
- README와 manual은 후속 #30 완료 후 `Vendor/rhwp` 제거와 릴리즈 태그 dependency 기준으로 다시 갱신해야 한다.

## 다음 단계 영향

Stage 4에서는 후속 작업자가 다시 읽을 가능성이 큰 산출 문서와 계획 문서를 정리한다.

대상:

- `mydocs/tech/task_m010_28_sample_provenance.md`
- `mydocs/plans/task_m010_30.md`
- 필요 시 `mydocs/plans/task_m050_29.md`
- 필요 시 `mydocs/report/task_m050_29_report.md`
- 필요 시 `mydocs/working/task_m050_29_stage*.md`
- GitHub Issue #29와 #30 본문

## 승인 요청

이 Stage 3 완료 보고서 기준으로 Stage 4를 진행할지 승인 요청한다.
