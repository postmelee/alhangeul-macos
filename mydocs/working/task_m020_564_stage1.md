# Task M020 #564 Stage 1 — 모델·형식 검증·공유 컨테이너 기반

- 이슈: [#564](https://github.com/postmelee/alhangeul-macos/issues/564)
- 구현계획: [task_m020_564_impl.md](../plans/task_m020_564_impl.md)
- 작업 브랜치: `local/task564`
- 승인: 2026-09-17 “진행해줘”로 구현계획 승인 및 Stage 1 착수

## 1. 단계 목적

Mac/Windows 입력이 공유할 글꼴 식별·지원 제한·검사 결과 모델을 구현하고, 독립 저장소가 사용할 App Group 접근 기반을 준비한다. 파일 저장과 renderer 연결은 다음 단계 및 후속 이슈의 범위다.

## 2. 산출물

| 파일 | 내용 |
|------|------|
| `Sources/Shared/FontLibrary/FontLibraryModels.swift` | 해시 객체, SFNT face ID, 다국어 name 원문, 축/instance, 출처·사용 근거·활성 선택·결과 모델 |
| `Sources/Shared/FontLibrary/FontFileInspector.swift` | bytes 해시, signature, table 범위·중복·겹침, metadata 한도, name/fvar/OS2·필수 구조 검사, CoreText descriptor 교차 확인 |
| `Sources/Shared/FontLibrary/FontLibraryLocation.swift` | 설정·현재 프로세스 entitlement·팀 확인 후 컨테이너 URL 해석, 실패 시 명시적 오류 |
| `Sources/HostApp/Info.plist`, `HostApp.entitlements` | `XH6JHKYXV8.com.postmelee.alhangeul.font-library` 설정 |
| `project.yml`, 생성된 `Alhangeul.xcodeproj/project.pbxproj` | Rust/HostApp 실행에 의존하지 않는 FontLibraryTests 타깃 |
| `Tests/FontLibraryTests/` | 20개 XCTest, 기하 도형으로 직접 만든 6개 글꼴 fixture(총 7,984 bytes), 생성 코드·해시·설명 |
| `Tests/FontLibraryContainerProbe/main.swift` | 동일 그룹 권한의 격리 앱에서 읽기·쓰기·정리 검증 |
| `scripts/test-font-library.sh` | 설정·fixture 해시 검증, 테스트 빌드와 XCTest 직접 실행 |
| `scripts/probe-font-library-container.sh` | 지정한 인증서로 테스트 앱만 로컬 서명·검증·실행 |

Xcode 프로젝트는 `xcodegen generate`로만 생성했다. 모델은 저장 후보와 실제 renderer 적용 상태를 구분한다. TTC는 face index를 보존하지만 선택 미검증, 가변은 축·instance를 보존하지만 적용 미검증이다. HFT 등 다른 signature는 미지원이다. CoreText에 시스템/프로세스 글꼴을 등록하지 않았다.

name format 0/1, 한국어·영어 및 언어 태그를 보존한다. 모르는 인코딩은 오해하여 Unicode로 변환하지 않고 원문 bytes와 nil 해석값으로 남긴다. coverage는 OS/2의 **선언된 Unicode range**이며 실제 모든 문자 렌더 가능성을 주장하지 않는다.

## 3. 본문 변경 정도와 무손실 여부

기존 문서 읽기·저장·렌더러 코드는 수정하지 않았다. 테스트 자산은 사각형 glyph를 직접 생성했으며 사용자·한컴 글꼴을 복사하거나 바꾸지 않았다. 수행/구현계획과 오늘할일은 승인·검증 상태를 갱신했다. 문서 본문 보존 및 HWP/HWPX round-trip은 이번 단계의 변경·검증 대상이 아니다.

## 4. 검증 결과

환경: macOS 26.5.2(25F84), arm64, Xcode 26.5 SDK, XcodeGen 2.45.4. 최소 타깃은 macOS 12.0을 유지했다.

| 검증 | 결과 |
|------|------|
| `scripts/test-font-library.sh` | PASS — XCTest 20개, 실패 0; 설정 일치·fixture SHA-256 확인 |
| 정상 TTF/OTF·regular/bold·TTC·가변 | PS/weight·SFNT index·축/instance와 제한 상태 확인 |
| 이름·형식·손상 | 다국어/format 1/알 수 없는 인코딩 원문 보존, 위장 확장자 구분, table 탈출·겹침·중복·overflow·가변 참조 오류 거부 |
| 한도·잘림 | 파일 크기 경계, metadata 예산, 4개 형식별 첫 128개 길이의 잘린 입력 거부(512개 입력) |
| 컨테이너 실패 | 잘못된 설정·미보유 entitlement·다른 팀·nil/비파일 URL에서 실패, 대체 경로 없음 |
| arm64 / x86_64 typecheck | 양쪽 `-target …-apple-macosx12.0 -warnings-as-errors` 통과 |
| signed sandbox probe | Developer ID 서명 검증, 그룹 임시 파일 읽기·쓰기·삭제 PASS |
| plist·shell·경계·diff | `plutil -lint`, `bash -n`, `scripts/check-no-appkit.sh`, `git diff --check` 통과 |

재현 명령:

```sh
scripts/test-font-library.sh
scripts/probe-font-library-container.sh 'Developer ID Application: Taegyu Lee (XH6JHKYXV8)'
xcrun swiftc -typecheck -warnings-as-errors -target arm64-apple-macosx12.0 \
  -module-cache-path build.noindex/task564-stage1/module-cache Sources/Shared/FontLibrary/*.swift
xcrun swiftc -typecheck -warnings-as-errors -target x86_64-apple-macosx12.0 \
  -module-cache-path build.noindex/task564-stage1/module-cache-x86 Sources/Shared/FontLibrary/*.swift
```

최종 로그:

- `build.noindex/task564-stage1/final-test.log`: `Executed 20 tests, with 0 failures` (22:32:00 KST).
- `build.noindex/task564-stage1/container-probe.log`: `PASS: signed sandbox App Group read/write; temporary probe removed`.
- `build.noindex/task564-stage1/test-without-building.log`: 별도 Xcode `test-without-building` 호출도 20개 통과 (22:30:45 KST).

### 실행 중 보완

- 제한된 실행 환경의 첫 Xcode 호출은 Sparkle 다운로드가 막혔다. 필요한 접근을 허용하여 해결했다.
- Security API에서 dynamic code를 static code로 변환한 뒤 signing information을 조회하도록 수정하고 양쪽 아키텍처 typecheck를 통과했다.
- XcodeGen의 중첩 source group 중복 경고는 공통 `Sources/Shared` 경로에 include 필터를 적용해 해결했다.
- 로컬 Xcode testmanager에서 스크립트 안의 `xcodebuild test` 및 빌드/실행 분리 호출은 간헐적 번들 로드 오류로 테스트 시작 전에 실패했다. ad-hoc 서명만으로 해소되지는 않았다. 별도 Xcode 실행과 동일 번들의 `xcrun xctest`는 통과했다. 정확한 환경 원인은 미확정이며 최종 스크립트는 빌드 성공 후 동일 번들을 XCTest 실행기로 실행하여 20개 테스트를 모두 검증한다. 오류를 무시하거나 테스트를 생략하는 fallback은 없다.
- 설치된 XCTest 프레임워크의 macOS 14 최소 버전에 관한 linker 경고가 있었다. 제품 소스 macOS 12 typecheck와 최신 OS XCTest 실행을 구분하며 최소 OS runtime 검증으로 대체하지 않는다.

## 5. 잔여 위험

- actual signed **HostApp** 및 Quick Look/Thumbnail 소비자는 아직 연결하지 않았다. 이번 서명 증거는 같은 그룹과 공통 location 코드를 사용하는 격리 앱이며 macOS 12 실제 실행도 미검증이다.
- group ID는 기존 설치 앱·배포 스크립트에서 확인한 팀을 사용한다. 다른 팀으로 서명한 개발 빌드는 해당 그룹 접근을 거부한다. 릴리스 스크립트가 임의 변수를 치환하지 않으므로 Info/entitlement에는 같은 literal을 두고 테스트로 일치를 확인한다.
- 구조 검사는 완전한 font sanitizer가 아니다. CFF/glyph 명령 전체 해석·실제 글리프 선택·모든 cmap의 의미적 유효성은 보증하지 않는다. 정적 항목도 `staticCandidate`이며 실제 렌더 성공을 표시하지 않는다.
- 관리 파일 읽기·복사·manifest·writer 잠금·내구성·snapshot/lease는 아직 미구현이다. inspector의 Data 입력 한도에 더해 Stage 2에서 파일을 읽기 전 한도도 적용해야 한다.
- 테스트 fixture는 metadata/경계 검증용이다. 실제 한컴 자산, 대형 CJK 파일, 손상 입력에 대한 성능·메모리 수용은 후속 검증 대상이다.
- 신규 CI 연결과 HostApp 전체 build는 Stage 4에서 수행한다. 현재 로컬에 Rhwp.xcframework가 없으며 이번 독립 테스트를 제품 전체 빌드로 보고하지 않는다.

## 6. 다음 단계 영향과 근거

Stage 2는 동일 핸들에서 제한된 bytes를 읽고 `FontFileInspector`에 전달한 바로 그 bytes를 저장한다. 객체·face ID를 중복/충돌 키의 재료로 사용하며 metadata의 대표 표시 이름을 문서 resolver로 오해하지 않는다. 지원 제한과 복사/임베딩 근거는 manifest에 별도로 유지한다.

App Group naming과 접근은 [Apple 컨테이너 API](https://developer.apple.com/documentation/Foundation/FileManager/containerURL%28forSecurityApplicationGroupIdentifier%3A%29), [macOS 그룹 접근](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)을 확인하고 로컬 서명 실험을 수행했다. SFNT/name/fvar 경계는 [OpenType 파일 구조](https://learn.microsoft.com/en-us/typography/opentype/spec/otff), [name](https://learn.microsoft.com/en-us/typography/opentype/spec/name), [fvar](https://learn.microsoft.com/en-us/typography/opentype/spec/fvar)를 참고했다. 확인일은 2026-09-17이다.

## 7. 승인 요청

Stage 1 결과를 검토한 뒤 **Stage 2 — 독립 글꼴 저장과 중복·충돌 처리** 진입 승인을 요청한다. 다음 단계에서는 staging/불변 객체/원자적 manifest 게시와 재시도·부분 실패·동시 writer 검증을 구현한다.
