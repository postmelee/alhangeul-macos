# Task M020 #580 — 확장 글꼴 준비·렌더 대기 계약

- 근거: [구현계획](../plans/task_m020_580_impl.md), [Stage 1 보고](../working/task_m020_580_stage1.md), [Stage 2 보고](../working/task_m020_580_stage2.md), [Stage 3 보고](../working/task_m020_580_stage3.md).
- 적용 상태: Stage 2의 확장 전용 metadata 재사용·OFF 경로·요청별 수명은 구현·검증했다. Stage 3의 bounded FIFO·동일 key 병합·취소·deadline도 구현·격리 검증했다. 실제 signed Finder 재측정은 Stage 4 범위다.
- 기준: `devel`의 `dac73a589dc17143e744da6a12a51d638a81fb77`, core v0.8.7. HostApp의 기본 준비·설정, C ABI, 렌더 기본값은 유지한다.

## 1. 비용과 진단의 해석

동일 unsigned CLI의 HWP/HWPX `same/warm/exactHit` 각 20건에서 내부 metadata 중앙값은 OFF 641.242ms, ON 638.258ms였다. 그 안의 전체 정규화는 615.691/612.535ms, 활성 descriptor 열거는 10.518/10.402ms였다. 공급 조립은 3.526/3.565ms이고 원본 fingerprint·current 검사는 대략 5–6ms다. 중첩 구간을 합산하지 않는다.

별도 snapshot-only workload의 warm metadata는 113.291/112.618ms로 달랐다. 렌더 workload에는 번들 글꼴 준비가 선행한다. workload·프로세스 상태·직접 비최적화 CLI와 signed Release를 섞어 성능 개선으로 해석하지 않는다.

시험용 활성 signature의 warm 10건 중앙값은 OFF 44.028ms, ON 43.910ms였다. 같은 PID에서 첫 비교 전체 scan은 800.809/634.373ms였다. signature는 제품 현재성 검사에 연결하지 않았으며 이 숫자는 signed 목표 통과 근거가 아니다.

진단의 `busy.thumbnailAdmission`, `busy.thumbnailRenderSlots`, `busy.installedReadSlots`, `busy.transferSlots`, `busy.managedReadLock`는 기존 오류 직전에 기록한다. 발생 시도와 최종 실패 건수를 구분한다. 직접 consumer 228건의 busy 8건은 모두 `thumbnailRenderSlots`였다. 기존 #569 signed busy 31건에는 해당 경계 기록이 없어 원인을 소급 확정하지 않는다.

## 2. 활성 signature의 항목과 한계

활성 signature는 아래 항목의 정렬된 표현과 원본 상태를 묶은 SHA-256이다. 캐시 identity나 로그에는 opaque digest만 사용한다.

| 대상 | 확인 항목 |
|------|------|
| 활성 descriptor | 매번 새 CoreText 활성 목록을 얻은 뒤 canonical source URL, PostScript 이름, family/style, 정렬된 variation 좌표, symbolic/weight/width/slant traits |
| 목록 전체 | 정렬 순서에 무관하게 비교하되 중복 descriptor의 개수는 보존; 활성 목록의 추가·제거·비활성 반영 |
| 원본 파일 | canonical URL별 stat 중복 제거; 계산 속성 cache miss의 저장 전 stat 추가 재확인; device/inode/size/mtime/ctime의 초·나노초; 읽기 확인 실패는 성공 stamp와 다른 상태 |
| 공유 상태 | 설치 사용 정책 revision, 관리 manifest generation/digest·선택 및 객체 stamp, 알림 epoch, 준비 성공/실패 상태 |

시험의 key 차이 검사는 제거·중복·각 descriptor 항목·missing/permission 실패·inode/ctime 변경을 구분했다. 실제 OS 설치·비활성·권한 변화 수용을 대신하지 않는다. 시험 구현의 20,000건 guard는 활성 필터 전에 적용되므로 제품에서는 기존처럼 활성 필터 후 한도를 검사한다.

descriptor에 URL/PS 정보가 없거나 자료형·variation/traits를 신뢰할 수 없으면 이전 정상 metadata의 재사용을 허용하지 않는다. 기존 full scan의 생략/limitation 규칙을 따른다. descriptor에 표현되지 않는 내부 이름·축 정보는 원본 stamp 변화로 다시 정규화한다. 실제 내용/face 검증은 기존 FD·hash·PS/style 검사로 수행한다. stat만으로 정확한 bytes를 사용했다고 주장하지 않는다.

