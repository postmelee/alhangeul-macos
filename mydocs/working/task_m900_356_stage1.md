# Task M900 #356 Stage 1 완료보고서

## 단계 요약

현재 release note 작성 경로와 `v0.1.5` 사례를 분석해, PR/Issue/최종 보고서 기반 release note 절차가 들어갈 지점을 정리했다.

결론은 다음과 같다.

| 항목 | 판단 |
|------|------|
| 현행 1차 자동 입력 | path 기반 `release delta checklist` |
| 현행 release note 원천 | `mydocs/release/v<version>.md`의 `GitHub Release 본문 구조 후보` |
| 현행 누락 | 포함 PR 분석 표, PR body/linked Issue/report 수집, 직접 반영된 PR/Issue section 검증 |
| 보강 방향 | `포함 PR 분석` 표를 release detail doc에 남기고, GitHub Release body는 그 표의 사용자-facing 판단을 기준으로 작성 |
| delta checklist 위치 | 계속 생성하되 누락 확인과 smoke 영역 점검용 보조 자료로 제한 |

## 확인한 현행 경로

| 파일 또는 workflow | 현재 역할 | Stage 1 판단 |
|-------------------|-----------|--------------|
| `scripts/ci/write-release-delta-checklist.sh` | `previous_release_ref..candidate_ref` 범위의 변경 파일 path를 영향 영역별로 분류 | PR title/body, linked Issue, 최종 보고서를 읽지 않는다. 보조 자료로 유지해야 한다. |
| `scripts/ci/write-release-notes.sh` | release detail doc의 `GitHub Release 본문 구조 후보`를 읽어 GitHub Release body 후보 생성 | `변경 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`만 요구한다. 직접 반영된 PR/Issue section은 없다. |
| `scripts/ci/check-release-notes-template.sh` | generated release note의 필수 heading, 상세 문서 링크, placeholder 금지 문구 검증 | 포함 PR 분석 표 또는 해결된 Issue/관련 Issue 구분을 검증하지 않는다. |
| `.github/workflows/release-rehearsal.yml` | release delta checklist를 summary/artifact로 업로드 | path 기반 checklist만 생성한다. PR 분석 artifact는 없다. |
| `.github/workflows/release-publish.yml` | path 기반 checklist 생성, signed/notarized DMG 생성, release note 작성, GitHub Release publish | release note 작성 전에 PR/Issue/report 분석 결과를 검증하지 않는다. |
| `.github/workflows/pr-ci.yml` | release helper dry-run, release note template check, delta checklist dry-run | dry-run sample이 `v0.1.3`/`v0.1.2` 기준으로 남아 있고, PR 분석 helper 검증은 없다. |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | GitHub Release body, Pages, Sparkle, delta checklist 기준 | 사용자-facing 문구 원칙은 있지만 포함 PR 분석 표 절차와 해결된 Issue 구분 기준은 부족하다. |
| `mydocs/manual/public_release_runbook.md` | release 당일 gate와 검증 순서 | release context 수집과 delta checklist 확인은 있으나 PR/Issue/report 분석 gate가 없다. |
| `mydocs/release/v0.1.5.md` | v0.1.5 release decision record | 연결된 Issue/PR 표가 좁아 실제 포함 PR 전체와 사용자-facing 판단을 남기지 못했다. |

## v0.1.5 사례 분석

`git log --oneline --merges v0.1.4..v0.1.5`는 다음 계열의 merge PR을 함께 보여준다.

| 계열 | 예시 | 의미 |
|------|------|------|
| release transport | PR #353 | `devel` release candidate를 `main`으로 반영한 PR |
| release candidate 준비 | PR #352 | version, workflow default, Pages/release record 정렬 |
| upstream sync | PR #349 | `rhwp v0.7.15` core/studio sync |
| upstream sync 자동화 | PR #350 | full sync PR workflow 보강 |
| 사용자-facing renderer 개선 | PR #334, PR #329, PR #326 | FormObject, RawSvg/OLE, image fill mode native renderer 보강 |
| 사용자-facing update 동작 | PR #324 | 앱 실행 시 Sparkle background check |
| 문서/운영 규칙 | PR #328, PR #331, PR #333 | Copilot/GitHub body/external PR skill 규칙 |
| 이전 release closeout | PR #310 부터 PR #322 일부 | `v0.1.4` 후속 정리와 docs-only Pages 관련 작업 |

