# Issue #70 Stage 5 완료 보고서

## 타스크

- GitHub Issue: #70
- 마일스톤: M040
- 제목: HostApp 디버그 사이드바를 About 패널로 이전하고 확장 상태 조회를 보정
- 작업 브랜치: `local/task70`
- Stage: 5. 초기 상태바 레이아웃 보정
- 완료 시각: 2026-04-26 17:31 KST

## 목표

사이드바 제거 후 빈 문서 초기 화면에서 하단 상태바의 `문서 없음` 텍스트가 창 왼쪽 하단이 아니라 중앙 콘텐츠 영역의 왼쪽 아래에 붙어 보이는 문제를 보정한다.

## 원인

`DocumentViewerView`의 루트 `ZStack`이 창 전체 폭과 높이를 명시적으로 채우지 않은 상태에서 `.safeAreaInset(edge: .bottom)`이 적용됐다. 이 때문에 빈 문서 상태에서는 상태바가 창 전체 하단이 아니라 콘텐츠 크기 기준 하단에 배치될 수 있었다.

## 변경 내용

`Sources/HostApp/Views/DocumentViewerView.swift`:

- 루트 `ZStack`에 `.frame(maxWidth: .infinity, maxHeight: .infinity)`를 추가했다.
- `StatusBarView`의 `HStack`에 `.frame(maxWidth: .infinity, alignment: .leading)`을 추가했다.

## 확인 결과

- Debug 앱 초기 화면에서 왼쪽 디버그 사이드바는 표시되지 않는다.
- 중앙의 `HWP 또는 HWPX 문서를 열어 주세요.` 안내와 `문서 열기` 버튼은 중앙에 유지된다.
- `문서 없음` 상태 텍스트는 창 왼쪽 하단에 표시된다.
- toolbar의 문서 열기와 zoom control은 유지된다.

## 검증

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

### 실제 앱 실행 확인

```bash
/usr/bin/open -n build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app
```

결과:

- 수정된 Debug 앱을 실행해 초기 화면을 확인했다.
- `문서 없음` 상태바 텍스트가 창 왼쪽 하단에 표시됨을 확인했다.
- 확인 후 실행한 Debug 앱 프로세스를 종료했다.

## 최종 보고서 갱신

- `mydocs/report/task_m040_70_report.md`에 Stage 5 보정 결과와 검증 내용을 반영했다.

## 승인 요청

Stage 5 완료와 최종 보고서 갱신을 기준으로 `publish/task70` 원격 게시 및 `devel` 대상 draft PR 생성 승인을 요청한다.
