# Task M016 #167 Stage 1 보고서

## 단계 목적

`rhwp v0.7.10`을 M16 release 기준으로 올려도 되는지 실제 dependency 변경 전에 확인한다. 확인 범위는 upstream release/tag metadata, resolved commit, `update-rhwp-core.sh` required API gate, bundled `rhwp-studio` asset sync 경로이다.

## 산출물

| 파일 | 라인 수 | 내용 |
|------|---------|------|
| `mydocs/working/task_m016_167_stage1.md` | 231 | `v0.7.10` compatibility와 `rhwp-studio` sync 가능성 조사 |
| `mydocs/orders/20260506.md` | 17 | #167 상태를 Stage 2 승인 대기로 갱신 |

조사 대상 파일의 현재 상태:

| 파일 | 현재 기준 |
|------|-----------|
| `rhwp-core.lock` | `v0.7.9`, commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863` |
| `RustBridge/Cargo.toml` | `rhwp` dependency `tag = "v0.7.9"` |
| `RustBridge/Cargo.lock` | `rhwp` source `tag=v0.7.9#0fb3e6758b8ad11d2f3c3849c83b914684e83863` |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | `source_release_tag = v0.7.9`, `source_resolved_commit = 0fb3e6758b8ad11d2f3c3849c83b914684e83863` |
| `scripts/sync-rhwp-studio.sh` | `EXPECTED_COMMIT`과 manifest `source_release_tag`가 `v0.7.9` 기준으로 hardcode |
| `scripts/verify-rhwp-studio-assets.sh` | manifest commit 검증이 `v0.7.9` commit으로 hardcode |

## 본문 변경 정도 / 본문 무손실 여부

Stage 1은 조사 단계라 제품 코드, dependency lock, bundled asset은 변경하지 않았다. 추적 파일 변경은 Stage 1 보고서 추가와 오늘할일 상태 갱신뿐이다.

`build.noindex/rhwp-upstream-task167`에는 `v0.7.10` upstream tree를 얕게 clone했다. `build.noindex/`는 `.gitignore` 대상이므로 commit 대상이 아니다.

## 검증 결과

### 브랜치 상태

```text
$ git status --short --branch
## local/task167...origin/devel-webview [ahead 2]
```

### upstream release metadata

```text
$ gh release view -R edwardkim/rhwp v0.7.10 --json tagName,publishedAt,url
{"publishedAt":"2026-05-05T17:56:40Z","tagName":"v0.7.10","url":"https://github.com/edwardkim/rhwp/releases/tag/v0.7.10"}
```

`v0.7.10` tag는 annotated tag이다. `refs/tags/v0.7.10`은 tag object이고, 실제 dependency 기준으로 써야 할 peeled commit은 `refs/tags/v0.7.10^{}` 값이다.

```text
$ git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.10
2a6f59f1f64958ace5181f04cdf40cf77fa709b5	refs/tags/v0.7.10

$ git ls-remote --tags https://github.com/edwardkim/rhwp.git 'refs/tags/v0.7.10^{}'
62a458aa317e962cd3d0eec6096728c172d57110	refs/tags/v0.7.10^{}
```

Stage 2의 stable 기준 resolved commit은 `62a458aa317e962cd3d0eec6096728c172d57110`으로 기록해야 한다.

### core compatibility gate

```text
$ ./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.10
From https://github.com/edwardkim/rhwp
 * [new tag]         v0.7.10    -> v0.7.10
Checked rhwp core target:
  channel: stable
  tag:     v0.7.10
  commit:  62a458aa317e962cd3d0eec6096728c172d57110
```

결과: 통과. `scripts/update-rhwp-core.sh`가 요구하는 API는 `build_page_render_tree`, `get_bin_data`, `render_page_svg_native`, `get_page_info_native`, `extract_thumbnail_only`이고, `v0.7.10` peeled commit에서 모두 확인되었다.

따라서 Stage 2에서 `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.10` 실행으로 core dependency와 lock 갱신을 진행해도 된다.

