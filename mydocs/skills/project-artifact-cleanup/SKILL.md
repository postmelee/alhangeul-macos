---
name: project-artifact-cleanup
description: |
  프로젝트 빌드 산출물, 렌더 검증 출력, /private/tmp rhwp/alhangeul 임시 파일을
  정리하기 위한 dry-run 분류 절차를 적용한다. 명시 호출 시에만 사용한다.
  git worktree, git repository, 설치본, 현재 작업 증거를 보호하고,
  실제 삭제는 작업지시자 승인 후에만 수행한다.
allow_implicit_invocation: false
---

# 프로젝트 부산물 정리

## 트리거

- 명시 호출만: 작업지시자가 "부산물 정리", "artifact cleanup", "debug build 정리", "`/private/tmp/rhwp*` 정리"를 명시 지시한 경우
- 본 SKILL을 직접 호출한 경우

## 사전 조건

- 현재 작업 브랜치와 working tree 상태를 먼저 확인한다.
- 정리 대상은 기본적으로 dry-run 후보 보고까지만 수행한다.
- 실제 삭제는 작업지시자가 삭제할 경로 목록을 확인하고 명시 승인한 뒤에만 수행한다.
- 이 Skill은 빌드/렌더/임시 산출물 정리용이다. PR merge 후 이슈 close, branch, worktree 정리는 `pr-merge-cleanup` Skill로 분리한다.

## 절차

### 1. 현재 상태 확인

```bash
git status --short --branch
git worktree list --porcelain
```

- 현재 checkout 중인 worktree와 `git worktree list --porcelain`에 나온 모든 worktree 경로는 삭제 금지로 분류한다.
- 삭제 후보가 현재 진행 중인 task 번호와 관련되면 단계 보고서나 최종 보고서에 아직 필요한 증거인지 먼저 확인한다.

### 2. 후보 수집

read-only 명령으로 후보와 용량을 수집한다.

```bash
du -sh build.noindex output RustBridge/target Frameworks 2>/dev/null

for d in build.noindex output Frameworks RustBridge/target; do
  [ -e "$d" ] || continue
  find "$d" -maxdepth 1 -mindepth 1 -exec du -sh {} + 2>/dev/null | sort -h
done

find /private/tmp -maxdepth 1 \( -name 'rhwp*' -o -name 'alhangeul*' \) \
  -exec du -sh {} + 2>/dev/null | sort -h

find /private/tmp -maxdepth 1 -type f \( -name 'task*-pr-body.md' -o -name 'rhwp*-issue-body.md' \) \
  -exec du -sh {} + 2>/dev/null | sort -h
```

이전 이름 설치본 충돌 후보를 다루는 경우에만 LaunchServices와 Spotlight 후보를 확인한다.

```bash
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -dump | grep -E "(RhwpMac|알한글)[.]app" || true
fi
mdfind "kMDItemContentType == 'com.apple.application-bundle'" | grep -E "(RhwpMac|알한글)[.]app" || true
```

`/private/tmp` 후보는 git 보호 여부를 추가 확인한다.

```bash
find /private/tmp -maxdepth 1 \( -name 'rhwp*' -o -name 'alhangeul*' \) -print |
while IFS= read -r path; do
  if [ -d "$path/.git" ] || [ -f "$path/.git" ]; then
    echo "GIT_PROTECTED $path"
  else
    echo "TMP_CANDIDATE $path"
  fi
done
```

### 3. 분류

#### safe

dry-run 보고 후 승인받으면 삭제 가능한 후보. 자동 삭제는 하지 않는다.

- `build.noindex/DerivedData*`
- `output/stage3-render*`, `output/task*-*`, `output/*-smoke`, `output/*-debug`
- `/private/tmp/rhwp-task*-stage*`, `/private/tmp/rhwp-task*-final*`, `/private/tmp/rhwp-task*-smoke`
- `/private/tmp/rhwp-task*-render`, `/private/tmp/rhwp-task*-bookreview`, `/private/tmp/rhwp-task*-bokhak` 같은 render-debug 출력
- `/private/tmp/rhwp-*-analysis`, `/private/tmp/rhwp-*-render-debug`
- `/private/tmp/rhwp-*-swift-cache`, `/private/tmp/rhwp-*-swift-module-cache`
- `/private/tmp/rhwp-*-clang-cache`, `/private/tmp/rhwp-*-clang-module-cache`
- `/private/tmp/task*-pr-body.md`, `/private/tmp/rhwp-*-issue-body.md`
- `/private/tmp/alhangeul-*` Quick Look/thumbnail 임시 출력

safe 후보라도 현재 보고서, PR 본문, 디버깅 인수인계에 아직 필요한 증거면 삭제하지 않는다.

#### approval-required

재생성 가능하지만 영향이 크거나 설치/검증 상태와 연결되는 후보. 삭제 이유와 복구 방법을 설명하고 별도 승인을 받는다.

- `build.noindex/release`
- `RustBridge/target`
- `Frameworks`
- 현재 진행 중이거나 상태가 불분명한 task 번호가 붙은 `/private/tmp/rhwp-task{N}-*`
- `/private/tmp/rhwp-core-*` 같은 core 분석 또는 dump 성격의 대용량 산출물
- 이전 이름 설치본(`RhwpMac.app`, `알한글.app`)이 충돌 후보로 확인된 경우

