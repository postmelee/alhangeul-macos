# Task #442 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#442 rhwp-studio v0.8.2 반영 후 HostApp 상단 툴바 겹침 수정](https://github.com/postmelee/alhangeul-macos/issues/442) |
| 마일스톤 | M010 `v0.1` |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task442` |
| upstream 기준 | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| 차단 대상 | [#441 v0.1.9 Release Operations](https://github.com/postmelee/alhangeul-macos/issues/441) |
| 단계 | Stage 1~4 |

rhwp-studio v0.8.2의 responsive ribbon과 충돌하던 HostApp WKWebView
전용 고정 높이·필드 폭 override를 제거했다. Alhangeul local stylesheet는
macOS WKWebView native select의 appearance, 내부 text metric, indicator와
disabled theme 표현만 보정하도록 축소했다.

핵심 결론:

- 회귀의 직접 원인은 upstream asset이나 breakpoint가 아니라, v0.7.x 단일 행
  UI 기준으로 남아 있던 local `#style-bar` 32px 고정 높이였다.
- upstream은 toolbar/ribbon 구조와 responsive layout을 소유하고, Alhangeul은
  WKWebView select presentation만 소유하도록 경계를 복원했다.
- asset verifier에 ownership guard를 추가해 fixed-height, field width와 control
  dimension이 local overlay에 다시 들어오면 검증이 실패한다.
- 900, 1023, 1024, 1280, 1600px에서 light/dark와 빈 문서/HWP/HWPX 조합을
  검증했고 control 경계 이탈과 의도하지 않은 수평 overflow가 없었다.
- version/build, release record, tag, GitHub Release와 배포 workflow는 변경하거나
  실행하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css` | stale toolbar/ribbon layout selector와 dimension을 제거하고 WKWebView select presentation만 유지 |
| `scripts/verify-rhwp-studio-assets.sh` | local override의 필수 select 보정과 금지 layout selector/dimension ownership guard 추가 |
| `mydocs/plans/task_m010_442.md` | 회귀 배경, 작업 범위, 검증 matrix와 #441 release handoff 정의 |
| `mydocs/plans/task_m010_442_impl.md` | Stage 1~5 구현·검증 절차, CSS ownership 계약과 중단 조건 정의 |
| `mydocs/working/task_m010_442_stage1.md` | upstream/local CSS 조사, 직접 원인과 select-only 구현 경계 확정 |
| `mydocs/working/task_m010_442_stage2.md` | local overlay 축소, ownership guard positive/negative 검증 기록 |
| `mydocs/working/task_m010_442_stage3.md` | Rust/HostApp build, breakpoint visual matrix, interaction과 등록 위생 결과 기록 |
| `mydocs/report/task_m010_442_report.md` | Stage 1~4 최종 결과, 수용 기준과 #441 차단 해제 조건 정리 |
| `mydocs/orders/20260728.md` | #442 작업 등록과 Stage 1~2 진행 기록 |
| `mydocs/orders/20260729.md` | Stage 3~4 진행 상태와 완료 시각 기록 |

제품 동작 변경은 CSS와 verifier 두 파일로 제한된다. upstream hashed CSS/JS,
`index.html`, manifest, WASM, core lock, Rust/Swift source, `project.yml`과
generated Xcode project에는 Task #442 diff가 없다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행 계획 | `48ffef2` | 이슈·브랜치·오늘할일과 breakpoint 검증 범위 등록 |
| Stage 1 | `136119b` | local 32px fixed-height override를 직접 원인으로 확정하고 CSS ownership 계약 수립 |
| Stage 2 | `c45fb4a` | select-only overlay로 축소하고 stale layout 재도입 방지 guard 추가 |
| Stage 3 | `f5ba498` | HostApp build, 5개 viewport, light/dark, 빈 문서/HWP/HWPX visual·interaction 검증 완료 |
| Stage 4 | 이번 커밋 | 최종 수용 검증, 보고서와 #441 release handoff 정리 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| local override | 101줄 | 39줄 |
| 제품 diff | 없음 | 2개 파일, `+37 / -73` |
| asset verifier | 154줄, asset 존재·provenance 중심 | 180줄, select presentation과 layout ownership guard 포함 |
| `#style-bar` layout | local `height/min-height: 32px`가 upstream auto height를 덮음 | upstream tablet grid와 desktop ribbon 높이를 그대로 사용 |
| local field/control dimension | style/language/font width와 size/spacing 24px 고정 | 독립 width/height/min-height/align-items 0건 |
| visual viewport | 최소·일반 폭 회귀 | 900/1023/1024/1280/1600px PASS |
| visible style controls | clipping 여부 미검증 | 각 probe 22개, 경계 이탈 0건 |
| document root overflow | 좁은 조건에서 사용자 제보 | Task #442 probe 전 구간 없음 |
| 실제 앱 캡처 | release 후보에서 겹침 확인 | 20개 허용 캡처 PASS |

첨부 화면과 같은 1110px 조건을 추가로 비교했다.

| resource | document width | style bar 경계 이탈 | 판정 |
|----------|----------------|----------------------|------|
| 설치된 Alhangeul v0.1.8 | client 1110px / scroll 1227px | 0 | 아이콘 툴바 수평 잘림 재현 |
| 기존 v0.1.9 rehearsal artifact | client 1110px / scroll 1110px | 22 | upstream 아이콘 줄바꿈은 적용됐으나 stale local style bar 유지 |
| Task #442 Debug | client 1110px / scroll 1110px | 0 | 아이콘 툴바와 style bar 모두 정상 |

