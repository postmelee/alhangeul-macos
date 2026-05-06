# Task #160 Stage 3 보고서

## 단계 목적

Stage 2에서 작성한 `mydocs/tech/branch_strategy_webview_native.md`를 기준으로 README, CONTRIBUTING, GitHub review instruction, 운영 매뉴얼의 브랜치 정책 표현을 정합화한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `README.md` | `devel-webview`를 v0.1.x 출시 우선 통합 브랜치로 명확히 하고 tech 문서 링크 추가 |
| `CONTRIBUTING.md` | PR base 선택 안내에 tech 문서 링크 추가 |
| `.github/copilot-instructions.md` | `devel` 단일 PR target 문구를 `devel-webview` 기본, native renderer는 `devel` 기준으로 수정 |
| `mydocs/manual/release_distribution_guide.md` | 브랜치 전략 문서 링크 추가, rollback 수정 PR base를 출시 대상 통합 브랜치 기준으로 수정 |
| `mydocs/manual/document_structure_guide.md` | 관련 매뉴얼 설명을 `devel-webview`/`devel` 분리 운용으로 수정 |
| `mydocs/manual/git_workflow_guide.md` | 브랜치 전략 문서 링크 추가 |
| `mydocs/manual/pr_process_guide.md` | 브랜치 전략 문서 링크 추가 |
| `mydocs/working/task_m010_160_stage3.md` | Stage 3 변경과 검증 결과 정리 |
| `mydocs/orders/20260506.md` | Task #160 상태를 Stage 3 보고 승인 대기로 갱신 |

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 기존 브랜치 정책을 뒤집지 않고, Stage 2 tech 문서를 진실 원천으로 연결하는 문서 보정이다.

- README/CONTRIBUTING은 기존 PR base 요약을 유지하고 링크와 v0.1.x 표현만 보강했다.
- `.github/copilot-instructions.md`의 충돌 문구는 실제 정책에 맞게 교체했다.
- release rollback 절차는 `devel` 고정 표현을 제거하고 출시 대상 통합 브랜치 기준으로 바꿨다.
- core dependency 관련 branch/floating ref 문맥은 수정하지 않았다.

## 검증 결과

실행 명령:

```bash
rg -n 'PRs normally target `devel`|수정 PR을 `devel`|`devel` 브랜치 운용' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
rg -n 'branch_strategy_webview_native|devel-webview|native viewer renderer|출시 대상 통합 브랜치' \
  README.md CONTRIBUTING.md .github mydocs/manual mydocs/tech
git diff --check
```

결과:

- 첫 번째 `rg`는 출력 없음. 기존 충돌 문구가 남아 있지 않다.
- 두 번째 `rg`는 README, CONTRIBUTING, `.github`, release/pr/git/document workflow, tech 문서의 관련 표현을 확인했다.
- `git diff --check` 통과. 출력 없음.

## 잔여 위험

- GitHub branch protection, default branch, CI/release workflow branch filter는 문서 점검 항목으로만 남아 있고 실제 설정 변경은 하지 않았다.
- `devel-webview`/`devel` 이름 혼동 리스크는 문서화했지만 rename 자체는 첫 출시 후 후속 판단으로 남아 있다.
- Stage 4에서 전체 검색을 다시 실행해 의도치 않은 `devel` 단일 기준 문구가 남았는지 재확인해야 한다.

## 다음 단계 영향

Stage 4에서는 전체 문서 검색과 diff 검증을 반복하고, 최종 보고서와 오늘할일 완료 처리를 진행한다.

## 승인 요청

Stage 3 문서 정합화는 완료했다. 이 보고서 기준으로 Stage 4 문서 검증과 최종 정리에 진입할지 승인 요청한다.
