# Task M020 #406 Stage 2 완료보고서

## 단계 목적

Stage 1에서 확인한 HOP HWP/HWPX UTI 계약을 알한글 HostApp, Quick Look preview, Finder thumbnail, 앱 내부 열기 패널에 일관되게 반영한다.

기존 문서 타입의 역할과 handler rank, 기존 UTI 선언, parser/renderer 동작은 유지하면서 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`만 외부 호환 타입으로 추가한다.

## 산출물

| 파일 | 변경량 | 요약 |
|------|--------|------|
| `Sources/HostApp/Info.plist` | +45 / -0 | `LSItemContentTypes`에 HOP UTI 두 개 추가, HOP HWP/HWPX imported declaration 추가 |
| `Sources/QLExtension/Info.plist` | +2 / -0 | `QLSupportedContentTypes`에 HOP UTI 두 개 추가 |
| `Sources/ThumbnailExtension/Info.plist` | +2 / -0 | `QLSupportedContentTypes`에 HOP UTI 두 개 추가 |
| `Sources/HostApp/Services/DocumentOpenPanel.swift` | +2 / -0 | `supportedContentTypes`에 HOP UTI 두 개 추가 |
| `mydocs/working/task_m020_406_stage2.md` | 신규 | 구현 내용, 정적 검사, build 결과, 잔여 위험 기록 |
| `mydocs/orders/20260711.md` | 수정 | #406 상태를 `Stage 2 완료보고서 승인 대기`로 갱신 |

생성 산출물인 `Frameworks/Rhwp.xcframework`, `Frameworks/universal/librhwp.a`, `build.noindex/DerivedData`는 빌드 검증에만 사용하며 커밋하지 않는다.

## 구현 결과

### HostApp 문서 연결

`CFBundleDocumentTypes[0].LSItemContentTypes`에서 알한글 자체 UTI 다음에 두 HOP UTI를 추가했다.

```text
com.postmelee.alhangeul.hwp
com.postmelee.alhangeul.hwpx
net.golbin.hop.hwp
net.golbin.hop.hwpx
com.hancom.hwp
...
```

기존 `CFBundleTypeRole=Viewer`, `LSHandlerRank=Alternate`는 변경하지 않았다. HOP의 `Editor` / `Owner` 정책을 알한글에 복제하지 않고 알한글의 viewer 역할을 유지한다.

### Imported type 계약

HOP source revision `bbd6bf69db05f275d714e7c61cef58b662809c6a`의 계약과 일치하게 선언했다.

| Identifier | Extension | MIME type | Conforms to |
|------------|-----------|-----------|-------------|
| `net.golbin.hop.hwp` | `hwp` | `application/x-hwp` | `public.data` |
| `net.golbin.hop.hwpx` | `hwpx` | `application/vnd.hancom.hwpx` | `public.data`, `public.zip-archive` |

알한글 소유 `UTExportedTypeDeclarations`와 Hancom, Hancom Office Viewer, LibreOffice imported declaration은 변경하지 않았다.

### Quick Look, Thumbnail, 앱 열기 패널

- Preview `QLSupportedContentTypes`에 두 HOP UTI 추가
- Thumbnail `QLSupportedContentTypes`에 두 HOP UTI 추가
- `DocumentOpenPanel.supportedContentTypes`에 두 HOP UTI 추가
- 열기 패널의 기존 `.data` fallback 유지

## 본문 변경 정도 / 본문 무손실 여부

- 네 source 파일 모두 기존 항목 삭제 없이 additive 변경만 수행했다.
- HostApp의 기존 UTI role, rank, conformance, MIME type, 배열 상대 순서를 변경하지 않았다.
- `DocumentOpenPanel`의 제어 흐름과 `.data` fallback을 변경하지 않았다.
- parser, renderer, `Sources/RhwpCoreBridge`, `Sources/Shared` 변경 없음
- `project.yml`, generated `Alhangeul.xcodeproj` 변경 없음
- 매뉴얼과 troubleshooting 문서 변경 없음
- 사용자 문서 및 repository sample 변경 없음

따라서 기존 HWP/HWPX 처리 본문은 무손실이며 LaunchServices/Uniform Type Identifier routing 선언만 확장됐다.

## 검증 결과

### plist 문법 검사

```text
$ plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK
```

### HostApp UTI 선언

```text
$ plutil -p Sources/HostApp/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|application/x-hwp|application/vnd.hancom.hwpx|LSItemContentTypes|UTImportedTypeDeclarations"
LSItemContentTypes:
  net.golbin.hop.hwp
  net.golbin.hop.hwpx
