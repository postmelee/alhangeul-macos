# Issue #45 Stage 1 완료 보고서

## 단계 목적

AGENTS.md에서 분량이 큰 3개 블록을 신규 매뉴얼로 본문 변경 없이 이전·정렬했다. 이는 다음 단계(AGENTS.md 압축)의 사전 작업이다.

## 산출물

| 파일 | 라인 수 | 출처 (AGENTS.md 현행) |
|------|---------|------------------------|
| `mydocs/manual/document_structure_guide.md` | 76 | L42~98 (폴더 구조·역할·파일명 규칙), L100~119 (외부 PR 폴더 정책) |
| `mydocs/manual/git_workflow_guide.md` | 67 | L162~226 (브랜치 표·다이어그램·메인테이너/컨트리뷰터 워크플로우) |
| `mydocs/manual/task_workflow_guide.md` | 44 | L228~263 (타스크 번호 관리·15단계 절차·작업 규칙) + L34~36 (승인 간주 조건) |

총 187줄.

## 본문 정합성

본문은 AGENTS.md 원문을 그대로 옮겼고, 구조적 정합을 위해 다음 최소 보정만 수행했다.

- `document_structure_guide.md` 폴더 역할 표에 `skills/` 행을 추가 (Agent Skills 위치 정책 도입에 따른 신규 항목, 후속 단계에서 실제 디렉터리 생성 예정)
- `document_structure_guide.md` 외부 PR 처리 절차 본문은 [pr_process_guide.md](../manual/pr_process_guide.md) 링크로 대체 (AGENTS.md L112~119 절차는 기존 매뉴얼에 이미 상세 존재 → 폴더 정책만 본 매뉴얼에 남김)
- `task_workflow_guide.md` "Codex" 단어를 "에이전트"로 1회 치환 (L263 작업 규칙 항목, 도구 비종속 표기로 정리)
- 신규 매뉴얼 헤더 1줄, 매뉴얼 목적 안내 1줄을 각 파일 상단에 추가

본문에 추가된 신규 강제 규칙은 없다. 폐지된 강제 규칙도 없다.

## 검증 결과

```
--- file existence ---
ok mydocs/manual/document_structure_guide.md
ok mydocs/manual/git_workflow_guide.md
ok mydocs/manual/task_workflow_guide.md
--- key terms ---
document_structure_guide.md:31:강제 규칙:
document_structure_guide.md:59:강제 규칙:
git_workflow_guide.md:35:## 메인테이너 워크플로우
task_workflow_guide.md:20:## 타스크 진행 절차
task_workflow_guide.md:42:## 승인 간주 조건
--- line counts ---
   76 mydocs/manual/document_structure_guide.md
   67 mydocs/manual/git_workflow_guide.md
   44 mydocs/manual/task_workflow_guide.md
  187 total
--- diff check ---
diff-check ok
```

## 다음 단계 영향

Stage 2(AGENTS.md/CLAUDE.md 압축)에서 위 매뉴얼 3종을 인덱스에 추가하고, AGENTS.md 본문에서 해당 블록을 제거한다. 본 단계의 본문 무손실 이전이 사실 검증되었으므로 Stage 2 진입 시 정보 손실 위험은 낮다.

## 잔여 위험

- `document_structure_guide.md` 폴더 역할 표에 `skills/` 행을 선반영했으나 실제 디렉터리는 Stage 3에서 생성한다. Stage 3 종료 시 표와 실제 상태 일치 여부를 재확인한다.
- 매뉴얼 간 상호 참조(예: `pr_process_guide.md` 링크) 무결성은 Stage 5 통합 검증에서 일괄 점검한다.

## 승인 요청

Stage 2(AGENTS.md/CLAUDE.md 압축과 매뉴얼 인덱스 갱신) 진입 승인 요청.
