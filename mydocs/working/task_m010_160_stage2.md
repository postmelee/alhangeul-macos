# Task #160 Stage 2 보고서

## 단계 목적

Stage 1 조사 결과를 바탕으로 WKWebView 첫 출시 라인과 native renderer 실험 라인의 브랜치 전략을 `mydocs/tech/branch_strategy_webview_native.md`에 진실 원천으로 정리한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/tech/branch_strategy_webview_native.md` | 브랜치별 역할, 단기 운영안, 장기 rename 후보, release PR 체크리스트, PR base 기준, 자동화 점검 항목 정리 |
| `mydocs/working/task_m010_160_stage2.md` | Stage 2 작성 결과와 검증 결과 정리 |
| `mydocs/orders/20260506.md` | Task #160 상태를 Stage 2 보고 승인 대기로 갱신 |

## 작성 내용

tech 문서에는 다음 결정을 명시했다.

- `main`은 release/tag 기준 브랜치로 유지한다.
- `devel-webview`는 v0.1.x 첫 public release 준비 기준 브랜치로 유지한다.
- `devel`은 native viewer renderer와 장기 native viewer 실험/통합 브랜치로 유지한다.
- 첫 출시 전에는 branch rename을 하지 않는다.
- `devel-webview -> main`은 release PR로 반영하고, tag/GitHub Release는 `main` 기준으로 만든다.
- 외부 기여 PR은 작업 범위에 따라 `devel-webview` 또는 `devel`을 base로 고른다.

## 판단 근거

Stage 1에서 확인한 remote-tracking 상태를 문서에 반영했다.

| 비교 | left 전용 | right 전용 | 반영 |
|------|-----------|------------|------|
| `origin/main...origin/devel-webview` | 6 | 232 | release PR에서 main 전용 README/banner 변경 보존 여부 확인 필요 |
| `origin/devel...origin/devel-webview` | 22 | 69 | `devel`과 `devel-webview`를 당장 합치거나 rename하지 않고 역할 분리 유지 |

첫 출시 전 branch rename을 보류하는 이유도 명시했다.

- 출시 전 rename은 PR base, branch protection, review instruction, 문서 링크, 자동화 filter를 동시에 흔든다.
- v0.1.x의 우선 위험은 브랜치 이름보다 release artifact, 설치본 smoke, fallback, license/provenance 정합성이다.
- `devel`에는 native renderer 전용 작업이 남아 있어 출시 기준과 섞지 않는 편이 명확하다.

## 검증 결과

실행 명령:

```bash
rg -n 'devel-webview|devel|main|PR base|통합 브랜치|출시 대상' \
  mydocs/tech/branch_strategy_webview_native.md
git diff --check -- mydocs/tech/branch_strategy_webview_native.md mydocs/working/task_m010_160_stage2.md
```

결과:

- `rg`로 tech 문서 안의 `devel-webview`, `devel`, `main`, PR base, 통합 브랜치, 출시 대상 표현을 확인했다.
- `git diff --check` 통과. 출력 없음.

## 잔여 위험

- Stage 2는 tech 문서 신규 작성만 수행했으므로 README, CONTRIBUTING, `.github`, 운영 매뉴얼의 실제 불일치 문구는 아직 남아 있다.
- GitHub branch protection/default branch, CI/release workflow filter는 문서 점검 항목으로만 남겼고 실제 설정 변경은 수행하지 않았다.
- `devel-webview`와 `devel` 이름 혼동 리스크는 해소하지 않고 출시 후 후속 판단으로 남겼다.

## 다음 단계 영향

Stage 3에서는 이 tech 문서를 기준으로 README, CONTRIBUTING, `.github/copilot-instructions.md`, `release_distribution_guide.md`, `document_structure_guide.md` 등 운영 문서를 정합화한다.

## 승인 요청

Stage 2 tech 문서 작성은 완료했다. 이 보고서 기준으로 Stage 3 README/CONTRIBUTING/운영 문서 정합화에 진입할지 승인 요청한다.
