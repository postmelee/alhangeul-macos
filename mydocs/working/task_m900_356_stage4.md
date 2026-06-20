# Task M900 #356 Stage 4 완료보고서

## 단계 요약

Release note generator, template checker, PR CI, release rehearsal/publish workflow가 포함 PR 분석 결과를 다루도록 연결했다.

이번 단계부터 GitHub Release body 후보는 `mydocs/release/v<version>.md`의 `포함 PR 분석`과 `GitHub Release 본문 구조 후보`를 함께 요구한다. `변경 요약`과 `알한글 앱 변화`는 사용자-facing으로 확정한 PR만 기준으로 작성하고, public body에는 `직접 반영된 PR과 Issue` section을 별도 top-level section으로 생성한다.

## 변경 내용

| 파일 | 변경 |
|------|------|
| `scripts/ci/write-release-notes.sh` | release detail doc의 `## 포함 PR 분석` 존재를 요구하고, `### 직접 반영된 PR`, `### 해결된 Issue`, `### 관련 Issue`를 GitHub Release body의 `## 직접 반영된 PR과 Issue` section으로 출력 |
| `scripts/ci/check-release-notes-template.sh` | PR/Issue section heading과 확정된 `#N` 또는 `없음` 항목을 검증하고, `확인 필요` 같은 미확정 문구를 금지 |
| `scripts/ci/write-release-delta-checklist.sh` | 새 PR 분석 helper 파일을 release tooling path로 분류해 보조 delta checklist에서 수동 분류로 떨어지지 않게 보정 |
| `.github/workflows/pr-ci.yml` | release helper dry-run sample을 `v0.1.5` 기준으로 갱신하고 PR 분석 helper dry-run과 `validate-github-body` 검증 추가 |
| `.github/workflows/release-rehearsal.yml` | rehearsal에서 `pr-analysis-<version>.md` 생성, summary 기록, artifact upload 추가 |
| `.github/workflows/release-publish.yml` | publish에서 tag 기준 `pr-analysis-<version>.md` 생성, summary 기록, artifact upload 추가 |
| `mydocs/release/v0.1.5.md` | `v0.1.4..v0.1.5` 포함 PR 분석 표와 GitHub Release용 직접 반영 PR/Issue section 후보 추가 |
| `mydocs/manual/ci_workflow_guide.md` | release checks 재현 명령, workflow 권한, PR 분석 artifact 산출물 설명 갱신 |
| `mydocs/manual/release_distribution_guide.md` | release 자산 목록과 rehearsal artifact 설명에 PR 분석 helper 반영 |

## Generator와 Checker 기준

`write-release-notes.sh`는 다음 조건을 만족하지 못하면 public body 후보 생성을 중단한다.

| 조건 | 이유 |
|------|------|
| `mydocs/release/v<version>.md`에 `## 포함 PR 분석` 존재 | public wording의 1차 입력을 PR/Issue/report 분석으로 고정 |
| `### 변경 요약`, `### 포함된 rhwp 변화`, `### 알한글 앱 변화` 존재 | 기존 GitHub Release 주요 변경 section 유지 |
| `### 직접 반영된 PR`, `### 해결된 Issue`, `### 관련 Issue` 존재 | public body에 PR/Issue provenance를 분리해 남김 |

`check-release-notes-template.sh`는 generated body에서 다음을 검증한다.

| 조건 | 기준 |
|------|------|
| `## 직접 반영된 PR과 Issue` heading | GitHub Release body top-level section |
| `### 직접 반영된 PR`, `### 해결된 Issue`, `### 관련 Issue` heading | PR, resolved Issue, related Issue 분리 |
| 각 PR/Issue 하위 section의 확정 항목 | `- \`#N\`` 또는 `- 없음` |
| release detail doc link | GitHub blob URL과 local `## 포함 PR 분석` 확인 |
| 미확정 public wording 금지 | `확인 필요`, placeholder 문구 금지 |

## Workflow 연결

