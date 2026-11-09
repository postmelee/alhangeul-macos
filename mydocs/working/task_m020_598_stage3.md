# Task M020 #598 Stage 3 완료 보고

작성일: 2026-11-03. [구현계획](../plans/task_m020_598_impl.md). 작업지시자의 Stage 3 진행 승인 후 수행. 공급·Studio 기능 기준을 고정했고 실제 HFT 재현과 설정 창 캡처 미검증을 분리했다.

## 단계 목적

커밋된 공급 진단을 새 프로세스로 실행해 현재 공식 버전의 기준 결과를 고정한다. 합성 공급, 실제 사용자 Fonts 공급, 원본 문서 관측, 환경 제한 및 미검증을 분리한다.

## 산출물

- [실행 인덱스](assets/task_m020_598/stage3/run-index.json): 실행 경계·종료 코드·결과 해시·깨끗한 실행 커밋·판정 요약.
- [합성 결과](assets/task_m020_598/stage3/fixtures-01.json)와 [Stage 2 비교 증거](assets/task_m020_598/stage3/comparison.json).
- [실제 사용자 OTF](assets/task_m020_598/stage3/installed-user-otf-host.json), [실제 사용자 TTF](assets/task_m020_598/stage3/installed-user-ttf-host.json), [딸기 조회](assets/task_m020_598/stage3/installed-strawberry-host.json), [관련 이름·지역화 이름 조회](assets/task_m020_598/stage3/active-fonts-host.json).
- [자산 재확인](assets/task_m020_598/stage3/asset-audit.json): 원본 문서 hash·HFT 선언·독립 PDF 부재, 사용자 Fonts 원본과 공급 bytes hash 대조.
- [sample10 WASM 기준 결과](assets/task_m020_598/stage3/sample10-result.json)와 [재실행 스크립트](assets/task_m020_598/stage3/sample10-baseline.mjs).
- [기존 Studio 시험 글꼴 provenance](assets/task_m020_598/stage3/gowun-provenance.json): Task #567의 고정 배포 hash와 일치한 Regular/Bold·OFL·metadata.
- [사용자 Fonts 위치 대조 코드](assets/task_m020_598/stage3/user-font-locations.swift)와 [결과](assets/task_m020_598/stage3/user-font-locations.json): 원본 경로 노출 없이 descriptor opaque ID와 공급 ID 대조.
- [Rust portable 검증](assets/task_m020_598/stage3/rust-build-result.json), [빌드 로그](assets/task_m020_598/stage3/rust-build-portable.log), [Studio 기능 요약](assets/task_m020_598/stage3/studio/summary.json), [기능 로그](assets/task_m020_598/stage3/studio/functional-run.log).
- 기존 Studio probe의 명시적 `--skip-settings-screenshots` 옵션과 캡처 PASS/FAIL/NOT_RUN 집계. 글꼴 기능 검사·기본 캡처 동작은 유지.

## 본문 변경 정도 / 본문 무손실 여부

제품 소스·core pin·Studio/WASM·matcher는 유지했다. 문서 원본·사용자 Fonts·앱 설정을 수정하지 않았다. 실제 글꼴은 읽기만 수행했고 파일 자체를 Git에 넣지 않았다. 문서 SVG·생성 framework·시험 앱은 로컬 산출물이다. 추가한 sample10 스크립트는 관측 재실행용이며 제품 선택 알고리즘을 구현하지 않는다.

검증 중 반복된 설정 창 캡처 오류를 기능 회귀와 분리하기 위해 `Tests/StudioFontIntegrationProbe/main.swift`와 실행기의 테스트 옵션만 보완했다. 기본 모드에서 캡처 실패를 성공으로 바꾸지 않으며, 명시 옵션을 쓴 경우 생략 수를 기록한다. Studio 시험 앱은 격리 저장소만 사용했고 실행기 종료 시 해당 앱의 LaunchServices 등록 해제가 성공했다. 사용자 글꼴의 CoreText 등록·서명 인증서·Finder extension 등록은 수행하지 않았다.

