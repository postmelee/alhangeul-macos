# Task M019 #214 Stage 5 완료 보고서

## 단계 목적

전체 변경의 로컬 통합 검증을 수행하고, 실제 GitHub Pages deployment는 merge 후 확인할 항목으로 분리해 최종 보고한다.

## 산출물

- `mydocs/working/task_m019_214_stage5.md`: Stage 5 통합 검증 보고서
- `mydocs/report/task_m019_214_report.md`: 최종 결과보고서
- `mydocs/orders/20260517.md`: #214 완료 처리

## 통합 검증 결과

실행한 검증:

```bash
git status --short --branch
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
bash -n scripts/ci/*.sh
scripts/ci/prepare-pages-artifact.sh --help
scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.2 \
  --build 8 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.2/alhangeul-macos-0.1.2.dmg \
  --length 1 \
  --ed-signature dummy-ed-signature \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.2.html \
  --pub-date "Fri, 08 May 2026 09:00:00 +0000" \
  --minimum-system-version 12.0 \
  --output build.noindex/release/appcast.xml
xmllint --noout build.noindex/release/appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/appcast.xml \
  --output-dir build.noindex/release/pages-artifact
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
test -f build.noindex/release/pages-artifact/index.html
test -f build.noindex/release/pages-artifact/updates/index.html
scripts/ci/classify-pr-changes.sh devel HEAD
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml \
  -o build.noindex/release/public-appcast.xml
xmllint --noout build.noindex/release/public-appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/public-appcast.xml \
  --output-dir build.noindex/release/docs-only-pages-artifact
xmllint --noout build.noindex/release/docs-only-pages-artifact/appcast.xml
test -f build.noindex/release/docs-only-pages-artifact/index.html
test -f build.noindex/release/docs-only-pages-artifact/updates/index.html
git diff --check
```

결과:

- 전체 workflow YAML parse 통과.
- Ruby 실행 시 기존 로컬 gem 경고(`ffi-1.13.1`)가 출력됐지만 exit code는 0이었다.
- 전체 shell script syntax 검증 통과.
- release-style generated appcast XML 생성과 Pages artifact dry-run 통과.
- docs-only public appcast 보존 경로 dry-run 통과.
- sandbox network 제한으로 최초 `curl`은 DNS 실패했으나, 승인된 escalated 실행에서는 public appcast 다운로드가 성공했다.
- public appcast와 docs-only artifact appcast는 v0.1.2 feed를 유지했다.
- 변경 범위 분류 결과 `run_release_checks=true`, `run_macos_build=false`, `run_rust_verify=false`, `run_render_smoke=false`.
- `git diff --check` 통과.

## 변경 범위 요약

Stage 5 진입 전 `devel..HEAD` 기준:

- 변경 파일: 13개
- 변경량: 1082 insertions, 3 deletions
- 주요 변경:
  - docs-only Pages deploy workflow 추가
  - release/docs-only Pages deployment concurrency 직렬화
  - PR CI workflow YAML parse 검증 추가
  - CI/Release/Pages 운영 매뉴얼 갱신
  - Stage 1~4 보고서와 계획 문서 작성

Stage 5에서는 최종 보고서, Stage 5 보고서, 오늘할일 완료 처리를 추가한다.

## 미실행 항목

다음은 로컬에서 재현하지 않았다.

- `actions/upload-pages-artifact@v5` 실제 artifact upload
- `actions/deploy-pages@v5` 실제 deployment
- GitHub Actions job-level concurrency의 실제 queueing 동작

이 항목들은 PR merge 후 GitHub-hosted runner에서 확인해야 한다.

## 잔여 위험

- public appcast endpoint가 일시적으로 실패하면 docs-only Pages deployment도 실패한다. stale appcast 배포보다 실패를 선택한 의도된 정책이다.
- GitHub Actions expression과 environment policy는 로컬 YAML parse만으로 완전 검증되지 않는다.

## 다음 단계 영향

최종 결과보고서 승인 후 `publish/task214`로 push하고 `devel` 대상 PR을 생성하는 절차로 넘어갈 수 있다.

## 승인 요청

Stage 5 결과와 최종 결과보고서를 승인하면 PR 게시 단계로 진행한다.