Stage 2 구현은 CoreText collection 안에서 이미 활성 필터를 통과한 목록의 enabled 속성을 중복 조회하지 않는다. 렌더 후 workload의 프로파일에서 중복 조회가 CoreText 내부 분석을 반복시키는 비용을 확인했다. signature가 불완전하거나 없는 주입 환경은 매 current 경계에서 full scan으로 검증한다. 원본 stat 실패를 정상 재사용 상태로 취급하지 않는다.

Stage 4.2는 확장 전용 `InstalledFontDescriptorCache`로 계산 속성만 재사용한다. 활성 collection·enabled·현재 URL/PS·원본 stat은 매 capture에서 확인한다. 전체 최소 속성 dictionary의 결정적 타입 보존 직렬화와 현재 URL/PS·stamp를 key로 삼고, 즉시 변경 epoch가 같은 cache session에서만 조회/저장한다. key 자체를 비교하며 hash만으로 같은 descriptor라고 판정하지 않는다. unknown·비정상 수·과도한 key는 cache를 사용하지 않고 기존 엄격한 getter로 처리한다. 중복·축·traits와 최종 signature 형식은 유지한다.

epoch·실패·취소로 무효화한 session의 늦은 저장은 차단하고, 재사용 불가능한 signature는 이전 계산 정보를 폐기한다. 저장은 최대 20,000항목·key/필드의 논리 크기 16MiB로 제한하며 넘으면 저장을 생략한다. 이 값은 실제 RSS 상한이 아니다. bytes/FD/snapshot을 저장하거나 전후/current 검사를 생략하지 않는다. HostApp의 기본 system 경로에는 이 cache를 연결하지 않는다. 직접 동등성·회귀 근거와 signed 재측정 gate는 [Stage 4 보고](../working/task_m020_580_stage4.md)를 따른다.

Stage 4.3은 확장 기본 환경의 `activeListMode`만 `activeCollection`으로 선택한다. `kCTFontCollectionIncludeDisabledFontsOption=false`로 매 capture마다 새 collection을 만들고 matching 결과의 중복을 보존한다. 활성 목록 자체나 enabled 값을 보관하지 않으며 matching 결과를 얻지 못하면 새 기본 collection과 기존 enabled getter 필터로 확인한다. HostApp 기본값은 `checkedAttributes`이고 주입 환경은 그대로 따른다. 원본 stat·epoch·계산 속성 key·전후/current 검사와 최종 digest 형식은 유지한다.

제품 연결 전 두 프로세스의 실제 목록 30쌍에서 기존 필터와 명시적 collection의 URL/PS 다중집합·digest/reusable이 일치했다. 고유 OFL 파일을 process scope로 등록하고, 실제 matching descriptor의 URL/PS/등록 scope를 확인한 뒤 해당 descriptor만 비활성화·재활성화·해제했다. 제품 회귀는 강제 epoch 갱신 없이도 이 변화를 감지했다. 사용자 OS 글꼴 설치/비활성화, 다른 macOS 버전 및 signed sandbox 동등성까지 검증한 것은 아니다. 새 후보의 동일 signed 목표를 확인하기 전 부모 Stage 4를 완료하지 않는다.

sandbox에서 얻는 목록과 원본 상태만 사용한다. HostApp bookmark나 관리 보관함 외의 지속 접근 권한을 공유하지 않는다. 현재성 검사가 실패하면 이전 bitmap을 성공으로 반환하지 않고 stale/준비 오류 경로로 처리한다. 모든 파일 bytes 선읽기는 금지한다.

## 3. 준비 세대와 변경의 게시

