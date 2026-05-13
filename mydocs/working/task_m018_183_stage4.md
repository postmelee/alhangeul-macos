# Task M018 #183 Stage 4 완료 보고서

## 단계 목적

Stage 3 수정 후 Debug build 산출물에서 HWP/HWPX 문서의 창 확대, 원복, 수동 resize smoke를 수행해 fatal runtime fallback이 재발하지 않는지 확인했다.

이번 단계는 smoke 검증 단계다. 제품 코드 변경은 하지 않았고, 수동 UI 검증 결과와 자동 검증 명령 결과만 기록했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m018_183_stage4.md` | Stage 4 UI smoke와 자동 검증 결과 |
| `mydocs/orders/20260509.md` | #183 상태를 Stage 4 완료 및 Stage 5 승인 대기로 갱신 |

## 검증 대상

| 항목 | 값 |
|------|----|
| branch | `local/task183` |
| app bundle | `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app` |
| Xcode scheme | `HostApp` |
| HWP sample | `samples/basic/KTX.hwp` |
| HWPX sample | `samples/hwpx/hwpx-01.hwpx` |

UI smoke는 signed Debug build를 다시 만든 뒤 실행했다. Stage 4 계획서의 unsigned build 검증도 별도로 수행했다.

## 자동 검증 결과

```bash
git status --short --branch
```

결과:

```text
## local/task183
```

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [0.442 sec]
```

UI smoke용 signed Debug build:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [1.758 sec]
```

source asset verifier:

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

bundle asset verifier:

```bash
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과:

```text
OK: rhwp-studio assets verified at build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

```bash
git diff --check
```

결과: 출력 없음. 공백 오류 없음.

## HWP smoke: `KTX.hwp`

실행 명령:

```bash
/usr/bin/open -n -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
```

초기 상태:

| 항목 | 값 |
|------|----|
| WebView URL | `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=KTX.hwp` |
| status text | `KTX.hwp — 1페이지` |
| page indicator | `1 / 1 쪽` |
| section indicator | `구역: 1 / 1` |
| zoom display | `78%` |
| toolbar | 공유, Finder에서 보기, PDF로 내보내기 활성 |

수동 동작 결과:

| 동작 | 결과 |
|------|------|
| green zoom button의 accessibility secondary action `윈도우 확대/축소` | fallback 미표시, `KTX.hwp — 1페이지` 유지 |
| 같은 action으로 원복 | fallback 미표시, toolbar 활성 유지 |
| title bar double click 시도 | 현재 환경에서는 눈에 띄는 window size 변화 없음, fallback 미표시 |
| bottom-right edge drag resize | fallback 미표시, status와 toolbar 활성 유지 |

Stage 1에서 같은 `KTX.hwp` window zoom에서 보였던 `웹 viewer 실행 중 오류가 발생했습니다` fallback은 재현되지 않았다.

## HWPX smoke: `hwpx-01.hwpx`

실행 명령:

```bash
/usr/bin/open -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app /Users/melee/Documents/projects/rhwp-mac/samples/hwpx/hwpx-01.hwpx
```

초기 상태:

| 항목 | 값 |
|------|----|
| WebView URL | `alhangeul-studio://app/index.html?url=alhangeul-document://current?revision%3D1&filename=hwpx-01.hwpx` |
| status text | `hwpx-01.hwpx — 9페이지` |
| page indicator | `1 / 9 쪽` |
| section indicator | `구역: 1 / 2` |
| zoom display | `111%` |
| toolbar | 공유, Finder에서 보기, PDF로 내보내기 활성 |

수동 동작 결과:

| 동작 | 결과 |
|------|------|
| green zoom button의 accessibility secondary action `윈도우 확대/축소` | fallback 미표시, `hwpx-01.hwpx — 9페이지` 유지 |
| 같은 action으로 원복 | fallback 미표시, toolbar 활성 유지 |
| bottom-right edge drag resize | fallback 미표시, status와 toolbar 활성 유지 |

Stage 1에서 정상 경로였던 HWPX 창 확대 동작도 회귀하지 않았다.

## runtime fallback 회귀 판단

Stage 3의 필터는 exact ResizeObserver loop notification과 `reason == ""`, `line == 0`, `column == 0` 조건에 묶여 있다. 따라서 source line/column이 있는 JavaScript error, stack이 있는 `Error`, promise rejection의 `reason`은 여전히 native `runtime-error`로 전달된다.

이번 smoke에서는 HWP/HWPX 모두 fatal fallback UI가 표시되지 않았고, 문서 상태 표시와 toolbar command가 유지됐다.

## 특이 사항

- Computer Use가 처음에는 동일 bundle identifier를 가진 `/Applications/Alhangeul.app` 설치본 빈 창에 붙었다. Debug build smoke 대상을 명확히 하기 위해 문서가 열려 있지 않은 설치본 프로세스를 종료했고, 이후 Debug build process에서 검증했다.
- Stage 4 중 외부 checkout으로 현재 브랜치가 `main`으로 바뀐 것이 한 번 감지됐다. Stage 4 보고서 작성 전 `local/task183`로 복귀했고, source/bundle asset verifier와 `git diff --check`를 같은 브랜치에서 다시 통과시켰다.
- UI smoke 후 Debug app process는 사용자가 결과를 직접 볼 수 있도록 그대로 두었다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드 변경 없음.
- 기존 문서 본문 삭제 없음.
- `mydocs/orders/20260509.md`는 #183 비고만 Stage 4 완료 상태로 갱신한다.

## 다음 단계

Stage 5에서는 #183 최종 보고서를 작성하고, #188 `v0.1.1` release 실행에서 반복할 설치본 smoke 항목으로 `KTX.hwp` window zoom/resize 검증을 넘긴다.
