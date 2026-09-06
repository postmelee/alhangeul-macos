# Task M010 #492 Stage 2 완료 보고서

구현계획서: `mydocs/plans/task_m010_492_impl.md`

## 단계 목적

Stage 1에서 확인한 글자색 color input의 native popover anchor 문제를 기존 Alhangeul 소유 CSS overlay에서 보정한다. 보정에 필요한 DOM과 CSS 계약을 asset verifier에 고정하고, upstream toolbar layout 소유 경계와 기존 sync 검증이 유지되는지 자동 검증한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css` | 숨은 글자색 input의 anchor 보정 4개 선언과 목적 주석 |
| `scripts/verify-rhwp-studio-assets.sh` | exact selector·declaration·media 검사, dimension ownership 예외 제한, button/input DOM 검사 |
| `scripts/ci/test-rhwp-studio-cargo-lock-verification.sh` | 새 계약에 맞는 resource/upstream fixture, color picker/ownership 27개 사례, production overlay 무손실 검사 |
| `mydocs/plans/task_m010_492_impl.md` | 승인된 CI fixture 추가 범위와 검증 명령 반영 |
| `mydocs/orders/20260904.md` | Stage 2 완료·Stage 3 승인 대기 상태 |
| `mydocs/working/task_m010_492_stage2.md` | 본 단계 결과와 다음 승인 경계 |

## 구현 결과

### CSS 보정

`@media (pointer: fine)` 안의 exact `#text-color-picker` selector에 다음 선언을 추가했다.

```css
inset: 0;
width: 100%;
height: 100%;
pointer-events: none;
```

숨은 input은 기존 `.sb-color-wrap`의 영역을 native popover 기준으로 사용한다. `pointer-events: none`으로 visible button의 기존 `mousedown`과 `preventDefault()`가 입력을 계속 처리하도록 했다. input/change event, formatting command와 형광펜 동적 input은 변경하지 않았다.

### Verifier 보강

- color input 보정은 `pointer: fine` 내부의 단독 `#text-color-picker` rule 하나에만 허용한다.
- 네 declaration은 각각 정확히 한 번 존재해야 하며 값 변경, 중복과 추가 declaration을 거부한다.
- CSS 주석을 제외하고 selector와 declaration을 검사하므로 주석 속 선언을 보정으로 인정하지 않는다.
- 그룹·자손 selector를 통한 dimension 예외 확장을 거부한다.
- exact color input block 밖의 `width`, `height`, `min-height`, `align-items` 금지를 유지한다.
- 기존 upstream toolbar selector 금지와 native select presentation 검사도 유지한다.
- HTML의 button id와 color input id/type을 확인한다. `data-id` 또는 같은 줄의 다른 color input을 대상 input으로 잘못 인정하지 않는다.

### 승인된 테스트 범위 보정

처음 승인된 제품 변경은 CSS와 verifier 두 파일이었다. 기존 CI fixture에는 새 color input DOM과 anchor rule이 없어 강화된 verifier의 첫 gate에서 실패했다. 작업지시자에게 실패 근거와 테스트 전용 세 번째 파일의 필요성을 보고한 뒤 승인받아 fixture를 갱신했다.

기존 Cargo.lock fingerprint, Git checkout identity, PDF font와 sync self-check 검증을 제거하거나 skip하지 않았다. resource fixture와 synthetic upstream HTML을 새 DOM 계약에 맞추고, 기존 CI 실행 경로 안에 다음 color picker/ownership 검증 27개를 추가했다.

| 분류 | 사례 수 | 내용 |
|------|---------|------|
| 정상 | 3 | 기준 fixture, 압축·순서 변경 CSS, input 속성 순서 변경 |
| CSS 실패 | 20 | 4개 선언 각각 누락, 값 변경, 중복·누락 rule, 허용 밖 dimension, 그룹·자손 selector, 잘못된 media, 주석 속 선언, 기존 toolbar selector 금지 |
| DOM 실패 | 4 | button/input id 누락, 다른 color input이 같은 줄에 있는 잘못된 type, `data-id` 오인 방지 |

