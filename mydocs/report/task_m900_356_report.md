# Task M900 #356 최종 보고서

## 작업 요약

릴리즈 노트를 코드 전체 diff가 아니라 직전 공개 릴리즈 이후 merge된 PR, linked Issue, 최종 보고서 기반으로 작성하도록 매뉴얼, 자동화, workflow를 보강했다.

핵심 변경은 다음과 같다.

- `mydocs/release/v<version>.md`에 `포함 PR 분석` 표를 남기는 표준 구조 추가.
- `previous_release_ref..candidate_ref` 범위의 merge PR 분석 helper 추가.
- 각 PR을 사용자-facing, 개발자-facing, 운영/배포, 문서-only, upstream sync로 분류하는 기준 문서화.
- GitHub Release body에 `직접 반영된 PR과 Issue` section을 생성/검증하도록 generator/checker 보강.
- Release Rehearsal/Publish workflow와 PR CI에 PR 분석 helper dry-run과 artifact 생성을 연결.
- `v0.1.5` release record와 Pages source를 PR 분석 기준으로 보정.

## 단계별 결과

| 단계 | 결과 | 커밋 |
|------|------|------|
| Task start | 수행계획서와 오늘할일 생성 | `a220482` |
| 구현계획서 | 5단계 구현계획서 작성 | `7a60dc0` |
| Stage 1 | 현행 release note 경로와 `v0.1.5` 사례 분석 | `6333892` |
| Stage 2 | release record와 매뉴얼 표준 구조 보강 | `029d49d` |
| Stage 3 | `write-release-pr-analysis.sh` helper 추가 | `76c1e64` |
| Stage 3 보강 | GitHub API 분석 경로 검증과 Issue 중복 제거 | `f3aff53` |
| Stage 4 | generator/checker/workflow 연결 | `6ffebe2` |
| Stage 5 | end-to-end 검증, public surface 정정 후보, 최종 보고 | 최종 커밋 예정 |

## 변경 파일 요약

| 영역 | 주요 파일 |
|------|-----------|
| 매뉴얼 | `mydocs/manual/release_github_pages_sparkle_guide.md`, `mydocs/manual/public_release_runbook.md`, `mydocs/manual/release_distribution_guide.md`, `mydocs/manual/ci_workflow_guide.md`, `mydocs/manual/document_structure_guide.md` |
| 자동화 | `scripts/ci/write-release-pr-analysis.sh`, `scripts/ci/write-release-notes.sh`, `scripts/ci/check-release-notes-template.sh`, `scripts/ci/write-release-delta-checklist.sh` |
| workflow | `.github/workflows/pr-ci.yml`, `.github/workflows/release-rehearsal.yml`, `.github/workflows/release-publish.yml` |
| release record | `mydocs/release/v0.1.5.md` |
| Pages source | `docs/updates/v0.1.5.html` |
| 작업 기록 | `mydocs/plans/task_m900_356.md`, `mydocs/plans/task_m900_356_impl.md`, `mydocs/working/task_m900_356_stage*.md`, `mydocs/report/task_m900_356_report.md`, `mydocs/orders/20260607.md` |

## 확정한 release note 규칙

| 항목 | 기준 |
|------|------|
| 1차 입력 | `previous_release_ref..candidate_ref` 범위의 merge PR title/body, linked Issue, 최종 보고서 |
| 보조 입력 | path 기반 delta checklist. 누락 확인과 smoke 영역 점검용 |
| release record | `포함 PR 분석` 표 필수 |
| 공개 요약 | `포함 PR 분석` 표에서 사용자-facing으로 확정된 항목만 기준 |
| 해결된 Issue | PR body closing keyword 또는 release record 완료 확정 항목 |
| 관련 Issue | `Refs`, `Related`, 대상 타스크, 선행/연관, 단순 참고 Issue |
| GitHub Release body | `직접 반영된 PR`, `해결된 Issue`, `관련 Issue` 구분 section 필수 |

