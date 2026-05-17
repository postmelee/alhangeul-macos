# Task M019 #214 Stage 4 완료 보고서

## 단계 목적

release-driven Pages deployment와 docs-only Pages deployment의 역할 차이, appcast 보존 정책, GitHub environment 전제 조건을 장기 운영 매뉴얼에 기록한다.

## 산출물

- `mydocs/manual/ci_workflow_guide.md`: `Docs-only Pages Deploy` workflow 역할, 권한, 재현 명령, 실패 해석 기준 추가
- `mydocs/manual/release_github_pages_sparkle_guide.md`: release/docs-only Pages 배포 역할 분리와 appcast 보존 기준 추가
- `mydocs/manual/release_distribution_guide.md`: 현재 release 자산과 체크리스트에 docs-only workflow와 Pages concurrency 기준 추가
- `mydocs/working/task_m019_214_stage4.md`: Stage 4 완료 보고서

## 변경 내용

### CI workflow 가이드

- Workflow map에 `Docs-only Pages Deploy`를 추가했다.
- PR CI 로컬 재현 명령에 `.github/workflows/*.yml` YAML parse 검증을 추가했다.
- `Release Publish DMG` 보호 조건에 `deploy-pages` job의 `pages-deploy` concurrency를 기록했다.
- `Docs-only Pages Deploy` 섹션을 추가했다.
  - trigger: `push` to `main` with `docs/**`, `workflow_dispatch`
  - 권한: `contents: read`, Pages job의 `pages: write`, `id-token: write`
  - environment: `github-pages`
  - appcast source: public `https://postmelee.github.io/alhangeul-macos/appcast.xml`
  - stale `docs/appcast.xml` fallback 금지
  - local dry-run 명령
- 실패 해석 기준에 docs-only workflow 실패 해석을 추가했다.

### GitHub Release, Pages, Sparkle 가이드

- 권한 원칙에 `main`에 merge된 `docs/**` 변경의 docs-only 자동 배포는 승인된 merge 결과를 반영하는 운영 경로라고 명시했다.
- Pages repository 설정에 `main` branch와 release tag `v*` deployment 허용 조건을 기록했다.
- release workflow와 docs-only workflow가 `pages-deploy` concurrency group을 공유한다는 기준을 기록했다.
- `Docs-only Pages 배포` 섹션을 추가했다.
  - release workflow는 generated stable appcast를 배포한다.
  - docs-only workflow는 public latest appcast를 보존한다.
  - repository `docs/appcast.xml`은 docs-only 배포 source로 사용하지 않는다.
  - public appcast 다운로드/XML 검증 실패 시 배포를 중단한다.

### 릴리스/배포 가이드

- 현재 release 자산에 `.github/workflows/pages-docs-deploy.yml`을 추가했다.
- public appcast 설명에 release workflow와 docs-only workflow의 역할 차이를 반영했다.
- 최종 체크리스트에 다음 항목을 추가 또는 보정했다.
  - `github-pages` environment가 `main` branch와 release tag `v*`를 허용하는지 확인
  - release/docs-only workflow가 `pages-deploy` concurrency group으로 Pages deployment를 취소 없이 직렬화하는지 확인
  - docs-only Pages workflow가 public appcast를 보존하고 stale fallback을 사용하지 않는지 확인

## 본문 변경 정도 / 본문 무손실 여부

기존 문서의 release-driven Pages deployment 기준은 유지했다. 이번 단계에서는 docs-only workflow 운영 기준과 release workflow와의 관계를 추가하고, 모호해질 수 있는 권한/자동 배포 관계를 보강했다.

## 검증 결과

실행한 검증:

```bash
git status --short --branch
rg -n "Docs-only|docs-only|pages-docs-deploy|public appcast|stale|fallback|github-pages|main|v\\*|Pages deployment|pages-deploy|workflow YAML|승인된 merge" mydocs/manual
git diff --check
wc -l mydocs/manual/ci_workflow_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/release_distribution_guide.md
```

결과:

- `rg` 검색으로 세 매뉴얼에 docs-only workflow, public appcast 보존, stale fallback 금지, `github-pages` environment, `main`/`v*`, `pages-deploy` concurrency 기준이 연결되어 있음을 확인했다.
- `git diff --check` 통과.
- 문서 라인 수:
  - `ci_workflow_guide.md`: 276 lines
  - `release_github_pages_sparkle_guide.md`: 215 lines
  - `release_distribution_guide.md`: 147 lines

## 잔여 위험

- 문서 반영은 완료됐지만 실제 docs-only workflow와 release workflow의 `pages-deploy` concurrency 동작은 GitHub Actions 실행에서 확인해야 한다.
- `github-pages` environment에 남아 있는 legacy branch policy 정리는 이번 범위가 아니다.

## 다음 단계 영향

Stage 5에서는 전체 workflow parse, shell syntax, Pages artifact dry-run, public appcast 보존 dry-run, 변경 범위 분류를 다시 수행하고 최종 보고서에 merge 후 확인 항목을 정리한다.

## 승인 요청

Stage 4 결과를 승인하면 Stage 5로 진행해 통합 검증과 최종 보고서를 작성한다.
