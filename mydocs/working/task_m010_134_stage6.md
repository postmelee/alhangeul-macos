# Task #134 Stage 6 완료 보고서

## 단계 목적

수동 테스트에서 확인된 WKWebView viewer 표시 문제를 보정한다. 증상은 `rhwp-studio`가 styled app UI로 보이지 않고, HTML 메뉴 항목이 plain text처럼 세로로 펼쳐지는 것이다.

## 원인

`rhwp-studio` production `index.html`의 JS/CSS tag에 `crossorigin` attribute가 남아 있었다.

```html
<script type="module" crossorigin src="./assets/index-CCXookfl.js"></script>
<link rel="stylesheet" crossorigin href="./assets/index-ro3nVBB2.css">
```

HostApp은 app bundle 내부 `rhwp-studio/index.html`을 `WKWebView.loadFileURL(_:allowingReadAccessTo:)`로 로드한다. 이 file URL 환경에서 explicit `crossorigin` subresource request가 보수적으로 처리되면서 CSS/JS가 적용되지 않았고, 결과적으로 정적 HTML 구조만 표시되었다.

## 산출물

- `Sources/HostApp/Resources/rhwp-studio/index.html`
  - JS/CSS tag의 `crossorigin` attribute 제거
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
  - 변경된 `index.html` sha256과 total bytes 반영
- `scripts/sync-rhwp-studio.sh`
  - upstream dist 동기화 후 `index.html`에서 `crossorigin` attribute를 제거하는 WKWebView 후처리 추가
- `scripts/verify-rhwp-studio-assets.sh`
  - `index.html`에 `crossorigin`이 남아 있으면 실패하도록 검증 추가
- `mydocs/working/task_m010_134_stage6.md`
  - Stage 6 완료 보고서
- `mydocs/report/task_m010_134_report.md`
  - 최종 보고서에 QA 보정 기록 추가
- `mydocs/orders/20260503.md`
  - #134 비고를 QA 보정 완료 상태로 갱신

## 검증 결과

```bash
$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task134/Sources/HostApp/Resources/rhwp-studio
```

결과: 성공.

```bash
$ rg -n "crossorigin" Sources/HostApp/Resources/rhwp-studio/index.html
```

결과: 출력 없음.

```bash
$ shasum -a 256 Sources/HostApp/Resources/rhwp-studio/index.html
4bcec64910b0fdfcacb8bae593b614c4af76c3c4d3f1d2252372a3d1a4202a29  Sources/HostApp/Resources/rhwp-studio/index.html
```

결과: `manifest.json`의 `entrypoints.index_html.sha256`과 일치.

```bash
$ xcodegen generate
Created project at /tmp/rhwp-mac-task134/AlhangeulMac.xcodeproj
```

결과: 성공.

```bash
$ xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [0.413 sec]
```

결과: 성공. Xcode가 CoreSimulatorService/DVT 관련 경고를 출력했지만 macOS HostApp build 자체는 성공했다.

```bash
$ /usr/bin/open -n -a /private/tmp/rhwp-mac-task134/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app /private/tmp/rhwp-mac-task134/samples/통합재정통계\(2011.10월\).hwp
```

결과: 앱 실행 성공. 화면 캡처에서 plain HTML로 펼쳐지던 menu bar가 `rhwp-studio` CSS가 적용된 toolbar/menu UI로 표시됨을 확인했다.

```bash
$ test -f build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/index.html
$ rg -n "crossorigin" build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/Resources/rhwp-studio/index.html
```

결과: app bundle의 `index.html` 존재 확인, `crossorigin` 검색 출력 없음.

## 잔여 위험

- 이번 단계는 `rhwp-studio` shell의 CSS/JS asset loading 문제를 보정했다.
- 특정 HWP/HWPX 문서의 실제 페이지 렌더 품질, blank page 여부, zoom/page 동작은 별도 샘플별 QA가 필요하다.
- 완전 offline 정책과 service worker/PWA 산출물의 필요 여부는 아직 후속 검토 대상이다.

## 다음 단계 영향

수정된 Debug 앱은 현재 실행되어 있어 작업지시자가 바로 수동 테스트할 수 있다. PR 게시 전에는 이 Stage 6 커밋까지 포함해 `devel-webview`에 push한다.
