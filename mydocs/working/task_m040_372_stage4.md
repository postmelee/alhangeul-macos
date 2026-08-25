# Task M040 #372 Stage 4 검증 보고서

> 상태: 완료. 2026-08-26 00:50 실제 Finder file drag 수동 확인까지 통과했다.

## 단계 목적

대표 정상·실패·fatal 입력을 실제 HostApp에서 검증하고, recoverable opening과 fatal WebView 상태 경계 및 재현 절차를 architecture·build/run 문서에 반영한다. 원본 HWP/HWPX/PDF의 SHA-256과 수정 시각을 전후 비교하고 Debug Quick Look/Thumbnail 등록 없이 제품 source 상태를 최종 검증한다.

## source 기준과 변경 범위

- 제품 source 기준: `1698154 Task #372 Stage 3: window-local 복구 모달과 retry 통합`
- Stage 4 제품·테스트 source 변경: 없음
- 장기 문서 변경:
  - `mydocs/tech/project_architecture.md`
  - `mydocs/manual/build_run_guide.md`
- 단계 보고서:
  - `mydocs/working/task_m040_372_stage4.md`
- smoke fixture와 격리 app copy: `build.noindex/task372-smoke/`에만 존재하며 커밋하지 않는다.

`project.yml`을 원본으로 `xcodegen generate`를 실행했으며 `Alhangeul.xcodeproj` diff는 생기지 않았다.

## fixture provenance와 원본 무손실

| fixture | 경로 | SHA-256 | 크기 | 수정 시각 |
|---------|------|---------|------|-----------|
| 대표 HWP 5, 21쪽 | `/Users/melee/Documents/projects/forks/rhwp/samples/3-11월_실전_통합_2022.hwp` | `bc8bccbb954c337d813d1af96f4e3047242124c2f2939163e282634eb721accd` | 5,534,720 bytes | 2026-06-08 04:47:43 +0900 |
| 대표 HWPX, 9쪽 | `samples/hwpx/2025년 2분기 해외직접투자 (최종).hwpx` | `e49c69c090fa7abe9d33971f2983839f30c3efd77068d6d24b99db93a3c2872f` | 134,836 bytes | 2026-04-25 10:35:29 +0900 |
| PDF negative | `/Users/melee/Documents/test.pdf` | `7d11c3d87985f59aaf7237e9378c796db6af89dce4b324c7e0e86aec463512d6` | 2,305,557 bytes | 2026-05-03 19:10:20 +0900 |
| 0-byte synthetic | `build.noindex/task372-smoke/empty.hwp` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0 bytes | 2026-08-26 00:23:05 +0900 |
| unknown signature synthetic | `build.noindex/task372-smoke/unknown-signature.hwp` | `4dbd5d8a9d06f1b9e9b58bea32680003ef3db8a939c23deec2a17bd31c61695c` | 8 bytes | 2026-08-26 00:23:06 +0900 |

대표 HWP/HWPX hash는 기존 Task #484 실제 문서 기준과 일치한다. Stage 4 시작 전 크기·수정 시각과 종료 후 위 hash·metadata가 동일했고, 현재 저장소와 외부 `rhwp` checkout 모두 해당 fixture diff가 없다. PDF도 Stage 4 시작 시 기록한 hash·크기·수정 시각과 종료 값이 동일하다.

미저장 상태 확인 중 생긴 editor state는 원본에 쓰지 않고 `build.noindex/task372-smoke/unsaved-preservation-smoke.hwpx`에 별도 저장했다. 결과는 111,469 bytes, SHA-256 `523830ee6e16fb0aae950fd7ca9a8d7c1454347d45be84e9515d72583e8df916`이다.

## 실제 HostApp smoke

기준 앱은 `build.noindex/task372-stage3-build/Build/Products/Debug/Alhangeul.app`이다. Computer Use로 실제 macOS 파일 패널, Finder `다음으로 열기`, toolbar 최근 문서, SwiftUI sheet와 fatal fallback을 확인했다.

### 정상 HWP와 HWPX

- 대표 HWP는 filename `3-11월_실전_통합_2022.hwp`, `1 / 21` page count와 활성 toolbar를 표시했다.
- Studio의 로컬 글꼴 안내에서 원본을 수정하지 않는 `대체 글꼴로 보기`를 선택한 뒤 `21페이지 (304.0ms)` 완료 상태를 확인했다.
- 대표 HWPX는 retry 성공 뒤 filename `2025년 2분기 해외직접투자 (최종).hwpx`, `1 / 9` page count와 활성 toolbar를 표시했다.
- 같은 글꼴 안내를 닫은 뒤 `9페이지 (165.0ms)` 완료 상태를 확인했다.

### 파일 패널 PDF와 0-byte

정상 21쪽 HWP가 열린 window에서 PDF를 선택했다.

- title: `문서를 열 수 없습니다`
- file: `test.pdf`
- reason: `이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다.`
- action: `닫기`, `다시 시도`

