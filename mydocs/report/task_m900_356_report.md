# Task M900 #356 최종 보고서

## 작업 요약

릴리즈 노트를 코드 전체 diff가 아니라 직전 공개 릴리즈 이후 merge된 PR, linked Issue, 최종 보고서 기반으로 작성하도록 매뉴얼, 자동화, workflow를 보강했다.

핵심 변경은 다음과 같다.

- `mydocs/release/v<version>.md`에 `포함 PR 분석` 표를 남기는 표준 구조 추가.
- `previous_release_ref..candidate_ref` 범위의 merge PR 분석 helper 추가.
- 각 PR을 사용자-facing, 개발자-facing, 운영/배포, 문서-only, upstream sync로 분류하는 기준 문서화.
- GitHub Release body에 `이번 릴리즈 관련 PR과 Issue` section을 생성/검증하도록 generator/checker 보강.
- GitHub Release body의 PR/Issue 목록이 GitHub 자동 제목 치환에 의존하지 않고 제목/설명 포함 링크로 남도록 helper/checker/규칙 보강.
- GitHub Release body의 첫 top-level section을 `이번 버전의 주요 변경 사항`으로 고정하고, 설치/지원/업데이트는 `다운로드 및 설치`로 통합.
- public body에서 실제 결과가 아닌 `검증 결과` 가이드라인과 `릴리즈 delta 기반 추가 확인 항목` 절차 문구 제거.
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
| Stage 5 | end-to-end 검증, public surface 정정, 최종 보고 | `68ff599`, `aecb260`, `2fc9976`, `dd1934c`, `0c34ae3`, `75a3ea7` |
| PR 준비 | 최종 보고서 최신화와 PR body 검증 | PR 직전 커밋 |
| CI follow-up | macOS release helper job의 `rg` 의존성 설치 보강 | PR CI 실패 분석 후 추가 커밋 |

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
| 해결된 Issue | 대상 타스크 Issue, PR body closing keyword, release record 완료 확정 항목 |
| 참고/연관 Issue | `Refs`, `Related`, 선행/연관, 단순 참고 Issue. 이전 public release에서 이미 해결된 Issue는 public body가 아니라 `포함 PR 분석` 표에만 기록 |
| GitHub Release body | `릴리즈 요약에 반영된 PR`, `해결된 Issue`, `참고/연관 Issue` 구분 section 필수 |
| PR/Issue section 표기 | `#<number>` 단독 또는 inline code가 아니라 `[#<number>: 제목](URL) - 한 줄 설명` 형식 |
| GitHub Release body 순서 | 첫 top-level section은 `이번 버전의 주요 변경 사항` |
| public body 제외 항목 | `릴리즈 delta 기반 추가 확인 항목`, 실제 결과가 아닌 검증 가이드라인 문구 |

## 자동화 결과

`scripts/ci/write-release-pr-analysis.sh`는 다음 형식으로 사용한다.

```bash
scripts/ci/write-release-pr-analysis.sh <previous-release-ref> <candidate-ref> <output-file>
```

helper는 merge PR 목록, first-parent release transport 후보, PR title/body/files, closing keyword, 참고/연관 Issue 후보, 보고서 후보, path/title 기반 분류 hint를 Markdown으로 모은다. `gh pr view`가 가능하면 PR body 경로를 우선 사용하고, 실패하면 git metadata fallback으로 내려간다. GitHub API 사용 가능 시 REST issue endpoint의 `pull_request` field로 PR 참조를 구분해 해결/참고 Issue 후보에서 제외한다. 참고/연관 Issue 후보는 누락 방지용이므로, 이전 public release에서 이미 해결된 Issue는 public body가 아니라 `포함 PR 분석` 표에만 남긴다.

`scripts/ci/write-release-notes.sh`는 이제 release detail doc의 `## 포함 PR 분석`과 다음 GitHub Release 후보 section을 요구한다.

- `### 변경 요약`
- `### 포함된 rhwp 변화`
- `### 알한글 앱 변화`
- `### 릴리즈 요약에 반영된 PR`
- `### 해결된 Issue`
- `### 참고/연관 Issue`

`scripts/ci/check-release-notes-template.sh`는 generated body에서 첫 top-level section이 `## 이번 버전의 주요 변경 사항`인지, `## 이번 릴리즈 관련 PR과 Issue` section이 제목 포함 PR/Issue 링크 또는 `없음` 항목을 쓰는지, `확인 필요`와 옛 구조 heading이 남지 않았는지, release detail doc에 `## 포함 PR 분석`이 있는지 검증한다.

## v0.1.5 보정 결과

`mydocs/release/v0.1.5.md`에 `v0.1.4..v0.1.5` 포함 PR 분석 표를 추가했다.

public body 후보 기준 릴리즈 요약에 반영된 PR:

- `#324`: 앱 실행 시 Sparkle 백그라운드 업데이트 확인 실행
- `#326`: Swift native renderer 이미지 fill mode parity 보강
- `#329`: RawSvg/OLE·차트 리소스 렌더링 보강
- `#334`: FormObject 정적 프리뷰 보강
- `#349`: `rhwp v0.7.15` upstream sync

해결된 Issue:

- `#110`: Swift native renderer Placeholder/FormObject 정적 프리뷰 보강
- `#121`: Swift native renderer RawSvg/OLE·차트 리소스 렌더링 보강
- `#122`: Swift native renderer 이미지 fill mode·타일·배치 렌더링 parity 보강
- `#323`: 앱 실행 시 Sparkle 백그라운드 업데이트 확인 실행

참고/연관 Issue:

- 없음. `#116`처럼 이전 public release에서 이미 해결된 Issue와 `#348`, `#351` 같은 운영 맥락은 public body가 아니라 `포함 PR 분석` 표에만 남겼다.

Pages source `docs/updates/v0.1.5.html`은 `앱 자체 신규 기능은 크지 않습니다` 문구를 제거하고, Quick Look/썸네일/PDF/공유 출력 표시 보강과 앱 실행 후 업데이트 확인 보강을 사용자-facing 변화로 반영했다.

GitHub Release body 정정 후보는 다음 파일에 생성했다.

```bash
build.noindex/release/github-release-v0.1.5-corrected.md
```

이 파일은 `scripts/ci/check-release-notes-template.sh`와 `scripts/validate-github-body.sh`를 통과했다. 공개 반영 승인 후 `gh release edit v0.1.5 --notes-file build.noindex/release/github-release-v0.1.5-corrected.md`로 GitHub Release body를 정정했다. 이후 PR/Issue 항목이 inline code 번호-only로 보이는 문제를 확인하고, 같은 body file을 제목/설명 포함 링크 형식으로 재생성해 같은 명령으로 다시 반영했다. 추가로 주요 변경 사항보다 설치/지원/업데이트 section이 앞서는 구조와 `검증 결과`, `릴리즈 delta 기반 추가 확인 항목`의 가이드라인 문구 노출 문제를 확인해 body를 주요 변경 우선 구조로 재생성했다. 마지막으로 `다운로드 및 설치`를 하위 section으로 나누고, 대상 타스크 Issue를 해결된 Issue로 재분류했으며, 이전 해결 Issue를 public 참고 목록에서 제거한 body를 다시 반영했다.

Pages public 반영은 main 대상 docs-only PR `#357`로 진행했다.

| 항목 | 값 |
|------|----|
| PR | `#357` |
| PR URL | https://github.com/postmelee/alhangeul-macos/pull/357 |
| merge commit | `bd075695dc77259d6b0624781a1c53ba0bd084cb` |
| Pages deploy run | `27097945876` |
| 결과 | success |

## 검증 결과

| 검증 | 결과 |
|------|------|
| shell syntax checks | 통과 |
| workflow YAML parse | 통과 |
| PR CI 실패 분석 | 확인 | `Release helper checks`가 `validate-github-body.sh` 실행 중 `rg` 누락으로 실패해 macOS release 관련 jobs에 `ripgrep` 설치 step 추가 |
| `write-release-pr-analysis.sh v0.1.4 v0.1.5` | 통과 |
| `write-release-pr-analysis.sh v0.1.4 v0.1.5` 제목 포함 dry-run | 통과 |
| GitHub API PR metadata path | 통과 |
| fallback PR analysis path | 통과 |
| `write-release-notes.sh 0.1.5 ...` | 통과 |
| `check-release-notes-template.sh` | 통과 |
| `write-release-delta-checklist.sh v0.1.4 HEAD` | 통과 |
| `update-release-version-notices.sh --check` | 통과 |
| `scripts/validate-github-body.sh` | 통과 |
| Pages HTML parse | 통과 |
| `git diff --check` | 통과 |

## Public 반영 결과

공개 반영 승인 후 다음을 완료했다.

- GitHub Release `v0.1.5` body 정정.
- GitHub Release `v0.1.5` body의 릴리즈 요약 반영 PR, 해결된 Issue, 참고/연관 Issue section을 제목/설명 포함 링크 형식으로 재정정.
- GitHub Release `v0.1.5` body를 주요 변경 우선 구조로 재정정하고 `검증 결과`, `릴리즈 delta 기반 추가 확인 항목` section 제거.
- GitHub Release `v0.1.5` body의 `다운로드 및 설치`를 `다운로드`, `지원 환경`, `설치 후 첫 실행`, `업데이트 확인`, `Homebrew` 하위 section으로 세분화.
- 대상 타스크 Issue 기준으로 해결된 Issue를 `#110`, `#121`, `#122`, `#323`으로 재정리.
- GitHub Release `v0.1.5` body section명을 `이번 릴리즈 관련 PR과 Issue`, `릴리즈 요약에 반영된 PR`, `참고/연관 Issue`로 정리하고, 이전 해결 Issue인 `#116`은 public 목록에서 제외.
- `docs/updates/v0.1.5.html` public Pages 배포.
- public GitHub Release body 재조회로 첫 section `이번 버전의 주요 변경 사항`, `다운로드 및 설치` 하위 section, `상세 기록`, 릴리즈 요약 반영 PR, 해결된 Issue, 참고/연관 Issue section의 제목/설명 포함 표기 확인.
- public Pages 재조회로 Quick Look/썸네일/PDF/공유 출력 표시 보강과 앱 실행 후 업데이트 확인 보강 문구 확인.

아래 항목은 여전히 로컬에서 직접 실행하지 않았다.

- release rehearsal/publish workflow artifact upload의 실제 GitHub Actions 실행

workflow artifact upload는 실제 release rehearsal/publish workflow 실행 시점에 확인한다.

## 남은 위험

- release owner가 `포함 PR 분석` 표의 사용자-facing 판단을 잘못 확정하면 generator는 그 판단을 그대로 public body에 반영한다.
- 대상 타스크 Issue가 PR title/body/report/branch에서 확인되지 않거나 PR body closing keyword가 누락된 실제 완료 Issue는 release record에서 명시적으로 완료 확정해야 해결된 Issue로 들어간다.
- workflow artifact upload는 로컬에서 검증할 수 없어 YAML parse와 helper dry-run으로만 확인했다.
