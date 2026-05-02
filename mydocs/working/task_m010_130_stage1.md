# Issue #130 Stage 1 완료 보고서

## 단계 목적

`project-artifact-cleanup` Skill 작성 전에 실제 저장소 산출물과 `/private/tmp` 후보를 확인하고, 삭제 가능/승인 필요/삭제 금지 기준을 확정했다. 이번 단계에서는 파일 삭제를 전혀 수행하지 않고 read-only 확인과 기준 정리만 수행했다.

## 산출물

- `mydocs/working/task_m010_130_stage1.md` — Stage 1 기준 정리 보고서

## 확인한 문서와 기준

- `mydocs/manual/build_run_guide.md`
  - Debug build는 compile/link 확인용이다.
  - Finder Quick Look/Thumbnail 등록 검증은 Release package 산출물과 `$HOME/Applications/AlhangeulMac.app` 단일 설치본 기준으로 수행한다.
  - Debug/Release 중간 산출물은 Spotlight 오염 방지를 위해 `build.noindex/` 아래에 둔다.
- `mydocs/troubleshootings/finder_integration_validation_pitfalls.md`
  - `qlmanage -m plugins` 미노출만으로 실패를 판정하지 않는다.
  - 이전 이름 설치본(`RhwpMac.app`, `알한글.app`)은 충돌이 확인되거나 의심될 때만 작업지시자 승인 후 제거한다.
  - 표시명 문제 해결을 위해 `.app` 또는 `.appex` 디렉터리 자체를 한글로 rename하지 않는다.
- `mydocs/skills/pr-merge-cleanup/SKILL.md`
  - PR merge 후 이슈 close, publish branch, local branch, worktree 정리 절차다.
  - 새 cleanup Skill은 빌드/렌더/임시 산출물 정리용으로 분리하고, PR/이슈/브랜치 정리는 다루지 않는다.

## 현재 후보 확인 결과

저장소 내부 재생성 산출물:

| 경로 | 크기 | 판단 |
|------|------|------|
| `build.noindex/` | 554M | Debug/Release 중간 산출물. 하위 경로별 판단 필요 |
| `build.noindex/DerivedData` | 444M | Debug build cleanup 후보 |
| `build.noindex/release` | 110M | Release package 산출물. 설치/검증 완료 전 삭제 보류 |
| `output/` | 230M | render smoke/debug 산출물. 검증 증거 보존 필요 여부 확인 후 cleanup 후보 |
| `RustBridge/target/` | 892M | 재생성 가능하지만 빌드 비용 큼. full clean/명시 승인 후보 |
| `Frameworks/` | 199M | `build-rust-macos.sh` 재생성 가능하지만 Xcode build 준비물. full clean/명시 승인 후보 |

`/private/tmp` 후보:

- `rhwp-task106-*`, `rhwp-task107-*`, `rhwp-task118-*`, `rhwp-*-analysis`, `rhwp-*-render-debug` 등 렌더/검증 산출물 다수
- `rhwp-*-issue-body.md`, `task*-pr-body.md` 등 GitHub 임시 본문 파일
- `rhwp-task118-swift-module-cache`, `rhwp-task118-clang-module-cache` 등 Swift/Clang module cache
- `/private/tmp/rhwp-mac-task120`, `/private/tmp/rhwp-mac-task127`은 `git worktree list --porcelain`에 등록된 실제 worktree
- `/private/tmp/rhwp-task530-before`는 `.git`을 가진 git 보호 대상 경로

## 확정 분류 기준

### safe

다음은 dry-run 보고 후, 작업지시자가 명시 승인하면 삭제 가능한 후보로 분류한다.

- `build.noindex/DerivedData*`
- `output/stage3-render*`, `output/task*-*`, `output/*-smoke`, `output/*-debug`
- `/private/tmp/rhwp-task*-stage*`, `/private/tmp/rhwp-task*-final*`, `/private/tmp/rhwp-task*-smoke`
- `/private/tmp/rhwp-task*-render`, `/private/tmp/rhwp-task*-bookreview`, `/private/tmp/rhwp-task*-bokhak` 같은 render-debug 출력
- `/private/tmp/rhwp-*-analysis`, `/private/tmp/rhwp-*-render-debug`
- `/private/tmp/rhwp-*-swift-cache`, `/private/tmp/rhwp-*-swift-module-cache`
- `/private/tmp/rhwp-*-clang-cache`, `/private/tmp/rhwp-*-clang-module-cache`
- `/private/tmp/task*-pr-body.md`, `/private/tmp/rhwp-*-issue-body.md`
- `/private/tmp/alhangeul-*` Quick Look/thumbnail 임시 출력