#### never-delete

삭제 후보로 제안하지 않는다.

- 저장소 루트와 그 상위 디렉터리
- `/private/tmp` 자체
- `$HOME`과 `$HOME/Applications` 자체
- `$HOME/Applications/AlhangeulMac.app`
- `git worktree list --porcelain`에 등록된 모든 worktree 경로
- `.git` 디렉터리 또는 gitfile을 가진 모든 경로
- 현재 checkout 중인 작업 브랜치 디렉터리
- 다른 작업자의 stash, branch, PR merge 후 정리 대상

## Debug build 정리 판단

Debug build는 compile/link 확인용이므로 `build.noindex/DerivedData*` 정리 후보가 될 수 있다. 다만 Quick Look, Thumbnail, Viewer 테스트를 계속할 수 있어야 하는 상황에서는 먼저 Release 설치본을 갱신하고 등록 상태를 확인한다.

다음 설치본 교체는 cleanup 삭제가 아니라 표준 설치 경로를 최신 Release package로 갱신하는 절차다. 작업지시자가 "Release 설치본 갱신 후 Debug 정리"를 승인한 경우에만 수행한다.

```bash
./scripts/package-release.sh <version>

RELEASE_APP="build.noindex/release/AlhangeulMac.app"
if [ ! -d "$RELEASE_APP" ]; then
  echo "missing release app: $RELEASE_APP" >&2
  exit 1
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
APP="$HOME/Applications/AlhangeulMac.app"
mkdir -p "$HOME/Applications"
"$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
rm -rf "$APP"
ditto "$RELEASE_APP" "$APP"
"$LSREGISTER" -f -R -trusted "$APP"
pluginkit -a "$APP"
pluginkit -mAvvv | grep com.postmelee.alhangeulmac
qlmanage -r
qlmanage -r cache
mkdir -p /tmp/alhangeul-ql
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql samples/basic/KTX.hwp
```

- 위 절차에서 제거하는 앱 경로는 표준 설치본 `$HOME/Applications/AlhangeulMac.app` 하나로 제한한다.
- 이 설치본 교체를 일반 cleanup 후보 삭제와 혼동하지 않는다.
- `CODE_SIGNING_ALLOWED=NO` Debug 산출물로 PlugInKit 등록 성공 여부를 판정하지 않는다.
- `qlmanage -r`, `qlmanage -r cache`, `/tmp/alhangeul-ql` 생성은 thumbnail smoke의 필수 전제이며 생략하지 않는다.
- Release 설치본 갱신과 smoke 확인이 끝난 뒤에만 Debug `DerivedData` 삭제를 제안한다.

## 승인 요청 형식

삭제 전에는 다음 형식으로 보고하고 멈춘다.

```text
dry-run 결과:
- safe: {경로, 크기, 이유}
- approval-required: {경로, 크기, 이유, 복구 방법}
- never-delete: {경로, 보호 이유}

삭제 승인 요청:
- 삭제 대상: {개별 절대 경로 목록}
- 예상 회수 용량: {합계}
- 복구 방법: {재생성 명령 또는 보존 불가 설명}
```

Release 설치본 갱신은 삭제 승인과 별도로 다음 형식으로 보고하고 멈춘다.

```text
Release 설치본 갱신 승인 요청:
- 교체 대상: $HOME/Applications/AlhangeulMac.app
- 새 bundle: build.noindex/release/AlhangeulMac.app 존재 확인 결과
- 목적: Quick Look/Thumbnail/Viewer smoke 기준 설치본 갱신
- 실행 예정: 기존 설치본 unregister, 표준 설치본 교체, LaunchServices/PlugInKit 등록, Quick Look cache reset, thumbnail smoke
- 이후 cleanup 제안: Release smoke 확인 후 Debug DerivedData 삭제 후보 제안
```

작업지시자가 승인하면 개별 경로만 인자로 넘겨 삭제한다. glob이나 상위 디렉터리 전체 삭제는 사용하지 않는다.

이전 이름 설치본(`RhwpMac.app`, `알한글.app`) 삭제가 승인된 경우에는 LaunchServices 등록을 먼저 해제한 뒤 해당 bundle 경로만 삭제한다.

```bash
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
APP="/absolute/path/to/approved/RhwpMac.app"
"$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
rm -rf "$APP"
```

```bash
rm -rf "/absolute/path/to/approved-artifact"
```

삭제 후에는 같은 후보 수집 명령으로 남은 항목과 회수 용량을 확인해 보고한다.

## 절대 하지 말 것

- 승인 없이 삭제 명령 실행
- `/private/tmp`, `$HOME`, 저장소 루트 같은 상위 디렉터리 삭제
- glob 확장 결과를 확인하지 않은 `rm -rf /private/tmp/rhwp*` 실행
- `git worktree list`에 잡힌 worktree 삭제
- `.git` 또는 gitfile이 있는 경로 삭제
- `$HOME/Applications/AlhangeulMac.app` 삭제를 cleanup 후보로 제안
- 이전 이름 설치본을 충돌 확인과 승인 없이 삭제
- PR merge 후 branch/worktree 정리를 이 Skill에서 수행

## 호출 방법

- Codex: `$project-artifact-cleanup` 또는 `/skills` 메뉴
- Claude Code: `/project-artifact-cleanup`
