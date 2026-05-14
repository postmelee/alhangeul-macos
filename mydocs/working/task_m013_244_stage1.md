# Task M013 #244 Stage 1 보고서

## 단계 목적

`devel`을 제품 기여 기본 브랜치로 승격하기 전에 현재 `main`, `devel-webview`, `devel`의 관계, 가상 병합 충돌, 문서/workflow 참조, 열린 PR/이슈 영향 범위를 조사했다.

이번 단계는 읽기 중심 조사만 수행했고, 원격 브랜치 push/delete/force-update와 repository setting 변경은 수행하지 않았다.

## 작업 환경

| 항목 | 값 |
|------|----|
| 작업 worktree | `/private/tmp/rhwp-mac-task244` |
| 작업 브랜치 | `local/task244` |
| 기준 tracking | `origin/devel-webview` |
| 메인 worktree | `/Users/melee/Documents/projects/rhwp-mac` |
| 메인 worktree 브랜치 | `local/task243` |

Stage 1 시작/종료 확인에서 `local/task243` 메인 worktree는 깨끗했고, #244 변경과 섞이지 않았다.

## 원격 브랜치 상태

`git fetch origin` 이후 확인한 주요 ref는 다음과 같다.

| 브랜치 | 커밋 |
|--------|------|
| `origin/main` | `ccc3806a9315c89747b3c1d33a596751dfb0d048` |
| `origin/devel-webview` | `69bcd486034d4c29d08436151f253d89980b543e` |
| `origin/devel` | `d51ad1647db281b2a8be3175eec5a723d340d8fd` |
| `origin/publish/task130` | `63776eda40429e25bef500d23e285af2e4585573` |
| `origin/publish/task178` | `7c784da6ba47d1f27ce902f74fc4d9f96381fc69` |

현재 원격 기본 HEAD는 `origin/main`이다.

## 브랜치 topology

| 비교 | merge-base | left/right count | cherry-pick 제외 count | 해석 |
|------|------------|------------------|-------------------------|------|
| `origin/devel...origin/devel-webview` | `ce6150ff158223ae5f9ed6359742557c6f2a9623` | `33 / 432` | `27 / 426` | 기존 `devel`과 제품 라인은 크게 분기되어 있고 일부 backport만 겹친다. |
| `origin/main...origin/devel-webview` | `f57b6466d2f673d05567e6d8e28b258cf8881189` | `46 / 17` | `46 / 17` | `main`에는 v0.1.2 public release 이후 문서/배포 기록이 있고, `devel-webview`에는 #230/#240 후속 작업이 남아 있다. |
| `origin/main...origin/devel` | `ce6150ff158223ae5f9ed6359742557c6f2a9623` | `461 / 33` | `455 / 27` | `devel`은 release/product line을 거의 따라오지 않은 native 장기 라인이다. |

first-parent 기준 주요 차이:

- `origin/devel` 전용 merge는 #119-devel, #123-devel, #109, #120 계열이다.
- `origin/devel-webview` 전용 merge는 #134 이후 WKWebView viewer, release hardening, Quick Look/Thumbnail smoke, Sparkle/update, Pages, release workflow, #240 registration hygiene까지 포함한다.
- `origin/main` 전용 merge와 commit은 v0.1.0/v0.1.2 release execution, README/banner, release record, Pages refresh 계열을 포함한다.

## 가상 병합 결과

`git merge-tree --write-tree --name-only --messages`로 worktree를 변경하지 않고 확인했다.

| 가상 병합 | 결과 | 충돌/자동 병합 요약 |
|----------|------|----------------------|
| `origin/devel` + `origin/devel-webview` | 충돌 | 11개 경로 충돌. 기존 `devel`을 제품 라인에 직접 merge하면 renderer/폰트/project 설정 충돌이 필요하다. |
| `origin/main` + `origin/devel-webview` | 자동 병합 가능 | `mydocs/orders/20260513.md` 자동 병합 메시지만 있고 충돌 없음. |
| `origin/devel` + `origin/main` | 충돌 | `origin/devel` + `origin/devel-webview`와 같은 충돌군. `main`으로 우회해도 기존 `devel` 직접 통합 문제는 해소되지 않는다. |

`origin/devel`과 제품 라인 사이의 충돌 경로는 다음과 같다.

