# Task M013 #244 Stage 5 보고서

## 단계 목적

Stage 2 runbook에 따라 원격 전환 gate를 최신 상태로 확인한 뒤, 작업지시자의 명시 지시에 따라 제품 `devel` 원격 전환을 실행했다.

이번 단계에서 기존 `origin/devel` native 라인은 `origin/native-viewer-editor`로 보존했고, `origin/devel`과 `origin/devel-webview`는 `origin/devel-webview` 제품 라인에 `origin/main` release 후속 기록을 병합한 동일 commit을 가리키도록 전환했다.

## 실행 전 gate

| 항목 | 결과 |
|------|------|
| `git fetch --prune origin` | 통과 |
| `gh pr list --state open --base devel` | 열린 PR 없음 |
| `gh pr list --state open --base devel-webview` | 열린 PR 없음 |
| GitHub default branch | `main` |
| `devel` 보호 상태 | protected |
| `devel-webview` 보호 상태 | unprotected |
| `native-viewer-editor` 원격 브랜치 | 없음 |

실행 전 원격 head:

| 브랜치 | head |
|--------|------|
| `origin/main` | `ccc3806a9315c89747b3c1d33a596751dfb0d048` |
| `origin/devel` | `d51ad1647db281b2a8be3175eec5a723d340d8fd` |
| `origin/devel-webview` | `69bcd486034d4c29d08436151f253d89980b543e` |
| `origin/native-viewer-editor` | 없음 |

## 제품 `devel` 후보 commit

최신 원격 기준으로 후보 브랜치를 재생성했다.

```bash
git checkout -B task244/product-devel-candidate origin/devel-webview
git merge --no-ff origin/main -m "Merge main release records into devel product line"
```

후보 commit:

| 항목 | 값 |
|------|----|
| 로컬 브랜치 | `task244/product-devel-candidate` |
| 후보 commit | `ae3f6da95447d87689766285f328bb9689f228c8` |
| 기준 first parent | `origin/devel-webview` |
| 병합 대상 | `origin/main` |

후보 검증:

| 검증 | 결과 |
|------|------|
| `git merge-base --is-ancestor origin/devel-webview HEAD` | 통과 |
| `git merge-base --is-ancestor origin/main HEAD` | 통과 |
| `git merge-base --is-ancestor origin/devel HEAD` | 실패가 기대값. 기존 native `devel` 라인을 제품 후보에 직접 포함하지 않음 |
| `git diff --check` | 통과 |

후보 생성 중 `origin/main` 병합은 충돌 없이 완료됐다. `mydocs/orders/20260513.md`는 자동 병합됐다.

## 원격 전환 실행

부분 전환을 남기지 않기 위해 `--atomic` push와 ref별 `--force-with-lease`를 함께 사용했다.

```bash
git push --atomic \
  --force-with-lease=refs/heads/native-viewer-editor: \
  --force-with-lease=refs/heads/devel-webview:69bcd486034d4c29d08436151f253d89980b543e \
  --force-with-lease=refs/heads/devel:d51ad1647db281b2a8be3175eec5a723d340d8fd \
  origin \
  origin/devel:refs/heads/native-viewer-editor \
  task244/product-devel-candidate:refs/heads/devel-webview \
  task244/product-devel-candidate:refs/heads/devel
```

실행 결과:

| 브랜치 | 결과 |
|--------|------|
| `native-viewer-editor` | 기존 `origin/devel` head에서 새 브랜치 생성 |
| `devel-webview` | `69bcd486...`에서 `ae3f6da...`로 fast-forward |
| `devel` | `d51ad164...`에서 `ae3f6da...`로 forced update |

## 실행 후 검증

`git fetch --prune origin` 후 확인한 원격 head:

| 브랜치 | head |
|--------|------|
| `origin/devel` | `ae3f6da95447d87689766285f328bb9689f228c8` |
| `origin/devel-webview` | `ae3f6da95447d87689766285f328bb9689f228c8` |
| `origin/native-viewer-editor` | `d51ad1647db281b2a8be3175eec5a723d340d8fd` |
| `origin/main` | `ccc3806a9315c89747b3c1d33a596751dfb0d048` |

| 검증 | 결과 |
|------|------|
| `git merge-base --is-ancestor origin/devel-webview origin/devel` | 통과 |
| `git merge-base --is-ancestor origin/main origin/devel` | 통과 |
| `git merge-base --is-ancestor origin/native-viewer-editor origin/devel` | 실패가 기대값. native 라인은 제품 라인에 직접 포함하지 않음 |
| `gh pr list --state open --base devel` | 열린 PR 없음 |
| `gh pr list --state open --base devel-webview` | 열린 PR 없음 |
| GitHub default branch | `main` 유지 |
| `devel` 보호 상태 | protected |
| `native-viewer-editor` 보호 상태 | unprotected |
| `devel-webview` 보호 상태 | unprotected |

## 로컬 작업 브랜치 정렬

원격 전환 후 #244 PR diff가 새 `devel` 기준을 되돌리지 않도록 `local/task244`에 `origin/devel`을 병합했다.

```bash
git checkout local/task244
git merge --no-ff origin/devel -m "Merge devel product line into Task #244"
```

충돌은 `README.md` 한 곳에서만 발생했다. v0.1.2 release 상태는 새 `devel`의 최신 public release 문구를 유지하고, #244의 브랜치 정책 문구를 보존하는 방식으로 해결했다.

병합 중 `mydocs/working/task_m010_166_stage4.md`의 EOF 공백 경고가 있어 trailing blank line만 정리했다.

## 남은 수동 설정

| 항목 | 상태 |
|------|------|
| `native-viewer-editor` branch protection | 아직 unprotected. native 장기 라인 보호 규칙 적용 필요 |
| `devel-webview` legacy alias 유지/삭제 | 유지 중. 삭제 여부와 시점은 별도 승인 필요 |
| GitHub default branch | `main` 유지. 외부 기여 PR 기본 base 관점에서 `devel` 전환 여부는 별도 판단 필요 |

## 다음 단계 제안

Stage 6에서는 최종 보고서를 작성하고, #244 PR을 새 제품 `devel` 대상으로 게시할 수 있도록 최종 검증과 보고를 완료한다.

## 승인 요청

Stage 5 원격 전환과 로컬 작업 브랜치 정렬을 완료했다. 이 보고서 기준으로 Stage 6 최종 보고와 PR 게시 준비를 진행해도 되는지 승인 요청한다.