### current bundled studio provenance

현재 bundled `rhwp-studio` manifest:

```text
source_repository: https://github.com/edwardkim/rhwp.git
source_ref_kind: release-tag
source_release_tag: v0.7.9
source_resolved_commit: 0fb3e6758b8ad11d2f3c3849c83b914684e83863
copied_from: rhwp-studio/dist
copied_file_count: 50
copied_total_bytes: 27704089
```

현재 bundled asset 구조 검증:

```text
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task167/Sources/HostApp/Resources/rhwp-studio
```

현재 verifier는 v0.7.9 commit을 기대하므로 Stage 3에서 manifest만 `v0.7.10`으로 바꾸면 검증이 실패한다. `scripts/verify-rhwp-studio-assets.sh`의 hardcode도 함께 갱신해야 한다.

### rhwp-studio sync 경로

`scripts/sync-rhwp-studio.sh`의 현재 요구 사항:

- optional upstream checkout 인자, 기본값 `build.noindex/rhwp-upstream-task134`
- upstream checkout HEAD가 `EXPECTED_COMMIT=0fb3e6758b8ad11d2f3c3849c83b914684e83863`와 일치해야 함
- upstream root에 `pkg/rhwp.js`, `pkg/rhwp_bg.wasm` 필요
- upstream `rhwp-studio/dist/index.html` 필요
- `rsync -a --delete --exclude 'samples/' "$DIST/" "$TARGET/"`로 bundled resource tree 교체
- `index.html`의 `crossorigin` 제거
- entrypoint hash와 copied file count/bytes를 계산해 `manifest.json` 재작성
- 마지막에 `scripts/verify-rhwp-studio-assets.sh` 실행

`v0.7.10` upstream tree는 조사용으로 `build.noindex/rhwp-upstream-task167`에 얕게 clone했다.

```text
$ git -C build.noindex/rhwp-upstream-task167 rev-parse HEAD
62a458aa317e962cd3d0eec6096728c172d57110
```

upstream `rhwp-studio/package.json`은 `version = "0.7.10"`이고 build script는 `tsc && vite build`이다. 현재 repository-local sync script는 relative base를 위해 `npx tsc && npx vite build --base ./`를 기록하고 실행하도록 요구한다.

초기 clone 직후에는 WASM pkg 산출물이 없다.

```text
$ test -f build.noindex/rhwp-upstream-task167/pkg/rhwp.js
exit 1

$ test -f build.noindex/rhwp-upstream-task167/pkg/rhwp_bg.wasm
exit 1
```

따라서 Stage 3의 실행 경로는 다음 순서가 현실적이다.

1. `build.noindex/rhwp-upstream-task167/.env.docker.example`을 `.env.docker`로 준비한다.
2. `build.noindex/rhwp-upstream-task167`에서 `docker-compose --env-file .env.docker run --rm wasm`을 실행해 root `pkg/` 산출물을 만든다.
3. `build.noindex/rhwp-upstream-task167/rhwp-studio`에서 `npm ci`를 실행한다.
4. 같은 위치에서 `npx tsc && npx vite build --base ./`을 실행한다.
5. `scripts/sync-rhwp-studio.sh`의 expected commit/tag 기준을 `v0.7.10`으로 갱신한 뒤 `scripts/sync-rhwp-studio.sh build.noindex/rhwp-upstream-task167`을 실행한다.
6. `scripts/verify-rhwp-studio-assets.sh`도 `v0.7.10` resolved commit을 기대하도록 갱신한다.

### local tool readiness

```text
$ command -v docker
/opt/homebrew/bin/docker

$ docker --version
Docker version 29.4.0, build 9d7ad9ff18

$ docker info --format '{{.ServerVersion}}'
29.2.1

$ command -v docker-compose
/opt/homebrew/bin/docker-compose

$ docker-compose --version
Docker Compose version 5.1.3

$ node --version
v24.15.0

$ npm --version
11.12.1
```