## 본문 변경 정도 / 본문 무손실 여부

- upstream generated JavaScript/CSS, `index.html`, WASM과 manifest는 변경하지 않았다.
- Swift source, WKUserScript, AppKit bridge와 core dependency는 변경하지 않았다.
- sync helper와 CI workflow 자체는 변경하지 않았다. 기존 fixture 실행 경로를 재사용한다.
- 실제 문서 저장이나 UI interaction은 이 Stage에서 수행하지 않았다.
- fixture 실행 전후 production manifest와 local overlay의 byte-identical 상태를 검사했다.
- 9월 3일 오늘할일 기록은 보존하고 9월 4일 진행 문서를 새로 작성했다.

## 검증 결과

구현계획서의 Stage 2 검증 명령을 모두 실행했다.

```text
$ bash -n scripts/verify-rhwp-studio-assets.sh scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
exit 0

$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio

$ scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
OK: rhwp-studio color picker/ownership fixtures passed (27 cases)
OK: rhwp-studio Cargo.lock fingerprint verification fixtures passed

$ git diff --check
exit 0
```

Stage 2 초기의 기존 fixture 실패는 승인된 fixture 갱신 후 같은 전체 검증 명령에서 해소됐다. 최종 상태에 skip된 검증이나 남은 실패는 없다. HostAppTests, 새 app bundle build와 HWP/HWPX UI smoke는 Stage 3의 별도 검증이며 이 결과에 포함하지 않는다.

## 잔여 위험

- source에 반영한 CSS의 실제 app bundle 포함 여부와 최종 native picker 동작은 Stage 3에서 재검증해야 한다.
- 색상 적용 후 selection, editor focus와 undo/redo는 아직 최종 검증 전이다.
- DOM 검사는 현재 bundled HTML의 target tag/attribute 존재를 검사하는 정적 gate이며 전체 DOM ancestry나 실제 renderer geometry를 대신하지 않는다.
- CSS 검사는 현재 local overlay의 rule/declaration 형식에 한정한다. 범용 CSS parser가 아니므로 새로운 syntax를 도입할 때 검사 계약도 검토해야 한다.
- macOS/WebKit 버전별 native popover 차이는 자동 fixture만으로 보장하지 않는다.

## 다음 단계 영향

Stage 3에서는 이 Stage의 source를 기준으로 HostAppTests와 Debug app을 빌드하고, source/bundle overlay 일치를 확인한다. disposable HWP/HWPX 사본에서 글자색·형광펜 사용자 지정 색상, 취소·반복 실행, 접근성 activation, selection·focus와 undo/redo를 검증한다.

새 JavaScript/Swift/AppKit bridge, upstream asset 변경과 dependency 갱신은 자동으로 추가하지 않는다. Stage 3에서 현재 CSS-only 보정의 한계가 발견되면 구체적인 실패와 최소 변경 범위를 보고하고 별도 승인을 요청한다.

## 승인 요청

Stage 2 구현과 자동 검증 결과를 검토하고, Stage 3 HostApp 빌드·테스트 및 HWP/HWPX interaction smoke 진입을 승인해 주기 바란다.

## Stage 5 대체 사항

이 Stage의 CSS anchor rule과 이를 강제하기 위해 추가한 전용 CSS parser 및 27개 fixture는 PR #493 리뷰 보완에서 제거했다. `.atDocumentEnd` HostApp bridge가 같은 geometry를 인라인 style로 곧 덮으므로 두 계층의 중복 소유와 dead contract를 유지할 실익이 없다는 판단이다.

최종 asset verifier는 HostApp bridge가 의존하는 `#btn-text-color`와 `input#text-color-picker[type=color]` DOM 계약만 유지한다. 일반 toolbar selector·dimension 비소유 guard는 단순 검사로 복구했고, color picker DOM fixture는 기대 건수를 명시적으로 검사하는 6개 사례로 축소했다. 이 보고서는 중간 Stage 수행 이력이며 최종 구조와 검증 결과는 Stage 5 보고서를 기준으로 한다.
