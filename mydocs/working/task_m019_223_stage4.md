# Task M019 #223 Stage 4 완료 보고서

## 단계 목적

Stage 2-3 변경 이후 정상 문서 표시 경로가 유지되는지 확인하고, fatal로 남아야 하는 fallback 경로가 계속 전체 오류 화면으로 전환되는지 회귀 검증했다. 또한 Stage 1에서 확인한 그림 선택 후 Space 입력 경로가 더 이상 전체 fallback으로 전환되지 않는지 화면 smoke로 확인했다.

## 실행 환경

| 항목 | 값 |
|------|-----|
| worktree | `/private/tmp/rhwp-mac-task223` |
| branch | `local/task223` |
| 앱 번들 | `build.noindex/DerivedDataStage3/Build/Products/Debug/Alhangeul.app` |
| 대상 샘플 | `samples/exam_science.hwp`, `samples/table-vpos-01.hwpx` |

동일 bundle identifier의 기존 실행 상태와 Launch Services 상태 복원을 피하기 위해 fresh launch는 `/usr/bin/open -n -F`로 수행했다. 파일 open event가 창 생성에 더 안정적이어서 일부 smoke는 앱을 먼저 띄운 뒤 AppleScript `open POSIX file`로 문서를 열었다.

## 자동 검증 결과

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage3 CODE_SIGNING_ALLOWED=NO build
```

결과: `** BUILD SUCCEEDED **`.

참고: 최초 sandbox 실행은 Xcode/SwiftPM 캐시 디렉터리 접근 제한으로 실패했다. 동일 명령을 권한 승격으로 재실행해 성공 결과를 확인했다.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과: 성공.

```bash
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedDataStage3/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과: 성공.

```bash
test -f build.noindex/DerivedDataStage3/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
```

결과: 성공.

```bash
find build.noindex/DerivedDataStage3/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/assets -maxdepth 1 -name 'rhwp_bg-*.wasm' -type f
```

결과: `rhwp_bg-BZNodj2e.wasm` 1개만 존재.

## 수동 smoke 결과

### 정상 HWP 표시

`samples/exam_science.hwp`를 Debug 앱에서 열었다. 화면에는 viewer toolbar와 문서 본문이 정상 표시됐고, 상태 영역에 `exam_science.hwp - 4페이지`가 표시됐다.

Stage 1 재현 경로도 다시 수행했다.

1. 7번 문항의 `[가설]` 박스 안 텍스트를 클릭했다.
2. 같은 줄의 작은 boxed/circled object를 클릭했다.
3. Space 키를 눌렀다.

결과: 전체 fallback 오류 화면으로 전환되지 않았고, 문서 화면과 toolbar가 유지됐다. smoke 화면에서 banner는 뚜렷하게 보이지 않았지만, 이번 작업의 1차 목표인 HostApp fatal fallback 전환은 발생하지 않았다.

### 정상 HWPX 표시

`samples/table-vpos-01.hwpx`를 Debug 앱에서 열었다. 문서 화면이 정상 표시됐고, 상태 영역에 `table-vpos-01.hwpx - 5페이지`와 페이지 표시 `1 / 5 쪽`이 유지됐다. 전체 fallback은 발생하지 않았다.

### missing WASM fatal fallback

검증용으로 Debug 앱을 `build.noindex/Stage4MissingWasm.app`에 복사한 뒤 bundled `rhwp_bg-BZNodj2e.wasm`을 `.missing`으로 변경했다.

```bash
scripts/verify-rhwp-studio-assets.sh build.noindex/Stage4MissingWasm.app/Contents/Resources/rhwp-studio
```

결과: 예상대로 실패.

```text
FAIL: expected one WASM asset, found 0
```

이 앱으로 `samples/exam_science.hwp`를 열면 전체 fallback 화면이 표시됐고, `웹 viewer 자산을 찾을 수 없습니다`, `설치본에 viewer 필수 파일이 빠져 있어 문서를 표시할 수 없습니다.` 문구를 확인했다.

### 빈 문서 fatal fallback

`build.noindex/empty-stage4.hwp` 빈 파일을 만든 뒤 fresh launch로 열었다. 전체 fallback 화면이 표시됐고, `비어 있는 문서는 열 수 없습니다.` 문구를 확인했다.

### ResizeObserver 계열 smoke

정상 `samples/exam_science.hwp` 표시 상태에서 System Events로 첫 번째 Alhangeul window 크기를 `{900, 620}`으로 변경했다. resize 후에도 문서 화면과 toolbar가 유지됐고 runtime fallback으로 전환되지 않았다.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `mydocs/orders/20260511.md` | 오늘할일 상태를 Stage 4 완료보고서 승인 대기로 갱신 |
| `mydocs/working/task_m019_223_stage4.md` | Stage 4 완료 보고서 추가 |

## 잔여 위험

- Stage 1 동작에서 전체 fallback은 사라졌지만, smoke 화면에서는 nonfatal banner가 명확히 보이지 않았다. underlying `rhwp-studio` 입력 상태 오류 자체는 upstream 영역으로 남아 있다.
- recoverable 분류 조건은 현재 bundled `index-*.js` line/column에 고정되어 있다. rhwp-studio asset 업데이트 작업에서는 Stage 1 source 위치를 다시 확인해야 한다.
- missing WASM 앱 복사본과 빈 문서 파일은 `build.noindex/` 아래 검증 산출물이며 git 추적 대상이 아니다.

## 다음 단계

Stage 4 결과를 승인하면 최종 보고서와 정리 단계로 진행한다.

## 승인 요청

Stage 4 산출물 승인을 요청한다.

승인 후 최종 보고서와 PR 게시 준비 단계로 진행한다.
