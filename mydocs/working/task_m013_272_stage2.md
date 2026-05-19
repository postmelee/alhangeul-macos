# Task M013 #272 Stage 2 보고서

## 단계 목적

Stage 1에서 확정한 설계에 따라 GitHub Issue Forms YAML 파일을 추가했다.

이번 단계에서는 `.github/ISSUE_TEMPLATE/` 아래 config와 7개 form을 만들었고, GitHub repository setting, label, milestone, PR template, 제품 코드는 변경하지 않았다.

## 추가 파일

| 파일 | 용도 | 기본 label |
|------|------|------------|
| `.github/ISSUE_TEMPLATE/config.yml` | template chooser 설정, 빈 이슈 허용 | - |
| `.github/ISSUE_TEMPLATE/01-user-bug.yml` | 일반 앱 문제 제보 | `bug`, `area:viewer-app` |
| `.github/ISSUE_TEMPLATE/02-document-compatibility.yml` | 특정 HWP/HWPX 문서 호환성 문제 | `bug`, `area:rendering`, `area:test-assets` |
| `.github/ISSUE_TEMPLATE/03-quick-look-thumbnail.yml` | Finder Quick Look/thumbnail 문제 | `bug`, `area:quick-look`, `area:thumbnail` |
| `.github/ISSUE_TEMPLATE/04-feature-request.yml` | 기능 제안 | `enhancement` |
| `.github/ISSUE_TEMPLATE/05-install-update-release.yml` | 설치, 업데이트, release asset 문제 | `bug`, `area:ci-cd` |
| `.github/ISSUE_TEMPLATE/07-developer-task.yml` | 개발자 타스크 제안 초안 | `question` |
| `.github/ISSUE_TEMPLATE/08-regression.yml` | 이전 버전 대비 회귀 제보 | `bug`, `kind:regression` |

## config 설정

`config.yml`은 사용자 요청에 맞춰 빈 이슈를 허용하는 최소 설정으로 추가했다.

```yaml
blank_issues_enabled: true
```

contact link는 추가하지 않았다. Security vulnerability 접수 경로와 Discussions 정책은 이번 작업의 제외 범위이기 때문이다.

## Issue Form 구성

모든 form에는 다음 top-level key를 포함했다.

- `name`
- `description`
- `title`
- `labels`
- `body`

공통 작성 원칙은 다음과 같이 적용했다.

- 표시 문구는 한국어로 작성했다.
- `id`는 모두 ASCII kebab-case로 작성했다.
- `labels`는 Stage 1에서 확인한 기존 label만 사용했다.
- `projects`, `assignees`, `type`은 사용하지 않았다.
- 사용자-facing 템플릿의 required 필드는 문제 요약, 환경, 재현 또는 비교 정보 중심으로 제한했다.
- 실제 파일 첨부는 모두 optional `upload`로 두었다.
- 민감정보와 보안 취약점 안내는 markdown element로 제공했다.

## 템플릿별 입력 항목

| 템플릿 | 필수 입력 핵심 | 선택 입력 |
|--------|----------------|-----------|
| 앱 문제 제보 | 문제 요약, 재현 절차, macOS 버전, 앱 버전, 설치 경로 | 파일 형식, 첨부 자료, 추가 맥락 |
| 문서 호환성 문제 | 문제 요약, 문서 형식, 영향 표면, 기대/실제 결과, 앱/macOS 버전, sample 제공 가능 여부 | sample 파일, 추가 맥락 |
| Quick Look 또는 썸네일 문제 | 문제 요약, 영향 기능, Finder 재현 절차, macOS/app 버전, 설치 경로, 파일 형식 | extension 진단 정보, 첨부 자료 |
| 기능 제안 | 제안 요약, 해결하려는 문제, 원하는 동작 | 대안, 관련 영역, 문서 유형 |
| 설치·업데이트 문제 | 문제 요약, 설치/업데이트 경로, 앱/macOS 버전, 절차 | Mac 아키텍처, 오류 메시지, 첨부 자료 |
| 개발자 타스크 제안 | 배경, 목표, 포함 범위, 제외 범위 | 후보 영역, milestone, label, 검증, 참고 링크 |
| 회귀 제보 | 회귀 요약, 정상 동작 버전, 문제 발생 버전, 영향 표면, 재현 절차, 이전/현재 동작, macOS 버전 | 첨부 자료 |

## 검증 결과

| 검증 | 결과 |
|------|------|
| `ruby -e 'require "yaml"; ARGV.each { \|f\| YAML.load_file(f) }; puts "ok"' .github/ISSUE_TEMPLATE/*.yml` | 통과. 로컬 `ffi` gem 경고가 있었지만 YAML parse는 `ok` |
| `rg -n "name:\|description:\|title:\|labels:\|body:\|blank_issues_enabled" .github/ISSUE_TEMPLATE` | 통과. 7개 form의 top-level key와 config 설정 확인 |
| `find .github/ISSUE_TEMPLATE -maxdepth 1 -type f -print \| sort` | 통과. config 1개와 form 7개 확인 |
| `git diff --check` | 통과 |

## Stage 2 판단

- Stage 1 설계의 7개 필수 템플릿을 모두 YAML 파일로 반영했다.
- 빈 이슈 허용 요청은 `blank_issues_enabled: true`로 반영했다.
- 사용자-facing 템플릿은 지나치게 많은 required field를 피하되 triage에 필요한 환경과 재현 정보는 필수로 받도록 구성했다.
- 개발자 타스크 제안 템플릿은 `question` label만 붙여 maintainer triage 흐름으로 남겼고, 실제 하이퍼-워터폴 절차를 대체하지 않는다는 안내를 포함했다.
- Stage 3에서는 GitHub form schema 관점의 세부 구조, dropdown options, required field, label 참조를 한 번 더 점검한다.

## 다음 단계 제안

Stage 3에서 다음을 수행한다.

1. 모든 Issue Form YAML의 구조를 다시 parse한다.
2. `id`, `attributes`, `validations`, dropdown options 구성이 일관되는지 확인한다.
3. label 참조가 기존 label과 정확히 일치하는지 조회 결과와 대조한다.
4. required field가 과도하지 않은지 사용자-facing 템플릿을 다시 읽어 보정한다.

## 승인 요청

Stage 2 Issue Template YAML 추가를 완료했다. 이 보고서 기준으로 Stage 3 구조 검증과 템플릿 품질 점검을 진행하려면 작업지시자 승인이 필요하다.