| 경로 | 충돌 유형/의미 |
|------|----------------|
| `AlhangeulMac.xcodeproj/project.pbxproj` | 제품 라인에서 삭제된 생성 Xcode project와 기존 `devel` 수정 충돌 |
| `project.yml` | XcodeGen 원본 설정 충돌 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | native renderer 변경 충돌 |
| `Sources/RhwpCoreBridge/FontFallback.swift` | font fallback 정책 충돌 |
| `Sources/RhwpCoreBridge/FontResourceRegistry.swift` | add/add 충돌 |
| `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | add/add 충돌 |
| `mydocs/tech/font_fallback_strategy.md` | add/add 충돌 |
| `mydocs/report/task_m015_119_report.md` | add/add 충돌 |
| `mydocs/orders/20260503.md` | add/add 충돌 |
| `mydocs/orders/20260505.md` | add/add 충돌 |
| `mydocs/orders/20260506.md` | add/add 충돌 |

따라서 Stage 2에서 기존 `devel`을 그대로 merge하는 방식은 제외하고, 기존 `devel` head를 native 보존 브랜치로 옮긴 뒤 제품 라인을 새 `devel`로 세우는 runbook을 작성하는 것이 타당하다.

## 문서와 workflow 참조 inventory

`rg`로 `devel-webview`, `devel`, native viewer/renderer, PR base, 통합 브랜치, branch filter, `publish/task`, `local/task` 참조를 확인했다.

| 영역 | 파일 | Stage 3/4 조치 |
|------|------|----------------|
| 사용자/기여자 문서 | `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `.github/copilot-instructions.md` | 일반 제품 PR base를 `devel`로 바꾸고, Swift native viewer/editor는 native 보존 브랜치로 안내해야 한다. |
| 핵심 브랜치 정책 | `mydocs/tech/branch_strategy_webview_native.md`, `mydocs/manual/git_workflow_guide.md` | 기존 `devel-webview`/`devel` 이중 정책을 새 정책과 migration 기록으로 갱신해야 한다. |
| 타스크/PR 절차 | `mydocs/manual/task_workflow_guide.md`, `mydocs/manual/pr_process_guide.md`, `mydocs/manual/document_structure_guide.md` | 통합 브랜치 선택 기준과 PR 생성 예시를 새 branch policy로 바꿔야 한다. |
| release/CI 문서 | `mydocs/manual/ci_workflow_guide.md`, `mydocs/manual/release_policy_guide.md`, `mydocs/manual/release_distribution_guide.md` | release 기준 브랜치 설명과 PR CI branch 대상 설명을 정렬해야 한다. |
| architecture/roadmap | `mydocs/tech/project_architecture.md`, `mydocs/tech/product_roadmap_notes.md`, `mydocs/tech/font_fallback_strategy.md`, `mydocs/manual/render_core_native_compare_guide.md`, `mydocs/manual/build_run_guide.md` | 대부분 branch policy가 아니라 native renderer 설명이다. 용어는 보존하되 PR base 문구가 있으면 조정한다. |
| workflow | `.github/workflows/pr-ci.yml` | PR trigger가 `main`, `devel-webview`, `devel`이다. 새 `devel`과 native 보존 브랜치, legacy `devel-webview` 유지 기간을 반영해야 한다. |
| workflow | `.github/workflows/release-publish.yml`, `.github/workflows/release-rehearsal.yml`, `.github/workflows/rhwp-upstream-check.yml` | 직접 branch filter는 없다. release tag 기준과 checkout/ref 문구만 점검하면 된다. |
| PR template | `.github/pull_request_template.md` | 현재 branch policy 문구는 없지만, 전환 후 리뷰 포인트에 base branch 안내를 넣을지 Stage 4에서 판단한다. |

참조 수가 많은 파일은 다음과 같다.

| 파일 | match 수 |
|------|---------:|
| `mydocs/tech/branch_strategy_webview_native.md` | 67 |
| `mydocs/manual/git_workflow_guide.md` | 58 |
| `README.md` | 27 |
| `CONTRIBUTING.md` | 20 |
| `mydocs/manual/pr_process_guide.md` | 17 |
| `mydocs/manual/task_workflow_guide.md` | 12 |
| `mydocs/manual/release_policy_guide.md` | 8 |
| `AGENTS.md` | 7 |

## workflow branch filter 확인

직접적인 branch filter는 `.github/workflows/pr-ci.yml`에만 있다.

```yaml
on:
  pull_request:
    branches:
      - main
      - devel-webview
      - devel
```

Stage 4에서는 최소한 다음 선택지를 결정해야 한다.

1. `main`, 새 제품 `devel`, native 보존 브랜치만 유지
2. 전환 안정화 기간 동안 `main`, `devel`, `devel-webview`, native 보존 브랜치를 모두 유지

release publish는 tag ref에서 실행되므로 제품 개발 브랜치 rename 자체와 직접 연결되지 않는다. release rehearsal은 `workflow_dispatch`이며 branch filter가 없으므로 문서와 운영 기준만 갱신하면 된다. upstream check도 schedule/workflow_dispatch만 사용한다.

