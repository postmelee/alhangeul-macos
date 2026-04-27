# Issue #26 단계1 완료 보고서

## 단계 목표

Finder Thumbnail 경로에서 저해상도 embedded preview가 큰 요청에 그대로 확대되는 문제를 막기 위해 품질 게이트를 추가한다.

## 변경 내용

`Sources/Shared/HwpPageImageRenderer.swift`에 embedded preview 사용 여부를 판단하는 helper를 추가했다.

- `maximumPixelSize`가 없는 호출은 기존 동작을 유지한다.
- 요청 긴 변이 `128px` 이하이면 embedded preview fast path를 유지한다.
- 요청 긴 변이 큰 경우 embedded preview 긴 변이 요청 긴 변의 `75%` 이상일 때만 fast path를 사용한다.
- 기준을 만족하지 못하면 `decodeEmbeddedThumbnail`이 `nil`을 반환해 기존 full render fallback을 사용한다.

## 분기 확인

임시 probe 결과:

| 파일 | 요청 | 결과 이미지 | logical size | 판단 |
|------|------|-------------|--------------|------|
| `group-drawing-02.hwp` | `64px` | `45x64` | `177x250` | embedded preview 유지 |
| `group-drawing-02.hwp` | `512px` | `363x512` | `793x1122` | full render fallback |
| `pic-in-head-02.hwp` | `64px` | `45x64` | `724x1024` | embedded preview 유지 |
| `pic-in-head-02.hwp` | `512px` | `362x512` | `724x1024` | embedded preview 유지 |

## 검증 결과

### 코드 형식

```bash
git diff --check -- Sources/Shared/HwpPageImageRenderer.swift
```

결과: 통과

### Shared bridge 경계

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### Xcode project 재생성

```bash
xcodegen generate
```

결과: 성공

### HostApp Debug build

```bash
xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 성공

### Finder thumbnail smoke test

```bash
qlmanage -r cache
qlmanage -t -x -s 512 -o /tmp/rhwp-task26-ql-512 /Users/melee/Documents/samples/group-drawing-02.hwp
qlmanage -t -x -s 512 -o /tmp/rhwp-task26-ql-512 /Users/melee/Documents/samples/pic-in-head-02.hwp
qlmanage -t -x -s 64 -o /tmp/rhwp-task26-ql-64 /Users/melee/Documents/samples/group-drawing-02.hwp
```

결과: 모두 `produced one thumbnail`

생성 PNG 크기:

| 출력 | 크기 |
|------|------|
| `/tmp/rhwp-task26-ql-512/group-drawing-02.hwp.png` | `363x512` |
| `/tmp/rhwp-task26-ql-512/pic-in-head-02.hwp.png` | `362x512` |
| `/tmp/rhwp-task26-ql-64/group-drawing-02.hwp.png` | `46x64` |

## 추가 확인

Finder 직접 확인 결과, `group-drawing-02.hwp`는 full render fallback 후에도 Quick Look preview와 Finder thumbnail에서 group drawing 영역이 저해상도처럼 보인다. 따라서 이 단계의 변경은 embedded preview 확대 방어로 유지하고, 공통 렌더링 품질 문제는 Issue #35로 분리한다.

## 승인 요청 사항

이 단계 결과 기준으로 최종 보고서 작성과 #26 범위 축소 마무리를 승인 요청한다.
