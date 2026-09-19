# Mac 설치 글꼴 최소 연결 실험 — Task #565 Stage 3

제품 코드·고정 rhwp checkout·사용자 설치 글꼴을 수정하지 않는 독립 WKWebView probe다. 고정 소스를 esbuild로 직접 묶으며 bundled minified JS를 패치하지 않는다. 테스트 문서는 합성 `PageLayerTree` 두 textRun이고, HWP/HWPX 파싱·편집·출력 통합 검증은 아니다.

## 준비와 재현

macOS, Swift, Node/npm, `rhwp-core.lock`과 같은 commit의 깨끗한 rhwp checkout이 필요하다. 활성 설치된 `NanumSquareR`와 `NanumSquareB`를 사용한다. 없으면 실패하며 사용자 글꼴을 자동 설치하지 않는다. 원본 글꼴은 저장소나 출력 폴더에 복사하지 않는다.

```bash
mkdir -p build.noindex/task565-stage3/tools
cp Tests/InstalledFontConnectionProbe/package*.json build.noindex/task565-stage3/tools/
npm ci --prefix build.noindex/task565-stage3/tools --ignore-scripts --no-audit --no-fund
RHWP_PROBE_CORE=/absolute/path/to/pinned/rhwp scripts/probe-installed-font-connection.sh
```

같은 명령을 다시 실행하면 `results/snapshot.json`을 새 프로세스에서 복원한다. `FONT_CONNECTION_RESULTS`로 새 결과 폴더를 지정하면 cold 실행을 분리할 수 있다. `PROBE_APP_SUFFIX=-adhoc`으로 앱 산출물 이름을 구분할 수 있다. 결과는 `build.noindex/task565-stage3` 아래 JSON·렌더링 PNG로 기록한다.

signed sandbox는 `PROBE_SIGN_ID`에 사용자가 승인한 로컬 코드 서명 인증서 이름을 추가한다. App Sandbox entitlement만 사용하며 공증·제품 배포·Quick Look 등록을 하지 않는다. 이 모드의 결과는 probe 자체 sandbox의 Application Support/Task565ConnectionProbe에 저장된다. 키체인 인증은 사용자가 수행한다.

## 측정 경계

- native CoreText 활성 목록에서 PS 이름이 일치하는 두 face를 골라 family/full/PS/style을 공급한다. 원본은 native의 ID→URL 목록으로만 접근하며 WebView에는 경로를 보내지 않는다.
- 실험 전용 `queryLocalFonts`와 `chrome.storage.local` adapter로 기존 감지·매칭·필요 bytes 로딩을 연결한다. 제품에 브라우저 API를 위장 설치하라는 설계가 아니다.
- 목록 열거에는 `blob`을 생략하여 모든 글꼴의 전체 바이트를 읽지 않는다. 따라서 이름 보강도 생략되며 한글/영문 alias 완전성은 미검증이다. 제품에서는 native 메타데이터 주입 계약을 정식으로 정의해야 한다.
- 실제 요청에서만 ID로 읽는다. 크기 제한·활성 PS·원본 PS 확인은 최소 방어이며 TOCTOU/동명 버전/전체 형식 검증은 제품 구현을 대신하지 않는다.
- `findPreparedTypeface` 관찰 wrapper는 원래 함수에 그대로 위임한다. 실제 선택된 local 객체와 PS/faceKey를 기록하며 정상 렌더 PNG와 native 원본 hash를 대조한다.
- CSS `local()` 성공은 별도 관찰 값이다. CanvasKit 성공은 native bytes와 upstream renderer 선택으로 판정한다.
- `missing`/`denied`는 주입 오류다. `corruptRaw`는 실제 원본 대신 메모리에서 만든 손상 바이트를 공급하여 renderer의 수용 여부를 관찰한다. `corrupt`는 같은 바이트를 native PS 검증에서 거부한다. 사용자 파일을 삭제하거나 권한을 변경하지 않는다.
- 정상 cold/warm/재실행, 동시 요청 병합, 모호한 family·없는 이름, reset 전 stale cache와 reset 후 fallback·복구를 검증한다.
- 스크립트 성공은 이 최소 연결의 성공이다. TTC/가변, 같은 PS의 다른 버전, 사용자 Fonts/외부 경로 권한, 자동 설치 알림, 실제 문서·출력은 별도 검증 대상이다.

## 산출물

- `result-{pid}.json`: 카탈로그·선택·단계별 요청/읽기 수·원본 지문·오류 대조·실행 환경.
- `render-{pid}.png`: 정상 CanvasKit 렌더 결과. 제품 설정 화면 스크린샷이 아니다.
- `snapshot.json`: 기존 rhwp 형식의 메타데이터만 저장. bytes는 저장하지 않는다.

권한 부재와 라이선스 부재는 다르다. 설치 사실이나 PS·fsType·사용자 동의만으로 사용/복사 허가를 주장하지 않는다.
