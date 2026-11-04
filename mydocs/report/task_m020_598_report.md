# Task M020 #598 최종 결과보고서

작성일: 2026-11-04. 작업지시자가 최종 보고서 작성·PR 게시 진행을 승인했다.

## 작업 요약

- 이슈: [#598 HFT 대응 설치 OTF/TTF 공급 진단 및 공식 릴리스 반영 전 회귀 검증 준비](https://github.com/postmelee/alhangeul-macos/issues/598)
- 마일스톤: M020 / 글꼴 마이그레이션. 4단계 준비 완료. 작업 `local/task598`, 게시 `publish/task598`, PR base `devel`.
- 후속 진입점: [공식 릴리스 재개 인계](../tech/task_m020_598_release_handoff.md). 다음 공식 upstream 반영 및 알한글 릴리스 요청 시 이 문서부터 재개한다.
- 제품 기준은 `f64f6101863777e2bd49c2336e5e4fd967b4da6e`, core/Studio/matcher는 `v0.8.7`, `1a76570e833917d15817415a53c09ad61ab3203f`로 유지했다. upstream 패치 선반영·제품 로직 변경·공개 릴리스는 수행하지 않았다.

`~/Library/Fonts`는 경로 자체가 빠진 문제가 아니며, 실제 사용자 폴더의 OTF/TTF 5개를 제품 공급 계층으로 읽고 원본 bytes와의 일치를 확인했다. 제보 대상은 HFT 원본에 대응하는 설치 글꼴의 선택 순서 문제로 구체화됐다. 실제 딸기 파일은 미확보이므로 제보 해결을 확정하지 않는다.

| 단계 | 완료 내용 | 커밋 |
|------|-----------|------|
| [Stage 1](../working/task_m020_598_stage1.md) | 공급 계약·자산·진단 결과 형식 확정 | `bd3d6498` |
| [Stage 2](../working/task_m020_598_stage2.md) | 실제 Swift 공급과 제품 JS adapter를 연결한 격리 진단·회귀 구현 | `c222ac81` |
| [Stage 3](../working/task_m020_598_stage3.md) | clean 재실행·실제 사용자 Fonts·Rust/Studio·원본 문서 기준 보존 | `fdc51e8e` |
| [Stage 4](../working/task_m020_598_stage4.md) | 공식 tag 포함 검증부터 앱 릴리스까지 재개 인계 | `dcfc1767` |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| [Tests/HFTFontSupplyProbe/main.swift](../../Tests/HFTFontSupplyProbe/main.swift) | 격리 catalog/library/supply/session을 호출하는 JSON-lines 서버. fixture와 실제 설치 이름 필터 모드 |
| [scripts/ci/hft-font-supply-adapter.cjs](../../scripts/ci/hft-font-supply-adapter.cjs) | 제품 provider 원문 실행, bytes hash·signature·음성 대조·세대 변경 검사, 판정/민감 필드 검증 |
| [scripts/probe-hft-font-supply.py](../../scripts/probe-hft-font-supply.py) | provenance 확인, CLI 컴파일·실행, 새 출력 경로 보호·시간 제한·임시 상태 정리 |
| [Node 계약 테스트](../../scripts/ci/test-hft-font-supply.cjs), [Python 실행기 테스트](../../scripts/test-hft-font-supply-runner.py) | 허위 통과·민감 필드·서버 시작 실패·경로 이탈·덮어쓰기·준비 실패 대조 |
| [Studio probe](../../Tests/StudioFontIntegrationProbe/main.swift), [실행기](../../scripts/probe-studio-font-integration.py) | 설정 창 캡처만 명시 생략하는 옵션과 PASS/FAIL/NOT_RUN 집계. 기본 캡처·글꼴 기능 검사는 유지 |
| [probe README](../../Tests/HFTFontSupplyProbe/README.md), [공급 계약](../tech/task_m020_598_font_supply_contract.md), [인계](../tech/task_m020_598_release_handoff.md) | 실행 환경·판정 한계·후속 버전 반영/수용 순서 |
| [수행계획](../plans/task_m020_598.md), [구현계획](../plans/task_m020_598_impl.md), 단계 보고·[오늘할일](../orders/20261104.md) | 승인 범위·단계 결과·완료 상태 기록 |
| `mydocs/working/assets/task_m020_598/` | 경로·상용 bytes를 제외한 JSON·로그·hash·관측 재실행 스크립트. [Stage 3 실행 인덱스](../working/assets/task_m020_598/stage3/run-index.json)에서 탐색 |

`Sources/`, `RustBridge/`, `rhwp-core.lock`, `project.yml`과 bundled Studio/WASM·matcher는 제품 기준 대비 무변경이다. 실제 폰트·문서·SVG 원문은 Git에 추가하지 않았다. 별도 사용자 OS 설치/삭제/등록·실제 앱 설정 변경·인증서 사용·Finder extension 등록을 하지 않았다. 시험 앱 2개와 fixture 상태 3개는 검증 후 정리했다.

## 변경 전·후 정량 비교

| 항목 | 준비 전 | 준비 후 |
|------|---------|---------|
| provider/bootstrap 및 새 계약 Node 회귀 | 기존 22개 | 기존 22 + 신규 5 = 27 PASS |
| 전용 Python 출력/실패 계약 회귀 | 전용 검사 없음 | 5 PASS |
| 전용 Swift↔JS 공급 진단 | 없음 | 10개 합성 시나리오, 67 PASS / 0 FAIL / 문서 단계 30 NOT_RUN |
| 이 타스크의 실제 사용자 Fonts 공급 증거 | 없음 | OTF 1 + TTF 4, descriptor 위치·ID 및 bytes hash 대조 |
| 이 타스크의 Studio 변경·재열기 기준 | 없음 | 기능 40 PASS + 저장 재열기 6개 항목 PASS; 설정 창 캡처 6 NOT_RUN |
| 후속 재개 문서 | 없음 | 기준 커밋·자산 hash·명령·미검증·공식 반영 및 릴리스 순서 1개 진입점 |

테스트 수 증가는 제품 지원 범위 증가를 뜻하지 않는다. HFT 해석기·별도 치환표·OTF 우선 resolver는 추가하지 않았다.

## 검증 결과

| 수용 기준 | 판정 | 근거 |
|-----------|------|------|
| 현재 core/Studio 유지 | OK | baseline 대비 제품 소스·고정 자산 diff 없음 |
| 실행 가능한 공급 진단과 실패 구분 | OK | Stage 2의 Node 27개·Python 5개, compile, 양성/음성 대조. exit 0/1/2 및 NOT_RUN 구분 |
| clean 커밋 재실행 | OK | `c222ac81`에서 Stage 2와 cases·summary·provenance 동일. [비교 증거](../working/assets/task_m020_598/stage3/comparison.json) |
| 실제 사용자 경로 공급 | OK | host CLI의 Pretendard/Hack 5개, [위치 대조](../working/assets/task_m020_598/stage3/user-font-locations.json)와 [원본 hash](../working/assets/task_m020_598/stage3/asset-audit.json) |
| Rust/core 연결 기준 | OK | arm64/x86_64 portable build, source/Cargo.lock/header/FFI 검증. strict archive byte 비교 제외 |
| 기존 Studio 기능·재열기 | OK | [기능 요약](../working/assets/task_m020_598/stage3/studio/summary.json): 40개 및 저장 재열기 6개 항목 |
| 원본 문서 기준 관측 | OK | HWP3/HWPX 입력 hash·HFT 선언, bundled WASM 첫 SVG의 재실행 hash 일치. 실제 폰트 선택은 검사하지 않음 |
| 인계의 완결성 | OK | 기준·명령·자산·공식 tag 확인·matcher 동기화·native/PDF/인쇄/Finder 수용·릴리스 운영 순서 명시 |
| 실제 딸기/HFT 해결·독립 PDF 비교 | MISS | 실제 문제 글꼴과 독립 PDF 미확보. 공개 해결 주장 불가 |
| 설정 창 캡처 전체 수용 | MISS | 기본 모드 두 차례 ScreenCaptureKit -3811. 기능 실행에서 캡처 6건을 명시 NOT_RUN 처리 |
| 실제 sandbox·OS 변경·출력별 수용·최소 OS/Intel 실행 | MISS | 이번 사전 준비의 후속 범위. universal build나 합성 refresh로 대체 판정하지 않음 |

공급 목록 0건은 실행 환경에 따라 달랐다. 제한된 도구에서는 존재하는 사용자 폰트도 0건이었고, 같은 사용자의 제한 밖 CLI에서는 정상 공급됐다. 이 차이는 제품 App Sandbox의 성공/실패 증거가 아니다. 실제 딸기 관련 이름은 제한 밖에서도 조회되지 않았다.

최종 게시 전 최신 `origin/devel`이 제품 기준과 같고 중복 게시 브랜치·PR이 없는 것을 확인했다. 문서 링크·shell 예제 구문·보존 결과 hash/수치·단계 보고 존재·공개 본문 형식을 검사한다. 최종 단계는 문서만 바꾸므로 앞서 통과한 공급/Studio 검사를 재실행하지 않는다. PR CI 결과는 게시된 PR에서 확인하며 이 보고서의 로컬 검증과 구분한다.

## 잔여 위험과 후속 작업

1. 다음 공식 tag에 upstream #8397 수정과 후속 보완이 실제 포함됐는지 확인하고, core/Studio/WASM/matcher를 동일 resolved commit으로 갱신한다. 현재 자동 sync에 native matcher 재생성 명령이 명시돼 있지 않은 점을 확인한다.
2. 권한 있는 실제 딸기 OTF/TTF와 독립 PDF를 확보해 원본 HWP3/HFT HWPX의 실제 선택·측정·글리프·줄바꿈·출력을 대조한다. 현재 sample10 pageCount 763과 SVG family 목록은 관측값이며 정답이 아니다.
3. native bridge의 layer tree 생성 후 run family 수집과 upstream 조판 전 공급 계약을 검토한다. signed sandbox·OS 알림·PDF/인쇄/Finder·최소 OS/Intel 수용을 수행한다.
4. 설정 창 캡처 -3811을 별도 재검증한다. 명시 생략 옵션은 캡처 오류 수정이 아니다. NativeFontSupplyProbe의 임시 자산·process 등록 전제도 재구성 후 사용한다.
5. 실제 upstream 반영과 알한글 새 릴리스는 후속 요청에서 인계 문서를 따라 진행한다. 이번 PR은 준비 작업이며 배포를 포함하지 않는다.

## 작업지시자 승인 요청

사전 준비 완료 결과를 `publish/task598`에서 `devel` 대상으로 Open PR 게시한다. 게시 후 리뷰·merge 판단을 요청하며 자동 merge는 하지 않는다. 이슈는 준비 범위의 merge 확인 또는 별도 승인 전까지 열린 상태로 둔다. 공식 upstream 반영과 알한글 새 릴리스는 별도 후속 지시로 재개한다.