## 자동화 결과

`scripts/ci/write-release-pr-analysis.sh`는 다음 형식으로 사용한다.

```bash
scripts/ci/write-release-pr-analysis.sh <previous-release-ref> <candidate-ref> <output-file>
```

helper는 merge PR 목록, first-parent release transport 후보, PR title/body/files, closing keyword, 관련 Issue 후보, 보고서 후보, path/title 기반 분류 hint를 Markdown으로 모은다. `gh pr view`가 가능하면 PR body 경로를 우선 사용하고, 실패하면 git metadata fallback으로 내려간다.

`scripts/ci/write-release-notes.sh`는 이제 release detail doc의 `## 포함 PR 분석`과 다음 GitHub Release 후보 section을 요구한다.

- `### 변경 요약`
- `### 포함된 rhwp 변화`
- `### 알한글 앱 변화`
- `### 직접 반영된 PR`
- `### 해결된 Issue`
- `### 관련 Issue`

`scripts/ci/check-release-notes-template.sh`는 generated body에서 `## 직접 반영된 PR과 Issue` section, 확정된 `#N` 또는 `없음` 항목, `확인 필요` 금지, release detail doc의 `## 포함 PR 분석` 존재를 검증한다.

## v0.1.5 보정 결과

`mydocs/release/v0.1.5.md`에 `v0.1.4..v0.1.5` 포함 PR 분석 표를 추가했다.

public body 후보 기준 직접 반영 PR:

- `#324`
- `#326`
- `#329`
- `#334`
- `#349`

해결된 Issue:

- `#110`

관련 Issue:

- `#106`
- `#116`
- `#121`
- `#122`
- `#280`
- `#282`
- `#323`
- `#348`
- `#351`

Pages source `docs/updates/v0.1.5.html`은 `앱 자체 신규 기능은 크지 않습니다` 문구를 제거하고, Quick Look/썸네일/PDF/공유 출력 표시 보강과 앱 실행 후 업데이트 확인 보강을 사용자-facing 변화로 반영했다.

GitHub Release body 정정 후보는 다음 파일에 생성했다.

```bash
build.noindex/release/github-release-v0.1.5-corrected.md
```

이 파일은 `scripts/ci/check-release-notes-template.sh`와 `scripts/validate-github-body.sh`를 통과했다. 실제 public GitHub Release 반영은 별도 승인 후 수행한다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| shell syntax checks | 통과 |
| workflow YAML parse | 통과 |
| `write-release-pr-analysis.sh v0.1.4 v0.1.5` | 통과 |
| GitHub API PR metadata path | 통과 |
| fallback PR analysis path | 통과 |
| `write-release-notes.sh 0.1.5 ...` | 통과 |
| `check-release-notes-template.sh` | 통과 |
| `write-release-delta-checklist.sh v0.1.4 HEAD` | 통과 |
| `update-release-version-notices.sh --check` | 통과 |
| `scripts/validate-github-body.sh` | 통과 |
| Pages HTML parse | 통과 |
| `git diff --check` | 통과 |

## 미실행 항목

다음 public action은 실행하지 않았다.

- `gh release edit v0.1.5 --notes-file build.noindex/release/github-release-v0.1.5-corrected.md`
- public Pages 배포
- workflow artifact upload의 실제 GitHub Actions 실행

위 항목은 public 표면 수정 또는 GitHub Actions 실행이므로 작업지시자 별도 승인 후 진행한다.

## 남은 위험

- release owner가 `포함 PR 분석` 표의 사용자-facing 판단을 잘못 확정하면 generator는 그 판단을 그대로 public body에 반영한다.
- PR body closing keyword가 누락된 실제 완료 Issue는 release record에서 명시적으로 완료 확정해야 해결된 Issue로 들어간다.
- workflow artifact upload는 로컬에서 검증할 수 없어 YAML parse와 helper dry-run으로만 확인했다.
