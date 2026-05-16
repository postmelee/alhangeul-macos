# Task M019 #223 Stage 1 완료 보고서

## 단계 목적

그림/개체 선택 후 Space 입력으로 발생하는 WKWebView runtime fallback을 재현하고, HostApp과 bundled `rhwp-studio`/WASM 입력 경로의 연결을 기록한다. 이번 단계는 진단 단계이며 제품 코드는 변경하지 않았다.

## 대상 샘플 확인

요청 파일은 `samples/exam_social.hwp`였지만, 첨부 스크린샷의 상태바에는 `exam_science.hwp - 4페이지`가 표시되어 있었다. 두 파일은 모두 저장소에 존재한다.

| 파일 | 크기 |
|------|------|
| `samples/exam_science.hwp` | 481280 bytes |
| `samples/exam_social.hwp` | 536064 bytes |

스크린샷과 같은 화면은 `exam_science.hwp`에서 확인했다. 화면 상태는 viewer 하단 기준 `2 / 4 쪽`, 문서 표시명 기준 `exam_science.hwp - 4페이지`, 본문은 과학탐구 영역의 7번/10번 문항이다.

## 빌드와 asset 검증

Debug HostApp 빌드 전 `Frameworks/Rhwp.xcframework`의 `librhwp.a`가 없어 최초 빌드가 실패했다. `./scripts/build-rust-macos.sh`로 macOS universal Rust static library와 `Rhwp.xcframework`를 생성한 뒤 HostApp Debug 빌드가 통과했다.

검증 결과:

| 항목 | 결과 |
|------|------|
| `./scripts/build-rust-macos.sh` | 성공, `x86_64 arm64` universal `librhwp.a` 생성 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | 성공 |
| `scripts/verify-rhwp-studio-assets.sh` | 성공 |
| `scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio` | 성공 |

수동 재현 중 macOS LaunchServices가 같은 bundle id의 `/Applications/Alhangeul.app`으로 문서 열기를 전달하는 현상이 있었다. 실제 fallback을 확인한 프로세스는 `/Applications/Alhangeul.app`의 v0.1.1 build 4였지만, 설치 앱과 저장소/Debug bundle의 viewer asset은 다음 파일에서 byte 동일함을 확인했다.

| 파일 | 확인 |
|------|------|
| `rhwp-studio/manifest.json` | `cmp -s` 동일 |
| `assets/index-BN69C-Lp.js` | `cmp -s` 동일 |
| `assets/rhwp_bg-BZNodj2e.wasm` | `cmp -s` 동일 |

현재 bundled viewer 기준:

| 항목 | 값 |
|------|----|
| upstream tag | `v0.7.10` |
| resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| main JS | `assets/index-BN69C-Lp.js` |
| main JS sha256 | `594133fe7dbe7464af580f573dbddf71c8c251cf0e27311694256c3050a7ecd6` |
| WASM | `assets/rhwp_bg-BZNodj2e.wasm` |
| WASM sha256 | `bdfbd391aa8f4204ff517938fc5b1ad83bb810c80de59f97a72e2be95b9e56fe` |

## 재현 결과

`exam_science.hwp`에서 다음 순서로 사용자 제보와 같은 fallback을 재현했다.

1. `samples/exam_science.hwp`를 Alhangeul로 연다.
2. 스크린샷과 같은 과학탐구 영역 7번 문항 위치로 이동한다.
3. `[가설]` 상자 안쪽의 본문 텍스트 영역을 먼저 클릭한다.
4. 같은 줄 왼쪽의 작은 boxed/circled 개체를 클릭한다.
5. Space를 입력한다.

단순히 개체만 클릭하고 Space를 누른 경우에는 항상 즉시 fallback으로 이어지지 않았다. 위 순서처럼 본문 텍스트 클릭 후 해당 개체를 선택하면 재현성이 높았다.

fallback 화면의 진단 정보:

```text
message=렌더링 오류: 지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다
sourceURL=alhangeul-studio://app/assets/index-BN69C-Lp.js
line=1
column=30942
reason=렌더링 오류: 지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다
```

`samples/exam_social.hwp`에서도 유사한 사람 아이콘/개체 위치를 클릭하고 Space를 입력해 보았지만, 이번 세션의 단순 smoke에서는 같은 fallback을 즉시 재현하지 못했다. 따라서 이번 이슈의 확정 재현 기준은 첨부 스크린샷과 일치하는 `exam_science.hwp` 경로로 둔다.

