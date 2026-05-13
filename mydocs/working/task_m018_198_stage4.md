# Task M018 #198 Stage 4 완료 보고서

## 단계 목적

PR CI, release rehearsal, release publish, rhwp upstream check의 역할과 실행 경계를 문서화하고, 실패 시 로컬에서 필요한 컨텍스트만 읽어 재현할 수 있게 manual entrypoint를 정리했다.

## 변경 요약

### `ci_workflow_guide.md` 추가

새 문서 [`ci_workflow_guide.md`](../manual/ci_workflow_guide.md)를 추가했다.

주요 내용:

- workflow별 trigger, 권한, runner, 역할
- PR CI의 `pull_request` 기준과 secrets 미사용 원칙
- `classify-pr-changes.sh` flag와 job mapping
- docs-only skip 기준
- macOS validation 로컬 재현 명령
- release checks 로컬 재현 명령
- `Release Rehearsal DMG`의 입력과 artifact/summary 위치
- `Release Publish DMG`의 보호 조건, 입력, artifact/summary 위치
- `rhwp Upstream Release Check`의 역할과 로컬 재현 명령
- 실패 해석 기준과 troubleshooting 분리 기준

### release manual entrypoint 보강

[`release_distribution_guide.md`](../manual/release_distribution_guide.md)를 entrypoint 역할에 맞게 보강했다.

- 하위 매뉴얼 표에 `ci_workflow_guide.md`를 추가했다.
- 현재 release 자산에 PR CI, release rehearsal/publish workflow, `classify-pr-changes.sh`를 추가했다.
- 전체 release flow에 CI guide 확인, rehearsal workflow, `previous_release_ref`와 delta checklist artifact 확인을 반영했다.
- 최종 체크리스트에 PR CI 또는 동등한 로컬 검증 확인과 workflow delta checklist summary/artifact 확인을 추가했다.

### 세부 release guide 연결

[`release_github_pages_sparkle_guide.md`](../manual/release_github_pages_sparkle_guide.md):

- delta checklist가 workflow에서 생성될 때의 입력, candidate ref, artifact 이름을 추가했다.
- 두 release workflow가 `GITHUB_STEP_SUMMARY`에 previous/candidate ref와 checklist path를 남긴다는 기준을 기록했다.

[`release_packaging_dmg_guide.md`](../manual/release_packaging_dmg_guide.md):

- `Release Rehearsal DMG` workflow 입력과 결과 artifact를 추가했다.
- `previous_release_ref` 확인 기준을 rehearsal DMG section에 연결했다.

### 기타 링크 보강

- [`README.md`](../../README.md)의 Checks 섹션에 CI workflow guide 링크를 추가했다.
- [`document_structure_guide.md`](../manual/document_structure_guide.md)의 릴리즈 매뉴얼 분리 정책에 CI workflow guide를 추가했다.

## 검증 결과

```bash
git status --short --branch
```

결과: `local/task198`에서 Stage 4 문서 변경만 존재함을 확인했다.

```bash
rg -n "PR CI|docs-only|classify-pr-changes|HostApp Debug|release rehearsal|release publish|rhwp upstream|pull_request|workflow_dispatch|environment: release|delta checklist" mydocs/manual README.md .github/workflows
```

결과 요약:

- `PR CI`, `pull_request`, `classify-pr-changes`, `HostApp Debug`, docs-only 기준이 `ci_workflow_guide.md`와 workflow에서 검색된다.
- `workflow_dispatch`, `environment: release`, release rehearsal/publish, delta checklist가 release workflow와 manual에서 검색된다.
- `rhwp upstream` 기준이 upstream check workflow와 `ci_workflow_guide.md`에서 검색된다.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

```bash
perl -ne 'print "$ARGV:$.:$_" if /[ \t]$/; close ARGV if eof' mydocs/manual/ci_workflow_guide.md mydocs/manual/release_distribution_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/release_packaging_dmg_guide.md mydocs/manual/document_structure_guide.md README.md
```

결과: 출력 없음, exit code 0.

## 다음 단계 영향

이슈 #198의 계획된 구현 단계는 Stage 4까지다. 다음 단계에서는 전체 변경 검토, 최종 검증, 최종 보고서 작성, PR 게시 절차로 넘어가야 한다. 최종 보고와 PR 게시 시점에는 `task-final-report` Skill을 명시 호출해 진행한다.

## 승인 요청

Stage 4 산출물 승인을 요청한다.

승인 후 최종 검증과 최종 보고서/PR 게시 준비로 진행한다.
