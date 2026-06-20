# Task M900 #356 Stage 2 완료보고서

## 단계 요약

릴리즈 노트 작성 절차의 1차 입력을 포함 PR/Issue/최종 보고서 분석으로 고정하는 매뉴얼 표준 구조를 추가했다.

이번 단계에서 자동화 helper는 아직 추가하지 않았다. Stage 3에서 helper를 구현하기 전에, release record와 runbook이 요구하는 표준 산출물과 판단 기준을 먼저 문서화했다.

## 변경 내용

| 파일 | 변경 |
|------|------|
| `mydocs/manual/release_github_pages_sparkle_guide.md` | `포함 PR 분석` section 추가, PR 분류 기준, 해결된 Issue/관련 Issue 구분, GitHub Release body의 `직접 반영된 PR과 Issue` section 기준 추가 |
| `mydocs/manual/public_release_runbook.md` | Gate 1.5 `포함 PR 분석` 추가, release note 최종 확인 gate에 사용자-facing PR 기준과 PR/Issue section 확인 추가 |
| `mydocs/manual/release_distribution_guide.md` | 전체 release flow와 최종 체크리스트에 포함 PR 분석, 분류, 해결된 Issue/관련 Issue 분리를 추가 |
| `mydocs/manual/ci_workflow_guide.md` | release workflow의 delta checklist가 path 기반 보조 자료이며 포함 PR 분석을 대체하지 않는다는 경계 명시 |
| `mydocs/manual/document_structure_guide.md` | `mydocs/release/v<version>.md` 장기 기록 항목에 포함 PR 분석과 직접 반영된 PR/Issue 구분 추가 |

## 표준화한 릴리즈 기록 구조

`mydocs/release/v<version>.md`에는 다음 표준 column의 `포함 PR 분석` 표를 남기도록 했다.

| PR | 제목 | 분류 | 사용자-facing | 공개 요약 반영 | 해결된 Issue | 관련 Issue | 근거 문서 | 비고 |
|----|------|------|---------------|----------------|---------------|-------------|-----------|------|

분류 기준은 다음 다섯 가지로 고정했다.

| 분류 | 기준 |
|------|------|
| 사용자-facing | HostApp, Quick Look preview, Finder thumbnail, 저장/공유/PDF/인쇄, 설치, 업데이트처럼 사용자가 직접 체감하는 변경 |
| 개발자-facing | 내부 개발자, 리뷰어, CI 작성자, 기여자 경험을 바꾸는 변경 |
| 운영/배포 | release workflow, signing/notarization, Pages/Sparkle, Homebrew, version/build, release record 변경 |
| 문서-only | source 동작이나 배포 산출물을 바꾸지 않는 문서 정리 |
| upstream sync | `rhwp` core 또는 bundled `rhwp-studio` provenance를 upstream release/commit 기준으로 동기화하는 변경 |

## 공개 표면 작성 기준

다음 기준을 매뉴얼에 반영했다.

- GitHub Release와 Pages의 `변경 요약` / `알한글 앱 변화`는 `포함 PR 분석` 표에서 사용자-facing으로 판정된 항목만 기준으로 작성한다.
- 개발자-facing, 운영/배포, 문서-only PR은 사용자-facing 결과가 따로 확인되지 않는 한 주요 변경 요약 근거로 쓰지 않는다.
- upstream sync는 사용자-facing 효과와 provenance 변경이 섞일 수 있으므로 upstream release note와 앱 경로 영향 검토 뒤 사용자-facing 여부를 별도로 판정한다.
- path 기반 delta checklist는 누락 확인과 smoke 영역 점검용 보조 자료로만 둔다.

## Issue 구분 기준

다음 기준을 매뉴얼에 반영했다.

- `해결된 Issue`는 PR body의 closing keyword 또는 release record에서 완료 확정된 항목만 쓴다.
- `Related`, `Refs`, `대상 타스크`, `관련 이슈`, `선행/연관`, 단순 링크는 `관련 Issue`로 분리한다.
- GitHub Release body에는 사용자 요약보다 뒤에 `직접 반영된 PR과 Issue` section을 둔다.
- 공개 GitHub body는 등록 전 `scripts/validate-github-body.sh <body-file>`를 통과해야 한다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `git diff --check` | 통과 | whitespace 오류 없음 |
| `scripts/validate-github-body.sh` on changed manuals | 통과 | PR/Issue 참조 토큰 뒤 한글 조사 결합 없음 |
| 핵심 키워드 검색 | 통과 | `포함 PR 분석`, `사용자-facing`, `해결된 Issue`, `관련 Issue`, `직접 반영된 PR`, `delta checklist` 검색 확인 |
| 변경 파일 확인 | 통과 | Stage 2 문서 5개와 단계 보고서만 변경 |

검증 명령:

```bash
git diff --check
scripts/validate-github-body.sh \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/manual/public_release_runbook.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/ci_workflow_guide.md \
  mydocs/manual/document_structure_guide.md
rg -n "포함 PR 분석|직접 반영된 PR|해결된 Issue|관련 Issue|사용자-facing|개발자-facing|운영/배포|문서-only|upstream sync|누락 확인용 보조" \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/manual/public_release_runbook.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/ci_workflow_guide.md \
  mydocs/manual/document_structure_guide.md
```

## 남은 위험

- Stage 2는 매뉴얼 표준화 단계라 실제 PR 분석 helper는 아직 없다.
- `write-release-notes.sh`와 `check-release-notes-template.sh`는 아직 `직접 반영된 PR과 Issue` section을 생성/검증하지 않는다. 이 보강은 Stage 4 범위다.
- release workflow는 아직 PR 분석 artifact를 만들지 않는다. 이 연결은 Stage 4 범위다.
- 기존 release record 중 과거 버전 문서에는 `포함 PR 분석` 표가 없을 수 있다. 이번 작업은 다음 릴리즈부터 적용하는 규칙화가 목적이며 과거 릴리즈 일괄 재작성은 범위 밖이다.

## 다음 단계 요청

Stage 3에서는 `previous_release_ref..candidate_ref` 범위의 merge PR 목록과 기본 분석 표 초안을 생성하는 `scripts/ci/write-release-pr-analysis.sh` helper를 추가한다.

Stage 3 진행 승인을 요청한다.
