# Task M020 #565 Stage 2 — 설정과 Mac 글꼴 가져오기 화면

- 수행일: 2026-09-20
- 승인: Stage 1 보고 후 작업지시자의 “진행해줘”로 착수
- 상태: 구현·검증 완료, Stage 3 승인 대기
- 기준: [구현계획](../plans/task_m020_565_impl.md)

## 1. 단계 목적

기존 개인정보 설정을 유지하면서 글꼴 설정을 추가하고, Mac 글꼴 탐색·수동 위치 선택·후보 선택·일괄 가져오기·기본 결과를 실제 SwiftUI 화면으로 연결한다.

## 2. 산출물과 변경 범위

| 파일 | 역할 |
|------|------|
| `Views/AppSettingsView.swift` | 개인정보·글꼴 탭, 720×560pt 설정 컨테이너 |
| `Views/FontLibrarySettingsModel.swift` | 서비스 준비, 화면 상태, 선택·배치 전달·취소·늦은 응답 방어 |
| `Views/FontLibrarySettingsView.swift` | 빈 보관함·목록·새로고침·가져오기 진입 |
| `Views/MacFontImportView.swift` | 출처·후보·처리 중·기본 결과, NSOpenPanel |
| `HostApp.swift` | 앱 단위 StateObject와 Settings scene 연결 |
| `Tests/FontLibraryTests/FontLibrarySettingsModelTests.swift` | 새 상태 전이 테스트 6개 |
| `Tests/FontLibraryUIProbe/main.swift`, `scripts/probe-font-library-ui.sh` | 동일 제품 View의 격리 preview·실제 sheet smoke |
| `project.yml`, 생성된 Xcode 프로젝트 | 테스트 소스 연결 및 생성 결과 |

View/HostApp 경로는 `Sources/HostApp/` 기준이다. 개인정보 View·토글·분석 서비스 코드는 수정하지 않았다. 기존 App Group 저장 및 원본 검증 계약도 유지했다. 서비스는 UI 최초 사용 시 생성하며 자동 가져오기를 앱 시작에 실행하지 않는다.

## 3. 사용자 흐름과 수명

1. 알한글 설정의 ‘글꼴’ 탭에서 ‘기존 한글 글꼴 가져오기…’를 누른다.
2. ‘이 Mac의 한글’ 또는 ‘Mac에 설치한 글꼴’을 선택한다. 직접 앱·폴더 선택도 가능하다.
3. 출처별 후보와 크기를 확인하고 전체/개별 선택한다. 검색 제한·접근 실패·HFT 제외를 안내한다.
4. 하나의 배치로 가져온다. 처리 중에는 불확정 진행 표시와 취소를 제공하며 임의의 퍼센트를 만들지 않는다.
5. 보관됨·이미 있음·선택 필요·지원 제한·오류·취소를 기본 결과로 표시하고 최신 목록을 조회한다.

panel 취소는 기존 후보·선택을 유지한다. 중복 버튼 실행은 busy 상태로 차단한다. 닫힌 탐색 화면의 오래된 응답은 요청 ID로 무시한다. 가져오는 중 화면이 닫히면 취소 요청 후 worker 종료까지 busy를 유지하고, 이미 저장된 결과를 재조회한다. 선택 원본 session의 lease는 처리 종료까지 유지한다.

‘문서 표시·출력 적용은 준비 중입니다’라는 문구로 보관과 실제 렌더링을 구분한다. 상세 오류별 재시도, 기존 충돌 선택 변경, 삭제·지원 제한 상세는 Stage 3 범위다.

## 4. 검증 결과

| 검증 | 결과 |
|------|------|
| 글꼴·UI 모델 XCTest | **71개 통과, 실패 0**. 기존 65개 + 새 6개 |
| 개인정보·HostApp XCTest | **224개 통과, 실패 0** |
| HostApp Debug compile/link | **BUILD SUCCEEDED** |
| 실제 SwiftUI sheet smoke | 자체 fixture 3개 탐색·가져오기·목록 확인 통과 |
| 수동 창 확인 | NSOpenPanel 폴더 선택, 후보 3개, 선택 취소 후 유지, 재가져오기 ‘이미 있음’ 결과 확인 |
| 공용 Swift 경계·shell·diff | check-no-appkit, bash -n, git diff --check 통과 |
| 개발 등록 정리 | 이번 빌드 두 앱과 내부 Sparkle 도우미 등록 해제, 해당 Debug 앱만 제거. 최종 hygiene Issues·Warnings 없음, 정식 설치본 provider 유지 |

