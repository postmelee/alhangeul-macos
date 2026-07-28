# Task M010 #442 구현계획서

수행계획서: `mydocs/plans/task_m010_442.md`

이 문서는 Stage 1 조사 결과를 바탕으로 구현 경계와 단계별 변경·검증 방법을 확정한다. 구현계획서 승인 전에는 CSS와 검증 스크립트를 변경하지 않는다. 승인 후 Stage 1은 `task-stage-report` 절차로 조사 결과와 구현계획서를 묶어 종료하고, Stage 2 진입은 단계 보고서에서 다시 승인받는다.

## 작업 개요

- 이슈: #442 `rhwp-studio v0.8.2 반영 후 HostApp 상단 툴바 겹침 수정`
- 마일스톤: M010 (`v0.1`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task442`
- 기준 통합 SHA: `76c86fc76a9e2b7291f80e57b8b85c7c1e1ff525`
- upstream 기준: `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`
- 차단 대상: Issue #441 v0.1.9 public release
- 변경 소유 영역: HostApp bundled rhwp-studio의 Alhangeul local WKWebView overlay

## Stage 1 조사 결론

### 확인된 사실

| 항목 | 확인 결과 | 판단 |
|------|-----------|------|
| upstream provenance | bundled manifest와 upstream `v0.8.2^{commit}`이 모두 `9b16aa9e...` | 잘못된 tag·asset 문제가 아니다. |
| stylesheet 순서 | generated `assets/index-CX93BaKm.css` 다음에 `alhangeul-wkwebview-overrides.css` 로드 | specificity가 같으면 local 선언이 최종 승리한다. |
| upstream 기본 layout | `#style-bar`: flex/wrap, `min-height: 68px`, `height: auto` | desktop ribbon이 여러 group과 label을 포함하도록 확장됐다. |
| upstream 768~1023px layout | `#style-bar`: grid, field 1행 + command 1행, `min-height: 0`, auto content height | 최소 창 구간에서 다중 행 높이가 필요하다. |
| local container override | `#style-bar`: `height/min-height: 32px`, `padding: 3px 8px`, `align-items: center` | 같은 ID specificity와 후순위 load로 upstream auto height를 덮어쓴다. |
| HostApp 최소 폭 | SwiftUI root `minWidth: 900` | 앱의 일반 최소 창이 정확히 upstream 768~1023px responsive 구간에 들어간다. |
| local field width | style/language/font `72/52/132px` | upstream v0.8.2 `88/64/160px`보다 작고 새 field grid ownership을 덮어쓴다. |
| local control metric | select와 size/spacing group을 24px로 고정 | upstream v0.8.2의 27px ribbon control rhythm과 다르다. |
| local overlay 이력 | Task #134에서 WKWebView native select metric 보정으로 도입, Task #140에서 line-spacing select까지 확장 | overlay 전체 삭제는 기존 WKWebView 회귀를 재도입할 위험이 있다. |
| upstream 이전 기준 | v0.7.18 style bar는 단일 행 28px, field 폭 `60/44/110px`, control 22px | local 32px/24px 보정은 이전 구조에서는 합리적이었으나 v0.8.2에서 stale해졌다. |
| 현재 asset verifier | manifest, entrypoint, 파일 수, override 존재·link는 검증하고 정상 통과 | local CSS가 upstream layout을 덮는지는 탐지하지 못한다. |
| v0.8.2 이후 upstream | `upstream/main`에서 style bar, responsive, toolbar, index 관련 후속 commit 없음 | 이번 release blocker는 local overlay에서 해결한다. |

### 직접 원인

1023px 이하에서는 upstream과 local CSS가 함께 적용된다. upstream은 `display: grid`와 두 행 배치를 제공하지만 local stylesheet가 동일한 `#style-bar` ID selector로 고정 높이 32px를 나중에 적용한다. grid 자식은 필요한 높이로 계속 배치되지만 container와 다음 editor 영역의 layout height는 32px로 제한되어 control이 겹치고 잘린다.

1024px 이상에서도 local 32px 고정 높이가 upstream desktop ribbon의 68px 최소 높이와 label 영역을 무효화한다. 창이 매우 넓으면 자식이 한 줄에 가까워져 덜 깨져 보일 뿐, upstream ribbon layout이 정상 복원된 상태는 아니다.

### 구현 대안

| 대안 | 장점 | 문제 | 선택 |
|------|------|------|------|
| A. local 숫자를 v0.8.2 값으로 갱신 | 변경량이 작아 보임 | 다음 upstream layout 변경 때 다시 stale하고 responsive breakpoint별 ownership 충돌이 남음 | 제외 |
| B. local override 전체 제거 | upstream layout을 완전히 따름 | Task #134/#140에서 해결한 WKWebView native select text·indicator 문제가 재발할 수 있음 | 제외 |
| C. local override를 select 표현 전용으로 축소 | upstream layout과 기존 WKWebView 보정을 함께 보존 | select 내부 metric을 27px rhythm에 맞춰 다시 검증해야 함 | 채택 |

## CSS ownership 계약

### upstream 소유

- `#style-bar` display, wrapping, grid, height/min-height, padding, alignment와 overflow
- style/language/font 및 line-spacing field 폭
- size/line-spacing group과 input/button의 height, alignment, border geometry
- breakpoint별 ribbon group, field grid와 label 배치
- 기본 control font size와 27px control rhythm

### Alhangeul local overlay 소유

- `select.sb-combo`, `select.sb-ls-select`의 `-webkit-appearance`/`appearance`
- native select 내부 text metric을 위한 line-height와 좌우 padding
- CSS dropdown indicator의 paint, 위치와 theme-aware 색상
- disabled select의 text/background theme token
- custom indicator를 사용하는 line-spacing select의 왼쪽 text alignment

### local overlay 금지

- `#style-bar`, `#style-name`, `.sb-font-lang`, `.sb-font` 직접 selector
- `.sb-size-group`, `.sb-size`, `.sb-size-unit`, `.sb-size-arrows`
- `.sb-ls-group`, `.sb-ls-arrows`, `.sb-arrow`
- 독립 `width`, `height`, `min-height`, `align-items` 선언
- upstream hashed CSS/JS 수정

## Stage 2. WKWebView overlay 축소와 ownership guard

### 목표

upstream v0.8.2 ribbon/responsive layout을 복원하면서 WKWebView select 표현 보정만 유지하고, 같은 구조 충돌이 재도입되면 기존 asset verification이 실패하도록 한다.

### CSS 변경

`Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`를 다음 기준으로 축소한다.

1. `#style-bar` block을 제거한다.
2. `#style-name`, `.sb-font-lang`, `.sb-font` width/font-size block을 제거한다.
3. size 및 line-spacing group/input/arrow의 24px block을 모두 제거한다.
4. `select.sb-combo`, `select.sb-ls-select`에서 `height`와 `min-height`를 제거해 upstream 27px 높이를 사용한다.
5. 27px border-box와 상하 1px padding에 맞춰 select `line-height`를 23px 기준으로 조정한다.
6. dropdown indicator의 세로 위치를 27px control 중심에 맞추고 `#555` 대신 `var(--color-text-secondary)`를 사용한다.
7. disabled background의 hard-coded `#f4f4f4`를 `var(--ui-surface-muted)`로 바꾼다.
8. line-spacing select는 upstream width와 font-size를 사용하고, `text-align: left`, 오른쪽 padding과 indicator 위치만 local에서 유지한다.
9. 파일 주석에 “upstream owns layout, local owns WKWebView select presentation” 경계를 명시한다.

23px line-height와 indicator 위치는 구현 기준값이다. 실제 WKWebView에서 수직 정렬이 어긋나면 Stage 2 안에서 select 내부 metric만 조정하고, container/field dimension을 다시 추가하지 않는다.

### verifier 변경

`scripts/verify-rhwp-studio-assets.sh`에 local override ownership 검사를 추가한다.

- `select.sb-combo`와 `select.sb-ls-select` 보정 존재 확인
- 금지 selector가 top-level rule로 다시 나타나면 실패
- `width`, `height`, `min-height`, `align-items` 독립 선언이 local override에 나타나면 실패
- 실패 메시지에 upstream layout ownership과 문제 파일을 표시
- source resource와 Debug app bundle resource 모두 같은 검사 적용

검사 정규식은 `line-height`와 `background-size`를 금지 property로 오인하지 않아야 한다. 정상 파일 통과 외에 task 전용 임시 resource 복사본에 `#style-bar { height: 32px; }`를 삽입했을 때 의도된 FAIL이 발생하는 negative test를 수행한다. 임시 복사본은 `build.noindex/` 아래에 두고 tracked source와 구분한다.

### 변경 파일

- `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`
- `scripts/verify-rhwp-studio-assets.sh`
- `mydocs/working/task_m010_442_stage2.md`
- `mydocs/orders/20260728.md`

### 검증

```bash
bash -n scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh
! rg -n "#style-bar|#style-name|\\.sb-font-lang|\\.sb-font[[:space:]]*\\{|\\.sb-size|\\.sb-ls-group|\\.sb-ls-arrows|^[[:space:]]*\\.sb-arrow" \
  Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css
rg -n "select\\.sb-combo|select\\.sb-ls-select|line-height: 23px|color-text-secondary|ui-surface-muted" \
  Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css
git diff --check -- Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css scripts/verify-rhwp-studio-assets.sh mydocs
```

첫 번째 CSS `rg`는 구현 후 결과가 없어야 한다. ownership negative test는 임시 resource 복사본에 대해서만 실패해야 하며 source resource 검증은 통과해야 한다.

### 완료 조건

- upstream layout selector와 dimension이 local overlay에서 제거돼 있다.
- WKWebView select appearance/text/indicator 보정은 유지된다.
- light/dark theme token을 사용하고 hard-coded disabled/indicator color가 없다.
- asset verifier가 정상 source에서는 통과하고 stale layout override를 넣은 임시 복사본에서는 실패한다.
- generated upstream asset, manifest와 core provenance에는 diff가 없다.

### 커밋

```text
Task #442 Stage 2: WKWebView override와 upstream layout 경계 복원
```

## Stage 3. HostApp build와 breakpoint visual QA

### 목표

수정 resource가 실제 app bundle에 포함되는지 확인하고, upstream breakpoint 전후와 문서 상태·theme별로 겹침·clipping이 사라졌으며 select 보정이 유지되는지 검증한다.

### 준비와 자동 검증

```bash
./scripts/build-rust-macos.sh --verify-lock
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
cmp \
  Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css \
  build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css
git status --short
git diff --check
```

`xcodegen generate` 뒤 `project.yml`과 generated project에 Task #442와 무관한 drift가 생기면 자동 수정하지 않고 보고한다.

### visual matrix

외부 window 크기만 기록하지 않고 Web Inspector의 `window.innerWidth`를 기준으로 다음 폭을 맞춘다.

| CSS viewport | 예상 upstream mode | 확인 기준 |
|--------------|--------------------|-----------|
| 900px | tablet grid | field 행과 command 행이 container 안에 있고 editor와 겹치지 않음 |
| 1023px | tablet grid 경계 | 두 행, control clipping 없음 |
| 1024px | desktop ribbon 시작 | 68px ribbon과 label 영역 정상 |
| 1280px | desktop ribbon | group separator, label, field width 정상 |
| wide | desktop ribbon | 넓은 화면에서도 upstream group 구조와 높이 유지 |

각 폭에서 다음 조합을 확인한다.

- light와 dark
- 빈 문서
- `samples/basic/KTX.hwp`
- `samples/hwpx/hwpx-01.hwpx`
- style, language, font, font size, line spacing select
- size/line-spacing arrow와 character/paragraph button

closed control의 bounding rectangle가 `#style-bar` 경계를 벗어나지 않는지, document root에 의도하지 않은 horizontal overflow가 없는지 Web Inspector로 확인한다. dropdown을 열었을 때 popup 자체가 container 밖에 표시되는 것은 정상이며 clipping 판정 대상에서 제외한다.

검증 스크린샷과 측정 메모는 `build.noindex/task442-visual/`에 저장하고 단계 보고서에는 viewport, theme, document 상태와 판정만 기록한다. Debug 앱 실행으로 생길 수 있는 LaunchServices 등록은 Finder/Quick Look 판정에 사용하지 않으며 필요 시 표준 hygiene 절차만 적용한다.

### 완료 조건

- Debug build와 source/bundle asset 검증이 통과한다.
- 5개 viewport의 light/dark에서 toolbar/style bar와 editor 겹침·clipping이 없다.
- 1023/1024px breakpoint 전환이 upstream 설계대로 동작한다.
- 빈 문서와 HWP/HWPX 상태에서 select text, indicator와 control 상호작용이 정상이다.
- 관련 없는 project/source drift와 개발 extension 등록 잔존이 없다.

### 커밋

```text
Task #442 Stage 3: HostApp 툴바 breakpoint 회귀 검증
```

## Stage 4. 최종 보고와 PR 게시

### 작업

1. Stage 1~3 변경·검증 결과와 visual matrix를 최종 보고서에 정리한다.
2. Issue #441 차단 해제 조건과 “기존 rehearsal artifact 재사용 금지”를 명시한다.
3. `task-final-report` 승인 절차로 최종 문서와 오늘할일을 마무리한다.
4. `publish/task442`를 push하고 `devel` 대상 ready PR을 생성한다.
5. PR CI의 classification, asset verification, Rust/core provenance, HostApp build와 release helper checks를 확인한다.

Task #442 PR은 source overlay와 verifier, task 문서만 포함한다. version/build, release record, tag, GitHub Release와 배포 workflow는 변경하지 않는다.

### 완료 조건

- 최종 보고서와 PR body가 Issue #442 범위·검증 결과를 일치하게 설명한다.
- `devel` 대상 PR이 conflict 없이 열리고 필수 CI가 통과한다.
- merge는 작업지시자의 별도 승인을 기다린다.

## Stage 5. Merge 정리와 Issue #441 인계

### 작업

1. Task #442 PR merge 확인 후 `pr-merge-cleanup` 승인 절차로 issue, branch와 worktree 부산물을 정리한다.
2. Issue #441 작업 브랜치에 새 `devel` merge SHA를 반영할 방법을 확인한다.
3. candidate SHA가 Task #442 merge를 포함하는지 ancestry로 검증한다.
4. Issue #441 Stage 3 candidate build와 Release Rehearsal을 기존 성공 run 재사용 없이 다시 수행하도록 인계한다.

Task #442에서는 Issue #441 브랜치를 임의로 변경하거나 release workflow를 실행하지 않는다. 인계 뒤 실제 candidate 갱신과 Rehearsal은 Issue #441 단계 승인으로 진행한다.

## Stage 1 검증

구현계획서 승인 뒤 Stage 1 종료 보고 전에 다음을 실행한다.

```bash
test "$(git -C /Users/melee/Documents/projects/forks/rhwp rev-parse 'v0.8.2^{commit}')" = \
  "9b16aa9e23f476e2b335d7c029fc9f24a199d63c"
scripts/verify-rhwp-studio-assets.sh
rg -n "height: 32px|min-height: 32px|#style-name|\\.sb-font-lang|\\.sb-font|\\.sb-size-group|\\.sb-ls-group" \
  Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css
rg -n "minWidth: 900" Sources/HostApp/HostApp.swift
rg -n "upstream 소유|Alhangeul local overlay 소유|local overlay 금지|Stage 2|Stage 3|Stage 4|Stage 5" \
  mydocs/plans/task_m010_442_impl.md
awk '/[[:blank:]]$/ { print FNR ":" $0; bad=1 } END { exit bad }' \
  mydocs/plans/task_m010_442_impl.md
git diff --check
```

첫 번째 override `rg`는 현재 회귀 원인 selector가 실제로 존재함을 확인하는 Stage 1 증거 명령이다. Stage 2에서는 같은 selector 검색 결과가 없어야 한다.

## 중단·재승인 조건

- select-only 변경으로도 900~1023px에서 clipping이 남음
- 정상 upstream responsive rule 자체에서 겹침이 재현됨
- WKWebView select 보정을 제거하지 않고는 layout을 복원할 수 없음
- generated upstream asset 또는 manifest 수정이 필요함
- HostApp Swift/JavaScript bridge 변경이 필요함
- verifier guard가 정상 upstream sync 또는 합법적인 platform 보정을 막음
- v0.8.2 이후 upstream의 동일 영역 수정이 새로 확인됨
- Issue #442 범위를 넘어 renderer, release version/build 또는 배포 변경이 필요함

이 조건 중 하나가 발생하면 관련 파일을 임의로 고치지 않고 증거, 영향과 최소 범위 보정안을 보고해 수행·구현계획 수정 승인을 요청한다.