UTImportedTypeDeclarations:
  net.golbin.hop.hwp / application/x-hwp
  net.golbin.hop.hwpx / application/vnd.hancom.hwpx
```

`plutil -extract UTImportedTypeDeclarations json` 출력에서 HWP conformance는 `public.data`, HWPX conformance는 `public.data`, `public.zip-archive`로 확인했다.

### Quick Look / Thumbnail / 열기 패널

```text
$ plutil -p Sources/QLExtension/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|QLSupportedContentTypes"
QLSupportedContentTypes: net.golbin.hop.hwp, net.golbin.hop.hwpx

$ plutil -p Sources/ThumbnailExtension/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|QLSupportedContentTypes"
QLSupportedContentTypes: net.golbin.hop.hwp, net.golbin.hop.hwpx

$ rg -n "net.golbin.hop.(hwp|hwpx)" Sources/HostApp/Services/DocumentOpenPanel.swift
24: net.golbin.hop.hwp
25: net.golbin.hop.hwpx
```

### Rust bridge 준비

새 worktree에 generated framework가 없어 구현계획서와 build guide에 따라 `./scripts/build-rust-macos.sh`를 실행했다.

```text
Rust release staticlib arm64: 통과
Rust release staticlib x86_64: 통과
Universal archive architectures: x86_64 arm64
cbindgen header / FFI symbol check: 통과
Rhwp.xcframework 생성: 통과
```

### HostApp Debug build

```text
$ xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
    -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
Target dependency graph: HostApp, QLExtension, ThumbnailExtension, Sparkle
** BUILD SUCCEEDED **
```

AppIntents framework dependency가 없어 metadata extraction을 생략했다는 Xcode warning이 있었으나 compile/link 및 embedded extension validation은 성공했다.

### Built bundle 반영

```text
Alhangeul.app/Contents/Info.plist:
  LSItemContentTypes와 UTImportedTypeDeclarations에 두 HOP UTI 확인
AlhangeulPreview.appex/Contents/Info.plist:
  QLSupportedContentTypes에 두 HOP UTI 확인
AlhangeulThumbnail.appex/Contents/Info.plist:
  QLSupportedContentTypes에 두 HOP UTI 확인
```

### 변경 무결성

```text
$ git diff --check
(출력 없음, 통과)
```

## 잔여 위험

- 로컬 HOP 설치본이 없어 `net.golbin.hop.*`가 실제 선택된 문서의 Finder 후보와 `mdls` 결과는 아직 재현하지 못했다.
- 사용자 제보 파일의 `mdls` 결과가 없어 HOP UTI 누락이 제보의 단일 원인인지는 확정할 수 없다.
- `xcodebuild`가 `build.noindex`의 Debug 앱을 LaunchServices에 자동 등록했다. 이 산출물은 signing/sealing된 Finder 검증 기준이 아니므로 Stage 3 시작 시 registration hygiene를 확인하고 설치본과 구분해야 한다.
- LaunchServices 후보 목록은 설치 순서, 기존 default handler, 캐시 상태에 영향을 받을 수 있다.
- `DocumentOpenPanel`은 `.data` fallback을 유지하므로 명시 UTI 추가가 현재 선택 가능 범위를 크게 바꾸지는 않지만 지원 목록 일관성은 확보한다.

## 다음 단계 영향

Stage 3에서는 다음 순서로 Finder 통합과 문서 열기 검증을 수행한다.

1. `scripts/check-extension-registration-hygiene.sh --check-only`로 Debug 등록 오염과 active provider path를 확인한다.
2. built app과 두 appex의 HOP UTI 선언을 재확인한다.
3. 일반 HWP/HWPX sample의 `mdls` content type과 app open handoff를 확인한다.
4. 가능한 경우 signed/sealed Release app 또는 표준 Finder integration helper로 Quick Look/Thumbnail smoke를 수행한다.
5. Finder `다음으로 열기` 후보와 앱 내부 열기 패널은 GUI 수동 검증 항목으로 분리한다.
6. HOP 설치본 부재로 공존 재현이 불가능하면 정적 bundle 선언과 일반 회귀 결과를 필수 결과로 두고 사용자 `mdls` 확인 필요성을 남긴다.

troubleshooting 문서는 기존 third-party UTI 진단 설명이 부족한 경우에만 최소 보강한다.

## 승인 요청

Stage 2의 additive UTI 선언과 검증 결과 검토를 요청한다. 승인 후 Stage 3 `HOP 공존 Finder 통합과 문서 열기 검증`으로 진행한다.
