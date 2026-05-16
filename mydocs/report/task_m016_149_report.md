# Task #149 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#149 손상·대용량 HWP/HWPX 파일 opening fallback 보강](https://github.com/postmelee/alhangeul-macos/issues/149) |
| 마일스톤 | M016 / v0.1 출시 전 보강 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task149` |
| 단계 수 | 5단계 |
| 결론 | HostApp, Quick Look preview, Finder thumbnail의 손상·빈 파일·미지원 입력·50 MB 초과 opening fallback 기준을 정리하고 구현했다. HostApp은 synthetic empty/corrupt open smoke에서 프로세스 유지까지 확인했고, extension 코드는 QLExtension/ThumbnailExtension build로 검증했다. 설치본 기준 Quick Look/Thumbnail negative smoke는 #151 gate로 넘긴다. |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/Shared/HwpDocumentInputValidator.swift` | HWP/HWPX signature preflight, 입력 오류, fallback reason/classifier 추가 |
| `Sources/Shared/HwpPageImageRenderer.swift` | thumbnail `.never` 정책에서 50 MB 초과 파일을 full data read 전에 차단 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | 파일 읽기 실패, 빈 문서, 손상/미지원 문서 메시지 taxonomy 적용 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | `rhwp-studio` status의 `파일 로드 실패:`를 native `document-load-error`로 전달 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `document-load-error` message를 fatal document load failure로 연결 |
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | 사용자 문서 load failure category와 기본 fallback 문구 추가 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | render/encoding 실패를 reply closure 밖에서 잡고 plain text fallback으로 mapping |
| `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | parse/render/access fallback 대상 오류를 기존 fallback tile로 mapping |
| `Alhangeul.xcodeproj/project.pbxproj` | `xcodegen generate` 결과로 새 Shared 파일을 target source에 반영 |
| `mydocs/manual/build_run_guide.md` | 손상/대용량 opening fallback smoke 절차 추가 |
| `README.md` | `corrupt file fallback` checklist 상태 갱신 |
| `mydocs/plans/task_m016_149.md` | 수행계획서 |
| `mydocs/plans/task_m016_149_impl.md` | 5단계 구현계획서 |
| `mydocs/working/task_m016_149_stage1.md` | 현행 opening/fallback 경로 inventory |
| `mydocs/working/task_m016_149_stage2.md` | fallback taxonomy와 구현 기준 |
| `mydocs/working/task_m016_149_stage3.md` | HostApp opening fallback 구현 보고 |
| `mydocs/working/task_m016_149_stage4.md` | Quick Look/Thumbnail fallback 구현 보고 |
| `mydocs/working/task_m016_149_stage5.md` | synthetic smoke와 release gate 정리 |

## 변경 전·후 정량 비교

| 항목 | 결과 |
|------|------|
| 단계 커밋 | 계획 2개 + Stage 1~5 5개 |
| 변경 파일 | 19개 |
| diff 규모 | 1,490 insertions / 50 deletions |
| 신규 shared helper | `HwpDocumentInputValidator`, `HwpDocumentFallbackClassifier` |
| HostApp hard block | 추가하지 않음 |
| Quick Look/Thumbnail 50 MB 기준 | 기존 `hwpQuickLookMaxFileSize = 50 * 1024 * 1024` 유지 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `aae1138` | 수행계획서와 오늘할일 항목을 작성했다. |
| 구현계획 | `e209e54` | 5단계 구현계획서와 수용 기준을 확정했다. |
| Stage 1 | `825c404` | HostApp, Quick Look, Thumbnail의 현행 negative input 전파 경로를 정리했다. |
| Stage 2 | `e65fd70` | empty/corrupt/50 MB/parse/render/encoding failure taxonomy와 문구를 확정했다. |
| Stage 3 | `9f130cc` | HostApp input preflight와 WebView document load failure bridge를 구현했다. |
| Stage 4 | `f8633f1` | Quick Look plain text fallback, Thumbnail fallback tile mapping, 대용량 full read 방지를 구현했다. |
| Stage 5 | `8b3e614` | synthetic smoke 결과, release gate 문서, #151/#146 handoff를 정리했다. |

## 검증 결과

| 수용 기준 | 결과 | 비고 |
|------|------|------|
| Shared code AppKit/UIKit 의존 없음 | OK | `./scripts/check-no-appkit.sh` |
| HostApp Debug build | OK | `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` |
| QLExtension Debug build | OK | `xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension ... build` |
| ThumbnailExtension Debug build | OK | `xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension ... build` |
| HostApp empty/corrupt open smoke | OK | Debug app으로 `empty.hwp`, `corrupt.hwp` open 후 `pgrep -x Alhangeul` 확인 |
| 정상 sample thumbnail smoke | OK | `samples/basic/KTX.hwp produced one thumbnail` |
| 51 MB large thumbnail smoke | OK | `large.hwp produced one thumbnail` |
| empty/corrupt thumbnail 설치본 smoke | 후속 | 현재 시스템 등록 산출물 기준 `No thumbnail created`; signed/sealed 설치본 기준 #151에서 재검증 |
| Quick Look preview GUI 문구 눈검증 | 후속 | `qlmanage -p -x -o`는 ExtensionFoundation 내부 예외로 gate에서 제외 |
| 문서 정합성 검색 | OK | `rg -n "50 MB|손상|대용량|fallback|corrupt file fallback|Quick Look|Thumbnail"` |
| whitespace 검증 | OK | `git diff --check` |

Xcode/CoreSimulator 관련 sandbox 경고와 provisioning profile 경고가 빌드 로그에 출력됐지만 macOS build 결과는 성공이었다.

## fallback 결과

| 표면 | 입력 | 결과 |
|------|------|------|
| HostApp | 빈 파일 | `비어 있는 문서는 열 수 없습니다.` taxonomy로 opening 실패 처리 |
| HostApp | 명백한 non-HWP/HWPX signature | `이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다.` taxonomy로 opening 실패 처리 |
| HostApp | `rhwp-studio` 문서 load 실패 | `document-load-error` native bridge로 fatal document load fallback |
| HostApp | 50 MB 초과 | hard block 없음. 앱 opening 제한과 preview 제한을 분리 |
| Quick Look | 50 MB 초과 | plain text fallback |
| Quick Look | 손상/미지원/빈 문서 | plain text fallback mapping |
| Thumbnail | 50 MB 초과 | 기존 fallback tile |
| Thumbnail | parse/render/access 실패 | 기존 fallback tile mapping |

## 후속 작업

| 후속 이슈 | 넘길 내용 |
|----------|-----------|
| #151 Quick Look/Thumbnail 설치본 smoke gate | signed/sealed package 설치 후 `empty.hwp`, `corrupt.hwp`, `large.hwp`, 정상 sample의 preview/thumbnail을 재검증한다. 빈/손상 thumbnail이 생성되지 않으면 extension 등록 대상, Quick Look cache, content type routing, fallback classifier 순서로 분리한다. |
| #146 렌더 경로 한계 문서화 | HostApp 50 MB hard block 없음, HWPX ZIP magic 수준 preflight, 손상 문서 fallback은 복구가 아니라 crash/hang/raw error 방지 목적이라는 제한을 known limitation으로 넘긴다. |
| 통합 브랜치 최신화 | 작업 중 `devel-webview`가 #148 merge로 전진했다. merge-tree 상 README가 양쪽에서 변경됐으므로 PR에서 최신 base와의 비교를 확인한다. |

## 잔여 위험

| 구분 | 내용 |
|------|------|
| 설치본 Quick Look/Thumbnail | Debug build는 compile/link 확인용이고 Finder/Quick Look 등록 검증의 진실 원천이 아니다. #151에서 release package 기준으로 확인해야 한다. |
| Quick Look preview | GUI plain text fallback 문구는 설치본 또는 foreground preview에서 직접 눈검증하지 못했다. |
| HWPX 구조 검증 | HWPX preflight는 ZIP magic까지만 확인하며, 내부 구조 손상은 parser/render 단계 fallback에 맡긴다. |
| 대용량 HostApp opening | HostApp에는 50 MB hard block을 추가하지 않았다. 대용량 앱 opening 안정성은 별도 성능/호환성 항목이다. |

## 완료 판단

#149의 구현 단계는 완료했다.

- HostApp은 파일 읽기 실패, 빈 문서, 손상/미지원 signature, WebView 문서 load 실패를 구분한다.
- Quick Look/Thumbnail은 parse/render/encoding failure를 raw error 대신 fallback으로 수렴시키는 코드 경로를 갖는다.
- 50 MB 기준은 Quick Look/Thumbnail preview 제한으로 유지했고 HostApp opening 제한과 섞지 않았다.
- synthetic smoke 절차와 설치본 gate handoff가 문서에 남았다.

## 작업지시자 승인 요청

Task #149의 손상·대용량 HWP/HWPX opening fallback 보강을 완료했다. 다음 단계는 `publish/task149` 브랜치 push와 `devel-webview` 대상 PR 생성이다.
