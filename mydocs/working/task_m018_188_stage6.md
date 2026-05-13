# Task M018 #188 Stage 6 작업 보고서

## 단계 목적

public `v0.1.1` 설치본에서 재현된 Quick Look preview와 Finder thumbnail 크래시를 수정하고, `v0.1.1` respin 전에 source-level 검증 기준을 확정한다.

확인 시각: `2026-05-11 04:33 KST`

## 문제 요약

작업지시자의 clean install 재현 결과:

| 항목 | 결과 |
|------|------|
| Quick Look preview | 동작하지 않음. 파일 정보 카드와 작은 썸네일만 표시 |
| Finder thumbnail | 일부 파일에서 깨진 bitmap 또는 fallback 표시 |
| 설치 후 macOS 훑어보기 등록 알림 | 표시되지 않음 |
| About window | extension은 앱에 포함됐지만 시스템 등록은 확인 불가로 표시 |

추가 확인 결과, extension 등록 자체는 성공했다. 실제 실패 지점은 Quick Look/Thumbnail provider가 `HwpPageImageRenderer`에서 bitmap을 그리다가 `EXC_BAD_ACCESS`로 종료되는 경로였다.

## 원인

`HwpPageImageRenderer.renderPage(...)`가 Swift 배열을 다음 형태로 `CGContext` backing store에 넘겼다.

```swift
var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)
CGContext(data: &pixels, ...)
```

이 방식은 Swift 배열의 저장소 수명을 CoreGraphics bitmap context가 기대하는 C memory buffer 수명과 명확히 맞추지 못한다. extension 프로세스에서 `CGContextFillRect` 또는 이후 텍스트 렌더링이 backing memory를 쓰는 동안 유효하지 않은 주소를 만질 수 있고, public `v0.1.1`에서 preview와 thumbnail이 모두 같은 renderer를 쓰기 때문에 두 extension 모두 크래시했다.

## 수정 내용

| 파일 | 변경 |
|------|------|
| `Sources/Shared/HwpPageImageRenderer.swift` | `CGContext(data: nil, bytesPerRow: 0, ...)`로 전환해 bitmap memory를 CoreGraphics가 소유하게 수정 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | OSLog 추가, request/PNG/PDF 분기/render ready/fallback/failure 로그 기록 |
| `Sources/ThumbnailExtension/HwpThumbnailProvider.swift` | OSLog 추가, request/render enqueue/ready/fallback/failure 로그 기록 |

Preview policy는 유지한다.

| 문서 | Quick Look reply |
|------|------------------|
| 단일 페이지 | PNG |
| 다중 페이지 | PDF |

단일 페이지가 현재 카드처럼 보인 이유는 PNG reply 자체가 아니라 provider crash다. PNG reply가 정상 완료되면 Quick Look은 첨부 영상처럼 문서 page preview를 표시할 수 있다.

## 검증 결과

| 명령/확인 | 결과 | 비고 |
|-----------|------|------|
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | OK | sandbox cache 권한 문제 후 로컬 권한으로 재실행 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/DerivedDataRelease CODE_SIGNING_ALLOWED=NO build` | OK | source-level Release build 통과 |
| `scripts/render-debug-compare.sh /private/tmp/alhangeul-render-debug-after-buffer-fix-recheck ...` | OK | `eq-01.hwp`, `group-drawing-02.hwp`, `footnote-01.hwp` 렌더 완료 |
| `scripts/render-debug-compare.sh /private/tmp/alhangeul-render-debug-after-buffer-fix-all-recheck /Users/melee/Desktop/files/*.hwp` | OK | `/Users/melee/Desktop/files`의 13개 HWP 샘플 렌더 완료 |
| PlugInKit active provider 경로 확인 | OK | 현재 시스템은 아직 public `/Applications/Alhangeul.app` extension을 사용 중 |

Renderer smoke 중 일부 문서에서 `LAYOUT_OVERFLOW*` diagnostic은 남았지만, 이는 기존 layout parity 이슈이며 이번 crash hotfix의 실패 조건은 아니다.

## 아직 완료되지 않은 항목

수정본은 아직 signed/notarized app으로 설치되지 않았다. 현재 Finder와 Quick Look은 public `v0.1.1` 설치본의 extension을 계속 실행하므로, 실제 설치본 smoke는 hotfix 산출물 생성 후 반복해야 한다.

다음 stage에서 필요한 검증:

1. hotfix commit 기준 signed/notarized DMG 또는 equivalent Developer ID signed app 생성
2. 기존 `/Applications/Alhangeul.app` 제거 후 clean install
3. PlugInKit active provider가 새 app bundle을 가리키는지 확인
4. `qlmanage -p -x`로 단일 페이지 PNG preview가 fallback 카드 없이 표시되는지 확인
5. `qlmanage -p -x`로 다중 페이지 PDF preview가 정상 표시되는지 확인
6. `qlmanage -t -x`와 Finder icon view로 thumbnail 확인
7. 새 `AlhangeulPreview`/`AlhangeulThumbnail` DiagnosticReports가 생기지 않는지 확인
8. Sparkle update 경로에서는 업데이트 후 새 extension이 active provider로 refresh되는지 확인

## 판단

이번 수정은 현재 빌드만 통과시키기 위한 편법이 아니다. CoreGraphics bitmap context의 memory ownership을 API가 보장하는 형태로 바꾼 것이고, Quick Look reply 정책도 기존 제품 설계와 사용자 기대에 맞게 유지했다.

다만 source-level smoke만으로 public 설치본 문제 해결을 완료로 볼 수는 없다. `v0.1.1` respin 전에는 반드시 signed/notarized 설치본 기준으로 Finder/Quick Look end-to-end smoke를 통과해야 한다.
