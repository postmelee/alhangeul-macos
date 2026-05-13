# Task M018 #183 Stage 1 완료 보고서

## 단계 목적

`v0.1.0` 설치본과 현재 `local/task183` Debug build에서 창 확대/resize WebView runtime fallback 재현 여부를 확인하고, Stage 2 원인 분리에 필요한 진단 정보를 수집했다.

이번 단계는 진단 단계다. 제품 코드 변경은 하지 않았고, 설치본과 Debug build의 bundle metadata, `rhwp-studio` asset verifier, 실제 UI fallback disclosure 값을 대조했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m018_183_stage1.md` | 설치본/current build 재현 결과, runtime 진단 값, 검증 결과, Stage 2 입력 정리 |
| `mydocs/orders/20260509.md` | #183 상태를 Stage 1 완료 및 Stage 2 승인 대기로 갱신 |

## 이슈와 선행 작업 대조

이슈 #183의 재현 조건은 다음과 같다.

- `v0.1.0` GitHub Release DMG 설치본
- `/Applications/Alhangeul.app`
- HWP/HWPX 문서 열기
- title bar 영역 더블 클릭 또는 창 확대
- `웹 viewer 실행 중 오류가 발생했습니다` fallback 표시

#150에서 도입된 runtime fallback category는 JavaScript/WASM runtime error를 fatal fallback으로 승격한다. #150 Stage 4에서는 `registerSW.js` service worker rejection false positive를 known benign issue로 필터링했지만, `ResizeObserver` 계열 browser warning/error는 필터링 대상이 아니었다.

## 설치본 상태

`/Applications/Alhangeul.app`은 실제 `v0.1.0` 설치본이다.

| 항목 | 값 |
|------|----|
| `CFBundleShortVersionString` | `0.1.0` |
| `CFBundleVersion` | `1` |
| `CFBundleIdentifier` | `com.postmelee.alhangeul` |
| signing TeamIdentifier | `XH6JHKYXV8` |
| Hardened Runtime | enabled (`flags=0x10000(runtime)`) |
| sealed resources | version 2, files 63 |

설치본 bundled `rhwp-studio` manifest:

| 항목 | 값 |
|------|----|
| `source_release_tag` | `v0.7.10` |
| `source_resolved_commit` | `62a458aa317e962cd3d0eec6096728c172d57110` |
| main JS | `assets/index-BN69C-Lp.js` |
| main CSS | `assets/index-ro3nVBB2.css` |
| WASM | `assets/rhwp_bg-BZNodj2e.wasm` |

설치본 asset verifier:

```text
OK: rhwp-studio assets verified at /Applications/Alhangeul.app/Contents/Resources/rhwp-studio
```

source asset verifier:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

## 설치본 재현 결과

### HWP: `samples/basic/KTX.hwp`

초기 로드 상태:

- WebView URL: `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=KTX.hwp`
- status text: `KTX.hwp — 1페이지`
- toolbar: 공유, Finder에서 보기, PDF로 내보내기 활성

창 확대 동작:

- Computer Use에서 window zoom secondary action 실행
- 결과: fatal fallback 표시

fallback 문구:

```text
웹 viewer 실행 중 오류가 발생했습니다
JavaScript 또는 WASM runtime 오류로 viewer가 정상 상태가 아닙니다.
```

진단 정보:

```text
message=ResizeObserver loop completed with undelivered notifications.
sourceURL=alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=KTX.hwp
line=0
column=0
```

관찰:

- document payload URL과 revision은 정상이다.
- resource/document scheme failure가 아니라 `window.error` runtime bridge로 들어온 browser-level ResizeObserver event다.
- fallback 진입 후 공유/PDF toolbar command는 비활성화되고 Finder에서 보기는 유지된다.

### HWPX: `samples/hwpx/hwpx-01.hwpx`

초기 로드 상태:

- WebView URL: `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=hwpx-01.hwpx`
- status text: `hwpx-01.hwpx — 9페이지`
- toolbar: 공유, Finder에서 보기, PDF로 내보내기 활성

창 확대 동작:

- Computer Use에서 window zoom secondary action 실행
- 결과: fallback 없이 viewer 유지
- status text: `hwpx-01.hwpx — 9페이지`

관찰:

- 같은 설치본에서도 샘플 문서와 레이아웃 상태에 따라 재현성이 다르다.
- 문제는 HWP/HWPX 형식 전체나 app bundle asset 누락이 아니라 특정 resize/layout cycle에서 발생하는 runtime event 처리 경로로 보인다.

## current Debug build 비교

Debug build 명령은 최초 sandbox 안에서 Sparkle package resolve 네트워크 실패로 중단됐다.

```text
Failed to clone repository https://github.com/sparkle-project/Sparkle
Could not resolve host: github.com
```

승인된 네트워크 실행으로 재시도했고, Sparkle `2.9.1` resolve 후 build가 성공했다.

```text
** BUILD SUCCEEDED ** [6.798 sec]
```

Debug app bundle:

- path: `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app`
- `CFBundleShortVersionString`: `0.1.0`
- `CFBundleVersion`: `1`
- SDK: `macosx26.4`

Debug app bundle asset verifier:

```text
OK: rhwp-studio assets verified at build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

