# Task M019 #287 최종 보고서

## 작업 요약

- 이슈: #287 rhwp upstream release check가 upstream LFS smudge 실패에 영향받지 않게 수정
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task287`
- 기준 브랜치: `devel`
- 단계 수: 4단계
- 목적: upstream `edwardkim/rhwp` checkout 중 Git LFS 대용량 객체 다운로드가 실패해도 release check와 sync PR workflow가 필요한 source 확인을 계속할 수 있게 한다.

## 결과

두 scheduled workflow 실패의 공통 원인은 upstream `edwardkim/rhwp` checkout 중 `pdf-large/hwp3-sample10-hwp5-2022.pdf` LFS 객체 다운로드가 LFS budget 초과로 실패한 것이었다.

이번 작업에서는 앱 저장소 checkout이나 전역 Git 설정을 바꾸지 않고, upstream 임시 checkout 경로에만 LFS smudge skip을 적용했다.

- `scripts/update-rhwp-core.sh`: 임시 upstream repository에 `lfs.skipSmudge true` 설정, demo/stable checkout에 `GIT_LFS_SKIP_SMUDGE=1` 적용
- `.github/workflows/rhwp-upstream-sync-pr.yml`: upstream clone과 target checkout에 `GIT_LFS_SKIP_SMUDGE=1` 적용, clone 후 local `lfs.skipSmudge true` 설정

`v0.7.13` target release check와 sync PR checkout/impact 판정 경로는 로컬 네트워크 검증에서 통과했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | `Check out upstream rhwp` 단계의 upstream clone/checkout에 LFS smudge skip 적용 |
| `scripts/update-rhwp-core.sh` | release/demo target checkout용 임시 repository에 LFS smudge skip 설정 적용 |
| `mydocs/orders/20260527.md` | #287 작업 시작과 완료 상태 기록 |
| `mydocs/plans/task_m019_287.md` | 수행계획서 |
| `mydocs/plans/task_m019_287_impl.md` | 구현계획서 |
| `mydocs/working/task_m019_287_stage1.md` | 실패 경로와 LFS skip 적용 지점 조사 보고 |
| `mydocs/working/task_m019_287_stage2.md` | checkout LFS smudge 비활성화 구현 보고 |
| `mydocs/working/task_m019_287_stage3.md` | `v0.7.13` release check와 sync impact 검증 보고 |
| `mydocs/report/task_m019_287_report.md` | 본 최종 보고서 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13` | LFS smudge가 대용량 PDF 다운로드를 시도해 실패 | 외부 환경 변수 없이 통과 |
| upstream release check wrapper | `compatibility_status=failed` | `compatibility_status=passed` |
| sync PR upstream checkout | `git clone` checkout 중 LFS budget 초과로 실패 | LFS smudge skip clone과 target checkout 통과 |
| impact detection | checkout 실패로 미실행 | `has_viewer_impact=true`, impact path 427개 산출 |
| 코드/workflow 변경 | 없음 | 2개 파일, checkout 명령 2곳과 local config 설정 추가 |

전체 diff 기준:

```text
8 files changed, 816 insertions(+), 4 deletions(-)
```

최종 보고서와 오늘할일 완료 갱신을 포함하면 변경 파일은 9개다.

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `e6ad0a1` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `d635ed0` | 구현 계획서 작성 |
| Stage 1 | `a623c03` | upstream checkout 실패 경로 정리 |
| Stage 2 | `21221d4` | upstream checkout LFS smudge 비활성화 |
| Stage 3 | `7f71409` | LFS skip checkout 경로 검증 |
| Stage 4 | 본 커밋 | 최종 보고서와 오늘할일 완료 처리 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `v0.7.13` target compatibility check가 LFS 객체 다운로드 없이 통과 | OK | `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13` 통과 |
| upstream release check wrapper가 통과 | OK | `compatibility_status=passed` |
| sync PR checkout 대응 경로가 target commit까지 checkout | OK | `b3e16ef212af81ef37d973ddb86d6816d3804642` checkout 통과 |
| impact detection이 upstream checkout 입력으로 정상 종료 | OK | `has_viewer_impact=true`, impact path 427개 |
| workflow YAML과 shell syntax 검증 | OK | `bash -n`, Ruby `Psych.parse_file`, `git diff --check` 통과 |
| core lock과 bundled asset 미변경 | OK | 변경 파일 목록에 `rhwp-core.lock`, `RustBridge/*`, `Sources/HostApp/Resources/rhwp-studio/*` 없음 |

실행한 주요 검증:

```bash
bash -n scripts/update-rhwp-core.sh
bash -n scripts/ci/check-rhwp-upstream-release.sh
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13
scripts/ci/check-rhwp-upstream-release.sh --target-tag v0.7.13 --run-compatibility-check true
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/edwardkim/rhwp.git build.noindex/rhwp-upstream
GIT_LFS_SKIP_SMUDGE=1 git -C build.noindex/rhwp-upstream checkout --detach b3e16ef212af81ef37d973ddb86d6816d3804642
scripts/ci/detect-rhwp-studio-impact.sh --upstream-dir build.noindex/rhwp-upstream --current-tag v0.7.12 --current-commit 1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5 --target-tag v0.7.13 --target-commit b3e16ef212af81ef37d973ddb86d6816d3804642 --output-dir build.noindex/rhwp-upstream-impact
git diff --check
```

참고:

- Ruby YAML parse 중 `ffi-1.13.1` extension 경고가 출력됐지만 `parsed`로 종료되어 parse 실패는 아니었다.
- Stage 3 검증 산출물 `build.noindex/rhwp-upstream`와 `build.noindex/rhwp-upstream-impact`는 최종 단계에서 정리했다.

## 미수행 범위

- `rhwp-core.lock`을 `v0.7.13`으로 갱신
- `RustBridge/Cargo.toml` 또는 `RustBridge/Cargo.lock` dependency 갱신
- bundled `rhwp-studio` asset 갱신
- upstream `edwardkim/rhwp`의 LFS budget 또는 repository 구성 수정
- 실제 자동 PR 생성 workflow 실행
- release/publish workflow 실행, signing, notarization, Homebrew 배포

## 잔여 위험과 후속 작업

| 항목 | 내용 |
|------|------|
| GitHub-hosted workflow 재실행 | 로컬 검증은 통과했지만 Actions schedule runner에서의 실제 재실행은 PR merge 후 수동 dispatch 또는 다음 schedule로 확인해야 한다. |
| sync PR 후속 build 단계 | 이번 작업은 upstream checkout과 impact detection 경로를 검증했다. 실제 bundled `rhwp-studio` build/sync/PR 생성 단계는 #204 자동화의 기존 범위다. |
| LFS fixture 검증 제외 | LFS smudge skip은 대용량 fixture 실제 content를 받지 않는다는 뜻이다. 이번 작업의 목적은 release 감시와 sync PR 자동화 안정화이므로 허용 범위다. |

## PR close 전략

PR 본문에는 다음을 명시한다.

```text
Closes #287
```

## 작업지시자 승인 요청

최종 보고 결과를 승인하면 PR 게시 절차로 진행한다. 다음 절차는 `publish/task287` 원격 브랜치 push와 `devel` 대상 Open PR 생성이다.
