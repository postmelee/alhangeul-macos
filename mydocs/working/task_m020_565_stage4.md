# Task M020 #565 Stage 4 — 활성 목록·설정·권한 지속 기반

- 수행일: 2026-09-20
- 승인: Stage 3 보고 후 작업지시자의 “진행해줘”로 착수
- 상태: 구현·검증 완료, Stage 5 승인 대기
- 기준: [구현계획](../plans/task_m020_565_impl.md)

## 1. 구현 결과

Mac의 활성 CoreText descriptor에서 원본 URL·PS·family/full/style·버전·traits·가변 축을 수집하는 native service를 구현했다. 사용 설정과 메타데이터, 사용자가 선택한 위치의 bookmark를 앱 전용 Application Support에 지속한다. font bytes는 저장하지 않고, 필요한 리소스를 요청할 때만 읽는다.

소비자 연결 전의 기반 단계다. 제품 설정 화면·앱 시작 진입점과 기존 가져오기 UI는 변경하지 않았다. Stage 5에서 앱 단위 service 소유·prepare·UI 연결을 수행하고, 실제 Studio adapter는 #567, 출력·확장은 #568 에서 연결한다.

## 2. 변경 파일

| 위치 | 책임 |
|------|------|
| `Services/InstalledFontModels.swift` | native metadata·권한·오류·generation·검증 리소스 모델 |
| `Services/InstalledFontSystem.swift` | CoreText 활성 목록, scope 수명, 동일 파일 핸들 읽기와 bytes 검증 |
| `Services/InstalledFontCatalogService.swift` | 상태 저장·설정·권한 교체/제거, 변경 알림·스트림·진행 중 요청 병합 |
| `Sources/HostApp/HostApp.entitlements` | 앱 범위 security-scoped bookmark 지원 |
| `Tests/FontLibraryTests/InstalledFontCatalogTests.swift` | 새 회귀 15개 |
| `Tests/InstalledFontCatalogProbe/`, `scripts/probe-installed-font-catalog.sh` | 제품 service의 signed sandbox 검증 |
| `project.yml`, 생성 Xcode 프로젝트 | 테스트 소스 연결, xcodegen 결과 |

Services 경로는 `Sources/HostApp/` 기준이다. RhwpCoreBridge에 AppKit 의존을 추가하지 않았으며 Rust ABI·core pin·bundled Studio·기존 독립 보관 형식은 변경하지 않았다.

## 3. 동작 계약

- 시작 시 `prepare()`가 저장 목록을 실제 활성 목록으로 재검증한다. 준비 전 snapshot에는 `notPrepared`를 표시하고 bytes 공급을 거부한다. 기본 사용 설정은 false이며 저장된 사용자 설정을 복원한다.
- 리소스 ID는 원본 URL·PS·축의 경계를 구분한 직렬화 hash다. 원본 stamp에는 device/inode/크기/mtime/ctime을 나노초까지 보존한다. 원본 URL과 bookmark는 native 전용이다.
- 같은 PS라도 다른 source/축 ID를 임의 합치지 않는다. 현재는 충돌 상태로 보존하고 공급을 거부한다. 명시적 충돌 선택 UI는 이번 단계 범위가 아니다.
- 제거된 face는 inactive 상태로 남아 소비자가 변화를 알 수 있다. 목록 최대 20,000개, 권한 최대 64개, 저장 JSON 최대 32 MiB다. 한도를 넘으면 실패를 명시하며 이전 목록을 검증된 상태로 공급하지 않는다. 파일 URL/PS를 얻지 못한 descriptor는 `omittedFaceCount`로 표시한다.
- CoreText process 알림은 NotificationCenter, session/persistent 알림은 DistributedNotificationCenter에서 수신한다. 200ms debounce 후 같은 refresh 경로로 재검사한다. 알림을 놓친 경우에도 읽기 직전/직후 원본과 활성 상태를 확인한다.
- 의미 있는 상태 변경은 UUID generation을 바꾸고 AsyncStream으로 최신 snapshot을 알린다. 이전 generation의 요청과 늦게 완료된 읽기는 `staleGeneration`으로 거부한다. 소비자는 해당 generation에 맞춰 자체 renderer cache를 무효화해야 한다.
- 같은 ID의 진행 중 요청은 공유한다. 현재 generation에서 서로 다른 진행 중 요청은 2개까지 받으며 초과는 `busy`다. 완료된 bytes 캐시나 영구 복사본은 두지 않는다. 취소·세대 변경 후 worker가 종료될 때까지 그 worker의 scope를 유지한다.
- 동일 fd에서 일반 파일을 최대 64 MiB 읽고 전후 fstat/경로 stamp를 대조한다. 공통 `FontFileInspector`로 정확한 bytes를 검증하고 단일 PS face·sfntIndex·SHA-256을 돌려준다. 링크·비일반 파일·원본 변경·비활성·권한 거부·손상을 공급 성공으로 처리하지 않는다.
- TTC/가변은 catalog 정보와 제한을 보존하지만 아직 bytes 적용 지원으로 승인하지 않는다. 소비자별 정확한 face/축 검증 전 `unsupported`로 거부한다.
- 손상·미지원·읽기 권한 실패는 동일 원본의 refresh만으로 성공으로 바뀌지 않는다. 원본이 바뀌거나 명시적 retry/권한 재선택을 해야 재검증한다. storage 손상·신규 schema를 자동 초기화하지 않는다.

