# Task M013 #272 Stage 3 보고서

## 단계 목적

Stage 2에서 추가한 GitHub Issue Forms YAML 파일을 구조적으로 점검하고, 저장소 label 체계와 form label 참조가 일치하는지 검증했다.

이번 단계에서는 템플릿 보정이 필요하지 않아 `.github/ISSUE_TEMPLATE/` 파일은 수정하지 않았다.

## 검증 대상

| 파일 | 용도 |
|------|------|
| `.github/ISSUE_TEMPLATE/config.yml` | 빈 이슈 허용 설정 |
| `.github/ISSUE_TEMPLATE/01-user-bug.yml` | 앱 문제 제보 |
| `.github/ISSUE_TEMPLATE/02-document-compatibility.yml` | 문서 호환성 문제 |
| `.github/ISSUE_TEMPLATE/03-quick-look-thumbnail.yml` | Quick Look/thumbnail 문제 |
| `.github/ISSUE_TEMPLATE/04-feature-request.yml` | 기능 제안 |
| `.github/ISSUE_TEMPLATE/05-install-update-release.yml` | 설치/업데이트 문제 |
| `.github/ISSUE_TEMPLATE/07-developer-task.yml` | 개발자 타스크 제안 |
| `.github/ISSUE_TEMPLATE/08-regression.yml` | 회귀 제보 |

## 구조 검증

Ruby YAML parser와 추가 schema 점검 스크립트로 다음을 확인했다.

- `config.yml` 외 모든 form에 `name`, `description`, `body`가 존재한다.
- 모든 form의 `body`는 배열이다.
- form element `type`은 GitHub 문서의 허용 값인 `markdown`, `textarea`, `input`, `dropdown`, `checkboxes`, `upload` 안에 있다.
- `markdown` element는 `attributes.value`를 가진다.
- `markdown` 외 element는 고유한 ASCII `id`와 `attributes.label`을 가진다.
- 각 form 안에서 `id` 중복이 없다.
- 모든 `dropdown`은 비어 있지 않은 `options` 배열을 가진다.
- `validations.required`는 boolean 값이다.

검증 명령:

```bash
ruby -ryaml -e 'allowed=%w[markdown textarea input dropdown checkboxes upload]; Dir[".github/ISSUE_TEMPLATE/*.yml"].sort.each do |path| next if File.basename(path)=="config.yml"; data=YAML.load_file(path); missing=%w[name description body].reject { |k| data.key?(k) }; raise "#{path}: missing #{missing.join(",")}" unless missing.empty?; raise "#{path}: body must be array" unless data["body"].is_a?(Array); ids=[]; data["body"].each_with_index do |item,i|; type=item["type"]; raise "#{path}: invalid type #{type.inspect} at #{i}" unless allowed.include?(type); attrs=item["attributes"] || {}; raise "#{path}: attributes must be map at #{i}" unless attrs.is_a?(Hash); if type=="markdown"; raise "#{path}: markdown value missing at #{i}" unless attrs["value"].is_a?(String) && !attrs["value"].empty?; else; id=item["id"]; raise "#{path}: missing id at #{i}" unless id.is_a?(String) && id.match?(/\A[A-Za-z0-9_-]+\z/); ids << id; raise "#{path}: label missing at #{i}" unless attrs["label"].is_a?(String) && !attrs["label"].empty?; end; if type=="dropdown"; opts=attrs["options"]; raise "#{path}: dropdown options missing at #{i}" unless opts.is_a?(Array) && !opts.empty?; end; if item.key?("validations"); v=item["validations"]; raise "#{path}: validations must be map at #{i}" unless v.is_a?(Hash); if v.key?("required"); raise "#{path}: required must be boolean at #{i}" unless [true,false].include?(v["required"]); end; end; end; seen={}; dupes=[]; ids.each { |id| seen[id] ? dupes << id : seen[id]=true }; raise "#{path}: duplicate ids #{dupes.uniq.join(",")}" unless dupes.empty?; end; puts "schema-ok"'
```