증거 위치는 `build.noindex/task565-stage2/`이며 `font-tests.log`, `host-tests-results.log`, `host-build-final.log`, `ui-probe.log`를 보존했다. 첫 HostApp 테스트에서는 Spotlight 검증이 요구하는 같은 Products 폴더의 앱이 없어 1개 실패했다. 해당 폴더에 실제 HostApp을 빌드하고 동일 224개 테스트를 재실행해 모두 통과했다. 제품 코드를 우회하지 않았다.

UI smoke는 macOS 12 target·warnings-as-errors로 동일 View/모델을 컴파일하며 ad-hoc 서명된 독립 앱에서 실행한다. 시스템 sandbox나 제품 App Group 접근을 검증한 것으로 해석하지 않는다. 비대화형 smoke 종료는 sheet 애니메이션 중 AppKit의 종료 보류와 분리해 fixture 정리 후 프로세스를 종료한다.

보관함 준비 실패 상태에서는 빈 목록 안내를 표시하지 않도록 최종 보완했다. 해당 View를 포함한 UI probe를 다시 warnings-as-errors로 컴파일하고 실제 sheet smoke를 통과했다. 최종 등록 정리 결과는 `hygiene-final.log`에 있다.

## 5. 실제 화면과 직접 확인

SwiftUI bitmap 캐시 캡처에서 일부 레이어가 빠져 해당 이미지는 폐기했다. 대신 computer-use로 실행 중 창을 확인·캡처했다. 아래 사진은 **실제 제품 View를 자체 fixture와 격리 저장소로 실행한 preview**다. 공개 배포 제품 또는 실제 한컴 글꼴의 renderer 적용 화면이 아니다.

| 화면 | 로컬 증거 |
|------|-----------|
| 출처 선택 | `build.noindex/task565-stage2/screenshots/source-window.jpeg` |
| 후보·선택 | `build.noindex/task565-stage2/screenshots/candidates-window.jpeg` |
| 기본 결과(동일 파일 재가져오기) | `build.noindex/task565-stage2/screenshots/results-window.jpeg` |
| 보관함 목록 | `build.noindex/task565-stage2/screenshots/library-window.jpeg` |

직접 확인하려면 저장소에서 다음을 실행한다.

```bash
scripts/probe-font-library-ui.sh --interactive
```

별도 ‘알한글 글꼴 화면 — 테스트 데이터’ 창이 열린다. ‘기존 한글 글꼴 가져오기…’를 누른 뒤 ‘한글 앱 또는 글꼴 폴더 선택…’에서 터미널에 출력된 검증용 글꼴 폴더를 고르면 된다. 실제 설정 탭 통합은 HostApp에 구현됐으며 preview는 글꼴 내용과 sheet를 직접 호스팅한다. preview의 데이터는 `build.noindex/task565-stage2/ui-data/`의 실행별 경로에 저장되어 제품 보관함을 변경하지 않는다. 대화형 실행 데이터는 확인용으로 남기고 비대화형 smoke 데이터만 자동 정리한다.

## 6. 잔여 위험

- signed 제품 sandbox의 자동 탐색·NSOpenPanel 접근·최소 OS 실제 실행은 Stage 4의 검증 대상이다.
- 편집기 실제 설치본, 전체 렌더러 연동, 한컴 제거 후 사용 가능 여부는 아직 검증하지 않았다.
- Stage 2는 기본 목록·결과까지다. 상세 충돌·삭제·재시도·지원 제한 설명을 Stage 3에서 완성한다.
- 화면은 밝은 모드와 자체 fixture 기준으로 확인했다. 어두운 모드·긴 이름·오류 화면·키보드 흐름은 Stage 3 시각 검증에서 확장한다.

## 7. 다음 단계 승인 요청

Stage 3 결과·충돌·목록 관리 구현에 대한 승인을 요청한다. 화면 피드백이 있으면 다음 단계에 함께 반영한다.