## 입력 경로 매핑

`Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js`의 column 30942 주변은 WASM glue의 `insertTextInCell`/`insertTextInCellByPath` 호출부다.

```text
insertTextInCell(e,t,n,r,i,a,o){... hwpdocument_insertTextInCell(...); ... if(m[3])throw ...}
insertTextInCellByPath(...)
```

upstream source 기준 입력 흐름은 다음과 같다.

| 파일 | 확인 내용 |
|------|----------|
| `rhwp-studio/src/engine/input-handler-keyboard.ts` | 그림/글상자 객체 선택 모드에서 Space는 전용 처리 대상이 아니다. Escape, Enter, Delete/Backspace, Ctrl+C/X/V, 화살표 등만 처리한 뒤 그 외 키는 개체 선택 해제 후 일반 처리로 내려간다. |
| `rhwp-studio/src/engine/input-handler-text.ts` | 일반 텍스트 입력은 `new InsertTextCommand(this.cursor.getPosition(), text)`로 전달된다. |
| `rhwp-studio/src/engine/command.ts` | `DocumentPosition`이 cell 계열로 보이면 `wasm.insertTextInCell(...)` 또는 `wasm.insertTextInCellByPath(...)`를 호출한다. |
| `src/document_core/commands/text_editing.rs` | `get_cell_paragraph_mut(...)`가 `Control::Table`, `Control::Shape`, `Control::Picture`만 허용하고 그 외 control이면 같은 오류 문자열을 반환한다. |

따라서 Space 입력 자체가 HostApp Swift 코드에서 직접 처리되는 것은 아니다. bundled viewer의 cursor state가 Space 입력 시 cell/textbox/picture caption 편집 경로처럼 남아 있고, 그 상태에서 WASM core가 실제 control 종류를 검사하며 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` 오류를 반환한다.

## HostApp 영향 범위

근본 입력 오류는 bundled `rhwp-studio`/WASM 경로에서 발생한다. 다만 우리 앱에서 사용자에게 보이는 치명적 증상은 HostApp이 post-load runtime error를 모두 fatal failure로 받아 전체 fallback 화면으로 전환하기 때문에 발생한다.

현재 HostApp에는 이미 `RhwpStudioWebViewFailure.isFatal` 필드가 있지만, `DocumentViewerStore.setWebViewFailure(_:)`는 fatal 여부와 관계없이 `webViewFailure`를 설정해 fallback view를 표시한다. 이 때문에 문서가 이미 표시된 뒤의 recoverable 성격 runtime error도 문서 화면 전체를 잃는 형태로 보인다.

## 검증 명령

```bash
git status --short --branch
ls -l samples/exam_social.hwp samples/exam_science.hwp
./scripts/build-rust-macos.sh
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
cmp -s Sources/HostApp/Resources/rhwp-studio/manifest.json /Applications/Alhangeul.app/Contents/Resources/rhwp-studio/manifest.json
cmp -s Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js /Applications/Alhangeul.app/Contents/Resources/rhwp-studio/assets/index-BN69C-Lp.js
cmp -s Sources/HostApp/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm /Applications/Alhangeul.app/Contents/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm
```

## 잔여 위험

- 재현은 설치 앱 프로세스에서 확인했다. 설치 앱과 Debug 산출물의 viewer JS/WASM은 동일하지만, Stage 3 smoke에서는 Debug app을 특정해 다시 확인해야 한다.
- `exam_social.hwp` 요청 파일에서는 같은 오류를 아직 확정하지 못했다. 사용자 첨부 스크린샷 기준으로는 `exam_science.hwp`가 실제 재현 파일이다.
- HostApp에서 recoverable runtime error를 fallback으로 전환하지 않게 하더라도, upstream cursor/input state 오류 자체가 사라지는 것은 아니다. 이번 이슈의 목표는 우리 앱의 전체 fallback 전환을 막는 것으로 제한한다.

## 다음 단계

Stage 1 결과를 승인하면 Stage 2에서 `RhwpStudioWebViewFailure.isFatal`을 실제 UI 라우팅에 반영해 nonfatal runtime failure가 문서 화면 전체 fallback을 띄우지 않게 한다.

## 승인 요청

Stage 1 산출물 승인을 요청한다.

승인 후 Stage 2 `nonfatal runtime failure 라우팅 구현`으로 진행한다.
