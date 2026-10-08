# Task #567 — 설치 글꼴의 앱 시작 비용 조사

2026-10-08 “앱 실행시마다 로컬 글꼴을 다시 탐색해서 실행시간이 지연될 가능성이 있는지” 지시에 따라 Stage 4.1에서 조사했다. 제품의 시작 정책은 변경하지 않았고 실제 서비스 코드의 metadata 경로를 격리 저장소에서 측정했다.

## 판단

새 프로세스에서는 저장한 목록을 읽은 뒤에도 **현재 CoreText 설치 목록을 다시 확인한다**. 설치 사용이 꺼져 있어도 시작 `prepare()`는 실행된다. 같은 프로세스에서 정상 준비를 반복하는 것은 목록을 재탐색하지 않는다. 저장한 목록만 영구 사용하지 않으므로 앱 종료 중 설치·삭제·비활성화된 글꼴도 다시 확인할 수 있다.

직접 전체 글꼴 파일을 읽는 탐색은 아니다. CoreText의 활성 descriptor를 열거하고 이름·스타일·축·원본 stat을 확인한다. native의 실제 font bytes 읽기·검사·전송은 문서의 face 요청에서 실행한다. CoreText/폰트 서버가 내부적으로 수행하는 I/O까지 0이라고 주장하지 않는다.

현재 Mac에서는 metadata 준비만 약 0.38초가 들었다. UI의 동기 시작 함수에서 전체 탐색을 실행하지는 않지만 첫 문서의 native 글꼴 공급 요청이 같은 catalog actor를 기다릴 수 있다. 따라서 비동기라는 이유만으로 시작/첫 문서 표시의 지연이 없다고 판단할 수 없다. 폰트가 많거나 스토리지·권한 상태가 다른 환경의 비용은 미측정이다.

## 호출 경로

| 시점 | 실제 처리 / 주의점 |
|------|---------------------|
| 앱 시작 | `HostApp.applicationDidFinishLaunching`의 Task → 공유 설정 모델 → 공유 provider → catalog `prepare()` |
| 새 프로세스 서비스 생성 | JSON metadata·설정·bookmark를 복원하지만 `prepared=false`. 최초 준비에서 실제 목록 재검사 |
| 최초 및 이후 앱 활성화 | `applicationDidBecomeActive` → `scheduleRefresh(retryPermissionFailures:true)`. 200ms debounce 후 실제 metadata `refresh()` |
| 설정 탭의 준비 | 같은 설정 모델·service를 재사용한다. 준비된 모델은 다시 준비하지 않음 |
| 문서의 handshake | `StudioFontSession` → `StudioFontSupply.snapshot`. `.notPrepared`이면 catalog 준비를 기다림. 각 문서가 별도 OS 목록을 만드는 구조는 아님 |
| 필요한 face 읽기 | `InstalledFontSystem.read`에서 원본 열기·stat·활성 상태 확인·bytes 검사. 활성 descriptor 검사는 읽기 전후 실행되지만 이번 시작 측정에는 face 읽기를 포함하지 않음 |
| 수동 재감지/CoreText 변경 | metadata 재검사. 바뀐 generation은 기존 Studio 리소스 갱신으로 전달 |

근거: [HostApp](../../Sources/HostApp/HostApp.swift), [설정 모델](../../Sources/HostApp/Views/InstalledFontSettingsModel.swift), [provider](../../Sources/HostApp/Services/InstalledFontServiceProvider.swift), [catalog](../../Sources/HostApp/Services/InstalledFontCatalogService.swift), [CoreText 공급](../../Sources/HostApp/Services/InstalledFontSystem.swift), [Studio snapshot](../../Sources/HostApp/Services/StudioFontSupply.swift).

앱 시작 준비와 최초 활성화는 별도 호출이다. 공유 `prepare()`는 중복 준비를 막지만 활성화의 명시적 `refresh()`를 막지는 않는다. 시작 준비 뒤 활성화를 순서대로 재현한 5개 새 프로세스에서 각각 탐색 2회를 확인했다. 실제 앱의 모든 실행에서 정확히 2회라고 측정한 결과는 아니며, 백그라운드 실행·이벤트 도착 순서·CoreText 알림에 따라 달라질 수 있다.

## 실제 측정

`scripts/profile-installed-font-startup.sh`는 수정하지 않은 제품 `InstalledFontSystem`·catalog·provider를 Swift `-O`, macOS 12 target으로 컴파일한다. 새 CLI 프로세스 5개에서 동일한 전용 JSON 저장소를 차례대로 복원하고 첫 준비 → 앱 활성화 요청 → 같은 프로세스 준비 20회를 실행했다. GUI·사용자 설정·OS 글꼴 등록은 변경하지 않았다.

환경은 macOS 26.5.2 / arm64, metadata 809 faces / 232 families다. 첫 프로세스에는 저장 목록이 없고 나머지 4개는 약 419KB JSON을 복원했다. OS font server/cache는 초기화하지 않았다.

| 항목 | 실측 |
|------|------:|
| 첫 프로세스 catalog 준비 | 471.03ms |
| 저장 목록을 복원한 새 프로세스 준비 | 중앙값 382.33ms, 379.30–394.15ms |
| metadata scan 10회 | 중앙값 378.97ms, 366.34–464.17ms |
| 저장 JSON 서비스 생성/복원 | 4.97–5.78ms (복원 프로세스 4개) |
| 시작 준비 + 최초 활성화 재현 | 프로세스마다 scan 2회 |
| 같은 프로세스 `prepare()` 20회 | 추가 scan 0회, 총 0.17–0.26ms |
| native 직접 font bytes 요청 | 전체 5개 프로세스에서 0회 |
| 시작 metadata 저장 | 프로세스마다 1회. 최초 `!prepared` 때문에 내용이 같아도 저장 |

이는 **metadata 단계의 wall time**이다. 컴파일 시간·CLI 프로세스 spawn·WASM 시작·첫 paint·문서 parsing·필요 face bytes·전체 앱 launch 시간을 합산하지 않았다. 앱을 켤 때 반드시 0.76초 더 늦어진다는 의미가 아니며, OS cold 시작이나 signed sandbox 성능의 증거도 아니다. [집계 원본](../working/assets/task_m020_567_stage4_1/startup-summary.json)을 보존했다.

## 권장 후속 순서

1. 시작 준비와 최초 활성화의 같은 목록 재검사를 합쳐 정상 시작에서 1회만 확인하도록 개선한다. 실제 CoreText 변경과 권한 복구 요청을 잘못 버리지 않는 회귀가 필요하다.
2. 설치 사용이 꺼져 있으면 시작 탐색을 미루고 설정 열기/사용 켜기에서 준비하는 방안을 검토한다. 관리 복사본의 자동 적용과 disabled/failure 의미를 보존해야 하므로 단순 조건문만으로 변경하지 않는다.
3. 실제 사용 중에는 프로세스 공유 catalog와 필요한 face 읽기를 유지하고 재감지·설치 변경·권한 실패 시 갱신한다. 오래된 저장 목록만으로 삭제·비활성 상태를 계속 허용하지 않는다.
4. 필요하면 실제 제품의 빈 문서/기존 문서 cold/warm 시작과 읽기 시 활성 목록 검사 비용을 따로 측정한다. Tauri의 조회 최적화와 같은 효과라고 수치 없이 단정하지 않는다.

이번 Stage 4.1은 UI 간소화와 조사 범위다. 위 시작 정책·cache 최적화는 구현하지 않았다. 다음 단계의 계획을 보정한 뒤 검증 가능한 개선을 선택한다.
