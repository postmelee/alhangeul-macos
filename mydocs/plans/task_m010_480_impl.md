# Task M010 #480 구현계획서

## 1. 개요

- 이슈: [#480 암호 문서를 native 저장할 때 평문으로 덮어쓰는 문제를 수정한다](https://github.com/postmelee/alhangeul-macos/issues/480)
- 마일스톤: `M010` (`v0.1`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task480`
- 게시 브랜치: `publish/task480`
- 수행계획서: `mydocs/plans/task_m010_480.md`
- 단계 수: 4

이 문서는 암호 문서의 무경고 평문 덮어쓰기를 먼저 차단하고, release tag로 제공되는 upstream host API가 준비된 경우에만 native 암호 저장을 연결하는 구현 경계를 정한다. 구현계획 승인 전에는 Stage 1을 시작하지 않으며, 각 Stage 종료 뒤 `task-stage-report` 절차로 결과와 다음 단계 조건을 다시 승인받는다.

## 2. 구현 전 확인 결과

| 항목 | 확인 결과 | 구현 영향 |
|------|-----------|-----------|
| 고정 upstream | `rhwp v0.8.4`, commit `496333b27d21ddb9114ba9ae340bcb895870c9a7` | 이 기준을 바꾸는 경우 release tag와 resolved commit을 함께 고정해야 한다. |
| WASM 암호 export | bundled binding에 `exportHwpWithPassword`, `exportHwpxWithPassword`가 존재한다. | serializer 자체를 새로 구현하지 않고 upstream 표면을 사용한다. |
| upstream Studio UX | `다른 이름으로 저장`에서 암호 설정을 선택하면 password exporter를 호출한다. | native 저장 패널이 이 경로를 가로채는 현재 구조와 기능 차이를 해소해야 한다. |
| Alhangeul 저장 가로채기 | 파일 메뉴와 저장 단축키를 capture 단계에서 가로채 HostApp 저장 흐름으로 전환한다. | upstream Studio의 암호 설정 UI는 native 저장에서 실행되지 않는다. |
| production host RPC | `exportHwp`, `exportHwpx`는 있으나 password exporter와 source protection state는 없다. | 완전한 Stage 3은 승인된 upstream host API와 release tag가 선행되어야 한다. |
| native FFI | `rhwp_open`은 parse 실패를 null로 축약하고 Swift도 일반 parse 실패로 처리한다. | 보호 상태를 안전하게 판정할 별도 typed probe를 검토한다. |
| 현재 write 계약 | 응답 format, base64, byte count, signature를 검증한 뒤 atomic write한다. 보호 상태 검증은 없다. | 암호 문서의 평문 export가 검증을 통과해 원본 URL을 덮어쓸 수 있다. |
| 회귀 fixture | exact upstream checkout에 HWP3/HWP5/HWPX 암호 fixture가 있다. | 사용자 원본 없이 복사본과 hash를 사용해 재현·회귀 검증할 수 있다. |

fixture의 암호는 공개 테스트 전용 값이라도 명령행, 로그, Stage 보고서와 최종 보고서에 기록하지 않는다. 테스트 코드에 값이 필요하면 fixture 전용 상수로 한정하고 운영 암호로 오인될 이름을 사용하지 않는다.

## 3. 공통 설계·보안 원칙

### 3.1 보호 상태와 암호 수명

문서 상태에는 암호 문자열이 아니라 다음과 같은 보호 분류만 둔다.

- `plain`: 보호되지 않은 것으로 확인된 입력
- `passwordProtected`: 암호 보호 입력으로 확인된 상태
- `unsupportedProtection`: 지원하지 않는 보호 방식
- `invalidOrUnknown`: 손상, 판정 실패 또는 불명 상태

실제 암호 문자열은 한 번의 export 요청 범위에서만 사용한다. `PendingSaveRequest`, URL, 파일명, 최근 문서, autosave metadata, `UserDefaults`, Keychain, analytics event, 로그와 오류 메시지에는 보관하지 않는다. JavaScript/native 경계에서도 script 문자열 보간을 피하고, 요청 종료 즉시 입력 필드와 지역 참조를 비운다.

### 3.2 보수적 write 정책

- `plain`은 현행 검증을 통과하면 기존 in-place 저장을 허용한다.
- `passwordProtected`는 보호된 응답을 검증하기 전 원본 URL에 쓰지 않는다.
- `passwordProtected`에서 평문을 선택하면 원본과 다른 URL의 명시적 평문 복사본만 허용하고 보호 해제 경고를 표시한다.
- `unsupportedProtection`과 `invalidOrUnknown`은 in-place overwrite를 금지한다.
- 암호 입력 취소, export 오류, 응답 보호 상태 불일치, byte count/signature 오류, write 오류에서는 원본 byte hash가 유지되어야 한다.
- 보호된 결과는 응답 metadata만 신뢰하지 않고 fixture 재열기에서 무암호·오답 거부와 정답 성공을 함께 검증한다.

### 3.3 코드 소유 경계

- `Sources/RhwpCoreBridge`는 Foundation 기반 typed bridge만 담당하고 AppKit/UI에 의존하지 않는다.
- 암호 입력과 경고 UI는 `Sources/HostApp`이 소유한다.
- `project.yml`을 Xcode project의 진실 원천으로 사용하며 `Alhangeul.xcodeproj`를 직접 수정하지 않는다.
- upstream serializer 알고리즘과 bundled minified JavaScript를 수동 수정하지 않는다.
- stable core/Studio에는 release tag와 resolved commit만 사용하고 branch 또는 floating ref를 채택하지 않는다.
- 새 문서를 열거나 다시 불러오면 이전 문서의 보호 상태와 pending save state를 초기화하고, 보호 상태를 현재 document revision과 결합한다.

## 4. Stage 1 — exact 재현과 통합 계약 확정

### 4.1 목적

v0.1.10 release artifact와 exact bundled Studio 기준으로 HWP3/HWP5/HWPX 암호 입력의 현재 저장 결과를 재현한다. 즉시 적용할 안전 차단 기준, HWP3 출력 정책, Stage 3에 필요한 upstream API 계약을 확정한다.

### 4.2 작업 범위

1. upstream 공개 fixture를 `build.noindex/task480-*` 아래의 일회성 복사본으로 준비한다.
2. 입력마다 원본 hash를 기록하고 다음 경로를 검증한다.
   - 열기 성공 여부
   - `Command+S` 일반 저장 결과
   - 다른 이름 저장의 HWP/HWPX 결과
   - 취소와 export 오류에서 원본 hash 유지 여부
3. production host RPC의 capability와 method 목록을 exact bundle에서 고정한다.
4. native FFI가 HWP3/HWP5/HWPX 보호 상태를 안정적으로 구분할 수 있는지 확인한다.
   - 가능하면 public parser enum을 직접 match한다.
   - 공개 타입 경계가 불가능하면 오류 문자열 분류를 제품 계약으로 채택하지 않고 upstream typed API 필요 조건으로 기록한다.
5. HWP3 암호 입력을 password exporter에 전달했을 때 원형 HWP3인지 HWP5 `EncryptVersion` 4 변환인지 실증한다.
6. Stage 3에 필요한 최소 upstream host API를 제안서 형태로 고정하되 외부 저장소 이슈/PR은 만들지 않는다.

### 4.3 upstream API 선행 조건

선호하는 host API는 다음을 만족해야 한다.

- source protection state를 암호 문자열 없이 반환한다.
- HWP/HWPX format과 password export를 명시적 method 또는 typed parameter로 제공한다.
- 응답에 format, protection, byte count와 필요한 content-loss metadata를 포함한다.
- 암호를 전역 상태, DOM, URL, console과 오류 문자열에 남기지 않는다.
- 가능한 경우 같은 window/session의 hardened RPC를 사용하고 불필요한 broadcast 범위를 만들지 않는다.
- API가 stable release tag와 provenance로 제공된다.

### 4.4 산출물

- `mydocs/working/task_m010_480_stage1.md`
- `mydocs/orders/20260818.md` 상태 갱신
- 필요 시 후속 upstream 이슈/PR 제안 초안(로컬 Stage 보고서 안에만 기록)

Stage 1에서는 production source를 변경하지 않는다. 재현용 파일과 로그는 `build.noindex/`에만 두고 커밋하지 않는다.

### 4.5 검증

```bash
rg -n "exportHwpWithPassword|exportHwpxWithPassword|exportHwp|exportHwpx" \
  Sources/HostApp/Resources/rhwp-studio Sources/HostApp
scripts/verify-rhwp-studio-assets.sh
git diff --check
```

fixture 암호를 command argument나 shell history에 직접 넣지 않는다. hash 비교와 재열기 결과만 보고서에 기록한다.

### 4.6 완료·분기 기준

- 세 입력 계열의 평문화 조건과 원본 보존 결과가 표로 고정된다.
- 즉시 차단할 보호 상태와 write 행위가 확정된다.
- HWP3 보존/변환 정책이 확인된다.
- stable upstream API가 없으면 Stage 2까지만 진행한 뒤 upstream 선행 작업 승인을 요청한다.

### 4.7 커밋

`Task #480 Stage 1: 암호 저장 경계와 보호 계약 확정`

## 5. Stage 2 — native 보호 상태와 안전 차단

### 5.1 목적

완전한 암호 export API의 제공 여부와 무관하게 암호 문서를 평문으로 원본 URL에 덮어쓰는 경로를 차단한다. 판정 불능 상태도 보수적으로 취급한다.

### 5.2 예상 변경 파일

- `RustBridge/src/lib.rs`
- `rhwp-ffi-symbols.txt`
- `rhwp-core.lock`
- `RustBridge/README.md`
- `mydocs/tech/project_architecture.md`
- FFI 공식 build가 생성하는 header 및 검증 산출물
- `Sources/RhwpCoreBridge/RhwpDocument.swift` 또는 신규 `Sources/RhwpCoreBridge/RhwpDocumentProtection.swift`
- `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift`
- `Sources/HostApp/Services/DocumentSaveContract.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Tests/HostAppTests/DocumentSaveContractTests.swift`
- 필요 시 신규 protection contract test
- `mydocs/working/task_m010_480_stage2.md`
- `mydocs/orders/20260818.md`

새 파일이 target에 포함되어야 하면 `project.yml`만 수정하고 `xcodegen generate`로 project를 재생성한다. 신규 C ABI 때문에 `build-rust-macos.sh --update-lock`으로 xcframework, generated header/symbol과 artifact metadata를 재생성한다. `Frameworks/**` generated output은 검증에 사용하되 저장소 정책대로 커밋하지 않는다.

### 5.3 구현 항목

1. exact pinned core parser 결과를 typed status로 변환하는 C ABI probe를 추가한다.
   - raw parser 오류나 암호를 반환하지 않는다.
   - null pointer, zero length와 알 수 없는 결과를 명시적으로 처리한다.
   - 기존 `rhwp_open` ABI와 동작을 변경하지 않는다.
2. Swift bridge에 Foundation-only 보호 enum과 probe wrapper를 추가한다.
   - 신규 status enum과 symbol의 ABI, ownership, fallback 규칙을 bridge/architecture 문서에 기록한다.
3. source document payload를 만들 때 보호 상태를 구하고 current document revision에 결합한다.
4. 새 문서, reload, load failure, WebView 재생성에서 이전 보호 상태를 초기화한다.
5. 저장 요청에 `sourceProtection`과 `outputProtectionIntent`를 추가하되 암호는 보관하지 않는다.
6. `passwordProtected`/`unsupportedProtection`/`invalidOrUnknown`의 원본 URL plain write를 export 전 차단한다.
7. 명시적 평문 복사본은 별도 destination과 보호 해제 경고를 거쳐서만 허용한다.
8. 취소·차단·오류 뒤 Studio dirty 상태와 원본 byte가 유지되도록 한다.

### 5.4 테스트

- FFI status: plain, password required, unsupported/invalid, null/empty input
- Swift enum mapping과 unknown fallback
- 보호 입력의 in-place save는 export/write 전에 거부
- 판정 불능 입력의 in-place save 거부
- 평문 복사본 취소 시 write 없음
- 기존 plain HWP/HWPX의 same-format save와 format conversion 회귀 없음
- load/reload 뒤 protection state가 다른 문서로 누수되지 않음
- 오류 문자열과 analytics payload에 암호 또는 fixture 비밀값 없음

### 5.5 검증

```bash
cargo test --manifest-path RustBridge/Cargo.toml --locked
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
comm -3 <(sort rhwp-ffi-symbols.txt) <(sort Frameworks/generated_rhwp_symbols.txt)
./scripts/verify-rhwp-core-build-info.sh
swift test
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task480-stage2-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

실제 script 이름과 bridge framework 갱신 명령은 Stage 시작 전에 `build_run_guide.md`와 repository script를 다시 확인해 확정한다.

### 5.6 완료 기준

- 암호 보호 또는 판정 불능 입력에서 평문 원본 overwrite가 구조적으로 불가능하다.
- 취소·실패 시 원본 hash와 dirty 상태가 보존된다.
- 기존 평문 저장 회귀 테스트가 통과한다.
- Stage 3 선행 조건이 없더라도 안전 수정만 독립적으로 merge 가능한 상태다.

### 5.7 커밋

`Task #480 Stage 2: 암호 문서 평문 덮어쓰기 차단`

## 6. Stage 3 — native 암호 저장 연결

### 6.1 진입 조건

다음 조건을 모두 만족할 때만 시작한다.

- Stage 1에서 확정한 password export와 source protection RPC가 upstream stable release tag에 포함되어 있다.
- bundled Studio provenance를 해당 tag와 resolved commit으로 검증할 수 있다.
- upstream sync 범위와 tag 변경을 작업지시자가 별도로 승인했다.

조건이 충족되지 않으면 Stage 2 보고 후 작업지시자에게 upstream 이슈/PR 등록과 후속 sync를 제안한다. minified asset patch, private hook, unreleased commit pin으로 우회하지 않는다.

### 6.2 예상 변경 파일

- 승인된 경우 `Sources/HostApp/Resources/rhwp-studio/`와 provenance manifest
- `Sources/HostApp/Services/DocumentSaveContract.swift`
- `Sources/HostApp/Services/DocumentSavePanel.swift`
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- 신규 `Sources/HostApp/Services/DocumentPasswordSavePrompt.swift` 또는 동등한 HostApp UI 파일
- `Tests/HostAppTests/DocumentSaveContractTests.swift`
- `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift`
- 필요 시 신규 password save contract test
- `mydocs/working/task_m010_480_stage3.md`
- `mydocs/orders/20260818.md`

### 6.3 구현 항목

1. native 저장 UI에 출력 보호 선택을 추가한다.
   - 원본 보호 유지/암호 보호 저장
   - 명시적 평문 복사본
   - 취소
2. 암호 저장 선택 시 secure text field로 새 암호와 확인 값을 입력받는다.
   - upstream UX와 동일한 최소 길이 정책을 적용한다.
   - 불일치와 길이 오류는 export 전에 거부한다.
   - 다음 저장에서는 이전 값을 재사용하지 않고 다시 입력받는다.
3. `PendingSaveRequest`에는 output protection intent만 보존하고 암호는 export 호출 지역 범위에서만 전달한다.
4. host bridge는 승인된 RPC를 호출하고 format, protection, base64/bytes, byte count, content-loss metadata를 구조화해 반환한다.
5. `DocumentSaveContract`가 요청 format과 보호 의도까지 일치하는지 검사한 뒤에만 atomic write한다.
6. 보호 응답 누락, protection 불일치, export 오류, save panel 취소에서는 write와 clean 동기화를 수행하지 않는다.
7. 성공 후에만 `notifySaved`와 current URL 갱신을 수행하고 암호 입력 참조를 제거한다.

### 6.4 테스트

- 암호/확인 일치와 최소 길이 검증
- 취소 시 RPC와 write 미호출
- HWP/HWPX password method 및 parameter contract
- format/protection/byte count 불일치 거부
- protected export 성공 뒤에만 write 및 clean 동기화
- 후속 `Command+S`에서 암호 재입력
- 평문 복사본이 원본 URL을 선택하지 못하는 destination guard
- 암호가 generated script source, 로그와 error description에 나타나지 않음

### 6.5 검증

```bash
swift test
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task480-stage3-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 6.6 완료 기준

- native UI에서 HWP/HWPX 보호 저장을 명시적으로 선택할 수 있다.
- 암호가 영속 상태와 관측 가능한 로그에 남지 않는다.
- 보호 의도와 응답이 일치할 때만 파일을 쓴다.
- 취소·오류·후속 저장 계약이 자동 테스트로 고정된다.

### 6.7 커밋

`Task #480 Stage 3: native 암호 저장 경로 연결`

## 7. Stage 4 — round-trip 회귀와 문서 보정

### 7.1 목적

지원 형식의 보호 저장·재열기를 fixture로 고정하고 기존 평문 저장 회귀와 제품 문서를 실제 지원 범위에 맞춘다.

### 7.2 예상 변경 파일

- 암호 저장 회귀용 비민감 fixture/helper와 관련 test
- `README.md`
- `docs/updates/v0.1.10.html`
- `mydocs/release/v0.1.10.md`
- `mydocs/working/task_m010_480_stage4.md`
- `mydocs/orders/20260818.md`

제품 소스 추가 보정이 발견되면 Stage 4 보고 전에 범위를 설명하고 승인을 받는다.

### 7.3 회귀 행렬

| 입력/행위 | 필수 확인 |
|-----------|-----------|
| HWP5 암호 저장 | 무암호·오답 열기 거부, 정답 재열기와 편집 내용 확인 |
| HWPX 암호 저장 | 무암호·오답 열기 거부, 정답 재열기와 편집 내용 확인 |
| HWP3 암호 입력 | Stage 1에서 승인한 원형 보존 또는 HWP5 변환 정책, content-loss/경고 확인 |
| 보호 입력 일반 저장 | 무경고 plain in-place overwrite 불가 |
| 명시적 평문 복사본 | 원본 hash 유지, 별도 URL, 보호 해제 경고 확인 |
| 취소/export/write 실패 | 원본 hash 유지, dirty 상태 유지 |
| 평문 HWP/HWPX | same-format save, 다른 형식 저장, 후속 `Command+S` 회귀 없음 |

### 7.4 문서 보정

- README에는 native 저장의 보호 선택과 지원/제한 형식을 사실대로 기록한다.
- v0.1.10 업데이트 문서가 암호 문서 ‘열기’와 ‘저장’을 혼동하지 않도록 고친다.
- full password export가 upstream 선행 조건으로 남으면 known limitation과 안전 차단을 분명히 기록하고 완료로 과장하지 않는다.
- 실제 암호, fixture 암호, 로컬 절대 fixture 경로는 문서에 기록하지 않는다.

### 7.5 검증

```bash
cargo test --manifest-path RustBridge/Cargo.toml --locked
./scripts/build-rust-macos.sh --verify-lock
./scripts/verify-rhwp-core-build-info.sh
swift test
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task480-stage4-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

필요한 app smoke는 `build.noindex/` 산출물과 test fixture로만 수행한다. Quick Look/Thumbnail 등록은 이 타스크 범위가 아니며 임의 등록하지 않는다.

### 7.6 완료 기준

- 지원하는 HWP/HWPX 암호 저장 round-trip이 자동 또는 재현 가능한 검증으로 고정된다.
- HWP3 정책과 제한이 UI·테스트·문서에서 일치한다.
- 평문 저장과 dirty/clean 동기화 회귀가 없다.
- 문서가 실제 구현 상태와 일치하고 암호 정보 누수가 없다.

### 7.7 커밋

`Task #480 Stage 4: 암호 저장 회귀 검증과 문서 보정`

## 8. 중단 및 분기 기준

1. stable production host RPC에 password export가 없으면 Stage 3을 시작하지 않는다. Stage 2 안전 차단을 완료한 뒤 upstream 이슈/PR 등록 승인을 요청한다.
2. native FFI에서 보호 상태를 typed 결과로 구분할 수 없으면 오류 문자열 match를 장기 계약으로 채택하지 않는다. `invalidOrUnknown` 차단을 적용하고 upstream parser API 보완을 제안한다.
3. HWP3가 보호된 HWP3로 재저장되지 않고 HWP5로 변환되면 자동 overwrite를 허용하지 않는다. 변환과 content-loss를 알리는 별도 저장 경로를 승인받거나 지원 범위에서 제외한다.
4. 보호된 export metadata와 실제 재열기 결과가 다르면 write 이전 검증 설계를 재검토하고 해당 Stage를 완료 처리하지 않는다.
5. 암호가 로그, JavaScript source 문자열, 상태 저장소에 남는 경로가 발견되면 기능 범위를 축소하더라도 먼저 제거한다.
6. 예상 밖 upstream tag 갱신, ABI 변경, serializer 수정이 필요하면 같은 Stage에 임의 포함하지 않고 별도 이슈/승인을 받는다.

## 9. 단계별 승인·보고·PR 경계

- 각 Stage 종료 시 `task-stage-report`를 명시 호출해 `mydocs/working/task_m010_480_stage{N}.md`를 작성하고 소스·테스트·보고서를 하나의 Stage 커밋으로 묶는다.
- Stage 보고에는 실제 실행한 검증, 실패와 제한, 다음 Stage 진입 조건을 기록하되 암호 값은 기록하지 않는다.
- Stage 2에서 upstream 선행 조건이 남으면 안전 차단 PR을 독립 게시할지, #480을 열린 채로 후속 sync까지 이어갈지 작업지시자 승인을 받는다.
- 모든 승인된 Stage가 끝난 뒤에만 `task-final-report`를 명시 호출해 `mydocs/report/task_m010_480_report.md`, 최종 검증, `publish/task480` push와 `devel` 대상 PR을 수행한다.
- PR에는 `Closes #480`을 사용하되 완전한 암호 저장 완료 기준을 충족하지 못한 경우 #480을 조기 close하지 않는다.
- 서명, 공증, GitHub Release, appcast와 Homebrew 배포는 이 타스크 범위가 아니다.

## 10. 구현계획 승인 요청

- Stage 1에서 exact fixture 재현과 upstream 통합 계약을 확정한다.
- Stage 2에서 typed 보호 상태와 평문 원본 overwrite 차단을 독립적으로 먼저 구현한다.
- Stage 3은 stable upstream password export RPC와 별도 승인 후에만 진행한다.
- Stage 4에서 round-trip, 기존 저장 회귀와 문서를 완료한다.

위 단계·안전 정책·분기 기준 승인 후 Stage 1 조사를 시작한다.
