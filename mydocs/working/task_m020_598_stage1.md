# Task M020 #598 Stage 1 완료 보고

작성일: 2026-11-03. [구현계획](../plans/task_m020_598_impl.md).

## 단계 목적

현재 core/Studio를 유지한 채 글꼴 공급 경계를 조사하고, 실제 재현 자산·실행 전제·Stage 2 최소 진단 구현 범위를 확정한다.

## 산출물

- [글꼴 공급 진단 계약](../tech/task_m020_598_font_supply_contract.md): metadata/후보/bytes/consumer 경계, 자산 표, CLI·결과 JSON·판정 계약, 후속 검증.
- [자산·provenance 해시](assets/task_m020_598/stage1/assets.json).
- [CoreText 대상 조회 코드](assets/task_m020_598/stage1/active-fonts.swift)와 [결과](assets/task_m020_598/stage1/active-fonts.json): 실제 활성 metadata만 읽고 경로·bytes를 출력하지 않음.
- [Node 회귀 로그](assets/task_m020_598/stage1/node-tests.log): 제품 adapter/bootstrap 테스트 22개.
- 수행/구현계획과 오늘할일의 승인·Stage 1 완료 상태 갱신.

## 본문 변경 정도 / 본문 무손실 여부

제품 Sources/RustBridge, core lock, Studio 번들 및 matcher는 변경하지 않았다. 원본 문서·사용자 글꼴·OS 설치/활성 상태·앱 설정·권한은 변경하지 않았다. 재현 문서와 상용 글꼴을 Git에 추가하지 않았다. 진단용 Swift 스크립트와 문서·비민감 결과만 기록했다.

## 확인한 사실

1. 설치 별칭은 CoreText family/full/PS이고 관리 별칭은 name table 1/4/6/16이다. 실제 대상의 한글 별칭 누락 여부는 미확정이다.
2. 설치 Book/빈 style은 adapter 후보에서 제외된다. 기존 계약 테스트로 확인된 제한이며 실제 제보 원인으로 단정하지 않는다.
3. OTF/CFF 검사·공급 경로가 이미 있다. 모든 상용 글꼴 통과 또는 정확한 렌더링을 보장하지 않는다.
4. 원본 sample10 HWP와 변환 HWPX가 로컬 upstream checkout에 있다. HWPX font ID 3에 딸기/HFT/nonembedded 선언을 확인했다.
5. 확인한 두 로컬 경로에는 독립 한컴 PDF가 없다. 현재 unsigned CLI의 CoreText 활성 metadata에서 딸기/Strawberry/HGSTRB 일치 0건이다. 실제 앱 sandbox와 Mac 전체 설치 부재 판정이 아니다.
6. 현재 native bridge는 layer tree 생성 뒤 run family를 수집한다. 향후 HFT 조판 전 공급 계약 확인이 필요하다.
7. 이번 단계에서 확정된 제품 결함은 없으며 Stage 2 제품 로직 변경은 제안하지 않는다.

## 검증 결과

- `node --test scripts/ci/test-studio-font-provider.cjs scripts/ci/test-studio-font-bootstrap.cjs`: 22 PASS, 0 FAIL, 0 skipped.
- Fixtures/SHA256SUMS의 6개 파일 해시 일치.
- Studio manifest와 matcher receipt commit 일치, 생성 matcher source hash와 receipt outputSHA256 일치.
- HWP 945360 bytes, HWPX 847607 bytes의 SHA256 기록. ZIP header.xml 파싱으로 HFT 선언 확인. 문서 렌더·PDF 확대 판독은 실행하지 않음.
- `swift -module-cache-path build.noindex/task598/stage1/modules mydocs/working/assets/task_m020_598/stage1/active-fonts.swift`: 대상 일치 0건. 최초 실행은 같은 내용의 build.noindex 내 사본을 사용했다.
- 환경: macOS 26.5.2 (25F84), arm64, Swift 6.3.3, Node 24.15.0, Python 3.9.6, xcodegen 존재.
- 새 worktree의 framework/static archive 부재 확인. 존재 검사 ls의 exit 1은 준비 상태를 나타내며 테스트 실패로 집계하지 않는다. Rust/HostApp build 및 signed sandbox/Finder 검증은 실행하지 않음.
- 문서 링크·결과 JSON 검사, `git diff --check`, baseline 대비 core/Studio/matcher 무변경 검사 통과.

## 잔여 위험

실제 딸기 파일·독립 PDF가 확보되지 않아 제보 자체의 시각 재현은 미검증이다. 현재 활성 목록 0건은 앱 문제를 반증하지 않는다. 전체 설치 폴더나 다른 앱 자산을 광범위하게 읽지 않았다. 향후 최소 지원 OS/Intel·실제 sandbox·OS 변경 이벤트·출력별 선택 증거는 별도 수용한다.

## 다음 단계 영향

Stage 2는 **제품 변경 없는 Swift CLI + 제품 JavaScript adapter 실행 harness**로 한정한다. framework 없이 공급 경계를 검사하고 기존 합성 fixture를 사용한다. 상세 파일·예정 CLI와 schema v1은 진단 계약에 확정했다. 실제 설치 모드는 대상 이름만 필터링하고 비존재를 NOT_RUN으로 보고한다. 미지원/충돌을 임의 해제하거나 OTF 우선 선택 로직을 앱에 복제하지 않는다.

## 승인 요청

Stage 1 조사 결과와 위 Stage 2 최소 구현 범위 승인을 요청한다. Stage 2 진입 전 제품 소스 변경은 없으며, 이후 별도 제품 수정 필요가 확인되면 원인·수정안을 다시 제시한다.
