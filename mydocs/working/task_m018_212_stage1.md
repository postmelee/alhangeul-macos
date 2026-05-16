# Task M018 #212 Stage 1 완료 보고서

## 단계 목적

#212 구현 전에 #206과의 변경 경계를 고정하고, 현재 Pages footer와 `/updates/` 안내의 수정 지점을 확인했다. 이번 단계는 현황 조사와 범위 확정 단계이며 `docs/` 소스는 아직 변경하지 않았다.

## #206 병행 작업 상태

현재 #206은 별도 worktree `/Users/melee/Documents/projects/rhwp-mac`의 `local/task206`에서 진행 중이다.

확인한 최신 #206 커밋:

| commit | 내용 |
|--------|------|
| `6161a12` | Task #206 Stage 2: Pages artifact helper 추가 |
| `dfaa349` | Task #206 Stage 1: Pages deploy-pages 전환 기준 확정 |
| `d19a768` | Task #206: 구현 계획서 작성 |
| `07f7fb7` | Task #206: 수행 계획서 작성과 오늘할일 갱신 |

`origin/devel-webview...local/task206` 기준 변경 파일:

| 상태 | 파일 |
|------|------|
| M | `.github/workflows/pr-ci.yml` |
| M | `mydocs/orders/20260510.md` |
| A | `mydocs/plans/task_m018_206.md` |
| A | `mydocs/plans/task_m018_206_impl.md` |
| A | `mydocs/working/task_m018_206_stage1.md` |
| A | `mydocs/working/task_m018_206_stage2.md` |
| A | `scripts/ci/prepare-pages-artifact.sh` |

#206 구현계획상 향후 주 변경 대상은 release workflow, Pages artifact helper, release/CI 운영 문서다. #206 계획은 Pages site redesign 또는 사용자-facing copy 전면 수정을 제외하고 있다.

## #212 수정 경계

#212는 다음 사용자-facing 정적 페이지와 CSS만 수정한다.

| 파일 | 수정 목적 |
|------|----------|
| `docs/index.html` | 홈 footer 문구를 승인 문구로 통일 |
| `docs/updates/index.html` | `/updates/` 업데이트 안내 단순화, appcast URL 설명 위계 조정, footer 문구 통일 |
| `docs/updates/v0.1.0.html` | 릴리즈 노트 footer 문구 통일 |
| `docs/updates/v0.1.1.html` | 릴리즈 노트 footer 문구 통일 |
| `docs/styles.css` | footer desktop/중간/mobile responsive layout 보정 |

이번 작업에서 제외하는 파일과 범위:

- `.github/` workflow
- `scripts/ci/` helper
- `docs/appcast.xml`
- Pages source, deploy-pages, appcast publish 방식
- Sparkle appcast item, release asset URL, EdDSA signature
- macOS 앱의 `SUFeedURL` 또는 Sparkle 설정

따라서 현재 #206과 #212의 직접 파일 충돌은 `mydocs/orders/20260510.md`를 제외하면 없다. 오늘할일 파일은 각 브랜치에서 task별 상태를 독립 갱신하므로 최종 PR 단계에서 통합 시 확인한다.

## 현재 Pages 상태

Footer 문구:

- `docs/index.html` footer는 “문서 접근은 특정 프로그램 구매 여부...” 문구를 사용한다.
- `docs/updates/index.html`, `docs/updates/v0.1.0.html`, `docs/updates/v0.1.1.html` footer는 “Mac을 위한 HWP/HWPX 문서 미리보기 및 뷰어 앱입니다...” 문구를 사용한다.
- 승인된 통일 문구는 “Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.”이다.

`/updates/` 업데이트 안내:

- `docs/updates/index.html`은 “앱에서 확인” 아래에 `수동 확인`, `자동 확인` 카드 2개를 둔다.
- 같은 페이지는 `Sparkle appcast URL`을 별도 큰 섹션으로 표시한다.
- Stage 2에서는 카드 2개를 일반 사용자용 단일 안내 흐름으로 합치고, appcast URL은 앱이 사용하는 고정 업데이트 feed라는 보조 설명으로 낮춘다.

Footer CSS:

- 기본 `.site-footer`는 `minmax(140px, 1fr) minmax(0, 760px) max-content` 3열 grid다.
- `@media (max-width: 1180px)`에서 footer가 2열로 바뀌고 nav가 `grid-column: 2`, `justify-self: start`로 내려간다.
- `@media (max-width: 820px)`에서 1열 stack으로 바뀐다.
- Stage 3에서는 desktop과 중간 폭에서 nav를 우측에 유지하고 설명 문구만 중앙 영역에서 줄바꿈되도록 조정한다. 모바일 1열 stack은 유지한다.

## 검증 결과

```bash
git status --short --branch
```

결과: `## local/task212...origin/devel-webview [ahead 2]`

```bash
git diff --name-status origin/devel-webview...local/task206
```

결과 요약: #206은 `.github/workflows/pr-ci.yml`, `scripts/ci/prepare-pages-artifact.sh`, #206 작업 문서만 변경했다. `docs/` 변경은 없다.

```bash
rg -n "Mac을 위한 HWP/HWPX|수동 확인|자동 확인|Sparkle appcast|site-footer|@media \(max-width: 1180px\)" docs
```

결과 요약:

- footer 문구 불일치 위치 확인
- `/updates/`의 `수동 확인`, `자동 확인`, `Sparkle appcast URL` 위치 확인
- footer CSS와 `1180px` breakpoint 위치 확인

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

## 산출물

- `mydocs/working/task_m018_212_stage1.md`: #206 병행 작업과 #212 수정 경계 기록

본문 변경 정도 / 본문 무손실 여부: 해당 없음. 이번 단계는 신규 보고서 작성만 수행했고 사용자-facing Pages 소스는 변경하지 않았다.

## 다음 단계

Stage 2에서는 footer 문구와 `/updates/` HTML 안내를 보정한다. 이때 `docs/appcast.xml`, workflow, release helper는 변경하지 않는다.

## 승인 요청

Stage 1 산출물 승인을 요청한다.

승인 후 Stage 2 `Footer 문구와 업데이트 안내 HTML 보정`으로 진행한다.
