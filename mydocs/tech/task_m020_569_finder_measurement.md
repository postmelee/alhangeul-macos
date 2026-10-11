# Task M020 #569 — Finder 글꼴 준비 측정 결과

- 일자: 2026-10-10. Stage 1 보고 후 “진행해줘”로 Stage 2 실행 승인.
- 기준: `local/task569`, `22e92164307f4cab4f16167513bd65dec1b6fd84` + 현재 미커밋 진단/probe 변경. 제품 core·Studio v0.8.7 고정 유지.
- 계약: [구현계획 Stage 2](../plans/task_m020_569_impl.md), [측정 계약](task_m020_569_finder_performance.md).
- 상태: **Stage 2 측정 완료**. 직접 측정·정확성 회귀·signed Finder 및 제어 요청과 원래 앱 복원을 완료했다. 출시 전 성능 개선이 필요하며 Stage 3는 아직 시작하지 않았다.

## 1. 현재 판단

직접 실행에서는 bitmap cache hit 이후에도 실제 CoreText 목록 준비가 반복되며 이 타스크의 성능 개선 검토 기준을 충족했다. 동일 문서 warm/cache hit의 내부 metadata 중앙값은 OFF/ON 각각 약 0.63초이고, 요청별로 대응한 전체 응답 대비 비율의 중앙값은 약 98%다. 새 프로세스 두 번 모두 같은 현상이 관찰됐다. 이 직접 CLI는 `swiftc`에 `-O`를 지정하지 않은 빌드이며 Release 성능으로 확대하지 않는다.

동시 최대 4건의 서로 다른 파일 요청에서는 내부 async 대기를 포함한 metadata 중앙값이 약 2.5초였고 최초 pass마다 4건의 `busy`가 발생했다. `busy`는 공급 한도/렌더 한도에 따른 결과이며 순수 목록 scan 시간과 같지 않다. 직접 측정은 정상 다수 파일 준비 비용의 재현 근거다. 실제 Finder 지연 또는 화면 완료시간으로 확대하지 않는다.

**최종 권고:** 출시 전에 확장의 반복 준비 비용과 정상 다수 파일의 `busy`를 개선한다. 최적화된 signed 확장의 exact/larger hit도 metadata 약 1.0초·전체 응답 대비 약 98%이며 독립 ON workload 두 번에서 기준을 충족했다. Finder GUI에서는 Thumbnail 55건 중 31건이 `busy`로 실패하고 일부 기본 파일 아이콘이 남았다. [성능 후속 이슈 초안](../working/task_m020_569_performance_issue.md)에 지배 구간·목표·freshness/한도 회귀를 정리했다. 이번 단계에서는 공급 동작·캐시·한도를 변경하지 않았다.

## 2. 입력과 실행 범위

- arm64 / macOS 26.5.2, 실제 `InstalledFontSystem` CoreText scan/read wrapper와 공통 공급·캐시·preview renderer를 호출했다.
- 공식 Google Fonts Gowun Batang Regular/Bold·OFL·METADATA 및 기존 HWP/HWPX/2페이지 HWPX의 Stage 1 hash를 검증한 뒤 실행별 private inputs/store에 복사했다. 고유 10개 문서는 단일 HWPX의 같은 bytes를 이름만 달리 복사했다.
- `snapshot`은 bundled font 등록을 수행하지 않았다. `consumers`/`transitions`는 제품 렌더가 사용하는 bundled 기본 글꼴을 프로세스 범위에서 한 번 준비한 뒤 측정했다. OS 영구 글꼴 설치는 수행하지 않았다. 두 조건의 결과를 합치지 않는다.
- 관리 Gowun R/B로 문서를 렌더했다. 실제 설치 catalog를 탐색했으나 사용자 OS 설치 원본 하나를 특정해 bytes 적용을 검증한 결과로 표현하지 않는다.
- OFF/ON 각각 snapshot 새 프로세스 3회 × 최초 1 + 반복 10, consumers 새 프로세스 2회, transitions 1회. 전체 **12개 프로세스, 530건: 성공 514 / busy 16**. 명시 fallback 2건은 관리 객체 제거 시나리오이며 성공 정확 적용으로 세지 않는다.
- 직접 측정 도중 unsigned Xcode 빌드의 의존성 조회를 한 번 시도했고 네트워크 제한으로 실패했다. 성공한 본 빌드와 guard/기능 회귀는 전체 측정 종료 후 실행했다. 다른 시스템 작업량은 통제하지 않았다.

