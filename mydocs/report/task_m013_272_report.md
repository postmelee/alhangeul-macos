# Task M013 #272 최종 결과보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#272](https://github.com/postmelee/alhangeul-macos/issues/272) |
| 마일스톤 | M013 — 하이퍼-워터폴 작업환경 조성 |
| 작업명 | GitHub Issue Forms 기반 사용자·개발자 이슈 템플릿 추가 |
| 단계 수 | 4단계 |
| 최종 PR base 판단 | `devel` |

이번 작업은 알한글 사용자와 개발자가 GitHub Issue를 열 때 목적에 맞는 구조화된 입력 양식을 선택할 수 있도록 Issue Forms 필수 세트를 추가한 작업이다.

공개 사용자 접근성을 유지하기 위해 빈 이슈는 허용했다. 보안 취약점 접수 경로, Discussions 정책, GitHub repository settings, PR template, 제품 Swift/Rust 코드는 변경하지 않았다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| task-start | `e4cec99` | #272 수행계획서와 오늘할일을 작성했다. |
| 구현계획 | `45b5acb` | Stage 1-4 구현계획서를 작성했다. |
| Stage 1 | `0883918` | GitHub Issue Forms 문법, 기존 label 체계, 7개 템플릿 설계와 label 매핑을 확정했다. |
| Stage 2 | `6a3cd6c` | `.github/ISSUE_TEMPLATE/`에 config와 7개 Issue Form YAML을 추가했다. |
| Stage 3 | `2d06fcb` | YAML 구조, id 중복, dropdown options, required field, label 참조를 검증했다. |
| Stage 4 | 최종 커밋 | 최종 검증, 결과보고서, 오늘할일 완료 처리를 수행했다. |

## 추가된 Issue Forms

| 파일 | 대상 | 용도 | 기본 label |
|------|------|------|------------|
| `.github/ISSUE_TEMPLATE/01-user-bug.yml` | 사용자 | 앱 실행, 파일 열기, 저장, 공유, PDF 내보내기 등 일반 앱 문제 | `bug`, `area:viewer-app` |
| `.github/ISSUE_TEMPLATE/02-document-compatibility.yml` | 사용자 | 특정 HWP/HWPX 문서의 열기, 표시, 저장, 내보내기 호환성 문제 | `bug`, `area:rendering`, `area:test-assets` |
| `.github/ISSUE_TEMPLATE/03-quick-look-thumbnail.yml` | 사용자 | Finder Quick Look preview, thumbnail, extension 등록 문제 | `bug`, `area:quick-look`, `area:thumbnail` |
| `.github/ISSUE_TEMPLATE/04-feature-request.yml` | 사용자/개발자 | 새 기능, 사용 흐름 개선, macOS 통합 제안 | `enhancement` |
| `.github/ISSUE_TEMPLATE/05-install-update-release.yml` | 사용자 | DMG, Homebrew, Sparkle, Gatekeeper, release asset 문제 | `bug`, `area:ci-cd` |
| `.github/ISSUE_TEMPLATE/07-developer-task.yml` | 개발자/관리자 | 하이퍼-워터폴 타스크로 등록할 수 있는 개발 작업 초안 | `question` |
| `.github/ISSUE_TEMPLATE/08-regression.yml` | 사용자/테스터 | 이전 버전 또는 이전 커밋 대비 회귀 제보 | `bug`, `kind:regression` |

## 빈 이슈 설정

`.github/ISSUE_TEMPLATE/config.yml`은 사용자 요청에 따라 다음처럼 설정했다.

```yaml
blank_issues_enabled: true
```