`git log --first-parent --oneline --merges v0.1.4..v0.1.5`는 PR #353 같은 main 반영 PR과 devel bridge PR 중심으로 보인다. 이 경로만 쓰면 devel 안의 실제 작업 PR을 놓칠 수 있다. 따라서 helper는 first-parent release transport PR을 따로 표시하되, 전체 merge commit subject에서 포함 작업 PR도 함께 수집해야 한다.

## 대표 PR body에서 확인한 Issue 구분

| PR | body에서 확인한 패턴 | Stage 1 판단 |
|----|---------------------|--------------|
| PR #324 | `대상 타스크: #323`, `관련 이슈 없음` | 대상 타스크는 작업 근거지만 closing keyword가 없으므로 해결된 Issue로 자동 확정하면 안 된다. |
| PR #326 | `대상 타스크: #122`, `Refs #106`, `Refs #116`, `Refs #280`, `Refs #282` | `Refs` 항목은 관련 Issue로 분리해야 한다. |
| PR #329 | `대상 타스크: #121`, upstream issue 링크 | upstream issue는 관련 항목이지 저장소 해결된 Issue로 단정할 수 없다. |
| PR #334 | `대상 타스크: #110`, `Closes #110`, 선행/연관 Issue 목록 | closing keyword가 있으므로 해결된 Issue 후보로 볼 수 있다. |
| PR #349 | upstream sync 자동 PR body, release boundary 명시 | upstream sync 분류가 필요하다. 사용자-facing 여부는 upstream release note와 앱 경로 영향 검토 뒤 판정해야 한다. |
| PR #350 | full sync PR workflow 보강, PR #349 생성 검증 | 개발자-facing 또는 운영/배포로 분류해야 하며 사용자 요약 원천은 아니다. |
| PR #352 | `Related: #351`, release candidate 준비 | release 실행/운영 항목이다. `Related`는 해결된 Issue가 아니다. |
| PR #353 | `Related: #351`, main 반영 PR | release transport PR이다. 포함 범위 설명에는 필요하지만 사용자-facing 변화 자체는 아니다. |

## 보고서 탐색 기준

내부 작업 보고서는 milestone 코드가 파일명에 포함되어 있어 Issue 번호만으로 정확한 경로를 단정하기 어렵다. 다만 다음 패턴으로 후보를 찾을 수 있다.

```text
mydocs/report/task_*_<issue>_report.md
```

`v0.1.5` 대표 사용자-facing 후보의 보고서 후보는 다음처럼 확인된다.

| Issue | 보고서 후보 |
|-------|-------------|
| #110 | `mydocs/report/task_m014_110_report.md` |
| #121 | `mydocs/report/task_m014_121_report.md` |
| #122 | `mydocs/report/task_m014_122_report.md` |
| #323 | `mydocs/report/task_m040_323_report.md` |
| #348 | `mydocs/report/task_m019_348_report.md` |

보고서가 없는 외부 PR, release transport PR, 자동 upstream sync PR은 PR body와 release record를 근거로 수동 보정해야 한다.

## 포함 PR 분석 표 설계

Stage 2에서 release detail doc에 추가할 표준 구조는 다음 column을 기준으로 한다.