## 3. 직접 측정 결과

아래는 요청 이벤트 대응을 보정한 같은 binary의 `snapshot-04`·`consumers-04`·`transitions-04` 유효 성공 sample 집계다. 별도 `guards-04` 두 프로세스는 제어한 대기를 포함하므로 성능 표에 넣지 않는다. 실패/busy는 별도 집계했다. metadata는 actor 내부 함수 진입부터 준비까지, `snapshotCall`은 호출 전 actor 대기까지 포함한다. scan/metadata/전체 구간은 중첩되므로 합산하지 않는다. 비율은 각 요청의 대응 구간으로 계산한 값의 중앙값이며 두 중앙값의 단순 나눗셈이 아니다.

| 조건 | count OFF/ON | 내부 metadata 중앙값 OFF/ON | 전체 응답 중앙값 OFF/ON | 대응 metadata 비율 OFF/ON |
|------|-------------|-----------------------------|---------------------------|---------------------------|
| snapshot 최초, bundled 등록 전 | 3 / 3 | 119.19 / 116.90ms | 124.68 / 122.18ms | 95.8 / 95.7% |
| snapshot 반복, bundled 등록 전 | 30 / 30 | 109.40 / 109.93ms | 114.47 / 115.02ms | 95.7 / 95.6% |
| HWP 같은 파일 warm exactHit | 20 / 20 | 634.29 / 632.75ms | 645.10 / 643.33ms | 98.4 / 98.3% |
| HWPX 같은 파일 warm exactHit | 20 / 20 | 633.84 / 628.55ms | 643.83 / 639.97ms | 98.4 / 98.3% |
| HWPX 128px warm, 256px larger hit | 20 / 20 | 643.38 / 637.10ms | 654.87 / 647.35ms | 98.2 / 98.3% |
| 10개 파일 순차 warm exactHit | 40 / 40 | 639.75 / 638.16ms | 651.28 / 649.10ms | 98.3 / 98.3% |
| 10개 파일 동시 최대 4건 warm exactHit | 32 / 32 | 2548.23 / 2550.03ms | 2564.63 / 2566.27ms | 99.3 / 99.3% |

동시 파일 최초 pass는 각 프로세스에서 성공 6 / busy 4, 다음 두 pass는 성공 20 / busy 0이다. warm pass에는 이전 실패 파일의 miss도 있으므로 exactHit 16건과 miss 4건을 분리했다. 위 warm exactHit 표는 두 반복의 exactHit 32건만 집계했다.

### 두 번 반복한 개선 검토 조건

| 설치 사용 | 반복 | 같은 파일 HWP+HWPX warm 20건 metadata 중앙값 | 대응 비율 중앙값 | 동시 warm 20건 metadata 중앙값 |
|-----------|------|-----------------------------------------------|------------------|-------------------------------|
| OFF | 0 | 629.58ms | 98.41% | 2545.63ms |
| OFF | 1 | 638.09ms | 98.34% | 2562.56ms |
| ON | 0 | 620.16ms | 98.28% | 2530.94ms |
| ON | 1 | 638.43ms | 98.27% | 2575.65ms |

500ms·30%는 이 타스크의 잠정 판단값이다. OS 성능 표준이나 자동 합격/불합격 기준으로 쓰지 않는다. bundled 등록 전 약 0.10초 결과만으로 렌더 이후 준비 비용이나 과거 signed 중앙값 1.09초가 개선됐다고 결론 내리지 않는다.

## 4. 정확성·한도 회귀