결과: `schema-ok`

로컬 Ruby가 `Ignoring ffi-1.13.1 because its extensions are not built` 경고를 출력했지만, YAML parse와 구조 검증 자체는 성공했다.

## label 대조

Issue Form에서 참조하는 label은 다음 10개다.

```text
area:ci-cd
area:quick-look
area:rendering
area:test-assets
area:thumbnail
area:viewer-app
bug
enhancement
kind:regression
question
```

`gh api repos/postmelee/alhangeul-macos/labels --paginate --jq '.[].name'`로 확인한 저장소 label 목록에 위 10개가 모두 존재한다.

따라서 이번 작업은 새 label을 만들지 않는다는 제외 범위를 지켰다.

## required field 점검

각 form의 required field 수는 다음과 같다.

| 파일 | required field 수 | 전체 body element 수 | 판단 |
|------|------------------:|--------------------:|------|
| `01-user-bug.yml` | 5 | 9 | 일반 앱 문제 triage에 필요한 최소 환경과 재현 정보 |
| `02-document-compatibility.yml` | 8 | 11 | 문서 호환성 문제 특성상 기대/실제 결과와 sample 제공 여부가 필요 |
| `03-quick-look-thumbnail.yml` | 7 | 9 | Finder extension 문제 재현에 필요한 설치/파일/환경 정보 |
| `04-feature-request.yml` | 3 | 6 | 제안 요약, 문제, 원하는 동작만 필수 |
| `05-install-update-release.yml` | 5 | 8 | 설치 경로, 버전, macOS, 재현 절차 중심 |
| `07-developer-task.yml` | 4 | 10 | 배경, 목표, 포함, 제외 범위만 필수 |
| `08-regression.yml` | 8 | 9 | good/bad version, 영향 표면, 비교 절차가 회귀 triage 핵심 |

Stage 3 판단으로는 required field가 과도한 수준은 아니다. `02-document-compatibility.yml`과 `08-regression.yml`은 필수 항목이 많지만, 두 템플릿은 재현성과 비교 기준이 없으면 triage가 어렵기 때문에 현재 구성을 유지한다.

## template chooser 정렬

파일명은 두 자리 숫자 prefix를 사용한다.

```text
01-user-bug.yml
02-document-compatibility.yml
03-quick-look-thumbnail.yml
04-feature-request.yml
05-install-update-release.yml
07-developer-task.yml
08-regression.yml
```

`06-question-support.yml`은 Stage 1 판단대로 제외했다. 빈 이슈를 허용하므로 간단한 질문은 blank issue로 받을 수 있다.

## 기타 검증 결과

| 검증 | 결과 |
|------|------|
| `ruby -e 'require "yaml"; ARGV.each { \|f\| YAML.load_file(f) }; puts "ok"' .github/ISSUE_TEMPLATE/*.yml` | 통과 |
| `rg -n "labels: \\[\|labels:\|validations:\|required: true\|type: dropdown\|type: textarea\|type: checkboxes" .github/ISSUE_TEMPLATE` | 확인 완료 |
| `find .github/ISSUE_TEMPLATE -maxdepth 1 -type f -print \| sort` | config 1개, form 7개 확인 |
| `git diff --check` | 통과 |
| `git status --short --branch` | Stage 3 보고서 작성 전 clean |

## Stage 3 판단

- YAML parse, form 구조, id 중복, dropdown options, required field, label 참조 모두 현재 기준에서 문제 없다.
- GitHub UI 렌더링 자체는 로컬에서 완전히 검증할 수 없으므로 PR 게시 후 template chooser에서 최종 확인해야 한다.
- Stage 4에서는 최종 보고서에 이 잔여 확인 항목을 명시하고, 오늘할일 상태를 완료로 갱신하면 된다.

## 승인 요청

Stage 3 구조 검증과 템플릿 품질 점검을 완료했다. 이 보고서 기준으로 Stage 4 최종 검증과 보고를 진행하려면 작업지시자 승인이 필요하다.
