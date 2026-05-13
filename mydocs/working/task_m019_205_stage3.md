# Task M019 #205 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 정리한 release provenance 표기 정책을 GitHub Release note 생성 경로와 release publish workflow에 반영했다.

이번 단계는 스크립트와 workflow 정의만 수정했다. Workflow 실행, signed/notarized DMG 생성, GitHub Release 게시, release asset upload, Sparkle appcast 갱신, Pages deployment는 수행하지 않았다.

## 변경 요약

### Release note generator

`scripts/ci/write-release-notes.sh`의 기존 section을 표준 metadata 구조로 변경했다.

기존 heading:

```md
## 포함된 rhwp core와 viewer asset provenance
```

변경 heading:

```md
## Release metadata
```

생성되는 표준 항목:

| 항목 | 값 |
|------|----|
| App version | `v<app-version>` |
| rhwp core release tag | `rhwp-core.lock`의 `rhwp_release_tag` |
| rhwp core commit | `rhwp-core.lock`의 `rhwp_commit` |
| bundled rhwp-studio release tag | studio manifest의 `source_release_tag` |
| bundled rhwp-studio commit | studio manifest의 `source_resolved_commit` |
| core lock | `rhwp-core.lock` |
| studio manifest | `Sources/HostApp/Resources/rhwp-studio/manifest.json` |

`release detail doc`는 사용자용 summary 문장에 이미 있고, 표준 metadata 표에서는 Stage 2 정책 문서의 필수 항목만 유지했다.

### Release note template checker

`scripts/ci/check-release-notes-template.sh`의 필수 heading을 새 구조에 맞췄다.

- 제거: `## 포함된 rhwp core와 viewer asset provenance`
- 추가: `## Release metadata`

Dry-run release note는 새 heading과 표준 metadata 표를 포함하고 checker를 통과했다.

### Release publish workflow

`.github/workflows/release-publish.yml`에 `include_rhwp_in_title` workflow dispatch input을 추가했다.

기본값:

```yaml
include_rhwp_in_title: false
```

기본 title은 기존과 같은 `Alhangeul v<version>`이다. `include_rhwp_in_title=true`일 때만 `steps.core.outputs.rhwp_tag`를 사용해 다음 형식으로 바꾼다.

```text
Alhangeul v<version> (rhwp v<rhwp-version>)
```

release create와 release edit 모두 같은 `release_title` 변수를 사용하도록 보정했다. Step summary에는 실제 title과 `include_rhwp_in_title` 값을 기록한다.

## 변경 파일

- `scripts/ci/write-release-notes.sh`
- `scripts/ci/check-release-notes-template.sh`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m019_205_stage3.md`

## 변경하지 않은 항목

- `rhwp-core.lock`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- release artifact 생성 경로
- GitHub Release 게시 상태
- Sparkle appcast
- Pages deployment
- Homebrew Cask

## 검증 결과

실행한 명령:

```bash
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release-publish.yml"); puts "workflow yaml ok"'
bash scripts/ci/write-release-notes.sh 0.1.2 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.2.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md
rg -n "Release metadata|App version|rhwp core release tag|rhwp core commit|bundled rhwp-studio release tag|bundled rhwp-studio commit|core lock|studio manifest|include_rhwp_in_title|INCLUDE_RHWP_IN_TITLE|release_title|Alhangeul \\$tag_name|expected_rhwp_tag" \
  build.noindex/release/release-notes-0.1.2.md scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh .github/workflows/release-publish.yml
git diff --check -- scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh .github/workflows/release-publish.yml
```

결과:

- `bash -n scripts/ci/write-release-notes.sh`: 통과.
- `bash -n scripts/ci/check-release-notes-template.sh`: 통과.
- workflow YAML parse: 통과. 로컬 Ruby 환경에서 `ffi-1.13.1` extension 관련 경고가 출력됐지만 YAML parse는 `workflow yaml ok`로 완료됐다.
- release note dry-run: 통과.
- release note template check: 통과.
- generated `build.noindex/release/release-notes-0.1.2.md`에서 `Release metadata` 표와 7개 표준 항목 확인.
- `.github/workflows/release-publish.yml`에서 `include_rhwp_in_title`, `INCLUDE_RHWP_IN_TITLE`, `release_title` 적용 확인.
- `git diff --check`: 통과.

## 생성물

검증용 dry-run output:

- `build.noindex/release/release-notes-0.1.2.md`

이 파일은 `build.noindex/` 아래에 있어 `.gitignore` 대상이며 커밋하지 않는다.

## 다음 단계 제안

Stage 4에서는 Stage 1-3 전체 변경을 통합 검증한다. 특히 README/Pages/release record의 short provenance와 generated GitHub Release body의 `Release metadata` 표가 같은 기준을 쓰는지 대조하고, 오늘할일과 최종 보고서를 정리한다.
