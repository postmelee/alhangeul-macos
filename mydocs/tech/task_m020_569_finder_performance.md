# Task M020 #569 — Finder 글꼴 준비 성능 측정 계약

- 기준: Stage 1, 제품 `dac73a589dc17143e744da6a12a51d638a81fb77`, arm64/macOS 26.5.2.
- 실행 계획: [구현계획 Stage 2](../plans/task_m020_569_impl.md).
- 목적: 반복 요청의 전체 글꼴 준비 비용과 사용 동작을 확인하고 출시 전 개선 필요성을 판단한다. 현재 문서는 새 성능 측정 결과가 아니다.

## 1. 현재 호출 순서와 시간 해석

```text
Thumbnail 요청 → 최대 16건 admission
  → ExtensionFontSupply.snapshot
    → 공유 정책 확인 → 설치 사용 flag 반영 → 실제 CoreText catalog.refresh
    → 설치/관리 공급 metadata → 원본/관리 객체 stat fingerprint → current
  → 문서 stat + 공급 identity를 cache key에 결합
  → exact/larger bitmap cache → miss면 같은 key 요청 병합·최대 2건 렌더
  → snapshot/문서 current 확인 → 결과·lease 해제
```

`ExtensionFontSupply.snapshot()`의 `metadataMs`는 함수 진입부터 성공 snapshot 준비까지다. actor 진입 전의 대기는 제외하며 내부 async 대기·catalog·관리 metadata·fingerprint/current 비용은 포함한다. CoreText scan만의 시간이 아니다. `InstalledFontCatalogService.setEnabled`는 scan을 직접 실행하지 않으며 `refresh`가 환경 scan을 호출한다.

bitmap hit에도 먼저 snapshot을 준비한다. 2건 renderer 한도와 16건 admission, 96개·64MiB bitmap cache는 서로 다른 한도다. Thumbnail의 `renderMs`는 하위 렌더 진단이며 공급 준비·cache 조회·모든 대기를 포함하는 전체 응답으로 쓰지 않는다.

## 2. 기존 관측의 재확인

