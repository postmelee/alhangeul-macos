# Task M020 #565 Stage 1 — Mac 탐색과 출처·권한 기반

- 수행일: 2026-09-20
- 기준: [구현계획](../plans/task_m020_565_impl.md) Stage 1, 작업지시자 “진행해줘” 승인
- 상태: 코드·테스트·빌드 검증 완료, Stage 2 진입 승인 요청

## 1. 단계 목적

Mac 글꼴 가져오기 화면에서 재사용할 제한된 비동기 탐색과 선택 URL의 접근 수명 관리를 구현한다. 자동 탐색에서 확인된 앱과 수동 선택 출처를 구분하고, 실패·부분 탐색을 숨기지 않는다.

## 2. 산출물

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/MacFontDiscovery.swift` | 출처·후보·진단 모델, 계정 홈 해석, 직렬 비동기 탐색·취소, 방문/깊이/후보 한도 |
| `Sources/HostApp/Services/FontImportSourceSession.swift` | 중복 URL scope 획득, worker lease, close 이후 마지막 worker 종료 시 해제 |
| `Tests/FontLibraryTests/MacFontDiscoveryTests.swift` | 새 테스트 11개 |
| `Tests/MacFontDiscoveryProbe/main.swift` | 실제 설치본 읽기 전용 탐색 결과 요약 |
| `scripts/probe-mac-font-discovery.sh` | macOS 12 대상 컴파일 및 진단 실행 |
| `project.yml`, 생성된 Xcode 프로젝트 | 테스트에 새 서비스 소스 연결 |

HostApp 소스 디렉터리에 추가해 실제 앱 빌드에 포함했으나 앱 시작이나 UI에서 탐색을 실행하는 연결은 아직 없다. 저장소 schema·기존 서비스 API·시스템 글꼴·사용자 원본을 변경하지 않았다. Xcode 프로젝트는 생성기로 갱신했다.

## 3. 확정 동작

- `/Applications`와 실제 계정 홈의 Applications 후보를 깊이 4로 탐색한다. sandbox 컨테이너 홈과 계정 홈을 구분한다.
- 자동 앱 식별은 실측된 `com.haansoft.HancomOfficeViewer.Mac`를 기준으로 한다. 다른 편집기는 앱 직접 선택으로 조사한 세 문서 경로를 탐색할 수 있으나 한컴 출처로 자동 확정하지 않는다.
- 앱 내부는 `TTF/Install`, `TTF/Hwp`, `Fonts` 문서용 후보만 탐색한다. 다른 앱·framework·bundle 안으로 일반 폴더 탐색을 확장하지 않는다.
- OS 사용자/공용 Fonts는 별도 출처다. 자동 OS 탐색에 시스템 Fonts는 포함하지 않는다.
- TTF·OTF·TTC·OTC 후보를 수집하고 HFT는 미지원 개수로 분리한다. 파일 형식·지원 가능 여부는 가져오기 공통 계층이 최종 판정한다.
- 글꼴 폴더 깊이 32, 방문 항목 20,000, 후보 4,096 한도에서 부분 탐색 진단을 제공한다. symlink·alias를 따라가지 않고 지정 루트의 symlink 조상도 거부한다.
- 미존재·권한 거부·읽기 오류·안전하지 않은 경로·깊이/방문/후보 한도는 구분된다. 미존재 진단에는 해당 앱 버전에 없는 선택적 후보 경로도 포함되므로 UI에서 앱 미설치로 해석하지 않아야 한다.
- close는 새 lease를 막지만 진행 중 worker를 강제로 종료하지 않는다. 취소 토큰을 확인한 worker가 끝난 후 scope를 해제한다. false scope 획득은 실제 읽기를 막는 조건이 아니며 stop을 호출하지 않는다.

## 4. 검증 결과

| 검증 | 결과·증거 |
|------|-----------|
| 공통·탐색 XCTest | **65개 통과, 실패 0**. 기존 54개 + 신규 11개. `build.noindex/task565-stage1/font-tests.log` |
| HostApp Debug compile/link | **BUILD SUCCEEDED**. 최종 소스 기준, `host-build.log` |
| 공용 Swift 경계 | `scripts/check-no-appkit.sh` 통과 |
| macOS 12 arm64 | 읽기 전용 probe `-warnings-as-errors` 컴파일·실행 통과 |
| macOS 12 x86_64 | 동일 소스 `-typecheck -warnings-as-errors` 통과, `intel-typecheck.log` |
| 실제 설치본 | Host 읽기 전용: 한컴 뷰어 12.31.8에서 문서용 후보 **9개**, OS 별도 설치 후보 **222개**. `discovery-probe-host.json` |
| shell·diff | `bash -n scripts/probe-mac-font-discovery.sh`, `git diff --check` 통과 |
| 개발 등록 정리 | 최종 hygiene: 개발 등록·앱 산출물·Issues·Warnings 모두 없음. 정식 `/Applications/Alhangeul.app` provider 유지. `hygiene-final.log` |

로그 경로는 모두 `build.noindex/task565-stage1/` 기준이다. probe는 글꼴 bytes를 복사·등록하지 않고 metadata와 경로 후보만 조사한다. 후보 수는 지원 확정·실제 설치 활성 face 수가 아니다. 실측에는 일부 깊이 제한·미존재·symlink 제외 진단이 있으며 전체 Mac 검색 완료로 주장하지 않는다.

재현 명령:

```bash
scripts/test-font-library.sh
scripts/probe-mac-font-discovery.sh
scripts/check-no-appkit.sh
```

테스트는 다중 설치·미확인 앱 수동 선택·UI 아이콘 제외·중복 경로·지원 확장자·한글 이름·symlink와 연결된 문서 폴더·앱/글꼴 깊이·방문/후보 한도·미존재/권한/순회 도중 오류·취소·scope 해제/소멸을 검증한다.

초기 테스트에서 Foundation의 `/private/var` → `/var` 표시 정규화 때문에 임시 폴더를 unsafe로 오판했다. 표준 시스템 별칭을 비교 양쪽에 정규화하여 해결했다. 순회 오류 주입 테스트에서도 URL 표현 차이를 경로 정규화로 보정했다. 실제 제품 코드는 오류 종류를 숨기는 우회 없이 검증했다.

초기 sandbox 제한의 Xcode cache 접근 실패는 호스트 빌드 권한에서 재검증했다. XCTest 런타임 dylib의 최소 OS 14 링크 경고는 현재 도구 체인 특성이며 macOS 12 실행 성공 증거로 사용하지 않는다.

HostApp 빌드가 자동 등록한 개발 앱은 표준 hygiene helper로 해제하고 이번 단계의 재생성 가능한 앱 산출물만 제거했다. 내부 Sparkle `Updater.app` 등록이 별도로 남아 해당 정확한 경로에 `lsregister -u`를 수행했다. 최종 점검에서 등록 잔여물이 없으며, 다른 작업의 산출물과 설치된 정식 앱은 변경하지 않았다.

## 5. 잔여 위험과 미검증

- 실제 NSOpenPanel 선택과 signed 제품 sandbox의 자동/수동 탐색은 Stage 2–4에서 검증한다. host 진단 성공이 이를 대신하지 않는다.
- 실제 한컴 편집기 버전/설치본은 검증하지 않았다. 자동 식별 범위 확대에는 실제 bundle ID·문서 경로 근거가 필요하다.
- 후보 검증 뒤 외부 경로가 변경될 수 있으므로 UI가 발견 당시 파일을 그대로 신뢰하지 않아야 한다. 최종 원본 읽기·파일 검증은 공통 importer에서 수행한다.
- 최소 OS 실제 실행·Intel 하드웨어 실행·전체 문서 렌더링 적용은 미검증이다.
- 이번 단계는 화면 변경이 없어 스크린샷이 없다. 직접 실행 진단은 위 probe로 가능하며, UI는 Stage 2에서 스크린샷 또는 서명된 앱의 실행·메뉴 동선을 제공한다.

## 6. 다음 단계와 승인 요청

Stage 2에서 설정의 글꼴 탭과 자동/수동 후보 확인·가져오기 흐름을 연결한다. session close와 작업 취소를 화면 수명에 연결하고 현재 제한을 사용자 문구로 변환한다. Stage 1 결과를 검토한 뒤 Stage 2 진행 승인을 요청한다.