## 4. 권한

정상 접근 가능한 공용 글꼴에는 추가 선택을 요구하지 않는다. 선택이 필요한 위치만 caller가 NSOpenPanel로 받고 `grantAccess(to:replacing:)`에 전달한다. 읽기 전용 security-scoped bookmark를 저장하고 stale/resolve 실패를 별도 grant issue로 표시한다. 성공한 scope만 해제하며 같은 URL을 중복 시작하지 않는다. 저장 권한 제거는 이후 bookmark 사용을 중단하는 것이며, OS의 이미 허용된 세션 권한을 강제로 철회한다는 의미가 아니다.

앱 범위 bookmark의 entitlement는 [Apple의 security-scoped bookmark 안내](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access)에 따라 추가했다. 선택 원본의 광역 접근 예외나 전체 디스크 접근을 추가하지 않았다. HostApp bookmark가 Quick Look/Thumbnail에 자동 공유된다고 가정하지 않는다.

## 5. 검증 결과

| 검증 | 결과 |
|------|------|
| 글꼴 XCTest | **86개 통과, 실패 0**: 기존 71개 + 새 15개 |
| HostApp Debug compile/link | **BUILD SUCCEEDED** |
| macOS 12 대상 typecheck | warnings-as-errors 통과. macOS 12 실제 실행은 미검증 |
| 공용 Swift 경계·shell·diff | 통과 |
| signed sandbox 기본 catalog | PID 6558, 레코드 809개, 공용 Regular/Bold 요청만 읽기·검증 성공 |
| 선택 전/후 권한 | PID 8385, 선택 전 자체 fixture 읽기 false → bookmark 1개 저장 → 읽기 true |
| 최종 소스 새 프로세스 | PID 11038, 사용 설정 복원 true, bookmark 1개, 재선택 없이 읽기 true, grant issue 0, omitted face 0 |
| 개발 등록 정리 | 이번 Debug 앱과 내부 도우미 등록 해제·산출물 제거. 최종 Issues/Warnings 없음, 정식 `/Applications/Alhangeul.app` provider 유지 |

선택 폴더는 작업지시자가 명시 허용한 `build.noindex/task565-stage4/installed-font-permission-fixture` 하나다. 자동 승인 검토가 최초 선택 제출을 차단했으므로 우회하지 않고 정확한 폴더의 지속 읽기 승인을 받은 뒤 진행했다. 자체 fixture는 해당 probe 프로세스 범위로만 등록·해제했고 실제 사용자 글꼴을 설치/삭제하지 않았다.

새 테스트는 재실행 전 활성 목록 재검사, 동명 다른 원본 충돌, 제거/갱신 generation, disable/변경 도중 늦은 읽기 거부, 동시 요청 병합, 손상 retry, scan/storage 실패, schema 보존, 권한 교체/제거, stale/resolve 실패·scope 균형, 실제 process 등록 fixture 교체 검출, 알림 debounce 및 실제 NotificationCenter 경로/AsyncStream을 포함한다.

실행 로그: `build.noindex/task565-stage4/font-tests.log`, `host-build.log`, `sandbox-cold.log`, `sandbox-choose.log`, `sandbox-relaunch.log`, `hygiene-final.log`. [sandbox 재현 안내](../../Tests/InstalledFontCatalogProbe/README.md).

## 6. 한계와 다음 단계

- 현재 검증 OS는 macOS 26.5.2 (25F84)다. 실제 영구 OS 글꼴 설치/제거 UI와 모든 OS의 분산 알림 전달은 이번 테스트로 보증하지 않는다. process fixture·알림 주입·사용 시 원본 검증을 구분한다.
- stale bookmark와 권한 resolve 실패는 주입 테스트다. 실제 폴더 이동·권한 변경·다른 볼륨·최소 OS 검증은 Stage 6에 남긴다.
- 동일 PS의 다른 원본은 안전하게 막으며 어느 버전을 선택할지 자동 결정하지 않는다. family-only 문서의 스타일 선택·한글 alias·TTC/가변 consumer 적용은 후속 연동에서 검증한다.
- catalog는 단일 HostApp service가 소유한다. 여러 writer 프로세스가 같은 저장 파일을 공유하는 저장소가 아니며 extensions와의 공유 계약도 아니다.
- 이번 단계는 화면 변경이 없다. Stage 5에서 ‘Mac에 설치된 글꼴 사용’과 ‘글꼴 목록 새로고침’에 연결하고 실제 화면/직접 확인 경로를 제공한다.
- 설치 사실·fsType·이름·사용자 체크를 라이선스 허가로 취급하지 않는다. 원본 삭제 후 독립 사용은 별도 가져오기 자산에만 적용한다.

다음 승인 대상은 Stage 5 UI와 공급 계약 연결이다. 이슈 close·PR·merge·배포는 수행하지 않았다.
