# Task M020 #580 — Finder 글꼴 준비·썸네일 대기 구현계획

- 수행계획: [task_m020_580.md](task_m020_580.md)
- 이슈: [#580](https://github.com/postmelee/alhangeul-macos/issues/580), 상위 [#562](https://github.com/postmelee/alhangeul-macos/issues/562), 후속 [#569](https://github.com/postmelee/alhangeul-macos/issues/569)
- 제품 기준: `devel` / `dac73a589dc17143e744da6a12a51d638a81fb77`, 작업 `local/task580`
- 수행계획 승인: 2026-10-10 “수행계획 승인·구현계획 작성 진행”. 구현계획·Stage 1 승인: 같은 날 “구현계획 승인·Stage 1 진행”.
- 현재: [Stage 1 보고](../working/task_m020_580_stage1.md)와 [확정 계약](../tech/task_m020_580_extension_font_contract.md) 작성·검증 완료. Stage 2 진입 승인 대기다.
- 측정 기준: #569 Stage 2 `60ea06a384ce5ba9e43b60a30278ce1268efe237`. 공개 본문의 핵심 표와 로컬 브랜치·선별 증거를 대조한다. 원시 근거는 덮어쓰지 않는다.

## 1. 현행 경로와 단계 구성

구현계획 작성 중 확인한 현행 코드:

- `ExtensionFontSupply.snapshot()`은 공유 정책을 읽고 매번 `catalog.refresh()`를 실행한 후 공급 snapshot과 전체 원본 stat fingerprint를 만든다.
- `InstalledFontCatalogService.prepare()`만 CoreText local/distributed 변경 감시를 시작한다. 현행 확장은 직접 refresh로 prepared 상태를 만들므로 강제 refresh만 제거하면 변경 감시가 자동으로 시작된다고 볼 수 없다.
- `StudioFontSupply.using()`은 미준비 catalog에 prepare를 호출한다. 따라서 설치 사용 OFF의 강제 refresh만 지워도 최초 요청은 목록을 탐색할 수 있다.
- `HwpThumbnailRenderCache`는 요청 16건을 admission 한도로 둔다. 서로 다른 font job이 2건이면 다음 miss를 대기 없이 busy로 반환하고, 같은 키는 기존 Task를 공유한다.
- busy는 위 두 한도 외에도 catalog read·공유 전송 budget·관리 보관함 shared lock에서 발생할 수 있다. 실제 31건의 원인을 아직 한 지점으로 확정하지 않는다.
- `FontLibrarySnapshot`은 읽기/해제 수명의 FD를 가진다. metadata 준비가 같다는 이유로 요청별 snapshot 전체를 공유하면 한 요청 해제가 다른 요청의 읽기를 닫을 수 있다.

| 단계 | 구현·산출물 | 커밋 |
|------|------|------|
| 1 | 비용/busy 경계 진단·무효화/대기 계약·baseline 측정 도구 인계 | `Task #580 Stage 1: 글꼴 준비와 렌더 대기 계약 확정` |
| 2 | 확장 목록/metadata 준비 재사용·OFF 경로·요청별 수명 | `Task #580 Stage 2: 확장 글꼴 준비 재사용과 현재성 검증` |
| 3 | 제한된 썸네일 렌더 대기·병합·취소/과부하 처리 | `Task #580 Stage 3: 다수 파일 썸네일 렌더 대기 개선` |
| 4 | 같은 workload 직접/signed 측정·소비자 회귀·설치 복원 | `Task #580 Stage 4: Finder 성능 재측정과 소비자 수용` |
| 5 | 최종 회귀·보고·devel PR·#569 인계 | `Task #580 Stage 5 + 최종 보고서: 성능 개선 결과와 Mac 수용 인계` |

각 단계 보고서는 `mydocs/working/task_m020_580_stage{N}.md`에 작성하고 소스와 함께 커밋한다. 최종 보고서는 `mydocs/report/task_m020_580_report.md`에 둔다. 단계 승인 없이 다음 단계로 넘어가지 않는다.

## 2. 변경 계약

### 2.1 목록 현재성과 요청별 공급

확장만 사용하는 준비 경로를 공통 service의 기존 HostApp 기본 경로와 구분한다. 필요한 내부 Swift 진입점을 추가할 수 있지만 C ABI·core pin·Studio API는 바꾸지 않는다.

- 설치 사용 ON의 첫 준비는 실제 활성 목록을 읽고 변경 감시를 시작한다. 같은 유효 세대의 전체 metadata scan은 재사용하고 동시에 들어온 준비 요청은 같은 준비 결과를 기다린다.
- 재사용 결정에는 공유 정책 revision, 활성 descriptor 식별 정보, 원본 stamp와 준비 실패/변경 상태를 사용한다. 전체 CTFont 생성·이름/축 정규화를 매번 수행하지 않는 가벼운 활성 상태 확인을 우선 검토한다. 알림 누락·파일 제자리 변경을 놓치지 않아야 한다.
- Stage 1에서 활성 signature의 정확한 항목·중복/축 처리·원본별 stat 중복 제거와 비용을 확정한다. signature와 metadata가 서로 다른 시점의 결과이면 이전 세대로 게시하지 않는다. 이를 입증하지 못하면 전체 scan을 생략하는 구현으로 진행하지 않는다.
- 준비 중 변경·OFF 전환·권한 상실·실패 복구가 발생하면 세대를 무효화하고 이전 결과를 폐기한다. 알림 후 debounce 동안 이전 bitmap을 유효하다고 답하지 않게 pending 변경 상태도 현재성에 반영한다.
- OFF는 설치 목록 준비를 생략하는 관리 글꼴 전용 공급 경로로 구성하되 관리 선택/객체·정책/manifest 검증과 오류 분류를 유지한다. OFF→ON은 새 현재 목록을 준비하고 HostApp의 설정·표시 정책은 바꾸지 않는다.
- 재사용하는 것은 불변 목록/metadata다. 호출자는 각자의 관리 metadata snapshot·read/current/release 수명을 얻으며 요청별 획득/해제를 대응한다. 공유 준비 Task는 한 대기자의 취소 때문에 다른 대기자를 취소하지 않는다.
- 모든 글꼴 bytes를 미리 읽지 않고 실제 선택한 face의 기존 FD/hash/PS/style 검증을 유지한다. stale·취소는 default 렌더 성공으로 우회하지 않는다.

### 2.2 썸네일 대기와 한도

admission 16건 안에서 miss job을 대기시키고 실제 렌더는 2건까지 실행하는 방향으로 `HwpThumbnailRenderCache`의 font 경로를 보완한다. 기존 글꼴 공급 없는 cache 경로는 필요한 경우만 대조한다.

- 같은 cache key의 대기/실행 작업은 병합한다. 각각의 호출자는 자기 문서·공급 current와 취소 상태를 반환 직전에 확인한다.
- 서로 다른 키는 제한된 대기 목록을 사용한다. 대기 항목과 실행 항목을 합쳐 admission 한도를 넘지 않으며 활성 render job 수와 혼동하지 않는다.
- 슬롯을 얻은 뒤에 문서 load·font bytes 읽기·렌더를 수행한다. 16개 요청이 미리 전체 bytes/bitmap을 쥔 채 기다리는 흐름을 만들지 않는다.
- 한 대기자의 취소는 그 대기자만 끝내고 마지막 대기자가 사라진 작업은 시작 전 제거한다. 이미 시작한 I/O는 실제 종료까지 슬롯·snapshot을 보유하고 종료 경로에서 한 번 해제한다.
- 완료·오류·stale·취소 모두 다음 대기 작업을 깨운다. slot·admission·lease가 새거나 continuation을 두 번 resume하지 않는다. cache hit도 current 검증을 거친다.
- cache 96항목/64MiB·render 2건·admission 16건과 기존 전송 budget을 유지한다. 17번째 실제 admission 초과는 명시 busy로 판정한다. 정상 3번째 miss가 슬롯을 기다리는 동작과 구분해 기존 probe 기대값을 보정한다.
- 대기 순서·deadlines·공유 작업 종료 규칙은 Stage 1에서 cold workload와 provider 수명 계약을 대조해 확정한다. 무제한 대기 목록·반복 즉시 재시도·한도 증가로 해결하지 않는다.

Stage 1 확정: 활성 descriptor·원본 stamp와 즉시 변경 epoch를 확인하고 준비 전후 signature가 일치한 세대만 재사용한다. 서로 다른 miss key는 FIFO, admission 후 렌더 시작 전 대기는 단조 시계 30초로 제한한다. 이 값은 OS timeout 보장이 아니며 deadline과 물리 I/O 슬롯 수명을 구분한다. 세부 규칙·한계·검증은 [확정 계약](../tech/task_m020_580_extension_font_contract.md)을 따른다.

## 3. Stage 1 — 경계 진단·설계와 측정 인계

성능 구조는 바꾸지 않고 필요한 측정 도구와 설계 계약을 준비한다.

1. #569의 `ExtensionFontPerformanceTrace`, 성능 CLI와 parser를 고정 커밋에서 대조하고 필요한 진단만 가져온다. CLI·출력 경로·fixture manifest는 #580 소유로 정리한다. #569의 보고서·오늘할일·후보 앱을 통째로 가져오지 않는다.
2. `ALHANGEUL_FONT_EXTENSION_PROBE` 안에서 요청 UUID·단조 구간과 busy 경계 원인을 추가한다. scan/정규화/stat, 관리 목록/lease, current/fingerprint, actor/렌더 대기와 전체 callback을 구분한다. 이 구간은 겹칠 수 있으므로 단순 합산하지 않는다.
3. 수동 TaskLocal 방식의 기존 진단을 재사용한다. 기본 제품 빌드에 기록기·공개 원본 경로·bytes·bookmark를 추가하지 않는다. parser는 PID/subsystem/request UUID/image UUID의 직접 근거로만 대응하며 실패·불완전 구간을 별도 기록한다.
4. 가벼운 활성 signature의 범위·변경 알림 수명·실패 복구·세대 게시 조건, bounded 대기 순서/deadline·취소/slot 소유를 기술 문서 `mydocs/tech/task_m020_580_extension_font_contract.md`에 확정한다. source identity/권한의 가벼운 검사만으로 현재성 보장이 불가능한 조건을 명시한다.
5. 실제 CoreText의 직접 unsigned baseline 일부와 상태 주입을 구분해 진단을 확인한다. 새 signed 후보·OS 설치·기존 앱 교체는 수행하지 않는다.

예상 파일: 기존 공급/thumbnail/native 진단 경계, `Tests/ExtensionFontPerformanceProbe/main.swift`(진단 재사용 예정), `scripts/probe-extension-font-performance.py`·`scripts/summarize-extension-font-performance.py`(재사용 예정), 별도 fixture manifest와 기술 계약. stage별 산출물은 `build.noindex/task580/stage1/`에 둔다.

검증: 새 parser의 UUID/시간/중복·누락/다른 PID 대응 회귀, 실제 source receipt·fixture SHA 일치, 기본/진단 flag의 최소 compile, 기존 확장 기능 probe. 같은 구간의 baseline 변화가 진단 오버헤드인지 구분한다. Stage 1 종료 때 이후 제품 설계를 확정해 보고하고 범위가 달라지면 구현 전에 계획을 보정한다.

## 4. Stage 2 — 목록 준비 재사용·OFF 경로

`ExtensionFontSupply`의 매 요청 전체 refresh를 Stage 1 계약에 따른 확장 준비 경로로 바꾼다. `InstalledFontCatalogService`·`InstalledFontSystem`의 필요한 내부 current/prepare 기능을 보완하고, `StudioFontSupply`는 설치 준비와 metadata 조립을 분리해 OFF에서도 불필요한 scan을 유발하지 않게 한다. HostApp 기본 동작은 기존 인자/경로로 유지한다.

검증의 핵심은 production 공급을 실제 private store·제어 가능한 scan/read와 함께 호출하는 것이다.

- ON 최초 준비 후 변화 없는 반복·동시 요청의 전체 scan 횟수, OFF 첫/반복 scan 생략과 관리 face 동일 선택을 확인한다.
- 새 활성 face·삭제·비활성·동명 다른 원본·축·원본 inode/ctime/내용 변화와 권한 상실/복구에서 signature와 세대가 바뀌고 이전 snapshot/cache가 stale로 폐기되는지 확인한다.
- 알림 도중 준비/대기·OFF/ON·새 PID·한 대기자 취소·전체 취소·준비 실패 후 재시도에서 오래된 결과나 미준비 상태를 성공으로 게시하지 않는지 확인한다.
- 관리 선택·객체 삭제/복구·manifest 변경, 두 요청의 서로 다른 FD/lease·먼저 끝난 요청 해제 후 나머지 읽기, 실제 bytes 지연/한도/face 검증을 확인한다.
- 공통 service 변경이 있으면 기존 설치 catalog·최초 활성화/재실행·Studio 공급·PDF 준비 단위 회귀를 수행한다. 실제 OS 변경 시험으로 수행하지 않은 조건은 주입 결과로 표기한다.

관련 XCTest는 `Tests/FontLibraryTests`에서 production service를 사용하고, renderer/bitmap 현재성은 기존 확장/native probe를 확장한다. 해당 단계에서 schema/core/ABI·HostApp UI를 바꾸지 않는다.

## 5. Stage 3 — 제한된 렌더 대기·취소

`HwpThumbnailRenderCache`의 font 작업 상태를 admission·대기 job·실행 job·대기자 수명으로 관리한다. Stage 1 계약에 정한 상태 전이만 직렬 상태 큐 또는 내부 actor가 소유하게 한다. 이미 생성된 lease를 여러 호출자의 ownership으로 복제하지 않는다.

검증은 실제 production cache에 제어 gate가 있는 공급/읽기를 넣어 다음을 확인한다.

- 정상 10개 다른 문서·동일 키·크기 변경의 완료/병합, 실행 최대 2건·admission 최대 16건과 17번째 busy.
- 대기 전/대기 중/슬롯 획득 직후 취소, 병합 대기자 한 명 취소·모두 취소, 완료와 취소 경합, I/O 실패·stale 후 다음 요청 복구.
- 대기 중 정책/문서/원본/관리 객체 변경에서 이전 결과 폐기, 실제 시작 전 불필요한 bytes 읽기 없음, 각 획득에 대응한 단 한 번 해제.
- exact/larger cache hit의 current 검증과 96항목/64MiB eviction, 오류/fallback 결과로 재시도를 막지 않는 동작.

기존 `Tests/ExtensionFontProbe/main.swift`의 “2건 렌더 중 다음 요청 busy” 부분은 정상 요청 대기/완료 증거로 보정한다. 실제 admission 초과·전송 한도·취소 I/O 완료까지 slot 보유 회귀는 유지한다. 실패를 모두 성공으로 바꾸거나 기존 제한 검사를 제거하지 않는다.

## 6. Stage 4 — 같은 workload의 재측정·소비자 수용

후보 SHA·source/lock/asset receipt와 fixture SHA를 고정한 뒤 직접 측정과 실제 signed Finder를 나누어 기록한다.

| 조건 | 표본/반복 | 판정 |
|------|------|------|
| snapshot·OFF/ON | 각각 새 PID 3회, 최초 1회·반복 10회 | scan/준비 횟수·metadata·bytes 선읽기 없음·현재성 |
| HWP/HWPX Thumbnail 256px | 최초 1회·exactHit 10회, ON 독립 workload 2회와 OFF 대조 | signed warm metadata 중앙값 <200ms·provider 중앙값 <300ms |
| 256px 후 128px | largerBucketHit 10회, 동일 반복 조건 | 실제 큰 bitmap hit·동일 시간 목표·현재성 |
| 다수 파일 10개 | 순차 3 pass·동시 4건 3 pass·최대 10건 부하를 구분 | 정상 준비/렌더 대기 busy 0, 실행/메모리 한도 유지 |
| preview | 같은 파일 열기/닫기 10회·고유 파일 10개 2 pass 시도 | 실제 새 요청만 집계·단일/2페이지 정확 공급·lease |
| 실제 Finder icon view | 고유 파일 10개 첫/반복 표시·크기 변경 | 실제 유효 요청의 정상 busy 없음·PNG/아이콘 확인 |
| 변경·복구 | OFF/ON·관리 선택/삭제/복구·격리 원본/권한·새 PID | stale 폐기·정확 face/style·새 identity·원래 상태 복원 |

시간 목표는 유효 성공 표본 10건 이상에서 판단하고 실패·취소를 별도 집계한다. 최초 miss·다른 PID·직접 non-optimized CLI·signed Release를 합치지 않는다. #569 baseline 직접 CLI는 `-O` 없이 컴파일됐으므로 같은 direct 비교와 새 최적화 비교를 별도 열로 기록한다. OS가 요청하지 않은 UI 시도는 `요청 없음`으로 남긴다.

Developer ID 서명·고유 fixture·`/Applications/Alhangeul.app` 백업/임시 설치·복원 대상이 준비된 뒤 구체 시험 승인을 받는다. 시험 후 원래 앱의 파일/링크·서명·active provider 등록과 own fixture/개발 등록 정리를 확인한다. 이전 후보는 이미 삭제됐으므로 새 후보 hash를 준비한다. 전역 cache 초기화·물리 인쇄·사용자 글꼴 변경은 하지 않는다.

CoreGraphics 기본과 Skia opt-in의 단일/다중 페이지 및 실제 공급 face 근거를 확인한다. 공통 catalog/공급 변경이 영향을 주면 Studio·PDF/인쇄 준비 회귀도 수행한다. 이는 #569의 최종 사용자 수용·최소 OS 실행·공개 DMG gate를 대신하지 않는다.

## 7. Stage 5 — 회귀·보고·PR·후속 인계

변경 유형의 검증과 Stage 4 개선 전후 표·busy 경계·정확성·환경/제한을 취합한다. 최종 보고·오늘할일 완료와 PR 승인 절차 후 `publish/task580`으로 게시하고 `devel` 대상 Open PR을 만든다. #580 완료 기준을 충족한 PR은 `Closes #580`, #562/#569는 `Refs`로 참조한다. 리뷰/CI/merge 전 이슈를 닫지 않는다.

인계에는 후보 SHA·core/asset·설정·원본/관리 fixture·signed 결과·미검증 환경·등록 복원 결과를 포함한다. #569 브랜치의 미병합 진단과 이 타스크의 재사용 부분을 대조할 통합 지점을 적고, 무승인 rebase/merge/cherry-pick을 하지 않는다. 이후 #569 Stage 3 웹 안내와 Stage 4 최종 Mac 수용을 개선 후보로 진행한다.

## 8. 검증 명령과 수용 경계

착수/계획 문서는 링크·섹션·상태·`git diff --check`만 검증한다. 아래는 해당 코드 변경 단계의 계획이며 지금 실행한 결과가 아니다.

- `scripts/test-font-library.sh`: 공통 catalog/공급·lease/정책 XCTest. 영향이 있으면 `scripts/test-studio-output.sh`의 HostApp 출력 회귀 추가.
- `scripts/probe-extension-fonts.py --output <새 build.noindex/task580/...>`: production cache/preview·취소·한도·실제 PNG/2페이지 PDF 회귀.
- `scripts/probe-native-font-supply.py --output <새 build.noindex/task580/...>`: 공식 matcher·CoreGraphics/Skia 실제 face/bytes와 전송 한도.
- 재사용 성능 CLI의 `--suite snapshot/consumers/transitions/guards`, parser self-test: #580 경로/fixture manifest를 Stage 1에서 확정. 타이밍을 일반 CI의 고정 성능 게이트로 만들지 않는다.
- `scripts/check-no-appkit.sh`, `node scripts/build-native-font-matcher.mjs --verify`, `scripts/verify-rhwp-studio-assets.sh`: 경계·matcher·번들 receipt 유지.
- `xcodegen generate`와 기본/진단 flag Release 최적화 build. `project.yml`을 원본으로 사용한다. renderer 연결을 변경하는 단계에는 `scripts/validate-stage3-render.sh`를 수행하고 시각 결과 변화가 있으면 문제 샘플 core/native 비교를 추가한다.
- signed 단계의 prepare/smoke helper는 #580 허용 경로·새 source receipt·기존 설치본 복원 guard를 최소 보완한다. 다른 작업 산출물이나 전역 등록은 변경하지 않는다.

시간 목표 미달·정상 다수 파일 busy·freshness/취소/해제/한도 실패는 미완료로 기록한다. 미달을 숨기기 위해 표본을 줄이거나 실패를 무조건 fallback 성공으로 합치지 않는다. 변경이 없고 검증을 통과했으면 같은 전체 검증을 이유 없이 반복하지 않는다.

## 9. 현재 승인 범위와 다음 승인 요청

수행계획·구현계획과 Stage 1의 경계 진단·무효화/대기 계약·측정 도구 인계를 승인받아 완료했다. **Stage 1 보고와 확정 계약을 검토하고 Stage 2의 확장 목록/metadata 재사용·OFF 경로·요청별 수명 구현을 승인받으면 진행한다.** 렌더 대기 제품 구조는 이후 Stage 3 승인 범위다.

Stage 1의 unsigned signature 비용은 재사용 설계를 진행할 근거이며 signed 성능 목표 달성을 입증하지 않는다. 이후 현재성 검사와 실제 대기 구현이 정확성이나 잠정 목표를 만족시키기 어려우면 측정 근거와 대안을 제시해 범위를 보정한다. 새 C ABI·renderer 기본 변경·사용자 OS 글꼴 변경·새 후보 로컬 서명/임시 설치·공개 release는 Stage 2 승인 요청에 포함하지 않는다.