닫기 뒤 WebView URL의 revision `2`, 기존 HWP filename, `1 / 21` page count와 toolbar가 그대로 유지됐다.

같은 window에서 `empty.hwp`를 선택했을 때 `비어 있는 문서는 열 수 없습니다.`가 표시됐다. 닫기 뒤 기존 21쪽 HWP snapshot이 유지됐다.

빈 window의 PDF 오류에서 다시 시도를 선택하면 오류 sheet가 먼저 사라지고 `HWP 문서 열기` panel만 표시됐다. panel에서 대표 HWPX를 선택해 9쪽 문서가 한 번만 commit되는 것을 확인했다. panel 취소와 sheet/panel 중첩 없음은 Stage 3 smoke 결과도 유지한다.

### 미저장 상태 보존

대표 HWPX에 미저장 editor state가 있는 상태에서 종료를 시도하면 다음 native 확인이 표시됐다.

```text
변경사항을 저장할까요?
"2025년 2분기 해외직접투자 (최종).hwpx" 문서에 저장되지 않은 변경사항이 있습니다.
```

취소 후 PDF opening failure를 표시하고 닫은 다음 다시 종료했을 때 동일한 HWPX 미저장 확인이 다시 표시됐다. 따라서 recoverable failure가 filename, document snapshot과 dirty 상태를 지우지 않음을 실제 앱에서 확인했다. 정리는 원본 대신 위 `build.noindex/` HWPX에 저장해 수행했다.

### Finder/open URL과 window-local 범위

Finder에서 `unknown-signature.hwp`를 선택하고 `다음으로 열기 > 기타…`에서 현재 Debug app의 절대 경로를 지정했다. 앱은 새 document window에 다음 recoverable sheet를 표시했다.

- title: `문서를 열 수 없습니다`
- file: `unknown-signature.hwp`
- reason: `이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다.`

sheet를 닫은 window는 빈 viewer로 돌아갔고, macOS 창 순환 단축키로 전환한 기존 window의 대표 HWPX는 filename, revision과 `1 / 9` page count를 유지했다. 외부 열기 failure가 다른 document window를 변경하지 않는 것을 확인했다.

### 최근 문서

toolbar 최근 문서 menu의 stale `representative.hwpx` 항목은 현재 filesystem에 존재하지 않는 것을 먼저 확인했다. 항목 선택 결과는 다음과 같다.

- title: `최근 문서를 열 수 없습니다`
- file: `representative.hwpx`
- reason: `문서를 읽을 수 없습니다. 파일 접근 권한 또는 위치를 확인한 뒤 다시 열어 주세요.`

닫기 뒤 현재 대표 HWPX의 filename과 9쪽 viewer가 유지됐다.

### fatal asset negative copy

Stage 3 Debug app을 `build.noindex/task372-smoke/fatal-negative/Alhangeul.app`으로 복사하고 격리를 위해 app bundle identifier만 `com.postmelee.alhangeul.task372negative`로 바꿨다. source asset은 건드리지 않고 복사본의 `rhwp_bg-CKllGEX8.wasm`만 `.missing`으로 옮겼다.

격리 앱은 기존 fatal fallback을 표시했다.

```text
웹 viewer 자산을 찾을 수 없습니다
설치본에 viewer 필수 파일이 빠져 있어 문서를 표시할 수 없습니다.

assetPattern=assets/rhwp_bg-*.wasm
count=0
directoryPath=.../build.noindex/task372-smoke/fatal-negative/Alhangeul.app/Contents/Resources/rhwp-studio/assets
```

fatal fallback의 `다른 파일 열기`에서 PDF를 선택하면 recoverable sheet가 위에 나타났고, 닫기 뒤 asset fatal fallback과 진단 정보가 그대로 유지됐다. 복사본의 WASM 파일명을 원래대로 복구하고 `다시 시도`를 누르면 rhwp-studio viewer가 다시 표시됐다. 종료 후 복사본에도 WASM asset 하나가 정상 파일명으로 존재한다.

### 실제 Finder drag/drop

Computer Use 좌표 drag는 Finder file pasteboard payload를 전달하지 못했으므로 증거에서 제외했다. 작업지시자가 2026-08-26 00:50 실제 마우스로 Finder의 `unknown-signature.hwp`를 대표 HWPX page 위에 drag하고 결과 스크린샷을 제공했다.

스크린샷에서 다음을 확인했다.

- Finder에서 `unknown-signature.hwp`가 실제 선택됨
- title: `끌어놓은 문서를 열 수 없습니다`
- file: `unknown-signature.hwp`
- reason: `이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다.`
- `닫기`, `다시 시도` action과 단일 sheet만 표시
- sheet 뒤 대표 HWPX page와 하단 `1 / 9` page count 유지

