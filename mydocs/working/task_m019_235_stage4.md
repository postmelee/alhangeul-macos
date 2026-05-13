# Task M019 #235 Stage 4 완료 보고서

## 단계 목적

Stage 2/3 변경이 정상 viewer runtime 완화와 fatal fallback 기준을 함께 만족하는지 통합 build와 smoke로 확인한다.

이번 단계는 검증과 보고 단계이며 제품 소스는 변경하지 않았다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/orders/20260513.md` | Stage 4 완료 후 Stage 5 승인 대기 상태 반영 |
| `mydocs/working/task_m019_235_stage4.md` | 본 Stage 4 통합 회귀 검증 보고서 |

참조한 산출물:

| 경로 | 용도 |
|------|------|
| `build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app` | Stage 4 통합 Debug 앱 |
| `build.noindex/Task235Stage4ResourceFault/Alhangeul.app` | WASM asset 누락 fatal fallback 확인용 임시 앱 복사본 |
| `/private/tmp/task235-empty.hwp` | 빈 문서 open event 확인용 synthetic 파일 |
| `/private/tmp/task235-truncated.hwp` | 잘린 문서 open event 확인용 synthetic 파일 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 소스 변경 없음.
- `project.yml`, `Alhangeul.xcodeproj`, 샘플 문서, bundled viewer asset 변경 없음.
- 임시 앱 복사본은 `build.noindex/` 아래에만 만들었다.
- synthetic 문서는 `/private/tmp/` 아래에만 만들었다.

## 검증 결과

### Source asset verifier

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

### Debug build

첫 실행:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask235 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: SwiftPM manifest/cache가 홈 캐시에 쓰려다 sandbox 제한으로 실패했다.

```text
error opening '/Users/melee/.cache/clang/ModuleCache/Swift-BF86GRDXI25I.swiftmodule' for output: Operation not permitted
cannot open file '/Users/melee/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading/sparkle.dia' for diagnostics emission
```

승인된 권한 재실행 결과:

```text
** BUILD SUCCEEDED ** [2.754 sec]
```

### Built app asset verifier

```bash
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과:

```text
OK: rhwp-studio assets verified at build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

추가 확인:

```text
index.html 존재: 통과
rhwp_bg-*.wasm 개수: 1
```

## 정상 runtime smoke

실행 앱:

```text
build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app
```

절차:

1. 앱을 먼저 실행했다.
2. 실행 중인 앱에 `samples/exam_social.hwp` open event를 전달했다.
3. `exam_social.hwp — 4페이지`, `1 / 4 쪽` 표시를 확인했다.
4. 상단 `성명` 입력칸을 선택했다.
5. `a` 입력으로 nonfatal runtime banner를 유도했다.
6. banner 표시 중 `b` 입력으로 같은 runtime 오류를 반복 유도했다.
7. 첫 표시 기준 약 5초 뒤 banner가 사라지는 것을 확인했다.

결과:

- 전체 fatal fallback으로 전환되지 않았다.
- 문서 화면은 유지됐다.
- banner 문구는 다음과 같았다.

```text
입력을 처리하지 못했습니다. 문서는 계속 볼 수 있습니다.
```

참고: `open -n -a Alhangeul.app samples/exam_social.hwp`처럼 앱 실행과 문서 전달을 한 명령으로 수행한 첫 시도에서는 `timeout` fatal fallback이 발생했다. Stage 1-3과 동일하게 앱 실행 후 sample open event를 별도로 전달하면 정상 로드됐다. 이 동작은 이번 코드 변경 범위 밖의 open event 타이밍 이슈로 보이며, Stage 5 최종 보고서의 잔여 위험에 남긴다.

## Resource fatal fallback smoke

정상 Debug app을 `build.noindex/Task235Stage4ResourceFault/Alhangeul.app`로 복사한 뒤 다음 WASM asset을 `.disabled`로 이동했다.

```text
rhwp_bg-BZNodj2e.wasm
```

깨진 복사본에 대해 verifier가 실패하는 것을 먼저 확인했다.

```bash
scripts/verify-rhwp-studio-assets.sh \
  build.noindex/Task235Stage4ResourceFault/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과:

```text
FAIL: expected one WASM asset, found 0
```

이후 깨진 앱 복사본으로 `samples/exam_social.hwp`를 열었다.

결과:

```text
웹 viewer 자산을 찾을 수 없습니다
설치본에 viewer 필수 파일이 빠져 있어 문서를 표시할 수 없습니다.
```

resource preflight failure는 nonfatal banner로 완화되지 않고 fatal fallback으로 유지됐다.

## Document open failure smoke

다음 synthetic 파일을 만들어 정상 Debug app에 open event를 전달했다.

```text
/private/tmp/task235-empty.hwp
/private/tmp/task235-truncated.hwp
```

결과:

- 두 파일 모두 `HWP 파일을 선택해주세요.` placeholder 상태에 머물렀다.
- `exam_social.hwp`와 달리 open event가 document loader까지 전달된 흔적을 화면에서 확인하지 못했다.
- fatal fallback 또는 nonfatal banner 어느 쪽도 표시되지 않았다.

따라서 이번 단계에서는 document load fatal 경로를 수동 smoke로 확정하지 못했다. 다만 Stage 2/3 변경은 runtime failure 분류와 banner dedupe에 한정되어 document open validation 경로를 수정하지 않았고, 재현 가능한 resource fatal 경로는 유지됨을 확인했다.

## 사용자가 직접 테스트할 앱

직접 확인할 앱 경로:

```text
/Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedDataTask235/Build/Products/Debug/Alhangeul.app
```

권장 확인 순서:

1. 위 앱을 실행한다.
2. `samples/exam_social.hwp`를 연다.
3. 첫 페이지 상단 `성명` 칸을 더블 클릭한다.
4. 임의의 문자 입력을 반복한다.
5. 문서 화면이 유지되고, `입력을 처리하지 못했습니다. 문서는 계속 볼 수 있습니다.` banner가 표시되는지 확인한다.
6. 같은 오류를 빠르게 반복해도 banner가 계속 연장되지 않고 첫 표시 기준으로 사라지는지 확인한다.

## 잔여 위험

- `open -n -a 앱 경로 파일 경로` 형태로 앱 실행과 문서 전달을 한 번에 수행하면 `timeout` fallback이 재현됐다. 앱 실행 후 sample open event를 별도로 전달하는 경우는 정상이다.
- synthetic 손상 문서 open event는 loader까지 도달한 화면 증거를 확보하지 못했다.
- upstream `rhwp` #850 원인은 그대로 남아 있다.
- resource fatal smoke용 깨진 앱 복사본은 `build.noindex/Task235Stage4ResourceFault/Alhangeul.app`에 남아 있다. 제품 산출물과 소스에는 영향이 없다.

## 다음 단계 영향

Stage 5에서는 Stage 1-4 결과를 최종 보고서로 묶고, #235 처리 결과와 upstream #850 잔여 범위를 release blocker 처리 기록으로 정리한다.

## 승인 요청

Stage 4 결과를 승인하면 Stage 5 `release 기록과 최종 보고`로 진행한다.
