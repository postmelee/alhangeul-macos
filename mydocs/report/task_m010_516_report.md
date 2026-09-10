# Task #516 최종 결과보고서

## 작업 요약

- 이슈: [#516 — 새 문서 저장 실패와 Word·HTML 내보내기 연결 누락 수정](https://github.com/postmelee/alhangeul-macos/issues/516)
- 마일스톤: `M010` / `v0.1`, 구현 단계 5개 완료
- 브랜치: `local/task516` → `publish/task516`, PR 대상 `devel`
- 승인: 같은 스레드에서 각 단계 승인 및 최종 보고·PR 게시와 사용자 테스트용 앱 실행 지시
- 계획: [수행계획서](../plans/task_m010_516.md), [구현계획서](../plans/task_m010_516_impl.md)

앱 시작 시 Studio에는 빈 문서가 있지만 native는 파일 bytes를 로드한 경우만 문서가 있다고 판단했다. 따라서 `ㅇㅇ`를 입력해도 저장 명령이 ‘저장할 문서가 없습니다’로 끝나고, native dirty/종료 확인과 도구 활성화도 연결되지 않았다. Word·HTML은 upstream의 Blob 다운로드를 native 파일 저장으로 받는 경로가 없었다.

파일 payload와 편집 세션을 분리하여 시작 문서와 editor 내부 문서 교체를 추적한다. 첫 저장은 현재 편집 내용을 파일에 기록하고 같은 세션에 source를 연결하며 WebView를 reload하지 않는다. 저장 완료는 실제 write 뒤에만 통지한다. Word·HTML은 전용 WKDownload로 받아 검증 후 게시하고 원본 URL·형식·dirty를 유지한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `RhwpStudioEditorSession.swift`, `RhwpStudioEditorSessionScript.swift`, `DocumentViewerStore.swift` | 준비·dirty·epoch·source binding 모델과 초기/지속 동기화, 파일 로드와 metadata 갱신 분리 |
| `RhwpStudioWebView.swift`, `DocumentViewerView.swift`, `RhwpStudioHostBridgeScript.swift` | 세션 등록, 명령 라우팅, 요청 상관관계 및 오래된 응답 무효화 |
| `RhwpStudioSaveBridgeScript.swift`, `RhwpStudioPDFExportController.swift` | 입력 확정·잠금·문서 SHA 검증, HWP/HWPX와 PDF 출력의 게시 경계 |
| `DocumentCloseConfirmationController.swift`, `DocumentTerminationCoordinator.swift` | 마지막 입력을 포함한 최신 상태 조회, 저장/취소/실패/버리기 처리 |
| `DocumentHTMLExportFormat.swift`, `DocumentHTMLExportPanel.swift` | DOC/HTML 형식·패널·출력 검증 및 원본 동일 경로/링크 보호 |
| `RhwpStudioHTMLExportScript.swift`, `RhwpStudioHTMLDownload.swift` | Blob 보존과 요청 전용 URL, WKDownload staging·timeout·취소·정리 |
| `Tests/HostAppTests/*EditorSession*`, `*SaveBridgeScript*`, `*HTMLExport*` | 세션 전이·stale 응답·잠금·내보내기 계약 테스트 |
| `project.yml`, `Alhangeul.xcodeproj/project.pbxproj` | 신규 파일을 원본 설정에 추가하고 XcodeGen으로 생성 |
| `mydocs/tech/project_architecture.md`, `mydocs/manual/build_run_guide.md` | 현재 책임과 새 문서 저장·출력 smoke 절차 |
| 계획서·Stage 1~5 보고서·오늘할일·본 보고서 | 이슈 범위·단계 결과·검증 한계와 완료 기록 |

제품 파일은 `Sources/HostApp`, 테스트는 `Tests/HostAppTests` 아래에 있다. Rust/FFI·고정 core·Studio bundle·확장 구현은 본 이슈에서 변경하지 않았다. PR 준비 중 `devel`의 #513 변경을 merge commit `ae53a52`로 통합했다. 오늘할일 두 작업은 모두 유지했고 Xcode 충돌은 병합된 `project.yml`에서 재생성했다. #516 저장·출력 소스는 Stage 4 최종 상태와 같다.

## 변경 전·후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 시작 문서의 HWP/HWPX 저장 | native 문서 없음으로 거부 | 현재 편집 세션을 저장하고 재열기 본문 확인 |
| 기존 파일 → 새 문서 | 이전 source와 편집 문서 상태 혼동 가능 | epoch 교체 시 이전 source·보호 상태 해제 |
| Word/HTML 출력 | native 저장 경로 없음 | 두 형식의 실제 WKDownload·저장 패널·본문 확인 |
| 최종 자동 테스트 | Stage 4: 201개 통과 | 최신 devel 통합 후 218개 통과, 실패 0 |
| 회귀 증거 | Stage 1 실패 재현 | 저장/PDF/종료 59개, Word/HTML 50개와 조합 이벤트 2개 통과 |

## 검증 결과

| 수용 기준 | 판정 | 근거 |
|-----------|------|------|
| 시작 → 한글 → 첫 HWP/HWPX 저장·재열기 | OK | Stage 3/4 회귀 및 Stage 5 실제 패널, core 본문·1페이지 확인 |
| 후속 Command+S 경로·형식 유지 | OK | 같은 HWP/HWPX 경로 저장, 패널 없는 후속 저장 |
| 저장 취소·쓰기 실패의 편집 상태 보존 | OK | 실제 패널 취소 및 쓰기/응답/세션 오류 주입 |
| 닫기·앱 종료의 저장/취소/버리기 | OK | 최신 dirty 조회, 저장 실패 창 보존, 별도 버리기 6개 검사 exit 0 |
| 새 문서 PDF와 도구 활성화 | OK | PDF 최신 한글 text layer, Store/toolbar command binding. 전체 toolbar UI 클릭은 별도 미검증 |
| 새 문서 교체 시 원본·보호 상태 분리 | OK | 상태 테스트 및 실제 기존 파일 → 새 문서 회귀 |
| Word/HTML 새·기존 파일 출력과 상태 보존 | OK | HWP/HWPX 네 조합, 메뉴·WKDownload·실제 패널 및 취소/실패 확인 |
| 기존 형식과 보호·HWP3 정책 | OK / MISS | 저장·정책 테스트 OK, 암호/HWP3 실제 fixture의 UI 전 과정 MISS |
| M1/Tahoe 26.3·최소 macOS·Word 실기 | MISS | macOS 26.5.2 arm64에서 실행, Word 앱 호환성 실기 없음 |

최신 통합 소스 검증:

```text
xcodegen generate: 성공
HostApp Debug build: BUILD SUCCEEDED
HostAppTests: 218 tests, 0 failures / TEST SUCCEEDED
check-no-appkit.sh: OK
verify-rhwp-studio-assets.sh: source / 최종 앱 모두 OK
git diff --check 및 문서 상대 링크: 통과
```

`build.noindex/task516/final/`에 `build.log`, `test-prerequisite-build.log`, `tests-final.log`를 보존한다. 새 Spotlight 테스트는 테스트 bundle과 같은 DerivedData 안에 실제 앱/importer가 있어야 한다. 첫 실행은 이 선행 산출물 없이 218개 중 1개 실패했고, 동일 DerivedData의 HostApp을 먼저 빌드한 후 전체 218개가 통과했다. 실패 로그 `tests.log`도 보존한다.

Stage 3/4 회귀와 Stage 5 실제 패널 결과는 [Stage 3](../working/task_m010_516_stage3.md), [Stage 4](../working/task_m010_516_stage4.md), [Stage 5](../working/task_m010_516_stage5.md)를 따른다. 실제 패널 실행은 HWP/HWPX/PDF/DOC/HTML 출력과 원본 보존을 확인한 뒤, 진단 코드의 닫힌 창 재부착에서 종료됐다. 이 실행을 전체 성공으로 합산하지 않으며 종료 버리기는 별도 정상 종료 runner로 보완했다. 초기 패널 API 직접 조작의 WebKit 종료 역시 UI 성공과 구분해 보존했다.

## 잔여 위험과 후속 작업

- 출처를 입증할 수 없는 editor 문서는 첫 저장에 `invalidOrUnknown` 평문 복사본 확인을 적용한다. 빈 문서도 출처를 임의로 plain으로 낮추지 않는다.
- DOC는 upstream의 HTML 기반 `.doc`다. macOS HTML importer에서 한글 본문을 확인했으나 실제 Word의 레이아웃·편집 호환성은 미검증이다.
- 물리 한글 IME, 서명된 sandbox 앱의 권한, 실제 WebContent process crash 복구, 대형 문서 성능은 별도 실기 범위다.
- 닫힌 동일 창에 controller를 재부착하면 기존 delegate가 자신을 가리키는 경계는 별도 보완 후보다. 관련 attach/detach 코드는 작업 기준에도 존재하며 일반 닫기와 구분한다.
- Stage 5 종료 시 task516 진단 앱 등록과 다운로드 staging 잔류는 없었다. 이번 사용자 요청에 따라 검증된 앱을 다시 실행해 두었으므로 사용자 테스트 종료 후 해당 개발 앱의 등록을 정리한다. 기존 설치본과 복구 자료는 유지한다.

## 작업지시자 승인 요청

최종 보고·PR 게시는 같은 스레드에서 승인받았다. 사용자 테스트용으로 Stage 4 제품 소스를 가진 `build.noindex/task516/DerivedData/Build/Products/Debug/Alhangeul.app`을 실행했다. 새 통합 빌드는 실행 중 앱을 덮어쓰지 않도록 `DerivedDataFinal`에 만들었다. 두 앱의 #516 저장·내보내기 구현은 동일하다.

PR 검토 및 사용자 테스트 후 merge 승인을 요청한다. 본 절차에서는 merge·이슈 close·릴리스·서명/공증을 수행하지 않는다.
