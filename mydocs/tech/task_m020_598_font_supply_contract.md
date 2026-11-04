# Task M020 #598 글꼴 공급 진단 계약

작성일: 2026-11-03. [구현계획](../plans/task_m020_598_impl.md), [Stage 1 보고](../working/task_m020_598_stage1.md).

공식 upstream 반영·알한글 새 릴리스 요청 시에는 [재개 인계](task_m020_598_release_handoff.md)에서 현재 기준과 후속 순서를 확인한다.

## 기준과 확인 범위

- 조사 source: `0699d16c` (문서 계획 커밋), 제품 baseline: `f64f6101863777e2bd49c2336e5e4fd967b4da6e`.
- core/Studio/matcher: `v0.8.7`, `1a76570e833917d15817415a53c09ad61ab3203f`. lock/manifest/receipt/source 해시는 [자산 기록](../working/assets/task_m020_598/stage1/assets.json).
- macOS 26.5.2 (25F84), arm64, Swift 6.3.3, Node v24.15.0, Python 3.9.6. xcodegen 사용 가능.
- 새 worktree에 Rhwp.xcframework 및 universal/librhwp.a 없음. 준비 상태 확인 결과이며 실행한 build 실패가 아니다. Stage 1에서는 빌드하지 않았다.
- upstream 수정 내용을 앱에 이식하거나 생성 matcher를 수정하지 않았다.

## 경계별 확정 사실

| 경계 | 코드 근거 | 관측·정책 | 판정 한계 |
|------|-----------|-----------|-----------|
| 설치 metadata | Sources/Shared/FontLibrary/InstalledFontSystem.swift: scan/activeDescriptors | CoreText 활성 descriptor, URL·PS·family·full·style·traits·axes·stat 획득. 이 시점 bytes 전체 읽기 없음 | 폴더 파일 존재와 활성 목록은 다름 |
| 설치 충돌 | InstalledFontCatalogService.swift: acceptScan | 소문자 PS가 같고 ID가 다르면 conflict | 같은 family의 서로 다른 PS와 동일 PS 충돌을 구분 |
| 설치 별칭 | StudioFontSupply.swift: installedFaces | family/full/PS만 aliases로 게시, weight는 nil | 파일의 다른 언어 이름이 자동으로 모두 전달되지는 않음 |
| 관리 별칭 | StudioFontSupply.swift: managedFaces | name ID 1/4/6/16 값과 OS/2 weight 전달 | 설치 경로와 metadata 출처가 다름 |
| adapter 후보 | Sources/HostApp/Services/StudioFontProviderScript.swift: normalize/select | 알려진 설치 style만 weight로 정규화. Book/빈 style 제외. 관리 후보 우선 및 충돌 차단 | 대상 실제 글꼴의 style과 alias가 없으므로 제보 원인 확정 불가 |
| 파일 검사·읽기 | InstalledFontSystem.read, FontFileInspector.inspect | symlink/크기/원본 변경·활성·PS 검사, static TTF/OTF 허용 후보, collection/variable 제한 | OTF/CFF 경로 존재는 모든 상용 OTF 통과 보장이 아님 |
| bytes 전송 | StudioFontSession.handle, provider.transfer | opaque ID, session/revision, chunk 및 PS/weight 검사, 취소·세대 무효화 | 전달 bytes와 렌더링 선택은 별개 |
| 변경 전파 | StudioFontMessageHandler.changed, adapter.refresh | native session 폐기 → alhangeul-fonts-changed → provider 구독 통지 | 문서 재조판 완료를 관측하지 않음 |
| Native 공급 | RustBridge/src/font_context.rs: collect_requests/rhwp_page_font_requests_json/render | build_page_layer_tree 후 run.style.font_family 요청 수집, tree에 bytes 기반 glyph sidecar 적용 | 조판 전에 원본 HFT 대응 글꼴을 공급하는 upstream 계약과 별도 확인 필요 |

현재 확인한 제품 결함은 없다. Book/빈 style 제외는 기존 테스트가 명시한 제한이며 임의로 해제하지 않는다. 설치 별칭 차이는 실제 대상에서 누락이 관측될 때만 수정 검토한다. 전체 파일 선읽기나 문자열 기반 딸기→Strawberry 강제 alias는 도입하지 않는다.

## 재현 자산

로컬 upstream checkout은 `/Users/melee/Documents/projects/forks/rhwp`에서 읽기만 수행했다. 아래 상대 경로와 해시를 장기 식별자로 사용하고 임시 출력 디렉터리에 의존하지 않는다.

