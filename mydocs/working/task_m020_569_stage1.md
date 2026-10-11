# Task M020 #569 Stage 1 — Mac 지원 범위·Finder 측정 계약 확정

- 일자: 2026-10-10, 작업 `local/task569`.
- 승인: 구현계획 제시 후 작업지시자의 “진행해줘”로 구현계획 및 Stage 1 시작을 승인받았다.
- 검토 head: `09b69736`, 제품 기준 `dac73a589dc17143e744da6a12a51d638a81fb77`.
- 결과: Stage 1 완료. 기존 증거·자산 대조와 다음 측정 계약이며 새로운 제품/성능/signed 수용 결과는 아니다.

## 1. 단계 목적

Mac 로컬 글꼴 선출시의 지원 범위를 소비자별로 정리하고, Finder 반복 요청의 metadata 비용을 과장하거나 cache hit에 가려진 비용을 놓치지 않도록 측정 경계를 확정했다. 같은 출시 후보의 Mac 수용과 Windows 후속, signed probe와 최종 배포 DMG smoke를 구분한다.

## 2. 산출물

| 파일 | 내용 |
|------|------|
| [Mac 출시 수용 기준](../tech/task_m020_569_mac_acceptance.md) | 현재 소비자별 실제 원본/환경/지원, 이번 후보의 미검증 행·필수 동선·후보/복원·release 인계 |
| [Finder 측정 계약](../tech/task_m020_569_finder_performance.md) | 현재 scan→snapshot→bitmap cache 순서, 시간 구간/입력·반복 수·집계·정확성·개선 판단 |
| [대조 영수증](assets/task_m020_569_stage1/evidence-audit.json), [검증 요약](assets/task_m020_569_stage1/validation-summary.json) | 소스·보존 증거·signed checksum·PDF·원본·lock/산출물과 현재 fixture hash 대조 |
| [문서 검증](assets/task_m020_569_stage1/document-validation.log), matcher/Studio/no-AppKit 로그 | 실행한 작은 무변경 검증의 결과 보존 |
| 수행/구현계획·오늘할일 | 승인 이력·Stage 1 완료·Stage 2 진입 범위 갱신 |

## 3. 본문 변경·기존 내용 보존

기술 계약 2개와 본 보고서·선별 evidence는 신규 작성이다. #569 수행/구현계획의 승인/현재 상태와 오늘할일의 #569 행만 보정했다. 기존 #568 지원 근거·보고서·자산은 수정하지 않았다. 제품·웹·Rust/ABI·프로젝트·lock은 바꾸지 않았다. 원본 font bytes·앱/DMG는 커밋하지 않는다.

## 4. 검증 결과

| 검증 | 결과 | 의미 |
|------|------|------|
| signed Finder source provenance | **125개 전부 hash 일치** | 현재 제품 입력과 과거 compiled source의 정합성. 새로운 signed binary 검증 아님 |
| #568 선별 evidence | **61개 hash/길이 일치** | 보존한 기존 증거가 바뀌지 않음 |
| Stage 5 `SHA256SUMS` | **26개 일치** | signed 결과·그림·복원/정리 증거 유지 |
| Stage 3 저장/인쇄 PDF | **12개 기존 hash와 일치하는 파일 보존 확인** | 이번에 PDF를 생성·추출·검색/인쇄한 결과로 확대하지 않음 |
| Gowun OFL 원본 | **TTF 2개·OFL·METADATA 4개 길이/hash 일치** | 원본 출처/face 입력을 재사용 가능. 사용자 OS 설치/변경 없음 |
| 문서 fixture | **HWP/HWPX/2페이지 HWPX 3개 현재 hash 기록** | 다음 실행의 고정 입력. 새 실행의 pageCount는 Stage 2에서 확인 |
| core/Studio | **lock·header/archive 3개, manifest/adapter 2개 hash 일치** | 기존 provenance 유지; 새 빌드나 core 갱신 아님 |
| 과거 metadata 재집계 | **32건, 최소 453.637875 / 중앙값 1089.7723335 / 최대 2949.453667ms** | 기존 signed snapshot 시간과 일치. 새 성능/실행시간 아님 |
| `node scripts/build-native-font-matcher.mjs --verify` | **OK: native matcher receipt** | 생성 matcher source/receipt 정합성 |
| `bash scripts/verify-rhwp-studio-assets.sh` | **adapter receipt·assets OK** | bundled Studio 정합성 |
| `bash scripts/check-no-appkit.sh` | **OK** | 공유 Swift의 AppKit/UIKit 금지 유지 |
| 문서/작업 범위 검증 | **PASS**, `git diff --check` 통과 | 문서 구조·한국어·링크·영수증 복사 정합성, 제품/웹 변경 없음 |