검증 종료 뒤 재생성 가능한 시험 앱 2개와 전용 fixture 상태 3개를 [정리](assets/task_m020_598/stage3/cleanup.json)했다. 결과·로그·snapshot과 고정 버전 framework는 후속 비교를 위해 보존했다.

## 검증 결과

### 공급 기준과 실행 환경

7개 공급 실행 모두 `c222ac81a7d3e544a7970c5473b11fe3ff303dde`, `dirty=false`에서 시작했다. core/Studio/matcher는 `v0.8.7`, `1a76570e833917d15817415a53c09ad61ab3203f`다. macOS 26.5.2 arm64, Swift 6.3.3, Node 24.15.0, Python 3.9.6이며 전체 입력 소스·fixture hash를 결과에 보존했다.

| 실행 | PASS / FAIL / NOT_RUN | 종료 | 의미 |
|------|----------------------|------|------|
| 새 프로세스 합성 10개 | 67 / 0 / 30 | 0 | Stage 2의 cases·summary·provenance와 완전 일치 |
| 제한 환경 딸기 / Pretendard-Regular / Hack | 각각 3 / 0 / 4 | 각각 2 | 세 대상 모두 raw/candidate 0건. 도구 환경에서의 관측 |
| 제한 밖 Pretendard-Regular | 7 / 0 / 3 | 0 | 실제 사용자 OTF 1개 읽기·전송 성공 |
| 제한 밖 Hack | 13 / 0 / 3 | 0 | 실제 사용자 TTF 4개 읽기·전송 성공 |
| 제한 밖 딸기 | 3 / 0 / 4 | 2 | 대상 후보 미확보. 해결 여부 미검증 |

여기서 제한 환경은 Codex 실행 도구의 제한이며 제품 App Sandbox가 아니다. 동일 도구·파일에서 제한 밖 실행 시 사용자 글꼴이 나타났으므로, 제한 환경의 0건을 OS 글꼴 부재나 앱 결함으로 해석하지 않는다. Stage 1/2의 0건 기록도 이 한계를 적용한다. 제한 밖의 별도 기존 CoreText 조회에서도 딸기/Strawberry/HGSTRB 및 관련 지역화 이름 일치는 0건이었다.

실제 대조 글꼴은 `~/Library/Fonts`의 Pretendard-Regular.otf와 Hack-Regular/Bold/Italic/BoldItalic.ttf다. 진단 전용 격리 목록에서 감지를 켠 상태이며 실제 앱의 설정을 켜거나 기본값을 검사한 것은 아니다. 공급한 5개 bytes의 SHA256을 해당 파일과 별도 대조하여 일치를 확인했다. OTF는 `4f54544f`, TTF는 `00010000`이다. Hack은 Regular 400 normal, Bold 700 normal, Italic 400 italic, Bold Italic 700 italic으로 관측됐다. 이 결과는 해당 파일들에 대한 사용자 글꼴 경로의 실제 공급 증거이며, 모든 글꼴·sandbox·HFT 선택 성공으로 일반화하지 않는다.

추가 CoreText descriptor 조회에서 원본 위치를 `user-Library-Fonts`로 분류하고 제품과 동일한 static face ID 직렬화로 대조했다. 5개 descriptor의 ID가 실제 read 결과의 ID와 모두 일치했다. 실제 절대 경로는 저장하지 않았다.

Book/빈 style 제외, 동일 PS 충돌 거부, 관리 우선·한글 별칭, 권한/손상 음성 대조, 구독 통지와 staleGeneration 거부는 합성 결과에 남겼다. 실제 문제 글꼴의 한글/영문 이름 대응은 여전히 미검증이다. 모든 공급 결과의 selection/layout/render는 NOT_RUN이고 `complete=false`다.

### 원본 HWP3·HWPX 현재 기준

Stage 1과 동일한 HWP/HWPX hash를 재확인했고 HWPX header의 `face=딸기, type=HFT, isEmbedded=0` 선언도 유지됐다. 확인한 로컬 두 위치에는 독립 한컴 PDF가 없다.