1. ON 최초 준비에서 변경 감시를 시작하고 signature → 전체 metadata scan → signature를 확인한다. 전후 signature·정책 revision·알림 epoch가 같을 때만 해당 세대를 게시한다.
2. 변화 없는 다음 요청은 가벼운 활성/원본 확인으로 준비된 불변 metadata를 재사용한다. 동일 준비·확인을 기다리는 요청은 한 작업을 공유하되 결과 획득 시 취소·정책·epoch를 다시 확인한다. 만료 시간만으로 재사용하지 않는다.
3. CoreText 변경 알림의 동기 callback에서 잠금으로 보호한 pending epoch를 즉시 증가시킨다. actor 전달 또는 200ms debounce 전에 이전 snapshot을 current로 답하지 않는다. 감시 시작과 첫 capture 사이 경합도 같은 epoch로 확인한다.
4. 알림이 누락돼도 매 요청과 반환 전 current 경계의 활성 signature·원본 상태 확인이 추가/제거/제자리 교체를 감지한다. 서로 다른 actor 구간에서 읽은 signature와 metadata를 하나의 유효 세대로 묶지 않는다.
5. 준비 중 변화가 확인되면 결과를 폐기하고 해당 요청은 stale로 끝낸다. 무한 재시도하지 않는다. 다음 요청이 새 준비를 시도한다. 준비 실패·권한 상실 상태에서 과거 정상 세대로 복귀하지 않는다.
6. OFF는 명시적인 설치 제외 상태로 관리 metadata만 조립한다. `StudioFontSupply.using()`의 기본 자동 prepare를 우회하는 내부 경계를 둔다. HostApp 기본 인자의 동작은 유지한다. OFF→ON은 새 준비와 변경 감시를 요구한다.

최초 렌더에 필요한 기존 process-scope 번들 글꼴 등록은 확장 공급/PNG/PDF 진입에서 설치 목록 준비보다 먼저 끝낸다. 준비 후 자기 번들 등록으로 세대가 바뀌는 경합을 피하며 renderer 기본값이나 OS 지속 글꼴 설치를 바꾸지 않는다. 모든 요청의 관리 manifest는 generation뿐 아니라 전체 불변 값도 비교해 같은 generation의 변경을 거부한다.

current 확인 이후 원본이 변할 수 있는 기존 TOCTOU 경계는 남는다. 실제 읽기 시와 결과 반환 직전 재검사를 보존하며 OS와 원자적 snapshot을 제공한다고 주장하지 않는다. 시험에서 활성 목록/권한 재검사 비용이 목표를 넘으면 정확성 검사를 제거하지 않고 근거와 대안을 보고한다.

## 4. 요청별 snapshot과 수명

공유하는 것은 불변 metadata와 준비 작업이다. 요청별 관리 snapshot/FD/read/current/release는 별도로 획득한다. A를 해제한 뒤 B가 읽을 수 있어야 하며 모든 획득에 해제가 한 번 대응한다.

준비 대기자 한 명이 취소돼도 다른 대기자의 준비 Task를 취소하지 않는다. 모든 대기자가 사라진 작업은 세대 게시를 차단하고 취소를 요청할 수 있지만, 취소에 반응하지 않는 물리 scan이 끝나기 전에 새 scan을 겹치지 않는다. 공유 preparation과 실제 read의 전송 budget은 구분한다.

관리 선택·객체 삭제/복구·정책 변화는 기존 generation/manifest 검증을 유지한다. 전체 metadata를 재사용하더라도 실제 읽기에서 현재 활성 face·정확한 PS/style·FD/hash·권한을 검증한다. stale/취소를 default 렌더 성공으로 우회하지 않는다.

## 5. 썸네일 대기 계약

| 자원 | 계약 |
|------|------|
| admission | 실행·metadata 준비·대기·동일 키 참가자를 모두 포함해 요청 16건; 취소된 job의 소유 접수도 실제 참조/I/O 종료까지 계산; 17번째는 공급 획득 전 busy |
| 물리 실행 | font miss job 최대 2건; 취소 요청을 받아도 실제 I/O 종료 전 슬롯을 반환하지 않음 |
| 대기 순서 | 서로 다른 miss key의 FIFO; 같은 key는 기존 대기/실행 job에 참가하며 새 슬롯을 만들지 않음 |
| cache | 기존 96항목·64MiB 유지; exact/larger hit도 현재성 검사 |
| bytes | 슬롯을 얻고 현재성을 재검사한 뒤 문서 load·선택 bytes 읽기·렌더 시작; 대기 중 전체 bytes/bitmap 선보유 금지 |
| 전송 | 설치 read 2건·공유 bytes 전송 2건 유지; 해당 과부하를 렌더 대기 성공으로 숨기지 않음 |

