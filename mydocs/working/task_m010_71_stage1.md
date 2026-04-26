# Task #71 Stage 1 — 사실 오류와 깨진 참조 정정

## 단계 목적

devel → main merge 전 점검에서 식별된 4개 사실 오류/깨진 참조(A1~A4)를 일괄 정정해 v0.1.0 운영 문서 세트의 명백한 오정보를 제거한다.

## 산출물

| 항목 | 파일 | 변경 종류 | 비고 |
|------|------|----------|------|
| A1 | `THIRD_PARTY_LICENSES.md` | 1줄 수정 | "git submodule" → "Cargo git dependency from `RustBridge/Cargo.toml`" |
| A2 | `mydocs/feedback/.gitkeep` | 신규 (empty) | 4개 문서가 절차상 참조하는 폴더 활성화 |
| A3 | `mydocs/manual/pr_process_guide.md` | 1줄 수정 | "AGENTS.md의 Git 워크플로우" → `[git_workflow_guide.md]` 직접 참조 |
| A4 | `CONTRIBUTING.md` | 신규 (243줄) | edwardkim/rhwp 포맷 참고, 본 프로젝트 기준으로 적응 |

`CONTRIBUTING.md` 섹션:
- 처음 참여하시나요? (Releases 안내, 개발 환경 10분 가이드, 첫 기여 찾기)
- 기여 방법 (버그 리포트, Fork & PR 워크플로우, PR 전 체크리스트, HWP 샘플 제공)
- 브랜치 규칙 (`git_workflow_guide.md` 링크)
- 디버깅 가이드 (`validate-stage3-render.sh`, `render-debug-compare.sh`, `qlmanage`)
- 프로젝트 구조 (Sources/RustBridge/Frameworks/scripts/mydocs 트리)
- 코드 스타일 (`check-no-appkit.sh`, FFI 안전성, `project.yml` 원본 정책)
- 문서 작성 규칙 (`mydocs/` 폴더 표, 파일명 규칙, 기여자 작성 범위)
- HWPUNIT 참고
- 라이선스 (MIT)

## 본문 변경 정도

- A1, A3: 단일 라인 수정으로 본문 무손실. 의미만 정정.
- A2: 신규 빈 폴더 (`.gitkeep` 추가로 git 추적). 기존 문서 본문 무수정.
- A4: 신규 파일. 기존 README L492의 깨진 `[CONTRIBUTING.md](CONTRIBUTING.md)` 링크가 자동으로 해소됨 (README 본문 무수정).

## 검증 결과

```text
=== git status ===
 M THIRD_PARTY_LICENSES.md
 M mydocs/manual/pr_process_guide.md
?? CONTRIBUTING.md
?? mydocs/feedback/

=== git diff --check ===
diff ok

=== A1: submodule wording ===
ok

=== A1: new wording ===
5:This project uses `rhwp` as a Cargo git dependency from `RustBridge/Cargo.toml`.

=== A2: feedback dir ===
ok

=== A2: gitkeep ===
ok

=== A3: stale reference removed ===
ok

=== A3: new link ===
7:브랜치 흐름과 merge 전략은 [`git_workflow_guide.md`](git_workflow_guide.md)를 따른다.

=== A4: CONTRIBUTING.md exists ===
ok

=== A4: README link target now exists ===
492:See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
```

모든 검증 통과. 깨진 참조 0건, 신규 파일/폴더 정상 생성, 새 링크 정상 작동 확인.

## 잔여 위험

- `CONTRIBUTING.md`의 본 프로젝트 기준 명령(`xcodebuild`, `pluginkit` 등)이 향후 README 변경 시 이 파일과 분기될 가능성. Stage 4 최종 정합성 확인에서 README와 `CONTRIBUTING.md`의 핵심 명령이 일치하는지 cross-check.
- `mydocs/feedback/`은 폴더만 생성. 향후 실제 피드백 문서가 들어왔을 때 `.gitkeep`은 제거 또는 유지 정책을 별도로 결정. 현 시점에는 4개 문서의 절차 참조가 깨지지 않게 하는 것이 목표.

## 다음 단계 영향

- Stage 2의 B1~B4 중복 정리에서 `CONTRIBUTING.md`는 진실 원천 후보가 아님(`README.md` 보완 위치). Stage 2는 `CONTRIBUTING.md`를 직접 변경하지 않는다.
- Stage 3의 C6 rename(`core_submodule_operation_guide.md` → `core_dependency_operation_guide.md`)은 본 단계 결과와 독립적. 본 단계가 만든 파일은 rename 영향 없음.

## 승인 요청

- 본 단계 결과 검토 후 Stage 2(B1~B4 중복 설명 정리) 진입 승인
- A2 `mydocs/feedback/.gitkeep` 처리 방식이 적절한지 확인 (다른 방식 선호 시 Stage 2 진입 전에 변경 가능)
