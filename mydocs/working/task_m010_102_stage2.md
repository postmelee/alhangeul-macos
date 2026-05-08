# Issue #102 Stage 2 완료 보고서

## 목적

GitHub repository ruleset에 Copilot 자동 코드 리뷰 rule을 추가해 `devel`과 `main` 대상 PR에 Copilot 리뷰가 자동 요청되도록 설정한다.

## 변경 요약

- GitHub repository ruleset `copilot-code-review`를 생성했다.
- ruleset target은 `branch`, enforcement는 `active`로 설정했다.
- 대상 브랜치는 `refs/heads/devel`, `refs/heads/main`으로 제한했다.
- rule은 `copilot_code_review` 하나만 추가했다.
- `review_on_push`는 `true`, `review_draft_pull_requests`는 `false`로 설정했다.
- 기존 `protect-main` ruleset은 수정하지 않았다.

## API 실행 기록

처음에는 `gh api -F 'rules[][type]=...'` 형태로 생성 요청을 시도했으나 rules 배열이 두 항목으로 해석되어 GitHub API가 422를 반환했다.

```text
Invalid property /rules/1: data matches no possible input.
```

이후 JSON payload를 명시 파일로 만든 뒤 `--input` 방식으로 생성했다.

```bash
gh api repos/postmelee/alhangeul-macos/rulesets \
  --method POST \
  --input /private/tmp/copilot-ruleset-task102.json \
  --jq '{id,name,target,enforcement,conditions,rules}'
```

생성 결과:

```json
{
  "id": 15754724,
  "name": "copilot-code-review",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "exclude": [],
      "include": ["refs/heads/devel", "refs/heads/main"]
    }
  },
  "rules": [
    {
      "type": "copilot_code_review",
      "parameters": {
        "review_on_push": true,
        "review_draft_pull_requests": false
      }
    }
  ]
}
```

## 검증

실행 명령:

```bash
gh api repos/postmelee/alhangeul-macos/rulesets \
  --jq '.[] | select(.name == "copilot-code-review") | {id,name,target,enforcement}'
gh api repos/postmelee/alhangeul-macos/rulesets/15754724 \
  --jq '{name,target,enforcement,conditions,rules}'
gh api repos/postmelee/alhangeul-macos/rulesets/15445649 \
  --jq '{id,name,target,enforcement,conditions,rules}'
```

결과:

- `copilot-code-review`: id `15754724`, target `branch`, enforcement `active`
- 상세 조건: include `refs/heads/devel`, `refs/heads/main`, exclude `[]`
- rule: `copilot_code_review`
- parameters: `review_on_push: true`, `review_draft_pull_requests: false`
- 기존 `protect-main`: id `15445649`, enforcement `disabled`, rules `deletion`, `non_fast_forward` 유지

## 산출물

| 대상 | 내용 |
|------|------|
| GitHub ruleset `copilot-code-review` | Copilot 자동 리뷰 원격 설정 |
| `mydocs/working/task_m010_102_stage2.md` | Stage 2 완료 보고서 |

## 다음 단계

Stage 3에서는 `.github/copilot-instructions.md`와 GitHub ruleset 최종 상태를 통합 검증하고 최종 결과 보고서를 작성한다.
