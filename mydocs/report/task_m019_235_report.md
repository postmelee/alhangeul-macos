# Task M019 #235 최종 보고서

## 작업 요약

- 이슈: #235 Web viewer runtime 오류를 fatal 화면 대신 non-blocking banner로 표시
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task235`
- 기준 브랜치: `devel-webview`
- 목적: `samples/exam_social.hwp` 성명 필드 입력 중 발생하는 post-load `컨트롤 인덱스 0 범위 초과` runtime error가 전체 fatal fallback 화면으로 전환되지 않고, 문서 화면을 유지한 채 non-blocking banner로 표시되게 한다.

## 결과

`samples/exam_social.hwp` 성명 필드 입력 중 bundled `rhwp-studio`/WASM runtime에서 다음 오류가 발생했다.

```text
message=렌더링 오류: 컨트롤 인덱스 0 범위 초과
sourceURL=alhangeul-studio://app/assets/index-BN69C-Lp.js
line=1
column=30942
reason=렌더링 오류: 컨트롤 인덱스 0 범위 초과
```

이전에는 이 오류가 fatal runtime failure로 처리되어 전체 fallback 화면으로 전환됐다. 이번 작업에서는 다음 기준으로 분리했다.

- 문서 표시 완료 후 bundled viewer runtime에서 발생한 확인된 입력 처리 오류: 문서 화면 유지, non-blocking banner 표시
- 같은 nonfatal runtime diagnostic이 banner 표시 중 반복되는 경우: 기존 banner와 dismiss timer 유지
- resource, document scheme, navigation, process termination, timeout, unknown runtime failure: fatal fallback 유지

사용자-facing banner 문구는 기존 nonfatal runtime 문구를 재사용했다.

```text
입력을 처리하지 못했습니다. 문서는 계속 볼 수 있습니다.
```

## 주요 변경 파일

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | recoverable runtime message allow-list에 `컨트롤 인덱스 0 범위 초과` 추가, invalid-control 전용 helper를 post-load runtime helper로 정리 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | nonfatal runtime banner dedupe key 추가, 같은 diagnostic 반복 시 timer reset 방지 |
| `mydocs/orders/20260512.md` | #235 완료 상태 반영 |
| `mydocs/orders/20260513.md` | #235 완료 상태 반영 |
| `mydocs/plans/task_m019_235.md` | 수행계획서 |
| `mydocs/plans/task_m019_235_impl.md` | 구현계획서 |
| `mydocs/working/task_m019_235_stage1.md` | 재현과 현행 오류 정책 inventory |
| `mydocs/working/task_m019_235_stage2.md` | control-index runtime recoverable 분류 구현 보고 |
| `mydocs/working/task_m019_235_stage3.md` | nonfatal runtime banner dedupe 구현 보고 |
| `mydocs/working/task_m019_235_stage4.md` | 통합 build와 fatal fallback 회귀 검증 보고 |
| `mydocs/working/task_m019_235_stage5.md` | 최종 보고와 release handoff 정리 |
| `mydocs/report/task_m019_235_report.md` | 본 최종 보고서 |

## 구현 요약

### recoverable runtime 분류

`RhwpStudioWebView.Coordinator`의 runtime error 판별을 known post-load runtime helper로 정리했다. 다음 조건을 모두 만족할 때만 nonfatal로 전달한다.

1. 현재 문서 payload가 있다.
2. WebView load가 완료된 상태다.
3. `message` 또는 `reason`이 확인된 recoverable 문구를 포함한다.
4. `sourceURL`이 bundled `rhwp-studio` `/assets/index-*.js`이고 line이 `1`이다.
5. `index.html` unhandled rejection 형태는 reason stack이 같은 bundled asset line `1`을 가리킨다.

recoverable message allow-list:

```text
지정된 컨트롤이 표, 글상자 또는 그림이 아닙니다
컨트롤 인덱스 0 범위 초과
```

Stage 1 재현에서 asset hash와 column이 Issue 본문과 달랐으므로 `column`은 allow-list 조건으로 쓰지 않았다.

### banner dedupe

`DocumentViewerStore`는 nonfatal runtime failure에 한해 다음 key를 만든다.

```text
{category.rawValue}
{diagnosticDetail}
```

같은 key의 banner가 이미 표시 중이면 새 표시 요청을 무시한다. 이때 기존 banner와 기존 자동 dismiss task를 유지하므로, 같은 오류 반복 입력으로 banner 표시 시간이 계속 연장되지 않는다.

일반 `setWebViewError(_:)` 경로는 dedupe key 없이 기존처럼 동작한다.

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `8e4d297` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `9f01167` | 구현계획서 작성 |
| Stage 1 | `4cbded0` | runtime 오류 정책과 재현 경로 정리 |
| Stage 2 | `dca6869` | control-index runtime 오류 recoverable 분류 추가 |
| Stage 3 | `dc15a28` | nonfatal runtime banner 중복 표시 제어 |
| Stage 4 | `218dffa` | runtime banner 통합 회귀 검증 |
| Stage 5 | 본 커밋 | 최종 보고서와 오늘할일 완료 처리 |

## 검증

자동 검증:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask235 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask235Stage2 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask235Stage3 CODE_SIGNING_ALLOWED=NO build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
test -f build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
find build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/assets -maxdepth 1 -name 'rhwp_bg-*.wasm' -type f
git diff --check
```

