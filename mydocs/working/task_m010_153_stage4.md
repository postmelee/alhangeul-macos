# Task #153 Stage 4 보고서

## 단계 목적

Task #153의 native Finder drag/drop URL 확보 구현을 빌드된 macOS 앱에서 smoke 검증한다. 핵심 확인 대상은 Finder drag/drop 후 `공유하기`, `Finder에서 보기`, `PDF로 내보내기` toolbar item이 모두 활성화되고, `Finder에서 보기`가 실제 원본 파일을 선택하는지 여부다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m010_153_stage4.md` | Stage 4 빌드 및 toolbar smoke 검증 결과 정리 |
| `mydocs/orders/20260506.md` | Task #153 상태를 Stage 4 보고 승인 대기로 갱신 |

소스 파일 변경은 없다. Stage 4 검증용 helper는 ignored 영역인 `build.noindex/` 아래에서만 사용했다.

## 검증 환경

| 항목 | 값 |
|------|----|
| 앱 | `build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app` |
| 프로세스 | `AlhangeulMacHost` |
| Finder drag/drop HWP | `/private/tmp/rhwp-task153-drag/task153_unique.hwp` (`samples/exam_science.hwp` 복사본) |
| native open HWP | `samples/exam_math.hwp` |
| native open HWPX | `samples/table-vpos-01.hwpx` |
| UI 상태 확인 | Accessibility helper (`build.noindex/gui_smoke`) |

## 검증 결과

### 1. 공유 Swift 경계 검사

실행 명령:

```bash
scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### 2. HostApp Debug build

실행 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [0.327 sec]
```

Xcode가 CoreSimulatorService 관련 환경 경고를 출력했지만 macOS HostApp build는 성공했다.

### 3. 빈 상태 baseline

실행 결과:

```text
baseline:
- 공유: disabled
- Finder에서 보기: disabled
- PDF로 내보내기: disabled
```

### 4. Finder drag/drop HWP

첫 시도에서는 Finder/App/Codex 창이 겹쳐 drop target이 앱 창이 아닌 다른 창 위에 놓였고 문서 로드가 발생하지 않았다. 앱 창을 오른쪽, Finder 임시 샘플 창을 왼쪽에 배치한 뒤 `/private/tmp/rhwp-task153-drag/task153_unique.hwp`를 앱 viewer 영역으로 다시 drag/drop했다.

성공한 drag 좌표:

```text
drag-source: 60,299
drag-target: 1350,596
```

toolbar 상태:

```text
after-visible-finder-drag:
- 공유: enabled
- Finder에서 보기: enabled
- PDF로 내보내기: enabled
```

`Finder에서 보기` 실행 결과:

```text
press-toolbar Finder에서 보기: enabled
/private/tmp/rhwp-task153-drag/task153_unique.hwp
```

결론: Finder drag/drop에서 native file URL이 `sourceDocument`로 연결되어 `Finder에서 보기`가 활성화되고, 실행 시 원본 파일이 Finder selection으로 선택된다.

### 5. native open HWP

실행 명령:

```bash
open -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app \
  /Users/melee/Documents/projects/rhwp-mac/samples/exam_math.hwp
```

toolbar 상태:

```text
after-native-open:
- 공유: enabled
- Finder에서 보기: enabled
- PDF로 내보내기: enabled
```

### 6. native open HWPX

실행 명령:

```bash
open -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app \
  /Users/melee/Documents/projects/rhwp-mac/samples/table-vpos-01.hwpx
```

toolbar 상태:

```text
after-hwpx-native-open:
- 공유: enabled
- Finder에서 보기: enabled
- PDF로 내보내기: enabled
```

## 미실행 또는 제한

| 항목 | 상태 | 이유 |
|------|------|------|
| source-less JS/File drop fallback smoke | 미실행 | Finder drag/drop은 이제 native URL 경로로 선점되어야 하므로, source-less fallback을 실제 UI에서 따로 만들지 않았다. 기존 JS fallback 코드는 유지되어 있고 Stage 3 duplicate guard만 추가했다. |
| HWPX Finder drag/drop | 미실행 | native open HWPX toolbar 상태만 확인했다. |

## 잔여 위험

- `build.noindex/gui_smoke` helper는 검증용 임시 산출물이며 커밋 대상이 아니다.
- source-less fallback은 이번 smoke에서 직접 재현하지 못했으므로 최종 보고서에 잔여 미검증 항목으로 남긴다.
- Finder drag/drop smoke는 창 배치가 실제 앱 window 위로 정확히 떨어질 때 성공했다. 창이 겹친 상태에서는 OS drag target이 다른 창으로 잡혀 실패할 수 있다.

## 다음 단계 영향

Stage 5에서는 문서 정리와 최종 보고 준비를 수행한다. 최종 보고서에는 Finder drag/drop 성공 결과, `Finder에서 보기` 원본 selection 확인, source-less fallback 미실행 항목을 함께 기록한다.

## 승인 요청

Stage 4 빌드 및 toolbar smoke 검증을 완료했다. 이 보고서 기준으로 Stage 5 최종 문서 정리와 PR 준비에 진입할지 승인 요청한다.
