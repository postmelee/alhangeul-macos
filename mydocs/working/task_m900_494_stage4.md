# Task M900 #494 Stage 4 검증 중간 보고서

## 단계 목적

2026-09-06 작업지시자의 Stage 4 진행 승인에 따라 source PR, devel → main, `v0.1.11` tag와 서명·공증 draft를 생성하고 실제 설치본을 검증했다. **HWP3 변환 복사본 저장이 sandbox 권한 오류로 실패하므로 Stage 4 완료와 official 공개를 보류한다.** 이 문서는 성공한 배포 준비, 실패 재현, 복원 결과와 필요한 수정 범위를 기록한다.

검증 후보는 `f3bb7bc73510593c35c2e423323bbb01d62c3aad`, tree `b370c2fd41e8f1f1da11958651225b1cbe68e22d`다. 앱은 `0.1.11 (17)`, rhwp는 `v0.8.6` / `f1f9c6ae58344ee9368996d3543f76b9345cf227`이다. 이 후보의 HWP3 저장 성공이나 최종 배포 가능 판정을 내리지 않는다.

## 산출물

| 대상 | 결과 / 위치 |
|------|-------------|
| Source PR | [#495](https://github.com/postmelee/alhangeul-macos/pull/495), merge `fe1efcf898613886fbdb6353f847ff3478c2aa0b` |
| main release PR | [#496](https://github.com/postmelee/alhangeul-macos/pull/496), merge `f3bb7bc73510593c35c2e423323bbb01d62c3aad` |
| annotated tag | `v0.1.11` → 위 main commit, 원격 peeled commit 일치 |
| signed draft | [Alhangeul v0.1.11 (rhwp v0.8.6)](https://github.com/postmelee/alhangeul-macos/releases/tag/untagged-9fe71ba4d0e2e4372b1b), release ID `383597735`, draft=true / prerelease=false |
| Publish run | [34035992953](https://github.com/postmelee/alhangeul-macos/actions/runs/34035992953), success |
| DMG | `build.noindex/task494/stage4/draft/alhangeul-macos-0.1.11.dmg`, 180,206,297 bytes |
| DMG SHA256 | `3894bba275dcaab66092b81dc27d41e8673729ea2582587b13628e03a22dbf5b` — 실패한 draft 후보의 값이며 official digest가 아님 |
| 전체 증거 | `build.noindex/task494/stage4/`: PR·CI·run·public snapshot, 서명 로그, AX·화면, 저장본, 원본 비교와 복원 자료 |
| 기록 문서 | release record/index, 두 계획서, 오늘할일, 이 보고서 |

Draft 조회는 `gh release view v0.1.11` 또는 release ID API로 확인했다. REST tag endpoint가 draft에 404를 반환한 조회는 release 부재로 판정하지 않았다. GitHub asset digest, checksum 파일, 본문, 다운로드 파일의 SHA256·크기가 일치한다.

## 본문 변경 정도와 무손실 여부

PR #495 검토에서 공개 준비 페이지의 상단 다운로드 링크 3개가 아직 없는 새 asset을 가리킨다는 지적을 반영했다. `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.11.html`의 상단 링크를 현재 공개 release로 바꾼 commit은 `882c97aeb9a708108ac261dd2380f6f3a403cb12`다. 최종 source PR tree와 devel/main tree가 같으며, Stage 3 검증 후 제품 source 변경은 없다.

이 중간 보고 시점의 추적 변경은 내부 기록 6개다. 발견한 저장 결함의 제품 source와 기존 tag·draft는 아직 변경하지 않았다. 공통 core lock·Cargo·header·Studio 기준은 보존했다. 원본 samples 180개는 SHA256·size·mtime가 같고, Stage 4 fixture 원본 6개도 SHA256·size가 같다. 저장 결과는 task 경로의 새 파일에만 썼다.

설치 전 `~/Applications/Alhangeul.app` v0.1.8 (14)를 ZIP과 146개 파일·링크 manifest로 백업했다. 표준 smoke로 signed 앱을 일시 설치한 뒤 종료하고 기존 v0.1.8을 복원했다. 146개 항목이 모두 일치하고 codesign 검증도 통과했다. `/Applications/Alhangeul.app` v0.1.10 (16)은 수정하지 않았다. 최종 PlugInKit에는 이 두 기존 설치본만 있고 v0.1.11 provider는 없다. 검증 DMG 마운트 두 경로는 모두 해제하고 검증용 Finder 창을 닫았다. 기존 Downloads 창은 유지했다.

## 검증 결과

| 검증 | 판정과 근거 |
|------|-------------|
| PR #495 CI·검토 | [34034506405](https://github.com/postmelee/alhangeul-macos/actions/runs/34034506405) 4개 checks 성공. Copilot 지적 3개 링크 수정, 후속 검토에 새 inline 지적 없음 |
| PR #496 CI·검토 | [34035171362](https://github.com/postmelee/alhangeul-macos/actions/runs/34035171362) 4개 checks 성공. Copilot은 requester quota로 검토 불가; 승인 review로 기록하지 않음. exact head·tree와 제품 diff 대조 |
| main Pages gate | [34035880238](https://github.com/postmelee/alhangeul-macos/actions/runs/34035880238) success, 새 asset 부재로 artifact 준비·upload·deploy skip 후 draft 생성 |
| draft workflow | exact tag에서 draft=true 실행 성공. signing·notarization·staple·asset 검증 성공; Sparkle/appcast/Pages 관련 단계 skip |
| DMG trust | hdiutil verify, stapler validate, Gatekeeper Notarized Developer ID 통과 |
| 앱 trust | 앱·Preview·Thumbnail·Sparkle 및 내부 구성요소 8개 strict 서명, 예상 Team ID, timestamp, hardened runtime, debug entitlement 없음. 앱 staple·Gatekeeper 통과 |
| 앱 내용 | 세 bundle `0.1.11 (17)`와 arm64/x86_64 일치. canonical Legal·copyright·Release endpoint·Studio tag/commit/Cargo fingerprint 통과 |
| DMG layout | 720×460 background, 노출 항목 app + Applications symlink. Finder에서 DMG를 직접 열면 toolbar hidden icon view, 설치 안내·화살표·두 아이콘 정상. `dmg-normal-open.png` |
| 설치 앱 식별 | 실제 실행 경로 `~/Applications/Alhangeul.app`; About의 v0.1.11 (17), rhwp v0.8.6 확인 |
| 평문 HWPX | 9페이지 열기 → 새 `signed-saved.hwpx` 저장 → Command+S → 재열기 9페이지. ZIP 무결성 통과 |
| 보호 HWPX | 암호 열기 23페이지, 평문 경고 취소·재진입, 새 `signed-decrypted.hwpx` 저장·무암호 재열기 23페이지 |
| 보호 HWP5 | 암호 열기 64페이지, 평문 경고 취소·재진입, 새 `signed-decrypted-hwp5.hwp` 저장·무암호 재열기 64페이지 |
| 보호 HWP3 | 암호 열기 24페이지와 보호 해제+HWP5 변환 경고·취소 정상. 새 HWP5 저장은 임시 파일 권한 오류로 실패 |
| 평문 HWP3 | 16페이지 열기와 변환 경고 정상. 새 HWP5 저장은 같은 임시 파일 권한 오류로 실패 |
| PDF·인쇄 | signed HWPX PDF 9페이지·869,612 bytes·794×1123 pt, 한글 1,796자 추출. 인쇄 9페이지 준비 → 취소 → PDF 저장 패널 재진입·취소 성공 |
| 열기 복구 | 빈 HWP 안내 → 다시 시도 → 선택 취소 뒤 기존 HWPX URL·9페이지 유지 |
| 종료 상태 | HWPX 저장 완료·후속 Command+S 뒤 Command+Q에서 저장 안내 재표시. 저장 선택 후 종료. 재열기한 HWP5를 native 메뉴로 종료할 때는 안내 없이 종료 |
| 표준 Finder helper | `smoke-finder-integration.sh --app <signed app>` exit 0, HWP/HWPX thumbnail 파일 생성. `draft-finder/task151-20260906-231002/` |
| 실제 Finder provider | HWP 미리보기 화면은 렌더됐으나 새 provider 실행 경로는 입증하지 못함. 기존 v0.1.10 Preview와 HOP Thumbnail 프로세스가 관찰돼 v0.1.11 실제 provider 통과로 판정하지 않음 |
| 원본·복원 | samples 180개, fixture 6개 변경 0. 원래 사용자 앱 146개 항목 일치, 기존 provider 두 버전 복원 |
| public 상태 | latest v0.1.10, public home·appcast가 시작 snapshot과 byte 동일. Homebrew 변경 없음 |

로컬 서명 audit 첫 실행은 `lipo` 인자 순서 오류로 중단했다. ignored 검증 스크립트만 고쳐 재실행한 결과 위 검사가 모두 통과했다. 제품 또는 signature 결함이 아니며 첫 실패 로그도 보존했다. strict static archive byte 비교 예외는 [Stage 3](task_m900_494_stage3.md) 및 현재 CI의 portable 정책과 동일하며 source/header/ABI 검증을 유지했다.

### HWP3 저장 실패 재현과 원인 근거

1. `gui-fixtures/plain-hwp3.hwp` 또는 `protected-hwp3.hwp`를 설치한 signed 앱으로 연다. 보호 fixture는 공개 샘플의 암호로 연다.
2. Command+S → 변환 경고 확인 → 같은 fixture 폴더의 새 파일명을 선택한다.
3. `.<새 파일명>.<UUID>.tmp` 파일을 폴더에 저장할 권한이 없다는 오류가 나타난다. 목적 파일은 생성되지 않고 원본은 보존된다.
4. `signed-plain-hwp3-save-result.ax.txt/.png`와 `signed-protected-hwp3-copy-saved.ax.txt/.png`에 오류를 보존했다.

[DocumentSaveContract.swift](../../Sources/HostApp/Services/DocumentSaveContract.swift)의 `writeNewFileAtomically`는 선택된 destination의 **부모 폴더에 임의 sibling 임시 파일**을 만든 뒤 `RENAME_EXCL`로 게시한다. NSSavePanel이 허용한 선택 파일과 임시 파일 경로가 달라 signed sandbox에서 실패한 UI 결과와 일치한다. 같은 폴더에서 일반 HWPX·보호 HWP5 복사본 저장은 성공했다. 시스템 sandbox 로그 조회에서는 추가 거부 행을 얻지 못했으므로 별도 OS 로그 입증으로 표현하지 않는다.

기존 write-policy XCTest는 자체 temporaryDirectory 안에서 실행되어 NSSavePanel의 파일 단위 권한 조건을 재현하지 않았다. HWP3→HWPX도 같은 신규 destination writer를 사용하므로 영향 가능성이 있지만 signed GUI 재현은 아직 HWP5 출력 두 경우에 한정한다.

### 다음 수정안

별도 버그 이슈 제목 후보는 **“Sandbox 앱에서 HWP3 변환 복사본 저장 시 임시 파일 권한 오류를 수정한다”**다. 관련 #482와 동일한 열린 milestone `v0.1` (`M010`), `bug`·`kind:regression`·`area:viewer-app` 라벨을 제안한다. 등록 본문은 `build.noindex/task494/stage4/hwp3-save-issue-body.md`에 준비했다. 아직 등록·게시하지 않았다.

- `DocumentSaveContract.swift`와 필요한 `DocumentSavePanel.swift` 범위에서 macOS가 제공하는 destination volume의 임시 저장 위치·선택 URL 접근 수명을 검증한다. Apple의 [itemReplacementDirectory](https://developer.apple.com/documentation/Foundation/FileManager/SearchPathDirectory/itemReplacementDirectory) 및 [동일 volume 임시 위치 안내](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat(_:withitemat:backupitemname:options:))를 참고하되, 실제 sandbox에서 동작하는지 검증한 뒤 채택한다.
- 완성된 파일만 게시하고 기존 destination·경쟁 생성 파일을 덮어쓰지 않는 `RENAME_EXCL` 계약을 유지한다. 광범위한 폴더 접근 권한이나 sandbox 해제로 해결하지 않는다. `replaceItemAt`으로 기존 파일을 무조건 교체하는 방식도 채택하지 않는다.
- 기존 실패·경쟁 생성·원본 보존 테스트를 유지하고 NSSavePanel로 선택한 sandbox 밖 경로의 통합 검증을 추가한다. 평문/보호 HWP3 → HWP5/HWPX 네 조합, 취소·재열기·후속 저장 및 기존 HWP5/HWPX 저장을 재검증한다.
- 저장 후 종료 안내는 별도 관찰이다. Command+Q가 수정으로 분류될 가능성이 있는 keyboard handler를 native 메뉴 종료와 비교해 추가 재현한다. HWP3 임시 파일 오류와 같은 원인으로 단정하거나 현재 수정안에 무조건 포함하지 않는다.

## 잔여 위험

- HWP3 변환 저장 실패는 필수 앱 smoke 차단 사유다. 이 draft를 official Publish·Homebrew에 사용하지 않는다.
- 새로운 provider의 실제 Finder Preview/Thumbnail 경로, signed 색상 부분 적용·undo/redo, PDF 앱에서 선택·검색·복사, 나머지 저장 조합은 수정 후보에서 검증해야 한다. renderer·텍스트 추출·helper 성공으로 대체하지 않는다.
- Intel Mac·macOS 12 실기기와 maintainer 직접 확인, Sparkle 실제 업데이트·Homebrew는 미실행이다. Computer Use로 한 검증을 maintainer 직접 확인으로 기록하지 않는다.
- 기존 두 앱 설치와 HOP 등 provider 선택 환경은 그대로 보존했다. 등록 hygiene 전체 통과나 자동 업데이트 후 자연 등록 성공을 주장하지 않는다.
- GitHub에 tag와 draft가 존재하지만 stable public release는 여전히 v0.1.10이다. draft가 있는 동안 main docs 변경·docs-only 재실행의 공개 영향을 계속 주의한다.

## 다음 단계 영향

Stage 4는 **진행 중 / 필수 저장 smoke 실패**다. Stage 5 승인을 요청할 상태가 아니다. 버그 이슈·계획·수정·회귀 검증·PR 절차를 거친 새 후보에서 signed draft를 다시 생성하고 Gate 2/4의 본문·provenance·설치 검증을 갱신한다. 기존 v0.1.11 tag/draft는 재현 기준으로 유지한다. 후보 교체 시 tag 처리와 Publish exact 입력은 구체적인 수정 commit이 준비된 뒤 승인 범위를 확정한다.

## 승인 요청

승인 대상은 **HWP3 저장 버그의 별도 이슈 등록과 수정·회귀 검증 진행**이다. 제품 source 변경 전 승인을 요구하는 [AGENTS.md](../../AGENTS.md)와 버그 수정 task를 별도로 추적하는 [release runbook](../manual/public_release_runbook.md)을 적용한다. 기존 승인인 PR 병합·tag·draft 생성의 재승인이 아니다. 공식 공개·Pages·Sparkle·Homebrew 승인은 이번 요청에 포함하지 않는다.

### 복구 진행 — 2026-09-07

2026-09-07 작업지시자가 PR #498 병합 → main 반영 → 기존 v0.1.11 tag 재지정·draft 자산 교체 → 서명·공증 재검증을 승인했다. 수정 PR은 `6fac59e2f3a19d9762cece3165d1da211d094aea`로 devel에 병합했다. 새 main SHA와 tag는 병합 결과로 확정한다. `version=0.1.11`, `build=17`, `previous_release_ref=v0.1.10`, `expected_rhwp_tag=v0.8.6`, `require_latest_rhwp=true`, `include_rhwp_in_title=true`, `draft=true`, `prerelease=false`로 실행한다. 기존 draft 본문·asset·hash를 보존하고 자산 교체 후 새 결과를 검증한다. docs/** 변경 및 docs-only Pages 실행은 공식 공개 단계로 남긴다. Official 공개·Sparkle·Pages·Homebrew는 이번 승인에 포함하지 않는다.

수정 제품 source는 `a9758e20cbb480b5338bc3f08696386027d113d1`이다. XCTest 184개, 실제 sandbox Debug 앱 저장·재열기 6조합, PR CI 3개 job 통과와 release helper job 생략을 확인했다. Copilot 검토는 할당량 초과로 미실행이었다. 수정 전 draft의 실패 증거와 위 기록은 보존하고, 새 공증 draft 결과를 후속 기록한다.