단, safe 후보라도 현재 진행 중인 task의 단계 보고서나 최종 보고서에 아직 인용해야 하는 증거라면 삭제하지 않는다.

### approval-required

다음은 재생성 가능하지만 영향이 크거나 설치/검증 상태와 연결되므로 별도 설명과 명시 승인을 요구한다.

- `build.noindex/release`
- `RustBridge/target`
- `Frameworks`
- 현재 진행 중이거나 상태가 불분명한 task 번호가 붙은 `/private/tmp/rhwp-task{N}-*`
- `/private/tmp/rhwp-core-*`처럼 core 분석 또는 dump 성격이 있는 대용량 산출물
- 이전 이름 설치본(`RhwpMac.app`, `알한글.app`) 발견 시 제거

### never-delete

다음은 cleanup Skill이 삭제 대상으로 제안하지 않는다.

- 저장소 루트와 그 상위 디렉터리
- `/private/tmp` 자체
- `$HOME`과 `$HOME/Applications` 자체
- `$HOME/Applications/AlhangeulMac.app`
- `git worktree list --porcelain`에 등록된 모든 worktree 경로
- `.git` 디렉터리 또는 gitfile을 가진 모든 경로
- 현재 checkout 중인 작업 브랜치 디렉터리
- 다른 작업자의 stash, branch, PR merge 후 정리 대상

## Debug build cleanup 판단

Debug build 산출물은 compile/link 확인용이므로 `build.noindex/DerivedData*` 정리 후보로 둘 수 있다. 다만 Quick Look, Thumbnail, Viewer 테스트를 계속할 수 있어야 하는 상황에서는 다음 조건을 먼저 만족해야 한다.

1. `./scripts/package-release.sh <version>`으로 Release package 산출물을 만든다.
2. `$HOME/Applications/AlhangeulMac.app` 단일 설치본을 갱신한다.
3. `lsregister -f -R -trusted "$APP"`와 `pluginkit -a "$APP"`를 수행한다.
4. `pluginkit -mAvvv | grep com.postmelee.alhangeulmac`로 extension 등록 후보를 확인한다.
5. `qlmanage -t -x -s 512 -o /tmp/alhangeul-ql samples/basic/KTX.hwp`로 thumbnail smoke를 확인한다.

이 조건을 만족한 뒤에는 Debug `DerivedData`를 삭제해도 Quick Look/Thumbnail/Viewer 테스트 기준 설치본은 유지된다.

## 검증 결과

```text
rg -n "build.noindex|/private/tmp|pluginkit|qlmanage|Release package|Debug" \
  mydocs/manual/build_run_guide.md \
  mydocs/troubleshootings/finder_integration_validation_pitfalls.md
```

결과: 관련 기준 확인 완료.

```text
rg -n "PR merge|worktree|git branch|rm -rf|절대 하지 말 것" \
  mydocs/skills/pr-merge-cleanup/SKILL.md
```

결과: 기존 Skill의 책임 범위와 금지사항 확인 완료.

```text
git worktree list --porcelain
```

결과: 현재 `local/task130` 외에 `/private/tmp/rhwp-mac-task120`, `/private/tmp/rhwp-mac-task127` worktree 확인. cleanup Skill의 `never-delete` 보호 대상에 포함해야 한다.

```text
du -sh build.noindex output RustBridge/target Frameworks
```

결과: `build.noindex` 554M, `output` 230M, `RustBridge/target` 892M, `Frameworks` 199M 확인.

```text
git diff --check
```

결과: 통과.

## 잔여 위험

- `/private/tmp` 파일명은 작업자가 임의로 만들 수 있으므로 패턴 기반 분류만으로 완전한 안전성을 보장할 수 없다.
- 현재 task 번호가 아닌 과거 task 산출물도 보고서나 PR 본문에서 아직 참조 중일 수 있다.
- `Frameworks/`와 `RustBridge/target/`은 재생성 가능하지만 삭제 후 즉시 빌드 가능한 환경인지 별도 확인이 필요하다.

## 다음 단계 영향

Stage 2에서는 위 분류 기준을 `project-artifact-cleanup` Skill 본문에 반영한다. 특히 기본 동작은 dry-run 후보 보고로 두고, 실제 삭제는 개별 경로 목록과 명시 승인 후에만 허용해야 한다.

## 승인 요청

Stage 1 완료를 보고한다. 다음 단계인 Stage 2 — `project-artifact-cleanup` Skill 작성을 승인 요청한다.
