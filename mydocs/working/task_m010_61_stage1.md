# Issue #61 Stage 1 완료 보고서

## 단계명

merged PR 문서 링크 전수 조사

## 작업 요약

최근 merged PR 100건 조회 기준으로 실제 반환된 27개 PR 본문을 조사했다. 저장소 내부 문서 링크는 `github.com/postmelee/alhangeul-macos/blob/{40자 SHA}/mydocs/...` 패턴으로 추출했고, 문서 섹션의 raw URL 표시와 상대/비클릭 `mydocs/` 경로를 별도로 확인했다.

이번 단계에서는 원격 PR 본문을 수정하지 않았다.

## 조사 범위

| 항목 | 결과 |
|------|------|
| 조회 대상 | merged PR 27건 |
| 고정 blob 문서 링크가 있는 PR | 18건 |
| 고정 blob 문서 링크 수 | 98건 |
| 존재하지 않는 40자 SHA | 1개 |
| 문서 섹션 raw URL 노출 PR | 1건 |
| 문서 섹션 상대/비클릭 `mydocs/` 경로 | 0건 |

고정 blob 문서 링크가 있는 PR:

| PR | 링크 수 | 제목 |
|----|--------|------|
| #60 | 9 | Task #55: release tag dependency 전환을 위한 core API compatibility와 update architecture 정리 |
| #59 | 7 | Task #52: 기존 PR 문서 링크를 고정 URL로 보정 |
| #58 | 7 | Task #57: 이슈 미등록 작업을 위한 task-register Skill 추가 |
| #56 | 5 | Task #54: core provenance를 edwardkim/rhwp 기준으로 정합화 |
| #53 | 8 | Task #49: 신규 매뉴얼 3종 자체 완결성 보강 |
| #51 | 6 | Task #48: Codex/Claude Code SKILL 인식 실측 |
| #50 | 7 | Task #47: Claude Code @AGENTS.md 임포트 실측과 폴백 결정 |
| #46 | 1 | Task #45: AGENTS.md/CLAUDE.md 최적화와 하이퍼-워터폴 절차 skill 분리 |
| #44 | 6 | Task #28: 렌더 검증 샘플 독립화 |
| #43 | 5 | Task #29: rhwp-core.lock v2 산출물 검증 도입 |
| #42 | 6 | Task #35: Quick Look thumbnail 렌더링 일관성 수정 |
| #41 | 6 | Task #40: Dock/Spotlight 표시명 한영 현지화 |
| #39 | 5 | Task #33: Quick Look thumbnail smoke test 실패 원인 분석 |
| #38 | 4 | Task #37: 문서 최신 상태와 브랜치 정리 반영 |
| #36 | 4 | Task #26: Thumbnail embedded preview quality gate |
| #34 | 5 | Task #27: 알한글 표시명과 Finder 절차 정합화 |
| #25 | 5 | Task #24: PR 템플릿과 PR 생성 규격 표준화 |
| #23 | 2 | Task #22: rework rhwp bridge and finder thumbnail flow |

## 문제 유형 분류

### 1. 존재하지 않는 SHA

PR #59 문서 섹션의 7개 링크가 모두 존재하지 않는 commit SHA를 사용한다.

| 항목 | 값 |
|------|-----|
| PR | #59 |
| 현재 본문 SHA | `6f57cccda6110abe999a54eec159aa91efa3b646` |
| GitHub API 결과 | `No commit found for SHA` |
| 실제 PR head SHA | `6f57ccc178438bb45ba7df85f6e278af4b428af0` |
| PR merge commit | `bf67565f0cb89f4530456c81003d72795e7c4e5b` |
| 영향 링크 수 | 7 |

PR #59의 실제 head SHA에서는 대표 문서 경로가 조회된다.

```text
gh api 'repos/postmelee/alhangeul-macos/contents/mydocs/plans/task_m010_52.md?ref=6f57ccc178438bb45ba7df85f6e278af4b428af0'
=> mydocs/plans/task_m010_52.md
```

Stage 2에서는 PR #59 문서 섹션의 기준 SHA를 `6f57ccc178438bb45ba7df85f6e278af4b428af0`로 교체하는 보정안을 작성한다.

### 2. 문서 섹션 raw URL 표시

PR #60 문서 섹션의 9개 링크는 commit SHA와 경로가 유효하지만 raw URL 전체가 노출되어 가독성이 낮다.

| 항목 | 값 |
|------|-----|
| PR | #60 |
| 현재 본문 SHA | `c39e479b131804f7c2c123cc71a30f70216402a3` |
| PR merge commit | `27c47a87fa0f8090eb39fa2660526f4698f07f08` |
| 영향 링크 수 | 9 |
| 접근성 | 대표 문서 경로 GitHub API 조회 성공 |

대표 경로 확인:

```text
gh api 'repos/postmelee/alhangeul-macos/contents/mydocs/plans/task_m010_55.md?ref=c39e479b131804f7c2c123cc71a30f70216402a3'
=> mydocs/plans/task_m010_55.md
```

Stage 2에서는 URL은 유지하고 표시 텍스트만 `[task_m010_55.md](URL)` 형식으로 바꾸는 보정안을 작성한다.