| 입력 | 확인 위치·출처 | 결과 |
|------|---------------|------|
| 원본 HWP3 | upstream `samples/hwp3-sample10.hwp` | 945360 bytes, SHA256 `d9ceb35d8abfb73e9afbe349bccb2a986cf552d66ae7f3f34dcfe4d9d385cb48`. PR에 기록된 원본 hash와 일치 |
| 변환 HWPX | upstream `mydocs/pr/assets/issue7774/sql-sample10-regressions-20261015/hwp3-sample10-hwpx.hwpx` | 847607 bytes, SHA256 `3395e19bebea8b6689f383df1f4ea1ddb253dee91c4320392cc40e90e2e4f191`. header.xml에서 `id=3, face=딸기, type=HFT, isEmbedded=0` 확인 |
| 독립 한컴 PDF | upstream `pdf/issue8371/hwp3-sample10-2020.pdf` 및 `output/hwp3-sample10-2020.pdf` | 두 로컬 위치에 없음. 다른 변환·정규화 PDF를 동일 기준으로 사용하지 않음 |
| 실제 딸기 OTF/TTF | 사용자/공용 Fonts 파일명과 별도 CLI CoreText 활성 metadata 조회 | 딸기/Strawberry/HGSTRB 이름 일치 0건. 해당 프로세스 관측이며 Mac 전체 부재나 실제 앱 sandbox 결과로 일반화하지 않음 |
| 합성 검사 글꼴 | Tests/FontLibraryTests/Fixtures | 커밋된 6개 파일 SHA256 검증 통과. regular.ttf/bold.ttf/regular.otf/language-tag.ttf 등을 재사용 |

실제 OTF/TTF는 확보되지 않았다. 제보자 Mac의 파일과 다른 파일의 바이트 동일성도 확인하지 않았다. 실제 글꼴 확보 시 이름·버전·signature·PS·hash를 확인하며 상용 파일 자체는 커밋하지 않는다.

Stage 3 보완: 위 “실제 OTF/TTF” 미확보는 제보 대상 딸기에 관한 기록이다. 다른 실제 사용자 Fonts의 Pretendard OTF와 Hack TTF는 제한 밖 CLI에서 5개 face를 공급하고 원본 hash와의 일치를 확인했다. 제한된 실행에서는 이 대조 글꼴도 0건이었으므로 Stage 1/2의 0건 결과를 설치 부재로 해석하지 않는다. 제한 밖 별도 조회에서도 딸기/Strawberry/HGSTRB 관련 이름 일치는 0건이었다. 실행 경계와 형식별 원본 문서의 현재 관측은 [Stage 3 기록](../working/task_m020_598_stage3.md)에 보존한다.

