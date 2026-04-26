# Issue #70 Stage 4 완료 보고서

## 타스크

- GitHub Issue: #70
- 마일스톤: M040
- 제목: HostApp 디버그 사이드바를 About 패널로 이전하고 확장 상태 조회를 보정
- 작업 브랜치: `local/task70`
- Stage: 4. 통합 검증과 보고
- 완료 시각: 2026-04-26 17:20 KST

## 목표

viewer 사이드바 제거, About 메뉴/창 추가, 확장 상태 표시 보정이 통합 상태에서 빌드와 실제 앱 실행 흐름으로 동작하는지 확인하고 최종 보고서를 작성한다.

## 변경 내용

`mydocs/orders/20260426.md`:

- #70 오늘할일 상태를 `완료`로 변경하고 완료 시각을 기록했다.

`mydocs/report/task_m040_70_report.md`:

- 전체 단계 결과, 변경 파일, 검증 결과, 잔여 위험과 PR 게시 승인 요청을 정리했다.

## 검증 결과

### diff check

```bash
git diff --check
```

결과:

- 통과

### AppKit 경계 검사

```bash
./scripts/check-no-appkit.sh
```

결과:

- `OK: shared Swift code has no AppKit/UIKit dependencies`

### Xcode project 확인

```bash
xcodebuild -list -project AlhangeulMac.xcodeproj
```

결과:

- `HostApp`, `QLExtension`, `ThumbnailExtension` target과 scheme 확인
- CoreSimulator, Xcode log store 관련 warning이 출력됐지만 project 목록 조회는 성공했다.

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

- `BUILD SUCCEEDED`
- CoreSimulator 관련 warning이 출력됐지만 macOS HostApp compile/link는 성공했다.

### 산출물 확인

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
  build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
  build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Info.plist
find build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns \
  -maxdepth 1 \
  -name '*.appex' \
  -print
```

결과:

- executable: `AlhangeulMacHost`
- bundle identifier: `com.postmelee.alhangeulmac`
- 포함 확장:
  - `AlhangeulMacThumbnail.appex`
  - `AlhangeulMacPreview.appex`

### 실제 앱 실행 확인

```bash
/usr/bin/open -n build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app
pgrep -fl AlhangeulMacHost
```

결과:

- Debug 앱 프로세스가 기동됐다.
- 검증 후 `알한글 > 알한글 종료`로 종료했고, `pgrep -x AlhangeulMacHost` 기준 실행 프로세스가 남지 않았다.

Computer Use로 확인한 UI 상태:

- viewer 초기 화면에 왼쪽 디버그 사이드바가 표시되지 않는다.
- 중앙 문서 열기 안내, `문서 열기` 버튼, toolbar의 문서 열기/zoom control, 하단 `문서 없음` 상태바가 유지된다.
- 앱 메뉴 `알한글 > 알한글에 관하여` 항목이 표시된다.
- About 창에 앱 이름, 설명, `v0.1.0 (1)`, 버전 `0.1.0`, 빌드 `1`이 표시된다.
- About 창에 Quick Look 미리보기와 Thumbnail 확장의 bundle identifier가 표시된다.
- 두 확장 모두 `앱 번들: 앱에 포함됨`, `시스템 등록: 시스템 등록됨`으로 표시된다.
- `상태 새로고침` 버튼 클릭 후 상태 표시가 유지된다.

## 확인된 한계

- `pluginkit` 조회는 실행 환경에 의존한다. Codex sandbox 내부 직접 실행에서는 `match: Connection invalid`가 발생할 수 있다.
- 실제 앱 실행 환경에서는 이번 검증에서 두 확장 모두 `시스템 등록됨`으로 표시됐다.
- 문서를 실제로 열어 페이지 렌더링까지 확인하는 범위는 이번 Stage 4에서 수행하지 않았다. 이번 타스크의 핵심 수용 기준은 viewer 디버그 사이드바 제거와 About 정보 이전이다.

## 최종 보고서

- `mydocs/report/task_m040_70_report.md`

## 승인 요청

Stage 4 완료와 최종 결과 보고를 기준으로 `publish/task70` 원격 게시 및 `devel` 대상 draft PR 생성 승인을 요청한다.
