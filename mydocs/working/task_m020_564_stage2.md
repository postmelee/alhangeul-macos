# Task M020 #564 Stage 2 — 독립 글꼴 저장과 중복·충돌 처리

- 이슈: [#564](https://github.com/postmelee/alhangeul-macos/issues/564)
- 구현계획: [task_m020_564_impl.md](../plans/task_m020_564_impl.md)
- 브랜치: `local/task564`
- 승인: Stage 1 보고 후 2026-09-17 “진행해줘”로 Stage 2 진입

## 1. 단계 목적

검증된 입력 bytes를 독립 객체로 저장하고, 목록을 원자적으로 게시한다. 반복 입력·이름 충돌·부분 실패·취소와 여러 writer의 경합에서 기존에 확정한 데이터를 보존한다.

## 2. 산출물과 확정 동작

| 위치 | 내용 |
|------|------|
| `Sources/Shared/FontLibrary/FontLibraryFileSystem.swift` | FD 기반 경로 접근·일반 파일/한도 검사, 배타적 잠금 파일 생성, flock, 쓰기·fsync/F_FULLFSYNC·원자적 이동 |
| `Sources/Shared/FontLibrary/FontLibraryStore.swift` | 비동기 import/list/select, 프로세스 내 공통 직렬 큐, schema·세대·선택 검증, transaction 게시 |
| `Sources/Shared/FontLibrary/FontLibraryModels.swift` | 입력·manifest·충돌 그룹·저장 항목, 저장 실패와 게시 상태 모델, Sendable 계약 |
| `Tests/FontLibraryTests/FontLibraryStoreTests.swift` | 저장소 15개 검사, 경합 반복·취소·실패·원본 교체 및 링크 방어 |
| `Tests/FontLibraryTests/FontLibraryProcessTests.swift` | 별도 프로세스 종료·잠금·동시 초기화 3개 검사 |
| `Tests/FontLibraryProcessProbe/main.swift` | import/list 및 게시 경계별 비정상 종료·잠금 대기 probe |
| `project.yml`, 생성 Xcode 프로젝트 | XCTest가 독립 process probe를 먼저 빌드하도록 설정 |
| 기존 container probe·실행 스크립트 | signed sandbox 안에서 실제 저장소 import/list·동기화·정리 검증 |

### 저장과 동시성

- 원본은 한 번 열어 제한된 bytes를 읽고 길이·mtime/ctime 변경을 검사한다. 읽은 bytes로 검사·해시·복사를 모두 수행한다. 원본 경로를 다시 열어 복사하지 않는다.
- 프로세스 내 모든 store 인스턴스는 utility 직렬 큐를 공유한다. 프로세스 간에는 `library.lock`의 flock을 사용한다. 대기 중 취소를 확인하며 잠금 파일은 교체하지 않는다.
- 입력 검사는 게시 잠금 전에 수행하고, staging부터는 잠금 안에서 수행한다. 최신 manifest를 다시 읽은 뒤 객체를 배타적으로 게시하고 새 manifest를 원자적으로 교체한다.
- 파일 fsync와 F_FULLFSYNC, 디렉터리 fsync, 게시 뒤 장치 flush 요청을 수행한다. 지원하지 않거나 실패한 동기화는 성공으로 바꾸지 않는다.
- `current.json` schema 1과 generation, 객체·face·출처·사용 근거·충돌 그룹·활성 선택을 보존한다. 초기화 표식 뒤 manifest가 없어지거나, 손상·미지원 schema이면 빈 목록으로 덮어쓰지 않는다.
- 객체 경로는 SHA-256 기반이다. 관리 경로는 FD 상대 접근과 O_NOFOLLOW를 사용하고, 일반 파일·단일 link 여부를 확인한다. macOS 표준 `/var` 등의 별칭만 `/private/...`로 치환한다.

### 중복과 충돌

같은 해시는 관리 객체의 길이와 해시를 재확인한 뒤 `alreadyPresent`로 반환한다. 동일 입력의 반복은 generation이나 항목 수를 늘리지 않는다. 출처는 최초 저장 시 기록하며 중복 재입력마다 출처 이력을 추가하지 않는다.

PostScript 이름 또는 family/subfamily·weight·width·slant가 같은 다른 bytes는 충돌로 보관하고 기존 활성 선택을 유지한다. 버전 문자열로 자동 교체하지 않는다. regular/bold는 분리하며, 여러 기존 그룹에 걸친 후보도 기존 선택을 병합·해제하지 않는다. 상세 다국어 문서 resolver는 #567 범위다.

`selectActive`는 expected generation을 요구하며, 오래된 요청·없는 face·미검증 적용 형식은 거부한다. TTC·가변 파일은 저장·목록에 남지만 자동 활성화하지 않는다. 저장 성공을 실제 렌더 성공으로 보고하지 않는다.

### 실패·취소 결과

파일 단위 commit이므로 뒤 입력의 실패나 취소는 앞서 저장한 항목을 되돌리지 않는다. 원본 읽기 실패와 저장 실패는 `readFailure` / `storageFailure`로 구분한다.

manifest 교체 후 동기화 실패는 다시 읽어 게시 여부를 확인하고 `visibleDurabilityUnconfirmed`로 반환한다. 이를 미저장 또는 정상 성공으로 보고하지 않는다. 재시도는 기존 객체를 확인하고 동기화를 다시 수행한다. 오류는 경로·원본 내용을 넣지 않는 제한된 코드로 전달한다.

## 3. 기존 본문·동작 보존

제품 문서 열기·저장·렌더러 및 번들 글꼴 등록 경로는 변경하지 않았다. 사용자·한컴 자산은 수정하지 않았다. HWP/HWPX 본문 무손실 및 화면/PDF 적용은 이번 단계의 검증 대상이 아니다. 실행 probe는 App Group 안에 UUID로 만든 격리 폴더만 사용하고 삭제하며 제품 `FontLibrary/v1/current.json`은 생성·변경하지 않는다.

## 4. 검증 결과

환경: macOS 26.5.2(25F84), arm64, 로컬 APFS, macOS 12 deployment target 유지.

| 항목 | 결과 |
|------|------|
| 전체 XCTest | **38개, 실패 0** — 기존 20 + store 15 + process 3 |
| 반복 입력·원본 부재·원본 교체 | 복사 bytes 일치, 재실행 목록 일치, 검사 뒤 원본이 바뀌어도 최초 bytes 저장 |
| 충돌·선택 | 기존 활성 선택 유지, regular/bold 분리, 명시 선택 변경, stale generation 거부 |
| 입력·파일·누적 한도 | 작은 설정으로 경계 확인; 별도 64 MiB 실측 및 +1 byte 거부 |
| 부분 실패·취소 | 정상→손상/읽기 실패→정상에서 두 항목 유지; 첫 commit 후 취소 시 나머지 두 항목 cancelled |
| 쓰기 실패 주입 | commit 전 각 경계의 ENOSPC 주입에서 기존 manifest 보존, 재시도 추가 성공 |
| 게시 후 실패 | manifest 교체 뒤 EIO에서 게시/내구성 미확인 구분, 재시도 중복 및 동기화 성공 |
| 프로세스 종료 | 9개 게시 경계에서 `_exit(71)`, 새 프로세스로 이전/새 세대 및 객체 확인, 재시도 성공 |
| 동시 접근 | 동일 프로세스 20회 초기화 경합, 별도 프로세스 10회 초기화 경합, 실제 잠금 대기·동일 입력 중복/다른 입력 갱신 보존 |
| 손상·경로 방어 | 손상 객체를 정상 중복으로 보고하지 않음, 손상/미지원/누락 manifest 보존, root/objects symlink·FIFO 거부 |
| signed sandbox | App Group 내 실제 import/list, 원본 삭제, fsync/fullsync, 격리 폴더 삭제 PASS |
| 컴파일·기본 검사 | arm64 빌드 및 x86_64 macOS 12 typecheck, AppKit 경계, shell 문법, diff 검사 통과 |

명령 및 증거:

```sh
scripts/test-font-library.sh
scripts/probe-font-library-container.sh 'Developer ID Application: Taegyu Lee (XH6JHKYXV8)'
xcrun swiftc -typecheck -warnings-as-errors -target x86_64-apple-macosx12.0 \
  -module-cache-path build.noindex/task564-stage2/module-cache-x86 Sources/Shared/FontLibrary/*.swift
scripts/check-no-appkit.sh
```

- `build.noindex/task564-stage2/tests.log`: 22:59:17 KST, `Executed 38 tests, with 0 failures`, 약 6.1초.
- `build.noindex/task564-stage2/container.log`: `PASS: signed sandbox import/list, original removed, fsync/fullsync, probe cleanup`.
- 테스트는 Stage 1과 동일하게 `build-for-testing` 후 `xcrun xctest`로 실행했다. 설치된 XCTest의 최소 OS 관련 linker 경고는 제품 최소 OS runtime 성공으로 해석하지 않는다.

### 입력 크기 실측

자체 생성 regular TTF 뒤에 padding을 붙인 **크기 경계용** 입력이다. 복잡한 대형 CJK 글꼴이나 4,096개 목록의 성능을 대신하지 않는다. Debug process probe를 `/usr/bin/time -l`로 측정했다.

| 입력 | 결과 | 실시간 | 최대 RSS |
|------|------|--------|----------|
| 64 MiB | added / durable | 0.11초 | 143,998,976 bytes (약 137.3 MiB) |
| 64 MiB + 1 byte | unsupported / inputLimitExceeded / notPublished | 0.00초(표시 정밀도 이내) | 7,274,496 bytes (약 6.9 MiB) |

근거: `build.noindex/task564-stage2/performance/{limit,over-limit}-{result.json,time.log}`. 크기 초과는 본문을 읽기 전에 거부했다. 잠정 한도 64 MiB/4,096개/1 GiB는 유지하되 대량 목록·실제 대형 글꼴 수용은 후속 검증에 남긴다.

### 구현 중 발견·보완

1. Foundation의 `/var` 임시 경로를 일반 symlink처럼 거부했던 문제를 macOS 표준 별칭에 한정해 보완했다. 임의 관리 경로의 링크 방어는 유지했다.
2. 최초 잠금 파일의 동시 `O_CREAT`가 ENOENT를 반환했다. 별도 C 재현에서 50회 중 2회 실패를 확인했다(`build.noindex/task564-stage2/open-race.c`). `O_CREAT|O_EXCL`로 한 프로세스만 생성하고 EEXIST면 기존 파일을 여는 방식으로 변경해 프로세스 간 초기화 반복 검사가 통과했다.
3. 실제 sandbox에서 상위 폴더를 O_RDONLY로 여는 작업이 거부됐다. 상위 경로는 O_SEARCH로만 탐색하고 허용된 관리 디렉터리의 읽기·동기화만 요청해 signed probe가 통과했다.
4. 메모리 통계를 읽는 `time` 명령은 제한된 실행 환경에서 sysctl 접근이 거부됐다. 측정 권한을 허용한 별도 실행으로 RSS를 확보했다.

## 5. 잔여 위험과 미검증

- 프로세스 종료 주입은 전원 차단/장치 고장을 재현하지 않는다. ENOSPC도 주입 검증이며 실제 볼륨을 가득 채우는 실험은 하지 않았다. APFS 외 저장장치의 동기화 지원은 미검증이다.
- signed 증거는 공통 코드를 사용하는 격리 앱이다. actual HostApp·확장 통합과 macOS 12 runtime은 아직 남아 있다. 제품 전체 빌드와 CI 연결은 Stage 4에서 수행한다.
- Stage 2는 정상 예외·취소 시 자기 staging을 정리한다. 객체 게시 후 manifest 확정 전 실패·취소로 생긴 고아 객체와 강제 종료로 남은 staging의 물리 GC는 아직 하지 않는다. 유효 목록은 보존하며 해당 정리는 Stage 3 소유다.
- snapshot/lease·삭제·bytes 공급 API는 아직 없다. 목록 metadata만으로 현재 renderer 적용이나 모든 관리 객체의 건강 상태를 보증하지 않는다.
- 사용 조건 근거는 원형대로 보존하며 자동 허가 판정을 추가하지 않았다. 원본 접근 권한의 시작/해제 및 사용자 안내는 후속 HostApp 서비스·입력 UI에 연결한다.
- 실제 글꼴의 성능·지원 범위와 다국어 이름 해석은 합성 자산 검사만으로 완료 처리하지 않는다.

## 6. 다음 단계 영향

Stage 3는 같은 잠금 아래 snapshot/lease 획득과 논리 삭제·GC를 수행해야 한다. stage transaction은 전부 writer 잠금 안에 있으므로 GC가 잠금을 획득한 시점에는 다른 정상 writer의 staging 작업이 진행 중이지 않다. 잠금 파일은 초기화 표식도 포함하므로 교체·삭제하면 안 된다.

manifest generation과 선택 집합을 snapshot에 고정하고, 원본이 아닌 hash 객체만 읽도록 연결한다. 게시 후 미확인 결과는 UI에서 성공이나 미저장으로 단정하지 말고 재조회·재시도를 제공해야 한다.

## 7. 승인 요청

**Stage 3 — 관리·snapshot·lease·복구** 진입 승인을 요청한다. 다음 단계에서 실행 중 삭제 보호, 원본 없는 새 프로세스의 리소스 공급, 변조 거부, 보수적인 lease 회수 및 고아 객체 정리를 구현한다.