| Column | 목적 |
|--------|------|
| `PR` | merge된 PR 번호와 링크 |
| `제목` | PR title |
| `분류` | 사용자-facing, 개발자-facing, 운영/배포, 문서-only, upstream sync |
| `사용자-facing` | GitHub Release/Pages 사용자 요약 후보 여부 |
| `공개 요약 반영` | `변경 요약` 또는 `알한글 앱 변화`에 실제 반영했는지 |
| `해결된 Issue` | closing keyword 또는 release record 완료 확정 Issue |
| `관련 Issue` | Refs, Related, 선행/연관, 단순 참고 Issue |
| `근거 문서` | PR body, 최종 보고서, release record |
| `비고` | release owner 수동 판단, smoke 필요, upstream 영향 요약 |

## 자동화 요구사항

Stage 3 helper는 다음 원칙으로 설계한다.

1. 입력은 `previous_release_ref`, `candidate_ref`, output file이다.
2. merge PR 목록은 git merge commit subject에서 먼저 수집한다.
3. `gh pr view`를 사용할 수 있으면 title/body/files/merge commit을 보강한다.
4. `gh` 사용이 불가능하면 git subject와 파일 path 기반 초안을 만들고, 수동 확인 필요로 표시한다.
5. closing keyword만 해결된 Issue 후보로 추출한다.
6. `Refs`, `Related`, `대상 타스크`, `관련 이슈`, `선행/연관`은 관련 Issue 후보로 분리한다.
7. `mydocs/report/task_*_<issue>_report.md` 후보를 찾아 근거 문서 column에 넣는다.
8. 분류와 사용자-facing 여부는 자동 승인하지 않고 release owner 확인값으로 둔다.

## Stage 2 반영 포인트

Stage 2에서는 다음 문서 기준을 먼저 고정해야 한다.

- release detail doc에는 `포함 PR 분석` 표를 남긴다.
- GitHub Release와 Pages의 `변경 요약` / `알한글 앱 변화`는 `포함 PR 분석`에서 사용자-facing으로 판정된 항목만 기준으로 작성한다.
- GitHub Release body에는 `직접 반영된 PR과 Issue` section을 추가한다.
- 해결된 Issue와 관련 Issue를 분리한다.
- path 기반 delta checklist는 누락 확인용 보조 자료로만 둔다.
- GitHub 공개 body는 `--body-file`과 `scripts/validate-github-body.sh`를 거친다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `git status --short --branch` | 통과 | `local/task356` |
| `git log --oneline --merges v0.1.4..v0.1.5` | 통과 | release transport와 포함 작업 PR이 함께 확인됨 |
| `git log --first-parent --oneline --merges v0.1.4..v0.1.5` | 통과 | first-parent만으로는 실제 작업 PR을 놓칠 수 있음을 확인 |
| `gh pr view` 대표 PR 확인 | 통과 | PR #324, PR #326, PR #329, PR #334, PR #349, PR #352, PR #353 body/files 확인 |
| release helper/workflow 파일 확인 | 통과 | generator/checker/workflow 현재 경계 확인 |
| 보고서 후보 탐색 | 통과 | `mydocs/report/task_*_<issue>_report.md` 패턴 확인 |

## 남은 위험

- GitHub API가 없는 환경에서는 PR body와 linked Issue를 자동으로 보강할 수 없다. helper는 fallback output과 수동 확인 필요 표시를 가져야 한다.
- closing keyword 없이 작업 타스크만 적은 PR이 많아, 해결된 Issue를 자동으로 넓게 잡으면 과대 계산된다.
- upstream sync PR은 사용자-facing 변화와 provenance 변경이 섞인다. 사용자-facing 판정은 upstream release note와 앱 경로 영향 검토가 필요하다.
- release transport PR과 포함 작업 PR을 같은 표에 넣을지, transport PR을 별도 비고로 둘지는 Stage 2 표준 구조에서 고정해야 한다.

## 다음 단계 요청

Stage 2에서는 release detail doc과 매뉴얼에 `포함 PR 분석` 표, 분류 기준, 해결된 Issue/관련 Issue 구분, path delta checklist 보조 위치를 문서화한다.

Stage 2 진행 승인을 요청한다.