## 열린 PR과 이슈 영향

열린 PR은 1개다.

| PR | base | head | 상태 | 영향 |
|----|------|------|------|------|
| [#131](https://github.com/postmelee/alhangeul-macos/pull/131) Task #130: 프로젝트 부산물 정리 Skill 추가 | `devel` | `publish/task130` | open, mergeable | 기존 `devel`을 native 보존 브랜치로 옮기기 전에 merge/close/retarget 결정을 해야 한다. |

관련 열린 이슈와 영향:

| 이슈 | milestone | 영향 |
|------|-----------|------|
| [#244](https://github.com/postmelee/alhangeul-macos/issues/244) | M013 | 현재 브랜치 전환 작업 |
| [#243](https://github.com/postmelee/alhangeul-macos/issues/243) | v0.1 | 진행 중인 HostApp 제품 작업. 전환 전이면 `devel-webview`, 전환 후면 새 `devel` 대상이 자연스럽다. |
| [#204](https://github.com/postmelee/alhangeul-macos/issues/204) | v0.1.2 | 이슈 설명에 `devel-webview` 대상 자동 PR 생성이 명시되어 있어 Stage 3/4에서 문서 또는 후속 이슈로 정리해야 한다. |
| [#214](https://github.com/postmelee/alhangeul-macos/issues/214) | v0.1.2 | Pages/appcast workflow 작업이므로 새 제품 `devel` 기준으로 base 안내가 바뀐다. |
| [#222](https://github.com/postmelee/alhangeul-macos/issues/222), #99, #124, #122, #121, #116, #110 등 | v0.5 | Swift native renderer/viewer 라인 이슈다. 새 native 보존 브랜치의 기본 대상 후보로 문서화해야 한다. |
| [#125](https://github.com/postmelee/alhangeul-macos/issues/125), [#126](https://github.com/postmelee/alhangeul-macos/issues/126) | v0.6 | Swift native editor 기반 이슈다. native 보존 브랜치 또는 별도 editor 라인 정책에 포함해야 한다. |

원격에는 `publish/task178`도 남아 있지만 열린 PR 목록에는 나오지 않는다. Stage 2 runbook에서 legacy publish branch 정리 대상 여부를 별도 확인하는 것이 좋다.

## Stage 1 판단

- 기존 `devel`은 제품 라인으로 fast-forward 또는 clean merge될 수 있는 상태가 아니다.
- `main`과 `devel-webview`는 자동 병합 가능하므로 새 제품 `devel` 기준은 두 라인을 통합한 commit으로 잡을 수 있다.
- 기존 `devel` head는 native 보존 브랜치로 먼저 보존해야 한다.
- `devel-webview`는 전환 직후 바로 삭제하지 말고 legacy alias로 두는 쪽이 안전하다. README/CONTRIBUTING/workflow/documentation 전환과 열린 PR 정리가 완료된 뒤 삭제 여부를 다시 판단해야 한다.
- Stage 2에서는 native 보존 브랜치 이름, `main + devel-webview` 통합 방식, #131 처리 gate, `devel-webview` legacy 유지 기간을 runbook에 고정해야 한다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `git status --short --branch` | #244 worktree와 #243 worktree 모두 깨끗한 상태에서 조사 시작 |
| `git fetch origin` | 통과 |
| branch ahead/behind count | 통과 |
| `git merge-tree` 가상 병합 | 결과 확인 완료. 제품 라인끼리는 clean, 기존 `devel` 포함 시 충돌 |
| branch reference `rg` inventory | 통과 |
| 열린 PR/이슈 `gh` 조회 | 통과 |
| `git diff --check` | Stage 1 보고서 작성 후 통과 |

## 다음 단계 제안

Stage 2에서 다음 정책을 확정한다.

1. 기존 `origin/devel` 보존 브랜치 이름은 `native-viewer` 또는 `native-viewer-editor` 중 하나로 결정한다.
2. 새 제품 `devel` 기준은 `origin/devel-webview`에 `origin/main` 전용 release 후속 변경을 병합한 commit으로 만든다.
3. `origin/devel-webview`는 최소 한 전환 주기 동안 legacy alias로 유지한다.
4. PR #131은 기존 `devel` 보존 전에 merge/close/retarget 중 하나를 결정한다.
5. `publish/task178` 원격 브랜치의 필요 여부를 확인한다.

## 승인 요청

Stage 1 조사와 보고를 완료했다. 이 보고서 기준으로 Stage 2 전환 정책과 runbook 확정을 진행해도 되는지 승인 요청한다.
