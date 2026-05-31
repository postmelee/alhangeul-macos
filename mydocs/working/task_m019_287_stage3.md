# Task M019 #287 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 적용한 LFS smudge skip 변경이 실제 upstream `v0.7.13` release check와 sync PR checkout/impact 판정 경로에서 동작하는지 확인한다.

이번 단계는 검증 단계이며 source, workflow, lock, bundled asset은 변경하지 않았다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m019_287_stage3.md` | `v0.7.13` release check, upstream checkout, impact detection 검증 결과 |

검증 중 생성된 재생성 가능 산출물:

| 경로 | 크기 | 상태 |
|------|------|------|
| `build.noindex/rhwp-upstream` | 605M | ignored build 산출물, target commit checkout 검증에 사용 |
| `build.noindex/rhwp-upstream-impact` | 104K | ignored build 산출물, impact detection output |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- workflow 변경 없음.
- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock` 변경 없음.
- bundled `Sources/HostApp/Resources/rhwp-studio` asset 변경 없음.
- 신규 단계 보고서만 추가했다.

## 검증 결과

### `update-rhwp-core.sh --check`

```bash
scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13
```

결과: 통과.

```text
From https://github.com/edwardkim/rhwp
 * [new tag]         v0.7.13    -> v0.7.13
Checked rhwp core target:
  channel: stable
  tag:     v0.7.13
  commit:  b3e16ef212af81ef37d973ddb86d6816d3804642
```

외부에서 `GIT_LFS_SKIP_SMUDGE=1`을 주지 않았는데도 통과했다. 즉 `scripts/update-rhwp-core.sh` 내부 변경만으로 release compatibility check checkout 경로가 LFS budget 실패를 회피했다.

### upstream release check wrapper

```bash
scripts/ci/check-rhwp-upstream-release.sh --target-tag v0.7.13 --run-compatibility-check true
```

결과: 통과.

```text
current_tag=v0.7.12
latest_tag=v0.7.13
target_tag=v0.7.13
outdated=true
compatibility_status=passed
```

summary에는 target URL `https://github.com/edwardkim/rhwp/releases/tag/v0.7.13`, release name `v0.7.13 — HWPX 렌더링/저장 호환성 + 시험지/공공기관 문서 회귀 정정`, published at `2026-05-26T13:57:15Z`가 기록됐다.

### sync PR checkout 대응 명령

검증 전 `build.noindex/rhwp-upstream`와 `build.noindex/rhwp-upstream-impact`는 존재하지 않았다.

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/edwardkim/rhwp.git build.noindex/rhwp-upstream
git -C build.noindex/rhwp-upstream config lfs.skipSmudge true
GIT_LFS_SKIP_SMUDGE=1 git -C build.noindex/rhwp-upstream checkout --detach b3e16ef212af81ef37d973ddb86d6816d3804642
```

결과: clone과 target commit checkout 모두 통과.

```text
HEAD is now at b3e16ef2 docs: add extension store submission notes
```

확인:

```bash
git -C build.noindex/rhwp-upstream rev-parse HEAD
git -C build.noindex/rhwp-upstream status --short
```

결과:

```text
b3e16ef212af81ef37d973ddb86d6816d3804642
```

`git status --short` 출력은 비어 있었다.

### impact detection

```bash
scripts/ci/detect-rhwp-studio-impact.sh \
  --upstream-dir build.noindex/rhwp-upstream \
  --current-tag v0.7.12 \
  --current-commit 1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5 \
  --target-tag v0.7.13 \
  --target-commit b3e16ef212af81ef37d973ddb86d6816d3804642 \
  --output-dir build.noindex/rhwp-upstream-impact
```

결과: 통과.

```text
changed paths: `1347`
impact paths: `427`
has viewer impact: `true`
current_tag=v0.7.12
current_commit=1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5
target_tag=v0.7.13
target_commit=b3e16ef212af81ef37d973ddb86d6816d3804642
has_viewer_impact=true
impact_reason_count=427
```

output 파일 line 수:

```text
1347 build.noindex/rhwp-upstream-impact/changed-v0.7.12-to-v0.7.13.txt
 427 build.noindex/rhwp-upstream-impact/impact-v0.7.12-to-v0.7.13.txt
 427 build.noindex/rhwp-upstream-impact/impact-details-v0.7.12-to-v0.7.13.tsv
```

impact path에는 `rhwp-studio/*`, `Cargo.toml`, `rust-toolchain.toml`, `src/*` 등 viewer/WASM/core 영향 경로가 포함됐다.

### 작업트리 검증

```bash
git status --short --branch
git diff --check
```

결과:

```text
## local/task287
```

`git diff --check`는 통과했다. `build.noindex/` 산출물은 ignored 경로라 git status에 나타나지 않았다.

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| `v0.7.13` target compatibility check가 LFS 객체 다운로드 없이 통과 | 통과 |
| upstream release check wrapper가 `compatibility_status=passed` 기록 | 통과 |
| sync PR checkout 대응 명령이 target commit checkout까지 통과 | 통과 |
| impact detection이 upstream checkout 입력으로 정상 종료 | 통과 |
| `rhwp-core.lock`, RustBridge dependency, bundled asset 미변경 | 확인 |

## 잔여 위험

- GitHub-hosted schedule workflow 재실행은 아직 확인하지 않았다. PR 이후 수동 재실행 또는 다음 schedule에서 확인해야 한다.
- `rhwp-upstream-sync-pr.yml`의 후속 build/sync/PR 생성 단계는 이번 Stage 3의 로컬 검증 범위가 아니다.
- `build.noindex/rhwp-upstream`는 605M의 재생성 가능 산출물이다. 최종 보고 또는 PR 준비 단계에서 정리 여부를 결정한다.

## 다음 단계 영향

Stage 4에서는 최종 보고서를 작성하고, 오늘할일 #287을 완료 처리한다. 최종 보고서에는 다음을 남긴다.

- 수정 파일과 변경 요약
- Stage 3 검증 명령과 결과
- GitHub-hosted workflow 재실행 잔여 확인 항목
- `rhwp-core.lock`과 bundled `rhwp-studio` asset을 갱신하지 않았다는 제외 범위 확인

## 승인 요청

Stage 3 결과를 승인하면 Stage 4 `최종 보고와 PR 준비`로 진행한다.