### 3. 상대 링크와 비클릭 문서 경로

문서 섹션 기준으로 `mydocs/...` 상대 링크 또는 비클릭 경로는 발견되지 않았다.

PR #59 본문에는 `blob/publish/taskN/...`, `](mydocs/` 문자열이 남아 있지만, 이는 검증 결과 설명에 포함된 패턴 이름이다. 실제 문서 링크가 아니므로 Stage 1 기준 보정 대상에서 제외한다.

## SHA 검증 결과

merged PR 본문에 등장하는 고정 blob SHA를 일괄 추출해 local git object 기준으로 확인했다.

```text
015a2fe50cf6720e198551e54ef3588a5b133302 commit
0df35a92fd476badb2ed27775a48d4ae0ef4ea1e commit
2fbdd0ed0b83884d0e1a5c71b4f65a496c5cc619 commit
35ee83aea2a09e00a71218b66e25f88de804c6b6 commit
53223924d4ca51c481543888e3f6197234446639 commit
69361546bc24c0caffbedaca14cea177b7c01059 commit
6f57cccda6110abe999a54eec159aa91efa3b646 missing
7adc116bf97291c5b151c61cf0146408044a1c0e commit
7c62f6870c842444085cbc04c45dbdcfef9be0e4 commit
8932ae7537b90f5eef5f72286df74cedfb969c57 commit
8cf41fbfc3786ffe7c71871eb39235954e6a41d3 commit
99ed78019c32d727fa14e4ef4358a6bd1b2f1783 commit
bdbc13ad57e08c371afff0fe669fed623f22b03d commit
c39e479b131804f7c2c123cc71a30f70216402a3 commit
d5bd5083abc9f04d73e95b152d6ce055c081b4c4 commit
e94e09bb92641a3797072be9db979d3a095b42b9 commit
fc1df58bb5d9b4e8b533550cba17552e52fb36b4 commit
ff57ef1f15b88a78b50676467e75ef846de7e592 commit
```

존재하지 않는 SHA는 PR #59의 `6f57cccda6110abe999a54eec159aa91efa3b646`뿐이다.

링크별 commit/path 검증에서는 변수명 `path`를 쓰면 zsh의 특수 변수 `path`와 충돌해 `PATH`가 깨지는 문제가 있었다. 최종 검증은 `file_path` 변수명으로 재실행했고, 결과는 PR #59의 `missing-commit` 7건만 남았다. 유효한 commit의 파일 경로 missing 사례는 확인되지 않았다.

## Stage 2 후보

| PR | 문제 | Stage 2 보정 방향 |
|----|------|-------------------|
| #59 | 7개 링크가 존재하지 않는 SHA 사용 | SHA를 실제 head `6f57ccc178438bb45ba7df85f6e278af4b428af0`로 교체하고 `[파일명](URL)` 형식 유지 |
| #60 | 9개 링크가 raw URL로 노출 | URL은 유지하고 표시 텍스트를 `[파일명](URL)` 형식으로 교체 |

추가 보정 후보는 현재 없다. Stage 2에서는 #59와 #60의 수정 전/후 Markdown을 PR 본문 문단 단위로 확정한다.

## 실행한 주요 명령

```bash
gh pr view 59 --repo postmelee/alhangeul-macos --json number,title,body,commits,mergeCommit,url,state
gh pr view 60 --repo postmelee/alhangeul-macos --json number,title,body,commits,mergeCommit,url,state
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json number,title,url,body,mergeCommit
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json body | jq -r '.[].body | scan("https://github\\.com/postmelee/alhangeul-macos/blob/([0-9a-f]{40})/[^\\s)]+") | .[0]' | sort -u | git cat-file --batch-check='%(objectname) %(objecttype)'
gh api repos/postmelee/alhangeul-macos/commits/6f57cccda6110abe999a54eec159aa91efa3b646 --jq '.sha'
gh api repos/postmelee/alhangeul-macos/commits/6f57ccc178438bb45ba7df85f6e278af4b428af0 --jq '.sha'
gh api 'repos/postmelee/alhangeul-macos/contents/mydocs/plans/task_m010_52.md?ref=6f57ccc178438bb45ba7df85f6e278af4b428af0' --jq '.path'
gh api 'repos/postmelee/alhangeul-macos/contents/mydocs/plans/task_m010_55.md?ref=c39e479b131804f7c2c123cc71a30f70216402a3' --jq '.path'
```

## 검증 결과

```bash
git diff --check -- mydocs/working/task_m010_61_stage1.md
```

결과: 통과.

## 완료 조건 확인

| 완료 조건 | 결과 |
|-----------|------|
| 보정 대상 PR과 제외 대상 PR이 표로 정리되어 있음 | 충족 |
| PR #59의 깨진 SHA와 PR #60의 raw URL 표시 문제가 재확인됨 | 충족 |
| Stage 2에서 사용할 기준 SHA 후보가 PR별로 정리됨 | 충족 |

## 승인 요청 사항

본 Stage 1 결과 기준으로 Stage 2: 기준 SHA와 PR 본문 보정안 확정 진행을 승인 요청한다.
