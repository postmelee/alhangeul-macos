# Task M019 #223 최종 보고서

## 작업 요약

- 이슈: #223 그림 선택 후 Space 입력 시 WKWebView viewer runtime error 발생
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task223`
- 작업 위치: `/private/tmp/rhwp-mac-task223`
- 기준 브랜치: `devel-webview`
- 단계 수: 7단계
- 목적: 문서 표시 후 그림/개체 선택 상태에서 발생하는 recoverable viewer runtime error가 앱 전체 fallback 화면으로 전환되지 않게 하고, 실제 load/resource/document failure는 fatal fallback으로 유지

## 결과

`samples/exam_science.hwp`의 과학탐구 영역 7번 문항에서 작은 boxed/circled object를 선택한 뒤 입력 키를 누르면 bundled `rhwp-studio`/WASM 경로가 stale control 상태로 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다` 오류를 반환했다.

HostApp은 이 post-load runtime error를 기존에는 모두 fatal로 처리해 전체 fallback 화면을 표시했다. 이번 작업에서는 다음 기준으로 분리했다.

- 문서 표시 완료 후 발생한 invalid-control runtime error: 문서 화면 유지, 상단 nonfatal banner 표시
- resource, document load, navigation, process termination, timeout failure: 기존 fatal fallback 유지
- 문서 표시 전 load 중 runtime error: 기존 fatal fallback 유지

또한 nonfatal banner는 5초 뒤 자동으로 사라지게 하고, 사용자가 즉시 닫을 수 있는 우측 `xmark` 버튼을 추가했다.

## 원인 요약

Space 입력 재현 진단:

```text
message=렌더링 오류: 지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다
sourceURL=alhangeul-studio://app/assets/index-BN69C-Lp.js
line=1
column=30942
```

Enter 입력 재현 진단:

```text
message=렌더링 오류: 지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다
sourceURL=alhangeul-studio://app/assets/index-BN69C-Lp.js
line=1
column=45271
```

`30942`는 `insertTextInCell` 계열, `45271`은 `splitParagraphInCell` 계열 WASM glue 주변이다. 둘 다 post-load 입력 처리 중 같은 core invalid-control 오류가 HostApp bridge로 전달된 것이다.

## 주요 변경 파일

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | fatal/nonfatal WebView failure 라우팅, banner dismiss task, 수동 dismiss API 추가 |
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | runtime failure factory의 `isFatal` 인자 반영 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | post-load invalid-control runtime error recoverable 분류, Space/Enter column 의존 제거 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | nonfatal banner 자동 dismiss와 우측 `xmark` 닫기 버튼 UI 추가 |
| `mydocs/orders/20260511.md` | #223 진행 상태와 완료 시각 갱신 |
| `mydocs/plans/task_m019_223.md` | 수행계획서 작성 |
| `mydocs/plans/task_m019_223_impl.md` | Stage 1-7 구현계획 작성과 Stage 5/6 범위 보강 |
| `mydocs/working/task_m019_223_stage1.md` | 재현 경로와 Space 입력 진단 기록 |
| `mydocs/working/task_m019_223_stage2.md` | nonfatal routing 구현 결과 기록 |
| `mydocs/working/task_m019_223_stage3.md` | Space 입력 recoverable 분류 구현 결과 기록 |
| `mydocs/working/task_m019_223_stage4.md` | fatal fallback 회귀 smoke 결과 기록 |
| `mydocs/working/task_m019_223_stage5.md` | banner dismiss UX 구현 결과 기록 |
| `mydocs/working/task_m019_223_stage6.md` | Enter 입력 recoverable 분류 보강 결과 기록 |
| `mydocs/working/task_m019_223_stage7.md` | 최종 정리와 PR 준비 결과 기록 |

## 구현 요약

### failure 라우팅

`DocumentViewerStore.setWebViewFailure(_:)`가 `RhwpStudioWebViewFailure.isFatal`을 반영하게 했다.

| failure | 처리 |
|---------|------|
| fatal | `webViewFailure` 저장, 전체 fallback 표시 |
| nonfatal | `webViewErrorMessage` 저장, 문서 화면과 banner 유지 |

`RhwpStudioWebViewFailure.runtime(...)`에는 `isFatal` 인자를 추가했다. 기본값은 `true`라 기존 runtime failure는 보수적으로 fatal이다.

### recoverable runtime 분류

`RhwpStudioWebView.Coordinator`가 `didFinish` 이후 상태를 추적하고, 다음 조건을 모두 만족할 때만 runtime error를 nonfatal로 전달한다.

1. 현재 문서 payload가 있다.
2. WebView load가 완료된 post-load 상태다.
3. `message` 또는 `reason`에 `지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다`가 포함된다.
4. source가 bundled viewer runtime이다.
   - `alhangeul-studio://app/assets/index-*.js`
   - `line == 1`
5. `index.html` unhandled rejection 형태는 stack이 bundled `index-*.js` line 1을 가리킬 때만 허용한다.

