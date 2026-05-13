# Task M018 #188 Stage 5 정정 보고서

## 단계 목적

기존 public `v0.1.0` 설치본의 Sparkle 업데이트 확인, public `v0.1.1` DMG 재설치 후 앱/Quick Look/Thumbnail smoke를 확인하고, 설치 후 Finder 통합 상태 이상을 진단한다.

초기 확인 시각: `2026-05-11 02:08 KST`
추가 정정 시각: `2026-05-11 04:17 KST`

## 정정 요약

초기 Stage 5 판단은 public `v0.1.1` 설치본의 app bundle, signing, PlugInKit 등록, 일부 `qlmanage -t` thumbnail 생성 결과를 근거로 문제를 legacy UTI/Spotlight cache 쪽으로 좁혔다. 이후 작업지시자의 재설치 후 재현, Quick Look GUI 확인, DiagnosticReports 분석을 통해 이 판단을 정정한다.

최종 판단은 다음과 같다.

- public `v0.1.1`의 Quick Look/Thumbnail extension은 `/Applications/Alhangeul.app` 아래에 포함되어 있고 PlugInKit에도 등록되어 있다.
- Finder Quick Look이 파일 정보 카드와 작은 썸네일만 보여준 것은 PNG reply 정책 때문이 아니라 preview provider가 렌더링 중 크래시했기 때문이다.
- Thumbnail이 일부 파일에서 깨져 보인 것도 같은 `HwpPageImageRenderer` 기반 bitmap 렌더 경로의 메모리 문제로 보는 것이 맞다.
- legacy `com.postmelee.rhwpmac.*` UTI cache는 현재 개발 로컬 환경에서 확인된 별도 환경 오염 요소지만, 이번 public `v0.1.1` Quick Look 실패의 주원인으로 볼 수 없다.
- 따라서 public `v0.1.1`은 Quick Look/Thumbnail crash hotfix 후 같은 version respin 또는 후속 patch release로 다시 배포해야 한다.

## 수행 결과

| 항목 | 결과 | 비고 |
|------|------|------|
| `v0.1.0` Sparkle 업데이트 확인 | OK | 작업지시자가 직접 진행했고 `v0.1.1` 업데이트 진행까지 완료 확인 |
| `v0.1.1` public DMG 재설치 | OK | 작업지시자가 직접 진행, About window 기준 `0.1.1 (2)` 확인 |
| 설치본 app bundle | OK | `/Applications/Alhangeul.app` 존재, `0.1.1` / build `2` |
| Quick Look/Thumbnail appex 포함 | OK | `Contents/PlugIns/AlhangeulPreview.appex`, `AlhangeulThumbnail.appex` 존재 |
| Developer ID signing | OK | app, Sparkle nested components, Quick Look/Thumbnail extension deep verify 통과 |
| PlugInKit 등록 | OK | 두 extension 모두 `+` 상태, 경로 `/Applications/Alhangeul.app/...` |
| About window 시스템 등록 표시 | 부정확 | 실제 PlugInKit 등록과 다르게 `시스템 등록 확인 불가`로 보일 수 있음 |
| Quick Look GUI preview | FAIL | extension 크래시 후 macOS generic fallback 카드 표시 |
| Finder thumbnail | FAIL | 일부 파일에서 깨진 이미지 또는 fallback 표시 |
| 초기 UTI cache 진단 | 보조 원인 | 과거 개발 빌드 UTI 기록은 확인됐지만 이번 실패의 직접 원인은 아님 |

## 설치본 상태

`/Applications/Alhangeul.app/Contents/Info.plist` 기준:

| 항목 | 값 |
|------|----|
| `CFBundleIdentifier` | `com.postmelee.alhangeul` |
| `CFBundleShortVersionString` | `0.1.1` |
| `CFBundleVersion` | `2` |
| `SUFeedURL` | `https://postmelee.github.io/alhangeul-macos/appcast.xml` |

Extension Info.plist 기준:

| Extension | Bundle ID | Extension point | 지원 content type |
|-----------|-----------|-----------------|-------------------|
| Quick Look preview | `com.postmelee.alhangeul.QLExtension` | `com.apple.quicklook.preview` | `com.postmelee.alhangeul.*`, `com.hancom.*`, `com.haansoft.*` |
| Thumbnail | `com.postmelee.alhangeul.ThumbnailExtension` | `com.apple.quicklook.thumbnail` | `com.postmelee.alhangeul.*`, `com.hancom.*`, `com.haansoft.*` |

## 추가 진단 내용

작업지시자 첨부 스크린샷에서 단일 페이지 문서가 기대한 큰 페이지 preview가 아니라 파일명, 파일 크기, 수정일과 작은 page image를 보여주는 카드로 표시됐다. 이 화면은 정상 PNG reply preview가 아니라 Quick Look preview provider 실패 후 macOS가 보여주는 generic fallback에 해당한다.

DiagnosticReports에서 다음 크래시를 확인했다.

