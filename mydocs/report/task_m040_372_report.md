# Task M040 #372 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#372 지원하지 않는 파일 열기 실패를 복구 가능한 모달 UX로 전환](https://github.com/postmelee/alhangeul-macos/issues/372) |
| 마일스톤 | v0.4 (`M040`) |
| 기준 브랜치 | `devel`, 기준 commit `beeed921857afeb666c461ca23a76c17b8fa038d` |
| 작업 브랜치 | `local/task372` → 게시 브랜치 `publish/task372` |
| 단계 | 수행·구현 계획, Stage 1~4 |

지원하지 않거나 비어 있거나 읽을 수 없는 입력을 열 때 기존 viewer와 마지막 정상 문서를 전체 오류 화면으로 교체하던 동작을 window-local 복구 sheet로 전환했다. 사용자는 `닫기`로 기존 문서를 계속 사용하거나 `다시 시도`로 sheet가 사라진 뒤 파일 패널을 다시 열 수 있다.

새 입력은 읽기, signature validation과 protection classification이 성공한 뒤에만 commit한다. 실패한 입력은 기존 payload, source URL, filename, revision, 미저장 상태와 fatal WebView failure를 변경하지 않는다. 파일 패널, Finder/open URL, 최근 문서, native URL drop과 WebView bytes drop은 공통 recoverable presentation 계약을 사용한다. viewer asset, navigation, timeout, process와 parser failure는 기존 fatal fallback으로 유지했다.

대표 21쪽 HWP와 9쪽 HWPX, PDF, 0-byte, unknown signature, stale 최근 문서, Finder 외부 열기와 실제 Finder drag를 검증했다. asset 하나를 제외한 격리 Debug app copy에서는 fatal fallback과 진단이 보존되고 asset 복원 뒤 viewer가 재시작되는 것도 확인했다.

## Stage와 커밋

