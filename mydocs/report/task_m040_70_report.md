# Issue #70 최종 결과 보고서

## 작업 요약

- GitHub Issue: [#70](https://github.com/postmelee/alhangeul-macos/issues/70)
- Milestone: v0.4.0
- 문서 prefix: `task_m040_70`
- 작업명: HostApp 디버그 사이드바를 About 패널로 이전하고 확장 상태 조회를 보정
- 작업 브랜치: `local/task70`
- 단계 수: 5단계

HostApp viewer의 왼쪽 디버그 사이드바를 제거하고, 앱/빌드/확장 정보는 macOS 표준 앱 메뉴의 `알한글 > 알한글에 관하여`에서 확인하도록 이동했다. 확장 상태는 앱 bundle 포함 여부와 PlugInKit 시스템 등록 여부를 분리해 표시하며, 조회 실패는 실제 미등록과 구분하도록 보정했다.

## 단계별 결과

| Stage | 결과 | 산출물 |
|-------|------|--------|
| Stage 1 | viewer 왼쪽 디버그 사이드바 제거 | `mydocs/working/task_m040_70_stage1.md` |
| Stage 2 | `알한글에 관하여` 메뉴와 About 창 추가 | `AboutView.swift`, `AboutWindowPresenter.swift`, `mydocs/working/task_m040_70_stage2.md` |
| Stage 3 | 확장 번들/시스템 등록 상태 분리 표시 | `ExtensionStatusModel.swift`, `AboutView.swift`, `mydocs/working/task_m040_70_stage3.md` |
| Stage 4 | 통합 빌드, 실제 앱 실행 확인, 최종 보고 | `mydocs/working/task_m040_70_stage4.md`, 본 보고서 |
| Stage 5 | 빈 문서 초기 화면 상태바 위치 보정 | `DocumentViewerView.swift`, `mydocs/working/task_m040_70_stage5.md` |

## 변경 파일과 영향 범위

| 파일 | 영향 |
|------|------|
| `Sources/HostApp/Views/ContentView.swift` | 왼쪽 디버그 사이드바 제거, viewer 본문 중심 구조로 단순화 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | 빈 문서 초기 화면에서 하단 상태바가 창 전체 폭과 높이 기준으로 배치되도록 보정 |
| `Sources/HostApp/HostApp.swift` | `알한글에 관하여` 메뉴 연결, ContentView 초기화 정리 |
| `Sources/HostApp/Views/AboutView.swift` | 앱 정보, 버전/빌드, 확장 정보와 상태 표시 화면 추가 |
| `Sources/HostApp/Services/AboutWindowPresenter.swift` | SwiftUI About 화면을 표시하는 AppKit window owner 추가 |
| `Sources/HostApp/Services/ExtensionStatusModel.swift` | 확장 bundle 포함 상태와 PlugInKit 등록 상태를 분리하는 모델로 보정 |
| `Sources/HostApp/Support/BuildInfo.swift` | 앱 표시명, 버전, 빌드 번호 helper 추가 |
| `AlhangeulMac.xcodeproj/project.pbxproj` | 신규 HostApp Swift source 반영 |
| `mydocs/orders/20260426.md` | #70 등록 및 완료 처리 |
| `mydocs/plans/task_m040_70.md` | 수행계획서 |
| `mydocs/plans/task_m040_70_impl.md` | 구현계획서 |
| `mydocs/working/task_m040_70_stage1.md` | Stage 1 완료 보고 |
| `mydocs/working/task_m040_70_stage2.md` | Stage 2 완료 보고 |
| `mydocs/working/task_m040_70_stage3.md` | Stage 3 완료 보고 |
| `mydocs/working/task_m040_70_stage4.md` | Stage 4 완료 보고 |
| `mydocs/working/task_m040_70_stage5.md` | Stage 5 완료 보고 |
| `mydocs/report/task_m040_70_report.md` | 최종 결과 보고 |

`Sources/RhwpCoreBridge`, Rust bridge, Quick Look/Thumbnail provider 렌더링 로직, packaging script, release 설정은 변경하지 않았다.

## 변경 전·후 정리

변경 전:

- viewer 왼쪽 사이드바에 문서 정보, 확장 상태, 빌드 정보가 함께 노출됐다.
- 앱 내부 `pluginkit` 조회 실패가 `확인할 수 없음`으로만 표시되어 bundle ID 문제, 실제 미등록, 조회 환경 실패를 구분하기 어려웠다.

변경 후:

- viewer 첫 화면은 문서 열기와 toolbar 중심으로 단순화됐다.
- 빈 문서 상태의 `문서 없음` 상태바 텍스트는 창 왼쪽 하단에 표시된다.
- 제품/빌드/확장 정보는 `알한글 > 알한글에 관하여` 창으로 이동했다.
- 확장은 `앱 번들`과 `시스템 등록` 상태를 별도로 표시한다.
- `시스템 등록 확인 불가`는 실제 `시스템 등록 없음`과 다른 상태로 분리됐다.

## 확장 ID 확인 결론

확장 bundle identifier는 기존 값이 맞다.

- `com.postmelee.alhangeulmac.QLExtension`
- `com.postmelee.alhangeulmac.ThumbnailExtension`

Stage 3에서 샌드박스 밖 `pluginkit -m -i ... -v` 조회 결과 두 ID 모두 등록됨으로 확인했다. Codex sandbox 내부 직접 조회에서는 `match: Connection invalid`가 발생했으므로, 현재 증상은 ID 불일치보다 PlugInKit 조회 환경 의존성으로 판단한다.

Stage 4 실제 앱 실행 검증에서는 About 창에 두 확장 모두 다음 상태로 표시됐다.

- `앱 번들: 앱에 포함됨`
- `시스템 등록: 시스템 등록됨`

## 검증 결과

실행한 검증:

```bash
git diff --check
./scripts/check-no-appkit.sh
xcodebuild -list -project AlhangeulMac.xcodeproj
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Info.plist
find build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns -maxdepth 1 -name '*.appex' -print
/usr/bin/open -n build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app
pgrep -x AlhangeulMacHost
```

결과:

- whitespace diff 검사 통과
- `Sources/RhwpCoreBridge` AppKit/UIKit 직접 의존 없음 확인
- `HostApp`, `QLExtension`, `ThumbnailExtension` target/scheme 확인
- HostApp Debug build 성공
- Debug app executable은 `AlhangeulMacHost`
- Debug app bundle identifier는 `com.postmelee.alhangeulmac`
- Debug app에 `AlhangeulMacPreview.appex`, `AlhangeulMacThumbnail.appex` 포함 확인
- Debug 앱 실행 성공
- viewer 초기 화면에서 왼쪽 디버그 사이드바 미노출 확인
- viewer 초기 화면에서 `문서 없음` 상태바 텍스트가 창 왼쪽 하단에 표시됨 확인
- `알한글 > 알한글에 관하여` 메뉴와 About 창 표시 확인
- About 창의 버전/빌드/확장 상태 표시와 `상태 새로고침` 동작 확인
- 검증 후 앱 종료 확인

`xcodebuild` 실행 중 CoreSimulator, Xcode log store 관련 warning이 출력됐지만 macOS HostApp build 결과에는 영향을 주지 않았다.

## 수용 기준 충족 여부

| 기준 | 결과 |
|------|------|
| viewer 왼쪽 디버그 사이드바 제거 | OK |
| 문서 열기 toolbar, zoom control, 하단 상태바 유지 | OK |
| 빈 문서 초기 화면의 `문서 없음` 상태바 위치 보정 | OK |
| `알한글 > 알한글에 관하여` 메뉴 제공 | OK |
| About 창에 앱 버전과 빌드 번호 표시 | OK |
| About 창에 Quick Look/Thumbnail 확장 정보 표시 | OK |
| 확장 bundle 포함 여부와 시스템 등록 상태 분리 표시 | OK |
| PlugInKit 조회 실패와 실제 미등록 상태 구분 | OK |
| `Sources/RhwpCoreBridge` AppKit/UIKit 직접 의존 없음 | OK |
| HostApp Debug build 성공 | OK |

## 잔여 위험과 후속 작업

- `pluginkit` 조회는 실행 환경에 따라 실패할 수 있다. 이 경우 About 창에는 `시스템 등록 확인 불가`가 표시되며 실제 미등록과 구분된다.
- 이번 작업은 HostApp viewer와 About 정보 이동이 범위다. 문서 렌더링 품질, Quick Look 렌더링 정확도, Thumbnail 생성 품질은 변경하지 않았다.
- About 창은 현재 제품 정보 중심의 소형 창이다. 향후 라이선스 목록이나 core provenance까지 넣을 경우 별도 스크롤 또는 탭 구조가 필요할 수 있다.

## 커밋 목록

```text
50fac7e Task #70: 수행 계획서 작성과 오늘할일 갱신
78b7482 Task #70: 구현 계획서 작성
714ce01 Task #70 Stage 1: viewer 디버그 사이드바 제거
2d2c558 Task #70 Stage 2: About 메뉴와 정보 화면 추가
37253ba Task #70 Stage 3: 확장 상태 표시 보정
29d9110 Task #70 Stage 4 + 최종 보고서: 통합 검증과 보고
```

Stage 5 상태바 레이아웃 보정과 문서 갱신은 본 보고서와 함께 후속 보정 커밋에 포함한다.

## 승인 요청 사항

본 최종 결과 보고서 기준으로 `publish/task70` 원격 게시와 `devel` 대상 draft PR 생성을 승인 요청한다.