| 검증 | 결과와 범위 |
|------|--------------|
| snapshot metadata만 준비 | 실제 scan 한 번/요청, bytes 선읽기 없음. ON 첫 공급 face metadata 530개(관리 2 포함), 모두 적용 가능하다는 의미는 아님 |
| 같은 파일 bitmap 재사용 | 최초 miss → exactHit, 실제 Gowun R/B와 공급 성공 확인. hit에서 추가 font bytes 읽기 없음 |
| 큰 bucket 재사용 | 128px 요청에서 실제 `largerBucketHit(256x256)` 관찰 |
| 단일/다중 preview | HWP/HWPX 단일, HWPX 실제 2페이지의 R/B 공급 및 요청당 snapshot 해제 한 번 확인 |
| 정책 OFF/ON | 새 identity·cache miss, 관리 글꼴은 설치 사용 설정과 독립적으로 공급 |
| 객체 제거/복구 | private 객체 제거 시 명시 fallback·faces 없음, atomic 복원 후 cache miss·정확한 R/B 공급 |
| 16건 admission | 제어한 공급 gate에서 16건 진입, 17번째 busy·공급 미진입, stale 종료 후 16건 해제. 성능 samples와 분리 |
| 취소·선택 변경 | OFF/ON guard 두 프로세스에서 취소된 PNG 미반환·한 번 해제, padding만 달리한 private OFL 객체 선택 후 이전 snapshot stale·새 identity·선택 face의 정확 bytes 확인 |
| 기존 native 기능 회귀 | CoreGraphics/Skia PNG, 2페이지 PDF, stale/권한 fallback, 2건 렌더 한도·초과 요청 bytes 미읽기, inode/ctime 변경 무효화 통과 |
| 한도 보존 | 제품 2 render/16 admission/96 entries/64MiB bitmap 정책은 수정하지 않음. peak RSS·전체 cache 한계 stress는 측정하지 않음 |
| helper 경계 | 잘못된 단계 경로/task/source hash/입력 경로를 실제 서명·설치 전에 거부하는 4건 확인 |
| 제품 compile | probe flag ON 및 OFF의 Release HostApp·두 확장 포함 unsigned 빌드 성공. 123개 build 입력 Swift hash 준비 후 동일함 확인. 일반 경로 재빌드는 후보 복사본을 변경하지 않음 |

## 5. 실제 signed 결과와 복원

Release 최적화 후보를 기존 Developer ID로 로컬 서명하고 표준 smoke 안에서 `/Applications/Alhangeul.app`을 백업 후 임시 교체했다. App Group의 고유 하위 보관함 `50DBE545-4FEC-4F71-ACC8-F7DA289DA8E4`에 관리 Gowun R/B와 설치 사용 정책만 준비했다. 제품 release artifact·공증·공개 배포는 아니다.

- Quick Look 동일 파일 ON 10회 키 조작 시도에서 실제 provider 6건, OFF 10회에서 10건을 관찰했다. 첫 ON 시도의 일부 UI 검사는 diff만 확인해 불확실하며 미호출 이유를 OS cache로 단정하지 않는다.
- 고유 10개 문서의 ON 순차 열기 2 pass에서 실제 preview 20건과 파일명 표시를 확인했다. 같은 파일/다수 파일을 합친 preview 전체는 ON 26건·OFF 10건 모두 성공이다.
- Finder icon 첫 표시·반복 방문·크기 변경을 ON/OFF로 시도했다. 실제 GUI Thumbnail 55건은 성공 24·busy 31이다. 크기 slider는 AX 값이며 요청 pixel/bucket으로 해석하지 않는다. 과도하게 큰 ON slider를 24로 복구한 뒤 반복 방문했다. 정확 bucket은 확장 ready 로그로 확인했다.
- 표준 `qlmanage -t` smoke 3건과 후속 제어 요청 63건은 모두 PNG 출력에 성공했다. 제어 요청은 새 HWPX alias마다 256px 최초 1·반복 10, 128px 10으로 OFF 1회·ON 2회 수행했다. Finder GUI와 제어 CLI 결과를 같은 workload라고 설명하지 않는다.
- 전체 signed provider는 **157건: 성공 126·busy 31**, Thumbnail PID `20620` / Preview PID `21365`. 314개 UUID trace가 모두 1 metadata + 1 provider 구간으로 대응하며 미대응/역전/중복 interval은 없다. 실제 process image UUID가 설치한 후보와 일치한다.

### 제어된 signed cache hit

| 조건·반복 | 실제 cache | count | metadata 중앙값 | provider 중앙값 | 대응 metadata 비율 중앙값 |
|-----------|------------|-------|-----------------|-----------------|-----------------------------|
| OFF 1 | exactHit | 10 | 1008.69ms | 1027.78ms | 98.25% |
| ON 1 | exactHit | 10 | 1051.00ms | 1068.09ms | 98.33% |
| ON 2 | exactHit | 10 | 1018.37ms | 1035.08ms | 98.38% |
| OFF 1 | largerBucketHit(256x256) | 10 | 1026.71ms | 1044.80ms | 98.31% |
| ON 1 | largerBucketHit(256x256) | 10 | 1057.31ms | 1075.93ms | 98.38% |
| ON 2 | largerBucketHit(256x256) | 10 | 1022.14ms | 1039.36ms | 98.35% |

