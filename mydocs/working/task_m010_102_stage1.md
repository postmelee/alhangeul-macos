# Issue #102 Stage 1 완료 보고서

## 목적

Copilot Code Review가 이 저장소의 핵심 코드 리뷰 기준을 읽을 수 있도록 `.github/copilot-instructions.md`를 작성한다.

## 변경 요약

- `.github/copilot-instructions.md`를 신규 추가했다.
- 첫 문장에 리뷰 코멘트는 한국어로 작성하도록 명시했다.
- 리뷰 우선순위를 correctness, runtime regression, FFI/memory safety, architecture boundary, build/release reproducibility, missing verification 중심으로 정리했다.
- `project.yml` 원본 정책, `RhwpCoreBridge` AppKit/UIKit 금지, Rust FFI 수명/해제 규칙, core dependency pin 정책을 포함했다.
- 렌더링, Quick Look, Thumbnail, HostApp, PR workflow, 검증 기대치를 압축했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `.github/copilot-instructions.md` | Copilot Code Review 저장소 지시사항 |
| `mydocs/working/task_m010_102_stage1.md` | Stage 1 완료 보고서 |

## 검증

실행 명령:

```bash
test -f .github/copilot-instructions.md
wc -c .github/copilot-instructions.md
rg -n "Korean|RhwpCoreBridge|AppKit|UIKit|FFI|project.yml|rhwp-core.lock|devel" .github/copilot-instructions.md
git diff --check -- .github/copilot-instructions.md mydocs/working/task_m010_102_stage1.md
```

결과:

- `test -f .github/copilot-instructions.md`: 통과
- `wc -c .github/copilot-instructions.md`: `3485`
- `rg -n ... .github/copilot-instructions.md`: 필수 키워드 확인
- `git diff --check -- ...`: 통과

## 결과

- `.github/copilot-instructions.md`는 Copilot Code Review가 읽는 저장소 지시사항 경로에 생성됐다.
- 지시사항은 4,000자 제한을 고려해 핵심 리뷰 기준을 앞부분에 배치했다.
- Swift/Rust/Xcode 소스 변경은 없으므로 빌드 검증은 수행하지 않는다.

## 다음 단계

Stage 2에서는 GitHub repository ruleset `copilot-code-review`를 생성하고 `copilot_code_review` rule을 활성화한다.