참고:

- sandbox 안의 첫 `xcodebuild` 시도들은 Sparkle dependency resolve, SwiftPM manifest cache, Xcode cache 접근 제한으로 실패했다.
- 같은 명령을 승인된 권한으로 재실행해 HostApp Debug build를 통과시켰다.

수동 smoke:

- `samples/exam_social.hwp` 정상 표시 확인
- 성명 필드 입력 시 fatal fallback 대신 nonfatal banner 표시 확인
- 문서 화면 유지 확인
- 같은 오류 반복 입력 시 banner dismiss timer가 reset되지 않는 것 확인
- 자동 dismiss 후 같은 오류 재표시 확인
- 수동 dismiss 후 같은 오류 재표시 확인
- WASM asset을 제거한 앱 복사본에서 resource preflight fatal fallback 유지 확인

검증 한계:

- 빈 `.hwp`와 잘린 `.hwp` synthetic 파일은 LaunchServices open event로 document loader까지 도달한 화면 증거를 확보하지 못했다. 빈 viewer placeholder 상태에 머물렀고 nonfatal banner로 오인되지는 않았다.
- `open -n -a 앱 경로 파일 경로` 형태로 앱 실행과 문서 전달을 한 번에 수행하면 `timeout` fallback이 재현됐다. 앱을 먼저 실행한 뒤 sample open event를 별도로 전달하면 정상 로드된다.

## 수용 기준별 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `컨트롤 인덱스 0 범위 초과` runtime error가 nonfatal로 전달 | OK | Stage 2 구현, Stage 2/4 smoke |
| load 전 runtime error와 다른 source의 runtime error는 fatal 유지 | OK | current document, load 완료, bundled source, message allow-list 조건 유지 |
| #223 invalid-control recoverable 경로 유지 | OK | 기존 문구 allow-list 유지 |
| 같은 nonfatal runtime diagnostic 반복 시 banner 중복 표시 제어 | OK | Stage 3/4 smoke |
| 자동 dismiss 또는 수동 dismiss 후 같은 오류 재표시 | OK | Stage 3 smoke |
| resource fatal fallback 유지 | OK | Stage 4 missing WASM 복사본 smoke |
| PR 전 미커밋 변경 없음 | Stage 5 커밋 후 확인 예정 | 본 커밋 후 확인 |

## 미수행 범위

- upstream `edwardkim/rhwp` 또는 `rhwp-studio` source 수정
- bundled minified JS 직접 patch
- native viewer/editor 구현
- release version bump
- signing, notarization, public release, Homebrew Cask 배포
- `mydocs/release/v0.1.2.md` 신규 작성

## release handoff

`mydocs/release/v0.1.2.md`는 아직 없다. 이번 Stage 5에서는 release decision record를 새로 만들지 않고, #235 최종 보고서에 다음 handoff를 남긴다.

- #235는 `v0.1.2` blocker 완화 작업으로 PR 본문에 포함한다.
- 사용자-visible 변화는 “viewer 입력 중 일부 runtime 오류가 전체 오류 화면 대신 문서 유지 banner로 표시됨”이다.
- upstream 원인 수정은 `edwardkim/rhwp` #850으로 남는다.
- release 기록 문서가 생성되는 시점에는 #223과 #235를 함께 `rhwp-studio` post-load runtime UX 완화 항목으로 묶는 것이 적절하다.

## PR close 전략

PR 본문에는 다음을 명시한다.

```text
Closes #235
```

upstream `rhwp` #850은 이 PR에서 close하지 않는다. 본 작업은 HostApp의 fatal/nonfatal 분류와 banner UX 완화이며, upstream editor/runtime root cause는 별도 추적 대상이다.

## 잔여 위험

- root cause는 upstream `rhwp-studio` 입력 처리와 WASM core control routing 문제다.
- recoverable message allow-list는 확인된 두 문구만 포함한다. 같은 계열의 다른 문구가 나오면 별도 이슈로 추가 판단이 필요하다.
- bundled asset 구조가 바뀌어 main JS line 구조가 달라지면 recoverable source 조건을 다시 확인해야 한다.
- 앱 실행과 문서 open event를 한 명령으로 수행할 때 발생한 timeout fallback은 별도 follow-up 후보다.
- resource fatal smoke용 깨진 앱 복사본은 `build.noindex/Task235Stage4ResourceFault/Alhangeul.app`에 남아 있다. 제품 소스와 정상 Debug 산출물에는 영향이 없다.

## 다음 절차

작업지시자 최종 승인 후 `task-final-report` 절차를 명시 호출해 `publish/task235` 원격 브랜치 push와 `devel-webview` 대상 Open PR 생성을 진행한다.