각 label의 최초 miss 1건은 위 warm 표에서 제외했다. 같은 signed PID의 독립 문서 workload 두 번이지 확장 새 PID 두 번은 아니다. 새 PID 반복은 직접 probe 결과에 남아 있다. 63개 PNG는 같은 요청 크기에서 OFF/ON·반복 간 bytes가 동일했고, 실제 출력은 256px의 182×256·128px의 91×128이다.

비율은 UUID로 대응한 단조 구간으로 계산했다. cache/bucket은 동일 PID·subsystem·thread·image UUID의 직전 ready 이벤트와 동기 callback의 trace가 1ms 이내일 때만 연결한다. metadata 조건도 동기 ready→trace에서만 읽는다. 다른 thread나 근접 시간창의 파일·cache를 추정해 대응하지 않는다. provider callback/reply 완료이며 Finder paint 완료시간과 같지 않다. metadata에는 목록/metadata/stat/current·내부 대기가 섞이며 순수 scan 시간으로 확대하지 않는다.

busy 31건의 실제 오류는 모두 `StudioFontError code=4`다. 제품 enum을 그대로 추출해 같은 Swift/Foundation에서 code 4가 busy, code 3이 stale임을 확인했다. 렌더 한도와 그 대기가 어떤 비율로 기여하는지는 추가 계측 없이 단정하지 않는다. 현행 2건 render/16건 admission 한도는 유지했다.

### 종료 검증

원래 v0.2.2 앱의 **152개 파일/링크·파일 hash/권한·symlink 대상이 첫 백업·두 번째 백업·복원본 사이에 전부 일치**했다. Info SHA `41f64c73e4d2848e2b8d34d4b3a1954e0645121072074f5d299929b5d52279a7`, unrestricted strict/deep 서명 검증과 원래 설치 경로 provider 확인을 통과했다. 실제 App Group `Library/Application Support/FontLibrary/v1/extension-probes/{UUID}` 제거·시험 Finder 창 닫기·소유 log stream 종료·개발 등록 없음도 확인했다. 전역 cache reset과 사용자 OS 글꼴 설치/변경은 수행하지 않았다.

## 6. 실패·환경 제약·정리