[#568 signed 이벤트](../working/assets/task_m020_568_stage5/signed-font-events.json)의 `metadataMs` 32건을 Stage 1에서 재집계해 기존 [요약](../working/assets/task_m020_568_stage5/signed-summary.json)과 일치함을 확인했다.

| count | 최소 | 중앙값 | 최대 |
|-------|------|--------|------|
| 32 | 453.637875ms | 1,089.7723335ms | 2,949.453667ms |

이 값은 과거 signed 실행의 snapshot 시간이다. 새 측정·warm/cache hit만의 중앙값·앱 실행시간·사용자가 보는 미리보기 완료시간으로 설명하지 않는다. 동시 요청의 metadata 이벤트를 특정 파일에 임의 대응하지 않는다. 기존 unsigned `ExtensionFontProbe`는 설치 scan을 빈 목록으로 주입하므로 실제 목록 탐색 성능 입력으로 사용하지 않는다.

## 3. 검증한 입력 자산

| 입력 | Stage 1 현재 hash | 용도 |
|------|------------------|------|
| `build.noindex/task568/stage3/fixtures/gowun-document.hwp` | `80f75353ba6b31c55169a7a8e29e35cbeba3ff4a2c66d0f961cadb4400caf199` | HWP 단일 페이지 원본 |
| `build.noindex/task568/stage3/fixtures/gowun-document.hwpx` | `d1dab09e04b996059929be22118975a1e9be88d87e526538337f13658d49bd33` | HWPX 단일 페이지 원본 |
| `build.noindex/task568/stage5/probe-inputs/multiple-two.hwpx` | `0a85f61a0fcb2a5fad6fa1487db862dedca3133a0457794c9f95b2c60f5ee281` | 기존 수용의 2페이지 HWPX. 새 실행에서도 실제 pageCount 확인 |

Gowun Batang Regular/Bold는 `build.noindex/task567/fonts/gowun-batang/`의 공식 Google Fonts commit `c1eda9233c33ad7775b27efd794f931095cf6133` 원본이다. TTF 두 개·OFL·METADATA 네 파일이 provenance의 길이/hash와 일치한다. R/B 원본 hash는 각각 `466c593e7147412e748af4856d5ad14709b5a860bdf62b9c2546f2c5874e9849` / `dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94`다. 사용자 OS 영구 설치를 수행하지 않는다.

Stage 2에서는 위 자산을 `build.noindex/task569/stage2/{run-id}/inputs/`에 복사하고 복사 후 hash를 확인한다. 다수 파일은 동일 bytes의 고유 이름 10개로 구성한다. 과거 NanumSquare/ArialUnicodeMS가 현재도 활성·접근 가능하다고 가정하지 않고 해당 실행의 실제 목록/선택/읽기를 기록한다.

## 4. 측정 구간과 원시 결과

모든 elapsed는 단조 시계로 구한다. wall-clock timestamp는 signed 로그의 실행 묶음/대응 확인용이며 NTP/시계 변경에 민감한 구간은 확정된 elapsed로 쓰지 않는다.

| 구간 | 정의 | 한계 |
|------|------|------|
| `scanMs` | 실제 `InstalledFontEnvironment.scan` wrapper의 진입→반환 | scan 횟수와 성공/실패를 함께 기록 |
| `snapshotCallMs` | 호출자에서 `await snapshot()` 시작→반환 | actor 진입 전 대기까지 포함 가능 |
| 기존 `metadataMs` | snapshot 내부 시작→성공 준비 | 내부 시간; 호출 전 대기 포함 값과 구분 |
| `readMs` / bytes | 실제 요청 face 읽기 시작→반환, read 횟수/bytes | cache hit 때 불필요한 읽기가 없음을 대조 |
| `renderMs` | 하위 renderer가 보고하는 구간 | metadata·cache·전체 응답으로 확대하지 않음 |
| `requestTotalMs` | 공통 소비자 호출 직전→callback/결과 반환 | Finder 화면 paint 완료시간이 아님 |
| 실제 provider 완료 | signed provider 함수 진입→reply handler | 요청 ID/단조 구간이 있는 경우만 확정 elapsed |

구간이 중첩되므로 합계로 전체 시간이나 순수 대기시간을 만들지 않는다. cache hit의 재사용된 render 진단도 새 요청의 렌더 시간으로 집계하지 않는다. 분리 계측이 없는 stat/fingerprint/queue 시간은 미측정이다.

원시 sample은 `runID`, `sequence`, `scenario`, `PID`, `installedEnabled`, `sourceCommit`, `buildFlags`, `documentHash/alias`, `maximumSize/scale`, 실제 bucket·cache event·backend, font identity·PS/style, monotonic start/end, scan/read 횟수와 확보된 각 시간, success/busy/stale/cancel/fallback/error를 기록한다. raw path·font bytes는 공개 evidence로 내보내지 않는다.

## 5. 반복·대조와 정확성

실제 CoreText 환경을 감싼 직접 probe와 signed Finder는 별도 결과군이다. 직접 probe의 App Group 대신 격리 root 사용·비 sandbox 조건을 반드시 표시한다. 정책 OFF/ON은 양쪽 모두 실제 서비스 호출을 사용하며 OFF에서도 현재 코드가 scan할 수 있음을 결과로 기록한다.

- snapshot: OFF/ON별 새 프로세스 3회, 각 최초 1회 + warm 10회. 프로세스 cold와 OS font cache cold를 혼동하지 않는다.
- 동일 Thumbnail: HWP/HWPX 각 256px 최초 1회 + 반복 10회, 조건별 2회. 256px 이후 128px 10회를 따로 측정하고 실제 larger bucket event를 확인한다.
- 다수 파일: 고유 10개, 순차 3 pass와 동시 최대 4건 3 pass. renderer/admission 초과 busy·실패를 기록한다. 추가로 제어된 한도 회귀에서 기존 2건/16건 경계와 취소/lease를 확인한다.
- preview: 단일 HWP/HWPX와 2페이지 HWPX의 최초/반복, 실제 페이지 수와 단일 snapshot·face 공급을 대조한다.
- 변화/복구: 격리 정책 OFF/ON·관리 선택/제거/복구·자체 원본 변경·새 PID. 실제 사용자 OS 원본을 삭제/변경하지 않는다. 설치 목록 변경은 주입 회귀와 실제 OS 수용을 분리한다.
- signed Finder: 같은 파일 Quick Look 열기/닫기 10회와 고유 10개 순차 열기 2 pass, icon view 최초/반복·크기 변경. 요청이 없으면 OS cache 생략으로 기록하고 sample 수를 억지로 채우지 않는다.

PS/style/hash가 다른데 성공으로 취급하거나 stale 결과 반환·권한 우회·bytes/renderer/admission 한도 초과·실제 I/O 전에 lease 해제가 발생하면 성능 수치와 무관한 결함으로 분리한다.

## 6. 집계와 개선 판단

scenario·OFF/ON·PID·cold/warm·direct/signed·cache event가 다른 sample을 한 중앙값으로 합치지 않는다. 유효 성공 sample의 count/min/median/max를 집계하고, 10개 이상일 때 nearest-rank p90(`ceil(0.9 × n)`번째)을 함께 기록한다. 실패/busy/stale/cancel/fallback 수는 별도 행으로 보존한다.

잠정 개선 검토 기준은 warm/cache hit에서 metadata median ≥ 500ms이고 같은 요청별 `metadataMs / requestTotalMs` 비율의 중앙값이 ≥ 0.30인 결과가 2회 재현되거나 정상 다수 파일에서 준비 대기/busy가 반복되는 경우다. 비율은 요청 ID로 대응되고 `0 < metadataMs ≤ requestTotalMs`인 성공 sample에만 계산한다. 비교 가능한 요청의 구간이 확보되지 않으면 30%를 추정하지 않고 분리 계측 또는 미판정으로 남긴다. 이 기준은 태스크 판단값이며 OS 표준·자동 합격/불합격 gate가 아니다.

재현되면 지배적인 구간·목표·freshness 회귀를 갖춘 별도 성능 이슈/계획으로 넘긴다. metadata 공유/변경 알림·정책 revision·선택 원본 검증을 보존하는 개선을 검토하되 무기한 캐시 재사용·전체 원본 선읽기를 이 측정 계약의 구현으로 간주하지 않는다. 개선 후 동일 workload로 재측정하고 최종 후보 수용에 연결한다.

## 7. signed 준비·종료 기준

[#569 Mac 수용 기준의 후보/복원 절차](task_m020_569_mac_acceptance.md)를 따른다. 기존 #568 helper의 고정 경로 guard를 우회하지 않고 UUID·출력 루트·fixture hash·인증서 범위·설치 원본/백업 digest·복원 상태를 준비한다. 서명/설치 전에 구체 대상의 승인 범위를 확인한다.

signed 결과에는 실제 extension 호출·PID·실제 공급/캐시 증거가 필요하다. 전역 cache reset·사용자 파일 timestamp 변경이나 다른 앱 등록 변경은 실행하지 않는다. 시험이 끝나면 해당 UUID 보관함·소유 후보 등록만 정리하고 원래 설치본을 복원한다. probe flag가 있는 signed 수용과 최종 배포 DMG smoke는 별개다.
