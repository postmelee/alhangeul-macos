# Task M020 #600 2단계 공식 후보 생성 보고서

2026-11-09 · [구현계획](../plans/task_m020_600_impl.md) · [1단계 태그 검증](task_m020_600_stage1.md) · [복구 smoke를 담당하는 #594](https://github.com/postmelee/alhangeul-macos/issues/594)

## 공식 입력과 네이티브 산출물

core, Studio, native matcher를 모두 rhwp 정식 태그 `v0.9.0`의 커밋 `c9095c5f67632e6721e800ccc7fb43ea49d26682`에서 빌드했다. RustBridge의 Cargo 선언·lock과 `rhwp-core.lock`, Swift build-info, README 배지를 갱신했다. 새 `ClipPath`의 자식에도 글꼴 요청 수집과 glyph 처리를 적용한다.

| 검증 대상 | 결과 |
|---|---|
| universal archive | arm64·x86_64, 397079216 bytes, SHA256 `80ac4b99f6e26a083c72193e85794655df7267c24e2cf29b841b24999d861955`. 실제 파일과 lock 기준값 일치 |
| C ABI | 기존 공개 심볼 19개 검증. 생성 헤더 7584 bytes, SHA256 `14994c7d1923107b5739b5518e43f98bc002e1b954a068647a377ec4d6e1fbc2` |
| native matcher | esbuild 0.25.12로 태그의 10개 모듈을 묶었다. 서로 다른 작업 디렉터리에서 생성한 Swift와 receipt가 바이트 단위로 일치했다. JavaScriptCore에서 한국어 이름 `시험`은 `Probe-Regular`를 선택했고 미등록 이름은 `absent`였다. |
| matcher SHA256 | Swift `a00a51a2d8c04d39a617dc5d12558afcd65eb85b8a62425d361d79ed535d0923`, receipt `a6df8becfc04bf0cf28fedb73354925397ccaa18b4c74597023843cb36a51ac9` |

`build-rust-macos.sh --update-lock` 및 `--verify-portable`, build-info 검증, README 배지 검사, CoreBridge의 AppKit 의존 검사에 통과했다.

## Studio·WASM 동기화

태그의 npm lock과 공식 wasm-pack wrapper를 사용했다. Studio typecheck 임시 디렉터리에서 upstream의 형제 디렉터리 `assets`, `rhwp-shared`, `src`를 찾도록 수정했다. 태그의 정적 타입 사본에 빠진 `getMemoList` 등은 실제 빌드에서 생성한 두 선언 파일을 dist로 복사해 맞췄다. 메뉴 어댑터 회귀 8건이 통과했다.

최초 WASM의 Rust 진단 문자열에 빌드 기기의 사용자 디렉터리가 포함되어 있었다. 아래 명령은 태그 루트에서 컴파일러 경로를 치환하며, `CARGO_TARGET_DIR`은 로컬 정책의 공용 target을 가리킨다.

```sh
export PORTABLE_RUSTFLAGS="--remap-path-prefix=${CARGO_HOME:-$HOME/.cargo}=/cargo --remap-path-prefix=$PWD=/rhwp --remap-path-prefix=$CARGO_TARGET_DIR=/target"
RUSTFLAGS=$PORTABLE_RUSTFLAGS scripts/wasm-pack-locked.sh --target web --out-dir pkg
```

공식 글꼴 40개(WOFF2 38개, TTF 1개, OTF 1개)의 바이트를 upstream 체크섬 목록 2개와 대조했다. 앱의 WOFF2 등록 목록과 바뀐 옛한글 파일 이름을 맞추고, 두 라이선스 안내 사본 및 태그의 제3자 고지를 함께 번들에 포함했다. 라이선스 디렉터리의 PDF·텍스트 등 22개 파일은 Git 인덱스의 바이트를 태그 원본과 대조했다.

## 네이티브 렌더 회귀

첫 실행에서 `request.hwp`의 선 22개가 새 점선 형식 `{"Explicit":[0.64,0.96,0,0,0,0]}`을 사용해 Swift 디코딩에 실패했다. 선과 도형의 디코더·CoreGraphics 그리기에 명시 간격과 태그의 HWP pen 패턴을 반영했다. 기존 문자열 표기, 명시 간격, HWP 패턴, 잘못된 형식의 회귀를 확인했다.

| 첫 쪽 smoke | 출력 크기 | TextRun | 한글 스칼라 |
|---|---:|---:|---:|
| KTX.hwp | 1123 × 794 | 438 | 234 |
| request.hwp | 567 × 794 | 110 | 312 |
| exam_kor.hwp | 1123 × 1588 | 223 | 1368 |

세 파일 모두 PNG 렌더를 통과했다. `request.hwp`의 고정 fixture에서는 이전·새 producer의 노드 종류가 15개로 같았고 TextRun은 103→110, TextLine은 65→66, Table은 4개였다. 실제 producer를 다시 실행해 Swift decoder와 golden SHA256 `880ad4d6cb49e2a86918e1c8c5fe60f5ed747921c47707ba8672cf85ee4f6d48`을 확인했다. 이 파일의 첫 쪽에서 upstream은 표가 18.2px 겹친다는 진단을 출력한다.

## #594 인계 식별값

| 파일 | SHA256 |
|---|---|
| Studio `manifest.json` | `d76a9682ed1dda1575001e3b1df00882ad9bb9fdfa357008d0e473c37f38ac90` |
| WASM `assets/rhwp_bg-D2q_obRY.wasm` | `5feacb4a6f29ba1b8c3ad27c2ab29feb937f93b8c98a16c21979bc83787134de` |
| Studio JS `assets/index-Cu1nxCj9.js` | `7117cb2676db40cf993a57050086d59ee0e1b50224f877d57def53b7c5bf177a` |
| 메뉴 어댑터 receipt | `8728c372d6b938a4351809307a4414527c9430bd778e5299b4083ba52d9f3a4a` |

최종 WASM은 wasm-opt를 거쳤고, 번들 전수 검사에서 빌드 기기의 사용자·볼륨·임시 경로가 검출되지 않았다. 태그와 Cargo.lock을 지정한 Studio strict 검증 및 검증기 회귀(색상 선택기 DOM 6건 포함)가 통과했다. 런타임의 네 진입점 해시를 확인하고 public JS·WASM과 두 타입 선언을 생성 pkg에 대조했다. 최종 JS에서 오류 계약과 웹폰트 기한 표식을 확인했다. 제품 WASM으로 `request.hwp`를 열어 1쪽과 `getMemoList()` 응답을 확인했다.

HostApp과 Quick Look·Thumbnail을 포함한 Debug 빌드가 통과했다. 앱에 복사된 Studio 및 Legal 전체와 matcher receipt도 후보 파일과 일치했다. #600 개발용 앱과 두 확장의 등록을 해제했고 마지막 빌드는 등록을 비활성화했다. RustBridge의 테스트 fixture는 새 변환 필드를 기본값으로 초기화하는 upstream 생성자를 쓰도록 갱신했다. arm64 RustBridge 단위 테스트 29건이 모두 통과했다.

재현에 필요한 저장소 상대 경로는 `Sources/HostApp/Resources/rhwp-studio/`, `Sources/Shared/FontLibrary/native-font-matcher-receipt.json`, `Frameworks/Rhwp.xcframework`다. 전용 checkout과 산출물의 실제 위치는 이 작업 채팅 및 비공개 `output/stage2/studio-handoff.json`에 기록한다. 공개 릴리스 운영자가 rehearsal/publish를 실행할 때는 `expected_rhwp_tag` 입력을 이번 후보의 `v0.9.0`으로 지정해야 한다.

## 인계 범위

#594는 이 후보로 실제 WKWebView 편집 오류 복구를 검증한다. 이번 단계의 네이티브 결과는 arm64 호스트에서의 빌드·렌더 검증이다. 실제 딸기 글꼴, sample10 조판과 한컴 PDF 대조, Studio 저장·재열기 및 Finder 소비자 판정은 3단계 대상이다.
