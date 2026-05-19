# Task M013 #272 구현계획서

## 구현 목표

GitHub Issue Forms 기반의 필수 이슈 템플릿 세트를 추가해 사용자 제보와 개발자 작업 제안을 구조화한다. 최종 산출물은 `.github/ISSUE_TEMPLATE/` 아래 7개 Issue Form, 빈 이슈 허용 `config.yml`, 단계 보고서, 최종 보고서다.

## Stage 1: Issue Forms 설계와 label 매핑 확정

### 작업 범위

- GitHub Issue Forms top-level schema와 field type 사용 기준을 확인한다.
- 현재 저장소의 기존 label 목록을 확인하고 각 템플릿의 기본 label을 기존 label 안에서만 매핑한다.
- 필수 세트 7종의 사용자 입력 항목을 확정한다.
- required 필드는 triage에 꼭 필요한 최소 항목으로 제한한다.
- 보안 취약점은 일반 issue template으로 받지 않는다는 안내 문구를 둘 위치를 정한다.

### 산출물

- `mydocs/working/task_m013_272_stage1.md`

### 검증

```bash
gh api repos/postmelee/alhangeul-macos/labels --paginate --jq '.[] | {name,description,color}'
git diff --check
```

GitHub Docs 확인은 공식 문서를 기준으로 수행하고, 조회가 필요한 경우 네트워크 권한을 승인받아 진행한다.

### 커밋

```text
Task #272 Stage 1: 이슈 템플릿 설계 확정
```

## Stage 2: Issue Template YAML 추가

### 작업 범위

- `.github/ISSUE_TEMPLATE/config.yml`을 추가하고 `blank_issues_enabled: true`로 설정한다.
- 다음 7개 Issue Form을 추가한다.
  - `01-user-bug.yml`
  - `02-document-compatibility.yml`
  - `03-quick-look-thumbnail.yml`
  - `04-feature-request.yml`
  - `05-install-update-release.yml`
  - `07-developer-task.yml`
  - `08-regression.yml`
- 각 템플릿에 `name`, `description`, `title`, `labels`, `body`를 둔다.
- 사용자-facing 템플릿은 macOS 버전, 앱 버전, 설치 경로, 재현 절차, 기대/실제 동작, 첨부 가능 여부를 흐름에 맞게 묻는다.
- 개발자-facing 템플릿은 배경, 목표, 범위, 제외, 예상 label/milestone 후보, 하이퍼-워터폴 절차 확인 항목을 포함한다.

### 산출물

- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/ISSUE_TEMPLATE/01-user-bug.yml`
- `.github/ISSUE_TEMPLATE/02-document-compatibility.yml`
- `.github/ISSUE_TEMPLATE/03-quick-look-thumbnail.yml`
- `.github/ISSUE_TEMPLATE/04-feature-request.yml`
- `.github/ISSUE_TEMPLATE/05-install-update-release.yml`
- `.github/ISSUE_TEMPLATE/07-developer-task.yml`
- `.github/ISSUE_TEMPLATE/08-regression.yml`
- `mydocs/working/task_m013_272_stage2.md`

### 검증

```bash
ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }; puts "ok"' .github/ISSUE_TEMPLATE/*.yml
rg -n "name:|description:|title:|labels:|body:|blank_issues_enabled" .github/ISSUE_TEMPLATE
git diff --check
```

### 커밋

```text
Task #272 Stage 2: GitHub Issue Forms 추가
```

## Stage 3: 구조 검증과 템플릿 품질 점검

### 작업 범위

- 모든 Issue Form YAML이 parse 가능한지 확인한다.
- GitHub form schema 관점에서 `id`, `attributes`, `validations`, dropdown options 구성이 일관되는지 점검한다.
- template chooser 정렬이 파일명 prefix 기준으로 의도와 맞는지 확인한다.
- label 참조가 기존 label과 일치하는지 다시 대조한다.
- required 필드가 과도하지 않은지 사용자-facing 템플릿을 읽어 점검한다.

### 산출물

- 필요 시 `.github/ISSUE_TEMPLATE/*.yml` 보정
- `mydocs/working/task_m013_272_stage3.md`

### 검증

```bash
ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }; puts "ok"' .github/ISSUE_TEMPLATE/*.yml
gh api repos/postmelee/alhangeul-macos/labels --paginate --jq '.[].name'
rg -n "labels: \\[|labels:|validations:|required: true|type: dropdown|type: textarea|type: checkboxes" .github/ISSUE_TEMPLATE
git diff --check
git status --short --branch
```

GitHub UI 렌더링은 로컬에서 완전히 재현할 수 없으므로, PR 게시 후 template chooser 확인을 잔여 검증으로 남긴다.

### 커밋

```text
Task #272 Stage 3: 이슈 템플릿 구조 검증
```

## Stage 4: 최종 검증과 보고

### 작업 범위

- 수행계획서와 구현계획서의 포함/제외 범위가 지켜졌는지 확인한다.
- 최종 결과보고서를 작성한다.
- 오늘할일 상태를 완료로 갱신한다.
- PR 게시 시 사용자-facing 변경점과 잔여 GitHub UI 확인 항목을 정리한다.

### 산출물

- `mydocs/report/task_m013_272_report.md`
- `mydocs/orders/20260519.md`

### 검증

```bash
ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }; puts "ok"' .github/ISSUE_TEMPLATE/*.yml
rg -n "blank_issues_enabled|사용자|문서|Quick Look|Thumbnail|설치|업데이트|회귀|하이퍼-워터폴" .github/ISSUE_TEMPLATE mydocs/report/task_m013_272_report.md
git diff --check
git status --short --branch
```

### 커밋

```text
Task #272 Stage 4 + 최종 보고서: 이슈 템플릿 정리
```

## PR 계획

- 작업 브랜치: `local/task272`
- 게시 브랜치: `publish/task272`
- 대상 브랜치: `devel`
- PR 제목 후보: `Add GitHub Issue Forms for users and developers`
- PR 본문에는 추가된 템플릿 목록, 빈 이슈 허용 설정, label 매핑, 로컬 YAML 검증 결과, PR 이후 GitHub UI 확인 필요 사항을 포함한다.

## 변경 금지 사항

- 새 label 또는 milestone을 만들지 않는다.
- GitHub repository settings를 변경하지 않는다.
- Security advisory, `SECURITY.md`, Discussions 정책을 이번 작업에 섞지 않는다.
- PR template을 수정하지 않는다.
- 제품 Swift/Rust 코드, workflow, release 설정을 수정하지 않는다.
