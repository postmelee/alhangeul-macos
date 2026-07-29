# Task M010 #442 Stage 2 완료보고서

## 단계 목적

rhwp-studio v0.8.2의 ribbon/responsive layout을 다시 upstream 소유로 돌리고, Alhangeul local stylesheet는 macOS WKWebView native select 표현만 보정하도록 축소한다. 같은 fixed-height·field-width 충돌이 다시 들어오면 기존 bundled asset verifier가 실패하도록 ownership guard를 추가한다.

## 산출물

- `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`
  - 101줄에서 39줄로 축소
  - upstream layout selector와 24/32px dimension 제거
  - WKWebView select appearance, text metric, indicator와 disabled theme 보정 유지
- `scripts/verify-rhwp-studio-assets.sh`
  - 154줄에서 180줄로 증가
  - required select presentation과 forbidden layout selector/dimension 검증 추가
- `mydocs/working/task_m010_442_stage2.md`
  - Stage 2 구현·검증 결과와 Stage 3 영향 기록
- `mydocs/orders/20260728.md`
  - Issue #442 비고를 `Stage 2 완료 · Stage 3 승인 대기`로 갱신

전체 제품 변경은 2개 파일, 37줄 추가와 73줄 삭제다.

## 본문 변경 정도 / 본문 무손실 여부

- upstream hashed CSS/JS, `index.html`, manifest, WASM, core lock과 Swift source는 변경하지 않았다.
- local overlay의 Task #134/#140 WKWebView select 보정 목적은 유지하고, upstream과 충돌하던 container/field/group dimension만 제거했다.
- verifier의 기존 argument, manifest, entrypoint, asset count, hash/provenance 검증은 변경하지 않고 ownership 검사를 앞단에 추가했다.
- `--help`, 기본 source 검증과 `--resource-dir` 검증 인터페이스를 보존했다.
- 오늘할일은 Issue #442 행의 진행 단계 비고만 변경했다.

## 구현 결과

### WKWebView overlay

- `#style-bar` 32px fixed height, padding과 alignment 제거
- `#style-name`, `.sb-font-lang`, `.sb-font`의 stale width/font-size 제거
- size/line-spacing group, input와 arrow의 24px dimension 제거
- select `height/min-height` 제거 후 upstream 27px control 사용
- 27px border-box에 맞춰 `line-height: 23px` 적용
- indicator 세로 위치를 `center`로 변경해 control height에 종속되지 않게 함
- indicator 색상을 `var(--color-text-secondary)`로 변경
- disabled background를 `var(--ui-surface-muted)`로 변경
- line-spacing select는 upstream width/font-size를 사용하고 local text alignment, padding, indicator만 유지

### Ownership guard

`verify_local_override_ownership`은 다음을 검사한다.

- `select.sb-combo`, `select.sb-ls-select`, `appearance: none` 존재
- `#style-bar`, field width selector, size/line-spacing group과 arrow selector 금지
- 독립 `width`, `height`, `min-height`, `align-items` property 금지

property regex는 line 시작과 정확한 property name을 기준으로 하므로 허용된 `line-height`와 `background-size`를 잘못 차단하지 않는다. source positive verification이 두 property를 포함한 상태에서 통과해 이를 확인했다.

## 검증 결과

Shell syntax와 정적 검사:

```text
PASS: bash -n scripts/verify-rhwp-studio-assets.sh
PASS: shellcheck scripts/verify-rhwp-studio-assets.sh
PASS: scripts/verify-rhwp-studio-assets.sh --help
PASS: git diff --check
```

정상 source positive verification:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac-task442/Sources/HostApp/Resources/rhwp-studio
```

금지된 stale selector 검색:

```text
PASS: #style-bar, #style-name, stale field/group/arrow selector 결과 없음
```

유지된 select presentation:

```text
7:  select.sb-combo,
8:  select.sb-ls-select {
11:    line-height: 23px;
16:      linear-gradient(45deg, transparent 50%, var(--color-text-secondary) 50%),
17:      linear-gradient(135deg, var(--color-text-secondary) 50%, transparent 50%);
26:  select.sb-combo:disabled,
27:  select.sb-ls-select:disabled {
29:    background-color: var(--ui-surface-muted);
32:  select.sb-ls-select {
```

task 전용 임시 resource에 `#style-bar { height: 32px; }`를 삽입한 selector negative verification:

```text
41:#style-bar {
FAIL: Alhangeul WKWebView override must not own upstream toolbar layout selectors
EXPECTED_FAIL: stale layout override rejected
```

같은 임시 resource에서 forbidden selector를 제거하고 허용된 select rule에 `height: 32px`를 삽입한 dimension negative verification:

```text
33:    height: 32px;
FAIL: Alhangeul WKWebView override must not own upstream control dimensions
EXPECTED_FAIL: stale control dimension rejected
```

negative fixture는 `/private/tmp/alhangeul-task442-negative.9VNBOp`에 격리했고 검증 후 제거했다. 제거 뒤 source verifier를 다시 실행해 정상 통과를 확인했다.

## 잔여 위험

- 정적 검증만으로 실제 WKWebView의 select text 수직 정렬과 indicator 위치를 확정할 수 없다.
- upstream layout 복원 후 900~1023px 두 행 grid의 실제 높이, editor 경계와 control clipping은 Debug app에서 확인해야 한다.
- 1023/1024px breakpoint 전환에서 정상적인 ribbon 높이 변화가 크므로 viewport별 기대값과 실제 겹침을 분리해 판정해야 한다.
- disabled select의 `var(--ui-surface-muted)` 대비는 light/dark mode에서 각각 확인해야 한다.
- verifier regex는 승인된 현재 ownership 계약을 강제하므로 future platform 보정에서 layout selector가 정말 필요해지면 구현계획 보정이 선행돼야 한다.
- source resource가 정상이어도 stale DerivedData app을 실행하면 수정 전 UI가 보일 수 있다.

## 다음 단계 영향

Stage 3에서는 새 worktree에서 Rust bridge artifact와 HostApp Debug app을 `build.noindex/`에 생성한다. source와 built app bundle에 같은 local override가 포함됐는지 verifier와 `cmp`로 확인한 뒤, Web Inspector의 `window.innerWidth` 기준 900, 1023, 1024, 1280px와 wide viewport에서 light/dark, 빈 문서/HWP/HWPX visual·interaction matrix를 수행한다.

Debug build나 앱 실행 과정에서 관련 없는 generated project drift 또는 개발 extension 등록 오염이 확인되면 임의 수정하지 않고 보고한다. Stage 3는 source 구현을 추가하는 단계가 아니라 현재 CSS 변경을 실제 WKWebView에서 검증하는 단계다.

## 승인 요청

이 Stage 2 결과를 승인하고 Stage 3의 HostApp build, source/bundle asset 확인과 breakpoint별 visual·interaction QA를 진행할지 승인 요청한다.

Stage 3 승인 전에는 Debug build, 앱 실행 또는 추가 source 변경을 진행하지 않는다.