| workflow | 변경 |
|----------|------|
| PR CI | `write-release-notes.sh 0.1.5 ...`, `check-release-notes-template.sh`, `validate-github-body.sh`, `write-release-pr-analysis.sh v0.1.4 HEAD ...`, PR 분석 output validator 실행 |
| Release Rehearsal DMG | `$GITHUB_SHA` 기준 `pr-analysis-<version>.md` 생성, `alhangeul-macos-<version>-rehearsal-pr-analysis` artifact upload |
| Release Publish DMG | `v<version>` tag 기준 `pr-analysis-<version>.md` 생성, `alhangeul-macos-<version>-release-pr-analysis` artifact upload |

두 release workflow 모두 `pull-requests: read` permission과 `GH_TOKEN`을 사용해 PR body 보강 경로를 우선 시도한다. path 기반 delta checklist summary는 누락 확인과 smoke 영역 점검용 보조 자료라는 문구로 정리했다.

## v0.1.5 release record 보강

`mydocs/release/v0.1.5.md`에는 `v0.1.4..v0.1.5` 범위의 포함 PR 분석 표를 추가했다.

GitHub Release body 후보의 직접 반영 PR은 다음 항목으로 확정했다.

- `#324`
- `#326`
- `#329`
- `#334`
- `#349`

해결된 Issue는 closing keyword 기준으로 `#110`만 public body 후보에 넣었다. `#106`, `#116`, `#121`, `#122`, `#280`, `#282`, `#323`, `#348`, `#351`은 관련 Issue로 분리했다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `bash -n scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh scripts/ci/write-release-pr-analysis.sh scripts/ci/write-release-delta-checklist.sh` | 통과 | shell syntax 오류 없음 |
| workflow YAML parse | 통과 | `ruby`/`psych`로 전체 `.github/workflows/*.yml` parse |
| `scripts/ci/write-release-notes.sh 0.1.5 ...` | 통과 | `build.noindex/release/release-notes-0.1.5.md` 생성 |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.5.md` | 통과 | PR/Issue section 포함 |
| `scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 ...` | 통과 | PR 분석 초안 생성 |
| `scripts/ci/write-release-delta-checklist.sh v0.1.4 HEAD ...` | 통과 | 보조 delta checklist 생성 |
| `scripts/validate-github-body.sh` | 통과 | release notes, PR analysis, changed manual/release docs |
| `git diff --check` | 통과 | whitespace 오류 없음 |

검증 명령:

```bash
bash -n scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh scripts/ci/write-release-pr-analysis.sh scripts/ci/write-release-delta-checklist.sh
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
scripts/ci/write-release-notes.sh 0.1.5 d347c13b80aeaa006776db7ae2b00f8a2d11836c94757165f4bb87a331dd585b build.noindex/release/release-notes-0.1.5.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.5.md
scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5.md
scripts/ci/write-release-delta-checklist.sh v0.1.4 HEAD build.noindex/release/delta-checklist-0.1.5.md
scripts/validate-github-body.sh build.noindex/release/release-notes-0.1.5.md build.noindex/release/pr-analysis-0.1.5.md mydocs/release/v0.1.5.md mydocs/manual/ci_workflow_guide.md mydocs/manual/release_distribution_guide.md
git diff --check
```

## 남은 위험

- workflow의 실제 artifact upload는 로컬에서 실행할 수 없으므로 YAML parse와 helper dry-run으로 검증했다.
- PR CI에서 `HEAD` 기준 PR 분석은 현재 PR branch의 commit range에 따라 fallback metadata가 섞일 수 있다. release rehearsal/publish에서는 `GH_TOKEN`과 `pull-requests: read` 권한을 부여해 PR body 보강 경로를 우선 사용한다.
- generated release notes는 `mydocs/release/v<version>.md`의 확정 section을 그대로 사용한다. release owner가 `포함 PR 분석` 표를 보정하지 않으면 public body도 부정확해질 수 있다.

## 다음 단계 요청

Stage 5에서는 문서, helper, generator/checker, workflow 연결을 end-to-end로 재검증하고 최종 보고서를 준비한다.

Stage 5 진행 승인을 요청한다.