따라서 native file URL drop이 공통 recoverable state를 사용하고 기존 문서 snapshot을 보존함을 확인했다. 같은 물리 drop에서 sheet가 중복 표시되지 않았으므로 native URL handler와 WebView bytes callback의 중복 presentation도 발생하지 않았다. WebView bytes-only route는 native file drop이 먼저 처리되는 실제 앱 구조상 별도 사용자 동작으로 분리하지 않고 Stage 2/3 source·단위 테스트 계약으로 검증했다.

## 장기 문서 반영

### `mydocs/tech/project_architecture.md`

- recoverable opening과 fatal WebView failure 비교표
- file panel, external open, recent, native URL drop과 bytes drop의 공통 presentation
- failure model의 sanitize·비보관 경계
- commit-on-success, generation과 stale completion 거부
- sheet `onDismiss` 뒤 retry pending 단일 소비
- window-local 외부 열기와 fatal parser/asset 경계

### `mydocs/manual/build_run_guide.md`

- 기존 손상 opening 절을 recoverable opening smoke로 확장
- 정상 문서 뒤 PDF·0-byte·corrupt 입력 순서와 기대 문구
- 닫기·Escape·retry·Return·panel 취소 확인
- Finder/open URL, stale recent와 drag/drop 확인 기준
- 원본 hash·mtime 불변과 미저장 fixture 분리 저장
- recoverable sheet와 asset fatal fallback 비교
- Debug app launch와 Quick Look/Thumbnail 등록 위생 경계

## 자동 검증

### XcodeGen

```text
xcodegen generate
Created project at .../Alhangeul.xcodeproj
```

결과: 통과. 생성 뒤 Xcode project diff 없음.

### HostAppTests

```text
xcodebuild -quiet -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task372-final-tests \
  -clonedSourcePackagesDirPath build.noindex/task372-stage2-tests/SourcePackages \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO test
```

첫 sandbox 실행은 Xcode/SwiftPM 사용자 cache 쓰기 권한이 없어 package manifest loading 전에 종료됐다. 허용된 Xcode cache 환경에서 같은 명령을 다시 실행했다.

결과: 통과.

- 전체 161 tests
- 성공 161
- 실패 0
- skip 0
- xcresult: `build.noindex/task372-final-tests/Logs/Test/Test-HostAppTests-2026.08.26_00-42-13-+0900.xcresult`

### HostApp Debug build

```text
xcodebuild -quiet -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task372-final-build \
  -clonedSourcePackagesDirPath build.noindex/task372-stage2-tests/SourcePackages \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO build
```

결과: 통과. 일반 destination 선택 warning 외 compile/link 오류 없음.

### 경계·asset·등록 위생

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies

scripts/verify-rhwp-studio-assets.sh
OK: source rhwp-studio assets verified

scripts/verify-rhwp-studio-assets.sh \
  build.noindex/task372-final-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
OK: built app rhwp-studio assets verified

scripts/check-extension-registration-hygiene.sh --check-only
Issues: none
Development registrations: none

git diff --check
통과
```

Debug app과 격리 fatal copy는 `build.noindex/`에만 존재한다. 수동 `lsregister`, `pluginkit -a`, Quick Look/Thumbnail 등록과 Finder thumbnail 판정은 수행하지 않았다.

## 완료 기준 확인

| 기준 | 상태 |
|------|------|
| 정상 HWP 5와 HWPX 실제 load | 완료, 21쪽·9쪽 |
| PDF·0-byte·unknown signature recoverable sheet | 완료 |
| 현재 snapshot·filename·revision 유지 | 완료 |
| 미저장 상태 유지 | 완료 |
| retry panel 순서·취소·정상 HWPX commit | 완료 |
| Finder/open URL window-local 실패 | 완료 |
| stale 최근 문서 실패 | 완료 |
| fatal asset fallback·진단·잘못된 입력 보존·retry 복구 | 완료 |
| native file URL 실제 Finder drop | 완료, 단일 sheet·기존 9쪽 viewer 유지 |
| WebView bytes drop 계약·중복 presentation 억제 | 완료, source·단위 테스트 및 실제 drop 단일 sheet 확인 |
| architecture·build/run 문서 반영 | 완료 |
| HostAppTests 161개·Debug build·asset·AppKit 검사 | 완료 |
| 원본 HWP/HWPX/PDF 무손실 | 완료 |
| Debug extension registration 없음 | 완료 |

## Stage 4 결론

대표 정상 HWP/HWPX, recoverable negative 입력, 미저장 상태, retry, 외부 열기, 최근 문서, 실제 Finder drag와 fatal asset copy를 모두 검증했다. 장기 architecture·build/run 문서에 복구 경계와 재현 절차를 반영했고, 제품·테스트 source는 Stage 3 기준을 유지했다. 자동 검증과 원본 fixture 무손실 확인도 모두 통과했다.

이로써 Stage 4 완료 기준을 충족했다. 본 단계 완료 결과를 검토하고 최종 보고서 작성과 PR 게시를 수행하는 `task-final-report` 절차 진입 승인을 요청한다.