- `direct-01`: sandbox가 `@TaskLocal` macro plugin 응답을 차단하여 compile 실패. 같은 표준 `TaskLocal` API를 직접 선언해 해결했다. 권한 확장으로 macro 실행을 강제하지 않았다.
- `direct-02`: snapshot만 66건 통과한 예비 결과. 내부 metadata 구간 진단 전 결과이므로 본 집계는 `direct-03`으로 구분했다.
- `direct-03` 후속 점검: 캐시의 별도 작업으로 넘어간 일부 read/release 이벤트가 요청 ID 없이 기록됐다. 시간/metadata 대응은 유효하지만 miss의 요청별 read/release count를 완전한 결과로 쓰지 않는다. 순차 hit 240개 구간의 전체 read 이벤트 겹침은 0이었다. 요청 ID를 snapshot 생성 때 캡처하도록 진단 probe를 보정하고 소비자 456건을 재실행해 최초 두 읽기·hit 읽기 없음·해제 한 번을 직접 확인했다. 동일 binary로 snapshot 66·변경 8·guard 두 프로세스를 재검증했으며 본 집계에는 대응 누락 이벤트가 없다. 보정 전 530건과 후 530건을 한 성능 표로 합치지 않는다.
- 첫 Finder build: Sparkle fetch DNS 제한으로 실패. 승인된 unsigned 빌드의 dependency fetch만 unrestricted 재실행하여 성공했다.
- 제한된 shell의 원래 앱 `codesign` 검증은 잘못된 서명처럼 실패하고 process/registration 조회도 제한됐다. unrestricted 읽기 검증은 서명 유효를 확인했다. 설치본을 재서명하거나 수정하지 않았다.
- Xcode/OS가 두 새 개발 앱의 LaunchServices 등록을 자동으로 남긴 것을 unrestricted 조회로 확인했다. 정확한 두 소유 경로와 그 자식만 개별 해제하고 원래 설치본 provider 유지·개발 등록 없음 확인. 전역 reset·다른 등록 정리 없음. 등록되지 않은 unsigned 확장의 `pluginkit -r` 오류는 기록하고 실제 잔존 등록 여부로 확인했다.
- 마지막 일반 경로 build의 소유 등록도 개별 해제했다. 완료한 예비/구버전 probe의 compile cache·binary와 Xcode 중간 products/objects를 제거해 **논리 크기 1,301,600,879 bytes**를 정리했다. 원시 JSON·로그·receipt·보정 전 source·다음 시험의 unsigned 후보와 최종 probe binary·SPM cache는 보존했다. 실제 파일시스템 가용 공간 증가량과 논리 크기를 같다고 주장하지 않는다.
- 첫 signed 설치는 provider 조회가 `no matches`라 표준 smoke가 중단되어 자동 복원했다. 비동기 등록 확인에 최대 10회/9초 대기를 추가하고 동일 승인 후보 재시험은 통과했다. mock 검증은 2번째 시도의 올바른 경로 수용과 10번의 잘못된 경로 거부를 확인했다. 첫 mock의 인자 index 오류는 harness에서 보정했다.
- 복원 직후 OS가 남긴 이번 후보/백업/staging 등록 5개를 확인하여 정확한 소유 경로만 추가 해제했다. 모든 복원 검증과 provenance 저장 후 소유 앱·fixture·staging·중복 백업 6개를 제거해 **논리 크기 1,733,261,022 bytes**를 추가 정리했다. 최종 표준 registration check는 issues/warnings 모두 없음이다.
- 사용자 문서/글꼴·#567/#568 보존 입력은 수정하지 않았다. Stage 3 진입·PR/이슈 close·공개 배포를 수행하지 않았다. 제품 성능 개선 구현은 별도 승인된 이슈/계획에 남긴다.

## 7. 근거 위치

- 선별 [직접 요약](../working/assets/task_m020_569_stage2/direct-summary.json), [분포](../working/assets/task_m020_569_stage2/direct-distributions.json), [후보 상태](../working/assets/task_m020_569_stage2/candidate-status.json), [helper guard](../working/assets/task_m020_569_stage2/candidate-guard-results.json).
- 본 원시 결과: `build.noindex/task569/stage2/{snapshot-04,consumers-04,transitions-04}/*/result.json`, 각 `summary.json`·`run-receipt.json`, `consumers-04/build/receipt.json`과 같은 binary. 합산 근거는 `final-direct-summary.json`.
- guard 원시 결과: `guards-04/*/result.json`, 기존 기능 회귀 `native-regression-01/result.json`.
- 보정 전 결과와 진단 결함 근거: `direct-03/*/result.json`, `direct-03-attribution-audit.json`, 측정 당시 hash와 일치하는 `direct-03/build/ExtensionFontPerformanceProbe-main.swift` 보존.
- signed 선별 [요약](../working/assets/task_m020_569_stage2/signed-summary.json), [UUID 구간](../working/assets/task_m020_569_stage2/signed-intervals.json), [원시 로그](../working/assets/task_m020_569_stage2/signed-font-events.json), [UI 시도](../working/assets/task_m020_569_stage2/ui-trials.json), [복원](../working/assets/task_m020_569_stage2/restore-verification.json), [PNG 동일성](../working/assets/task_m020_569_stage2/controlled-output-check.json).
- signed 원본은 `finder-candidate-01/{font-events.ndjson,final-signed.json,ui-trials.json,controlled-qlmanage.py,controlled-thumbnails/receipt.json}`이다. 준비/서명 영수증은 선별 provenance에도 보존했다.
- build/preparation/복원 계획: `finder-build/{source-at-build.json,build-retry.log,default-build.log}`, `finder-candidate-01/{preparation.json,operation-plan.json}`. 중간 products 삭제 후에도 후보 복사본 Info/executable SHA와 원래 설치본 Info SHA가 유지됨을 확인했다.

[Stage 2 보고](../working/task_m020_569_stage2.md)에 측정 완료와 출시 전 성능 후속을 인계한다. 웹 안내와 최종 Mac 수용은 후속 승인된 단계에서 진행한다.
