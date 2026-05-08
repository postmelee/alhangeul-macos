# Task M016 #167 구현계획서

수행계획서: `mydocs/plans/task_m016_167.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #167 rhwp v0.7.10 stable tag 반영과 M16 release 기준 재검증
- 마일스톤: M016 (`v0.1 출시 전 보강`)
- 브랜치: `local/task167`
- 작업 위치: `/private/tmp/rhwp-mac-task167`
- 기준 통합 브랜치: `devel-webview`
- 목표 core tag: `edwardkim/rhwp` `v0.7.10`
- 주 대상: `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`, bundled `rhwp-studio` manifest/resource, release provenance 문서
- 목표: M16 release artifact와 public publish workflow가 모두 `v0.7.10` 기준으로 정합화되도록 core/studio provenance와 기본 검증을 완료한다.

## 구현 원칙

- Stable core 기준은 `release tag + resolved commit`이다. branch/floating ref는 배포 기준으로 쓰지 않는다.
- 먼저 compatibility check를 실행하고, 실패하면 dependency 파일을 갱신하지 않는다.
- Rust bridge artifact는 `scripts/build-rust-macos.sh --update-lock`로 재생성한 뒤 `--verify-lock`으로 다시 검증한다.
- `rhwp-ffi-symbols.txt`는 변화가 확인되고 의도된 경우에만 갱신한다.
- HostApp viewer가 쓰는 bundled `rhwp-studio` asset도 core provenance와 맞춘다. `rhwp-core.lock`만 `v0.7.10`이고 `rhwp-studio/manifest.json`이 `v0.7.9`로 남는 상태는 기본적으로 완료로 보지 않는다.
- `rhwp-studio` `v0.7.10` asset sync가 로컬 환경에서 막히면, Stage 보고서에서 원인을 분리하고 작업지시자 판단을 받는다.
- `Frameworks/` 생성 산출물은 commit하지 않는다. 산출물 hash/size는 `rhwp-core.lock`에만 기록한다.
- 실제 public release, signing/notarization, Homebrew Cask checksum 교체는 수행하지 않는다.
- 기존 메인 worktree의 `README.md` 미커밋 변경은 이 작업 범위 밖이므로 건드리지 않는다.

## Stage 1. v0.7.10 compatibility와 sync 가능성 조사

### 목표

- `rhwp v0.7.10`이 현재 RustBridge required API와 update script gate를 통과하는지 확인한다.
- bundled `rhwp-studio`를 `v0.7.10` 기준으로 갱신할 수 있는 경로를 확인한다.

### 작업

- `gh release view -R edwardkim/rhwp v0.7.10` 또는 equivalent 명령으로 upstream release tag, published date, URL을 확인한다.
- `git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.10` 또는 update script 출력으로 resolved commit을 확인한다.
- `./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.10`을 실행한다.
- `scripts/update-rhwp-core.sh`, `scripts/sync-rhwp-studio.sh`, `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 현재 동작과 요구 입력을 확인한다.
- `rhwp-studio` asset sync가 Docker/Node/upstream clone 중 어느 경로를 요구하는지 확인한다.
- Stage 1 보고서에 core compatibility 결과, resolved commit, studio sync 후보 경로, Stage 2-3 실행 판단을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m016_167_stage1.md`

### 검증

```bash
git status --short --branch
gh release view -R edwardkim/rhwp v0.7.10 --json tagName,publishedAt,url
git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.10
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.10
sed -n '1,260p' scripts/update-rhwp-core.sh
sed -n '1,220p' scripts/sync-rhwp-studio.sh
sed -n '1,220p' Sources/HostApp/Resources/rhwp-studio/manifest.json
git diff --check
```

### 완료 기준

- `v0.7.10` stable compatibility check 결과가 기록된다.
- resolved commit 확인 방법과 결과가 보고서에 남는다.
- `rhwp-studio` asset을 같은 기준으로 맞추기 위한 실행 경로가 확인된다.
- Stage 2 core bump 진행 여부가 명확하다.

### 커밋 메시지

```text
Task #167 Stage 1: v0.7.10 compatibility 조사
```

## Stage 2. core dependency와 Rust bridge artifact 갱신

### 목표

- RustBridge dependency, Cargo lock, app-level lock을 `v0.7.10` 기준으로 갱신한다.
- Rust bridge generated artifact hash/size와 FFI symbol snapshot 정합성을 확인한다.

### 작업

- Stage 1 compatibility 통과 결과를 기준으로 `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.10`을 실행한다.
- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock` 변경을 검토한다.
- `./scripts/build-rust-macos.sh --update-lock`을 실행해 universal staticlib/header를 재생성하고 hash/size를 lock에 반영한다.
- `./scripts/build-rust-macos.sh --verify-lock`을 실행한다.
- `rhwp-ffi-symbols.txt` diff 여부를 확인한다.
- FFI symbol 변화가 있으면 Stage 보고서에 ABI 영향과 Swift bridge 확인 범위를 적고, 필요한 경우 snapshot을 갱신한다.
- Stage 2 보고서에 변경 파일, resolved commit, artifact hash/size, FFI 변화 여부를 기록한다.

