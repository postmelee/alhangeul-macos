# Task M020 #564 Stage 4 — 글꼴 관리 서비스 통합 검증과 후속 계약

- 이슈: [#564](https://github.com/postmelee/alhangeul-macos/issues/564), M020
- 구현계획: [task_m020_564_impl.md](../plans/task_m020_564_impl.md)
- 브랜치: `local/task564`
- 승인: Stage 3 보고 후 2026-09-18 “진행해줘”로 Stage 4 진입. 로컬 서명 인증 대기 후 같은 날 “승인할 준비가 되었어”로 재시도.

## 1. 결과

HostApp이 공통 글꼴 저장소를 사용할 서비스와 원본 접근 권한 수명을 연결했다. 서비스 포함 XCTest 54개, 기존 Studio 문서 lifecycle 39개, 실제 HostApp 빌드, Rust portable 검증이 통과했다. 서명된 실제 HostApp 진단 복사본에서 가져오기·원본 삭제·앱 종료 후 재실행 읽기까지 통과했다.

사용자용 가져오기 버튼/탐색 및 실제 렌더러 연결은 후속 이슈다. 이번 단계는 입력 계층과 소비자가 사용할 공통 서비스·검증·인계 계약을 완성한다.

## 2. 변경

| 위치 | 내용 |
|------|------|
| `Sources/HostApp/Services/FontLibraryService.swift` | App Group 기반 구성, prepare/list/import/선택/삭제/snapshot/read/release/recover 진입점 |
| `Sources/HostApp/HostApp.swift` | 지연 생성 서비스 Result 소유, Debug 전용 서명 진단 분기 |
| `Tests/FontLibraryTests/FontLibraryServiceTests.swift` | 폴더 scope·중복 scope·false 획득·취소·배치 한도·입력/저장 오류와 자원 해제 검사 |
| `project.yml`, 생성 Xcode 프로젝트 | 독립 FontLibraryTests에 실제 HostApp 서비스 소스 포함 |
| `.github/workflows/pr-ci.yml` | macOS validation에서 기존 글꼴 검증 스크립트 실행 |
| `Sources/HostApp/Support/FontLibraryHostProbe.swift` | Debug에서만 격리 App Group 저장소 생성/가져오기/재실행 읽기 |
| `scripts/probe-font-library-host.py` | 실제 빌드 복사본의 로컬 서명, 두 번 실행, 소유 앱/등록/격리 저장소 정리 |
| [후속 연동 계약](../tech/font_library_integration.md) | #565~#568 입력·관리·충돌·snapshot·bytes 공급 예시와 제한 |

### 서비스

후속 UI는 `AppDelegate.fontLibraryService`에서 구성 결과를 받고 최초 사용 시 `prepare()`로 검증·복구한다. 앱 시작 시 자동 탐색하거나 기존 문서 열기/저장 흐름에 importer를 실행하지 않는다. App Group 구성 실패는 다른 저장 폴더로 우회하지 않는다.

원본 후보와 security scope URL을 별도로 받아 사용자가 고른 부모 폴더를 유지할 수 있다. 같은 URL은 한 번만 획득하고 성공적으로 획득한 scope만 배치 종료·실패·취소 뒤 해제한다. start가 false여도 이미 접근 가능한 파일일 수 있어 실제 읽기 결과로 판정한다. 저장 I/O는 기존 store의 직렬 큐에 위임한다.

배치를 파일별 서비스 호출로 분해하지 않아 파일 수·누적 bytes 제한을 보존한다. store의 후보별 상태·게시 내구성 상태와 관리 오류를 그대로 전달한다. UI가 사용 조건 미확인을 허가로 표시하거나 저장 성공을 실제 적용 성공으로 표시하지 않도록 인계 문서에 구분했다.

### 진단

진단은 실제 HostApp Debug 실행 파일과 동일 서비스 코드를 사용한다. 앱 복사본의 bundle ID를 진단용으로 분리하고 제품의 App Group entitlement를 유지한다. 고유 UUID 폴더만 사용하며 제품 `FontLibrary/v1`의 manifest는 변경하지 않는다. 두 번째 프로세스에서 원본 없이 관리 bytes를 재검사한 뒤 폴더를 제거한다.

Xcode Debug는 구현을 `Alhangeul.debug.dylib`로 분리하므로 진단 진입점 확인은 실행 파일과 dylib을 모두 검사한다. 모든 Debug dylib, Sparkle 하위 구성요소, 확장/importer, 최상위 앱 순으로 같은 인증서로 서명한다. hardened runtime library validation을 끄지 않았다. Release에는 진단 분기가 컴파일되지 않으며 릴리스·공증·배포는 실행하지 않았다.

## 3. 검증과 회복

환경: macOS 26.5.2, arm64, 로컬 APFS. 최소 deployment target macOS 12 유지.

| 검증 | 결과/증거 (`build.noindex/task564-stage4/`) |
|------|-------------------------------------------|
| 공통 계층+서비스 XCTest | **54개, 실패 0**, `font-tests.log` (20:50:39 KST) |
| 실제 HostApp Debug 및 포함 타깃 빌드 | **BUILD SUCCEEDED**, `host-build.log` |
| 기존 문서 lifecycle | **39개 통과**, `lifecycle.log`; 실제 window·dirty·저장/취소·종료, 원본 입력 유지 |
| Rust universal framework/고정 core | **portable 검증 통과**, `rust-build.log`; lock 수정 없음 |
| macOS 12 컴파일 | 공통 계층+서비스 arm64/x86_64 warnings-as-errors typecheck 통과 |
| 실제 signed HostApp | create/reopen 모두 **PASS**, `signed-host-final.log` |
| signed 실행 상세 | `build.noindex/font-host-probe-6p23s614/create.log`, `reopen.log`; 두 프로세스의 bytes 무결성 확인 |
| 서명/진단 정리 | codesign deep/strict 검증, 진단 앱 삭제 후 LaunchServices 경로 소멸 확인; 스크립트 exit 0 |
| 기본 검사 | AppKit 경계, Python 구문, workflow/project YAML, 문서 링크, diff 검사 통과 |

진행 중 발견한 문제와 처리:

1. 개별 서비스 소스를 테스트에 추가했을 때 Xcode 그룹 중복 경고가 발생했다. `project.yml`에서 HostApp 경로의 includes로 변경하고 재생성/재빌드해 해소했다.
2. 처음 서명은 시간 초과 및 `errSecInternalComponent`로 실패했고 작은 대조 probe에서도 SecurityAgent 대기 뒤 같은 오류가 발생했다. 사용자에게 OS 인증 확인을 요청했고 준비 후 재시도하여 서명 자체가 통과했다. 키체인 보안 설정이나 인증서를 변경하지 않았다.
3. 실제 실행에서 Debug dylib의 Team ID 불일치로 dyld가 거부했다. 모든 Debug dylib을 같은 인증서로 먼저 서명하도록 진단 스크립트를 수정한 뒤 create/reopen이 모두 통과했다.
4. `pluginkit -r`의 이미 없는 항목과 `lsregister -u`의 -10814를 실행 실패와 구분했다. 알려진 no-plugin 응답만 허용하며, 앱 등록 정리는 명령 반환만으로 성공 처리하지 않고 소유 복사본 제거 후 실제 LaunchServices 경로가 없어졌는지 검사한다. 이전 실패 복사본과 검증을 마친 Debug 앱도 소유 경로만 정리하고 로그를 보존했다. 전역 등록 초기화는 하지 않았다.

재현 명령:

```sh
scripts/test-font-library.sh
scripts/build-rust-macos.sh --verify-portable
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/task564-stage4/DerivedData CODE_SIGNING_ALLOWED=NO build
python3 scripts/smoke-studio-document-lifecycle.py --fixture samples/re-font-dotum-empty-hancom.hwp
python3 scripts/probe-font-library-host.py \
  build.noindex/task564-stage4/DerivedData/Build/Products/Debug/Alhangeul.app \
  'Developer ID Application: Taegyu Lee (XH6JHKYXV8)'
scripts/check-no-appkit.sh
git diff --check
```

진단 스크립트는 자기 복사본만 제거한다. Xcode가 자동 등록한 원본 Debug 산출물의 정리는 실행자가 별도로 확인한다. 이번 검증은 그 산출물까지 제거하고 기존 설치본을 유지했다.

## 4. 미검증·후속 범위

- macOS 12 실제 실행과 Intel 하드웨어 실행은 미검증이다. macOS 12 typecheck와 최신 OS 실행을 대신하는 증거로 쓰지 않는다. Xcode의 XCTest dylib 최소 버전 경고 및 AppIntents 미사용 metadata 경고는 남아 있다.
- 실제 NSOpenPanel로 한컴 폴더를 고르는 UI·sandbox 권한 승인 과정은 #565에서 검증한다. 이번 scope 수명은 주입 테스트로 검사했고 signed 실제 앱의 입력은 격리 컨테이너 내부 fixture다.
- 실제 사용자 한컴 글꼴·TTC/가변의 renderer 적용·PDF/인쇄·확장 공유는 #565~#568 범위다. 웹페이지 안내와 통합 테스트는 #569다.
- PR CI 연결은 완료했으며 로컬에서 같은 스크립트가 통과했다. 원격 GitHub Actions 결과는 PR 게시 후 확인한다. 이번 단계에서 PR 게시·merge·이슈 close는 하지 않았다.

**Stage 4 완료. 최종 결과보고서 작성 승인 대기.** 단계 소스와 본 보고서를 함께 커밋하며, 다음 승인 후 전체 수용 기준/제약을 최종 보고서로 정리한다.
