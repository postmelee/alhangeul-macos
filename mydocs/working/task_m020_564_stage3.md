# Task M020 #564 Stage 3 — 글꼴 snapshot·수명 관리와 복구

- 이슈: [#564](https://github.com/postmelee/alhangeul-macos/issues/564)
- 구현계획: [task_m020_564_impl.md](../plans/task_m020_564_impl.md)
- 브랜치: `local/task564`
- 승인: Stage 2 보고 후 2026-09-18 “진행해줘”로 Stage 3 진입

## 1. 결과

글꼴을 목록에서 삭제해도 기존 snapshot을 가진 reader는 독립 복사본을 계속 읽는다. 새 snapshot에는 삭제된 선택이 포함되지 않는다. reader의 명시적 해제·객체 수명 종료·프로세스 종료 후에는 manifest와 다른 lease에서 참조하지 않는 파일만 회수한다.

## 2. 구현과 후속 계약

| 위치 | 변경 |
|------|------|
| `FontLibraryStore.swift` | remove/acquireSnapshot/readResource/releaseSnapshot/recover 비동기 API |
| `FontLibrarySnapshot.swift` | 불변 세대·리소스·선택 digest, 잠금 FD 수명 |
| `FontLibraryRecovery.swift` | lease 검사·고아 객체 및 중단 transaction 정리 |
| `FontLibraryFileSystem.swift` | 제한된 디렉터리 열거, 생성 없는 하위 디렉터리 접근 |
| `FontLibraryModels.swift` | 잘못된 리소스·해제 snapshot·다른 저장소·손상 lease 오류 |
| XCTest 및 process/container probe | 다중 프로세스 reader, 종료·원본 유실·권한 거부·변조 및 복구 검사 |
| 생성 Xcode 프로젝트 | `project.yml`의 기존 소스 경로에서 신규 파일을 반영 |

공통 파일은 `Sources/Shared/FontLibrary/` 아래다. 제품 UI·renderer 및 원본 글꼴은 변경하지 않았다.

### 관리와 리소스 공급

- `remove(objectHash:expectedGeneration:)`는 파일 단위 논리 삭제다. 오래된 세대는 거부하고, 삭제한 활성 선택을 다른 후보로 자동 대체하지 않는다. 실제 파일 삭제는 `recover()`가 담당한다.
- 삭제 후 같은 bytes를 가져오면 `added`로 복원한다. 물리 회수 전 남아 있는 객체는 해시/길이를 재검사해 재사용한다.
- `acquireSnapshot()`은 현재 활성 선택만 고정한다. TTC/가변처럼 미검증 형식은 기존 정책에 따라 활성화되지 않는다.
- snapshot에는 generation, policyVersion 1, 정렬된 resource 목록과 SHA-256 digest가 있다. digest에는 객체·face·axes·사용 근거를 포함하며 generation/lease UUID/원본 영수증은 제외한다. 같은 선택을 재가져오면 동일 digest를 얻는다.
- resource에는 객체/face/axes/사용 근거가 있고 원본 경로·bookmark는 없다. `readResource(_:snapshot:)`는 발급 목록에 포함된 ID만 허용하고 매번 bytes 길이와 해시를 확인한다. 저장 상태를 실제 렌더 또는 사용 허가 성공으로 바꾸지 않는다.
- snapshot handle은 해당 저장소의 프로세스 내 객체다. 다른 저장소에 전달하거나 해제 후 읽으면 오류를 반환한다. renderer/WebView는 native 소유자의 이 API를 통해 bytes를 받아야 하며 handle을 JSON으로 전달해서 재구성하지 않는다.
- `releaseSnapshot`은 반복 호출 가능하다. 마지막 참조가 해제될 때에도 FD를 닫는다. 정상 lifecycle에서는 명시적 해제를 우선한다.

### lease 생존 판정 확정

초기 계획의 PID/시작 시각 조회를 **lease 파일의 kernel flock 소유권**으로 구체화했다. 각 snapshot이 독립 세션 UUID 파일을 만들고 배타 잠금 FD를 유지한다. 모든 발급·회수는 `library.lock` 안에서 수행하며 lease 파일을 교체하지 않는다. 회수자가 같은 파일에 비차단 배타 잠금을 얻으면 소유 reader가 없는 것으로 판정한다. 잠금을 얻지 못하면 참조 객체를 보존한다.

PID를 조회하거나 비교하지 않으므로 PID 재사용 및 다른 프로세스 정보를 조회할 sandbox 권한에 의존하지 않는다. 시간·TTL로 회수하지 않는다. FD는 close-on-exec이며 프로세스 종료 시 kernel이 해제한다. fork로 FD가 상속되면 남은 참조가 닫힐 때까지 보수적으로 유지될 수 있다. 근거는 로컬 macOS `flock(2)`/`close(2)` 계약과 동일·별도 프로세스 실행 테스트다.

`leases.version` 표식을 둬 최초 사용과 기존 lease 디렉터리 유실을 구분한다. 표식 뒤 디렉터리가 없으면 빈 디렉터리를 만들고 GC하는 대신 실패한다. 손상/미지원 schema·예상 밖 이름·일반 파일이 아닌 lease·읽기 권한/잠금 확인 오류가 하나라도 있으면 전체 객체 회수를 보류한다. 자동으로 손상 lease를 삭제하지 않는다.

lease 목록은 발급 시 4,096개로 제한한다. 명시 해제는 FD를 닫고 기록은 다음 `recover()`에서 정리하므로 장기 실행 서비스는 시작/작업 완료 시 적절히 복구를 호출해야 한다. 디렉터리 열거에도 한도가 있으며 한도 초과는 오류로 반환한다.

### 복구

`recover()`는 manifest의 schema/구조와 참조 객체의 bytes를 먼저 검증한다. 손상·유실·미지원이면 데이터를 초기화하거나 GC하지 않는다. 유효한 저장소에서 종료된 lease 기록과 미참조 일반 객체를 정리한다. 모든 writer가 동일 잠금 아래 staging을 생성하므로 정상 동작 중 transaction은 GC와 경합하지 않는다.

staging은 UUID 디렉터리 및 알려진 `object`/`manifest` 일반 파일만 정리한다. 알 수 없는 자식·symlink·hardlink·디렉터리는 보존하고 `collectionDeferred`로 알린다. 재귀 삭제하지 않는다. 결과의 removed 카운트는 이번 실행의 삭제 수이며, 부분 보류나 I/O 실패 이후에는 다시 복구할 수 있다. 손상 lease 때문에 보류된 경우는 파일 회수를 시작하지 않는다.

## 3. 검증

환경: macOS 26.5.2, arm64, 로컬 APFS. 기존 macOS 12 deployment target 유지.

| 검증 | 결과 |
|------|------|
| 전체 XCTest | **49개, 실패 0** — inspector 14 + location 6 + store 15 + process 4 + snapshot 10 |
| 별도 reader/삭제/새 snapshot | 원본 삭제 후 새 프로세스에서 획득; 다른 프로세스의 논리 삭제·복구 후에도 bytes/face metadata 일치; 새 선택은 빈 목록 |
| reader 종료 | 명시 해제 및 `_exit(72)` 후 새 store의 복구에서 미참조 객체 1개 회수 |
| 같은 프로세스 여러 handle | 하나의 수명 종료 뒤 다른 snapshot 보호; 마지막 해제 뒤 회수 |
| 9개 게시 경계 종료 | 이전/새 manifest 보존, 게시 전 고아 객체와 중단 staging만 정리, 재가져오기 성공 |
| 원본 권한 상실 | 원본 chmod 000 및 삭제 뒤 관리 bytes 읽기 일치 |
| 보수적 회수 | 손상/미지원 lease·symlink·chmod 000에서 회수 보류; lease 디렉터리 유실은 실패 |
| 무결성·입력 거부 | 잘못된 ID/다른 저장소/해제 handle 거부; 객체 변조 시 읽기·획득·복구 실패 |
| manifest 손상/미지원 | 복구 실패, 미참조 객체도 보존; 유효 manifest 복원 후 회수 |
| 재가져오기 | GC 전/후 모두 복원, 동일 선택 digest 일치, stale 삭제 거부 |
| signed sandbox | 실제 App Group의 격리 저장소에서 import/snapshot/read, 원본 삭제, live lease 보호·해제 후 회수 PASS |
| 컴파일·정적 검사 | arm64/x86_64 macOS 12 typecheck, warnings-as-errors 및 AppKit 경계/diff 검사 |

재현 명령:

```sh
scripts/test-font-library.sh
scripts/probe-font-library-container.sh 'Developer ID Application: Taegyu Lee (XH6JHKYXV8)'
xcrun swiftc -typecheck -warnings-as-errors -target arm64-apple-macosx12.0 -module-cache-path build.noindex/task564-stage3/module-cache Sources/Shared/FontLibrary/*.swift
xcrun swiftc -typecheck -warnings-as-errors -target x86_64-apple-macosx12.0 -module-cache-path build.noindex/task564-stage3/module-cache-x86 Sources/Shared/FontLibrary/*.swift
scripts/check-no-appkit.sh
git diff --check
```

로컬 증거: `build.noindex/task564-stage3/tests.log`(20:31:00 KST, 49개 통과), `signed-probe.log`. 처음 실행에서 Foundation `Process.waitUntilExit`가 async 테스트의 스레드 전환 뒤 종료된 프로세스를 기다리며 정지했다. `hang-sample.txt`로 해당 호출 스택을 확인했다. harness에서 종료 상태 확인 후 불필요한 RunLoop 대기를 제거하고 재실행해 통과했다. 제품 저장소 잠금의 교착으로 판정하지 않았다.

## 4. 한계와 다음 단계

macOS 12 실제 실행, 실제 HostApp의 서명·빌드·서비스 lifecycle 연결은 아직 검증하지 않았다. 로컬 Xcode의 XCTest dylib은 macOS 14 대상으로 빌드되어 macOS 12 링크 경고가 있으며, 테스트 실행 성공을 최소 OS 실행 증거로 간주하지 않는다. AppIntents 미사용 타깃의 metadata 추출 생략 경고도 있었다. 이번 signed probe는 같은 App Group 설정을 사용하는 격리 테스트 앱이며 제품 설치·릴리스·공증은 수행하지 않았다. 실제 전원 장애/장치 고장, 악의적으로 관리 파일을 동시 교체하는 비협조 프로세스까지 보장하지 않는다. 모든 정상 소비자는 잠금 규약에 참여해야 한다.

PID 재사용을 인위적으로 발생시키는 테스트는 하지 않았다. 구현 자체가 PID 식별에 의존하지 않으며 실제 다중 프로세스 종료로 FD 소유 수명을 검사했다. 비정상 lease는 자동 복구보다 데이터 보존을 우선하므로 별도 복구 안내가 필요하다.

**Stage 3 완료. Stage 4 승인 대기.** 다음 단계는 HostApp 서비스·원본 권한 수명·CI 연결·제품 빌드 및 후속 이슈 인계다. 사용자용 가져오기 UI와 실제 renderer 적용은 #565~#568에서 진행한다.
