# Task M010 #492 Stage 1 완료 보고서

구현계획서: `mydocs/plans/task_m010_492_impl.md`

## 단계 목적

bundled `rhwp-studio`의 글자색과 형광펜 사용자 지정 색상 경로를 같은 macOS WKWebView 환경에서 비교해 실패 경계를 확정한다. generated upstream asset 또는 제품 source를 수정하지 않은 상태에서 CSS-only 보정 가설을 task 전용 app bundle로 검증하고, Stage 2의 최소 변경 범위와 검증 계약을 구현계획서에 고정한다.

## 산출물

| 파일 | 규모 | 내용 |
|------|------|------|
| `mydocs/plans/task_m010_492_impl.md` | 233줄 | 재현 결과, 직접 원인, CSS-only A/B 결과, Stage 2~4 구현·검증 계획 |
| `mydocs/working/task_m010_492_stage1.md` | 본 보고서 | Stage 1 조사·검증 결과와 다음 단계 승인 경계 |
| `mydocs/orders/20260903.md` | 1행 갱신 | `Stage 1 원인 확정·구현계획 작성, Stage 2 승인 대기` 상태 반영 |

task 전용 실험 산출물은 `build.noindex/task492/` 아래에만 두었으며 Git 추적 대상이 아니다.

## 원인 분석 결과

### 기준 경로

- bundled studio 기준은 `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7`이다.
- 글자색 버튼은 `mousedown`에서 `preventDefault()` 후 영구적인 `#text-color-picker`의 합성 `click()`을 호출한다.
- 해당 input은 absolute 위치의 0×0 renderer이며 `.sb-color-wrap`의 visible button 아래쪽에 offset돼 있다.
- 형광펜 `다른 색...`는 실행 시점에 0×0 input을 visible button의 자식으로 만들며, 별도 absolute offset이 없다.

### 기준 앱 재현

| 확인 | 결과 |
|------|------|
| 글자색 버튼 | native color well은 생성되지만 visible popover가 열리지 않음 |
| 글자색 color well 활성화 | 기준 CSS에서는 visible popover가 열리지 않음 |
| 형광펜 `다른 색...` | 같은 process에서 native color popover가 정상 표시됨 |

글자색도 native color well 생성까지 도달하므로 WKWebView color input 미지원, JavaScript handler 미실행 또는 WKUIDelegate 부재는 직접 원인이 아니다. 같은 process의 형광펜 경로가 positive control로 동작하므로 renderer의 DOM 배치와 anchor 영역 차이가 presentation 성공 여부를 가른다.

### CSS-only A/B

tracked source와 app binary를 변경하지 않고 분리된 Debug app bundle의 local overlay에만 다음 값을 실험 적용했다.

- `inset: 0`
- `width: 100%`
- `height: 100%`
- `pointer-events: none`

결과:

- 글자색 버튼에서 native color popover 표시
- 취소 후 동일 버튼으로 반복 표시
- color well 접근성 활성화에서도 popover 표시
- 형광펜 기본 팔레트와 `다른 색...` 경로 유지
- visible button이 기존 `mousedown`과 `preventDefault()`를 계속 소유

따라서 글자색 input의 0×0/offset anchor geometry를 충분 원인으로 확정했다. Stage 2는 기존 CSS overlay와 asset verifier의 최소 변경으로 해결하며 Swift, JavaScript 또는 AppKit color panel bridge는 제외한다.

## 본문 변경 정도 / 본문 무손실 여부

- HostApp Swift source, `RhwpStudioHostBridgeScript`, `RhwpStudioWebView`를 변경하지 않았다.
- bundled `index.html`, hashed JavaScript/CSS, WASM, manifest와 service worker를 변경하지 않았다.
- `rhwp-core.lock`, Rust bridge, framework와 Xcode project를 변경하지 않았다.
- 원본 sample과 사용자 문서는 저장하지 않았다. UI A/B는 `build.noindex/task492/fixtures/`의 HWP 사본으로 수행했다.
- tracked 변경은 구현계획서, 본 Stage 보고서와 오늘할일 상태뿐이다.