PDF의 후속 획득 참조는 [PR #8397 제출 head의 PDF](https://github.com/edwardkim/rhwp/blob/8b0bcde745f7b78a5b1fbe2122238a57696b1feb/pdf/issue8371/hwp3-sample10-2020.pdf). PR에 기재된 기대 SHA256은 `310e3251e910ac8c7c6f34d0e50d85c4a0ecbbadd65e69fe4f5071370931a918`이다. 이번 단계에서는 다운로드·직접 렌더 판독하지 않았으며 확보 시 hash를 재검증한다. 기존 HWP/HWPX도 이번 단계에서 저장소에 복사하지 않았다.

## Stage 2 최소 구현 결정

제품 코드 변경 없이 전용 CLI와 제품 adapter 실행 harness를 만든다. 기존 전체 Studio probe는 Rust framework·GUI 의존성이 있어 현재 최소 공급 진단의 필수 전제로 삼지 않는다.

구현 파일:

1. `scripts/probe-hft-font-supply.py`: 새 build.noindex 하위 출력만 허용하는 실행기. swiftc/Node 호출, 입력 hash·실행 source·결과 요약 및 프로세스 실패 구분.
2. `Tests/HFTFontSupplyProbe/main.swift`: Shared/FontLibrary 제품 소스와 StudioFontSession을 컴파일한 CLI. 격리 InstalledFontCatalogService/FontLibraryStore/StudioFontSupply로 metadata 및 공급을 관측. 실제 설치 모드에서는 실제 system scan/read와 정확한 이름 필터를 사용하며 사용자 설정 저장소를 사용하지 않음.
3. `scripts/ci/hft-font-supply-adapter.cjs`: 제품 StudioFontProviderScript raw string을 기존 테스트 방식으로 실행. CLI JSON transport와 연결해 provider 공개 getSnapshot/readFace/subscribe를 검사. normalize/select 구현을 복사하지 않음.
4. `scripts/ci/test-hft-font-supply.cjs` 및 필요 runner 테스트: 출력 계약, 음성 대조, 실행 실패 집계. 기존 22개 테스트와 중복되는 전송/취소 전 범위를 새로 작성하지 않음.
5. `Tests/HFTFontSupplyProbe/README.md`: 정확한 실행·판정·한계.

확정 CLI 계약:

```bash
python3 scripts/probe-hft-font-supply.py --mode fixtures \
  --output-dir build.noindex/task598/stage2/fixtures-01
python3 scripts/probe-hft-font-supply.py --mode installed --family '딸기' \
  --output-dir build.noindex/task598/stage3/installed-01
```

Stage 2에서 위 도구를 구현·검증했다. 실행 방법과 종료 코드의 해석은 [probe README](../../Tests/HFTFontSupplyProbe/README.md), 검증 증거는 [Stage 2 보고](../working/task_m020_598_stage2.md)에 있다. fixture 모드는 scan/read 입력을 통제하되 제품 catalog/supply/session을 사용한다. 실제 파일의 검사에는 FontFileInspector를 사용한다. 실제 InstalledFontSystem.read는 installed 모드에서 대상이 확보되고 읽기까지 성공한 경우에만 입증한다. CoreText process/global font 등록 없이 fixture 주입으로 대조한다.

Node와 Swift 사이의 bytes는 테스트 전용 요청/응답 또는 실행 중 임시 전송 데이터로만 전달하고 영구 result에는 넣지 않는다. 실제 상용 bytes를 디스크 중간 파일로 남기지 않는 방식이 우선이다. Swift compile에는 Rust framework가 필요 없는 제품 파일 집합을 사용한다. 프로세스 통신 형식·취소·실패 처리가 기존 protocol을 바꾸지 않아야 한다.

후보 제외는 공개 결과에서 빠졌다는 사실과 입력 limitation/검사 사례를 기록한다. 제품이 노출하지 않은 내부 사유는 `unclassifiedExclusion` 또는 테스트의 예상 조건으로 표시하고 정확한 내부 reason이라고 꾸미지 않는다. 복수 후보는 그대로 유지하고 실제 upstream matcher 선택은 별도 증거가 있을 때만 판정한다.

## 결과 JSON 계약 v1

- `schemaVersion`: 1; `runID`, `mode`, `evidenceKind`(synthetic 또는 installed-cli), `sourceCommit`, `dirty`, OS/architecture/toolVersions.
- `provenance`: core/Studio/matcher commit, lock/manifest/matcher hash, fixture 파일별 hash.
- `cases`: 각 scenario의 `request`(family/weight/slant), `observations`, `checks`.
- `observations`: raw catalog와 provider 후보의 필요한 이름·PS·style·alias·limitation, opaque face ID, 읽은 bytes의 SHA256/길이/signature, revision 변경 여부. installed 목록 전체를 출력하지 않고 대상만 기록.
- `checks`: `stage`(catalog/candidate/bytes/invalidation/selection/layout/render), `status`, `reason`, `evidenceKind`. source 경로·bookmark·raw bytes는 금지.
- `status`: PASS, FAIL, EXPECTED_LIMITATION, NOT_RUN. 예상 제한에는 근거·조건이 필요. fixture의 의도한 실패 코드와 bytes 미공급을 확인하면 음성 대조 검사 자체는 PASS.
- `summary`: 각 status 수와 `complete`, `supplyComplete` 여부. NOT_RUN이 있으면 전체 제품 성공 표시 금지. `supplyComplete`는 selection/layout/render를 제외한 검사 완료이며 종료 코드 0도 이 범위에 한정한다. installed 대상 0건은 NOT_RUN으로 명시하며 원인 오류를 EXPECTED_LIMITATION으로 바꾸지 않음.
- 종료 코드: 0=요청 범위 계약 검사 완료, 1=계약 실패/도구 오류, 2=필수 대상·환경 미확보로 불완전. 증거 결과가 남아도 실패 코드를 삼키지 않음.

현재 구현에서는 HFT selection/layout/render 증거가 없으므로 NOT_RUN 또는 명확한 근거가 있는 제한으로만 표시한다. 정상 공급 계약과 이 판정을 별도 집계한다. fixture 모드 완료는 synthetic 공급 검증 완료만 뜻한다.

## 검증표

| 사례 | 이번에 검증할 것 | 이후에 검증할 것 |
|------|----------------|----------------|
| TTF만 / OTF만 | signature·PS·hash 동일한 bytes 공급 | 실제 HFT 원본 face 선택 |
| 양쪽 / 없음 | 후보 수·충돌 상태, 미공급·실패 구분 | OTF/TTF 순서와 fallback |
| 한글 요청·영문 metadata | alias 전달/누락의 관측 | 실제 딸기 metadata와 선택 |
| Book/빈 style | raw 목록 존재·provider 제외 | 별도 증거에 따른 지원 확대 판단 |
| 관리/설치 동명 | 관리 우선·차단 정책 보존 | 실제 출력 동등성 |
| 권한 거부/손상/변경 | 주입 또는 실제 실패의 정확한 구분 | 서명 sandbox·OS 변화 |
| refresh/재실행 | 세대 무효화·독립 프로세스의 공급 | 문서 재조판·줄바꿈·저장 원래 이름 |

공식 릴리스 후 실제 Studio/PDF/인쇄/Quick Look/Thumbnail에서 동일 bytes·선택·배치를 검증해야 한다. 지금 임시 HFT 치환 또는 원본 문서 이름 변경으로 통과시키지 않는다.
