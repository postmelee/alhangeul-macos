# Task M020 #580 Stage 1 — 글꼴 준비와 렌더 대기 계약 확정

- 이슈: [#580](https://github.com/postmelee/alhangeul-macos/issues/580), 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562), 후속 [#569](https://github.com/postmelee/alhangeul-macos/issues/569).
- 수행: 2026-10-10, `local/task580`. 구현계획·Stage 1 승인: “구현계획 승인·Stage 1 진행”. 기준 commit `702d518a`, 제품 기준 `dac73a589dc17143e744da6a12a51d638a81fb77`.
- 계획: [수행계획](../plans/task_m020_580.md), [구현계획](../plans/task_m020_580_impl.md). 상태: Stage 1 완료, Stage 2 승인 대기.

## 1. 단계 목적과 결과

제품 성능 구조를 바꾸기 전에 준비 비용과 busy 경계를 나누고, metadata 재사용·현재성·제한된 렌더 대기의 구현 계약을 확정했다. 설치 사용 OFF도 현재 전체 scan을 수행하며, direct consumer warm에서는 전체 정규화가 준비 시간의 대부분이었다. 시험용 가벼운 signature는 약 44ms로 재사용 설계를 진행할 근거가 있다. 제품에 연결하거나 signed 성능 목표를 통과했다고 판정하지 않았다.

## 2. 산출물과 변경 범위

| 파일/영역 | 변경 |
|------|------|
| `Sources/Shared/FontLibrary/ExtensionFontSupply.swift` | #569 고정 진단 재사용, catalogRefresh/supplyAssembly/sourceFingerprint 구간·고정 busy 명칭·상세 관찰자 |
| `InstalledFontSystem.swift`, `FontLibraryStore.swift` | 열거/정규화·관리 queue 진입 대기, detached/GCD의 요청 ID·관찰자 전달 |
| `InstalledFontCatalogService.swift`, `HostFontSupplyTypes.swift` | 기존 read/전송 busy 직전 진단 |
| Thumbnail cache·두 provider | 기존 admission/render busy와 실제 callback UUID 구간; 렌더·cache 정책은 유지 |
| `Tests/ExtensionFontPerformanceProbe/` | 고정 CLI 인계, OFL/문서 fixture manifest, 제품에 연결하지 않은 signature 비용·key 의미 실험 |
| 두 성능 scripts | #580 소유 출력·source/fixture/binary receipt, 부분 반복, 상세 구간 집계·signed parser의 image identity/대응 회귀 |
| [확정 계약](../tech/task_m020_580_extension_font_contract.md) | 활성 signature·즉시 epoch·전후 세대 게시·OFF 공급·요청별 lease·FIFO/30초 대기/취소 소유 |
| [선별 근거](assets/task_m020_580_stage1/measurements.json), [source receipt](assets/task_m020_580_stage1/source-receipt.json), [검증 receipt](assets/task_m020_580_stage1/validation.json) | 원시 결과 SHA와 요청별 구간·판정·lease/bytes·빌드·정리 근거 |

#569의 `60ea06a384ce5ba9e43b60a30278ce1268efe237`에서 필요한 진단/측정 파일만 대조해 인계했다. 해당 브랜치·원시 결과·보고서는 유지했으며 전체 cherry-pick/merge를 하지 않았다. fixture manifest는 기존 읽기 전용 OFL 글꼴과 격리 문서의 SHA를 검증한다.

추가 비용/busy 기록은 `ALHANGEUL_FONT_EXTENSION_PROBE` 내부다. 기본 빌드의 scan·공급·FD/read/release·한도·오류 분류는 유지했다. 문서는 기존 승인/현재 상태 문단과 오늘할일 #580 행만 보정했으며 기존 본문·다른 작업 변경을 삭제하지 않았다. core pin·C ABI·Studio·project.yml·renderer 기본값·HostApp UI는 바꾸지 않았다.

## 3. 직접 비용 측정

모든 새 측정은 unsigned, `swiftc -O` 없는 공통 production 서비스 CLI이며 OS 설치/등록/서명 없이 private 관리 store를 사용한다. 렌더 workload는 기존처럼 번들 글꼴 준비가 선행한다. 같은 machine/CoreText 목록에서 OFF/ON을 나누었고 첫 요청·다른 PID·실제 signed Finder 시간을 합치지 않는다.

HWP/HWPX `same/warm/exactHit` 각 20개 요청의 중앙값:

| 구간 | OFF (ms) | ON (ms) |
|------|------:|------:|
| 내부 metadata | 641.242 | 638.258 |
| catalogRefresh | 631.507 | 628.081 |
| 활성 descriptor 열거 | 10.518 | 10.402 |
| 전체 metadata 정규화 | 615.691 | 612.535 |
| 공급 조립 | 3.526 | 3.565 |
| 원본 fingerprint, 각 60구간 | 4.882 | 5.205 |
| current 확인, 각 40구간 | 5.470 | 5.974 |

정규화는 열거·catalogRefresh 내부에 포함되고 fingerprint/current도 중첩되므로 합산하지 않는다. 첫 metadata 전 actor 대기는 snapshotCall과 내부 metadata의 차이로 확인하고 내부 구간에 더하지 않는다. 관리 queue 대기·render 시간은 개별 구간으로 남겼다.

별도 snapshot-only warm 각 10건 metadata는 OFF 113.291ms, ON 112.618ms였다. workload마다 큰 차이가 있으므로 이를 consumer 대비 성능 개선으로 해석하지 않는다. 기존 고정 진단 binary의 모든 source/hash를 기준 commit과 대조한 뒤 새 상세 진단과 ON snapshot을 번갈아 새 PID에서 실행했다. 기존 111.281/109.888ms, 상세 110.177/111.440ms로 큰 추가 지연의 징후는 없었지만 환경 변동과 순수 진단 overhead를 완전히 분리한 실험은 아니다.

signature 실험은 현재 활성 descriptor 565개에서 각 11건이었다. warm 각 10건 중앙값은 OFF 44.028ms, ON 43.910ms, 같은 PID의 첫 전체 scan 비교는 800.809/634.373ms였다. OFF 표시는 private 정책 대조 조건일 뿐이며 시험 signature 자체는 양쪽 모두 목록을 확인했다. 제품 OFF scan 생략은 Stage 2에서 구현한다. 제거/중복·URL/PS/family/style/variation/traits·원본 실패·inode/ctime의 key 의미 차이와 정적 목록 반복 일치를 확인했고 실제 OS 변경 시험은 하지 않았다.

## 4. 정확성·busy·수명 결과

- consumer 228건: 성공 220, busy 8. 각 OFF/ON 114건에서 성공 110·busy 4이며 전부 `busy.thumbnailRenderSlots`로 직접 기록됐다. 정상 3번째 miss 대기를 아직 구현하지 않아 baseline의 즉시 busy가 유지된다.
- 각 consumer 실행의 metadata/snapshot 114회와 release 114회가 대응했다. exact/larger hit는 bytes를 읽지 않고 실제 miss/PDF는 Gowun Batang Regular/Bold의 정확한 bytes·face를 사용했다. 2페이지 PDF는 한 snapshot에서 두 페이지를 처리했다.
- snapshot 22건·signature 22건·교차 진단 비교 44건은 모두 성공했다. consumer를 포함한 새 시간 표본은 총 316건, 성공 308·busy 8이다. 초기 `snapshot-01` pilot 22건은 정식 취합에서 제외했다.
- guards OFF/ON은 각 16건 admission 상태에서 17번째 공급 획득 전 busy를 확인했다. 제어 gate·취소 preview 해제·관리 선택의 identity/정확 bytes 변화가 모두 통과했다. guard 내부 작업을 시간 표본 316건에 중복 집계하지 않는다.
- 기존 signed 로그 parser 호환은 157건, 성공 126·실패 31로 유지됐다. 다른 PID/UUID/잘못된 구간·중복·누락·다른 image UUID와 callback thread/시간 오대응을 거부하는 self-test가 통과했다. 새 signed 시험이 아니며 과거 busy 31건을 새 경계로 소급 분류하지 않는다.

## 5. 빌드·회귀와 재현

| 검증 | 결과 |
|------|------|
| `probe-extension-fonts.py --output build.noindex/task580/stage1/default-regression-01` | PASS. 진단 flag 없는 production cache, CoreGraphics/Skia PNG·2페이지 PDF·문서/원본 stale·권한 fallback·취소/한도·lease 회귀 |
| 성능 CLI `signature/snapshot/consumers/guards --repetitions 1` | PASS. canonical binary/source/fixture SHA 일치, 위 구간과 proof 검증 |
| 기존/상세 binary 교차 ON snapshot 2회씩 | PASS. 기준 commit source receipt와 binary SHA 대조 후 44건 비교 |
| signed parser self-test·기존 로그 재집계 | PASS. 157건 판정 보존·오대응 거부 |
| 두 Python scripts compile, `scripts/check-no-appkit.sh` | PASS |
| `xcodegen generate` → HostApp Release, `CODE_SIGNING_ALLOWED=NO` | 기본/진단 flag 모두 BUILD SUCCEEDED (46.588/55.748초) |
| source·sample·구간·lease·hit bytes·선별 SHA 검증, `git diff --check` | PASS |

성능 driver 예: `python3 scripts/probe-extension-font-performance.py --suite consumers --repetitions 1 --binary build.noindex/task580/stage1/signature-01/build/font-performance --output build.noindex/task580/stage1/<새 경로>`. 기존 binary는 source/fixture/framework receipt가 일치할 때만 재사용한다. fixture 파일은 manifest의 기존 격리 경로가 필요하며 일반 CI 성능 게이트로 실행하지 않는다.

Release build는 `-derivedDataPath build.noindex/task580/stage1/provider-build/DerivedData -clonedSourcePackagesDirPath build.noindex/task569/stage2/finder-build/DerivedData/SourcePackages -disableAutomaticPackageResolution`을 사용했다. 진단 build만 `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) ALHANGEUL_FONT_EXTENSION_PROBE'`를 추가했다. 첫 시도 네트워크와 sandbox package cache 접근 실패는 기존 cache를 사용한 재실행으로 회복했다. AppIntents 미사용 metadata 추출 경고는 남았으며 Swift compile 오류는 없다. 실제 sandbox/signed Finder 수용은 Stage 4 범위다.

## 6. 소유 부산물·등록 정리

기본 Xcode build는 `REGISTER_APP_WITH_LAUNCH_SERVICES=NO`에도 `RegisterWithLaunchServices`를 실행했다. 자동 등록을 의도한 시험이 아니며 설치된 앱을 교체하지 않았다. 표준 매뉴얼의 소유 경로 정리 방식으로 이번 `.app` 내부 두 appex·앱·Sparkle Updater 등록만 해제했고 각 exit 0을 확인했다. 전역 reset·다른 앱 등록 보정·OS 글꼴 변경은 하지 않았다.

등록 위생의 개발 등록/문제는 없었지만 app bundle이 남은 동안 `mdimport -L`에 소유 importer가 남았다. 완료된 소유 앱·두 loose appex·loose importer 총 4개를 정리하고 남은 앱 경로를 다시 해제했다. 이미 해제·삭제된 Updater 경로의 추가 해제는 `-10814`였으며 최종 등록/발견 검사로 잔존 없음을 확인했다. 논리 파일 합계 약 399.0MiB이며 실제 확보된 디스크 공간으로 환산하지 않는다. 측정 raw JSON·로그·receipt·CLI와 다음 단계 compile cache는 보존했다.

최종 위생 검사는 개발 등록·개발 app bundle·문제·경고 모두 0, provider root는 `/Applications/Alhangeul.app`이었다. importer 목록에서도 task580은 없고 기존 설치본 importer는 유지됐다. 원래 앱의 Info SHA `41f64c73e4d2848e2b8d34d4b3a1954e0645121072074f5d299929b5d52279a7`과 `codesign --verify --deep --strict` exit 0을 확인했다. 서명 검사는 제한된 실행 환경에서 `invalid signature`를 반환해 동일 명령의 권한 확장 읽기 검증으로 exit 0을 확인했으며 재서명하지 않았다. 선별 JSON 3개는 [SHA256SUMS](assets/task_m020_580_stage1/SHA256SUMS)로 고정했다.

## 7. 남은 위험과 다음 단계

signature의 실제 변화/권한·알림 경합과 metadata 재사용은 아직 제품에 연결하지 않았다. stat가 같다는 이유만으로 정확 bytes 사용을 보장할 수 없어 기존 FD/hash/face 검증을 유지한다. 전달되지 않는 OS 취소·실제 I/O 종료·deadline·병합 lease 수명은 계약과 production 회귀에서 구분해야 한다. 30초 대기 한도는 초기 내부 정책이며 OS 보장이나 느린 모든 문서의 성공 약속이 아니다.

확정 계약은 ON 준비 전후 signature·즉시 pending epoch 일치, OFF 관리 전용 공급, 요청별 snapshot, FIFO·2실행/16접수·시작 전 30초 대기와 실제 I/O 종료까지 슬롯 보유다. Stage 2 구현·production 회귀 → Stage 3 대기 → Stage 4 같은 signed 후보 재측정 → Stage 5 보고/PR 후 #569 안내·최종 Mac 수용으로 이어간다.

## 8. 승인 요청

Stage 1 보고와 확정 계약을 검토한 뒤 **Stage 2의 확장 목록/metadata 재사용·OFF 경로·요청별 수명 구현과 해당 회귀** 승인을 요청한다. 렌더 대기 제품 구현·새 후보 서명/설치·공개 배포는 이번 다음 단계 승인 범위에 포함하지 않는다.