## 검증 결과

### Source asset 및 문서 검증

```text
$ bash -n scripts/verify-rhwp-studio-assets.sh
exit 0

$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at .../Sources/HostApp/Resources/rhwp-studio

$ git diff --check -- mydocs/plans/task_m010_492_impl.md
exit 0

$ rg -n "직접 원인|CSS-only A/B|Stage 2|Stage 3|구현계획 승인 요청" \
    mydocs/plans/task_m010_492_impl.md
필수 원인·단계·승인 섹션 확인
```

### HostApp Debug build 및 bundle 검증

최초 sandbox 실행은 Sparkle repository DNS 접근 제한으로 package resolve 단계에서 실패했다. 같은 명령을 승인된 네트워크 환경에서 다시 실행해 source 실패와 분리했다.

```text
$ xcodebuild -project Alhangeul.xcodeproj \
    -scheme HostApp \
    -configuration Debug \
    -derivedDataPath build.noindex/task492/stage1-report \
    CODE_SIGNING_ALLOWED=NO \
    build
** BUILD SUCCEEDED **

$ scripts/verify-rhwp-studio-assets.sh \
    build.noindex/task492/stage1-report/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
OK: rhwp-studio assets verified at build.noindex/task492/stage1-report/.../rhwp-studio

$ cmp \
    Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css \
    build.noindex/task492/stage1-report/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css
exit 0
```

### 등록 위생 확인

```text
$ scripts/check-extension-registration-hygiene.sh --check-only
Development registrations: (none)
Issues: (none)
```

`build.noindex/` 아래 Debug app은 존재하지만 LaunchServices/PlugInKit 개발 등록으로 남아 있지 않다. 설치본 Quick Look/Thumbnail provider가 보고되지 않은 경고는 이 Stage의 HostApp 색상 UI 판정 범위 밖이다.

## 잔여 위험

- Stage 1은 popover presentation과 반복·접근성 activation까지만 확인했다. 실제 색상 적용 후 selection, editor focus와 undo/redo는 아직 검증하지 않았다.
- HWPX 형식의 interaction smoke는 Stage 3에서 수행한다.
- `pointer-events: none`이 다양한 macOS/WebKit 버전에서도 visible button hit target을 안정적으로 보존하는지는 지원 환경 회귀 확인이 필요하다.
- bundled studio 변경으로 `#btn-text-color`, `#text-color-picker` 또는 `.sb-color-wrap` 구조가 바뀌면 local selector가 무효화될 수 있다.
- verifier의 dimension ownership 예외를 넓게 구현하면 upstream toolbar layout 소유 경계가 약화될 수 있으므로 exact selector block만 허용해야 한다.

## 다음 단계 영향

Stage 2 변경 범위는 다음 두 파일로 확정한다.

1. `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`
2. `scripts/verify-rhwp-studio-assets.sh`

CSS는 `#text-color-picker`에 버튼 크기의 anchor를 제공하고 `pointer-events: none`으로 기존 button activation 계약을 보존한다. verifier는 target DOM과 네 declaration을 요구하며, exact color input block 밖의 toolbar dimension 소유는 계속 거부한다.

Swift source, compatibility script, AppKit color panel, generated asset, manifest와 core dependency는 Stage 2 범위에 포함하지 않는다. CSS-only 구현이 승인된 자동·수동 검증에서 실패할 경우 자동 확장하지 않고 범위 보정 승인을 요청한다.

## 승인 요청

1. Stage 1 원인 분석과 CSS-only A/B 판정을 승인해 주기 바란다.
2. 구현계획서의 Stage 2 범위대로 local CSS overlay와 asset verifier 두 파일을 수정할지 승인 요청한다.
3. Stage 2 완료 뒤 별도 단계 보고와 승인을 거쳐 HWP/HWPX interaction smoke로 진입하는 순서를 승인 요청한다.