Stage 3에서는 Space 입력의 `column=30942`만 허용했으나, Stage 6에서 Enter 입력의 `column=45271`도 같은 계열로 확인되어 column 숫자 의존성을 제거했다.

### banner UX

`DocumentViewerStore`가 banner 표시와 dismiss 예약을 소유한다.

- banner 표시 후 5초 뒤 자동 dismiss
- 새 banner가 들어오면 기존 dismiss task 취소 후 timer reset
- 닫기 버튼으로 즉시 dismiss
- reload/retry/fatal failure 전환 시 dismiss task 정리
- fatal fallback 화면에는 자동 dismiss나 닫기 버튼을 적용하지 않음

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 계획 | `4bfeab0` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `559d5c5` | 구현계획서 작성 |
| Stage 1 | `66e7415` | 그림 선택 Space 오류 재현 경로 확정 |
| Stage 2 | `427a35a` | nonfatal WebView runtime failure 라우팅 추가 |
| Stage 3 | `64d4fa7` | 그림 선택 입력 예외를 recoverable로 분류 |
| Stage 4 | `40b9309` | fatal fallback 회귀 확인 |
| Stage 5 | `90978b9` | nonfatal banner dismiss UX 추가 |
| Stage 6 | `412191f` | Enter 입력 invalid-control 오류 recoverable 처리 |
| Stage 7 | 본 커밋 | 최종 보고서 작성과 오늘할일 완료 처리 |

## 검증

완료한 자동 검증:

```bash
./scripts/build-rust-macos.sh
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage3 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage5 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage6 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage7 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataFinal CODE_SIGNING_ALLOWED=NO build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage3/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage5/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage6/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage7/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataFinal/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
xcodebuild -list -project Alhangeul.xcodeproj
git diff --check
```

수동 smoke:

- `samples/exam_science.hwp` 정상 표시 확인
- Stage 1 재현 동작에서 Space 입력 후 전체 fallback 미발생 확인
- 작업지시자가 Stage 5 변경본에서 banner 닫기와 자동 dismiss 정상 동작 확인
- 작업지시자가 Enter 입력에서 추가 fallback을 발견했고, Stage 6에서 같은 invalid-control 계열로 분류 보강
- `samples/table-vpos-01.hwpx` 정상 표시 확인
- missing WASM 복사본에서 fatal fallback 유지 확인
- 빈 `.hwp` 파일에서 fatal fallback 유지 확인
- 창 resize 후 runtime fallback 미발생 확인

테스트 타깃은 별도로 없고, `HostApp`, `QLExtension`, `ThumbnailExtension` scheme만 존재한다.

## 수용 기준별 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| Space 입력에서 전체 runtime fallback 미표시 | OK | Stage 3 smoke와 작업지시자 확인 |
| Enter 입력에서 전체 runtime fallback 미표시 | OK | Stage 6에서 같은 invalid-control 계열로 분류 보강 |
| nonfatal banner 자동 dismiss | OK | Stage 5에서 5초 자동 dismiss 구현, 작업지시자 확인 |
| nonfatal banner 수동 닫기 | OK | Stage 5에서 우측 `xmark` 버튼 구현, 작업지시자 확인 |
| fatal load/resource/document fallback 유지 | OK | Stage 4 negative smoke, Stage 6/7 asset 검증 |
| PR 전 미커밋 변경 없음 | OK | Stage 7 커밋 후 `local/task223` clean 확인 |

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| recoverable invalid-control 처리 | 전체 fallback 화면 전환 | 문서 화면 유지와 nonfatal banner |
| banner dismiss | 수동 닫기 없음, 자동 dismiss 없음 | 5초 자동 dismiss와 우측 닫기 버튼 |
| runtime column allow-list | 없음 또는 Space `30942` 중심 | bundled `index-*.js` line 1의 정확한 invalid-control 문구 기준 |
| 검증 빌드 | 없음 | Stage 3, 5, 6, 7, Final `HostApp` Debug build 통과 |

## 미수행 범위

- upstream `edwardkim/rhwp` 또는 `rhwp-studio` source 수정
- bundled minified JS 직접 patch
- native viewer/editor 구현
- public release, signing, notarization, Homebrew Cask 배포

## 잔여 위험

- root cause는 upstream `rhwp-studio` 입력 상태와 WASM core control routing 문제다. HostApp은 문서 보기 상태가 전체 fallback으로 전환되지 않도록 분류를 완화했다.
- 같은 invalid-control 문구가 post-load bundled viewer runtime에서 발생하면 전체 fallback 대신 banner로 표시된다. 이 조건은 resource/load 실패를 숨기지 않도록 current document, load 완료, source URL, line, 오류 문구로 제한했다.
- `rhwp-studio` asset이 업데이트되어 main JS 파일명이나 line 구조가 바뀌면 recoverable source 조건을 다시 확인해야 한다.

## 다음 절차

작업지시자가 2026-05-11 12:55에 "진행해줘"로 PR 게시 절차 진행을 승인했다.
