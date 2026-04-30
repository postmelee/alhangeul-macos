# Issue #102 구현 계획서

수행계획서: `mydocs/plans/task_m010_102.md`

## 작업명

Copilot 자동 코드 리뷰 설정

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_102.md`를 기준으로 진행한다.
- Copilot 지시사항은 공식 저장소 경로인 `.github/copilot-instructions.md`에 둔다.
- Copilot Code Review가 instruction 파일 앞 4,000자만 읽는 제약을 고려해 리뷰에 필요한 핵심 가드레일을 앞부분에 압축한다.
- GitHub Ruleset은 Copilot 자동 리뷰 rule만 갖는 독립 ruleset으로 추가한다.
- 기존 `protect-main` ruleset은 이번 작업에서 수정하지 않는다.
- 자동 리뷰 대상은 `devel`과 `main`으로 설정한다.
- `review_on_push`는 true, `review_draft_pull_requests`는 false로 둔다.
- Swift/Rust/Xcode 소스 변경이 아니므로 Xcode/Rust 빌드 검증은 수행하지 않는다.

## Stage 1: Copilot Code Review 지시사항 작성

대상:

- `.github/copilot-instructions.md`
- `mydocs/working/task_m010_102_stage1.md`

작업:

1. `.github/copilot-instructions.md`를 신규 작성한다.
2. 리뷰 언어와 우선순위를 명시한다.
   - 한국어 리뷰
   - correctness, runtime regression, FFI/memory safety, architecture boundary, build/release reproducibility, missing verification 우선
   - 칭찬/요약/style-only 코멘트 최소화
3. 저장소 아키텍처 규칙을 압축한다.
   - `project.yml`이 Xcode project 원본
   - `Frameworks/` 산출물과 `rhwp-core.lock` 정합성
   - `Sources/RhwpCoreBridge`의 AppKit/UIKit 금지
   - Swift/Rust FFI 포인터/길이/수명/해제 규칙
   - core dependency pin 정책
4. 렌더링, Quick Look, Thumbnail, HostApp 검토 기준을 적는다.
5. PR workflow와 검증 기대치를 적는다.
6. Stage 1 단계 보고서를 작성한다.

산출물:

- `.github/copilot-instructions.md`
- `mydocs/working/task_m010_102_stage1.md`

검증:

```bash
test -f .github/copilot-instructions.md
wc -c .github/copilot-instructions.md
rg -n "Korean|RhwpCoreBridge|AppKit|UIKit|FFI|project.yml|rhwp-core.lock|devel" .github/copilot-instructions.md
git diff --check -- .github/copilot-instructions.md mydocs/working/task_m010_102_stage1.md
```

완료 조건:

- `.github/copilot-instructions.md`가 존재한다.
- 지시사항이 4,000자 이내 또는 앞 4,000자 안에 핵심 규칙이 모두 들어간다.
- 리뷰 우선순위, 아키텍처 경계, FFI 안전성, 검증 기대치가 포함된다.

커밋:

```text
Task #102 Stage 1: Copilot 리뷰 지시사항 작성
```

## Stage 2: GitHub Copilot 자동 리뷰 Ruleset 설정

대상:

- GitHub repository ruleset: `copilot-code-review`
- `mydocs/working/task_m010_102_stage2.md`

작업:

1. 기존 ruleset 목록을 조회해 같은 이름의 ruleset이 있는지 확인한다.
2. 기존 `copilot-code-review` ruleset이 없으면 새 ruleset을 생성한다.
3. ruleset 조건은 branch target의 `devel`, `main`을 포함한다.
4. ruleset rule은 `copilot_code_review`만 포함한다.
5. parameters를 다음 기준으로 설정한다.
   - `review_on_push: true`
   - `review_draft_pull_requests: false`
6. 생성 결과를 조회해 id, enforcement, target, conditions, rules를 확인한다.
7. Stage 2 단계 보고서를 작성한다.

예상 API payload:

```json
{
  "name": "copilot-code-review",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/devel", "refs/heads/main"],
      "exclude": []
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
  ],
  "bypass_actors": []
}
```

산출물:

- 원격 ruleset `copilot-code-review`
- `mydocs/working/task_m010_102_stage2.md`

검증:

```bash
gh api repos/postmelee/alhangeul-macos/rulesets \
  --jq '.[] | select(.name == "copilot-code-review") | {id,name,target,enforcement}'
gh api repos/postmelee/alhangeul-macos/rulesets/{ruleset_id} \
  --jq '{name,target,enforcement,conditions,rules}'
git diff --check -- mydocs/working/task_m010_102_stage2.md
```

완료 조건:

- `copilot-code-review` ruleset이 `active` 상태로 존재한다.
- target이 `branch`이고 대상 branch에 `devel`, `main`이 포함된다.
- rules에 `copilot_code_review`가 존재하고 `review_on_push` true, `review_draft_pull_requests` false다.
- 기존 `protect-main` ruleset은 변경하지 않는다.

커밋:

```text
Task #102 Stage 2: Copilot 자동 리뷰 Ruleset 설정
```

## Stage 3: 통합 검증과 최종 보고

대상:

- `.github/copilot-instructions.md`
- GitHub repository ruleset `copilot-code-review`
- `mydocs/orders/20260430.md`
- `mydocs/working/task_m010_102_stage3.md`
- `mydocs/report/task_m010_102_report.md`

작업:

1. Copilot 지시사항 파일의 핵심 키워드와 크기를 확인한다.
2. GitHub API로 ruleset 최종 상태를 확인한다.
3. `git diff --check`를 실행한다.
4. 오늘할일 상태를 완료로 갱신하고 완료 시각을 기록한다.
5. 최종 결과 보고서를 작성한다.
6. Stage 3 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_102_stage3.md`
- `mydocs/report/task_m010_102_report.md`
- 갱신된 `mydocs/orders/20260430.md`

검증:

```bash
test -f .github/copilot-instructions.md
wc -c .github/copilot-instructions.md
rg -n "Korean|RhwpCoreBridge|AppKit|UIKit|FFI|project.yml|rhwp-core.lock|review_on_push|review_draft_pull_requests" \
  .github/copilot-instructions.md \
  mydocs/working/task_m010_102_stage2.md \
  mydocs/report/task_m010_102_report.md
gh api repos/postmelee/alhangeul-macos/rulesets/{ruleset_id} \
  --jq '{name,target,enforcement,conditions,rules}'
git diff --check
git status --short
```

완료 조건:

- Copilot custom instructions 파일이 커밋되어 있다.
- Copilot 자동 리뷰 ruleset이 GitHub 원격에 활성화되어 있다.
- 최종 보고서와 오늘할일 완료 처리가 끝난다.
- working tree가 clean이고 PR 게시 승인 요청이 가능하다.

커밋:

```text
Task #102 Stage 3 + 최종 보고서: Copilot 자동 리뷰 설정 통합 보고
```

## 단계별 커밋 메시지

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #102 Stage 1: Copilot 리뷰 지시사항 작성` |
| 2 | `Task #102 Stage 2: Copilot 자동 리뷰 Ruleset 설정` |
| 3 | `Task #102 Stage 3 + 최종 보고서: Copilot 자동 리뷰 설정 통합 보고` |

## 후속 작업

- Stage 3 완료 후 작업지시자 승인 시 `task-final-report` 절차로 `publish/task102` push와 draft PR 생성을 진행한다.
- PR merge 후 정리는 `pr-merge-cleanup` 절차로 수행한다.

## 승인 요청 사항

이 구현 계획서 3단계 구성으로 Stage 1 진입을 승인 요청한다.
