# Task M020 #447 Stage 1 완료보고서

## 단계 목적

v0.1.9 signed candidate의 Thumbnail crash와 rhwp v0.8.2 BinData API 변경을
코드 수준에서 연결하고, `rhwp_image_data`가 따라야 할 단일 ownership 계약,
회귀 fixture와 Stage 2~5 구현·검증 경계를 확정한다.

Stage 1은 조사와 구현계획 작성만 수행한다. RustBridge, Swift caller,
generated artifact, 앱과 extension 등록 상태는 변경하지 않는다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/plans/task_m020_447_impl.md` | 신규 486줄 | caller-owned buffer/free 계약, Rust·Swift test matrix, Stage 1~5와 중단 조건 확정 |
| `mydocs/working/task_m020_447_stage1.md` | 신규 | 조사 근거, 대안 판단, 검증 결과와 Stage 2 승인 요청 기록 |
| `mydocs/orders/20260729.md` | 1행 갱신 | #447 상태를 Stage 1 완료·Stage 2 승인 대기로 전환 |

### 조사 결론

1. upstream v0.8.2의 `DocumentCore::get_bin_data()`는 지연 로딩 도입으로
   `Option<Vec<u8>>`를 반환한다.
2. 현재 RustBridge는 이 임시 `Vec`의 `as_ptr()`를 반환하고 함수 종료 시
   allocation을 해제한다.
3. Swift의 `Data(bytes:count:)` 복사는 Rust 함수가 돌아온 뒤 실행되므로
   해제된 pointer를 읽을 수 있다.
4. 실제 v0.1.9 build 15 crash 두 건은 모두
   `_platform_memmove → Data.InlineSlice → RhwpDocument.imageData`와
   `com.postmelee.alhangeul.thumbnail-render` queue를 가리킨다.
5. 기존 `rhwp_free_bytes`가 있고 직접 caller는
   `RhwpDocument.imageData`와 `imageDataLength` 두 곳이므로 새 symbol 없이
   explicit ownership으로 전환할 수 있다.

### 대안 판정

| 대안 | 판정 | 근거 |
|------|------|------|
| `RhwpHandle` stable cache | 제외 | upstream lazy loading의 메모리 절감 목적과 달리 raw bytes를 handle 종료까지 중복 보유하며 mutation/interior mutability 계약이 추가된다. |
| 신규 copy symbol | 제외 | unsafe 기존 symbol을 남기고 API·test·문서 경로를 이중화한다. |
| 기존 symbol caller-owned 전환 | 채택 | upstream owned `Vec`와 의미가 맞고 Swift 복사 직후 기존 free ABI로 회수하며 symbol 목록을 유지한다. |

확정 계약은 다음과 같다.

- `rhwp_image_data` 성공 반환형은 mutable byte pointer다.
- pointer는 caller-owned이며 `rhwp_free_bytes(pointer, len)` 전까지 유효하다.
- allocation은 document handle과 독립이다.
- 실패·empty·panic은 null pointer와 length 0으로 정규화한다.
- Swift는 `Data` 복사 직후 `defer`로 pointer를 정확히 한 번 해제한다.
- `imageDataLength`도 bytes allocation을 받으므로 길이만 사용한 뒤 해제한다.

### 회귀 fixture

`samples/복학원서.hwp`를 최소 lifetime fixture로 확정했다. 기존 metadata
보고에 다음 embedded image 근거가 남아 있다.

| binDataId | mime | byteCount | 용도 |
|----------:|------|----------:|------|
| 1 | `image/png` | 44,860 | Rust/Swift 반복 data 조회 기본 fixture |
| 2 | `image/png` | 253,602 | 두 번째 id와 교차 조회 확장 fixture |

Stage 2 Rust test는 id 1 pointer를 explicit free 전에 allocator pressure에
노출하고, 동시 두 allocation과 handle close 뒤 유효성을 확인한다. Stage 3
Swift test는 copied `Data`의 document lifetime 독립성과 반복 조회를 확인한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source, Rust dependency, core/studio provenance와 generated artifact
  변경은 없다.
- `RustBridge/src/lib.rs`, `RhwpDocument.swift`, test source는 읽기만 했다.
- 기존 수행계획서 본문은 변경하지 않았다.
- 오늘할일의 기존 #441 보류와 #442 완료 행은 보존하고 #447 비고만 현재
  승인 단계로 갱신했다.
- 로컬 crash report는 증거로만 읽었고 이동·삭제·수정하지 않았다.
- `/Users/melee/Documents/projects/forks/rhwp`의 사용자 변경은 건드리지 않았다.

## 검증 결과

구현계획서 Stage 1에 고정한 검증 명령을 그대로 실행했고 모두 exit code 0으로
통과했다.

| 검증 | 결과 | 핵심 출력 |
|------|------|-----------|
| upstream API | PASS | line 1227~1228에서 지연 로딩과 `Option<Vec<u8>>` 확인 |
| FFI symbol·caller inventory | PASS | 기존 `rhwp_image_data`, `rhwp_free_bytes`, Swift wrapper 두 곳 확인 |
| fixture 근거 | PASS | `복학원서.hwp` id 1·2와 byteCount 표 확인 |
| crash evidence | PASS | 두 `.ips`에서 `_platform_memmove`, `Data.InlineSlice`, `RhwpDocument.imageData`, thumbnail-render queue 확인 |
| 구현계획 단계·계약 | PASS | owned-buffer, free ABI, Stage 2~5와 중단 조건 확인 |
| whitespace/diff | PASS | `git diff --check` 오류 없음 |

crash header 교차 확인:

| 시각 | 앱 | 버전/build | Incident |
|------|----|------------|----------|
| 2026-07-29 17:16:01 KST | AlhangeulThumbnail | 0.1.9 / 15 | `BFC71233-F2CA-4FE8-A54F-6BC29B2A2172` |
| 2026-07-29 17:16:10 KST | AlhangeulThumbnail | 0.1.9 / 15 | `31487801-6D12-4CF6-A0BD-1BFB216A3226` |

두 보고서의 slice UUID는
`dbbe01a1-bbdf-3219-8d8a-2fc2e8b9e70d`로 동일하다. 서로 다른 코드 버전의
우연한 crash를 합친 것이 아니다.

## 잔여 위험

- 아직 unsafe RustBridge source는 수정되지 않았으므로 현재 branch에서
  `rhwp_image_data`를 호출하면 같은 use-after-free 가능성이 남아 있다.
- mutable pointer 반환은 machine ABI representation을 유지하지만 generated
  header와 Swift imported type이 함께 갱신돼야 한다.
- `Box<[u8]>`로 넘긴 allocation을 기존 `rhwp_free_bytes`가 정확한 length로
  해제하는지 Stage 2 unit test와 Stage 3 artifact test가 필요하다.
- `imageDataLength`는 길이 확인을 위해 lazy bytes 전체를 load한다. 이 타스크는
  별도 metadata ABI를 추가하지 않으며 실제 memory 문제가 확인되면 후속
  이슈로 분리한다.
- Rust/Swift source test 통과만으로 Finder extension crash 해결을 확정할 수
  없다. Stage 4 exact-provider package smoke와 신규 crash report 부재가
  최종 제품 gate다.
- v0.1.9 tag와 draft release 처리 전략은 #441 이슈 소유이며 Stage 1에서
  변경하지 않았다.

## 다음 단계 영향

Stage 2 범위는 `RustBridge/src/lib.rs` 하나와 단계 문서로 제한한다.

1. `rhwp_image_data`를 caller-owned mutable pointer 반환으로 전환한다.
2. out length를 진입 시 0으로 초기화하고 panic을 null/0으로 격리한다.
3. non-empty Vec를 `Box<[u8]>` allocation으로 넘긴다.
4. `복학원서.hwp` 기반 invalid/repeated/allocator-pressure/handle-close test를
   추가한다.
5. 전체 locked Rust test를 통과시킨다.

Stage 2에서는 Swift caller, generated header, `rhwp-core.lock`, README와
architecture 문서를 아직 변경하지 않는다. 이 변경은 Stage 3에서 regenerated
XCFramework와 함께 원자적으로 검증한다.

## 승인 요청

Stage 1 조사와 구현계획을 승인하고, 구현계획서의 Stage 2
`RustBridge owned image buffer와 unit test`에 진입할지 승인 요청한다.

Stage 2 승인 전에는 `RustBridge/src/lib.rs`를 수정하거나 Rust artifact를
재생성하지 않는다.