admission 이후 실제 렌더 시작 전 대기에는 단조 시계 기준 **30초**의 내부 deadline을 둔다. metadata 준비·key 확인·렌더 큐 대기를 포함하고, 실제 시작한 물리 I/O의 강제 종료 시간으로 사용하지 않는다. 정상 direct cold 동시 workload의 최대 약 2.752초와 구분해 여유를 둔 초기 값이며 OS가 보장하는 timeout이 아니다. 느린 사용자 환경에서도 무기한 대기 객체를 남기지 않기 위한 한도다. Stage 3는 주입한 deadline 길이와 제어한 공급/current/read gate로 단조 시계 경계를 검증하고 Stage 4는 정상 10개가 이 한도에 걸리지 않는지 확인한다.

deadline 초과는 `StudioFontError.busy`로 끝내되 `busy.thumbnailWaitDeadline`로 별도 진단한다. 반복 polling/즉시 재시도를 만들지 않는다. state 소유자가 deadline·완료·취소 경합을 직렬 처리해 대기 continuation을 한 번만 완료한다. 현재 callback 기반 provider는 OS 취소를 내부 Task로 직접 전달하지 않으므로 OS가 모든 요청 취소를 알려준다고 가정하지 않는다. 내부 Task 취소 회귀와 실제 Finder 관찰을 구분한다.

## 6. 병합 작업의 소유와 종료

- 각 참가자는 자신의 문서 stamp·공급 current·취소 상태를 반환 직전에 확인한다. key가 같다는 이유로 각자의 current 확인을 생략하지 않는다.
- job은 실제 렌더에 쓸 snapshot 한 개를 소유하고 참가자의 metadata lease와 수명을 구분한다. 최초 참가자의 단일 FD 소유에 job 참조를 retain하며, 마지막 참조에서만 실제 release한다. 다른 참가자는 각각 독립 snapshot을 획득한다. 참가자 한 명의 해제 때문에 실행 job의 FD가 닫히지 않게 한다. 불필요한 추가 lease는 해제하되 재검사에 필요한 값은 유지한다.
- 한 참가자의 취소/deadline은 그 참가자만 제거한다. 마지막 참가자가 없어진 대기 job은 큐에서 제거하고 소유 lease를 해제한다. 실행 중이면 취소 요청 후 물리 종료까지 슬롯과 job lease를 유지한다.
- 완료·오류·stale·취소 후 다음 FIFO job을 깨운다. key 변경/문서 변경/정책 변경 시 대기 결과는 폐기한다. 실패/fallback bitmap은 기존대로 성공 cache를 채우지 않는다.
- 유효한 참가자의 완료와 cache 게시를 별도로 판단한다. 취소된 마지막 참가자·무효 세대의 결과를 cache에 게시하지 않는다. 실제 완료 후 job 소유 해제·slot 반환·admission 반환이 각각 한 번 대응해야 한다.

## 7. 구현 단계의 통과 조건

Stage 2는 production 공급에 제어 가능한 scan/signature/알림 epoch·원본 변화를 주입해 full scan 횟수·OFF 생략·동시 준비·변경 중 게시 금지·권한 실패/복구·요청별 lease를 확인한다. descriptor 시험만으로 완료하지 않는다.

Stage 3는 실제 production cache에서 10개 정상 요청·동일 키·최대 2실행/16접수·17번째 busy, deadline·취소·오류·stale·경합·복구를 검증한다. 취소가 무시되는 I/O가 끝나기 전에 슬롯을 재사용하지 않는 검사가 필요하다.

Stage 4의 같은 signed 후보에서 warm metadata <200ms·provider <300ms와 정상 다수 파일 busy 0을 측정했다. 2026-10-11 승인으로 metadata 약 160~170ms·provider 약 328~343ms와 정상 자동 186건 busy 0·정확성·변경/복구·실제 GUI·원상복원을 현재 #580 완료 결과로 수용한다. provider <300ms는 미충족으로 보존하고 [독립 후속 #581](https://github.com/postmelee/alhangeul-macos/issues/581)으로 분리한다. 현재성·취소/lease·원본/권한·한도 계약은 완화하지 않는다. 직접 CLI 시간과 signed 시간을 합치지 않으며 실제 사용자 수용·웹 안내·release는 #569로 인계한다.
