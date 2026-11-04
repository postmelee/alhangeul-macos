# Task M020 #598 공식 릴리스 반영 재개 인계

작성일: 2026-11-04. 준비 이슈: [alhangeul-macos #598](https://github.com/postmelee/alhangeul-macos/issues/598). 다음에 **“업스트림 릴리스 반영 및 알한글 새 릴리스 진행”** 요청을 받으면 이 문서부터 읽는다.

## 재개 지점과 완료 경계

공식 릴리스 전 공급 진단·회귀 기준·인계 준비를 마쳤다. 실제 딸기/HFT 문제 해결, 새 upstream 버전 반영, 알한글 공개 배포는 아직 수행하지 않았다. 이 문서는 2026-11-03 검증과 11-04 인계 작성 시점의 로컬 기록이며, 새 공식 릴리스의 존재·수정 포함 여부는 재개 시 확인한다.

| 식별자 | 기준 |
|--------|------|
| 작업 | `local/task598`, 통합 대상 `devel` |
| 제품 기준 커밋 | `f64f6101863777e2bd49c2336e5e4fd967b4da6e` |
| 공급 도구의 clean 실행 커밋 | `c222ac81a7d3e544a7970c5473b11fe3ff303dde` |
| 검증 도구·기준 결과 최종 커밋 | `fdc51e8e09ed9f3b6955fe41f85ef447b18460eb` — 설정 캡처 선택 옵션과 Stage 3 증거 포함 |
| core/Studio/matcher | 공식 `v0.8.7`, `1a76570e833917d15817415a53c09ad61ab3203f` |
| upstream 참조 | [이슈 #8371](https://github.com/edwardkim/rhwp/issues/8371), [PR #8397](https://github.com/edwardkim/rhwp/pull/8397); 조사 당시 기록한 merge SHA `99a176b7cb34fde54454c03433baa1382b2de9fa` |

Stage 4와 최종 보고 단계는 문서만 변경한다. 인계 문서 커밋은 `git log -1 --format='%H %s' -- mydocs/tech/task_m020_598_release_handoff.md`로 찾는다. 2026-11-04 최종 보고·PR 게시 승인을 받아 [최종 보고서](../report/task_m020_598_report.md)를 작성했다. `publish/task598` → `devel` PR의 최신 게시·merge 상태는 #598에서 확인한다.

처음 재개할 때 #598의 PR·merge 상태부터 확인한다. 이미 통합됐으면 최신 통합 브랜치의 후속 이슈에서 진행하며, 위 과거 커밋으로 현재 작업을 되돌리지 않는다. 미통합 상태라면 이 브랜치의 준비 변경을 먼저 확인한다. 이슈 close와 worktree 삭제는 준비 PR의 승인·merge 절차를 따른다.

근거: [수행계획](../plans/task_m020_598.md), [구현계획](../plans/task_m020_598_impl.md), [공급 계약](task_m020_598_font_supply_contract.md), [Stage 1](../working/task_m020_598_stage1.md), [Stage 2](../working/task_m020_598_stage2.md), [Stage 3](../working/task_m020_598_stage3.md), [Stage 4](../working/task_m020_598_stage4.md).

## 현재 결과와 후속 판정

| 검사 | 저장한 결과 | 해석 |
|------|-------------|------|
| 합성 공급 10개 | 67 PASS, 0 FAIL, 30 NOT_RUN; Stage 2와 동일 | 후보·bytes·실패·세대 계약 검증. 문서 선택/조판/출력 미실행 |
| 실제 사용자 Fonts | Pretendard OTF 1개, Hack TTF 4개 | CoreText 원본 위치·opaque ID·공급 bytes hash 일치. 감지를 켠 격리 CLI 결과 |
| 실제 딸기 | 제한 밖에서도 후보 0건 | 대상 미확보. 제보 해결 판정 불가 |
| Rust portable | arm64/x86_64 build·source/lock/header/FFI 통과 | 최소 OS·Intel 실기 실행 또는 strict archive byte 동일성 증거는 아님 |
| Studio 소비자 | 기능 40 PASS, 저장 재열기 6개 항목 PASS | 고운바탕 시험 문서, 통제된 설치 목록. 실제 OS 변경/HFT 문서와 별개 |
| 설정 창 캡처 | 기본 모드 두 차례 `ScreenCaptureKit -3811`; 명시 생략 6 NOT_RUN | 캡처 문제 미해결. 기능 검사 통과와 구분 |
| sample10 HWP3/HWPX | 둘 다 pageCount 763, 첫 SVG 생성·재실행 hash 일치 | host provider 없는 기준 관측. 763을 정답으로 고정하지 않음 |
| 첫 SVG 이름 | HWP3: 딸기·신명 디나루 / HWPX: 돋움 | CSS family 목록 차이. 실제 선택된 파일이나 올바른 글리프 증거가 아님 |

증거의 진입점은 [실행 인덱스](../working/assets/task_m020_598/stage3/run-index.json), [자산 검사](../working/assets/task_m020_598/stage3/asset-audit.json), [Studio 요약](../working/assets/task_m020_598/stage3/studio/summary.json), [sample10 결과](../working/assets/task_m020_598/stage3/sample10-result.json)다. 전체 결과는 Git에 있고 큰 글꼴·문서·SVG·시험 앱은 포함하지 않았다. 로컬 `build.noindex/task598/stage3/`에는 로그·snapshot·SVG가 남아 있지만 재개를 그 디렉터리 존재에 의존하지 않는다. 시험 앱 2개와 임시 상태 3개는 정리했다.

## 입력 자산 확보

| 자산 | 재확보 기준 | 상태·주의 |
|------|-------------|-----------|
| 자체 합성 글꼴 6개 | `Tests/FontLibraryTests/Fixtures/SHA256SUMS` | Git에 포함. 작은 자체 제작 glyph로 실제 딸기 모양은 검증 불가 |
| HWP3 | upstream `samples/hwp3-sample10.hwp` | 945360 bytes, SHA256 `d9ceb35d8abfb73e9afbe349bccb2a986cf552d66ae7f3f34dcfe4d9d385cb48` |
| HFT 선언 HWPX | upstream `mydocs/pr/assets/issue7774/sql-sample10-regressions-20261015/hwp3-sample10-hwpx.hwpx` | 847607 bytes, SHA256 `3395e19bebea8b6689f383df1f4ea1ddb253dee91c4320392cc40e90e2e4f191`; header font ID 3에 딸기/HFT/nonembedded |
| 독립 한컴 PDF | [PR 제출 head의 원본](https://github.com/edwardkim/rhwp/blob/8b0bcde745f7b78a5b1fbe2122238a57696b1feb/pdf/issue8371/hwp3-sample10-2020.pdf) | 미확보. 기록된 기대 SHA256 `310e3251e910ac8c7c6f34d0e50d85c4a0ecbbadd65e69fe4f5071370931a918`를 실제 파일에서 재확인 |
| 실제 딸기 OTF/TTF | 제보자와 같은 제품·버전의 원본, 실제 family/full/PS·style·signature·hash 기록 | 미확보. 권한 있는 파일을 받아 비교하며 임의 alias·문서 이름 치환으로 대체하지 않음 |
| 사용자 경로 양성 대조 | Pretendard-Regular.otf, Hack-Regular/Bold/Italic/BoldItalic.ttf | 당시 `~/Library/Fonts`; hash는 자산 검사에 있음. 다른 Mac의 설치 상태를 가정하지 않음 |
| Studio 고운바탕 | [고정 provenance](../working/assets/task_m020_598/stage3/gowun-provenance.json), [Task #567 원출처](../plans/task_m020_567_impl.md) | Regular/Bold와 OFL.txt·METADATA.pb 필요. SIL OFL 1.1 원문·저작권 표시 보존 |

HWP/HWPX의 마지막 로컬 확인 checkout은 `/Users/melee/Documents/projects/forks/rhwp`다. 다른 환경에서는 upstream 참조 checkout에서 위 상대 경로를 확보하고 hash를 검증한다. PDF는 `8b0bcde...` 제출 head에서 가져와 Git LFS pointer나 다른 변환 PDF가 아닌 실제 파일인지 hash로 판별한다. 원본 문서·PDF·상용 글꼴의 재배포 권리는 이번에 확정하지 않았으므로 Git에 자동 추가하지 않는다.

고운바탕의 고정 출처는 `google/fonts` commit `c1eda9233c33ad7775b27efd794f931095cf6133`의 `ofl/gowunbatang/`다. 기존 probe의 경로는 `build.noindex/task567/fonts/gowun-batang/`로 고정돼 있다. 새 checkout에서는 그 위치에 4개 파일을 준비하고 provenance의 크기·hash를 대조한다. 확보 URL 패턴은 `https://raw.githubusercontent.com/google/fonts/c1eda9233c33ad7775b27efd794f931095cf6133/ofl/gowunbatang/{파일명}`이다. 다운로드·복사 후 실제 OS 글꼴로 등록할 필요는 없다.

## 공급 기준 재실행

저장소 루트에서 macOS GUI 사용자 세션, Xcode CLI/Swift, Node, Python 3.9 이상을 준비한다. 검증 환경은 macOS 26.5.2 arm64, Swift 6.3.3, Node 24.15.0, Python 3.9.6이었다. framework 없는 공급 CLI도 실행 가능하다. 명령별 종료 코드를 확인하고, 결과 폴더는 매 실행 새 이름을 쓴다.

```bash
TASK598_RUN='build.noindex/task598/resume-01'

node --test scripts/ci/test-hft-font-supply.cjs \
  scripts/ci/test-studio-font-provider.cjs scripts/ci/test-studio-font-bootstrap.cjs
python3 scripts/test-hft-font-supply-runner.py
python3 scripts/probe-hft-font-supply.py --mode fixtures \
  --output-dir "$TASK598_RUN/fixtures"
python3 scripts/probe-hft-font-supply.py --mode installed --family '딸기' \
  --output-dir "$TASK598_RUN/installed-target"
python3 scripts/probe-hft-font-supply.py --mode installed --family Pretendard-Regular \
  --output-dir "$TASK598_RUN/installed-control-otf"
python3 scripts/probe-hft-font-supply.py --mode installed --family Hack \
  --output-dir "$TASK598_RUN/installed-control-ttf"
```

기대 판정은 [probe README](../../Tests/HFTFontSupplyProbe/README.md)와 [schema v1](task_m020_598_font_supply_contract.md)을 따른다.

- 종료 0은 공급 검사 완료, 1은 계약/도구 실패, 2는 대상 후보 미확보다. `summary.supplyComplete`와 selection/layout/render의 NOT_RUN을 따로 읽는다. 2를 정상 공급 성공으로 집계하지 않는다.
- 현재 fixture의 cases·summary가 [기준 결과](../working/assets/task_m020_598/stage3/fixtures-01.json)와 같은지 확인한다. 새 버전에서 의도된 변화가 있으면 해당 검사와 근거를 기록하고, 기대값만 바꿔 실패를 숨기지 않는다.
- provenance의 core/Studio/matcher commit, 실제 입력 hash, 실행 HEAD·dirty 상태를 함께 비교한다. runID·시간·실행 커밋 차이는 재실행에서 자연스럽지만 bytes·판정 차이는 설명해야 한다.
- 명령을 격리하는 도구에서는 활성 목록이 0건일 수 있다. 이미 설치된 양성 대조도 함께 조회하고 같은 macOS 사용자의 일반 터미널과 비교한다. 이 실행 경계는 제품 App Sandbox와 다르다. `sudo`로 사용자 컨텍스트를 바꾸는 방식으로 대체하지 않는다.
- installed의 이름은 NFC·대소문자 무시 완전 일치다. 실제 metadata에서 확인한 한글/영문 family 또는 PS로 각각 실행한다. 없는 글꼴을 얻기 위해 사용자 OS 설치/삭제를 자동 수행하지 않는다.

## 문서·Studio 기준 재실행

아래 `TASK598_UPSTREAM`은 위 두 문서가 들어 있고 hash를 확인한 checkout이다. 새 릴리스 build checkout과 다른 자산용 checkout일 수 있다. 앞선 공급 실행으로 `TASK598_RUN` 상위 디렉터리가 생성돼 있어야 한다.

```bash
TASK598_UPSTREAM='/path/to/upstream-rhwp'
node mydocs/working/assets/task_m020_598/stage3/sample10-baseline.mjs \
  . "$TASK598_UPSTREAM" "$TASK598_RUN/sample10"

./scripts/build-rust-macos.sh --verify-portable
python3 scripts/probe-studio-font-integration.py --changes --skip-settings-screenshots \
  --output-dir "$TASK598_RUN/studio-functional"
```

sample10 명령은 현재 checkout의 bundled WASM을 사용한다. 실행 전후의 입력 hash, SVG hash·family 목록·pageCount를 기록하며 실제 선택과 시각 대조는 별도 수행한다. 이 명령만으로 HFT 해결을 판정하지 않는다.

Studio 명령은 고운바탕 4개 자산과 framework가 필요하다. 공급 후보/bytes 변경, 문서 이름 보존, 새 프로세스 재열기 결과 및 `changes-saved-proof.json`을 기준과 비교한다. `--skip-settings-screenshots`는 설정 창 캡처만 NOT_RUN으로 남긴다. 기본 캡처를 재검증할 때는 옵션을 빼고 다른 새 출력 경로에서 실행한다. `--skip-build`는 새 소스·버전 검증에 사용하지 않는다. 실행 후 시험 앱의 등록 해제와 임시 상태 정리를 확인한다.

기존 `scripts/probe-native-font-supply.py`는 Task #568의 임시 문서·변형 글꼴과 process-scope CoreText 등록을 전제로 하므로 즉시 실행 가능한 범용 HFT 검사로 취급하지 않는다. 입력 provenance·등록 격리·정리 조건을 먼저 재구성한다. `scripts/probe-studio-font-acceptance.py` 역시 NanumSquare 시험 문서와 승인된 서명 identity를 요구한다. 실제 딸기 대상의 signed sandbox 검사는 별도 수용 계획으로 준비한다.

## 공식 릴리스 반영 순서

이 절의 갱신 명령은 **다음 공식 릴리스 반영 요청 시** 사용한다. 현재 준비 작업에서 실행하지 않았다. [core 운영 가이드](../manual/core_dependency_operation_guide.md)와 당시 최신 sync workflow를 함께 읽는다.

1. 공식 GitHub Release의 tag·게시 상태·resolved commit을 확인한다. #8397과 관련 후속 수정이 포함됐는지 release notes·commit·코드·회귀 결과로 검증한다. merge SHA의 ancestor 여부는 단서이며, 후속 revert나 squash/cherry-pick까지 확인해야 한다. 포함 근거가 없으면 반영을 보류하고 floating devel로 대체하지 않는다.
2. 후속 이슈·계획에서 tag/commit과 변경 범위를 고정한다. 이미 자동 sync PR이 있으면 그 후보를 먼저 검토해 중복 작업을 피한다. 준비 PR의 통합 여부와 충돌을 확인한다.
3. 해당 tag의 깨끗한 upstream checkout에서 core와 WASM·Studio를 빌드한다. `pkg/`, `rhwp-studio/dist`를 다른 커밋에서 가져오지 않는다. Studio는 앱 소유 어댑터를 적용하는 `scripts/build-rhwp-studio.mjs`와 sync 증명 검증을 따른다.
4. core lock/RustBridge, build-info, Studio manifest/WASM, 생성 native matcher/receipt를 같은 resolved commit으로 갱신한다. 생성 파일을 손으로 편집하지 않는다.
5. source/API/ABI·build-info·bundle·matcher 검증과 위 기준 회귀, 다음 절의 실제 소비자 수용을 수행한다. 통합 PR이 통과해도 공개 릴리스 완료로 간주하지 않는다.

아래 값은 재개 시 확인한 값으로 설정한다. mutation 명령은 승인된 후속 브랜치에서만 실행한다.

```bash
TASK598_TAG='vX.Y.Z'
TASK598_COMMIT='검증한_40자리_resolved_commit'
TASK598_BUILD_UPSTREAM='/path/to/clean-target-checkout'

# 반영 전 호환성 검사
./scripts/update-rhwp-core.sh --channel stable --tag "$TASK598_TAG" --check \
  --upstream-dir "$TASK598_BUILD_UPSTREAM"

# 승인된 공식 버전 반영
./scripts/update-rhwp-core.sh --channel stable --tag "$TASK598_TAG" \
  --upstream-dir "$TASK598_BUILD_UPSTREAM"
./scripts/build-rust-macos.sh --update-lock
./scripts/update-rhwp-core-build-info.sh
./scripts/verify-rhwp-core-build-info.sh

# 같은 commit의 WASM/Studio build와 adapter 증명 준비 후 실행
./scripts/sync-rhwp-studio.sh --upstream-dir "$TASK598_BUILD_UPSTREAM" \
  --tag "$TASK598_TAG" --commit "$TASK598_COMMIT"
./scripts/verify-rhwp-studio-assets.sh --upstream-dir "$TASK598_BUILD_UPSTREAM" \
  --tag "$TASK598_TAG" --commit "$TASK598_COMMIT"

# 현재 generator는 별도 tool-dir의 esbuild 0.25.12를 요구한다.
TASK598_TOOLS='build.noindex/task598/matcher-tools'
npm install --prefix "$TASK598_TOOLS" --save-exact esbuild@0.25.12
node scripts/build-native-font-matcher.mjs --upstream-dir "$TASK598_BUILD_UPSTREAM" \
  --tool-dir "$TASK598_TOOLS"
node scripts/build-native-font-matcher.mjs --verify --upstream-dir "$TASK598_BUILD_UPSTREAM"
./scripts/build-rust-macos.sh --verify-portable
```

현재 저장소의 `.github/workflows/rhwp-upstream-sync-pr.yml`에는 native matcher 재생성 명령이 명시돼 있지 않다. 자동 core/Studio sync만으로 matcher까지 갱신됐다고 가정하지 않는다. 후속 시점에 workflow와 generator API를 다시 확인하고 필요하면 후속 이슈에서 보완한다. API 변화로 generator가 실패하면 이전 receipt나 새 commit 문자열만 붙여 통과시키지 않는다.

위 블록은 WASM/Studio 빌드 전체를 대신하지 않는다. 실제 WASM build command와 산출물 provenance는 당시 upstream 빌드 절차·sync workflow에서 확인하고, 기본값과 다른 경우 sync의 `--actual-wasm-build-command`에 실제 명령을 기록한다. render tree golden은 기존 producer 갱신·검증 절차를 적용하며 무조건 재생성해 통과시키지 않는다. HostApp build/PR CI도 후속 변경 범위에 따라 실행한다.

## 실제 HFT 해결의 수용 기준

| 경계 | 필요한 증거 |
|------|-------------|
| HWP3·HFT HWPX 입력 | 원본 hash·font type/name 유지. 이름이나 형식을 바꾼 우회 입력과 구분 |
| 한글/영문·스타일 | 실제 대상의 family/full/PS/aliases·Regular/Bold 및 제외 사유. 임의 alias나 weight 추정으로 오매칭하지 않음 |
| OTF만/TTF만/양쪽/없음 | 실제 대응 글꼴의 signature·PS·hash, 선택된 face, 없을 때 정상 fallback. 안전한 격리 환경으로 조합 구성 |
| Studio 본문 | 원본 HFT 이름에 대응한 실제 bytes·선택 face, 측정·그림의 동일성, 줄바꿈·페이지 배치 및 독립 PDF 대조 |
| 감지·재열기 | 열기 전/후 공급 변경, 실제 OS 알림·권한, 이전 세대 폐기, 열린 문서 재조판·새 프로세스 결과. 합성 refresh만으로 완료 처리 금지 |
| native | RustBridge `font_context.rs`가 layer tree 생성 후 run family를 수집하는 현재 구조와 upstream 조판 전 공급 계약의 호환성. 차이가 있으면 ABI/bridge 별도 수정·검증 |
| PDF·인쇄 | 실제 선택 PS/style/program·글리프·ToUnicode/텍스트와 배치 대조. 화면 CSS 이름이나 공급 성공만으로 출력 성공 판정 금지 |
| Quick Look·Thumbnail | 실제 배포형 sandbox/서명 산출물의 첫 페이지·glyph·캐시 갱신. 표준 Finder smoke의 등록·해제 절차 사용 |
| OS/아키텍처 | 최소 지원 macOS 및 Intel 실기 수용 여부 명시. universal build로 실행 검증을 대체하지 않음 |

관리 우선·동일 PS 충돌·손상·권한 거부·Book/빈 style 등 기존 제한도 유지/변경 근거를 기록한다. 일반 공급 FAIL을 “upstream HFT 제한”으로 낮추지 않는다. 실제 대상 미확보나 독립 기준 부재가 남으면 “HFT 해결 확인” 릴리스 문구를 사용하지 않는다.

## 알한글 새 릴리스로 연결

공식 upstream 반영과 실제 수용 결과가 준비되면 별도 릴리스 운영 이슈에서 알한글 버전·candidate commit·포함 PR·지원 범위·남은 한계를 확정한다. [릴리스 진입점](../manual/release_distribution_guide.md)과 [public runbook](../manual/public_release_runbook.md)을 그 시점에 다시 읽고 signed/notarized draft DMG, 설치 smoke, universal/서명/Gatekeeper, Sparkle 업데이트, 공개 전 확인을 수행한다.

이미 받은 “릴리스 진행” 지시의 범위를 존중하되, runbook이 요구하는 실제 후보 산출물을 먼저 준비해 검토 가능한 상태로 만든다. public publish·Pages/Sparkle·Homebrew의 승인은 해당 단계의 구체 후보와 함께 처리한다. 이번 인계는 서명·공증·태그·공개 작업을 실행하거나 미래 성공을 보증하지 않는다.

최종 보고·PR 게시 때 #598과 PR 본문에 **이 문서의 게시된 commit 고정 링크**, 준비 기준 커밋, 잔여 HFT 수용 항목을 남긴다. 이슈를 닫더라도 준비 완료와 실제 문제 해결을 구분한다. 별도 채팅에서 “#598 인계 기준으로 공식 릴리스 반영과 알한글 릴리스 진행”이라고 요청하면 이 순서로 이어갈 수 있다.
