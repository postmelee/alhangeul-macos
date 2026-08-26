# Task M040 #459 최종 결과 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#459 PDF·인쇄 lifecycle에서 중복 요청과 stale navigation callback 방어](https://github.com/postmelee/alhangeul-macos/issues/459) |
| 마일스톤 | `M040` (`v0.4`) |
| 대상 통합 브랜치 | `devel` |
| 작업 브랜치 | `local/task459` |
| 단계 수 | 4 |
| 결과 | 일반 인쇄 controller의 단일 ownership과 PDF renderer의 generation/page/navigation identity를 도입해 중복 요청과 stale callback을 차단 |

일반 인쇄 중 두 번째 `print-document`가 기존 controller를 교체하고 첫 controller의 늦은 completion이 후속 controller를 해제할 수 있던 위험을 제거했다. `RhwpStudioPrintLifecycle`이 active controller를 단일 소유하며 controller 생성 전에 중복을 명시적으로 거부하고, 객체 identity가 일치하는 completion만 ownership을 해제한다.

공용 `RhwpStudioPagePDFRenderer`에는 단조 증가 generation, `(generation, pageIndex)` token과 실제 `WKNavigation` identity를 적용했다. Navigation delegate, preparation JavaScript, `createPDF`, page append와 timeout 결과는 current token일 때만 반영하며, 종료 시 token을 먼저 무효화하고 retained state를 정리한 뒤 completion을 호출한다. 정상·실패·timeout·WebContent process 종료 뒤 같은 renderer와 print lifecycle을 즉시 재사용하는 회귀를 고정했다.

## 단계별 결과