| 대상 | 결과 |
|------|------|
| `AlhangeulPreview` | `EXC_BAD_ACCESS`, `SIGSEGV` |
| Preview stack | `_platform_memset_pattern16` -> `CGBlt_fillBytes` -> `CGContextFillRect` -> `HwpPageImageRenderer.renderPage(...)` -> `HwpPreviewProvider.pngReply(...)` |
| `AlhangeulThumbnail` | `EXC_BAD_ACCESS` |
| Thumbnail stack | `CGTreeRenderer.drawTextClusters(...)` -> `HwpPageImageRenderer.renderPage(...)` -> thumbnail render queue |

문제 지점은 `HwpPageImageRenderer`가 Swift `[UInt8]` 배열을 `CGContext(data: &pixels, ...)`의 backing store로 넘긴 구조다. Swift 배열 주소를 CoreGraphics bitmap context의 장기 backing memory처럼 쓰면 extension 프로세스의 최적화/수명 조건에서 유효하지 않은 메모리 접근이 발생할 수 있다. public `v0.1.1` 설치본에서 preview와 thumbnail이 모두 같은 renderer 경로를 타기 때문에 두 extension 모두 같은 유형으로 실패했다.

## PNG/PDF reply 정책 판단

단일 페이지 문서가 첨부 영상처럼 큰 페이지 preview로 보이려면 반드시 PDF reply여야 하는 것은 아니다. 단일 페이지 PNG reply도 provider가 정상 완료되면 Quick Look 안에서 페이지 이미지로 표시된다.

현재 화면이 영상과 다르게 보인 이유는 PNG reply라서가 아니라 provider가 PNG 데이터를 끝까지 반환하지 못하고 크래시했기 때문이다. 따라서 이번 hotfix에서는 “단일 페이지 PNG, 다중 페이지 PDF” 정책을 유지하고, bitmap renderer의 메모리 소유권 문제를 수정하는 방향이 맞다.

## 수정 방향

Stage 5 추가 진단 후 Stage 6 hotfix로 다음을 진행한다.

- `HwpPageImageRenderer` bitmap context를 Swift 배열 backing store가 아니라 CoreGraphics가 소유하는 memory로 생성한다.
- Quick Look preview와 Thumbnail extension에 OSLog 기반 요청/분기/fallback/failure 로그를 추가해 다음 배포 smoke에서 extension 실행 여부와 실패 지점을 바로 확인할 수 있게 한다.
- 정상 요청 로그는 `debug`, fallback은 `warning`, 실패는 `error`로 남긴다.
- 문서 본문이나 민감 데이터는 로그에 남기지 않고 파일명, page count, 크기, error type/domain/code만 기록한다.

## 실행한 검증

| 명령/확인 | 결과 | 비고 |
|-----------|------|------|
| `xcodebuild ... Debug ... CODE_SIGNING_ALLOWED=NO build` | OK | sandbox cache 권한 문제 후 로컬 권한으로 재실행 성공 |
| `xcodebuild ... Release ... CODE_SIGNING_ALLOWED=NO build` | OK | source-level Release build 성공 |
| `scripts/render-debug-compare.sh ... eq-01.hwp group-drawing-02.hwp footnote-01.hwp` | OK | crash 없이 PNG 렌더 완료 |
| `scripts/render-debug-compare.sh ... /Users/melee/Desktop/files/*.hwp` | OK | 13개 HWP 샘플 렌더 완료 |
| PlugInKit active path 확인 | OK | 현재 설치본은 여전히 public `/Applications/Alhangeul.app` 경로를 가리킴 |

## 남은 검증

아직 수정된 app/extension을 signed/notarized 설치본으로 `/Applications/Alhangeul.app`에 반영하지 않았다. 따라서 Finder/Quick Look에서 수정본이 실제로 실행되는 end-to-end smoke는 완료되지 않았다.

다음 단계에서는 hotfix commit을 포함한 signed/notarized `v0.1.1` respin 산출물을 만들고, clean install 후 다음을 반복해야 한다.

1. `/Applications/Alhangeul.app` 기준 PlugInKit active provider 경로 확인
2. `qlmanage -r`, `qlmanage -r cache`, Quick Look 관련 프로세스 재시작
3. `qlmanage -p -x` GUI preview에서 단일 페이지 PNG reply가 fallback 카드가 아니라 큰 페이지 preview로 표시되는지 확인
4. `qlmanage -t -x` thumbnail 생성과 Finder icon view thumbnail 확인
5. `~/Library/Logs/DiagnosticReports`에 새 `AlhangeulPreview`/`AlhangeulThumbnail` crash report가 생기지 않는지 확인
6. About window의 시스템 등록 표시가 실제 PlugInKit 등록과 어긋나는 문제는 별도 UI 보강 이슈로 남김

## 실행하지 않은 항목

- Intel Mac 실기기 smoke는 이번 로컬 환경에서 실행하지 않았다.
- 수정본 signed/notarized DMG 설치 smoke는 아직 실행하지 않았다.
- LaunchServices DB 전체 삭제나 reboot 요구 작업은 실행하지 않았다.