| Stage | 커밋 | 결과 |
|-------|------|------|
| 수행 계획 | `7263cfe` | Issue 범위, 4단계 승인 gate와 기준 브랜치 확정 |
| 구현 계획 | `223358a` | recoverable/fatal 경계, commit-on-success와 retry 계약 구체화 |
| Stage 1 | `52dea07` | 모든 opening 경로와 상태 생산자·소비자를 추적하고 전이·테스트 seam 확정 |
| Stage 2 | `36b3ba2` | Foundation-only recovery state, store commit-on-success와 9개 전이 테스트 구현 |
| Stage 3 | `1698154` | window-local sheet, retry pending 단일 소비, 키보드·접근성 연결과 1개 테스트 보강 |
| Stage 4 | `1167fd1` | 정상·negative·fatal 실제 앱 smoke, architecture·build/run 문서와 무손실 검증 완료 |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/DocumentOpenRecoveryState.swift` | 입력 source, sanitize된 failure presentation, generation과 retry pending을 관리하는 Foundation-only 상태 machine 추가 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | opening 실패의 기존 snapshot 보존, 최신 generation만 성공 commit하고 retry panel을 단일 소비 뒤 호출 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | 전체 오류 화면 대신 window-local recoverable sheet, 닫기·기본 다시 시도·접근성 label과 focus 연결 |
| `Tests/HostAppTests/DocumentOpenRecoveryTests.swift` | 실패 mapping, stale completion, dismiss, retry, 취소와 새 load 전이 10개 회귀 검증 |
| `project.yml`, `Alhangeul.xcodeproj/project.pbxproj` | recovery state와 테스트를 HostAppTests selected source에 포함하고 XcodeGen 결과 반영 |
| `mydocs/tech/project_architecture.md` | recoverable opening과 fatal WebView failure의 소유·상태·snapshot 경계 기록 |
| `mydocs/manual/build_run_guide.md` | 정상·negative·fatal opening smoke, 실제 Finder pasteboard drag와 등록 위생 절차 기록 |
| `mydocs/plans/task_m040_372.md`, `task_m040_372_impl.md` | 수행 범위, 구현 단계, 수용 기준과 승인 gate 기록 |
| `mydocs/working/task_m040_372_stage1.md` ~ `task_m040_372_stage4.md` | 조사, 구현, UI 통합과 실제 앱 검증 결과 기록 |
| `mydocs/orders/20260825.md` | Task #372 시작·완료 상태와 완료 시각 기록 |
| `mydocs/report/task_m040_372_report.md` | 전체 결과, 정량 비교, 수용 기준과 잔여 위험 기록 |

`Sources/RhwpCoreBridge`, bundled `rhwp-studio`, `rhwp-core.lock`, Quick Look/Thumbnail 제품 source와 지원 형식은 변경하지 않았다. Stage 4 smoke용 fixture와 격리 app copy는 `build.noindex/`에만 두고 커밋하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| opening 실패 표시 | viewer 전체 `ErrorStateView` 교체 | 기존 viewer 위 window-local sheet 1개 |
| 실패 시 현재 문서 | payload, source, filename, revision과 dirty 상태 제거 | 전체 snapshot과 기존 fatal 상태 유지 |
| retry 순서 | recovery action 없음 | sheet dismiss → pending 1회 소비 → `NSOpenPanel` 1회 |
| opening failure 상태 | 문자열 `errorMessage` | source·filename·title·message만 가진 sanitize된 값 타입 |
| focused recovery 테스트 | 0개 | 10개 |
| 전체 HostAppTests | Stage 2 구현 전 suite | 161개 통과, 실패·skip 0개 |
| 최종 보고서 작성 전 Task diff | 기준 브랜치와 동일 | 15파일, 1,992줄 추가·85줄 삭제 |
| 실제 정상 문서 smoke | 미확정 | HWP 21쪽, HWPX 9쪽 |

## 구현 결과

### Recoverable opening 상태와 commit-on-success

`DocumentOpenRecoveryState`는 load generation, 최신 failure와 retry pending을 관리한다. failure에는 표시 source와 sanitize된 파일명·제목·문구만 보관하며 URL, bookmark, 원본 bytes와 `Error` 객체를 장기 보관하지 않는다.

`DocumentViewerStore`는 새 시도에서 이전 async load를 취소하고 generation을 갱신하지만 현재 문서 snapshot과 fatal failure는 지우지 않는다. 읽기, signature validation과 protection classification이 완료되고 generation이 최신일 때만 payload, source, filename과 revision을 한 번 commit한다. stale success/failure와 같은 generation의 중복 completion은 무시한다.

### Window-local sheet와 retry

`DocumentViewerView`는 기존 viewer 또는 fatal fallback을 유지한 채 recoverable state를 sheet로 표시한다. 닫기와 Escape는 failure와 pending만 해제한다. 다시 시도와 Return 기본 action은 retry pending으로 전환하고, sheet `onDismiss`가 이를 한 번 소비한 뒤 chooser를 호출한다. 이 순서로 sheet와 `NSOpenPanel` session 중첩, 빠른 중복 action과 chooser 이중 호출을 막는다. panel 취소는 새 load를 시작하지 않는다.

외부 열기가 새 window를 만든 경우 failure는 해당 window에만 표시된다. 다른 document window의 viewer, filename과 page count는 유지된다.

### Recoverable과 fatal 경계

파일 읽기 실패, 0-byte, HWP/HWPX가 아닌 signature와 최근 bookmark 복원 실패는 recoverable sheet로 수렴한다. viewer asset 누락, navigation/timeout/process failure와 WebView parser `document-load-error`는 기존 `WebViewerFallbackView`와 진단을 유지한다. fatal fallback에서 잘못된 파일을 골라도 fallback은 보존되고, 정상 입력을 고르면 새 문서 성공 commit과 함께 해제된다.

## 실제 HostApp 통합 검증

| 시나리오 | 결과 |
|----------|------|
| 정상 HWP | `3-11월_실전_통합_2022.hwp`, 21쪽 load와 viewer 조작 확인 |
| 정상 HWPX | `2025년 2분기 해외직접투자 (최종).hwpx`, 9쪽 load와 viewer 조작 확인 |
| PDF·0-byte·unknown signature | 원인별 recoverable sheet 표시, 기존 filename·revision·page count 유지 |
| 미저장 상태 | 실패 sheet 닫기 전후 같은 native 저장 확인이 다시 표시되어 dirty 상태 유지 |
| retry | sheet가 사라진 뒤 panel 하나만 표시, 취소 시 기존 viewer 유지, HWPX 선택 시 9쪽 문서 한 번 commit |
| Finder/open URL | 새 window에 failure 표시, 기존 HWPX window의 `1 / 9` 유지 |
| stale 최근 문서 | `최근 문서를 열 수 없습니다` 표시 뒤 현재 HWPX 유지 |
| 실제 Finder drag | `unknown-signature.hwp`의 `끌어놓은 문서를 열 수 없습니다` sheet 1개, 뒤의 HWPX `1 / 9` 유지 |
| fatal asset copy | WASM 누락 진단 fallback 유지, 잘못된 입력 sheet 닫기 뒤 fallback 복귀, asset 복원·retry 성공 |

실제 Finder drag는 작업지시자가 2026-08-26 00:50 마우스로 수행한 스크린샷으로 확인했다. 좌표만 움직여 file pasteboard를 전달하지 못한 합성 drag는 증거에서 제외했다. WebView bytes-only route는 native file URL handler가 실제 drag를 먼저 처리하는 구조상 별도 사용자 동작으로 분리하지 않고 공통 제품 state와 자동 테스트로 검증했다.

## 최종 수용 기준 검증

| 수용 기준 | 결과 | 상태 |
|-----------|------|------|
| 미지원·빈·읽기 실패가 viewer 전체를 교체하지 않음 | 기존 viewer 또는 empty viewer 위 recoverable sheet | OK |
| 마지막 정상 snapshot과 미저장 상태 보존 | PDF·0-byte·unknown signature 및 dirty-state smoke 통과 | OK |
| 닫기·다시 시도 제공 | Escape, Return 기본 action과 accessibility label·focus 연결 | OK |
| sheet와 파일 패널 중첩·chooser 중복 방지 | retry pending 단일 소비 테스트와 실제 panel 확인 | OK |
| panel 취소 뒤 기존 viewer/fatal 유지 | 자동 전이 테스트와 실제 앱 smoke 통과 | OK |
| 정상 HWP/HWPX 성공은 한 번만 commit | generation·중복 completion 테스트와 실제 HWPX retry 확인 | OK |
| 모든 opening source의 공통 계약 | file panel, Finder/open, recent, URL drop과 bytes drop source mapping 확인 | OK |
| 기존 fatal fallback 유지 | asset negative copy와 기존 fatal 분류 확인 | OK |
| HostAppTests·Debug build·AppKit 경계 | 161/161, build, `check-no-appkit.sh` 통과 | OK |
| 원본 fixture·extension 등록 무손실 | hash·mtime 동일, development registration 없음 | OK |

## 최종 통합 검증

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과, 생성 후 예상 밖 project diff 없음 |
| HostAppTests | 161/161 통과, 실패·skip 0개 |
| test result | `build.noindex/task372-final-report-tests/Logs/Test/Test-HostAppTests-2026.08.26_00-53-37-+0900.xcresult` |
| HostApp Debug build | 통과, `build.noindex/task372-final-report-build` |
| source·built app Studio asset | 두 verifier 모두 통과 |
| `./scripts/check-no-appkit.sh` | 통과, shared Swift의 AppKit/UIKit 직접 의존 없음 |
| extension registration hygiene | issue·development registration 없음 |
| fixture SHA-256 | HWP `bc8bccbb...1accd`, HWPX `e49c69c0...2872f`, PDF `7d11c3d8...12d6` 유지 |
| `git diff --check` | 통과 |
| `origin/devel..HEAD` | 기준 commit이 ancestor이고 Task #372 계획·단계·최종·리뷰 보정 commit만 앞섬 |

## PR #486 리뷰 보정

PR 리뷰에서 지적된 sheet dismissal, WebView loading과 접근성 경계를 다음과 같이 보정했다.

- sheet binding의 `nil` write-back은 Store에 현재 failure가 남아 있을 때만 명시 dismiss로 처리한다. retry가 이미 failure를 지우고 pending만 남긴 상태에서는 setter가 no-op이므로 `onDismiss`가 pending을 정상 소비한다.
- 새 입력 validation 시작 시 기존 `isWebViewLoading`을 강제로 `false`로 만들지 않는다. 실패 뒤에도 유지된 기존 WebView가 자신의 실제 loading completion을 보고할 때까지 command gate를 열지 않는다.
- 버튼 accessibility label을 표시 문자열인 `닫기`, `다시 시도`와 일치시키고 부가 설명은 hint로 분리했다.
- 대체 구현을 주입하는 테스트가 없는 chooser closure는 제거하고 `DocumentOpenPanel.chooseDocumentURL()` 직접 호출로 복원했다.

HostAppTests는 selected Foundation source를 직접 컴파일하므로 `DocumentViewerStore` 전체를 test target에 포함하지 않는다. 실제 제품에서 사용하는 `DocumentOpenRecoveryState`의 generation·failure·retry 전이 10개는 자동 테스트하며, Store의 payload·filename·revision·dirty·fatal 연결은 mutation이 `finishDocumentLoad`에만 있는 구조 검사와 실제 앱 negative smoke로 검증한다.

Store 하나를 test target에 추가하려면 AppKit recent/bookmark, WebView 모델, save contract와 `Rhwp.xcframework` 의존을 함께 가져오거나 별도 모듈 분리가 필요하다. 현재 변경 규모와 이미 확보한 자동·수동 검증을 고려하면 이 테스트만을 위한 독립 후속 이슈의 비용 대비 가치는 낮다. 향후 Store 모듈화 또는 document lifecycle 대규모 변경이 시작될 때 통합 test host를 함께 설계하며, 이번 PR에서는 별도 이슈를 만들지 않는다.

보정 뒤 `xcodegen generate`, HostAppTests 161/161과 HostApp Debug build를 다시 통과했다. 보정 Debug 앱의 accessibility tree에서 `닫기`, `다시 시도` label과 각각의 hint를 확인했다. PDF failure의 `다시 시도`는 sheet dismissal 뒤 file panel 하나만 열었고, panel 취소 뒤 viewer로 복귀했다. `닫기`는 file panel 없이 viewer로 돌아왔다. AppKit 경계, source·built asset verifier와 extension registration hygiene도 다시 통과했다.

## 잔여 위험과 후속 작업

- WebView bytes-only drop은 native file URL interception을 우회하는 별도 실제 사용자 gesture로 재현하지 않았다. 순수 recovery state와 bytes source mapping 자동 테스트가 이 경계를 담당한다.
- VoiceOver 음성 전체 순서는 실청취하지 않았다. macOS accessibility tree의 label 노출, 초기 focus와 키보드 action까지 검증했다.
- parser `document-load-error`는 계획대로 fatal이다. signature는 맞지만 내부 구조가 손상된 입력을 recoverable로 재분류하려면 별도 범위와 회귀 검증이 필요하다.
- Intel Mac과 deployment target macOS 12 실기기에서의 UI smoke는 수행하지 않았다. 현재 Apple Silicon macOS 환경의 Debug build와 테스트로 검증했다.
- `build.noindex/` 아래 개발 app bundle은 등록되지 않은 상태로 남아 있다. Finder/Quick Look 판정에는 사용하지 않았고 cleanup 시 필요 없는 산출물만 정리할 수 있다.
- Store snapshot 연결은 직접 unit test가 아니라 제품 recovery state 테스트, 단일 mutation 경계 검사와 실제 앱 smoke의 조합으로 검증한다. 이 경계가 여러 Store나 service로 분산되면 통합 test host 도입을 다시 검토해야 한다.

현재 수용 기준을 막는 미해결 blocker나 별도 후속 이슈 제안은 없다. 참고 선행 이슈는 기존 opening fallback을 다룬 [#149](https://github.com/postmelee/alhangeul-macos/issues/149)다.

## 최종 결론

Issue #372의 수행·구현 계획과 Stage 1~4를 완료했다. 문서 입력 실패를 기존 viewer를 제거하는 전체 오류 상태에서 복구 가능한 window-local sheet로 전환했고, commit-on-success와 generation 전이로 마지막 정상 문서·미저장 상태·fatal fallback을 보존한다. 닫기, retry, panel 취소와 모든 opening source가 공통 계약을 사용한다.

161개 자동 테스트, Debug build, 경계·asset·등록 위생 검사와 대표 HWP/HWPX·negative·fatal 실제 앱 smoke가 모두 통과했다. 원본 fixture와 범위 밖 core, Studio 및 extension source는 변경하지 않았다.

## 작업지시자 승인 요청

Task #372의 4개 Stage, 전체 수용 검증과 최종 보고서 작성을 완료했다. `publish/task372`를 `devel` 대상으로 게시한 Open PR의 리뷰와 merge 승인을 요청한다. merge 전에는 Issue #372를 열린 상태로 유지하고, merge 확인 뒤 `pr-merge-cleanup` 절차로 issue와 작업 브랜치를 정리한다.
