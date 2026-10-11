# Task M020 #580 Stage 2 — 확장 글꼴 준비 재사용과 현재성 검증

- 이슈: [#580](https://github.com/postmelee/alhangeul-macos/issues/580), 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562), 후속 [#569](https://github.com/postmelee/alhangeul-macos/issues/569).
- 승인: 2026-10-10, Stage 2 승인 요청에 대한 작업지시자의 “진행해줘”. 작업 `local/task580`, 단계 기준 `b9b11d3b`.
- 근거: [구현계획](../plans/task_m020_580_impl.md), [준비·대기 계약](../tech/task_m020_580_extension_font_contract.md), [Stage 1](task_m020_580_stage1.md).
- 상태: Stage 2 구현·검증 완료, Stage 3 승인 대기. signed 성능 목표·Finder 수용·release 완료를 뜻하지 않는다.

## 1. 결과

확장 프로세스의 변경 없는 설치 목록은 전체 정규화를 재사용하고 동시 준비 요청은 한 작업으로 합쳤다. OFF는 설치 목록·signature 확인 없이 관리 글꼴만 준비한다. 실제 읽기·결과 반환 전 활성 목록/원본 상태·정책·관리 manifest를 계속 검사하며 요청별 관리 FD/read/release 수명을 유지했다.

같은 direct consumer의 HWP/HWPX warm exactHit 20건에서 metadata 중앙값은 OFF 641.242→2.220ms, ON 638.258→112.186ms였다. 값은 unsigned 비최적화 CLI이며 앱 시작·Finder paint·signed provider 응답으로 해석하지 않는다. 렌더 슬롯 busy는 그대로 남아 Stage 3에서 처리한다.

## 2. 산출물과 제품 변경

| 영역 | 내용 |
|------|------|
| `ExtensionInstalledFontPreparation.swift` (181줄) | 확장 전용 직렬 준비, 불변 metadata 재사용, 요청 병합·개별 취소·실제 worker 종료까지 준비 슬롯 유지, 정책/즉시 epoch·전후 signature 게시 검증 |
| `InstalledFontActiveSignature.swift` (71줄), `InstalledFontSystem`·모델 | 활성 URL/PS/family/style/variation/traits·중복과 경로별 stamp/failure를 opaque signature로 확인; 불완전/미제공 상태는 full scan 검증 |
| `ExtensionFontSupply`, `StudioFontSupply` | 명시적인 preparedState로 OFF 자동 prepare 방지, 각자의 metadata snapshot/FD 획득, read 전후·current 검사와 전체 관리 manifest 비교 |
| `InstalledFontCatalogService` | 기존 scan 처리 로직을 수용 경계로 분리해 재사용; HostApp 기본 prepare·감시·설정은 기존 경로 유지 |
| `ExtensionFontRenderer` | 기존 process-scope 번들 등록을 설치 준비보다 먼저 완료해 최초 자기 등록 경합 방지; 기본 renderer/대체 정책은 유지 |
| `ExtensionFontPreparationTests.swift` (435줄, 21개) | production 공급/준비·signature를 사용한 재사용·변경·실패/복구·취소·수명 회귀 |
| 성능 CLI | production signature 연결·detached 진단 대응·ON 최초 1회/반복 0회·OFF 0회 정규화 기대값 |
| 계획·계약·오늘할일·선별 증거 | 단계 상태, 실제 비용과 소유 정리·다음 단계 영향 |

`project.yml`의 기존 source glob으로 `xcodegen generate`를 수행해 생성 project에 새 Swift 파일을 반영했다. 생성 project를 직접 편집하지 않았다. core v0.8.7 pin·Rust C ABI·Studio source/asset·저장 schema·HostApp UI·한도는 바꾸지 않았다.

## 3. 현재성·수명 검증

새 21개 XCTest는 production `ExtensionFontSupply`/준비 소유자/공통 catalog에 실제 격리 font 파일과 제어 가능한 활성 목록·scan·read·변경 epoch를 제공했다. OS 전체 설치·삭제·비활성 수용으로 주장하지 않는다.

- ON 동시 10건·반복 5건에서 full scan 1회, bytes 선읽기 0회. 새 공급 인스턴스는 이전 프로세스 상태를 사용하지 않고 다시 준비했다.
- OFF 최초·반복에서 scan/signature 실패를 주입해도 관리 공급이 정상이며 설치 scan/read 0회. A 해제 후 A 읽기는 거부하고 B의 정확 bytes는 계속 읽혔다.
- OFF→ON→OFF→ON은 새 준비·identity를 요구하고 이전 정책 snapshot을 거부했다. OFF는 아직 실행 중인 이전 ON scan을 기다리지 않고 관리 전용 상태를 제공하며 이전 ON 결과는 게시되지 않았다.
- 알림 누락을 가정한 활성 추가/제거, 같은 PS의 다른 원본·충돌/복구, style/traits/variation 변화, inode/ctime·권한 변경, 원본 삭제/재생성이 이전 current/read를 거부했다. 가변 축은 기존 unsupported 제한을 유지했다.
- NotificationCenter의 CoreText 변경 신호를 동기 callback으로 받아 actor/debounce 전에 epoch가 증가하고 이전 ticket이 즉시 stale임을 확인했다. 실제 OS 폰트를 변경하지 않았다.
- scan 중 signature/epoch 변화는 섞인 결과를 폐기했다. signature/scan/read 권한 실패 후 이전 metadata를 성공으로 제공하지 않고 새 준비로 복구했다. signature 불완전/미제공은 검증을 생략하지 않았다.
- 한 대기자 취소는 나머지 준비를 끊지 않았다. 모두 취소되면 결과를 게시하지 않고 취소를 무시하는 물리 scan의 종료 전 새 scan을 겹치지 않았다. 실제 동시 scan 최대 1회였다.
- 관리 선택·객체 제거/복구와 동일 generation의 manifest metadata 변경도 이전 snapshot을 거부했다. 기존 catalog·권한·lease·Studio session·출력 job 테스트를 함께 통과했다.

## 4. 직접 전후 측정

최종 canonical 경로는 `build.noindex/task580/stage2/final-direct-01/`이다. 같은 fixture SHA·OFF/ON·HWP/HWPX·exact/larger hit·`swiftc -O` 없는 direct 방식으로 비교했다. ON/OFF 각 warm 20건이며 렌더 workload는 기존처럼 process 번들 준비가 선행한다. 구간은 중첩되므로 합산하지 않는다.

| 조건 | Stage 1 metadata / 전체 direct 요청 (ms) | Stage 2 metadata / 전체 direct 요청 (ms) |
|------|------:|------:|
| OFF warm exactHit | 641.242 / 652.717 | 2.220 / 4.222 |
| ON warm exactHit | 638.258 / 650.400 | 112.186 / 221.256 |
| OFF warm largerBucketHit | Stage 1 선별 근거에서 별도 대응 | 2.432 / 4.624 |
| ON warm largerBucketHit | Stage 1 선별 근거에서 별도 대응 | 110.844 / 219.362 |

ON exactHit의 catalogPreparation 중앙값은 54.314ms, activeSignature는 각 요청의 여러 current 경계를 포함한 80구간에서 53.019ms, currentCheck 40구간에서 54.519ms였다. OFF는 activeSignature·scan이 없다. 전체 consumer 실행에서 각 metadata 114회/release 114회가 대응했고 ON full scan 1회, OFF 0회다. bitmap hit는 bytes를 읽지 않았다.

snapshot-only warm 각 10건은 OFF metadata 2.178ms, ON 90.856ms였다. 첫 consumer miss는 OFF HWP/HWPX 62.036/61.968ms, ON 1603.341/959.308ms였다. 최초 ON은 full scan·전후 signature·실제 reads/current 검사 비용이 있어 warm 개선 수치와 합치지 않는다. cold 단축을 완료했다고 판정하지 않으며 Stage 4의 signed 첫/반복·다수 파일 측정에서 따로 확인한다.

전체 direct 8회 실행의 시간 표본은 258건, 성공 250·busy 8이다. consumer OFF/ON 각 114건 중 성공 110·busy 4가 유지됐고 모두 `busy.thumbnailRenderSlots`다. snapshot 22건·transition 8건은 성공, guards의 admission 16/17번째 busy·취소 해제·관리 선택 정확 bytes는 별도 proof로 통과했다.

## 5. 발견과 보정

첫 준비 후 기존 renderer의 lazy 번들 등록이 자기 CoreText 변경 신호를 발생시켜 최초 결과를 stale로 만들었다. 이미 필요한 process-scope 등록을 공급/PNG/PDF 진입으로 앞당겨 PNG·다중 PDF·cache 회귀를 통과했다. OS 지속 등록은 하지 않는다.

첫 consumer 측정에서는 signature 내부에서 이미 활성 필터를 통과한 descriptor의 enabled를 다시 조회해 약 600ms의 내부 비용이 발생했다. 자체 프로세스 3초 `sample`에서 `capture`의 enabled 조회→CoreText 내부 script/native font 분석 경로가 지배 구간이었다. 중복 조회를 제거한 뒤 위 최종 결과를 얻었다. 이전 ON 진단 프로세스는 경로를 대조해 종료했고 partial JSON·profile은 원시 경로에 보존하되 최종 258건에서 제외했다. profile의 의미를 OS 전체 동작 보장으로 확대하지 않는다.

동일 generation의 관리 manifest 변경을 generation 검사만으로는 놓칠 수 있어 full manifest equality를 추가하고 해당 production 회귀를 통과했다. 추가 read 전후 검사는 정확성을 위해 보존하며 성능 목표 때문에 검사를 제거하지 않았다.

## 6. 빌드·회귀와 재현

| 검증 | 최종 결과 |
|------|------|
| `scripts/test-font-library.sh` | 154개, 실패 0 (새 21개 포함); 표준 Node bridge tests·fixture/App Group 대조 포함 |
| `scripts/test-studio-output.sh build.noindex/task580/stage2/studio-output-tests` | 81개, 실패 0; WebKit/PDF·인쇄 준비/취소 callback·importer 제품 경로 회귀, 물리 전송 없음 |
| `probe-extension-fonts.py --output .../default-regression-final` | PASS. CoreGraphics/Skia PNG·2페이지 PDF·stale·권한 fallback·2렌더 한도·lease |
| `probe-native-font-supply.py --output .../native-regression-final` | PASS. 실제 공급/matcher·CG/Skia·face/bytes·삭제/취소 I/O·한도 회귀 |
| `probe-extension-font-performance.py --suite all --repetitions 1 --output .../final-direct-01` | PASS. 8회/258건·별도 guard proof, source/binary/fixture receipt 일치 |
| HostApp Debug 사전 build, 기본/진단 Release build | 모두 BUILD SUCCEEDED; Release 40.446/57.125초, Developer ID 서명 없음 |
| no-AppKit, matcher/Studio asset receipt, signed parser self-test·문서 링크·선별 SHA·diff check | PASS |

첫 XCTest 실행은 sandbox package cache 접근 실패로 표준 권한 컨텍스트에서 회복했다. 새 테스트의 Swift closure 타입 추론 오류는 명시 타입으로 보정했다. 출력 테스트는 같은 DerivedData에 HostApp이 없어 importer 경로 대조 1건이 실패했으며 실제 HostApp build를 먼저 수행한 뒤 81건을 통과했다. 기존 테스트의 Swift 6 NSCondition 경고·현재 SDK XCTest의 최소 OS 링크 경고·AppIntents 미사용 경고는 남는다. 최소 macOS 12/Intel 실제 실행으로 대신하지 않는다.

[측정 근거](assets/task_m020_580_stage2/measurements.json), [source receipt](assets/task_m020_580_stage2/source-receipt.json), [검증·정리 receipt](assets/task_m020_580_stage2/validation.json), [SHA256SUMS](assets/task_m020_580_stage2/SHA256SUMS)에 원시 SHA·요청별 구간·proof와 로그 해시를 남겼다. 이 출력은 `build.noindex`의 OFL/문서 fixture가 있는 로컬 환경에서 재현한다. canonical binary는 source receipt가 일치할 때만 후속 실행에 재사용한다.

## 7. 부산물·등록과 기존 앱 보존

빌드가 자동 등록한 소유 Release/Debug 앱의 appex·앱·Updater를 경로 단위로 해제했다. 완료된 앱·loose preview/thumbnail·loose importer 총 8개를 제거했다. 삭제 뒤 이미 없는 앱 경로 재해제의 exit 1로 최초 receipt 생성이 중단돼 최종 읽기 검사로 복구했다. 해당 bundle의 삭제 전 논리 파일 합계는 기록되지 않아 공간 수치를 추정하지 않는다.

완료된 중간 module cache·private library 복사본 22개 디렉터리는 삭제 전에 journal을 저장하고 정리했다. 논리 파일 합계 490.8MiB이며 물리 확보 공간으로 환산하지 않는다. raw JSON·profile·로그·receipt, canonical CLI/입력 및 Stage 3의 Xcode compile cache는 보존했다. 성능 재실행은 보존 입력으로 새 private store를 만드는 새 출력 경로에서 수행한다.

최종 위생 검사의 개발 등록·개발 bundle·문제·경고는 모두 0, provider root는 `/Applications/Alhangeul.app`이었다. importer 목록에는 task580이 없고 기존 설치본 importer가 유지됐다. 원래 앱 Info SHA `41f64c73e4d2848e2b8d34d4b3a1954e0645121072074f5d299929b5d52279a7`, strict 서명 exit 0을 확인했다. 설치본 교체·Developer ID 사용·전역 reset·사용자 글꼴/문서 변경·공개 배포는 수행하지 않았다.

## 8. 남은 위험과 다음 단계 승인

새 프로세스의 최초 ON scan과 불완전 signature의 full 검증 비용은 남는다. CoreText·파일/권한 변경의 실제 OS 수용과 signed warm 성능, cache/순서·대기 취소의 실제 Finder 관찰은 Stage 4 범위다. source/current 확인 뒤의 기존 TOCTOU를 원자적 OS snapshot으로 주장하지 않는다.

Stage 3의 **admission 16·물리 render 2를 유지하는 FIFO 대기·동일 키 병합·30초 시작 전 deadline·개별/전체 취소·실제 I/O 종료까지 slot/lease 소유·실패/stale 복구** 구현과 검증 승인을 요청한다. 현재 정상 3번째 miss의 즉시 busy 동작을 보정하되 실제 admission 초과·전송 한도는 유지한다. signed 후보·임시 설치·공개 배포 승인은 포함하지 않는다.