현재 번들 WASM으로 **host provider를 연결하지 않고** 두 원본의 parse·pageCount·첫 페이지 SVG 생성만 실행했다. 별도 스크립트로 새 프로세스에서 재실행하여 결과·SVG hash의 동일성도 확인했다.

| 입력 | pageCount 관측값 | 첫 페이지 SVG의 font-family 선두 이름 |
|------|-----------------|--------------------------------------|
| HWP3 | 763 | 딸기, 신명 디나루 |
| 변환 HWPX | 763 | 돋움 |

두 형식의 첫 페이지 출력 이름이 다르다는 기준 관측이다. SVG의 CSS family 목록은 실제 선택·읽은 파일의 증거가 아니며, 763이라는 관측값도 올바른 페이지 수라는 수용 판정이 아니다. 전체 페이지·실제 글리프·줄바꿈·독립 PDF 비교는 NOT_RUN이다. SVG 원문은 Git에 추가하지 않고 결과의 hash/크기·이름 목록만 보존했다.

### 기존 Studio 소비자 회귀

- `build-rust-macos.sh --verify-portable`: arm64/x86_64 release build, core source·Cargo.lock·header·FFI symbol 검증 통과. 최초 제한 실행은 Cargo cache 쓰기 거부(exit 101), 같은 locked 버전을 제한 밖에서 재실행해 exit 0으로 회복했다. strict staticlib byte 일치는 검사하지 않았고 lock reference를 갱신하지 않았다.
- Task #567의 커밋된 provenance와 hash가 일치하는 Gowun Batang Regular/Bold, OFL.txt, METADATA.pb를 기존 로컬 checkout에서 읽어 새 worktree의 시험 경로로 복사했다. 확인 없는 generated framework 복사는 하지 않았다.
- 기존 `--changes` 기본 실행과 동일 바이너리 재실행에서 각각 변경 검사 31개와 관리 재열기 검사 5개 후 ScreenCaptureKit `-3811` 설정 창 캡처 오류가 발생했다. 실패 증거는 [요약](assets/task_m020_598/stage3/studio/summary.json)의 originalCaptureAttempts에 남겼으며 성공으로 덮어쓰지 않았다.
- 설정 창 캡처만 명시적으로 생략하는 옵션을 추가해 새 출력 경로에서 다시 컴파일·실행했다. compile.log 진단 0 bytes, 실행기 exit 0. 새 옵션은 `--changes` 없이 사용하면 인자 오류(exit 2)이며 자동 캡처 우회는 없다.
- 최종 결과: **변경 31 + 관리 재열기 5 + 설치 재열기 4 = 기능 40 PASS**, HWP/HWPX 저장 후 이름·굵기 검증 **6개 항목 PASS**, **설정 창 캡처 6 NOT_RUN**. WKWebView snapshot은 그대로 실행했다. 캡처를 포함한 전체 시각 수용 성공은 아니다.
- canvas2d/CanvasKit에서 후보 제거·복원, 권한 회복, 동일 PS의 변경 bytes 재공급, 관리 보관함 우선, 늦은 응답 폐기, 문서 원래 이름·굵기·clean 상태 유지와 새 프로세스 자동 공급을 확인했다. 설치 목록은 통제된 fixture 주입이므로 실제 OS 설치 이벤트 검증이 아니다. 이 문서는 고운바탕 시험 문서이며 sample10 HFT 재현과 별개다.
- 제품·고정 자산 무변경, 보존 JSON·실행 입력 hash·문서 링크 및 `git diff --check` 검사를 완료했다. 공급 구현은 바꾸지 않았으므로 Stage 2의 Node 27개·Python 5개 단위 회귀를 의미 없이 반복하지 않았다.

### 실행 명령

저장소 루트에서 실행했다. 같은 명령을 재실행할 때 출력 디렉터리는 새 이름으로 바꾼다. 실제 설치 모드는 CoreText를 조회할 수 있는 호스트 터미널에서 실행한다.

