# PR #328 검토 기록

## PR 정보

- 번호: #328
- 제목: Task #132: Copilot 보고서 리뷰 규칙 정렬
- URL: https://github.com/postmelee/alhangeul-macos/pull/328
- 작성자: `1jsjs`
- base/head: `devel` <- `1jsjs:task-132-align-copilot-review`
- 외부 fork 여부: 예 (`1jsjs/alhangeul-macos`)
- 연결 이슈: #132 Copilot Code Review 보고서 규칙 정렬
- 작성자 이력: 조회 범위 내 기존 PR/merge 이력 없음. 첫 외부 기여 PR로 판단.

## Review 시작 triage

### 초기 상태

- assignee: 없음
- label: 없음
- milestone: 없음
- reviewer request: 없음
- 연결 이슈 #132 label: `documentation`, `area:workflow`, `kind:follow-up`
- 연결 이슈 #132 milestone: `하이퍼-워터폴 작업환경 조성`

### 권장값

- reviewer: `postmelee`
- assignee: `1jsjs`
- label: `documentation`, `area:workflow`, `kind:follow-up`
- milestone: `하이퍼-워터폴 작업환경 조성`

### 작업지시자 선택

- 선택: triage 적용 후 리뷰 진행
- 승인 시각: 2026-06-03 KST, 같은 스레드에서 "1. 로 진행해줘."로 승인

### 적용 결과

- `postmelee` review request 적용됨
- `1jsjs` assignee 적용됨
- `하이퍼-워터폴 작업환경 조성` milestone 적용됨
- `documentation`, `area:workflow`, `kind:follow-up` label 적용됨
- 참고: 첫 `gh pr edit`는 milestone 이름 공백 quoting 문제로 실패했고, 두 번째 통합 적용 명령은 GitHub GraphQL 오류를 반환했으나 reviewer/assignee/milestone은 부분 적용됨을 확인했다. label은 별도 명령으로 적용 완료했다.

## 변경 요약

- `.github/copilot-instructions.md`
  - workflow/review 지침을 짧게 압축했다.
  - `mydocs/plans/**`, `mydocs/working/**`, `mydocs/report/**` 변경은 새 path-specific instruction을 적용하라고 연결했다.
- `.github/instructions/hyperfall-documents.instructions.md`
  - `applyTo` frontmatter로 하이퍼-워터폴 문서 경로를 지정했다.
  - 계획서, 단계 보고서, 최종 보고서의 추적성/검증 신뢰성 중심 리뷰 기준을 추가했다.

## 영향 범위와 호환성

- FFI/RustBridge: 영향 없음
- build/Xcode/project.yml: 영향 없음
- Quick Look/Thumbnail: 영향 없음
- core pin/rhwp-core.lock: 영향 없음
- 문서/워크플로우: Copilot Code Review 지침에만 영향
- GitHub Copilot custom instructions:
  - 공식 문서 기준 `.github/copilot-instructions.md`는 repository-wide instruction 경로로 유효하다.
  - 공식 문서 기준 `.github/instructions/**/*.instructions.md`와 `applyTo` frontmatter는 path-specific instruction 경로로 유효하다.
  - Copilot Code Review는 custom instruction 파일별 첫 4,000자만 사용하므로 길이 제한을 확인해야 한다.

## 코드/문서 점검 결과

- PR base는 `devel`로 정책과 맞다.
- 변경 파일은 GitHub Copilot instruction 파일 2개뿐이며, 앱 코드/빌드 설정/생성 산출물을 건드리지 않는다.
- 새 `applyTo` 범위는 `mydocs/plans/**/*.md`, `mydocs/working/**/*.md`, `mydocs/report/**/*.md`로 하이퍼-워터폴 문서 검토 범위와 맞다.
- repo-wide instruction은 문서 전용 기준을 path-specific instruction으로 분리하고, 기존 branch/build/architecture/release-risk 기준을 유지한다.
- path-specific instruction은 문체 지적보다 추적성, 폴더/파일명, stage/commit linkage, 실제 검증, 승인 경계를 우선하도록 정리되어 목적과 맞다.
- 차단 이슈는 발견하지 못했다.

## 검증 계획

- 수행한 검증:
  - `gh pr view 328 --repo postmelee/alhangeul-macos --json ...`
  - `gh issue view 132 --repo postmelee/alhangeul-macos --json ...`
  - `gh pr diff 328 --repo postmelee/alhangeul-macos`
  - `gh pr checks 328 --repo postmelee/alhangeul-macos`
  - `git fetch origin devel pull/328/head:refs/remotes/origin/pr/328`
  - `git diff --check origin/devel...origin/pr/328`
  - `git show origin/pr/328:.github/copilot-instructions.md | wc -m`
  - `git show origin/pr/328:.github/instructions/hyperfall-documents.instructions.md | wc -m`
- 결과:
  - `git diff --check`: 통과
  - `.github/copilot-instructions.md`: 3,962자
  - `.github/instructions/hyperfall-documents.instructions.md`: 1,561자
  - PR checks: `task-132-align-copilot-review` branch에 보고된 check 없음
- 추가 검증 필요:
  - GitHub Copilot Code Review의 실제 적용 여부는 GitHub 서비스 동작에 의존하므로, merge 후 문서 변경 PR 또는 테스트 PR에서 Copilot review를 다시 요청해 확인하는 것이 현실적이다.

## 권고

- 권고: merge
- 근거:
  - 연결 이슈 #132의 목적과 변경 범위가 일치한다.
  - `devel` base, label/milestone, 외부 fork PR 상태가 정리됐다.
  - 변경이 GitHub Copilot instruction에 한정되어 앱 런타임/빌드/FFI 위험이 없다.
  - 문법, 파일 위치, 길이 제한, 공백 검증에서 차단 이슈가 없다.
- 유의:
  - PR checks가 보고되지 않아 CI 녹색 신호는 없다. 다만 변경 범위가 `.github` instruction 문서뿐이라 별도 빌드 검증은 요구하지 않는다.
  - 실제 Copilot review 품질 개선은 merge 후 후속 PR에서 관찰해야 한다.

## merge 후 완료 처리 handoff 필요 여부

- 필요.
- PR merge 후 `external-pr-complete` Skill로 완료 코멘트, 연결 이슈 #132 close 여부, `pr_328_report.md` 작성, `mydocs/pr/archives/` 이동을 처리한다.

## 작업지시자 승인 요청

- 위 검토 결과 기준으로 PR #328은 merge 권고다.
- merge 또는 cherry-pick 여부는 작업지시자가 결정한다.
