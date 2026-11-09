# Task M020 #598 Stage 2 완료 보고

작성일: 2026-11-03. [구현계획](../plans/task_m020_598_impl.md). 작업지시자의 Stage 2 진행 승인 범위에서 수행했다.

## 단계 목적

현재 공식 core/Studio를 유지하면서 제품 공급 계층을 호출하는 격리 진단 도구를 만든다. 후보·bytes·실패·세대 무효화를 재현하고 HFT 문서의 실제 선택·조판·출력과 구분해 기록한다.

## 산출물

- [Swift CLI](../../Tests/HFTFontSupplyProbe/main.swift): 실제 catalog/library/supply/session 연결, 10개 합성 대조 및 대상 이름에 한정한 실제 설치 모드.
- [Node adapter harness](../../scripts/ci/hft-font-supply-adapter.cjs): 제품 JavaScript 원문 실행, bytes hash·signature, 오류 코드, 구독 통지·이전 revision 거부, 판정 집계.
- [Python 실행기](../../scripts/probe-hft-font-supply.py): 입력 provenance 검증, Swift 컴파일, 프로세스 시간 제한, 새 출력 경로 보호, 임시 상태 제거, 실패 보고.
- [결과 계약 테스트](../../scripts/ci/test-hft-font-supply.cjs), [실행기 테스트](../../scripts/test-hft-font-supply-runner.py): 미검증/실패 집계, 잘못된 증거·요약·민감 필드 거부, 서버 시작 실패, 출력 덮어쓰기·symlink 방지, 준비 실패의 결과 보존.
- [실행 README](../../Tests/HFTFontSupplyProbe/README.md), [진단 계약](../tech/task_m020_598_font_supply_contract.md) 확정.
- 비민감 실행 증거: [합성 결과](assets/task_m020_598/stage2/fixtures-result.json), [실제 대상 조회 결과](assets/task_m020_598/stage2/installed-result.json), [Node 로그](assets/task_m020_598/stage2/node-tests.log), [Python 로그](assets/task_m020_598/stage2/runner-tests.log).

## 본문 변경 정도 / 본문 무손실 여부

제품 Sources/RustBridge, core lock, Studio 번들, 생성 matcher 및 project.yml을 변경하지 않았다. 사용자 OS 글꼴·앱 설정·보관함·원본 문서는 수정하지 않았다. 인증서 사용·별도 codesign·Finder 등록을 수행하지 않았다. 테스트용 CLI 컴파일과 격리 보관함을 사용했다. 글꼴 bytes는 pipe 메모리로 전달하고 영구 결과에 저장하지 않았다.

## 검증 결과

저장소 루트에서 실행했다. 아래 출력 디렉터리는 이미 존재하므로 재실행에는 새로운 이름을 사용한다.

```bash
node --test scripts/ci/test-hft-font-supply.cjs \
  scripts/ci/test-studio-font-provider.cjs scripts/ci/test-studio-font-bootstrap.cjs
python3 scripts/test-hft-font-supply-runner.py
python3 scripts/probe-hft-font-supply.py --mode fixtures \
  --output-dir build.noindex/task598/stage2/fixtures-03
python3 scripts/probe-hft-font-supply.py --mode installed --family '딸기' \
  --output-dir build.noindex/task598/stage2/installed-02
git diff --check
git diff --exit-code f64f6101863777e2bd49c2336e5e4fd967b4da6e -- \
  Sources RustBridge rhwp-core.lock project.yml
```

- Node: **27 PASS / 0 FAIL / 0 skipped**. 기존 provider/bootstrap 22개와 새 계약·서버 시작 실패 검사 5개.
- Python: **5 PASS**. 출력 경로 4개와 준비 실패 보고 1개.
- Swift: `-warnings-as-errors`, `-swift-version 5`, 현재 arm64의 macOS 12 target으로 컴파일·실행 성공. 두 실행의 compile.log는 비어 있다. 최소 OS 실행 검증은 아니다.
- fixtures: **67 PASS / 0 FAIL / 30 NOT_RUN**, 종료 0, `supplyComplete=true`, `complete=false`. 문서 selection/layout/render 각 10건은 미실행이다.
- installed 딸기: raw/candidate 0건. **3 PASS / 0 FAIL / 4 NOT_RUN**, 종료 2, `supplyComplete=false`. 후보 미확보와 selection/layout/render 미실행을 구분했다. 실제 파일 읽기 성공 증거는 없다.
- 입력 6개 fixture hash 및 core/Studio/matcher commit 일치, matcher source hash 일치. 기준은 계속 `v0.8.7`, `1a76570e833917d15817415a53c09ad61ab3203f`다.
- 결과의 실행 HEAD는 Stage 1 커밋 `bd3d6498bad5f17dbdbf31f4b54b141281a931f4`, `dirty=true`다. 이번 단계의 미커밋 구현으로 실행했으며 결과의 `inputHashes`가 최종 도구·제품 소스와 일치함을 별도로 확인했다.
- 정상 종료 후 private-state 제거, 결과에 원본 절대 경로·bookmark·bytes 미포함을 확인했다. `git diff --check` 및 baseline 대비 제품 무변경 검사를 통과했다.

| 합성 시나리오 | raw / 후보 | 확인 결과 |
|---------------|------------|-----------|
| TTF / OTF | 각 1 / 1 | TTF `00010000`, CFF OTF `4f54544f`, fixture·native·전송 bytes hash 일치 |
| 양쪽 | 2 / 2 | 각 face bytes 공급. 서로 다른 PS의 fixture이며 HFT 원본 대응 쌍의 선택 검사 아님 |
| 없음 | 0 / 0 | bytes 미공급 |
| Book / 빈 style | 각 1 / 0 | 기존 adapter 제외 정책 유지 |
| 권한 / 손상 | 각 1 / 1 | 주입한 permissionDenied / corrupt를 정확히 반환, 정상 bytes 반환 없음 |
| 동일 PS 충돌 | 2 / 0 | raw limitation=conflict, 공급 후보 제외 |
| 관리 우선 | 2 / 1 | 관리 후보 우선, 한글 name table 별칭 전달 |

모든 합성 사례에서 refresh의 provider 구독 통지와 revision 변경을 확인했다. 기존 후보가 있는 사례는 이전 revision read의 staleGeneration 거부도 확인했다. 이는 OS 변경 감지나 실제 문서 재조판 검사가 아니다.

## 잔여 위험

실제 문제 글꼴이 없어 제보 자체는 재현하지 못했다. 영문으로 주입한 설치 metadata에 한글 별칭이 없다는 대조를 실제 딸기 글꼴의 별칭 결함으로 일반화하지 않는다. 실제 설치 모드의 성공적인 read, sandbox 권한, WKWebView·loadToken handler, upstream 선택, native/PDF/인쇄/Finder 출력은 미검증이다. 실제 읽기 오류가 발생하면 정상 공급 FAIL로 기록하며 HFT 예상 제한으로 낮추지 않는다.

## 다음 단계 영향

Stage 3에서 이번에 커밋한 도구를 새 프로세스로 재실행해 현 버전 기준 결과를 고정한다. 합성 공급과 실제 자산/환경 미확보를 나누고, 가능한 소비자 검사의 전제를 확인한다. framework 부재를 숨기거나 실제 자산 없는 문서 검증을 성공으로 표시하지 않는다. 공식 릴리스 이후 재개 문서는 Stage 4에서 작성한다.

## 승인 요청

Stage 2 결과 검토와 Stage 3 진입 승인을 요청한다. Stage 3에서도 core/Studio 갱신이나 공개 릴리스는 수행하지 않는다.