전체 빌드·Swift/Rust/JS suite·실제 글꼴 scan·새 렌더·GUI·서명·설치·등록·공개 배포는 수행하지 않았다. 변경 없는 소스를 확인하기 위해 같은 큰 시험을 반복하지 않았다. 새 실행 환경은 `uname -m`/`sw_vers -productVersion`으로 arm64/macOS 26.5.2를 확인한 범위다.

## 5. 발견 사항과 잔여 위험

- Thumbnail은 공급 metadata 준비 후 bitmap cache를 조회한다. 반복 hit에서도 전체 목록/원본 stat 비용이 남을 수 있으며 현재 단계에서 개선 필요성과 출시 성능을 확정하지 않는다.
- 기존 `metadataMs`에는 내부 준비/async 비용이 섞이고 호출 전 actor 대기는 빠진다. `renderMs`나 OS 화면 응답과 혼동하지 않도록 별도 단조 구간과 scan 횟수를 계약에 넣었다.
- 기존 unsigned probe는 빈 설치 목록을 주입한다. 실제 CoreText scan을 감싼 별도 probe가 필요하다. OFF도 같은 실제 서비스를 호출하여 OFF 준비 비용을 숨기지 않는다.
- 요청 ID로 대응되지 않는 signed 동시 로그는 개별 metadata/전체 시간 비율을 추정하지 않는다. OS cache가 호출을 생략하면 미호출로 기록한다.
- #568 전용 signed helper는 고정 경로/fixture guard가 있다. #569에 무단 재사용하지 않고 새 실행 root·UUID·backup/복원 contract를 준비한다. 삭제된 과거 앱을 이미 준비된 후보로 취급하지 않는다.
- macOS 12/Intel 실제 실행·실제 한컴 설치/제거·물리 출력·Windows 입력은 미검증이다. 같은 최종 후보의 Mac 전체 수용도 Stage 4 및 release 운영에 남아 있다.

## 6. 다음 단계 영향과 부산물

Stage 2는 실제 CoreText 환경을 감싼 격리 probe·측정 집계와 필요한 최소 진단을 구현한다. warm/cache hit·OFF/ON·고유 10개 문서·동시 4건과 변화/복구를 분리하며 준비/총시간·scan/read·실제 cache/face를 함께 기록한다. 재현된 비용이 있으면 구조 변경을 독립 성능 이슈/계획으로 인계한다.

이번 새 산출물은 작은 JSON/로그와 문서뿐이다. 앱/확장·DMG·compile cache·사용자 글꼴·App Group 시험 영역을 만들거나 등록하지 않았다. `build.noindex/task569/stage1/`의 원본 audit/log와 선별 tracked evidence를 다음 단계에 보존한다.

## 7. 승인 요청

**Stage 2 격리 성능 probe 구현·반복 탐색 측정·개선 판단**의 시작 승인을 요청한다. 실제 signed Finder 측정은 앱·고유 fixture·백업/복원 계획이 준비된 시점에 해당 구체 범위를 확인한다. 새 성능 구조 구현·core/ABI·공개 release/Pages는 이 승인에 포함시키지 않는다. Mac 부분 준비를 Windows #566 또는 #569/#562 전체 완료로 처리하지 않는다.
