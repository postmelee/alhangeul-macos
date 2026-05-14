# Task M013 #244 Stage 5 보고서

## 단계 목적

Stage 2 runbook에 따라 원격 전환 gate를 최신 상태로 확인하고, `origin/devel-webview` 제품 라인과 `origin/main` release 후속 기록을 합친 제품 `devel` 후보 commit을 로컬에서 생성했다.

이번 단계에서는 원격 브랜치 ref를 변경하지 않았다. `devel`은 protected 상태이고, 실제 전환에는 기존 `devel`의 비 fast-forward 교체가 필요하므로 작업지시자의 원격 전환 실행 명시 승인과 GitHub branch protection 설정 확인이 필요하다.

## 원격 gate 확인

| 항목 | 결과 |
|------|------|
| `git fetch --prune origin` | 통과 |
| `gh pr list --state open --base devel` | 열린 PR 없음 |
| `gh pr list --state open --base devel-webview` | 열린 PR 없음 |
| GitHub default branch | `main` |
| `main` 보호 상태 | protected |
| `devel` 보호 상태 | protected |
| `devel-webview` 보호 상태 | unprotected |
| `native-viewer-editor` 원격 브랜치 | 없음 |

원격 head 확인 결과:

| 브랜치 | head |
|--------|------|
| `origin/main` | `ccc3806a9315c89747b3c1d33a596751dfb0d048` |
| `origin/devel` | `d51ad1647db281b2a8be3175eec5a723d340d8fd` |
| `origin/devel-webview` | `69bcd486034d4c29d08436151f253d89980b543e` |
| `origin/native-viewer-editor` | 없음 |

분기 상태:

| 비교 | left 전용 | right 전용 |
|------|-----------|------------|
| `origin/main...origin/devel-webview` | 46 | 17 |
| `origin/devel...origin/devel-webview` | 33 | 432 |
| `origin/main...origin/devel` | 461 | 33 |

## 제품 `devel` 후보 commit

로컬 후보 브랜치:

```bash
git checkout -B task244/product-devel-candidate origin/devel-webview
git merge --no-ff origin/main -m "Merge main release records into devel product line"
```

후보 commit:

| 항목 | 값 |
|------|----|
| 로컬 브랜치 | `task244/product-devel-candidate` |
| 후보 commit | `6bbae0e69929de2a8dc7e626dd2cc92378121e66` |
| 기준 first parent | `origin/devel-webview` |
| 병합 대상 | `origin/main` |

검증:

| 검증 | 결과 |
|------|------|
| `git merge-base --is-ancestor origin/devel-webview HEAD` | 통과 |
| `git merge-base --is-ancestor origin/main HEAD` | 통과 |
| `git merge-base --is-ancestor origin/devel HEAD` | 실패가 기대값. 기존 native `devel` 라인을 제품 후보에 직접 포함하지 않음 |
| `git rev-list --left-right --count origin/devel-webview...HEAD` | `0 47` |
| `git rev-list --left-right --count origin/main...HEAD` | `0 18` |
| `git diff --check` | 통과 |

후보 생성 중 `origin/main` 병합은 충돌 없이 완료됐다. `mydocs/orders/20260513.md`는 자동 병합됐다.

## 원격 전환 실행 보류

이번 Stage 5에서는 다음 원격 명령을 실행하지 않았다.

```bash
git push origin origin/devel:refs/heads/native-viewer-editor
git push origin task244/product-devel-candidate:devel-webview
git push --force-with-lease=refs/heads/devel:d51ad1647db281b2a8be3175eec5a723d340d8fd origin task244/product-devel-candidate:devel
```

보류 사유:

- `devel`은 GitHub에서 protected 상태다.
- `origin/devel`과 제품 후보 commit은 fast-forward 관계가 아니므로 `devel` 교체에는 비 fast-forward update가 필요하다.
- `native-viewer-editor` 생성, `devel-webview` fast-forward, `devel` 교체는 하나의 원격 전환 묶음으로 처리해야 중간 상태가 남지 않는다.
- branch protection 임시 설정 변경 또는 branch rename 방식 중 어느 방식으로 진행할지 작업지시자 확인이 필요하다.

## 실행 승인 시 handoff 명령

작업지시자가 원격 전환 실행을 명시 승인하고 GitHub branch protection 처리 방식이 정해지면 다음 순서로 진행한다.

1. 다시 `git fetch --prune origin`을 실행한다.
2. 열린 PR을 다시 확인한다.
3. `origin/devel` head가 `d51ad1647db281b2a8be3175eec5a723d340d8fd`인지 확인한다.
4. `origin/devel-webview` head가 `69bcd486034d4c29d08436151f253d89980b543e`인지 확인한다.
5. `native-viewer-editor`가 여전히 없으면 기존 `origin/devel` head로 생성한다.
6. 제품 후보가 최신 원격 기준과 달라졌으면 후보 commit을 재생성한다.
7. `devel-webview`를 제품 후보로 fast-forward한다.
8. `devel`을 `--force-with-lease`로 제품 후보 commit에 맞춘다.
9. `git fetch --prune origin` 후 `origin/devel`, `origin/devel-webview`, `origin/native-viewer-editor`를 검증한다.
10. GitHub repository setting에서 branch protection/default branch를 수동 확인한다.

## 보류 이후 PR 기준

`local/task244`의 Stage 1-5 문서와 workflow 변경은 아직 제품 후보 commit에 포함하지 않았다. 원격 전환을 먼저 실행하면 #244 최종 PR 대상은 새 제품 `devel`이 된다. 원격 전환을 보류하면 #244 PR 대상은 기존 `devel-webview`가 된다.

## 다음 단계 제안

Stage 6에서는 최종 보고서를 작성하고, 원격 전환 실행 여부를 최종 결과에 명확히 기록한다. 원격 전환을 실제로 실행하려면 Stage 6 전에 작업지시자가 "원격 전환 실행"을 별도로 명시해야 한다.

## 승인 요청

Stage 5 gate 확인과 로컬 제품 후보 생성, 원격 전환 handoff 정리를 완료했다. 이 보고서 기준으로 원격 전환을 실행할지, 아니면 보류 상태로 Stage 6 최종 보고를 진행할지 결정 요청한다.