주의: sandbox 기본 권한에서는 Docker socket 접근이 `permission denied`였고, escalated 실행에서는 Docker daemon version 확인이 통과했다. Stage 3에서 Docker build를 실제로 돌릴 때도 escalated 실행이 필요할 가능성이 높다.

### planned validation commands

구현계획서 Stage 1 검증 명령은 모두 수행했다.

```text
$ sed -n '1,260p' scripts/update-rhwp-core.sh
통과

$ sed -n '1,220p' scripts/sync-rhwp-studio.sh
통과

$ sed -n '1,220p' Sources/HostApp/Resources/rhwp-studio/manifest.json
통과

$ git diff --check
통과
```

추가로 ignored checkout 상태도 확인했다.

```text
$ git status --ignored --short build.noindex
!! build.noindex/
```

## Stage 2 진행 판단

Stage 2 core bump는 진행 가능하다.

- `v0.7.10` release metadata 확인 완료
- stable tag의 실제 resolved commit 확인 완료
- `update-rhwp-core.sh --check` required API gate 통과
- Stage 2에서 lock과 Rust bridge artifact를 갱신할 기준 commit은 `62a458aa317e962cd3d0eec6096728c172d57110`

## Stage 3 영향

`rhwp-studio`는 단순 asset 교체가 아니라 script 기준 갱신을 포함해야 한다.

- `scripts/sync-rhwp-studio.sh`의 `EXPECTED_COMMIT`과 manifest `source_release_tag`를 `v0.7.10` 기준으로 바꿔야 한다.
- `scripts/verify-rhwp-studio-assets.sh`의 expected manifest commit도 `62a458aa317e962cd3d0eec6096728c172d57110`으로 바꿔야 한다.
- upstream `pkg/` 산출물은 clone에 포함되지 않으므로 Docker WASM build가 필요하다.
- upstream `rhwp-studio/dist` 산출물도 clone에 포함되지 않으므로 npm install/build가 필요하다.
- Stage 3 작업은 Docker daemon과 npm dependency install을 동반하므로 네트워크와 권한 실패를 compatibility 실패와 분리해 기록해야 한다.

## 잔여 위험

- Stage 2에서 `cargo generate-lockfile` 또는 Rust bridge artifact build가 네트워크/로컬 toolchain 문제로 실패할 수 있다. 이는 Stage 1 compatibility 실패가 아니라 환경 실패로 분리해야 한다.
- Stage 3의 Docker WASM build와 npm build는 아직 실행하지 않았다. Docker daemon 접근은 escalated 실행에서만 확인됐다.
- `sync-rhwp-studio.sh`와 `verify-rhwp-studio-assets.sh`의 hardcode를 유지하면 `v0.7.10` manifest를 정상 검증할 수 없다.
- `v0.7.10`에서 generated WASM/JS/CSS asset 이름과 copied file count가 바뀔 수 있으므로 Stage 3에서 manifest hash를 재계산해야 한다.

## 다음 단계 영향

Stage 2에서는 core dependency와 Rust bridge artifact 갱신만 수행한다. `rhwp-studio` resource tree는 Stage 3에서 별도로 갱신한다.

Stage 2 완료 기준:

- `RustBridge/Cargo.toml`의 `rhwp` dependency가 `tag = "v0.7.10"`을 가리킨다.
- `RustBridge/Cargo.lock`의 `rhwp` source가 `62a458aa317e962cd3d0eec6096728c172d57110`으로 resolve된다.
- `rhwp-core.lock`이 `rhwp_release_tag = "v0.7.10"`과 같은 resolved commit을 기록한다.
- `scripts/build-rust-macos.sh --update-lock`과 `--verify-lock`로 artifact hash/size 정합성을 확인한다.
- `rhwp-ffi-symbols.txt` 변경 여부를 명시한다.

## 승인 요청

Stage 1 완료를 보고한다. 승인 후 Stage 2 `core dependency와 Rust bridge artifact 갱신`으로 진행한다.
