# Task #71 Stage 4 — 작은 표현 개선과 19개 문서 최종 정합성 확인

## 단계 목적

마지막 4개 표현 개선(D1~D4)을 적용하고, Task #71의 모든 점검 대상(A/B/C/D 4개 분류, 20개 항목)이 closed 상태인지 19개 문서 전수 검증으로 확인한다.

## 산출물

### D1 — README 아키텍처 링크 섹션 분리

`v2.0.0` 이정표 마지막 bullet 직후, 아키텍처 링크 줄 앞에 `---` 추가.

```diff
- Codex Plugin 또는 Claude Code 연동 도구로 packaging
+
+---

자세한 구조와 bridge 정책은 [아키텍처 문서](mydocs/tech/project_architecture.md)를 참조하세요.
```

링크가 v2.0.0 단계의 detail이 아니라 "이정표" 섹션 전체의 마무리 포인터임을 시각적으로 분리.

### D2 — PR 템플릿 placeholder 명시

`task_m000_0` 4곳을 `task_m{milestone}_{issue}` placeholder로 교체하고, 주석에 placeholder 설명 추가.

```diff
- 표시는 raw URL 대신 `[파일명](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/...)` 형식으로 적습니다.
- 해당 없는 항목은 삭제합니다.
+ 표시는 raw URL 대신 `[파일명](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/...)` 형식으로 적습니다.
+ 아래 `{head_sha}`, `{milestone}`, `{issue}`는 placeholder입니다. 실제 commit SHA, 마일스톤(`m100` 등), 이슈 번호로 치환하세요. 해당 없는 항목은 삭제합니다.

- - 수행 계획서: [task_m000_0.md](https://.../task_m000_0.md)
+ - 수행 계획서: [task_m{milestone}_{issue}.md](https://.../task_m{milestone}_{issue}.md)
```

`m000`은 `document_structure_guide.md:26`에서 사용 금지된 표기이므로 placeholder 형식으로 교체.

### D3 — `git_workflow_guide.md` 다이어그램 단순화

병렬 task를 한 다이어그램에 합쳐 화살표가 모호하던 구조를 단일 task 흐름으로 단순화. 병렬은 본문에서 한 줄 안내.

```diff
-local/task{N}  ──커밋──커밋──┐
-local/task{N+1}──커밋──커밋──┤
-                              ├─→ publish/task{N} push
-                              │
-                              ├─→ devel 대상 PR 생성 + 리뷰 + merge
-                              │
-                              ├─→ devel 누적
-                              │
-                              ├─→ main PR 생성 + 리뷰 + merge + 태그 (릴리즈 시점)

+local/task{N} ── 커밋 · 커밋 · 커밋 ──→ publish/task{N} push
+                                          │
+                                          └─→ devel 대상 PR → 리뷰 → merge
+                                                                       │
+                                                                       └─→ devel 누적
+                                                                              │
+                                                                              └─→ main PR (릴리즈 시점) → 태그
+
+병렬 task는 각각 독립적인 `local/task{N}` 브랜치로 위 흐름을 반복한다.
```

### D4 — README "타스크 진행 절차" 압축

6단계 산문 → 한 줄 흐름 + `task_workflow_guide.md` 링크.

```diff
-1. `gh issue create` → GitHub Issue 등록
-2. `origin/devel` 기준으로 `local/task{issue번호}` 브랜치 생성
-3. 수행계획서 작성 → 구현 계획서 작성 → 구현 → 검증
-4. 단계별 완료 보고서와 최종 보고서 작성
-5. `publish/task{issue번호}`로 push 후 ... draft PR 생성
-6. PR merge 후 ... 원격 브랜치 정리

+이슈 → 브랜치 → 오늘할일 → 수행계획서 → 구현계획서 → 구현 → 검증 → 단계 보고 → 최종 보고 → PR 게시 → merge 후 정리.
+
+15단계 상세, 승인 게이트, 커밋 메시지 규칙은 [`task_workflow_guide.md`](mydocs/manual/task_workflow_guide.md)를 참고하세요.
```

README 6단계와 매뉴얼 15단계의 단계 수 불일치 혼선 해소. README는 흐름만, 상세는 매뉴얼.

## 본문 변경 정도

- D1, D2, D3, D4 모두 표면적 표현/구조 개선. 의미 변경 없음.
- D2의 placeholder 형식은 매뉴얼 규칙(`task_{milestone}_{이슈번호}`)과 일치하도록 통일.
- 정보 손실 없음.

## 검증 결과

```text
=== Stage 4 자체 검증 ===
git status:           3 files modified (.github/pull_request_template.md, README.md, mydocs/manual/git_workflow_guide.md)
git diff --check:     ok
D1: README ---:       ok (separator 추가)
D2: m000 제거:        ok (4개 placeholder로 교체)
D3: N+1 다이어그램:   ok (단순화)
D4: 6단계 산문:       ok (1줄 + 링크)

=== Task #71 전체 19개 점검 대상 최종 정합성 ===
A1 submodule wording:                 ok
A2 mydocs/feedback dir:               ok
A3 pr_process_guide link:             ok
A4 CONTRIBUTING.md:                   ok
B1 tech link in 4 docs:               4 (모두 링크 정상)
B2 README mydocs 트리만 + 링크:       ok (Stage 2 검증 완료)
B3 README architecture 링크:          ok (3회 등장)
B4 README/release smoke test 링크:    ok (build_run_guide로 통합)
C1 swift_macos function names:        ok (제거)
C2 troubleshootings 신규:             ok (build_run_guide에서 링크)
C3 ASCII roadmap:                     ok (인라인으로 교체)
C4 sample_provenance:                 ok (삭제)
C5 확정된 기준 분리:                  ok (2 섹션)
C6 core 가이드 rename:                ok (운영 문서 stale ref 0건)
D1 README architecture 분리:          ok
D2 PR template placeholder:           ok
D3 git diagram 단순화:                ok
D4 README 타스크 진행 절차 압축:      ok

=== Code safety net ===
./scripts/check-no-appkit.sh:         OK: shared Swift code has no AppKit/UIKit dependencies
```

20개 항목 모두 closed. 운영 문서/매뉴얼/아키텍처 stale 참조 0건. 코드 무영향 보장.

## 잔여 위험

- devel branch가 본 task 시작 이후 8 commit 진행됨 (현재 4 ahead, 8 behind). PR 시점에 충돌 여부 사전 확인 필요. 대부분 운영 문서/매뉴얼 변경이라 코드 충돌 가능성은 낮으나, 동기간 다른 task에서 같은 README/AGENTS 영역을 수정했다면 merge conflict 발생 가능. `task-final-report` skill 진입 전 `git fetch + git log origin/devel ^local/task71`로 영향 범위 확인 후 진행.
- `mydocs/feedback/` 폴더는 빈 상태(.gitkeep만). 향후 첫 피드백 문서가 들어오면 .gitkeep 제거 정책 별도 결정.

## 다음 단계 영향

- 모든 단계 완료. `task-final-report` skill로 최종 보고서 작성, `publish/task71` push, devel 대상 draft PR 생성으로 진행.
- PR 본문은 `.github/pull_request_template.md`(본 단계에서 placeholder 정정된 새 양식) 기준으로 작성.

## 승인 요청

- 본 단계와 Task #71 전체 결과 검토 후 `task-final-report` skill 진입 승인 (최종 보고서 작성 + PR 생성)
