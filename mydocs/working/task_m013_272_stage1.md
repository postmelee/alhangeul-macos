# Task M013 #272 Stage 1 보고서

## 단계 목적

GitHub Issue Forms 기반 이슈 템플릿을 추가하기 전에 공식 form schema, 저장소의 기존 label 체계, 템플릿별 입력 항목과 기본 label 매핑을 확정했다.

이번 단계에서는 `.github/ISSUE_TEMPLATE/` 파일을 만들지 않았다. 실제 YAML 파일 추가는 Stage 2 범위로 남겼다.

## 공식 문법 확인

GitHub 공식 문서 기준으로 확인한 구현 제약은 다음과 같다.

| 항목 | 확인 내용 | 적용 |
|------|-----------|------|
| 파일 위치 | Issue Forms는 `.github/ISSUE_TEMPLATE/*.yml`에 둔다. | Stage 2에서 7개 `.yml` 파일 추가 |
| 필수 top-level key | `name`, `description`, `body`가 필요하다. | 모든 form에 공통 적용 |
| 선택 top-level key | `title`, `labels`, `assignees`, `projects`, `type` 등을 둘 수 있다. | `title`, `labels`만 사용 |
| form element type | `markdown`, `textarea`, `input`, `dropdown`, `checkboxes`, `upload`를 사용할 수 있다. | 6종 모두 필요에 따라 사용 |
| element id | `markdown` 외 element는 고유 `id`를 둘 수 있고, 영문/숫자/`-`/`_`만 사용한다. | 모든 `id`는 ASCII kebab-case 사용 |
| required | `validations.required` 또는 checkbox option의 `required`로 필수 입력을 지정한다. | 사용자 friction을 줄이기 위해 최소화 |
| blank issue | `config.yml`의 `blank_issues_enabled: true`는 빈 이슈 선택지를 노출한다. | 사용자 요청대로 true 설정 |
| 정렬 | 템플릿은 파일명 기준 alphanumeric 정렬된다. | 두 자리 숫자 prefix 사용 |

참조 문서:

- GitHub Docs: `Syntax for issue forms`
- GitHub Docs: `Syntax for GitHub's form schema`
- GitHub Docs: `Configuring issue templates for your repository`

## 기존 label 확인

`gh api repos/postmelee/alhangeul-macos/labels --paginate --jq '.[] | {name,description,color}'`로 확인한 기존 label 중 이번 작업에 사용할 label은 다음으로 제한한다.

| label | 용도 |
|-------|------|
| `bug` | 실제 동작 문제, 설치/업데이트 문제, 회귀 문제 |
| `enhancement` | 기능 제안, 일반 개발 작업 제안 |
| `question` | 개발자 타스크 초안처럼 maintainer triage가 필요한 입력 |
| `area:viewer-app` | HostApp viewer/app UX 문제 |
| `area:rendering` | 렌더링, 문서 표시 품질, renderer behavior |
| `area:test-assets` | sample 문서, fixture, 재현 문서 관리 |
| `area:quick-look` | Quick Look preview extension 문제 |
| `area:thumbnail` | Finder thumbnail extension 문제 |
| `area:ci-cd` | 설치, 배포, DMG, Homebrew, release automation 문제 |
| `area:workflow` | 하이퍼-워터폴, 이슈/PR workflow 관련 작업 |
| `kind:regression` | 이전 동작 대비 품질 저하 |

새 label은 만들지 않는다.

## 템플릿별 설계

### `01-user-bug.yml`

| 항목 | 값 |
|------|----|
| name | `앱 문제 제보` |
| description | 앱 실행, 파일 열기, 저장, 공유, PDF 내보내기 등 일반 사용 중 문제 |
| title | `[Bug] ` |
| labels | `["bug", "area:viewer-app"]` |

입력 항목:

| id | type | 필수 | 용도 |
|----|------|------|------|
| `security-check` | `markdown` | - | 보안 취약점/민감정보를 public issue에 쓰지 말라는 안내 |
| `summary` | `textarea` | 예 | 문제 요약과 기대/실제 동작 |
| `steps` | `textarea` | 예 | 재현 절차 |
| `macos-version` | `input` | 예 | macOS 버전 |
| `app-version` | `input` | 예 | 알한글 앱 버전/빌드 |
| `install-source` | `dropdown` | 예 | DMG, Homebrew, source build 등 설치 경로 |
| `file-type` | `dropdown` | 아니오 | HWP/HWPX/기타 |
| `attachments` | `upload` | 아니오 | 스크린샷, 로그, 짧은 영상 |
| `extra-context` | `textarea` | 아니오 | 추가 맥락 |

판단:

- 일반 앱 문제는 HostApp UX가 주 triage 표면이므로 `area:viewer-app`을 기본 label로 둔다.
- 문서 자체 호환성 문제는 별도 `02-document-compatibility.yml`로 유도한다.

### `02-document-compatibility.yml`

| 항목 | 값 |
|------|----|
| name | `문서 호환성 문제` |
| description | 특정 HWP/HWPX 문서가 열리지 않거나 표시/저장/내보내기 결과가 이상한 문제 |
| title | `[Compat] ` |
| labels | `["bug", "area:rendering", "area:test-assets"]` |

입력 항목:

| id | type | 필수 | 용도 |
|----|------|------|------|
| `privacy-check` | `markdown` | - | 민감한 문서 첨부 전 개인정보 제거 안내 |
| `summary` | `textarea` | 예 | 문제 요약 |
| `document-format` | `dropdown` | 예 | HWP, HWPX, HWP3, 알 수 없음 |
| `affected-surface` | `dropdown` | 예 | 앱 화면, Quick Look, thumbnail, PDF export, print, share 등 복수 선택 |
| `expected-result` | `textarea` | 예 | 기대 결과 |
| `actual-result` | `textarea` | 예 | 실제 결과 |
| `app-version` | `input` | 예 | 앱 버전/빌드 |
| `macos-version` | `input` | 예 | macOS 버전 |
| `sample-availability` | `dropdown` | 예 | sample 문서 첨부 가능 여부 |
| `sample-file` | `upload` | 아니오 | 제거 가능한 경우 sample 문서 또는 캡처 |
| `extra-context` | `textarea` | 아니오 | 문서 생성 프로그램, 원본 환경 등 |

판단:

- `area:rendering`은 렌더링/표시 품질 문제를 받기 위한 기본 label이다.
- `area:test-assets`는 재현 문서나 fixture 관리가 거의 항상 필요하므로 함께 둔다.

### `03-quick-look-thumbnail.yml`

| 항목 | 값 |
|------|----|
| name | `Quick Look 또는 썸네일 문제` |
| description | Finder 미리보기, spacebar Quick Look, Finder thumbnail, extension 등록 문제 |
| title | `[Finder] ` |
| labels | `["bug", "area:quick-look", "area:thumbnail"]` |

입력 항목:

| id | type | 필수 | 용도 |
|----|------|------|------|
| `summary` | `textarea` | 예 | 문제 요약 |
| `affected-feature` | `dropdown` | 예 | Quick Look, thumbnail, 둘 다, extension 상태 진단 |
| `steps` | `textarea` | 예 | Finder에서 재현하는 절차 |
| `macos-version` | `input` | 예 | macOS 버전 |
| `app-version` | `input` | 예 | 앱 버전/빌드 |
| `install-source` | `dropdown` | 예 | DMG, Homebrew, source build 등 설치 경로 |
| `file-type` | `dropdown` | 예 | HWP/HWPX/기타 |
| `extension-diagnostics` | `textarea` | 아니오 | 앱 정보 창의 extension 상태, `qlmanage` 결과 등 |
| `attachments` | `upload` | 아니오 | Finder 캡처, sample 문서 |

판단:

- Quick Look과 thumbnail은 사용자가 구분하기 어려운 경우가 많으므로 하나의 템플릿으로 묶는다.
- 둘 중 하나만 해당해도 기본 label 2개가 모두 붙지만, triage 비용보다 사용자 선택 단순성이 더 중요하다.

### `04-feature-request.yml`

| 항목 | 값 |
|------|----|
| name | `기능 제안` |
| description | 새 기능, 사용 흐름 개선, macOS 통합 제안 |
| title | `[Feature] ` |
| labels | `["enhancement"]` |

입력 항목:

| id | type | 필수 | 용도 |
|----|------|------|------|
| `summary` | `textarea` | 예 | 제안 요약 |
| `problem` | `textarea` | 예 | 해결하려는 사용자 문제 |
| `proposed-solution` | `textarea` | 예 | 원하는 동작 |
| `alternatives` | `textarea` | 아니오 | 대안 또는 현재 workaround |
| `affected-area` | `dropdown` | 아니오 | 앱, Quick Look, thumbnail, 변환/자동화, 설치/업데이트 등 |
| `documents` | `textarea` | 아니오 | 관련 문서 유형 또는 예시 |

판단:

- 기능 제안은 영역이 다양하므로 area label은 기본으로 붙이지 않는다.
- `affected-area` dropdown으로 maintainer가 후속 label을 고르게 한다.

### `05-install-update-release.yml`

| 항목 | 값 |
|------|----|
| name | `설치·업데이트 문제` |
| description | DMG 설치, Homebrew Cask, Sparkle 업데이트, Gatekeeper, release asset 문제 |
| title | `[Install] ` |
| labels | `["bug", "area:ci-cd"]` |

입력 항목:

| id | type | 필수 | 용도 |
|----|------|------|------|
| `summary` | `textarea` | 예 | 문제 요약 |
| `install-source` | `dropdown` | 예 | GitHub Release DMG, Homebrew Cask, Sparkle update, source build |
| `app-version` | `input` | 예 | 설치/업데이트 대상 버전 |
| `macos-version` | `input` | 예 | macOS 버전 |
| `architecture` | `dropdown` | 아니오 | Apple Silicon, Intel, Universal 확인 불가 |
| `steps` | `textarea` | 예 | 설치/업데이트 절차와 실패 지점 |
| `message` | `textarea` | 아니오 | 표시된 오류 문구 또는 터미널 출력 |
| `attachments` | `upload` | 아니오 | 스크린샷, 로그 |

판단:

- 사용자 체감 문제이지만 원인 분석은 release/packaging/Homebrew/Sparkle 경로로 이어지므로 `area:ci-cd`가 맞다.

### `07-developer-task.yml`

| 항목 | 값 |
|------|----|
| name | `개발자 타스크 제안` |
| description | maintainer가 하이퍼-워터폴 타스크로 등록할 수 있는 개발 작업 초안 |
| title | `[Task] ` |
| labels | `["question"]` |

입력 항목:

| id | type | 필수 | 용도 |
|----|------|------|------|
| `workflow-note` | `markdown` | - | 실제 작업 시작은 `task-register`/`task-start` 승인 절차를 따른다는 안내 |
| `background` | `textarea` | 예 | 배경 |
| `goal` | `textarea` | 예 | 목표 |
| `scope` | `textarea` | 예 | 포함 범위 |
| `out-of-scope` | `textarea` | 예 | 제외 범위 |
| `affected-area` | `dropdown` | 아니오 | 후보 area |
| `milestone-candidate` | `input` | 아니오 | 후보 milestone |
| `labels-candidate` | `input` | 아니오 | 후보 label |
| `validation` | `textarea` | 아니오 | 예상 검증 |
| `references` | `textarea` | 아니오 | 관련 issue/PR/문서 |

판단:

- 개발자 타스크는 제품 기능, workflow, 문서, CI 등으로 갈릴 수 있어 area label을 기본으로 붙이면 오분류 위험이 크다.
- `question`으로 triage 필요 상태를 표시하고, 실제 이슈 등록/작업 시작은 기존 하이퍼-워터폴 승인 절차에 맡긴다.

### `08-regression.yml`

| 항목 | 값 |
|------|----|
| name | `회귀 제보` |
| description | 이전 버전이나 이전 커밋에서 되던 기능이 새 버전에서 깨진 문제 |
| title | `[Regression] ` |
| labels | `["bug", "kind:regression"]` |

입력 항목:

| id | type | 필수 | 용도 |
|----|------|------|------|
| `summary` | `textarea` | 예 | 회귀 요약 |
| `worked-before` | `input` | 예 | 정상 동작하던 마지막 버전/빌드/커밋 |
| `broken-now` | `input` | 예 | 문제가 발생한 버전/빌드/커밋 |
| `affected-surface` | `dropdown` | 예 | 앱, Quick Look, thumbnail, PDF export, install/update 등 |
| `steps` | `textarea` | 예 | 같은 절차로 비교 가능한 재현 단계 |
| `expected-result` | `textarea` | 예 | 이전 정상 동작 |
| `actual-result` | `textarea` | 예 | 현재 깨진 동작 |
| `macos-version` | `input` | 예 | macOS 버전 |
| `attachments` | `upload` | 아니오 | 이전/현재 비교 캡처, sample 문서, 로그 |

판단:

- area는 영향을 받은 표면에 따라 달라지므로 기본 label에는 넣지 않는다.
- 회귀 triage 핵심은 good/bad version 범위라서 `worked-before`, `broken-now`를 필수로 둔다.

## 공통 설계 규칙

- 모든 템플릿은 한국어 표시명을 사용한다.
- 모든 `id`는 ASCII kebab-case로 작성한다.
- `name`은 GitHub 표시 기준을 만족하도록 4자 이상으로 둔다.
- `labels`는 기존 label만 사용한다.
- `projects`, `assignees`, `type`은 이번 작업에서 사용하지 않는다.
- 사용자-facing template의 required 필드는 `summary`, 환경, 재현 또는 비교 정보 중심으로 제한한다.
- 민감정보와 보안 취약점은 public issue에 쓰지 말라는 안내를 `markdown` element로 제공한다.
- 문서 첨부가 필요한 템플릿은 `upload`를 선택 항목으로 두되, 개인정보 제거와 첨부 가능 여부를 먼저 묻는다.
- `config.yml`은 다음 최소 구조로 둔다.

```yaml
blank_issues_enabled: true
```

## Stage 1 판단

- 7개 필수 템플릿은 충분히 분리되어 있고, 사용자가 어느 흐름을 선택해야 하는지 template chooser에서 구분 가능하다.
- `06-question-support.yml`은 이번 필수 세트에서 제외한다. 빈 이슈를 허용하므로 간단한 질문은 blank issue로 받을 수 있고, 별도 질문 템플릿은 초기 유지 비용이 더 크다.
- `09-architecture-proposal.yml`, `10-docs.yml`도 필수 세트에서 제외한다. 구조 제안은 `07-developer-task.yml`, 문서 개선은 blank issue 또는 maintainer triage로 충분하다.
- `03-quick-look-thumbnail.yml`은 Quick Look과 thumbnail을 묶는 설계가 맞다. 사용자가 두 extension의 차이를 정확히 알 필요가 없고, `affected-feature`로 세부 구분을 받으면 된다.
- `07-developer-task.yml`은 실제 하이퍼-워터폴 이슈 생성 절차를 대체하지 않는다. 작업 시작은 계속 `task-register` 또는 `task-start` 승인 절차를 따른다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| GitHub Issue Forms 공식 문서 확인 | 완료 |
| GitHub form schema 공식 문서 확인 | 완료 |
| GitHub template chooser `config.yml` 문서 확인 | 완료 |
| 기존 label 목록 조회 | 완료. 새 label 없이 설계 가능 |
| `.github` 기존 템플릿 확인 | `.github/ISSUE_TEMPLATE/` 없음 |
| `git status --short --branch` | `local/task272`, Stage 1 작성 전 미커밋 변경 없음 |
| `git diff --check` | 보고서 작성 후 수행 예정 |

## 다음 단계 제안

Stage 2에서는 이 설계표를 기준으로 `.github/ISSUE_TEMPLATE/config.yml`과 7개 YAML Issue Form을 추가한다.

YAML 작성 시 특히 다음을 점검한다.

- 모든 form에 `name`, `description`, `title`, `labels`, `body`가 있는지 확인한다.
- `id`가 중복되지 않고 ASCII kebab-case인지 확인한다.
- `dropdown` options가 비어 있지 않은지 확인한다.
- `upload` element는 optional로만 둔다.
- `blank_issues_enabled: true`가 정확히 들어갔는지 확인한다.

## 승인 요청

Stage 1 설계와 label 매핑을 완료했다. 이 보고서 기준으로 Stage 2 Issue Template YAML 추가를 진행하려면 작업지시자 승인이 필요하다.