### Debug HWP: `samples/basic/KTX.hwp`

초기 로드 상태:

- WebView URL: `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=KTX.hwp`
- status text: `KTX.hwp — 1페이지`

창 확대 동작:

- Computer Use에서 window zoom secondary action 실행
- 결과: 설치본과 같은 fatal fallback 표시

진단 정보:

```text
message=ResizeObserver loop completed with undelivered notifications.
sourceURL=alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=KTX.hwp
line=0
column=0
```

`다시 시도`를 누르면 같은 payload가 재로드되어 viewer가 다시 표시됐다. 이후 title bar double click으로 창을 원복하는 동작에서는 fallback이 다시 뜨지 않았다. 재현성이 있는 trigger는 초기 작은 창에서 큰 창으로 확대되는 resize cycle이다.

## runtime/log 관찰

`/usr/bin/log show --last 15m --style compact --predicate 'process == "Alhangeul" AND eventMessage CONTAINS "ResizeObserver"'` 결과는 header만 출력됐다.

```text
Timestamp               Ty Process[PID:TID]
```

즉 `ResizeObserver loop completed with undelivered notifications.`는 unified log가 아니라 WebView의 page-level runtime event로 native bridge에 전달되는 값이다. Stage 2에서는 `RhwpStudioHostBridgeScript.runtimeErrorSource`의 `window.addEventListener("error", ...)` 경로와 브라우저 ResizeObserver loop notification의 성격을 중심으로 분리한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드 변경 없음.
- 설치본과 Debug app bundle은 진단 실행 대상으로만 사용했고 수정하지 않았다.
- 기존 문서 본문 삭제 없음.
- `mydocs/orders/20260509.md`는 #183 비고만 Stage 1 완료 상태로 갱신했다.

## 검증 결과

```bash
git status --short --branch
```

초기 상태:

```text
## local/task183
```

```bash
gh issue view 183 --repo postmelee/alhangeul-macos --json number,title,state,milestone,body
```

결과: #183은 `OPEN`, milestone은 `v0.1.1`, 범위는 설치본 창 확대/resize runtime error 진단과 수정이다.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

```bash
scripts/verify-rhwp-studio-assets.sh /Applications/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과:

```text
OK: rhwp-studio assets verified at /Applications/Alhangeul.app/Contents/Resources/rhwp-studio
```

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

최초 current build 비교용 결과:

```text
** BUILD SUCCEEDED ** [6.798 sec]
```

보고서 작성 후 Stage 1 검증 재실행 결과:

```text
** BUILD SUCCEEDED ** [4.437 sec]
```

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- Stage 1은 재현과 진단 단계이므로 아직 수정하지 않았다.
- HWPX 샘플은 설치본 window zoom에서 재현되지 않았다. HWPX에서도 다른 문서나 다른 window 크기에서는 재현될 가능성이 남는다.
- unified log에는 ResizeObserver message가 남지 않아, 자동화된 로그 기반 감지는 어렵다. Stage 4 smoke는 UI 상태와 fallback disclosure 중심으로 확인해야 한다.
- 현재 build와 설치본 모두 같은 증상을 보이므로 Stage 2/3 수정은 current code path에 필요하다.

## 다음 단계 영향

Stage 2에서는 다음 경로를 우선 분석한다.

- `RhwpStudioHostBridgeScript.runtimeErrorSource`의 `window.error` listener
- `isBenignRuntimeIssue(sourceURL, reason)` 필터 확장 여부
- ResizeObserver loop notification이 실제 문서 상태 손상을 의미하는지 여부
- HWP `KTX.hwp` 확대 시 발생하지만 HWPX `hwpx-01.hwpx` 확대 시 발생하지 않은 layout 차이
- runtime failure를 숨기지 않기 위한 narrow guard 조건

현재 관찰만으로는 resource/document scheme, signing/notarization, asset 누락 문제 가능성은 낮다.

## 승인 요청

Stage 1 완료를 승인하면 Stage 2 `원인 경로 분리와 수정안 확정`으로 진행한다.
