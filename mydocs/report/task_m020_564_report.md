# Task M020 #564 최종 결과보고서 — 공통 글꼴 가져오기·관리 기반

## 1. 작업 요약

- 대상: [#564](https://github.com/postmelee/alhangeul-macos/issues/564), 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562)
- 마일스톤: M020 — v0.2 계열 글꼴 마이그레이션
- 작업 브랜치: `local/task564`, PR 대상: `devel`
- 선행: #563 조사·설계 및 PR #570 통합
- 단계: 4단계 구현·검증 완료, 2026-09-18 최종 보고서 작성 승인

원본 한컴 앱이나 파일이 없어져도 읽을 수 있는 독립 글꼴 저장소와 HostApp 서비스를 구현했다. 파일 구조/메타데이터 검사, 원자적 게시, 중복/충돌 관리, 논리 삭제, snapshot을 통한 검증된 bytes 공급, 실행 중 reader 보호 및 보수적 회수를 제공한다.

이번 완료는 **공통 저장·관리 기반 #564 이슈**의 완료다. 사용자용 Mac 자동 탐색/가져오기 버튼, Windows ZIP, 문서의 실제 글꼴 적용, 웹페이지 안내는 #565~#569 후속 이슈에 남아 있다.

| 단계 | 핵심 결과 | 커밋 |
|------|-----------|------|
| [Stage 1](../working/task_m020_564_stage1.md) | 모델·SFNT 검사·App Group 구성·독립 테스트 | `7c428c0` |
| [Stage 2](../working/task_m020_564_stage2.md) | 독립 복사·원자적 저장·중복/충돌·게시 실패 처리 | `4bcb8a1` |
| [Stage 3](../working/task_m020_564_stage3.md) | snapshot·lease·논리 삭제·재가져오기·복구/GC | `a0909b1` |
| [Stage 4](../working/task_m020_564_stage4.md) | HostApp 서비스·권한 수명·CI 연결·제품 빌드/서명 및 인계 | `42cdcad` |

## 2. 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/Shared/FontLibrary/FontLibraryModels.swift`, `FontFileInspector.swift` | 객체/face/이름/축/사용 근거·결과 모델, 제한된 SFNT/TTC 구조 검사와 CoreText 교차 확인 |
| `Sources/Shared/FontLibrary/FontLibraryLocation.swift` | Info·현재 서명·entitlement 검증 및 App Group 위치 해석 |
| `Sources/Shared/FontLibrary/FontLibraryFileSystem.swift`, `FontLibraryStore.swift` | FD 기반 경로 접근·잠금·동기화·원자적 게시·import/list/select/remove/resource API |
| `Sources/Shared/FontLibrary/FontLibrarySnapshot.swift`, `FontLibraryRecovery.swift` | 불변 선택/digest, FD lease, 참조 보호와 중단 transaction/미참조 객체 회수 |
| `Sources/HostApp/Services/FontLibraryService.swift`, `HostApp.swift` | 지연 서비스 구성, 원본 scope 수명·취소와 공통 계층 연결 |
| `Sources/HostApp/HostApp.entitlements`, `Info.plist` | 배포 팀 기반 App Group 상수 일치 |
| `Sources/HostApp/Support/FontLibraryHostProbe.swift` | Debug 전용 실제 HostApp 격리 서명 진단 |
| `Tests/FontLibraryTests/` | parser/location/store/process/snapshot/service 테스트 54개 및 자체 fixture 6개 |
| `Tests/FontLibraryProcessProbe/main.swift`, `Tests/FontLibraryContainerProbe/main.swift` | 별도 프로세스 종료/reader 및 signed sandbox 진단 |
| `scripts/test-font-library.sh`, `probe-font-library-container.sh`, `probe-font-library-host.py` | 반복 가능한 테스트·설정 검사·서명/재실행/정리 |
| `project.yml`, `Alhangeul.xcodeproj/project.pbxproj`, `.github/workflows/pr-ci.yml` | 독립 타깃/스킴, 생성 프로젝트, macOS CI 실행 연결 |
| `mydocs/plans/task_m020_564*.md`, `mydocs/working/task_m020_564_stage*.md`, `mydocs/orders/20260917.md`, `20260918.md` | 계획·승인·단계 증거·진행 기록 |
| [연동 계약](../tech/font_library_integration.md), [기반 설계](../tech/font_migration_design.md), 본 보고서 | 확정 계약·후속 이슈 경계·전체 수용 결과 |

`RustBridge`, `rhwp-core.lock`, bundled Studio 자산은 변경하지 않았다. 기존 문서 열기/저장/렌더 경로에 importer를 자동 실행하지 않으며, 원본 글꼴을 수정하거나 시스템 전체에 설치하지 않는다. 생성 Xcode 프로젝트는 `project.yml`에서 재생성했다.

## 3. 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 영구 글꼴 저장/관리 계층 | 없음 | 공통 Swift 7개 파일 + HostApp 서비스 |
| 전용 자동 검사 | 0개 | XCTest 54개, 실패 0 |
| 단계별 전용 검사 | 없음 | 20 → 38 → 49 → 54개 |
| 자체 font fixture | 없음 | MIT 자체 생성 6개, 7,984 bytes, 해시 고정 |
| 게시 중 프로세스 종료 검사 | 없음 | 9개 게시 경계, 새 프로세스 재조회·회수·재시도 |
| 동시 최초 생성 검사 | 없음 | 동일 프로세스 20회, 별도 프로세스 10회 반복 |
| 기존 문서 lifecycle 회귀 | 기존 smoke 유지 | 실제 window/저장·취소·종료 39개 통과 |
| 실제 signed HostApp 원본 독립 읽기 | 없음 | create/reopen 두 프로세스 모두 통과 |

Stage 2에서 자체 fixture를 64 MiB로 패딩한 경계 입력은 0.11초, 최대 RSS 약 137.3 MiB로 저장됐으며 64 MiB+1 byte는 본문 읽기 전에 거부됐다. 실제 대형 CJK 글꼴/대량 배치 성능 수치로 일반화하지 않는다. 파일 64 MiB·후보 4,096개·총 읽기 1 GiB의 잠정 한도를 유지한다.

## 4. 수용 기준별 검증

OK는 아래에 명시한 범위의 확인이며, MISS는 미실행 또는 후속 범위다. 후속 기능을 공통 계층의 테스트 통과로 대체하지 않는다.

| 수용 항목 | 판정 | 증거·범위 |
|-----------|------|-----------|
| App Group 설정·권한 실패 구분 | OK | Info/entitlement 일치, 서명 팀/그룹 검증, 컨테이너 불가 시 명시 오류 |
| 파일 구조·face/이름/축·제한 형식 | OK | static TTF/OTF, TTC index, variable metadata, name 언어/원문, 손상/미지원/크기 경계 |
| 독립 복사·재실행·원본 부재 | OK | 원본 chmod 000/삭제 후 읽기, 새 프로세스 bytes/metadata 확인, 실제 HostApp 재실행 |
| 동일 해시·동명 충돌·활성 선택 | OK | 중복 멱등성, 기존 선택 유지, 스타일 분리, stale generation 거부 |
| 부분 실패·취소·원본 scope 수명 | OK | 후보별 결과 및 앞선 게시 보존, scope 주입 검사, 취소/실패 후 해제 |
| 원자적 게시·다중 writer | OK | flock, 9개 종료 경계, 동시 초기화/가져오기, 갱신 손실/중복 방지 |
| 용량 부족·게시 후 동기화 실패 | OK | ENOSPC/EIO 주입; 게시 가시성과 내구성 미확인 결과 분리 |
| snapshot 중 삭제·lease 회수 | OK | 기존 reader 보호, 새 선택 제외, 명시 해제/프로세스 종료 뒤 미참조 객체만 회수 |
| 생존 불확실·손상 lease | OK | PID/시간 대신 kernel flock; 읽기 불가/손상/schema 불명은 전체 객체 회수 보류 |
| 객체/manifest 무결성 및 경로 방어 | OK | 잘못된 ID, 변조, 손상/미지원/누락 manifest, symlink/FIFO 등 거부 |
| 실제 제품 compile/link·core 계약 | OK | HostApp Debug 및 포함 타깃 빌드, Rust universal portable 검증, lock 변경 없음 |
| 실제 signed HostApp 접근·재실행 | OK | 동일 서비스·그룹의 진단 복사본, fixture import/create/reopen 및 해시 검증 |
| 기존 문서 저장/종료 회귀 | OK | Studio lifecycle 39개 및 원본 입력 보존 |
| 개발 등록·격리 산출물 정리 | OK | 최종 hygiene 검사 Issues/Warnings 없음, provider는 기존 `/Applications/Alhangeul.app` |
| macOS 12 compile target | OK | 공통+서비스 arm64/x86_64 warnings-as-errors typecheck |
| macOS 12/Intel 실제 실행 | MISS | 해당 OS/하드웨어에서 실행하지 않음 |
| 실제 전원 장애·볼륨 소진 | MISS | 프로세스 종료/오류 주입만 수행; 장치 고장 실험 아님 |
| 원격 GitHub Actions | MISS | workflow 연결 및 동일 스크립트 로컬 통과; PR 게시 후 확인 |
| 한컴 선택 UI·Windows ZIP·실제 renderer 적용 | MISS | #565~#569 후속 범위 |

최종 통합 검증은 Stage 4에서 완료했다. 이후 소스 변경 없이 보고서를 작성하므로 동일 검사를 불필요하게 재실행하지 않고 해당 실행 증거를 재사용했다. 로컬 Xcode의 testmanager 번들 로드 문제 때문에 스크립트는 `build-for-testing` 후 동일 번들을 `xcrun xctest`로 실행한다. 검사를 생략하는 fallback은 없다.

주요 로컬 증거: `build.noindex/task564-stage4/font-tests.log`, `host-build.log`, `rust-build.log`, `lifecycle.log`, `signed-host-final.log`, `hygiene-final.log`. signed create/reopen 로그는 `build.noindex/font-host-probe-6p23s614/`에 남겼다. 앱 복사본과 검증이 끝난 Debug 앱은 정리했다. 재현 명령과 서명 실패 회복 과정은 [Stage 4 보고](../working/task_m020_564_stage4.md)를 따른다.

## 5. 확정 계약·잔여 위험과 후속 작업

- 저장 성공과 실제 글꼴 적용은 별개다. static TTF/OTF도 `staticCandidate`이며 완전한 font sanitizer 또는 렌더링 보증이 아니다. TTC/가변은 metadata 저장만 지원하고 활성 선택을 거부하며 HFT는 미지원이다.
- schema가 불명확하거나 관리 객체가 손상되면 빈 저장소로 초기화하지 않는다. 게시 후 내구성 미확인 결과는 미저장으로 단정하지 않고 재조회/재시도해야 한다.
- lease는 snapshot 객체가 kernel 잠금 FD를 유지한다. PID 재사용/TTL에 의존하지 않고 확인 불가 기록은 보존한다. 해제 기록은 recover에서 정리되므로 장기 실행 서비스는 시작/작업 완료 시 복구를 호출한다.
- 사용 근거의 localCopy와 embedding을 별도로 보존하며 unknown을 허가로 표시하지 않는다. 라이선스 문서 수집/저장 기능은 구현하지 않았고 관련 리소스 ID는 예약 메타데이터다.
- signed HostApp 진단은 제품 실행 코드의 복사본에 진단용 bundle ID와 격리 폴더를 사용했다. 실제 NSOpenPanel로 한컴 폴더 접근을 허용하는 사용자 경로는 #565 이슈에서 검증한다. 릴리스·공증·설치는 수행하지 않았다.
- 최신 OS에서의 성공을 macOS 12 실행 증거로 간주하지 않는다. Xcode XCTest dylib 최소 OS 링크 경고와 AppIntents 미사용 metadata 경고는 남아 있다.

| 후속 이슈 | 인계 내용 |
|-----------|-----------|
| [#565](https://github.com/postmelee/alhangeul-macos/issues/565) | Mac 자동 탐색·선택 UI, 후보/부모 폴더 권한 URL, 충돌·부분 실패 안내 |
| [#566](https://github.com/postmelee/alhangeul-macos/issues/566) | Windows 폴더/ZIP 입력, 경로/확장 제한 및 임시 해제물 수명 |
| [#567](https://github.com/postmelee/alhangeul-macos/issues/567) | 이름 resolver, Studio CSS/CanvasKit, native snapshot 소유와 bytes 공급 |
| [#568](https://github.com/postmelee/alhangeul-macos/issues/568) | PDF/인쇄·Quick Look/Thumbnail 소비·서명 구성, 캐시 digest와 임베딩 조건 |
| [#569](https://github.com/postmelee/alhangeul-macos/issues/569) | 실제 제품 통합 수용, 사용자용 단계별 웹페이지 안내 |

구체적인 호출 예시와 오류 처리는 [공통 글꼴 관리 계층 연동 계약](../tech/font_library_integration.md)을 따른다.

## 6. 작업지시자 승인 요청

#564 이슈의 공통 기반 구현·검증 결과와 위 MISS/후속 범위를 검토하고 **최종 결과 수용 및 `publish/task564` → `devel` Open PR 게시**를 승인 요청한다. 오늘할일의 완료는 구현·보고 완료이며 GitHub 이슈 close나 merge 완료를 의미하지 않는다.

보고서 승인 후 원격 브랜치 게시·PR 생성과 실제 CI 결과 확인을 진행한다. PR merge와 이슈 close는 이번 보고서 작성 단계에서 수행하지 않는다.
