# Task M020 #565 Stage 5 — 설치 글꼴 설정 UI와 공급 계약

- 이슈: [#565](https://github.com/postmelee/alhangeul-macos/issues/565), M020 / v0.2 계열
- 브랜치: `local/task565` → `devel`
- 승인: Stage 4 보고 후 작업지시자의 “진행해줘”로 Stage 5 승인
- 기준: [구현계획](../plans/task_m020_565_impl.md)

## 구현 결과

설정의 기본 글꼴 화면을 ‘Mac에 설치된 글꼴 사용’과 ‘글꼴 목록 새로고침’으로 전환했다. 앱 시작 시 하나의 모델/service를 준비하고 설정 창도 같은 인스턴스를 관찰한다. service 생성의 저장 파일 읽기는 MainActor 밖에서 수행한다. 기본 동작은 글꼴 복사/import를 호출하지 않는다.

목록에는 이름·family·style과 제한 상태를 표시한다. 초기 조회, 빈 목록, 부분 누락, 읽기 권한 부족, 저장된 권한 재선택, 준비/변경 실패를 구분한다. 원본 삭제·비활성 시 사용할 수 없고 현재 문서 적용은 준비 중임을 안내한다. 원본 삭제 UI는 없다. 기존 복사 기반 화면은 ‘가져온 글꼴 보관함’ sheet로 보존했다.

권한 선택창은 폴더만 한 개 선택하며 읽기 권한 저장 목적을 설명한다. 선택 취소는 기존 상태를 보존한다. 저장된 권한 문제는 해당 grant ID를 교체한다. grant 안내가 많아도 화면 전체를 밀어내지 않도록 스크롤 높이를 제한했다.

UI snapshot은 단일 updates 스트림 순서로만 반영한다. 개별 작업 반환값으로 최신 알림을 덮어쓰지 않는다. busy 동안 사용자 변경을 직렬화하고 저장 실패를 성공으로 낙관 표시하지 않는다.

`InstalledFontSupplyCatalog`은 generation·사용 설정·전체 실패·누락 수와 face별 opaque ID/이름/style/version/traits/axes/제한을 직렬화한다. URL/bookmark/stat/grant ID는 소비자 DTO에 포함하지 않는다. 축이 있는 face는 미지원이며 일반 face도 실제 bytes 검증 전에는 적용 성공으로 표시하지 않는다. 리소스 읽기는 기존 service의 ID·generation 검증을 사용한다.

## 검증

| 항목 | 결과 |
|------|------|
| 글꼴 XCTest | **89개 통과, 실패 0** (기존 86 + UI 상태·저장 실패·DTO 노출 방지 3) |
| HostApp Debug 빌드 | **BUILD SUCCEEDED**, 마지막 변경 후 재검증 |
| macOS 12 대상 UI probe | warnings-as-errors 컴파일·ad-hoc 서명 검증 통과 |
| 공용 Swift 의존·shell 문법·diff | 통과 |
| 개발 등록 정리 | 이번 Debug 앱·helper 등록 해제 및 중간 앱 제거, 최종 Issues/Warnings 없음 |
| 실제 SwiftUI 화면 | 밝은/어두운 모드, 긴 이름·충돌·권한 안내, 720×560 확인 |
| 실제 UI 동작 | 사용 설정 체크 변경, 재실행 복원, 보관함 열기·Escape 닫기, Tab 목록 포커스, 권한 선택창 Escape 취소 확인 |

테스트 앱은 `Tests/InstalledFontUIProbe`에 있으며 메타데이터와 저장소를 격리했다. 실제 글꼴을 설치/삭제하거나 사용자의 앱 설정을 변경하지 않았다. 테스트 앱은 권한 제출을 의도적으로 지원하지 않는다. 실제 bookmark 지속 권한은 Stage 4 증거와 Stage 6 재검증 범위다. 목록에서 방향키로 행 선택하는 동작은 selection을 제공하지 않아 검증 성공으로 주장하지 않는다.

최초 probe 실행에서 List의 기본 크기 때문에 창이 커지는 문제가 있어 제품 설정과 같은 고정 크기를 적용한 뒤 최종 화면을 재촬영했다. 중복 실행된 자체 probe 프로세스는 종료했다.

로그: `build.noindex/task565-stage5/font-tests.log`, `host-build.log`, `ui-probe-dark.log`, `ui-probe-light.log`, `hygiene-final.log`. 실제 실행 OS는 macOS 26.5.2이며 macOS 12 실제 실행은 미검증이다.

## 화면 확인

아래는 실제 제품 View를 테스트 메타데이터로 실행한 화면이다. 실제 설치 목록이나 문서 렌더링 결과를 뜻하지 않는다.

![밝은 화면](../../build.noindex/task565-stage5/screenshots/light.jpeg)
![어두운 화면](../../build.noindex/task565-stage5/screenshots/dark.jpeg)

직접 실행은 저장소 루트에서 `scripts/probe-installed-font-ui.sh` 또는 `scripts/probe-installed-font-ui.sh --dark`를 사용한다. 기존 창을 닫고 다음 모드를 실행한다. 자세한 격리 범위는 [재현 안내](../../Tests/InstalledFontUIProbe/README.md)에 기록했다. 미서명 HostApp 중간 산출물은 사용자 실행용으로 제공하지 않는다.

## 다음 단계 경계

Stage 5는 설정 UI와 공급 DTO까지다. Studio 제품 메시지 handler·매칭·렌더 캐시 연결은 #567, PDF/인쇄/native/Quick Look/썸네일은 #568, 전체 수용과 웹 안내는 #569다. 체크박스를 켠 것만으로 문서가 설치 글꼴을 사용한다고 주장하지 않는다.

다음 승인 대상은 Stage 6 기반 회귀·signed sandbox 재실행 및 소비자별 인계다. 이슈 close·PR·merge·배포는 수행하지 않았다.

## 사용자 피드백 반영 — Stage 5 UI 보완

작업지시자의 “다듬고 내가 직접 조작할 수 있게 창을 띄워줘” 승인으로 제목 중복과 정상 항목의 기술적 설명을 제거했다. family별 스타일을 묶고 검색·펼치기·스크롤을 제공한다. 체크박스는 사용 설정 아래로 옮겼으며 현재 설정만 저장됨을 명시한다. 권한 버튼은 해당 face 옆에 두고 선택창을 원본 폴더에서 시작하도록 했다.

실제 Mac 목록을 격리 저장소로 확인하는 `--live` probe를 추가했다. 실제 목록 232개 family에서 검색·펼치기·스크롤을 확인했다. List의 macOS 런타임 경고를 확인하여 ScrollView/LazyVStack으로 변경 후 동일 동작을 재검증했다. macOS 12 대상 warnings-as-errors 컴파일·ad-hoc 서명 검증, 공용 Swift 의존 및 diff 검사를 통과했다. 이번 보완은 UI와 probe 변경으로 기존 89개 service 테스트 결과와 구분한다.

최신 화면은 `build.noindex/task565-stage5/screenshots/refined-search.jpeg`다. 사용자 조작을 위해 실제 목록 테스트 창을 열어 둔다. 제품 앱 설정 및 글꼴 원본은 변경하지 않았으며 문서 렌더러 연결과 Stage 6은 여전히 후속 범위다.

사용자의 20개 이상 가상 목록 요청에 따라 기본 probe를 28개 family/84개 face로 확대했다. 실제 설치 없이 검색·스크롤·긴 이름·충돌·권한 부족·미지원 표시를 조작할 수 있다. macOS 12 대상 컴파일·서명 검증 통과 후 창에서 28개 표시를 확인했고, 사용자 조작용으로 열어 두었다. 화면은 `screenshots/demo28.jpeg`, 로그는 `ui-demo28.log`다.

사용자 스크린샷 피드백에 따라 펼친 스타일 목록에 leading 32pt(부모 이름보다 약 20pt 안쪽)와 bottom 8pt를 적용했다. 목록 내용의 trailing 여백을 24pt로 늘려 overlay 스크롤바와 내용이 겹치지 않도록 했다. 부모 구분선 정렬은 유지했다. macOS 12 대상 warnings-as-errors 컴파일·서명 검증 및 실제 펼친 화면 확인을 통과했고, 28개 가상 목록 창을 다시 열어 두었다. 화면: `screenshots/spacing.jpeg`, 로그: `ui-spacing.log`.
