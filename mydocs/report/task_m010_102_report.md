# Issue #102 최종 결과 보고서

## 요약

GitHub Copilot 자동 코드 리뷰를 저장소에 적용하기 위한 두 축을 구성했다.

- Copilot Code Review 저장소 지시사항 `.github/copilot-instructions.md`를 추가했다.
- GitHub repository ruleset `copilot-code-review`를 생성해 `devel`과 `main` 대상 PR에 자동 리뷰를 활성화했다.
- 자동 리뷰는 새 push마다 다시 실행되도록 `review_on_push: true`로 설정했다.
- draft PR 리뷰는 quota와 중간 산출물 노이즈를 줄이기 위해 `review_draft_pull_requests: false`로 설정했다.

## 단계별 결과

| Stage | 결과 | 커밋 |
|-------|------|------|
| Stage 1 | Copilot Code Review 지시사항 작성 | `ba956fa` |
| Stage 2 | GitHub 자동 리뷰 ruleset 생성 | `c916307` |
| Stage 3 | 통합 검증, 오늘할일 완료 처리, 최종 보고 | `dc8ba8a` |

## 주요 산출물

| 대상 | 내용 |
|------|------|
| `.github/copilot-instructions.md` | 한국어 리뷰 지시, 아키텍처 경계, FFI 안전성, core pin, 렌더링/extension 검증 기준 |
| GitHub ruleset `copilot-code-review` | `devel`/`main` 대상 Copilot 자동 리뷰 활성화 |
| `mydocs/working/task_m010_102_stage1.md` | 지시사항 작성 보고 |
| `mydocs/working/task_m010_102_stage2.md` | ruleset 생성 보고 |
| `mydocs/working/task_m010_102_stage3.md` | 통합 검증 보고 |

## Copilot 지시사항 내용

`.github/copilot-instructions.md`에는 다음 리뷰 기준을 압축해 넣었다.

- 리뷰 코멘트는 한국어로 작성
- correctness, runtime regression, FFI/memory safety, architecture boundary, build/release reproducibility, missing verification 우선
- `project.yml`이 Xcode 설정 원본임을 확인
- `Frameworks/` 생성 산출물, `rhwp-core.lock`, `RustBridge/Cargo.lock`, `rhwp-ffi-symbols.txt` 정합성 확인
- `Sources/RhwpCoreBridge`에서 AppKit/UIKit 직접 의존 금지
- Swift/Rust FFI의 null pointer, pointer/length, 해제 함수, handle lifetime 규칙 확인
- Stable/Demo core dependency pin 정책 확인
- renderer, Quick Look, Thumbnail, HostApp 검증 포인트 확인
- 실제 수행한 검증만 PR 본문에 적도록 요구

## GitHub Ruleset 설정

생성된 ruleset:

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
        "review_draft_pull_requests": false,
        "review_on_push": true
      }
    }
  ]
}
```

기존 `protect-main` ruleset은 수정하지 않았다. Stage 2 검증에서 id `15445649`, enforcement `disabled`, rules `deletion`, `non_fast_forward` 상태가 유지됨을 확인했다.

## 검증

실행한 명령:

```bash
test -f .github/copilot-instructions.md
wc -c .github/copilot-instructions.md
rg -n "Korean|RhwpCoreBridge|AppKit|UIKit|FFI|project.yml|rhwp-core.lock|review_on_push|review_draft_pull_requests" \
  .github/copilot-instructions.md \
  mydocs/working/task_m010_102_stage2.md \
  mydocs/report/task_m010_102_report.md
gh api repos/postmelee/alhangeul-macos/rulesets/15754724 \
  --jq '{name,target,enforcement,conditions,rules}'
git diff --check
```

결과:

- `.github/copilot-instructions.md` 존재 확인
- 파일 크기 `3485` bytes
- 필수 키워드 확인
- ruleset `copilot-code-review` active 확인
- branch include `refs/heads/devel`, `refs/heads/main` 확인
- `copilot_code_review` rule 확인
- `review_on_push: true`, `review_draft_pull_requests: false` 확인
- `git diff --check` 통과

Swift/Rust/Xcode 소스 변경이 아니므로 `xcodebuild`, Rust bridge build, render smoke test는 수행하지 않았다.

## 남은 리스크

- GitHub ruleset은 이미 원격에서 활성화됐지만, `.github/copilot-instructions.md`는 이 변경이 `devel`에 merge된 뒤부터 `devel` 대상 PR의 base branch 지시사항으로 안정적으로 사용된다.
- `main` 대상 PR에서도 custom instructions를 안정적으로 사용하려면 이후 `devel` 변경이 `main`으로 반영되어야 한다.
- Copilot 자동 리뷰 실행 여부는 PR 작성자의 Copilot Code Review 접근 권한과 premium request quota에 영향을 받을 수 있다.

## 결론

Issue #102의 목표였던 Copilot 자동 코드 리뷰 ruleset 설정과 저장소 전용 코드 리뷰 프롬프트 작성은 완료됐다. PR merge 후에는 이후 `devel` 대상 PR에서 저장소 고유 가드레일을 반영한 Copilot 리뷰를 받을 수 있다.
