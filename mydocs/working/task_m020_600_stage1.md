# Task M020 #600 1단계 완료 보고서

2026-11-08 · [구현계획](../plans/task_m020_600_impl.md) · [#598 인계](../tech/task_m020_598_release_handoff.md)

## 태그·앱 기준

[공식 rhwp v0.9.0](https://github.com/edwardkim/rhwp/releases/tag/v0.9.0)은 2026-11-08 20:02 KST에 게시된 정식 릴리스다. GitHub의 draft/prerelease 값은 모두 false이며 원격 태그와 별도 checkout HEAD는 `c9095c5f67632e6721e800ccc7fb43ea49d26682`다. 앱은 #599 머지 커밋 `2b13f03e86c7fdb907d8051e1e2e55ffcd7c7071`에서 시작했다. 최초 조회 시 동일 태그 자동 PR과 해당 원격 브랜치는 0개였다.

| 확인한 수정 | 태그의 실제 동작 |
|------------|------------------|
| #8397 `99a176b7cb`, 후속 `e64921811f`, `5551091085` | 세 커밋 모두 태그의 선조다. host Canvas의 `host-canvas-fonts.ts`가 선택 파일의 실제 bytes를 공급하고 `registerHftOutlineFont`를 호출한다. native의 `renderer/skia/font_lookup.rs`는 현지화된 이름을 확인하고 `text_replay.rs`는 해당 face에서 HFT 윤곽을 재생한다. |
| #8104 `9418ed0c7c` | 태그의 선조다. Studio는 `window.rhwpCommandErrors.getState()`와 `rhwp-command-error` 이벤트를 제공한다. embed에서는 capability 협상 후 `getCommandErrorState`와 오류 구독을 제공한다. |
| #8614 `ece9c3383b` | 태그의 선조다. `font-loader.ts`에서 바이트 요청은 5초 기한에 fetch를 abort하고 FontFace 준비도 5초로 제한한다. 같은 파일의 늦은 성공이 등록 상태를 복원하는 경로를 검사했다. 앱 빌드에 #594의 실험용 어댑터를 추가할 필요가 없다. |

`scripts/update-rhwp-core.sh --check --channel stable --tag v0.9.0 --upstream-dir "$UP"`가 통과했다. 메뉴 어댑터는 local-fonts, toolbar, options-dialog, main 네 원본을 메모리에서 각각 변환했다. native matcher의 세 진입점 `setHostFontProvider`, `prepareHostFontCatalog`, `resolveRendererLocalFont`도 실제 태그에 있다.

## 원본 회귀

공식 Studio lock으로 의존성을 설치하고 아래 명령을 태그 루트에서 실행했다.

```sh
node --test --test-concurrency=1 rhwp-studio/tests/command-error-contract.test.ts \
  rhwp-studio/tests/font-loader-deadline.test.ts rhwp-studio/tests/font-loader-offline-mode.test.ts \
  rhwp-studio/tests/host-font-provider.test.ts rhwp-studio/tests/host-canvas-fonts.test.ts
```

최종 결과는 59 PASS, 0 FAIL, 0 SKIP이다. 첫 실행은 sparse checkout에서 `tests/fixtures/fonts`가 빠져 3건 실패했다. 같은 태그의 fixture 디렉터리를 추가해 원본 테스트 그대로 재실행했다. 이 수치는 태그 단위 테스트이며 알한글 WKWebView의 실제 오류 복구는 #594가 공식 번들로 검증한다.

## 실제 입력

| 입력 | 확인 결과 |
|------|----------|
| sample10 HWP3 | 945360 bytes · SHA256 `d9ceb35d8abfb73e9afbe349bccb2a986cf552d66ae7f3f34dcfe4d9d385cb48` |
| sample10 HFT HWPX | 847607 bytes · SHA256 `3395e19bebea8b6689f383df1f4ea1ddb253dee91c4320392cc40e90e2e4f191` |
| 독립 한컴 PDF | 96185197 bytes · SHA256 `310e3251e910ac8c7c6f34d0e50d85c4a0ecbbadd65e69fe4f5071370931a918`. PDF 헤더와 실제 git blob `af35caf0aec471085bf3e738f25c30122538a0b3`이 [#598 지정 제출 head](https://github.com/edwardkim/rhwp/blob/8b0bcde745f7b78a5b1fbe2122238a57696b1feb/pdf/issue8371/hwp3-sample10-2020.pdf)의 객체와 일치했다. |
| 고운바탕 Regular/Bold·OFL·METADATA | #598 provenance의 4개 size/SHA256이 모두 일치했다. |
| 실제 설치 글꼴 | 사용자 Fonts에서 Pretendard OTF·Hack TTF 파일을 확인했다. 딸기 대응 실물은 식별하지 못했다. 활성 CoreText 후보와 실제 bytes는 3단계 probe로 판정한다. |

## 후보 생성 시 확인할 사항

- 앱 native bridge는 `RustBridge/src/font_context.rs`에서 이미 구성한 layer tree의 run 요청을 모아 선택한 bytes를 glyph sidecar로 낮춘다. 이 경로의 성공만으로 HFT 파일을 조판 전에 사용해 줄바꿈까지 일치했다고 판정할 수 없다. 실제 조판·glyph·프로그램 증거를 비교한다.
- upstream의 `prepareDeclaredFontEnvironment`는 host provider가 있는 경우 브라우저 local() 자동 환경을 적용하지 않는다. host 공급 변경은 `onHostFontsChanged`에서 측정 캐시 무효화와 renderer revision 갱신으로 이어진다. 이 연결의 제품 결과는 실제 앱에서 검사한다.
- 새 Studio 소스가 `rhwp-shared/forms`, `rhwp-shared/pdf`, `assets/fonts`를 상대 경로로 import한다. 기존 앱 typecheck helper의 임시 디렉터리에는 src/types만 복제된다. 공식 pkg 빌드 후 컴파일 진단으로 실제 영향을 확인한다.
- 새 upstream의 T7 라우팅은 세 경로 모두 연결됐고 pending이 없다. 의존성 설치 중 npm이 교체한 node_modules 링크도 설치 종료 후 사용 여부·파일 해시를 확인해 T7로 복원했다. 앱 전용 산출물과 #594 자료는 서로 다른 경로에 있다.

다음 단계는 공식 pin·universal bridge·WASM·Studio·matcher·receipt를 생성하고 검증된 파일을 #594에 인계하는 작업이다.
