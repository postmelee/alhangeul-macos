# Task M020 #580 — Stage 3 제한된 썸네일 대기·병합·취소

- 이슈: [#580](https://github.com/postmelee/alhangeul-macos/issues/580), 상위 #562, 후속 #569.
- 계획: [구현계획](../plans/task_m020_580_impl.md), [확정 계약](../tech/task_m020_580_extension_font_contract.md).
- 기준 커밋: `fe06d8d7` (Stage 2 완료). 브랜치 `local/task580`.
- 승인: Stage 2 보고 후 “진행해줘. 저장공간도 최대한 확보하면서 진행해줘.” 지시로 Stage 3 구현·검증과 소유 부산물 정리를 승인받았다.
- 판정: Stage 3 완료. 실제 signed Finder의 성능·정확성 수용은 Stage 4에서 확인한다.

## 1. 변경과 동작

기존에는 두 font miss job이 실행 중이면 정상 세 번째 요청도 즉시 busy였다. 이제 `HwpThumbnailFontQueue` actor가 접수·FIFO 대기·동일 key 병합·실행·취소·종료를 직렬 관리한다. 접수 16건, 물리 실행 2건, 기존 bitmap cache 96항목/64MiB와 설치/공유 전송 2건 한도는 유지했다. 17번째 접수는 metadata 공급/FD 획득 전에 busy로 거부한다.

슬롯을 얻고 문서·공급 current와 Task 취소를 다시 확인한 뒤에만 document load·선택 bytes 읽기·렌더를 시작한다. 공급 실패의 명시적인 기본 대체도 같은 대기/실행 한도를 따른다. fallback·오류·stale 결과는 성공 cache를 채우지 않는다.

접수부터 렌더 시작 전까지 단조 시계 30초 deadline을 적용한다. metadata 준비와 FIFO 대기를 포함하고, timer 실행이 늦어져도 시작 직전 절대 deadline을 재검사한다. 초과는 busy이며 진단 빌드는 `busy.thumbnailWaitDeadline`로 구분한다. 이미 시작한 물리 I/O는 deadline으로 강제 종료하지 않는다. 주입한 짧은 deadline은 정확성 회귀용이며 실제 OS timeout 판정이 아니다.

각 참가자는 독립 공급 snapshot을 획득하고 반환 전에 자신의 문서 stamp·공급 current·취소를 확인한다. 최초 참가자의 단일 FD 소유에 job 참조를 retain해 참가자 해제와 실제 job 종료의 수명을 분리했다. 참조 마지막 해제에서 원래 snapshot.release를 한 번 호출한다. 렌더 API에는 job이 빌리는 snapshot을 전달하며 그 API의 release가 원본 FD를 먼저 닫지 않게 했다.

한 참가자의 취소/deadline은 나머지 참가자를 끊지 않는다. 마지막 대기자가 취소되면 FIFO에서 job을 제거한다. 실행 중 마지막 취소는 worker 취소를 요청하지만 실제 I/O/참조 해제가 끝날 때까지 물리 slot과 소유 접수 한도를 보유한다. 취소된 실행 job에 새 동일 key 요청을 병합하지 않는다. 완료·취소·deadline과 cache 게시를 직렬화해 continuation과 각 소유권을 한 번만 종료한다.

callback provider는 유지했다. 새 내부 async 진입은 호출 Task의 취소를 대기자에 전달한다. 현재 QL callback이 OS 취소를 이 Task로 직접 전달한다는 보장은 추가하지 않았다. 기존 공급 없는 cache 경로·HostApp·Studio·설정·core pin/C ABI·renderer 기본값은 변경하지 않았다.

## 2. 진단과 실제 공급 회귀

`thumbnailRenderWait`는 큐 진입부터 slot 획득/실행 job 참가 또는 대기 중단까지 기록한다. 물리 렌더 시간을 포함하지 않는다. FIFO의 다음 worker와 deadline 기록은 최초 요청의 opaque trace ID/observer를 복원해 이전 worker의 요청에 잘못 귀속하지 않는다. 기본 빌드에는 기록기를 활성화하지 않는다.

`Tests/ExtensionFontProbe/ThumbnailQueueAcceptance.swift`는 실제 production cache와 private 관리 글꼴/문서에 제어한 공급·current·read gate를 주입한다. 별도 모형 scheduler를 시험한 결과가 아니다. 기본/진단 flag 두 실행에서 다음을 통과했다.

| 조건 | 확인 결과 |
|------|------|
| 10개 고유 key + 같은 key 5명 | FIFO, 같은 key 한 번 렌더, 처음 요청과 참가자 하나 취소 후 나머지 성공, 14개 획득 모두 한 번 해제 |
| 대기 중 동일 key 병합 | owner 하나 취소 후 나머지 성공; 모두 취소한 key는 bytes 없이 제거·해제 후 재시도 |
| 접수 16/17번째 | 실행·대기·metadata 모두 계산; 17번째 공급 진입 없음 |
| 전체 취소·비협조 I/O | 실제 gate가 끝날 때까지 2 slot/원본 FD 유지; 그 뒤 새 요청 성공; 마지막 취소 결과 cache 게시 없음 |
| metadata/큐 deadline | metadata도 포함, 대기만 종료, 실행 I/O는 유지, lease 해제 후 재시도 |
| 슬롯 획득 직후 취소 | current 재검사 중 취소한 요청이 document load/bytes 전에 종료·해제·복구 |
| 대기 중 원본/current·문서 교체 | load/bytes 전에 stale 폐기, 다음 FIFO 요청 계속 성공, 모든 획득 해제 |
| 읽기 실패·완료/취소 경합 | 명시적 기본 대체·cache 미게시·한 번 완료·다음 요청 복구 |
| 기존 cache 상한 | 97개 작은 실제 bitmap과 64MiB를 넘는 큰 bitmap 8개로 오래된 항목 축출·최근 항목 hit |

기존 PNG CoreGraphics/Skia decode/Skia direct, 2페이지 PDF, exact/larger bitmap hit, 정책 revision 변경, inode/ctime 교체·stale·권한 fallback 회귀도 통과했다. 네 PNG(CoreGraphics·Skia 두 방식·권한 fallback)는 Stage 2 파일과 SHA-256이 동일하다. 정확한 GowunBatang Regular/Bold와 cache hit bytes 추가 읽기 없음·해제 대응을 유지했다. 이 결과는 실제 Finder/OS 권한 변화 수용을 대신하지 않는다.

## 3. 실제 CoreText 직접 workload

최종 source receipt가 일치하는 `final-direct-02`의 비최적화 unsigned CLI에서 OFF/ON snapshot·consumer·transition·guards 8회, 시간 표본 318건은 모두 success였다. 관리 객체 삭제의 예상된 명시적 fallback 2건은 정상 consumer와 구분했다. guard의 의도적인 17번째 busy 각 1회는 시간 표본에 포함하지 않았다.

| workload | OFF | ON |
|------|------|------|
| consumer 전체 | 144 성공 / busy 0 | 144 성공 / busy 0 |
| 동일 HWP/HWPX 첫 miss 후 exactHit | 각 1 miss + 10 hit | 각 1 miss + 10 hit |
| 256px 후 128px | HWP/HWPX 각 larger hit 10 | HWP/HWPX 각 larger hit 10 |
| 10개 순차 3 pass | 10 miss + 20 hit, busy 0 | 10 miss + 20 hit, busy 0 |
| 동시 4건 3 pass | 10 miss + 20 hit, busy 0 | 10 miss + 20 hit, busy 0 |
| 동시 최대 10건 3 pass | 10 miss + 20 hit, busy 0 | 10 miss + 20 hit, busy 0 |
| consumer 공급/해제 | 144 / 144 | 144 / 144 |
| consumer scan / 선택 read | 0 / 96 | 1 / 96 |

Stage 2와 공통 consumer 228건의 busy 8건은 이번 실행에서 0건이다. 새 최대 10건 부하의 추가 60건도 busy가 없었다. 정상 consumer의 `thumbnailRenderWait`는 OFF/ON 각각 32건이고 최대 242.929/3410.077ms였다. 이는 이번 직접 환경에서 30초 이전에 시작한 증거이며 signed 시간 목표 달성 근거로 사용하지 않는다. 첫/반복·다른 PID·snapshot-only와 renderer workload를 섞지 않는다.

## 4. 빌드와 검증

| 검증 | 결과 |
|------|------|
| `probe-extension-fonts.py --output .../default-acceptance-01` | PASS; production cache·위 표의 취소/한도·실제 PNG/다중 PDF |
| 동일 probe `--diagnostics --output .../diagnostic-acceptance-01` | PASS; 진단 flag의 동일 정확성 경로 |
| 성능 CLI `--suite all --repetitions 1 --output .../final-direct-02` | PASS, 8회/318건 및 guard proof, final source/binary/fixture receipt 일치 |
| `validate-stage3-render.sh .../render-smoke` | KTX/request/exam_kor 3종 PASS; 기존 core의 table overlap 진단은 남음 |
| `xcodegen generate`, 기본/진단 HostApp Release | BUILD SUCCEEDED, 41.384/37.584초; Developer ID 사용 없음 |
| no-AppKit·matcher/Studio asset receipt·parser self-test·문서 링크/SHA·diff check | PASS |

Stage 2의 FontLibrary 154개/Host 출력 81개 회귀는 해당 공통/Host/native renderer source를 바꾸지 않아 이번 단계에서 반복하지 않았다. 이 단계의 변경 경로는 실제 cache probe와 제품 Release compile로 검사했다. 기존 AppIntents 미사용 경고는 남는다. 최소 macOS 12/Intel 실제 실행은 수행하지 않았다.

초기 추가 probe에서 Swift actor 속성의 논리 연산 autoclosure 접근을 보정했다. 짧은 deadline 검사에서는 참가자 종료 직후 아직 진행 중인 job 참조 해제까지 기다린 뒤 해제 수를 검사하도록 시험을 보정했다. 실제 코드의 slot/current 경계 취소도 document load 직전 재검사와 제어 gate 회귀로 확인했다. 초기/중간 로그는 canonical 수용 표본에서 제외했다.

추가 `build-rust-macos.sh --verify-portable` 호출은 Rust 재빌드를 시작하는 명령이었고 Cargo sandbox git 디렉터리 접근 실패로 중단됐다. Rust source/core/ABI 변경이 없어 공간을 다시 사용하는 재빌드는 반복하지 않았다. 기존 사용 staticlib/헤더 SHA가 Stage 2와 동일함을 확인했고 그 산출물로 실제 PNG/제품 compile·렌더 smoke를 통과했다. Rust portable 재빌드 완료로 기록하지 않는다.

[측정](assets/task_m020_580_stage3/measurements.json), [source receipt](assets/task_m020_580_stage3/source-receipt.json), [검증·정리](assets/task_m020_580_stage3/validation.json), [SHA256SUMS](assets/task_m020_580_stage3/SHA256SUMS)에 원시 로그/JSON·source/binary/fixture hash·proof를 보존했다. canonical 성능 binary는 source receipt가 일치할 때만 재사용한다.

## 5. 공간 확보·등록·설치본 보존

삭제 전에 journal을 작성하고 다음 소유 중간 산출물을 정리했다.

| 정리 대상 | 논리 파일 합계 |
|------|------|
| 이전 단계 중복 CLI/모듈·완료된 출력 XCTest cache | 1295.2MiB |
| 완료된 `RustBridge/target` cache | 2008.1MiB |
| 이번 Release 앱·loose 확장/importer 4개 | 400.0MiB |
| 중간 실행 파일·모듈·임시 private 보관함 등 70개 | 1755.7MiB |

합계 약 **5.33GiB**의 논리 파일을 제거했다. 관찰한 볼륨 여유 공간은 약 19GiB에서 23GiB가 됐다. 중간 새 빌드와 APFS/다른 프로세스 사용량이 있으므로 논리 합계를 물리 확보 공간으로 환산하지 않는다. Rust cache의 process 조회는 sandbox에서 사용할 수 없어 프로세스 부재를 확인했다고 기록하지 않았다. 현재 단계는 보존한 Frameworks를 사용하며 향후 core 변경에는 cache 재생성이 필요하다.

raw JSON/로그/PNG/PDF·curated hash와 원본 OFL/문서 fixture, 후속 단계용 canonical 성능 binary·필요한 Release compile/SwiftPM cache는 유지했다. 타 작업 source/worktree·사용자 글꼴/문서·전역 cache를 수정하지 않았다.

Xcode가 자동 등록한 소유 앱/확장/Updater는 경로별 해제한 후 번들을 제거했다. 최종 개발 등록·bundle·문제·경고는 0, provider root는 `/Applications/Alhangeul.app`이다. 삭제 직후의 importer 목록에는 비동기 stale entry가 남았지만 재확인에서 task580 경로가 사라지고 설치본 importer가 유지됐다. 전역 reset/daemon 종료는 하지 않았다.

원래 앱 Info SHA `41f64c73e4d2848e2b8d34d4b3a1954e0645121072074f5d299929b5d52279a7`, strict 서명 exit 0을 확인했다. 설치본 교체·Developer ID 사용·공개 배포는 수행하지 않았다.

## 6. 다음 단계 승인

Stage 4의 같은 workload 직접 비교와 새로운 signed Finder 후보 수용을 준비할 승인을 요청한다. warm metadata <200ms/provider <300ms, 실제 정상 다수 파일 busy 0, face/bytes·변경/복구·등록/기존 설치본 복원을 따로 판정한다. 새 후보의 SHA·구체 fixture/설치·복원 대상이 준비되면 로컬 서명·임시 설치는 별도 승인받는다. #569 웹 안내·최종 사용자 수용·공개 release는 이후 순서다.