upstream 아이콘 툴바 줄바꿈은
[`2307a5c` fix(studio): wrap icon toolbar groups on narrow screens (#3243)](https://github.com/edwardkim/rhwp/commit/2307a5c992824b2a33a8277db4023642a30c2a53)
에서 반영됐고 v0.8.2에 포함돼 있다. 따라서 Task #442에서는 별도
`#icon-toolbar` local override를 추가하지 않았다.

## 검증 결과

### 수용 기준

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| local overlay가 upstream layout을 덮지 않음 | OK | 금지 selector와 독립 dimension 검색 결과 없음 |
| WKWebView select 표현 보정 유지 | OK | appearance, 23px line-height, indicator와 theme token 유지 |
| stale layout 재도입 방지 | OK | source positive PASS, selector/dimension negative fixture EXPECTED_FAIL |
| core/studio provenance 유지 | OK | `v0.8.2` / `9b16aa9…`, lock·header·15개 FFI symbol 검증 |
| HostApp Debug build | OK | `CODE_SIGNING_ALLOWED=NO` build 성공 |
| source/bundle resource 정합성 | OK | 양쪽 asset verifier 통과, override `cmp` 일치 |
| 1023/1024px breakpoint 전환 | OK | 1023px grid 86px, 1024px flex 69px |
| control clipping·수평 overflow 제거 | OK | 5개 viewport에서 경계 이탈 0, overflow 없음 |
| light/dark와 빈 문서/HWP/HWPX | OK | 실제 앱 matrix와 off-screen metric 교차 검증 |
| 개발 등록 위생 | OK | development/legacy registration과 issue 없음 |
| release 범위 비변경 | OK | version/build, release metadata와 workflow diff 없음 |

### Stage 4 재검증

```text
PASS: bash -n scripts/verify-rhwp-studio-assets.sh
PASS: shellcheck scripts/verify-rhwp-studio-assets.sh
PASS: source rhwp-studio asset verification
PASS: Debug app bundle rhwp-studio asset verification
PASS: source/bundle alhangeul-wkwebview-overrides.css cmp
PASS: ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1
      ./scripts/build-rust-macos.sh --verify-lock
PASS: xcodegen generate, tracked project drift 없음
PASS: HostApp Debug xcodebuild
PASS: extension registration hygiene, issue 0
PASS: git diff --check
```

Stage 3 strict Rust verification에서 universal static archive의 local
byte fingerprint만 lock reference와 달랐다.

```text
expected sha256: b35e935283f97c20d41f634f559e623ccd510f54f1341ca83d0f2108345a58eb
actual sha256:   427e4b88300cb732c0c8986889f4ee45859a5a3e1c9a9f06569ac655d980e26f
expected size:   212505600
actual size:     212514296
```

source tag/commit, Cargo lock, generated header와 FFI symbol은 일치했다.
운영 기준에 따라 static archive byte 비교만 제외한 portable gate를 Stage 3과
Stage 4에서 다시 통과했으며 `rhwp-core.lock`은 변경하지 않았다.

## Issue #441 차단 해제와 릴리스 인계

Task #442 PR merge만으로 v0.1.9 공개 릴리스가 승인되는 것은 아니다. #441에서
다음 조건을 모두 충족해야 한다.

1. Task #442 PR merge SHA를 포함한 최신 `devel`을 release candidate 기준으로
   반영한다.
2. 새 candidate SHA로 v0.1.9 package와 DMG를 다시 생성한다.
3. 새 SHA에서 Release Rehearsal과 사용자-facing toolbar visual QA를 다시 수행한다.
4. 서명·공증, Sparkle/Pages, GitHub Release와 Homebrew gate를 #441 절차로
   확인한다.

다음 기존 산출물은 재사용하지 않는다.

- Release Rehearsal run `30365232108`
- candidate `1d358103a877a9d0b6c924a280b84e60e94d6739`
- Task #442 merge 전 생성한 v0.1.9 DMG와 release artifact

Task #442에서는 #441 브랜치, release version/build, tag, public workflow와
배포 시스템을 변경하지 않는다.

## 잔여 위험과 후속 작업

- local Rust/Xcode/build path에서는 `librhwp.a` strict byte reference가 다르다.
  public release workflow에서 source/header/FFI와 portable gate 결과를 함께
  확인해야 한다.
- 실제 native window의 1280/1600px 구간은 현재 디스플레이 제약으로 off-screen
  WKWebView에서 확인했다. 900~1206px은 실제 Debug 앱에서 확인했다.
- registration helper가 Sparkle 내부 `Updater.app` record를 상위
  `Alhangeul.app`으로 집계할 수 있다. 최종 check는 clean이며 이번 UI 회귀
  해결 범위에는 포함하지 않았다.
- 향후 툴바를 여러 줄로 감싸는 대신 한 줄 overflow 메뉴로 재설계하려면
  Alhangeul local CSS가 아니라 upstream rhwp-studio 별도 UX 이슈로 진행한다.
- 새 후속 이슈 등록은 필요하지 않다. v0.1.9 candidate 재생성과 Rehearsal은
  기존 #441에서 이어간다.

## 작업지시자 승인 요청

Stage 1~4 결과와 `devel` 대상 ready PR을 검토하고 merge 여부를 승인 요청한다.
merge 전에는 #441 release candidate 갱신과 Release Rehearsal을 실행하지 않는다.