| 단계 | 결과 | 커밋 |
|------|------|------|
| Stage 1 | 인쇄 lifecycle 단일 ownership, 중복 요청 거부, controller identity 해제와 PDF menu `aria-label` observer 보완 | `7cf08a6` |
| Stage 2 | Renderer generation/page/navigation token과 모든 비동기 current 판정 적용 | `829faee` |
| Stage 3 | 종료 유형별 동일 renderer 재사용, completion 내부 즉시 재진입과 stale async result 통합 회귀 보강 | `5345616` |
| Stage 4 | Ownership·cleanup·재사용 architecture 계약과 자동 검증 한계 문서화, 최종 수용 검증 | `40383f4` |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioPrintLifecycle.swift` | Active print controller의 단일 ownership, 중복 거부와 identity 기반 completion 해제 구현 |
| `Sources/HostApp/Services/RhwpStudioPrintController.swift` | Lifecycle protocol 연결과 기존 단일 `finish` 수렴 계약 유지 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | Coordinator의 직접 controller slot을 lifecycle 위임으로 교체 |
| `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` | Render generation/page/navigation state, stale callback gate, cleanup·재사용과 internal WebKit operation seam 구현 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | Native PDF menu observer의 attribute filter에 `aria-label` 추가 |
| `Tests/HostAppTests/RhwpStudioPrintLifecycleTests.swift` | 중복 거부, identity 해제, outcome별 재진입, completion 내부 즉시 재진입과 retain cycle 회귀 추가 |
| `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` | Generation/navigation identity, stale async result, 모든 종료 유형 뒤 동일 renderer 재사용 회귀 추가·보강 |
| `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift` | `aria-label` filter와 canonical 복원 source 계약 보강 |
| `project.yml` | 신규 print lifecycle production source를 standalone HostAppTests source 목록에 추가 |
| `Alhangeul.xcodeproj/project.pbxproj` | XcodeGen 생성 결과로 HostApp·HostAppTests source membership 반영 |
| `mydocs/tech/project_architecture.md` | Print ownership, renderer current 판정, `finish` 순서, 재사용과 검증 한계 기록 |
| `mydocs/plans/task_m040_459.md` | Issue 범위, 완료 조건, 제외 경계와 단계 계획 기록 |
| `mydocs/plans/task_m040_459_impl.md` | 4개 Stage의 구현·검증·중단 기준 기록 |
| `mydocs/working/task_m040_459_stage1.md` | Print lifecycle와 observer 구현·검증 결과 |
| `mydocs/working/task_m040_459_stage2.md` | Renderer generation과 stale callback 차단 결과 |
| `mydocs/working/task_m040_459_stage3.md` | Cleanup·재사용 통합 회귀 결과 |
| `mydocs/working/task_m040_459_stage4.md` | Architecture 계약과 Issue 완료 조건별 최종 수용 근거 |
| `mydocs/orders/20260826.md` | Task #459 오늘할일 완료 처리 |
| `mydocs/report/task_m040_459_report.md` | 최종 결과, 정량 비교, 수용 기준과 잔여 위험 정리 |

변경은 HostApp PDF·일반 인쇄 lifecycle과 해당 HostAppTests에 한정했다. HWP/HWPX bytes와 page SVG payload, PDF geometry·font·CSP, PDF export request state, Rust core, `RhwpCoreBridge`, Quick Look·Thumbnail과 bundled `rhwp-studio` asset은 변경하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 인쇄 controller ownership | Coordinator의 교체 가능한 단일 slot | `RhwpStudioPrintLifecycle` 단일 ownership + identity 해제 |
| 인쇄 중 중복 요청 | 새 controller 생성·교체 가능 | Factory 추가 호출 0회, 기존 작업 유지, 명시적 오류 1회 |
| Renderer 비동기 식별 | `didFinish`와 page index 중심 | Generation + page token + 실제 navigation identity |
| Stale navigation/async result | 현재 render와 구분 불충분 | Current token 불일치 시 state·timeout·completion 변경 0회 |
| 종료 뒤 재사용 | 일부 timeout/process retry만 검증 | 정상·navigation·font·encoding·timeout·process 종료 전체 검증 |
| 전체 HostAppTests | 163개 | 178개, 순증 15개 |
| Test function diff | 기준 | 신규·이름 보강 16개, 기존 timeout test 1개 대체 |
| Production Swift diff | 기준 | 5개 파일, 348줄 추가·73줄 삭제 |
| HostAppTests Swift diff | 기준 | 3개 파일, 654줄 추가·17줄 삭제 |
| 구현 단계 | 계획 전 | 4/4 완료 |

최종 보고서 작성 전 `devel...40383f4` task diff는 18개 파일, 2,174줄 추가·91줄 삭제였다. 이 중 1,161줄 추가·1줄 삭제는 수행·구현계획, architecture와 4개 단계 보고서 등 작업 문서이며, 제품 동작은 HostApp service/view와 HostAppTests 범위에서만 변경됐다.

## 검증 결과

| 수용 기준 | 검증 근거 | 결과 |
|-----------|-----------|------|
| 중복 인쇄가 기존 controller를 교체하지 않음 | Active 검사 뒤에만 factory 호출, `testDuplicateRequestKeepsActiveControllerAndReportsErrorWithoutCreatingAnother` | OK |
| 중복 요청이 사용자에게 명시적으로 거부됨 | `.printingInProgress`와 기존 coordinator `onError`, 오류 1회 test | OK |
| Identity가 일치하는 completion만 ownership 해제 | `testOnlyMatchingControllerCompletionReleasesCurrentController`, completion call stack 재진입 test | OK |
| 이전 render/navigation callback이 현재 page·completion을 변경하지 않음 | Generation/page/navigation state tests, 실제 `WKNavigation` failure 재전달, stale `createPDF` result test | OK |
| 정상·실패·timeout·process 종료 뒤 renderer 재진입 | 다중 page 정상, navigation, font, encoding, timeout, WebContent process 종료별 동일 instance 재사용 test | OK |
| 실패·취소·정상 인쇄 completion 뒤 다음 요청 수락 | Outcome별 fake controller completion과 즉시 다음 요청 test | OK |
| Native PDF menu `aria-label` observer 복원 | `testNativePDFMenuOverrideIsReappliedAfterAttributeChanges` | OK |
| 기존 PDF 품질·보안 계약 유지 | Geometry, orientation, page count, 한글·수식 selectable text, Noto/ToUnicode, CSP·resource 차단 전체 renderer tests | OK |
| 관련 전체 자동 회귀 | HostAppTests 178/178, 실패·skip 0 | OK |
| HostApp 제품 build | Debug unsigned build 성공 | OK |
| XcodeGen 단일 진실 원천 | 연속 2회 SHA-1 `192e1cd7c42b3a80213fbdf7f3b8ab396a738ef0`, 두 번째 추가 diff 없음 | OK |
| 공통 Swift UI 의존 경계 | `./scripts/check-no-appkit.sh` | OK |
| Bundled Studio asset 불변 | `./scripts/verify-rhwp-studio-assets.sh` | OK |
| Extension 등록 위생 | issue 0, development registration 0 | OK |
| Patch 정합성 | `git diff --check` | OK |

PR 게시 전 최종 절차에서 XcodeGen 2회, 전체 HostAppTests, HostApp Debug build, no-AppKit, bundled Studio asset, extension registration hygiene와 patch 정합성을 다시 실행해 모두 통과했다.

최종 test 결과 bundle:

- `build.noindex/task459-final-tests/Logs/Test/Test-HostAppTests-2026.08.26_18-08-08-+0900.xcresult`

## 잔여 위험과 후속 작업

- `WKNavigationAction`에는 render generation/navigation identity가 없어 current page의 최초 main-frame `about:blank` 1회 pending state로 허용 범위를 제한한다. 허용 범위를 넓히는 fallback은 두지 않았다.
- WebContent process 종료 callback에도 process generation identity가 없어 renderer 소유 WebView와 current page token을 요구한다. 같은 WebView의 과거 process에서 극단적으로 늦게 온 callback 자체는 WebKit API가 식별하지 않는다.
- 실제 printer, modal `NSPrintOperation` panel과 사용자 취소 UI는 deterministic 자동 테스트에 포함하지 않았다. Production controller의 모든 종료가 단일 `finish`로 수렴하고 lifecycle fake가 ownership과 completion 중복 내성을 검증한다.
- 실제 print panel 통합 테스트는 OS UI·printer 환경 의존성과 유지 비용에 비해 현재 lifecycle identity 검증을 강화하는 폭이 작아 별도 후속 이슈로 분리하지 않는다. 사용자 회귀가 관측되거나 print operation을 주입 가능한 구조로 바꾸는 작업이 생길 때 재평가한다.

별도 후속 이슈가 필요한 미완료 구현은 없다. Issue #459는 PR merge 뒤 `pr-merge-cleanup` 절차에서 close한다.

## 작업지시자 승인 요청

Issue #459의 네 Stage, architecture 계약과 수용 기준을 모두 완료했다. `publish/task459`를 `devel` 대상으로 게시한 PR의 리뷰와 merge 승인을 요청한다.