```bash
python3 scripts/probe-hft-font-supply.py --mode fixtures \
  --output-dir build.noindex/task598/stage3/fixtures-01
python3 scripts/probe-hft-font-supply.py --mode installed --family Pretendard-Regular \
  --output-dir build.noindex/task598/stage3/installed-user-otf-host
python3 scripts/probe-hft-font-supply.py --mode installed --family Hack \
  --output-dir build.noindex/task598/stage3/installed-user-ttf-host
python3 scripts/probe-hft-font-supply.py --mode installed --family '딸기' \
  --output-dir build.noindex/task598/stage3/installed-strawberry-host
swift -module-cache-path build.noindex/task598/stage3/active-modules \
  mydocs/working/assets/task_m020_598/stage1/active-fonts.swift
node mydocs/working/assets/task_m020_598/stage3/sample10-baseline.mjs \
  . /path/to/upstream-rhwp build.noindex/task598/stage3/sample10-baseline-replay
./scripts/build-rust-macos.sh --verify-portable
python3 scripts/probe-studio-font-integration.py --changes --skip-settings-screenshots \
  --output-dir build.noindex/task598/stage3/studio-changes-functional
```

sample10 스크립트의 세 번째 인자는 존재하는 상위 디렉터리 아래의 새 경로여야 한다. 원본 위치는 [진단 계약](../tech/task_m020_598_font_supply_contract.md)의 upstream 상대 경로를 따른다. sample10 스크립트 실행 시에는 기록 파일이 추가되어 `dirty=true`이고, script/JS/WASM/input hash로 실행 입력을 식별한다. 이를 공급 실행 7개의 clean 결과와 구분한다.

Studio는 GUI 세션, 위 framework, `build.noindex/task567/fonts/gowun-batang/`의 고정 시험 글꼴을 요구한다. 기본 캡처까지 검증할 때는 `--skip-settings-screenshots`를 빼며, 현재 환경에서는 반복 실패가 알려져 있다. 새 옵션을 사용하기 전 probe를 새로 빌드한다. 최종 실행은 Stage 2 커밋 위 테스트 보완 상태이며, [요약의 inputHashes](assets/task_m020_598/stage3/studio/summary.json)로 정확한 테스트 소스를 식별한다.

## 잔여 위험

제보의 실제 딸기 OTF/TTF와 독립 PDF를 확보하지 못했다. 실제 앱 sandbox, 최소 지원 OS/Intel 실행, OS 설치/제거 감지, 실제 HFT 원본 대응 선택·측정·재조판·PDF/인쇄/Finder 수용은 남아 있다. 정상 공급 FAIL은 발견되지 않았으나, 이를 HFT 수정 검증 완료로 표시하지 않는다.

설정 창 캡처 `-3811`의 근본 원인은 확정하지 않았다. 명시적 캡처 생략은 기능 검사 실행을 위한 구분이며 캡처 오류 해결이 아니다. 환경이 준비되면 기본 캡처 모드로 별도 수용해야 한다.

기존 NativeFontSupplyProbe는 새 worktree에 없는 Task #568 문서·변형 font 등 임시 경로를 하드코딩하고, main.swift에서 process-scope CoreText 등록을 수행한다. 스크립트 설명의 “등록 없음”만 보고 무조건 실행하지 않는다. 이 선택적 검사는 입력 provenance·격리 조건을 다시 준비할 후속 항목이며 이번에는 NOT_RUN이다.

## 다음 단계 영향

Stage 4 인계에는 실행 도구의 제한과 실제 앱 sandbox의 차이, clean 공급 기준 커밋, 사용자 경로 양성 대조, 형식별 sample10 출력 차이 및 미확보 자산을 포함한다. 공식 릴리스의 수정 포함 확인과 반영 후 비교는 이 기준을 사용하되 실제 문제 글꼴·문서 소비자의 증거를 별도로 요구한다.

## 승인 요청

Stage 3의 기능 기준 결과 및 명시한 미검증을 검토하고 Stage 4 인계 문서 작성 진입 승인을 요청한다. upstream 릴리스 반영·알한글 공개 릴리스는 이번 단계에서 수행하지 않았다.
