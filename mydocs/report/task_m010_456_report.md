# Task #456 최종 결과보고서

## 작업 요약

- 이슈: [#456 HostApp의 HWP/HWPX 형식별 native 저장 경로 연결](https://github.com/postmelee/alhangeul-macos/issues/456)
- 마일스톤: v0.1 (`M010`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task456` → 게시 브랜치 `publish/task456`
- 단계 수: 5

HostApp의 HWP 전용 native 저장 경로를 HWP/HWPX 형식 인식형 경로로 확장했다. 알한글이 upstream 파일 메뉴와 native 저장 UX를 소유하고, bundled `rhwp-studio`의 형식별 exporter를 호출해 받은 bytes만 검증 후 atomic write한다. HWPX로 다른 이름 저장한 뒤 current source를 새 `.hwpx` URL로 전환하므로 이후 `Command+S`도 같은 파일에 `exportHwpx` 결과를 저장한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/DocumentSaveFormat.swift` | HWP/HWPX 형식 추론, panel title·UTI·filename 정규화와 CFB/ZIP signature guard를 제공하는 공통 모델 추가 |
| `Sources/HostApp/Services/DocumentSaveContract.swift` | 저장 command별 format 결정과 response format·base64·byte count·signature·destination 검증 계약 추가 |
| `Sources/HostApp/Services/DocumentSavePanel.swift` | HWP 고정 panel을 형식 필수 입력의 HWP/HWPX native `NSSavePanel`로 일반화 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | 형식별 저장 메뉴 intercept, HWP/HWPX exporter 선택, response format과 `notifySaved` bridge 연결 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | destination+format pending state, 제자리 저장·동일 형식 fallback, write 전 검증, current source 전환과 editor 동기화 구현 |
| `Tests/HostAppTests/DocumentSaveFormatTests.swift` | format 추론·filename 정규화·CFB/ZIP signature 단위 테스트 10개 추가 |
| `Tests/HostAppTests/DocumentSaveContractTests.swift` | command format 보존과 response mismatch·bad signature·byte count·destination 거부 테스트 11개 추가 |
| `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift` | 명시적 format command, `exportHwpx`, response format과 `notifySaved` 계약 테스트 3개 추가 |
| `project.yml` | HostAppTests에 신규 format/contract/bridge source 포함 |
| `Alhangeul.xcodeproj/project.pbxproj` | `project.yml`에서 재생성된 source reference 반영 |
| `mydocs/tech/project_architecture.md` | 저장 command matrix, HostApp/upstream 소유 경계, exporter·write guard와 호환 제한 문서화 |
| `mydocs/plans/task_m010_456.md` | Task #456 범위, 수용 기준, 5단계 수행 계획 기록 |
| `mydocs/plans/task_m010_456_impl.md` | format contract, 상태 전이, 단계별 구현·검증 계획 기록 |
| `mydocs/working/task_m010_456_stage1.md` ~ `task_m010_456_stage5.md` | 조사, 모델, 연결, 실제 UI 통합 검증과 architecture 정리 결과 기록 |
| `mydocs/orders/20260804.md` | Task #456 진행·완료 상태 기록 |

upstream `rhwp` core, bundled `rhwp-studio` asset, `Sources/RhwpCoreBridge`, 공유, 인쇄와 현행 PDF export의 제품 경로는 변경하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| native 저장 형식 | HWP 고정 | HWP/HWPX 2종 |
| 명시적 형식 native command | 0개 | `file:save-as-hwp`, `file:save-as-hwpx` 2개 |
| 일반 저장 형식 결정 | HWP 고정 | source URL → filename → 기본 HWP |
| pending 저장 상태 | destination 중심 | destination + format 단일 요청 |
| 신규 저장 계약 테스트 | 0개 | format 10 + contract 11 + bridge 3 = 24개 |
| HostAppTests 전체 | 76개 | 100개, 실패 0개 |
| 실제 형식 조합 smoke | 미검증 | HWP→HWP, HWP→HWPX, HWPX→HWPX, HWPX→HWP 4개 |
| 읽기 전용 source fallback | HWP 중심 | 요청한 HWP/HWPX 형식 유지 |

`origin/devel...HEAD` 기준 최종 보고서 작성 전 diff는 19개 파일, 1,990줄 추가, 103줄 삭제다.

| 구분 | 추가 | 삭제 |
|------|------|------|
| HostApp 제품 source | 502 | 97 |
| HostAppTests | 358 | 0 |
| Xcode project 설정 | 29 | 0 |
| 계획·단계·architecture·orders 문서 | 1,101 | 6 |

## 구현 결과

### 형식별 menu·panel·exporter

| command | format | exporter | destination |
|---------|--------|----------|-------------|
| `file:save` | source URL → filename → HWP | HWP 또는 HWPX | 같은 형식 source 제자리, 없거나 write 실패 시 같은 형식 panel |
| `file:save-as` | source URL → filename → HWP | HWP 또는 HWPX | 현재 형식 native panel |
| `file:save-as-hwp` | HWP | `exportHwpBase64`, 미지원 시 `exportHwp` | HWP native panel |
| `file:save-as-hwpx` | HWPX | `exportHwpx` | HWPX native panel |

`DocumentSaveFormat`이 확장자, panel title, UTI, 기본 filename과 signature를 한 곳에서 제공한다. 지원 확장자를 다른 형식으로 바꿀 때 기존 suffix를 제거해 `.hwp.hwpx` 같은 중복 확장자를 만들지 않는다.

### write 전 계약과 상태 동기화

HostApp은 pending request, response format, base64, byte count, payload signature와 destination extension을 순서대로 검사한다. 하나라도 일치하지 않으면 파일과 current source, 최근 문서와 clean state를 변경하지 않는다. source atomic write가 실패하면 payload를 다시 export하지 않고 원래 요청 format의 native panel로 fallback한다.

write 성공 뒤 실제 destination을 current source와 최근 문서로 기록하고 `notifySaved(fileName)`을 호출한다. 이 RPC가 upstream filename, dirty state와 recovery draft를 정리한다. RPC 동기화가 실패해도 이미 완료된 durable write는 되돌리지 않고 별도 오류로 알린다.

### HWPX 저장 뒤 `Command+S`

실제 UI에서 HWP source를 HWPX로 저장한 뒤 `Stage 4 save check`를 추가하고 `Command+S`를 실행했다.

- save panel 재표시 없음
- 같은 `.hwpx` URL 유지
- 27,780 → 27,801 bytes
- 수정 시각과 SHA-256 변경
- 갱신 결과 ZIP signature와 `unzip -t` 유지
- 알한글/core 재열기와 추가 텍스트 render 확인

따라서 HWPX 저장 후 일반 저장이 HWP exporter로 되돌아가지 않고 `exportHwpx`를 계속 사용한다는 핵심 요구사항을 단위 계약과 실제 UI 왕복 양쪽에서 확인했다.

## 수용 기준별 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `HWP 형식으로 저장`은 `.hwp`와 HWP payload 사용 | OK | 실제 HWP→HWP, HWPX→HWP 결과가 CFB `d0cf11e0a1b11ae1`, 알한글/core 재열기 통과 |
| `HWPX 형식으로 저장`은 `.hwpx`와 `exportHwpx` payload 사용 | OK | bridge 계약 테스트와 실제 HWP→HWPX, HWPX→HWPX 결과가 ZIP `504b0304`, `unzip -t` 통과 |
| HWPX 저장 뒤 `Command+S`는 같은 URL에 HWPX 재저장 | OK | 실제 UI 편집 후 panel 없이 동일 URL의 크기·mtime·hash 변경, ZIP/container/reopen 유지 |
| 확장자와 payload의 교차 기록 방지 | OK | request/response format, signature와 destination mismatch 단위 테스트가 write 전에 거부 |
| 저장 결과 재열기와 대표 내용 유지 | OK | 네 형식 조합 모두 알한글 재열기, core page 1 text run과 non-blank render 통과 |
| 실패·취소·중복 요청과 clean state 유지 | OK | panel 취소 뒤 제자리 저장, 읽기 전용 HWPX 동일 형식 fallback, 중복 `Command+S`, 문서 전환 시 unsaved guard 없음 |
| upstream/core 직접 수정 없음 | OK | bundled asset 검증 통과, `Sources/RhwpCoreBridge` 변경 없음 |
| PDF 생성 경로 변경 없음 | OK | Task #456 diff에 PDF controller/backend 변경 없음. 별도 Task #455에서 처리 |

## 최종 통합 검증

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과. `project.yml`에서 project를 재생성했고 추가 diff 없음 |
| clean `HostAppTests` (`build.noindex/task456/final-tests`) | `** TEST SUCCEEDED **`, 100개, 실패 0개 |
| clean HostApp Debug build (`build.noindex/task456/final-build`) | `** BUILD SUCCEEDED **` |
| final app bundled asset 검증 | 통과 |
| `./scripts/check-no-appkit.sh` | 통과 |
| Stage 4 HWPX 세 결과 `unzip -t` | 모두 통과 |
| 저장·fallback 결과 5개 core render smoke | 모두 page 1 text run/non-white pixel 통과 |
| 네 형식 조합 알한글 UI 재열기 | 모두 완료 filename과 page 상태로 재열림 |
| 원본 fixture SHA-256 | smoke 입력과 일치, 원본 변경 없음 |
| `git diff --check` | 통과 |

Xcode build가 등록한 `build.noindex` Debug 앱은 표준 hygiene helper, 대상별 `pluginkit -r`/`lsregister -u`와 LaunchServices garbage collection으로 정리를 시도했다. macOS가 대상별 unregister에 `-10814`를 반환해 LaunchServices dump의 개발 경로 기록은 남았지만 실행 중이던 smoke 앱은 종료했고, Quick Look/Thumbnail active provider root는 `/Applications/Alhangeul.app` 하나임을 확인했다. 저장소 정책에 따라 전역 LaunchServices reset과 파일 삭제는 수행하지 않았다.

## 잔여 위험과 후속 작업

- 대표 fixture의 텍스트·표·이미지와 non-blank render는 확인했지만 upstream exporter가 모든 HWP/HWPX 요소를 의미론적으로 완전 무손실 보존한다고 보장하지 않는다.
- runtime HWPX guard는 ZIP magic까지만 검사한다. 손상 ZIP이나 필수 entry 누락은 별도 container 검증 없이는 runtime guard를 통과할 수 있다.
- chunked base64 encoding으로 JavaScript call-stack 위험을 줄였지만 JS와 Swift가 전체 payload를 보유하는 메모리 비용은 대용량 문서에서 남는다.
- `notifySaved`는 durable write 뒤 비동기 실행되므로 실패 시 파일은 저장됐지만 upstream dirty/recovery 상태가 남을 수 있으며 사용자에게 동기화 오류가 표시된다.
- PDF 메뉴와 생성 backend의 native page SVG + `WKWebView.createPDF` 전환은 별도 [#455](https://github.com/postmelee/alhangeul-macos/issues/455) 범위다.
- PR merge 뒤 #456 close, `publish/task456`/`local/task456`과 분리 worktree 정리는 merge 확인 후 수행한다.

## 작업지시자 승인 요청

Task #456의 5개 Stage, 최종 수용 검증과 결과보고서 작성을 완료했다. `publish/task456`을 `devel` 대상으로 게시한 PR의 리뷰와 merge 승인을 요청한다.
