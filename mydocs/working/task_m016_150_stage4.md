# Task M016 #150 Stage 4 완료 보고서

## 단계 목적

정상 Debug app bundle과 인위적으로 훼손한 app bundle 복사본에서 WKWebView viewer fallback 동작을 확인하고, smoke 절차를 build guide에 연결했다.

Stage 4 도중 정상 문서 smoke에서 `registerSW.js` service worker 등록 rejection이 runtime fatal fallback으로 과하게 승격되는 회귀를 발견했다. 이는 WKWebView custom scheme 환경에서 예상 가능한 PWA 부산물 오류라 문서 렌더 실패로 보지 않도록 runtime bridge에 known benign 필터를 추가한 뒤 smoke를 재수행했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | `registerSW.js` service worker registration rejection을 fatal runtime fallback에서 제외 |
| `mydocs/manual/build_run_guide.md` | WKWebView viewer 정상/negative smoke 절차 보강 |
| `mydocs/working/task_m016_150_stage4.md` | Stage 4 smoke 결과와 잔여 한계 기록 |
| `mydocs/orders/20260507.md` | #150 상태를 Stage 4 완료 및 Stage 5 승인 대기로 갱신 |

## 정상 smoke 결과

### HWPX

대상:

- app: `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app`
- sample: `samples/hwpx/hwpx-01.hwpx`

확인 결과:

- WebView URL: `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=hwpx-01.hwpx`
- 상태 표시: `hwpx-01.hwpx — 9페이지`
- toolbar: 공유, Finder에서 보기, PDF로 내보내기 활성
- fallback 표시 없음

### HWP

대상:

- app: `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app`
- sample: `samples/basic/KTX.hwp`

확인 결과:

- WebView URL: `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=KTX.hwp`
- 상태 표시: `KTX.hwp — 1페이지`
- toolbar: 공유, Finder에서 보기, PDF로 내보내기 활성
- fallback 표시 없음

## 발견한 회귀와 수정

초기 정상 HWPX smoke에서 다음 fatal fallback이 표시됐다.

```text
웹 viewer 실행 중 오류가 발생했습니다
JavaScript 또는 WASM runtime 오류로 viewer가 정상 상태가 아닙니다.
```

진단 정보:

```text
message=Unhandled promise rejection
sourceURL=alhangeul-studio://app/index.html
line=0
column=0
reason=register@[native code]
@alhangeul-studio://app/registerSW.js:1:106
```

원인은 `registerSW.js`의 service worker 등록 promise rejection이었다. WKWebView custom scheme에서는 service worker registration이 정상 렌더링과 무관하게 실패할 수 있으므로, `sourceURL` 또는 rejection detail에 `/registerSW.js`가 포함된 runtime issue는 native fatal fallback으로 전달하지 않도록 필터링했다.

수정 후 HWP/HWPX 정상 smoke를 재수행했고 fallback이 뜨지 않았다.

## negative smoke 결과

절차:

1. Debug app을 `build.noindex/stage4-negative.yQgYJ7/Alhangeul.app`로 복사했다.
2. 복사본의 `Contents/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm`만 `.missing`으로 rename했다.
3. 복사본 앱으로 `samples/hwpx/hwpx-01.hwpx`를 열었다.

확인된 fallback:

```text
웹 viewer 자산을 찾을 수 없습니다
설치본에 viewer 필수 파일이 빠져 있어 문서를 표시할 수 없습니다.
```

진단 정보:

```text
assetPattern=assets/rhwp_bg-*.wasm
count=0
directoryPath=/Users/melee/Documents/projects/rhwp-mac/build.noindex/stage4-negative.yQgYJ7/Alhangeul.app/Contents/Resources/rhwp-studio/assets
```

toolbar 상태:

- 공유: 비활성
- PDF로 내보내기: 비활성
- Finder에서 보기: 활성

retry 확인:

1. 같은 복사본에서 `.missing` 파일명을 원래 `.wasm`으로 되돌렸다.
2. fallback의 `다시 시도` 버튼을 눌렀다.
3. `hwpx-01.hwpx — 9페이지`가 표시되고 toolbar command가 활성화됐다.

## build guide 보강

`mydocs/manual/build_run_guide.md`의 HostApp WKWebView viewer smoke test를 다음 방향으로 보강했다.

- hash가 포함된 특정 WASM 파일명 대신 `rhwp_bg-*.wasm` pattern count를 사용한다.
- source resource뿐 아니라 Debug app bundle resource에도 `scripts/verify-rhwp-studio-assets.sh`를 실행하는 예시를 추가했다.
- source를 훼손하지 않고 app bundle 복사본만 수정하는 negative smoke 절차를 추가했다.
- negative smoke 기대 결과와 retry 확인 방법을 명시했다.

## 검증 결과

```bash
git diff --check
```

결과: 통과.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

```bash
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과:

```text
OK: rhwp-studio assets verified at build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [0.353 sec]
```

Xcode/CoreSimulator 경고는 계속 출력됐지만 macOS HostApp build는 성공했다.

## 미수행 / 한계

- document scheme mismatch는 제품 코드에 테스트 훅을 남기지 않는 범위에서 자연스럽게 재현하기 어렵다. Stage 4에서는 정상 문서 load URL의 `alhangeul-document://current?revision=1` 연결과 asset preflight negative smoke까지 확인했다.
- runtime error negative smoke는 별도 JS throw를 app bundle에 주입하지 않았다. 대신 정상 smoke에서 발견된 `registerSW.js` false positive를 수정해 실제 runtime bridge의 과잉 fatal 처리 리스크를 검증했다.
- signed/notarized 설치본 smoke는 #151 범위다. 이번 단계는 Debug app과 build artifact 복사본 기준으로만 수행했다.

## 다음 단계 영향

Stage 5에서는 최종 보고서에 다음을 정리한다.

- #150이 해결한 범위: WKWebView asset/document delivery/runtime fallback
- #149로 남길 범위: 손상·대용량 HWP/HWPX opening fallback
- #151로 넘길 범위: 설치본 Quick Look/Thumbnail 및 signed package smoke gate
- #146로 넘길 범위: WKWebView viewer/runtime fallback의 알려진 한계

## 승인 요청

Stage 4 완료를 승인하면 Stage 5 `최종 보고와 M16 release gate 연결`로 진행한다.