따라서 GitHub template chooser에서 일반 사용자도 빈 이슈를 선택할 수 있다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `.github/ISSUE_TEMPLATE/config.yml` | 빈 이슈 허용 설정 |
| `.github/ISSUE_TEMPLATE/01-user-bug.yml` | 앱 문제 제보 form |
| `.github/ISSUE_TEMPLATE/02-document-compatibility.yml` | 문서 호환성 문제 form |
| `.github/ISSUE_TEMPLATE/03-quick-look-thumbnail.yml` | Quick Look/thumbnail 문제 form |
| `.github/ISSUE_TEMPLATE/04-feature-request.yml` | 기능 제안 form |
| `.github/ISSUE_TEMPLATE/05-install-update-release.yml` | 설치/업데이트 문제 form |
| `.github/ISSUE_TEMPLATE/07-developer-task.yml` | 개발자 타스크 제안 form |
| `.github/ISSUE_TEMPLATE/08-regression.yml` | 회귀 제보 form |
| `mydocs/plans/task_m013_272.md` | 수행계획서 |
| `mydocs/plans/task_m013_272_impl.md` | 구현계획서 |
| `mydocs/working/task_m013_272_stage1.md` | Stage 1 설계 보고서 |
| `mydocs/working/task_m013_272_stage2.md` | Stage 2 YAML 추가 보고서 |
| `mydocs/working/task_m013_272_stage3.md` | Stage 3 구조 검증 보고서 |
| `mydocs/report/task_m013_272_report.md` | 최종 결과보고서 |
| `mydocs/orders/20260519.md` | #272 오늘할일 완료 처리 |

## 변경 전·후 정량 비교

| 항목 | 결과 |
|------|------|
| 최종 보고서 작성 전 커밋 수 | 5개 |
| 최종 보고서 작성 전 변경 파일 수 | 14개 |
| 최종 보고서 작성 전 diff stat | 1325 insertions |
| Issue Form 추가 수 | 7개 |
| Issue template config 추가 수 | 1개 |
| 새 label 생성 | 없음 |
| 코드 변경 | 없음 |
| workflow 변경 | 없음 |
| repository setting 변경 | 없음 |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| YAML parse 가능 | OK | `ruby -e 'require "yaml"; ARGV.each { \|f\| YAML.load_file(f) }; puts "ok"' .github/ISSUE_TEMPLATE/*.yml` 통과 |
| form 구조 유효성 | OK | Stage 3 schema 점검에서 top-level key, 허용 type, id 중복, dropdown options, required boolean 확인 |
| blank issue 허용 | OK | `.github/ISSUE_TEMPLATE/config.yml`의 `blank_issues_enabled: true` 확인 |
| 기존 label만 사용 | OK | `gh api repos/postmelee/alhangeul-macos/labels --paginate --jq '.[].name'`와 form label 대조 |
| 문서 whitespace 문제 없음 | OK | `git diff --check` 통과 |
| 변경 범위 준수 | OK | `.github/ISSUE_TEMPLATE/`와 하이퍼-워터폴 문서만 변경 |

로컬 Ruby 실행 시 `Ignoring ffi-1.13.1 because its extensions are not built` 경고가 출력되었지만, YAML parse와 구조 검증은 정상 완료했다. 이 경고는 이번 YAML 파일의 유효성과 직접 관련 없는 로컬 gem 상태 경고다.

## 잔여 위험과 후속 확인

| 항목 | 처리 |
|------|------|
| GitHub UI template chooser 렌더링 | 로컬에서 완전히 검증할 수 없으므로 PR 게시 후 GitHub UI에서 7개 form과 blank issue 노출 확인 필요 |
| Issue Forms public preview 성격 | GitHub form schema 변경 가능성이 있으므로 PR 이후 GitHub UI 오류가 있으면 즉시 보정 |
| required field 부담 | Stage 3에서 과도하지 않다고 판단했지만, 실제 사용자 제보가 줄거나 incomplete report가 늘면 후속 조정 |
| Security vulnerability 접수 경로 | 이번 범위에서 제외. 필요 시 별도 `SECURITY.md` 또는 GitHub Security Advisory 작업으로 분리 |
| 질문/문서/아키텍처 별도 템플릿 | 이번 필수 세트에서 제외. 빈 이슈와 개발자 타스크 제안 form으로 우선 대응 |

## PR 게시 준비

| 항목 | 값 |
|------|----|
| 작업 브랜치 | `local/task272` |
| 게시 브랜치 | `publish/task272` |
| PR base | `devel` |
| PR 제목 후보 | `Add GitHub Issue Forms for users and developers` |

PR 본문에는 추가된 템플릿 목록, 빈 이슈 허용 설정, YAML/label 검증 결과, PR 이후 GitHub UI 확인 필요 사항을 포함하면 된다.

## 작업지시자 승인 요청

최종 결과보고서 작성과 오늘할일 완료 처리를 마쳤다. 이 보고서 기준으로 `publish/task272` 원격 브랜치 push와 `devel` 대상 Open PR 생성을 진행하려면 작업지시자 승인이 필요하다.
