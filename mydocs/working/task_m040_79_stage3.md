# Task M040 #79 Stage 3 완료보고서

## 단계 목적

기존 릴리스/배포 진입점인 `release_distribution_guide.md`에서 Stage 2에 작성한 `public_release_runbook.md`를 찾을 수 있게 연결했다. 정책 설명은 기존 가이드와 하위 매뉴얼에 유지하고, 실제 public release 당일의 실행 순서와 승인 gate는 runbook을 우선하도록 역할을 구분했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/manual/release_distribution_guide.md` | 하위 매뉴얼 표에 `public_release_runbook.md` 추가, 전체 release flow 앞에 runbook 우선 안내 추가 |
| `mydocs/manual/public_release_runbook.md` | 제목을 `메인테이너용 public release 실행 runbook`으로 보정해 검색성과 역할 명확화 |
| `mydocs/working/task_m040_79_stage3.md` | Stage 3 완료보고서 |

## 변경 내용

- `release_distribution_guide.md`의 하위 매뉴얼 표 첫 항목에 `public_release_runbook.md`를 추가했다.
- 전체 release flow 섹션 앞에 실제 public release 실행 지시를 받으면 runbook으로 최신 release context와 승인 gate를 먼저 확정한다는 문장을 추가했다.
- 기존 최종 체크리스트는 그대로 두고, 체크리스트는 누락 방지 기준이며 배포일 단계별 실행 순서는 runbook을 우선한다고 역할을 구분했다.
- `public_release_runbook.md` 제목을 한국어 문서 맥락에 맞게 `메인테이너용 public release 실행 runbook`으로 보정했다.

## 본문 변경 정도 / 본문 무손실 여부

기존 가이드의 정책, 체크리스트, rollback 절차는 삭제하거나 재작성하지 않았다. 링크와 역할 안내만 추가했으며, Stage 2 runbook 본문도 제목 외 내용은 변경하지 않았다.

## 검증 결과

### 연결 검색

```bash
rg -n "public_release_runbook|public release 실행 runbook|메인테이너용" mydocs/manual/release_distribution_guide.md mydocs/manual/public_release_runbook.md
```

결과: 통과.

```text
mydocs/manual/public_release_runbook.md:1:# 메인테이너용 public release 실행 runbook
mydocs/manual/release_distribution_guide.md:22:| [`public_release_runbook.md`](public_release_runbook.md) | ...
mydocs/manual/release_distribution_guide.md:74:실제 public release 실행 지시를 받으면 먼저 ...
```

### whitespace 검증

```bash
git diff --check
```

결과: 통과. whitespace 오류 없음.

## 잔여 위험

- `release_distribution_guide.md`의 기존 최종 체크리스트와 새 runbook은 일부 항목을 공통으로 다룬다. 현재는 역할을 구분했지만, 향후 release policy가 바뀌면 두 문서의 표현이 함께 갱신되어야 한다.
- `public_release_runbook.md`는 Stage 4에서 secret 금지 문자열과 placeholder 사용을 한 번 더 확인해야 한다.

## 다음 단계 영향

Stage 4에서는 runbook과 연결 문서의 최종 검증을 수행한다. 특히 링크, workflow input 이름, Homebrew gate, rollback 항목, secret 미기록 원칙을 확인하고 최종 결과보고서와 오늘할일 완료 처리를 진행한다.

## 승인 요청

Stage 3 완료 결과를 검토한 뒤 Stage 4 최종 문서 검증과 보고 진행 승인을 요청한다.
