# Issue #45 Stage 4 완료 보고서

## 단계 목적

`.agents/skills`(Codex 인식)와 `.claude/skills`(Claude Code 인식)를 `mydocs/skills` 진실 원천으로 향하는 심볼릭 링크로 만든다. 두 링크를 git에 mode `120000`으로 커밋해 양 도구가 동일한 SKILL.md 본문을 인식하도록 한다.

## 산출물

| 경로 | 형태 | 대상 | git mode | git object hash |
|------|------|------|----------|-----------------|
| `.agents/skills` | symlink | `../mydocs/skills` | `120000` | `d1fe2f5ad8f296c8dd1932d69a837a1bc5032415` |
| `.claude/skills` | symlink | `../mydocs/skills` | `120000` | `d1fe2f5ad8f296c8dd1932d69a837a1bc5032415` |

두 링크의 git object hash가 동일하다 → 같은 대상을 가리키는 식별 가능한 동일 심볼릭 링크.

위치 정책 안내는 Stage 1에서 [`document_structure_guide.md`](../manual/document_structure_guide.md) 마지막 섹션 "Agent Skills 위치 정책"에 선반영되었으므로 본 단계에서 추가 매뉴얼 변경은 없다.

## 양 경로 인식 검증

```
--- skill access via both paths ---
agents ok task-start
claude ok task-start
agents ok task-stage-report
claude ok task-stage-report
agents ok task-final-report
claude ok task-final-report
agents ok pr-merge-cleanup
claude ok pr-merge-cleanup
agents ok external-pr-review
claude ok external-pr-review
```

`.agents/skills/{name}/SKILL.md`와 `.claude/skills/{name}/SKILL.md` 둘 다에서 5종 모두 접근 가능.

## 도구 인식 실측에 대한 책임 분담

본 단계는 파일 시스템 + git 추적 단위 인식까지만 보장한다. CLI 단위의 실제 인식은 도구 세션을 새로 시작해야 측정 가능하므로 다음 항목은 작업지시자 또는 후속 세션에서 사람 검증 항목으로 남긴다.

- Codex CLI: `codex` 또는 `/skills` 메뉴에서 5종 노출 여부
- Claude Code: 새 세션 시스템 프롬프트의 user-invocable skills 목록에 5종 노출 여부

이 두 항목은 Stage 5 최종 보고서 "잔여 위험과 후속 작업"에 명시한다.

## 검증 결과

```
--- ls -la ---
lrwxr-xr-x@ 1 melee  staff  16 Apr 25 21:44 .agents/skills -> ../mydocs/skills
lrwxr-xr-x@ 1 melee  staff  16 Apr 25 21:44 .claude/skills -> ../mydocs/skills

--- git ls-files modes ---
120000 d1fe2f5ad8f296c8dd1932d69a837a1bc5032415 0	.agents/skills
120000 d1fe2f5ad8f296c8dd1932d69a837a1bc5032415 0	.claude/skills

--- diff check ---
diff-check ok
```

## 잔여 위험

- 일부 CI/CD 환경 또는 zip 기반 배포에서 심볼릭 링크가 일반 파일로 변환되거나 누락될 수 있다. 본 저장소는 GitHub Actions·로컬 macOS 운영 환경 위주이므로 현재 영향 없음. 추후 Windows/zip 배포 도입 시 재검토.
- 양 도구 모두 `.agents/skills`·`.claude/skills`를 디렉터리로 인식하지만, 일부 미래 버전이 실제 디렉터리만 허용하도록 변경될 가능성은 낮다 (현재 표준상 심볼릭 링크 허용).

## 다음 단계 영향

Stage 5에서 통합 검증, 최종 보고서 작성, 오늘할일 #45 완료 처리 후 PR 직전 상태로 정리한다.

## 승인 요청

Stage 5(최종 검증과 보고서) 진입 승인 요청.
