# Task M020 #598 구현계획서

- 이슈: [#598](https://github.com/postmelee/alhangeul-macos/issues/598)
- 수행계획: [task_m020_598.md](task_m020_598.md), 2026-11-03 작업지시자 승인.
- 작업 브랜치: `local/task598`, 통합 대상: `devel`
- 기준: `f64f6101863777e2bd49c2336e5e4fd967b4da6e`; core/Studio 공식 `v0.8.7`, `1a76570e833917d15817415a53c09ad61ab3203f`.
- 상태: 2026-11-04 사전 준비 4단계·[최종 보고](../report/task_m020_598_report.md)·[재개 인계](../tech/task_m020_598_release_handoff.md) 완료. 최종 보고·PR 게시 승인됨. merge·실제 릴리스 후속.

## 구현 원칙과 완료 경계

이번 작업은 차기 공식 릴리스 전 공급 진단·회귀 도구·인계를 완료한다. HFT 파일 디코딩이나 원본 대응 OTF/TTF 선택 알고리즘을 새로 구현하지 않는다. core pin, Rust dependency/lock, Studio/WASM 번들, 생성 matcher와 receipt는 유지한다. 제품 결함 수정은 Stage 1에서 재현 및 최소 변경안을 제시하고 승인된 범위에 한정한다.

준비 완료는 실제 HFT 문서의 선택·재조판·출력 해결 또는 공개 배포 완료가 아니다. 실제 자산이 없으면 실행 가능한 합성 공급 계약과 실제 재현 미검증을 명확히 분리한다. 준비 완료 후 공식 릴리스 대기는 후속 인계에 기록하고, 다음 사용자 지시 없이 릴리스 감시·배포를 시작하지 않는다.

## 기존 도구와 확장 지점

| 기존 요소 | 재사용 방법 | 한계 |
|----------|------------|------|
| FontLibraryTests Fixtures | regular/bold TTF, CFF OTF, language-tag TTF 및 해시 사용 | 직접 만든 3개 glyph만 포함. 실제 딸기 모양이나 품질 증거가 아님 |
| Node provider/bootstrap 테스트 | 제품 Swift raw string을 직접 실행하여 후보 제외·충돌·전송·세대 무효화 검증 | 실제 CoreText 열거·WKWebView 조판을 입증하지 않음 |
| InstalledFontSystem/StudioFontSupply | 활성 metadata, 선택된 파일의 검사·bytes, 설치/관리 별칭 비교 | 별칭의 실제 누락 여부는 대상 글꼴로 확인 필요 |
| StudioFontIntegrationProbe | 고정 번들·제품 Coordinator·격리 공급, changes 모드의 재시작 검증 재사용 | 합성 설치 상태는 OS 설치 이벤트와 다름 |
| StudioFontAcceptanceProbe | 실제 설치 글꼴·서명 sandbox의 후속 진입점 | 현 도구는 NanumSquare 중심, CoreText 변경 알림 감시를 끔. 인증서 별도 승인 필요 |
| NativeFontSupplyProbe | 기존 matcher/bytes/native 공급 회귀 | arm64 고정 helper와 framework 전제 확인 필요. HFT 조판 전 공급 완료를 의미하지 않음 |

## Stage 1 — 공급 계약·자산·진단 명세 확정

작업:

1. 현재 lock/manifest/생성 matcher receipt의 SHA와 작업 소스를 고정하고, 별도 worktree의 framework·도구 준비 상태를 확인한다. 다른 타스크의 generated framework를 출처 확인 없이 복사하지 않는다.
2. 설치 metadata → StudioFontSupply 별칭 → adapter normalize/select → session openFace/readChunk → consumer 연결을 추적한다. 스타일 제외, 한글 별칭, 관리 우선, 동일 PostScript 충돌을 후보와 확정 사실로 구분한다.
3. upstream sample10 HWP, HFT 선언 변환 HWPX, 독립 한컴 PDF와 사용 가능한 문제 글꼴을 관련 로컬 자산/공식 참조 범위에서 확인한다. 시스템 변경 없이 필요한 파일만 읽는다. 확보되지 않은 자산은 필요한 출처·이름·형식과 함께 미확보로 기록한다.
4. 아래 진단 결과 계약과 검증표를 확정하고 기존 probe 확장 또는 전용 unsigned CLI 중 최소 구현을 선택한다. API 호출이나 글꼴 이름을 바꾸는 우회는 하지 않는다.
5. 기본 Node 회귀를 실행한다. 제품 로직 수정은 하지 않는다. 공급 결함이 발견되면 Stage 2 파일·변경안과 검증을 구체화하여 승인받는다.

산출물: `mydocs/tech/task_m020_598_font_supply_contract.md`, `mydocs/working/task_m020_598_stage1.md`. 자산 원문은 필요·권리 확인 전 Git에 추가하지 않는다.

완료 기준: 경계별 근거, 자산 확보/미확보 표, 실제/합성 검사 구분, Stage 2 최소 변경 범위가 구체적이어야 한다.

커밋: `Task #598 Stage 1: 글꼴 공급 진단 계약과 재현 자산 정리`

## Stage 2 — 진단·회귀 도구 구현

작업:

1. 재사용 가능한 TTF/OTF 자산으로 실제 제품 공급 함수를 호출한다. 대상 family 또는 명시 입력을 제한하여 전체 설치 글꼴 bytes를 선읽지 않는다. 외부 원본은 수정하지 않는다.
2. 후보 포함/제외와 사유, 검증 bytes hash/PS/style, 세대 및 요청 결과를 기록한다. 제품 matcher 복제 대신 기존 matcher 또는 provider의 결과를 관측한다. 선택 증거를 얻을 수 없는 renderer는 미검증으로 남긴다.
3. 후보가 없거나 읽기에 실패해도 진단 보고를 남기되, 실행 자체 실패와 예상 대조 결과를 구분한다. 출력 경로·기존 결과 덮어쓰기·원본 경로 노출을 방지한다.
4. 기존 Node 테스트에 한글/영문 별칭·스타일 제외·관리 충돌·복수 후보·갱신 경계의 부족한 사례만 추가한다. 이미 충분한 취소/전송 테스트는 중복 작성하지 않는다.
5. 필요 Swift 테스트는 `Tests/FontLibraryTests/` 또는 격리 probe에 추가한다. 프로젝트 파일은 직접 수정하지 않는다. 앱 제품 변경이 필요하면 승인된 최소 변경만 포함하고 별칭·weight 추정으로 무조건 성공시키지 않는다.

잠정 신규 파일: `scripts/probe-hft-font-supply.py`, `Tests/HFTFontSupplyProbe/main.swift`, 결과 계약 검증용 테스트. 기존 도구 확장으로 충분하면 신규 파일을 만들지 않는다. 최종 경로·CLI는 [Stage 1 진단 계약](../tech/task_m020_598_font_supply_contract.md)에 확정했다. Stage 2는 제품 로직 변경 없이 진단 도구와 회귀 검증만 구현한다.

완료 기준: 양성 공급, 제외·읽기 실패 음성 대조, stale 결과 거부, 결과의 판정 단계·형식 검사가 재현 가능하다. OTF/TTF 우선순위는 앱에서 구현하지 않는다.

커밋: `Task #598 Stage 2: 글꼴 공급 진단과 격리 회귀 도구 준비`

## Stage 3 — 현재 버전 기준 결과·재실행 검증

아래 표를 실제/합성/미검증 표시와 함께 실행한다. 조합 전체의 무조건 곱집합을 만들지 않고 각 경계가 독립적으로 검증되는 최소 사례를 사용한다.

| 대조 | 이번 준비의 판정 | 공식 릴리스 이후 판정 |
|------|----------------|---------------------|
| OTF만 / TTF만 | 각 bytes 검사·공급 성공 또는 정확한 실패 이유 | 원본 대응 face가 실제 선택되고 측정·출력 일치 |
| 양쪽 존재 | 공급 후보·충돌 상태 및 실제 전달 가능성 기록 | upstream 정책에 따른 선택·glyph 공급 확인 |
| 양쪽 없음 | 원본 공급 없음과 fallback을 구분 | 기존 정상 fallback 유지 |
| 한글/영문 이름, Regular/Bold, Book/빈 style | 후보 매칭/제외 이유와 실제 metadata 대조 | 잘못된 face/style 선택 없음 |
| 권한 거부·손상·동명 충돌 | 실제 또는 주입한 실패를 구분하고 bytes 오공급 없음 | 실패 후 안전한 fallback/사용자 상태 |
| 열기 전/후 감지·새 프로세스 | 세대 갱신·재요청·이전 결과 폐기 확인 | 열린 문서 재조판과 재열기 결과 일치 |
| HWP3 / HFT 선언 HWPX | 실제 자산 가용성 및 현 버전 결과 기록 | 원본 이름·실제 글꼴·줄바꿈·독립 PDF 대조 |

원본/출력 hash, 실행 커밋·core/Studio identity, OS/architecture, fixture 종류와 명령을 기록한다. 실제 글꼴이 없으면 테스트를 성공으로 건너뛰지 않고 재현 미검증으로 집계한다. 문서 이름/형식을 바꿔 우회한 결과를 HFT 해결로 기록하지 않는다.

산출물: `build.noindex/task598/stage3/<실행별 디렉터리>/` 및 `mydocs/working/task_m020_598_stage3.md`. 장기 근거는 민감 정보가 없는 최소 JSON/표·해시만 단계 보고서에 연결한다. 임시 절대 경로만으로 후속 재개를 의존하지 않는다.

완료 기준: 현재 기준 결과, 알려진 실패, 환경 미확보가 명시되고 새 프로세스에서 준비 도구를 다시 실행할 수 있다. 정상 공급 회귀 실패를 예상된 HFT 실패로 낮추지 않는다.

실행 보완: 기존 Studio probe의 설정 창 캡처가 ScreenCaptureKit -3811로 반복 실패하여, 테스트에 `--skip-settings-screenshots` 명시 옵션과 캡처 NOT_RUN 집계를 추가했다. 기본 모드·제품·글꼴 기능 검사·WKWebView snapshot은 유지한다. 공급 10개 시나리오 재실행, 실제 사용자 Fonts 5개 공급, Studio 기능 40개·저장 재열기 6개를 검증했고 설정 창 캡처 6개는 별도 미실행이다. 구체 증거·환경 경계는 Stage 3 보고를 따른다.

커밋: `Task #598 Stage 3: 현 버전 공급 회귀와 재실행 기준 기록`

## Stage 4 — 공식 릴리스 이후 인계·최종 준비 보고

`mydocs/tech/task_m020_598_release_handoff.md`에 다음을 기록한다.

- 이슈·준비 최종 commit·계약/단계/최종 보고 링크, 준비 완료와 해결 완료의 차이.
- 입력별 출처·해시·권리·확보 방법, 로컬에만 있는 자산과 없는 자산, 실행 전제.
- 복사해 실행할 수 있는 최종 명령, 실제 output 위치/스키마, 기대값과 알려진 실패 목록.
- 공식 tag의 #8397 포함과 후속 수정 확인. 미포함이면 반영을 보류하며 floating devel로 대체하지 않음.
- core/Studio/WASM/생성 matcher·receipt의 일치 확인과 ABI/Native 조판 전 공급 계약 검토.
- 현재 기준과 새 기준 비교, 실제 Mac sandbox 글꼴, 본문/PDF·인쇄/Finder 각 소비자의 수용 항목.
- 알한글 새 릴리스는 별도 운영 이슈에서 버전·서명·공증·설치·Sparkle·공개를 승인받아 수행.

최종 보고 및 오늘할일에 진입 문서를 연결하고 승인 후 PR/이슈에도 commit 고정 링크로 남긴다. 기존 릴리스 기록에 미래 수정이 출시됐다고 쓰지 않는다. 단계 보고와 최종 보고는 각각 working/report 위치를 따른다.

완료 기준: 다른 대화에서 이슈 번호만으로 준비 결과·명령·잔여 검증을 찾고 공식 릴리스 반영을 재개할 수 있다.

커밋: `Task #598 Stage 4: 공식 릴리스 후 검증 재개 절차 정리`. 최종 보고·게시 절차는 별도 승인으로 수행한다.

## 검증 명령과 실행 전제

모든 명령은 이 worktree 루트에서 실행한다. 새로 구현하는 helper 명령은 Stage 1에서 정하고 최종 인계에는 확정 명령만 남긴다.

```bash
# Stage 1 및 provider 변경 시
node --test scripts/ci/test-studio-font-provider.cjs scripts/ci/test-studio-font-bootstrap.cjs

# 관련 FontLibrary/Swift 공급 변경 시: 기존 suite는 임시 XCTest ad-hoc 서명을 포함한다.
# 서명 실행은 별도 명시 승인 범위에 포함된 경우에만 한다.
bash scripts/test-font-library.sh

# framework가 필요한 검사: 현재 고정 dependency로만 준비, --update-lock 금지
./scripts/build-rust-macos.sh
./scripts/build-rust-macos.sh --verify-portable
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/task598/DerivedData CODE_SIGNING_ALLOWED=NO build

# 기존 제품 WKWebView·격리 변경 회귀 (GUI/현재 framework 필요)
python3 scripts/probe-studio-font-integration.py --changes \
  --output-dir build.noindex/task598/stage3/studio-changes

# 선택적 native 공급 회귀 (helper의 arm64 전제 확인)
python3 scripts/probe-native-font-supply.py --output build.noindex/task598/stage3/native-supply

git diff --check
```

같은 결과를 불필요하게 반복하지 않는다. 문서만 변경한 단계에는 문서 링크·경로·형식 검사를 적용한다. 새 worktree의 framework 부재나 네트워크 실패는 준비 실패로 기록하고 core 호환성 회귀라고 단정하지 않는다. 소스 변경에 필요한 검증을 수행하지 못하면 통과로 처리하지 않고 승인/환경 필요 항목을 보고한다. 실제 인증서 사용이 필요한 acceptance probe와 Finder 등록은 이 명령 목록에 자동 실행 대상으로 포함하지 않는다.

고정 자산 무변경 검사는 baseline과의 `git diff --exit-code f64f6101863777e2bd49c2336e5e4fd967b4da6e -- rhwp-core.lock RustBridge/Cargo.toml RustBridge/Cargo.lock Sources/HostApp/Resources/rhwp-studio Sources/Shared/FontLibrary/RhwpNativeFontMatcherSource.swift Sources/Shared/FontLibrary/native-font-matcher-receipt.json`으로 확인한다. 산출물 재빌드와 provenance 갱신을 혼동하지 않는다.

## 결과 판정과 승인

- 진단 결과는 검사 단계별 PASS / FAIL / EXPECTED_LIMITATION / NOT_RUN으로 구분한다. 예상 제한에는 이슈·조건·근거가 필요하며 unknown 오류를 자동 허용하지 않는다.
- 정상 계약 FAIL 또는 도구 오류가 남으면 단계 성공으로 커밋하지 않는다. 기대한 음성 대조는 정확한 실패 코드와 오공급 부재를 확인한 경우 계약 검증 PASS다.
- Stage 1 승인 후 Stage 2, Stage 2 승인 후 Stage 3, Stage 3 승인 후 Stage 4로 진행한다. 단계별 보고서는 해당 변경과 함께 커밋한다.
- 이번 승인 요청은 이 구현계획과 Stage 1 진입이다. 후속 단계, 제품 수정 범위 확대, 서명·등록·배포는 각 해당 승인 지점을 따른다.
