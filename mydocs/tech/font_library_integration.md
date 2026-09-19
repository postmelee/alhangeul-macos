# 공통 글꼴 관리 계층 연동 계약

## 2026-09-20 현재 적용 기준

Mac 기본 목표는 **활성 설치 글꼴 자동 사용**으로 변경됐다. [#565 수정 계획](../plans/task_m020_565_impl.md)을 현재 기준으로 삼는다. 메타데이터·설정·필요한 권한을 지속하고 필요한 bytes만 읽으며 기존 rhwp 매칭/fallback을 재사용한다. 원본 삭제·비활성·권한 상실 시 계속 사용을 보장하지 않는다. 한컴 앱 내부에만 있는 글꼴 자동 추출은 기본 범위에서 제외한다.

아래 독립 복사·import·manifest·snapshot 계약과 기존 조사 결과는 **별도 Windows ZIP/외부 파일 가져오기 및 관리 자산**에 유효하다. 이를 Mac 설치 참조의 필수 경로로 적용하지 않는다. 설치 참조의 지속 권한·활성 상태·generation/캐시 무효화 계약은 #565 실험 뒤 확정한다. OS 설치나 fsType은 외부 사용 허가의 증명이 아니다.

기존 #563/#564 및 #565 Stage 1–2 결과는 보존한다. Studio 제품 연결은 #567, PDF·인쇄·native·확장은 #568, 전체 수용·웹 안내는 #569 범위다. 최소 연결 probe는 이 소비자들의 완료를 대신하지 않는다.


- 범위: [#564](https://github.com/postmelee/alhangeul-macos/issues/564), M020
- 기반 설계: [글꼴 마이그레이션 설계](font_migration_design.md)
- 구현: `Sources/Shared/FontLibrary/`, `Sources/HostApp/Services/FontLibraryService.swift`

## 설치 참조 adapter — Stage 3 실험 인계

[최소 연결 실험](../working/task_m020_565_stage3.md)에서 실제 활성 static face 2종의 기존 rhwp 매칭·CanvasKit 적용을 확인했다. 제품 통합 및 signed sandbox는 미완료다.

- catalog 열거와 bytes 요청을 분리한다. 기존 감지의 blob 이름 보강에 전체 파일을 무조건 공급하지 않는다.
- PS만으로 원본·버전을 식별하지 않는다. native identity/face/style/축·generation을 보존하며 모호한 입력을 임의로 합치지 않는다.
- 변경 시 renderer의 이미 준비된 local 객체와 실패 캐시까지 무효화한다. 목록만 갱신하면 오래된 렌더 객체가 남는다.
- 바이트 검증 실패는 공급 전에 거부하고 정상 fallback으로 연결한다. 손상 데이터로 생성된 FontMgr 객체의 존재를 준비 성공으로 취급하지 않는다.
- 실험용 queryLocalFonts/chrome.storage shim은 제품 API가 아니다. #567 에서 native provenance·메타데이터/alias·opaque ID·필요 bytes 공급 계약을 정식 연결한다.

## HostApp 입력 계층 — #565 / #566

`AppDelegate.fontLibraryService`는 지연 생성한 `Result<FontLibraryService, Error>`다. 최초 사용 시 App Group 설정·현재 서명·컨테이너를 확인한다. 구성 실패는 임의의 다른 폴더로 우회하지 않는다. 호출자가 실패 원인을 안내하고, 서비스 사용 시작 때 `prepare()`로 검증·복구를 실행한다. 현재 이 서비스는 입력 UI나 앱 시작 시 자동 탐색을 실행하지 않는다.

```swift
let service = try FontLibraryService()
let recovery = try await service.prepare()
// recovery.collectionDeferred이면 일부 파일을 보존한 상태임을 안내한다.
let results = await service.importFonts(.init(
    candidates: discoveredURLs.map {
        FontImportCandidate(sourceURL: $0, sourceKind: .macApplication)
    },
    accessURLs: [selectedApplicationOrFolderURL]
))
```

Mac 자동 탐색·선택 UI는 #565, Windows 파일/폴더/ZIP 탐색은 #566이 담당한다. `accessURLs`에는 실제 사용자가 접근 권한을 부여한 URL을 넣는다. 부모 폴더와 후보 파일 URL이 다를 수 있으므로 후보에서 추측하지 않는다. 같은 URL은 한 번만 획득한다. 성공적으로 시작한 security scope만 배치가 끝나거나 취소된 뒤 해제한다. 획득 결과 false는 이미 접근 가능한 sandbox 내부 파일에서도 가능하므로, 실제 읽기 실패는 후보별 결과로 판정한다.

ZIP 임시 해제물의 수명은 호출자가 import 반환까지 유지한다. 압축 경로 탈출·확장 크기/개수·탐색 깊이 제한도 #566 소유다. 공통 계층은 전체 배치를 한 번에 받아 파일 64 MiB/후보 4,096개/총 읽기 1 GiB 한도를 유지한다. 후보별로 서비스를 반복 호출해서 전체 입력 제한을 우회하지 않는다. cancel은 실행 중인 Task를 취소하면 전파되며 이미 게시된 앞선 입력은 유지한다.

| 결과 | 호출자 처리 |
|------|-------------|
| added | 독립 저장됨. 실제 문서 적용 성공과 구분 |
| alreadyPresent | 동일 bytes 존재. 기존 출처/선택 유지 |
| selectionRequired | 기존 활성 선택을 보존하고 사용자에게 충돌 선택 제공 |
| unsupported / corrupt | 형식·구조·크기 제한 사유 안내 |
| readFailure | 원본 권한/경로를 확인하고 다시 선택 |
| storageFailure | 저장 위치·용량/무결성 등 사유에 맞춰 재시도/복구 안내 |
| cancelled | 해당 항목 게시 전 취소. 앞선 성공 항목을 롤백하지 않음 |

`publication == visibleDurabilityUnconfirmed`는 manifest가 이미 보이지만 내구성 확인이 끝나지 않은 상태다. 이를 “추가되지 않음”으로 단정하지 않고 재조회/동일 입력 재시도를 사용한다. 상세 오류에 원본 절대 경로/문서 내용을 로그로 덧붙이지 않는다.

TTC와 가변 글꼴은 목록/메타데이터 저장만 제공하고 활성 선택은 거부한다. HFT는 미지원이다. localCopy/embedding 사용 근거는 별도로 보존하며 unknown을 허가로 표시하지 않는다. 라이선스 문서 수집/복사는 이번 구현에 포함되지 않으며 licenseResourceID는 예약된 메타데이터다.

## 관리 화면

`list()`의 generation을 `selectActive`/`remove`에 전달한다. `staleGeneration`은 최신 목록을 다시 보여준 뒤 선택을 받는다. remove는 파일 단위 논리 삭제다. 다른 충돌 버전으로 자동 전환하지 않는다. 삭제 후 같은 bytes를 재가져오면 added로 복원한다.

`recover()`는 원본에 접근하지 않고 저장된 객체/manifest/lease를 검사한다. 논리 삭제/작업 완료 뒤 호출할 수 있다. 손상·미지원 manifest/객체는 오류로 반환하며 자동 초기화하지 않는다. 손상·읽기 불가 lease는 회수를 보류한다. 진행 중 작업을 보호하기 위해 파일을 보존한 것이므로 사용자가 파일을 직접 삭제하도록 자동 안내하지 않는다.

## 리소스 소비자 — #567 / #568

```swift
let snapshot = try await service.acquireSnapshot()
do {
    for resource in snapshot.resources {
        let bytes = try await service.readResource(resource.id, snapshot: snapshot)
        // 정확한 face/axes/사용 근거와 함께 소비자에 공급한다.
        // CSS/CanvasKit/CoreText/Skia/PDF 연결은 각 후속 이슈가 구현한다.
        consume(bytes, resource.face, resource.axes)
    }
    try await service.releaseSnapshot(snapshot)
} catch {
    try? await service.releaseSnapshot(snapshot)
    throw error
}
```

위 consume는 계약을 설명하는 자리표시자다. 화면/출력 작업 동안 native 소유자가 snapshot을 유지하고 성공·실패·취소 후 해제한다. Swift 참조의 수명이 끝나도 lease FD가 닫히지만 명시적 종료를 우선한다. WebView에 원본 URL·bookmark·관리 파일 경로를 전달하지 않는다. snapshot handle은 직렬화해서 다른 프로세스에 넘기지 않으며 프로세스별로 획득한다. 확장의 App Group entitlement/구성 및 실제 소비자 연결은 #568 범위다.

snapshot은 immutable 선택 집합, generation, 정책 버전, 선택 digest를 제공한다. 캐시에는 digest를 포함한다. 파일 삭제/선택 변경은 새 snapshot에만 반영하고 기존 출력은 기존 bytes로 끝낸다. 리소스 읽기는 허용 집합과 길이/해시를 매번 검사한다. 무결성 오류·선택 없음은 소비자 fallback 사유로 처리하며 조용히 다른 버전을 공급하지 않는다.

lease는 PID/시간 추정 없이 파일 잠금으로 생존을 판정한다. 해제/프로세스 종료 뒤 미참조 파일만 회수한다. 4,096개 lease 기록 한도 때문에 장기 실행에서는 시작/종료 시 recover를 호출한다. 손상/미지원 기록의 보수적 보존 및 macOS 실행 검증은 [Stage 3 보고](../working/task_m020_564_stage3.md)를 참고한다.

## 검증과 미완료 범위

`scripts/test-font-library.sh`는 공개 배포 가능한 자체 fixture의 해시, App Group 설정, parser/store/process/snapshot/HostApp 서비스 XCTest를 검증한다. PR CI의 macOS validation에서 동일 스크립트를 호출한다. 로컬 서명 검증은 `probe-font-library-container.sh`와 `probe-font-library-host.py`를 사용하며 인증서/로그인 환경이 필요하므로 일반 CI에서 실행하지 않는다.

이번 작업은 공통 저장·공급 기반이다. 자동 Mac 폴더 탐색/버튼, Windows ZIP, Studio의 실제 이름 해석·렌더러 공급, PDF/인쇄·확장 공유, 제품 웹페이지 안내는 각각 #565~#569에 남아 있다. macOS 12 target 컴파일은 실제 macOS 12 실행 검증을 대신하지 않는다.
