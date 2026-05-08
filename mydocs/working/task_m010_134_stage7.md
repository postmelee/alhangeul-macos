# Task M010 #134 Stage 7 보고서

## 단계 목적

Stage 6에서 `rhwp-studio` CSS/JS asset이 적용되어 plain HTML 상태는 해소됐지만, 수동 확인 중 toolbar/menu button이 반응하지 않는 증상이 이어졌다. 이 단계는 WKWebView 안에서 `rhwp-studio` JS 초기화와 WASM fetch가 끝까지 완료되도록 bundle resource 로딩 방식을 보정하는 단계다.

## 원인

`rhwp-studio` entry JS는 `Ha()` 초기화에서 `X.initialize()`를 기다린 뒤 menu/tab/toolbar event listener를 등록한다. CSS/JS 파일 자체가 로드되더라도 WASM 초기화가 실패하면 `new Pn(...)`과 `.tb-btn[data-cmd]` listener 등록까지 도달하지 못한다.

기존 Stage 6 상태는 app bundle의 `index.html`을 file URL로 열고, JS module이 같은 file URL 상대 경로의 `assets/rhwp_bg-*.wasm`을 fetch하는 구조였다. WKWebView file URL 환경에서는 subresource와 WASM fetch가 WebKit 정책에 걸릴 수 있어, UI shell은 보이지만 버튼 event listener가 붙지 않는 상태가 발생했다.

## 변경 내용

- `RhwpStudioResourceSchemeHandler`를 추가해 `alhangeul-studio://app/...` custom scheme으로 bundled `rhwp-studio` 정적 asset을 제공한다.
- HTML, JS, CSS, WASM, webmanifest, image, font asset에 필요한 MIME type을 명시해 WKWebView가 WASM과 module asset을 정상 해석하도록 했다.
- `RhwpStudioResourceLocator`의 entrypoint를 `alhangeul-studio://app/index.html?...`로 변경했다.
- `RhwpStudioWebView`가 `loadFileURL` 대신 `webView.load(URLRequest(url: ...))`로 custom scheme entrypoint를 로드하도록 바꿨다.
- 기존 `alhangeul-document://current?revision=...` document bytes scheme은 유지했다.
- navigation policy는 `alhangeul-studio://app`, `alhangeul-document://current`, `about`, `blob`, `data`만 허용하도록 유지했다.
- 아키텍처 문서와 `Sources/README.md`의 HostApp viewer 흐름을 custom resource scheme 기준으로 보정했다.

## 검증

```bash
./scripts/check-no-appkit.sh
```

결과: 성공.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과: 성공.

```bash
xcodegen generate
```

결과: 성공.

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED ** [0.430 sec]`.

```bash
/usr/bin/open -n -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/통합재정통계\(2011.10월\).hwp
```

결과: 단일 Debug app 인스턴스에서 `통합재정통계(2011.10월).hwp`가 `rhwp-studio` UI와 함께 렌더링되고 상태바에 파일명과 페이지 수가 표시됨을 화면 캡처로 확인했다.

추가로 `AXRaise` 후 상단 tab 좌표 click smoke를 수행해 WKWebView 내부 toolbar/menu 상태가 바뀌는 것을 확인했다. 이는 WASM 초기화 이후 `rhwp-studio` event listener 등록 경로에 도달했음을 확인하는 최소 수동 근거다.

## 잔여 위험

- 이번 검증은 수동 smoke 기준이다. 모든 toolbar command의 기능별 결과까지 자동화하지는 않았다.
- `rhwp-studio` 내부의 service worker 등록은 custom scheme 환경에서 실패할 수 있으나, MVP viewer의 bundled asset 직접 제공 경로에는 필수 조건이 아니다.
- 외부 URL을 여는 일부 `rhwp-studio` action은 HostApp navigation policy에서 별도 허용/위임 정책이 필요할 수 있다.

## 결론

WKWebView file URL 기반 asset 로딩을 `alhangeul-studio://app` custom resource scheme으로 전환해 `rhwp-studio` WASM/JS 초기화와 버튼 event listener 등록이 가능한 상태로 보정했다. HostApp Debug build와 샘플 문서 렌더링 smoke가 통과했다.