### 예상 변경 파일

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt` (필요 시)
- `mydocs/working/task_m016_167_stage2.md`

### 검증

```bash
git status --short --branch
./scripts/update-rhwp-core.sh --channel stable --tag v0.7.10
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
git diff -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock rhwp-ffi-symbols.txt
rg -n "v0\\.7\\.9|v0\\.7\\.10|rhwp_release_tag|rhwp_commit|source =" RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git diff --check
```

### 완료 기준

- `rhwp-core.lock`이 `v0.7.10` release tag와 resolved commit을 기록한다.
- `RustBridge/Cargo.lock`의 `rhwp` source commit과 `rhwp-core.lock` commit이 일치한다.
- Rust bridge artifact hash/size가 lock과 일치한다.
- FFI symbol 변화 여부가 명확히 기록된다.

### 커밋 메시지

```text
Task #167 Stage 2: rhwp v0.7.10 core lock 갱신
```

## Stage 3. bundled rhwp-studio asset/manifest 기준 정합화

### 목표

- HostApp WKWebView viewer의 bundled `rhwp-studio` asset과 manifest가 `v0.7.10` release artifact 기준과 충돌하지 않도록 정합화한다.

### 작업

- Stage 1에서 확인한 sync 경로에 따라 `rhwp-studio` asset 갱신을 수행한다.
- 갱신 경로가 `scripts/sync-rhwp-studio.sh`라면 script 입력과 output을 보고서에 기록한다.
- Docker/Node/upstream build가 필요하고 로컬에서 막히면 실패 지점을 분리해 작업지시자에게 판단을 요청한다.
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 `source_release_tag`, `source_resolved_commit`, copied count/bytes, entrypoint hash를 확인한다.
- `scripts/verify-rhwp-studio-assets.sh`를 실행한다.
- bundled font/license 문서와 충돌이 있는지 핵심 키워드를 검색한다.
- Stage 3 보고서에 asset 추가/삭제/변경 요약과 manifest 정합성을 기록한다.

### 예상 변경 파일

- `Sources/HostApp/Resources/rhwp-studio/**`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` (필요 시)
- `THIRD_PARTY_LICENSES.md` (필요 시)
- `mydocs/working/task_m016_167_stage3.md`

### 검증

```bash
git status --short --branch
scripts/verify-rhwp-studio-assets.sh
sed -n '1,220p' Sources/HostApp/Resources/rhwp-studio/manifest.json
find Sources/HostApp/Resources/rhwp-studio -maxdepth 3 -type f | sort | wc -l
find Sources/HostApp/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | sort | wc -l
rg -n "v0\\.7\\.9|v0\\.7\\.10|source_release_tag|source_resolved_commit|THIRD_PARTY_LICENSES|FONTS.md|WOFF2" \
  Sources/HostApp/Resources/rhwp-studio THIRD_PARTY_LICENSES.md
git diff --check
```

### 완료 기준

- bundled `rhwp-studio` manifest가 `v0.7.10` 기준이거나, 예외 판단이 명확히 보고된다.
- asset 구조 검증이 통과한다.
- #145 release artifact provenance가 core/studio 기준 불일치 없이 이어질 수 있다.

### 커밋 메시지

```text
Task #167 Stage 3: rhwp-studio v0.7.10 asset 정합화
```

## Stage 4. build/render 검증과 release 기준 문서 연결

### 목표

- core/studio 기준 갱신 이후 앱 build, render smoke, release provenance 문서 연결이 통과하는지 확인한다.

### 작업

- `./scripts/check-no-appkit.sh`를 실행한다.
- `xcodegen generate`를 실행한다.
- Debug HostApp build를 실행한다.
- Release build 또는 `./scripts/package-release.sh 0.1.0` 중 승인된 검증을 실행한다.
- `./scripts/validate-stage3-render.sh`를 실행한다.
- `README.md`, `THIRD_PARTY_LICENSES.md`, `mydocs/manual/release_distribution_guide.md`, #145 관련 문서에서 `v0.7.9` stale reference가 release 기준과 충돌하는지 검색한다.
- 필요한 문서에는 `v0.7.10` 기준 또는 #167 handoff 문구를 반영한다.
- Stage 4 보고서에 검증 명령과 결과, 남은 public release 전 조건을 기록한다.

### 예상 변경 파일

- `mydocs/manual/release_distribution_guide.md` (필요 시)
- `THIRD_PARTY_LICENSES.md` (필요 시)
- `README.md` (필요 시. 단, 원 worktree 사용자 변경과 충돌하지 않게 주의)
- `mydocs/working/task_m016_167_stage4.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
scripts/verify-rhwp-studio-assets.sh
rg -n "v0\\.7\\.9|v0\\.7\\.10|0fb3e6758b8ad11d2f3c3849c83b914684e83863|rhwp-core.lock|rhwp-studio|manifest.json" \
  README.md THIRD_PARTY_LICENSES.md rhwp-core.lock RustBridge/Cargo.toml RustBridge/Cargo.lock \
  Sources/HostApp/Resources/rhwp-studio/manifest.json mydocs scripts .github
git diff --check
```

선택 release/package 검증:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/package-release.sh 0.1.0
```

### 완료 기준

- shared code boundary, Debug build, render smoke, asset verification이 통과한다.
- release 기준 문서에 `v0.7.9` stale reference가 무비판적으로 남지 않는다.
- #145/#151/#146/#166으로 넘길 기준이 명확하다.

### 커밋 메시지

```text
Task #167 Stage 4: v0.7.10 build와 release 기준 검증
```

## Stage 5. 최종 보고와 handoff

### 목표

- #167 결과를 최종 보고서로 정리하고 #145/#151/#146/#166이 이어받을 기준을 명시한다.

### 작업

- 최종 결과보고서에 core tag/commit, `rhwp-core.lock` artifact hash/size, FFI symbol 변화 여부, `rhwp-studio` manifest, 검증 결과를 정리한다.
- `mydocs/orders/20260506.md`의 #167 상태를 완료로 갱신한다.
- #145 재개 시 Stage 3 이후 반영해야 할 문구와 검증 기준을 handoff로 남긴다.
- #166은 #167 결과 확인만 하면 된다는 점을 다시 기록한다.
- PR 게시 전 working tree 상태를 확인한다.

### 예상 변경 파일

- `mydocs/working/task_m016_167_stage5.md`
- `mydocs/report/task_m016_167_report.md`
- `mydocs/orders/20260506.md`

### 검증

```bash
git status --short --branch
rg -n "v0\\.7\\.10|rhwp-core.lock|rhwp-studio|manifest.json|FFI|#145|#151|#146|#166" \
  mydocs/working/task_m016_167_stage5.md mydocs/report/task_m016_167_report.md mydocs/orders/20260506.md
git diff --check
```

### 완료 기준

- #167 최종 보고서에 core/studio provenance와 검증 결과가 정리된다.
- 오늘할일이 완료 상태로 갱신된다.
- #145와 #166이 반복 없이 이어받을 handoff가 명확하다.
- PR 게시 전 working tree가 clean 상태다.

### 커밋 메시지

```text
Task #167 Stage 5 + 최종 보고서: rhwp v0.7.10 release 기준 정합화 완료
```
