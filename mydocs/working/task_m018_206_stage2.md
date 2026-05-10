# Task M018 #206 Stage 2 완료 보고서

## 단계 목적

`Release Publish DMG` workflow에서 사용할 Pages artifact assembly를 독립 helper로 분리하고, PR CI의 release helper checks에서 helper interface와 dry-run을 검증하도록 연결했다.

## 산출물

| 파일 | 라인 수 | 요약 |
|------|---------|------|
| `.github/workflows/pr-ci.yml` | 230 | release helper checks에 `prepare-pages-artifact.sh --help`와 Pages artifact dry-run 검증을 추가 |
| `scripts/ci/prepare-pages-artifact.sh` | 134 | `docs/` 정적 파일과 generated `appcast.xml`을 `build.noindex` 아래 Pages artifact directory로 조립 |

`prepare-pages-artifact.sh` 동작:

- `--docs-dir`, `--appcast`, `--output-dir` 입력을 받는다.
- `docs/index.html`과 `docs/updates/index.html` 존재를 확인한다.
- Pages artifact에 부적합한 symlink가 `docs/`에 있으면 실패한다.
- output은 `build.noindex` 아래만 허용한다.
- 기존 output directory는 새 artifact로 교체한다.
- ignored macOS metadata인 `.DS_Store`는 artifact에서 제거한다.
- generated appcast를 artifact root의 `appcast.xml`로 덮어쓴다.

## 본문 변경 정도 / 본문 무손실 여부

사용자-facing Pages HTML 본문은 수정하지 않았다. `docs/` 원본 파일도 수정하지 않았으며, generated Pages artifact는 `build.noindex/` 아래 검증 산출물이다.

## 검증 결과

```bash
git status --short --branch
```

결과 요약: `local/task206` 브랜치에서 `.github/workflows/pr-ci.yml`, `scripts/ci/prepare-pages-artifact.sh` 변경을 확인했다.

```bash
bash -n scripts/ci/prepare-pages-artifact.sh
```

결과: 출력 없음, exit code 0.

```bash
scripts/ci/prepare-pages-artifact.sh --help
```

결과 요약: `--docs-dir`, `--appcast`, `--output-dir` 사용법 출력.

```bash
scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.1 \
  --build 2 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.1/alhangeul-macos-0.1.1.dmg \
  --length 1 \
  --ed-signature dummy-ed-signature \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html \
  --pub-date "Fri, 08 May 2026 09:00:00 +0000" \
  --minimum-system-version 12.0 \
  --output build.noindex/release/appcast.xml
```

결과: 출력 없음, exit code 0.

```bash
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/appcast.xml \
  --output-dir build.noindex/release/pages-artifact
```

결과:

```text
Prepared Pages artifact at /Users/melee/Documents/projects/rhwp-mac/build.noindex/release/pages-artifact
```

```bash
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
test -f build.noindex/release/pages-artifact/index.html
test -f build.noindex/release/pages-artifact/updates/index.html
test -f build.noindex/release/pages-artifact/updates/v0.1.1.html
find build.noindex/release/pages-artifact -name '.DS_Store' -print
find build.noindex/release/pages-artifact -maxdepth 2 -type f | wc -l
```

결과 요약:

- XML 검증 통과
- `index.html`, `updates/index.html`, `updates/v0.1.1.html` 존재
- `.DS_Store` 출력 없음
- maxdepth 2 기준 파일 55개

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
```

결과: YAML parse 통과. 로컬 Ruby 환경에서 `ffi-1.13.1` extension 관련 warning이 출력됐지만 parse exit code는 0이었다.

```bash
bash -n scripts/ci/*.sh
```

결과: 출력 없음, exit code 0.

```bash
scripts/ci/classify-pr-changes.sh devel-webview 289838016b49b933f4d15977a2cdb8dbe6c5691a
```

`HEAD`는 아직 Stage 2 커밋 전이라 미커밋 파일을 보지 못한다. 따라서 staged 변경을 포함한 임시 commit object `289838016b49b933f4d15977a2cdb8dbe6c5691a`를 만들어 PR 변경 분류를 검증했다.

결과 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `true` |

`run_release_checks=true` 이유:

- `.github/workflows/pr-ci.yml` affects release scripts, workflows, or Cask automation
- `scripts/ci/prepare-pages-artifact.sh` affects release scripts, workflows, or Cask automation

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

## 잔여 위험

- Stage 2는 helper와 PR CI dry-run 연결까지만 다뤘다. 실제 `Release Publish DMG` workflow의 Pages artifact upload와 `deploy-pages` job 연결은 Stage 3 범위다.
- helper는 output을 `build.noindex` 아래로 제한한다. release workflow도 `ALHANGEUL_BUILD_ROOT`를 `build.noindex`로 사용하므로 의도와 맞지만, 다른 경로로 재사용하려면 별도 변경이 필요하다.
- 실제 Pages upload artifact validation은 `actions/upload-pages-artifact@v5` 실행 시점에 최종 확인된다.

## 다음 단계 영향

Stage 3에서는 이 helper를 `release-publish.yml` stable path에 연결하고, generated appcast를 포함한 Pages artifact를 `actions/upload-pages-artifact@v5`로 업로드한 뒤 별도 `deploy-pages@v5` job으로 배포하도록 전환한다.

## 승인 요청

Stage 2 산출물 승인을 요청한다.

승인 후 Stage 3 `Release Publish DMG workflow를 deploy-pages 경로로 전환`으로 진행한다.
