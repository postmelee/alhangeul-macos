# Task M020 #564 구현계획서 — 공통 글꼴 가져오기·관리 기반

- 수행계획: [task_m020_564.md](task_m020_564.md)
- 이슈: [#564](https://github.com/postmelee/alhangeul-macos/issues/564), 상위 #562
- 기준 설계: [font_migration_design.md](../tech/font_migration_design.md)
- 브랜치: `local/task564` → `devel` / 마일스톤: M020, v0.2 계열
- 승인 이력: 2026-09-17 작업지시자의 “진행해줘”로 수행계획 승인 및 구현계획 작성 진입. 이후 같은 날 “진행해줘”로 구현계획 승인 및 Stage 1 착수. Stage 1 보고 후 같은 날 “진행해줘”로 Stage 2 착수 승인. Stage 2 보고 후 2026-09-18 “진행해줘”로 Stage 3 착수 승인. Stage 3 보고 후 같은 날 “진행해줘”로 Stage 4 착수 승인.
- 상태: Stage 4 구현·검증 완료, [최종 결과보고서](../report/task_m020_564_report.md) 작성 완료, 결과·PR 게시 승인 대기. [Stage 1 보고](../working/task_m020_564_stage1.md), [Stage 2 보고](../working/task_m020_564_stage2.md), [Stage 3 보고](../working/task_m020_564_stage3.md), [Stage 4 보고](../working/task_m020_564_stage4.md).

## 1. 구현 경계와 파일 배치

`Sources/Shared/FontLibrary/`에 Foundation·CoreText·CryptoKit·Darwin 기반 공통 계층을 둔다. UI 및 원본 권한 수명은 HostApp 서비스가 담당한다. 기존 bundled `HwpBundledFontRegistry`와 Rust bridge를 영구 저장소로 확장하지 않는다.

| 파일(신규 예정) | 책임 |
|------|------|
| `FontLibraryModels.swift` | 객체·face·이름·축·출처·사용 조건·활성 선택·결과 모델 |
| `FontFileInspector.swift` | signature, SFNT 구조, bounds, metadata, 지원 상태 판정 |
| `FontLibraryLocation.swift` | App Group 컨테이너 해석과 테스트용 root 주입 |
| `FontLibraryStore.swift` | 가져오기, manifest 게시, 목록·충돌 선택·논리 삭제 |
| `FontLibraryFileSystem.swift` | 한정된 파일 접근, 잠금·동기화·원자적 교체·장애 주입 seam |
| `FontLibrarySnapshot.swift` | 세대·선택·축 digest, lease, 리소스 ID |
| `FontLibraryRecovery.swift` | staging·고아 객체·lease 복구와 보수적 GC |
| `Sources/HostApp/Services/FontLibraryService.swift` | 원본 접근 수명과 공통 저장소 구성, 비동기 서비스 진입점 |
| `Tests/FontLibraryTests/` | parser·저장소·관리·snapshot XCTest |
| `Tests/FontLibraryProcessProbe/main.swift` | 별도 프로세스 writer·reader·비정상 종료 재현 |
| `scripts/test-font-library.sh` | 위 검증의 재현 가능한 실행 진입점 |

공통 파일은 표의 basename이며 모두 `Sources/Shared/FontLibrary/` 아래다. `project.yml`에 Rust 산출물에 의존하지 않는 테스트 타깃/스킴을 추가한다. 실제 빌드 필요에 따른 파일 분할은 같은 책임 범위 안에서 조정할 수 있다. CI 연결은 기존 PR 검증 workflow를 읽고 동일 환경에 추가한다.

## 2. 모델과 서비스 계약

다음 이름은 구현할 내부 계약이며 현재 존재하는 API가 아니다.

- `FontObject`: SHA-256, byte 길이, 실제 형식, SFNT face 수, 검증 버전.
- `FontFace`: 객체 해시+SFNT index, name 레코드의 platform/encoding/language/nameID 및 원문, family/full/PostScript, 스타일·버전·coverage·axes·named instances·fsType. 얻지 못한 메타데이터는 추정값과 구분한다.
- `SourceReceipt`: 입력 종류, 원본 파일명, 로컬 출처·선택적 bookmark. 복사/임베딩 사용 근거는 별도 `UsageEvidence`에 저장한다. 원본 정보는 리소스 응답에 포함하지 않는다.
- `ActiveSelection`: 충돌 그룹별 선택 face와 axes. 동명 다른 해시는 기존 활성 항목을 유지하고 새 항목은 선택 대기로 보관한다. 같은 family의 regular/bold를 단순 이름 일치로 합치지 않는다.
- `ImportItemResult`: added / alreadyPresent / selectionRequired / unsupported / corrupt / readFailure / cancelled와 사유·다음 조치. 목록에서 저장 상태, 적용 가능 상태를 별도로 제공하며 실제 renderer 결과는 이번 계층이 성공으로 생성하지 않는다.
- `importCandidates`: 입력별 결과를 반환하는 비동기 직렬 처리. 원본 선택/탐색/ZIP은 호출자 소유. 읽기 권한은 복사가 끝날 때까지 유지하고 반드시 해제한다.
- `list`, `selectActive`, `remove`: 최신 세대를 기준으로 처리한다. 선택 변경은 예상 generation을 받아 오래된 선택 요청을 충돌로 반환한다. 재가져오기는 같은 bytes 중복과 논리 삭제 후 복원을 구분한다.
- `acquireSnapshot`, `readResource`, `releaseSnapshot`: immutable 선택 집합을 lease와 함께 획득하고, 해당 snapshot에서 발급한 ID만 읽는다. snapshot 해제 후 읽기는 거부한다.

앱 전체에 전역 설치하거나 원본 URL을 renderer에 넘기지 않는다. CoreText 등록이 필요한 소비자는 #567 / #568 이슈에서 프로세스별로 연결한다. 이번 재등록 범위는 관리 상태 복원 및 소비자 재획득 계약이다.

## 3. 저장·동시성·복구 계약

관리 위치는 App Group 컨테이너의 `Library/Application Support/FontLibrary/v1/`다. `current.json`, `library.lock`, `objects/<sha256>.font`, `staging/<transaction>/`, `leases/<session>.json`, `licenses/`를 사용한다. manifest는 schema, generation, 객체·face·출처·활성 선택을 포함한다.

### 입력 검증과 게시

1. 일반 파일을 한 번 열고 같은 핸들에서 제한된 bytes를 읽는다. 읽은 bytes를 기준으로 해시·구조 검증·저장을 수행한다. 파일 크기 변경·잘린 읽기를 오류로 구분한다. 관리 경로는 symlink·경로 탈출을 거부한다.
2. big-endian SFNT/TTC header 및 table offset/length 계산에 overflow와 bounds 검사를 둔다. name·OS/2·cmap·fvar 등 필요한 metadata를 제한된 범위에서 해석한다. 파일 형식과 확장자 불일치를 기록하며 실제 형식으로 판정한다.
3. CoreText로 읽을 수 있는지 교차 확인하되 descriptor 수를 face 수로 쓰지 않는다. table 검증은 완전한 font sanitizer를 대신하지 않는다. 파싱 실패는 해당 입력에 격리한다.
4. staging에 bytes를 쓰고 동기화한다. writer는 프로세스 내부 직렬화와 프로세스 간 파일 잠금을 함께 사용한다. 게시 잠금 획득 후 최신 manifest를 다시 읽고 중복·충돌을 판정한다.
5. 객체를 불변 경로에 게시하고 디렉터리 내구성을 확인한 뒤 임시 manifest를 쓰고 동기화·원자적 교체한다. 이미 있는 동일 해시 객체도 길이/해시를 확인하며 손상 객체를 정상 중복으로 반환하지 않는다.
6. 객체·manifest·디렉터리 동기화 실패를 조용히 성공 처리하지 않는다. manifest 교체 전 실패는 기존 세대를 유지하고, 교체 후 결과가 불확실하면 재조회로 커밋 여부를 확인한다. 실제 APFS/서명 환경의 지원 동작을 Stage 2에서 검증한다.

배치는 파일별 transaction으로 처리한다. 앞서 커밋된 성공 항목은 다음 입력 실패·취소로 롤백하지 않는다. 취소 시 아직 게시되지 않은 입력을 정리하고 결과를 반환한다. 잠정 한도는 파일 64 MiB, 입력 4,096개·총 1 GiB이며 경계 테스트와 메모리 실측으로 조정한다. 한 번에 모든 bytes를 메모리에 올리지 않는다.

### 복구와 삭제

- 복구·snapshot 획득·논리 삭제·GC는 동일한 잠금 규칙에 참여한다. staging 정리가 진행 중 transaction과 경합하지 않도록 transaction 수명 잠금 또는 소유 상태를 둔다.
- manifest가 없을 때의 신규 초기화와 기존 manifest 손상/미지원 schema를 구분한다. 손상·미지원이면 자동 빈 저장소 생성이나 객체 삭제를 하지 않고 복구 필요로 반환한다.
- manifest 게시 전 남은 객체는 고아 후보이며 활성 transaction·manifest·lease 참조가 모두 없을 때만 제거한다. 현재 목록에서 사라져도 진행 중 snapshot이 읽는 객체는 보존한다.
- snapshot 생성 시 잠금 안에서 참조 객체와 lease를 함께 확정한다. digest는 정렬된 객체·face·axes·정책 버전을 사용하여 같은 선택에 결정적으로 생성한다.
- Stage 3에서 lease 생존 판정은 PID/시작 시각 조회 대신 세션별 파일의 kernel flock으로 확정했다. snapshot이 FD를 소유하고 해제·프로세스 종료 시 잠금이 풀린다. 세션 UUID와 참조 객체를 기록하며, 회수자가 배타 잠금을 얻은 경우에만 미사용으로 판정한다. PID 재사용에 의존하지 않고, 권한/잠금 확인 실패·손상/미지원 lease는 보존한다. 시간 초과만으로 회수하지 않는다.
- resource ID는 외부가 파일 경로를 조립할 수 없는 값이다. 읽을 때 허용 집합·길이·해시를 확인하며 변조 시 bytes를 공급하지 않는다.

## 4. Stage 1 — 모델·형식 검증·컨테이너 접근

산출물: 모델, inspector, location, 독립 테스트 타깃, HostApp App Group 설정.

- identifier는 실제 배포 팀과 macOS 12 지원 조건을 확인한 뒤 확정한다. `scripts/release.sh`의 팀 설정과 기존 서명 방식을 확인하고, 동일 상수를 entitlement/서비스에서 일치시킨다. 이 계획에서는 검증되지 않은 group ID를 하드코딩하지 않는다.
- 컨테이너를 얻지 못하면 명시적으로 unavailable로 반환한다. 일반 Application Support나 원본 경로로 조용히 대체하지 않는다. 테스트 root 주입은 제품 경로와 구분한다.
- static TTF/OTF는 구조·CoreText 확인을 통과해야 지원 후보가 된다. TTC/가변은 metadata와 지원 제한을 보존하며, HFT/그 외 형식은 미지원으로 반환한다.
- 테스트: 정상 TTF/OTF, truncated header/table, offset overflow, 확장자 위장, 다국어 이름, regular/bold, TTC face index, variable 축/instance, 컨테이너 접근 거부.
- signed HostApp 접근 probe를 준비한다. 실제 자격/환경 부족은 미검증으로 보고하고 서명 구성 성공으로 대신하지 않는다.

완료 기준: 모델 식별과 지원 상태가 일관되고 parser 경계 테스트가 통과한다. App Group 설정·실제 접근의 확인 범위와 미확인 항목을 분리한다.

커밋: `Task #564 Stage 1: 글꼴 모델·검증과 공유 컨테이너 기반 구현`

## 5. Stage 2 — 가져오기·원자적 저장·중복 및 충돌

산출물: 파일 시스템 adapter, store의 import/list/select, schema와 transaction 처리.

Stage 2 확정: 프로세스 내 공통 직렬 큐와 프로세스 간 flock을 함께 사용한다. staging 생성은 writer 잠금 안에서 수행하여 다음 단계의 정리가 실행 중 transaction을 지우지 않도록 한다. 파일의 동기화와 디렉터리 게시 뒤 장치 flush를 요청한다. 결과에는 원본 읽기 실패와 다른 `storageFailure`, 그리고 `notPublished` / `durable` / `visibleDurabilityUnconfirmed`를 추가해 게시 후 내구성 미확인을 숨기지 않는다.

- Stage 1 검증 결과의 bytes만 저장한다. 원본을 다시 열어 다른 내용을 복사하지 않는다.
- 동일 hash·동명 다른 hash·스타일별 항목, 세대가 지난 선택 요청, 일부 실패·취소를 결과에 반영한다.
- 두 writer가 동시에 가져오는 subprocess 검증으로 갱신 손실과 중복 게시를 확인한다.
- staging write, object 게시, manifest write/교체 전후에 종료·쓰기 실패를 주입하고 새 프로세스에서 유효 세대와 객체 관계를 검사한다. 디스크 부족은 오류 주입과 가능한 격리 환경의 실제 실패를 구분한다.
- 파일/총량 한도 초과와 대표 입력의 실행 시간·최대 메모리를 기록한다.

완료 기준: 기존 유효 데이터 보존, 파일별 결과 일치, 같은 입력 재시도의 멱등성, 게시 경계 복구 확인.

커밋: `Task #564 Stage 2: 독립 글꼴 저장과 중복·충돌 처리 구현`

## 6. Stage 3 — 관리·snapshot·lease·복구

산출물: 삭제/재가져오기, snapshot/resource API, recovery/GC, process probe.

- 원본을 격리하고 새 프로세스에서 관리 객체를 읽어 hash와 metadata를 비교한다.
- reader가 lease를 가진 상태에서 다른 프로세스가 삭제해도 기존 reader가 읽을 수 있고 새 snapshot에는 삭제된 선택이 없음을 확인한다.
- lease 해제 뒤 참조 없는 객체만 제거되는지, PID 조회 없이 실제 FD 소유를 판정하며 권한 거부/손상 lease에서 보수적으로 유지되는지 확인한다.
- 관리 bytes 변조, 잘못된 resource ID, 해제된 snapshot, 손상·미지원 schema, 재시작과 원본 권한 상실을 검증한다.

완료 기준: 관리 복사본의 원본 독립성, 진행 중 reader 보호, 무결성 실패의 명시적 반환, 재실행 시 상태 일관성.

커밋: `Task #564 Stage 3: 글꼴 snapshot·수명 관리와 복구 구현`

## 7. Stage 4 — HostApp 서비스·회귀·인계

산출물: HostApp 구성 서비스, 재현 스크립트/CI 연결, 확정 기술 계약과 단계 보고.

- UI와 renderer 연결 없이 후속 Mac/Windows 입력이 호출할 진입점을 구성한다. 취소·권한 수명·오류 매핑을 통합 검증한다.
- `scripts/test-font-library.sh`에서 독립 XCTest와 subprocess 회귀를 실행하고 기존 PR CI에 연결한다. fixture는 공개 사용 가능한 자산과 출처/라이선스/hash를 고정하며 사용자 Fonts 설치 상태에 의존하지 않는다.
- `xcodegen generate`, 독립 테스트 스킴의 `xcodebuild test`, HostApp 빌드 및 `scripts/check-no-appkit.sh`를 실행한다. Stage 1에서 `FontLibraryTests` 스킴을 고정했다. 로컬 Xcode testmanager의 번들 로드 오류 때문에 재현 스크립트는 `build-for-testing` 후 `xcrun xctest`로 동일 XCTest를 실행한다. 별도 `xcodebuild test-without-building` 성공 증거와 실행 환경 제약은 Stage 1 보고서에 기록한다. CI 연결 시 실행 환경에 맞는 경로를 검증한다.
- HostApp 빌드에 필요한 core framework는 빌드 가이드대로 준비한다. 독립 테스트 통과만으로 제품 compile/link를 통과했다고 기록하지 않는다.
- 서명된 HostApp 컨테이너 접근, entitlement, 재실행을 확인한다. macOS 12 컴파일과 실제 macOS 12 실행 결과를 구분한다. 자격/환경 부족으로 남은 수용 조건은 최종 승인 전에 명시한다. 릴리스·공증·배포는 실행하지 않는다.
- 기존 저장·종료 lifecycle 등 영향받는 회귀 및 최종 PR CI 결과를 확인한다. `.app`/`.appex`는 `build.noindex/`에만 생성한다.
- 후속 #565 ~ #568 이슈에 입력 계약, 충돌 결과, 제한 형식, snapshot/lease, bytes 공급 예시를 인계한다. 실제 제품 글꼴 적용과 확장 공유는 미완료 상태로 구분한다.

완료 기준: 관련 테스트/빌드 통과, 사용 가능한 환경의 signed 접근 증거, 환경상 미검증 수용 조건 및 후속 범위의 명확한 인계.

2026-09-18 완료 기록: HostApp 서비스/권한 수명/취소/배치·오류 전달 및 CI 연결 완료. XCTest 54개, 실제 HostApp Debug 빌드, Studio lifecycle 39개, arm64/x86_64 macOS 12 typecheck, Rust portable 검증 통과. 사용자 OS 인증 후 Debug dylib 서명 순서를 보완해 실제 signed HostApp create/reopen도 통과했다. [후속 연동 계약](../tech/font_library_integration.md)과 [Stage 4 보고](../working/task_m020_564_stage4.md)에 검증/복구 경과 및 미확인 조건을 기록했다. macOS 12 실제 실행·원격 PR CI는 별도 미확인이다.

커밋: `Task #564 Stage 4: 글꼴 관리 서비스 통합 검증과 후속 계약 정리`

## 8. 보고·승인

단계 보고서는 `mydocs/working/task_m020_564_stage{N}.md`에 작성하고 해당 단계 소스와 함께 커밋한다. 검증 실패는 같은 단계에서 해결하며 다음 단계로 넘기지 않는다. 환경상 미검증은 검증 통과와 구분하고 승인 판단에 포함한다.

모든 단계 후 `mydocs/report/task_m020_564_report.md`에 수용 기준별 결과·제약·실행 증거를 정리하고 승인 후 PR을 게시한다. 이번 구현계획 승인은 Stage 1 착수 승인이며 이후 단계는 각 결과 보고 뒤 승인을 받는다.
