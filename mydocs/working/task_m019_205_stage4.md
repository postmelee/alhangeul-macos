# Task M019 #205 Stage 4 완료 보고서

## 단계 목적

Stage 1-3에서 정리한 release provenance 정책, Pages/README/release record, release note generator, release publish workflow를 통합 검증하고 최종 보고서와 오늘할일을 정리했다.

## 변경 파일

- `mydocs/orders/20260511.md`
- `mydocs/working/task_m019_205_stage4.md`
- `mydocs/report/task_m019_205_report.md`

## 통합 검증 결과

### Static checks

다음 정적 검증을 완료했다.

```bash
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
jq empty Sources/HostApp/Resources/rhwp-studio/manifest.json
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release-publish.yml"); puts "workflow yaml ok"'
git diff --check
```

결과:

- `write-release-notes.sh` syntax: 통과.
- `check-release-notes-template.sh` syntax: 통과.
- studio manifest JSON validation: 통과.
- workflow YAML parse: 통과. 로컬 Ruby 환경에서 `ffi-1.13.1` extension 관련 경고가 출력됐지만 YAML parse는 `workflow yaml ok`로 완료됐다.
- `git diff --check`: 통과.

### Release note dry-run

다음 명령으로 v0.1.2 release note 후보를 생성했다.

```bash
bash scripts/ci/write-release-notes.sh 0.1.2 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.2.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md
```

결과:

- release note dry-run: 통과.
- template check: 통과.
- generated release note에 `Release metadata` 표와 7개 표준 항목이 포함됨을 확인했다.

확인한 generated metadata:

| 항목 | 값 |
|------|----|
| App version | `v0.1.2` |
| rhwp core release tag | `v0.7.10` |
| rhwp core commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| bundled rhwp-studio release tag | `v0.7.10` |
| bundled rhwp-studio commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| core lock | `rhwp-core.lock` |
| studio manifest | `Sources/HostApp/Resources/rhwp-studio/manifest.json` |

Dry-run output은 `build.noindex/release/release-notes-0.1.2.md`이며 `.gitignore` 대상이므로 커밋하지 않는다.

### Cross-surface keyword scan

다음 표면에서 같은 기준이 반영됐는지 확인했다.

- `README.md`
- `docs/updates/v0.1.0.html`
- `docs/updates/v0.1.1.html`
- `mydocs/release/v0.1.0.md`
- `mydocs/release/v0.1.1.md`
- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `scripts/ci/write-release-notes.sh`
- `scripts/ci/check-release-notes-template.sh`
- `.github/workflows/release-publish.yml`

확인한 기준:

- README 최신 공개 릴리즈는 bundled `rhwp v0.7.10`을 한 줄로 안내한다.
- Pages `v0.1.0`과 `v0.1.1`은 모두 `포함된 rhwp` section과 upstream `rhwp v0.7.10` release 링크를 가진다.
- `mydocs/release/v0.1.0.md`와 `mydocs/release/v0.1.1.md`는 `Release metadata` 표를 사용한다.
- release policy는 앱 version 단독 identity와 `rhwp` provenance 분리 기준을 가진다.
- Pages/Sparkle guide는 Pages short provenance와 Sparkle appcast 앱 버전 경계를 가진다.
- release note generator와 checker는 `Release metadata` heading을 기준으로 동작한다.
- release publish workflow는 기본 title을 유지하고, `include_rhwp_in_title=true`일 때만 `(rhwp vX.Y.Z)` 병기를 적용한다.

## 원격 기준 상태

현재 브랜치는 `origin/devel-webview` 대비 `ahead 6, behind 11` 상태다. 원격의 ahead commit은 #221 merge와 관련된 변경이며, 변경 파일 겹침은 `mydocs/orders/20260511.md`에서 확인됐다.

Stage 4에서 `origin/devel-webview:mydocs/orders/20260511.md`의 #221 완료 행을 보존하고 #205 완료 행을 함께 반영했다. PR 전에는 최신 `devel-webview` 기준으로 rebase 또는 merge 충돌 여부를 다시 확인해야 한다.

## 오늘할일 갱신

`mydocs/orders/20260511.md`에서 #205 상태를 `완료`로 갱신했다. 같은 파일의 원격 #221 완료 항목도 보존했다.

## 미수행 범위

- public release 실행
- GitHub Release 게시
- release asset upload
- signed/notarized DMG 생성
- Sparkle appcast 갱신
- Pages deployment
- Homebrew Cask 반영
- 원격 push/PR 생성

위 항목은 별도 승인 범위에서 진행한다.

## 다음 단계

최종 보고서와 Stage 4 변경을 커밋한 뒤, 작업지시자 승인에 따라 PR 게시 절차로 넘어간다.
