# Task M010 #367 Stage 3 완료보고서

## 단계 목적

LibreOffice가 `.hwp`에 별도 UTI를 선언하는 환경에서 Finder Quick Look/Thumbnail 문제를 진단하는 기준을 troubleshooting 문서에 추가했다. 또한 Stage 2 plist 변경이 Debug build 산출물에 반영되는지 확인하고, 현재 설치본 기준으로 실행 가능한 `mdls`, `pluginkit`, `qlmanage -t` smoke 결과를 기록했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | LibreOffice HWP UTI 공존 진단 절 추가 |
| `mydocs/working/task_m010_367_stage3.md` | Stage 3 문서 변경, 빌드, smoke 결과 기록 |

## 본문 변경 정도 / 본문 무손실 여부

기존 troubleshooting 문서 본문은 삭제하지 않았다. `전역 reset 주의` 뒤에 `LibreOffice HWP UTI 공존 진단` 절을 추가했고, 뒤쪽 섹션 번호를 `6`, `7`로 밀었다. 기존 표준 helper 선택 기준과 표시명 진단 내용은 유지했다.

## 문서 변경 내용

추가한 진단 기준은 다음과 같다.

- LibreOffice 설치 시 `.hwp`가 `org.libreoffice.hwp-document`로 분류될 수 있음을 명시했다.
- `mdls -name kMDItemContentType -name kMDItemContentTypeTree <file.hwp>`로 실제 content type을 먼저 확인하도록 했다.
- LibreOffice Quick Look appex가 HWP를 직접 지원하지 않는 경우, provider 우선순위 경쟁보다 LaunchServices content type mismatch 가능성을 우선 보도록 정리했다.
- 해결 방향은 LibreOffice 제거가 아니라 알한글 앱과 extension의 supported content type 보강, active provider path, Quick Look cache, fresh sample thumbnail 재검증으로 정리했다.
- 전역 LaunchServices reset과 Finder/Quick Look daemon 종료는 기존 경고 기준을 따르도록 했다.

## 검증 결과

### 문서 키워드와 whitespace 검증

명령:

```bash
git diff --check
rg -n "LibreOffice|org\\.libreoffice\\.hwp-document|mdls|Quick Look|Thumbnail" mydocs/troubleshootings/finder_integration_validation_pitfalls.md
```

결과 요약:

- `git diff --check` 통과.
- troubleshooting 문서의 신규 절에서 `LibreOffice`, `org.libreoffice.hwp-document`, `mdls`, `Quick Look`, `Thumbnail` 기준이 모두 확인됐다.

확인된 주요 위치:

```text
89:## 5. LibreOffice HWP UTI 공존 진단
91:LibreOffice가 설치된 환경에서는 `.hwp` 파일이 Hancom 계열 UTI가 아니라 `org.libreoffice.hwp-document`로 분류될 수 있다.
96:mdls -name kMDItemContentType -name kMDItemContentTypeTree <file.hwp>
101:- `kMDItemContentType`이 `org.libreoffice.hwp-document`이면 LibreOffice UTI 공존 경로로 본다.
```

### Debug build 검증

명령:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [9.001 sec]
```

비고:

- sandbox 내부 첫 실행은 SwiftPM/Xcode cache 쓰기 권한 제한으로 실패했다.
- 같은 명령을 외부 권한으로 재실행해 성공했다.
- XcodeBuildMCP는 현재 iOS Simulator workflow 도구만 노출되어 macOS HostApp build에는 사용하지 않았다.

### Debug build 산출물 plist 반영 확인

명령:

```bash
plutil -p build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Info.plist | rg "org.libreoffice.hwp-document|LibreOffice Hangul WP 97|LSItemContentTypes|UTImportedTypeDeclarations"
plutil -p build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
plutil -p build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
```

결과 요약:

```text
HostApp LSItemContentTypes: 6 => "org.libreoffice.hwp-document"
HostApp UTImportedTypeDeclarations: "UTTypeIdentifier" => "org.libreoffice.hwp-document"
Preview QLSupportedContentTypes: 6 => "org.libreoffice.hwp-document"
Thumbnail QLSupportedContentTypes: 6 => "org.libreoffice.hwp-document"
```

판단: Stage 2 plist 변경이 HostApp Debug build 산출물과 두 embedded appex 산출물에 반영됐다.

### 로컬 sample content type 확인

명령:

```bash
cp samples/basic/KTX.hwp /tmp/alhangeul-KTX.hwp
mdls -name kMDItemContentType -name kMDItemContentTypeTree /tmp/alhangeul-KTX.hwp
```

결과:

```text
kMDItemContentType     = "com.haansoft.hancomofficeviewer.mac.hwp"
kMDItemContentTypeTree = (
    "public.data",
    "public.item",
    "com.haansoft.hancomofficeviewer.mac.hwp"
)
```

판단:

- 현재 로컬 sample은 `org.libreoffice.hwp-document`로 분류되지 않았다.
- 사용자 환경과 같은 LibreOffice UTI 선택 상태는 이번 smoke에서도 재현하지 못했다.
- 이 결과는 Stage 1의 로컬 재현 한계와 일치한다.

### PlugInKit active path 확인

명령:

```bash
pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension
pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension
```

결과 요약:

```text
com.postmelee.alhangeul.QLExtension(0.1.6)
Path = /Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
Parent Bundle = /Applications/Alhangeul.app

com.postmelee.alhangeul.ThumbnailExtension(0.1.6)
Path = /Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
Parent Bundle = /Applications/Alhangeul.app
```

판단:

- 현재 PlugInKit active path는 `/Applications/Alhangeul.app` 설치본이다.
- Debug build 산출물은 build 검증에는 사용했지만, 현재 PlugInKit active provider로 잡히지는 않았다.

### Quick Look thumbnail smoke

명령:

```bash
mkdir -p /tmp/alhangeul-ql-libreoffice
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql-libreoffice /tmp/alhangeul-KTX.hwp
find /tmp/alhangeul-ql-libreoffice -maxdepth 1 -type f -print -ls
```

결과:

```text
/tmp/alhangeul-KTX.hwp produced one thumbnail
/tmp/alhangeul-ql-libreoffice/alhangeul-KTX.hwp.png 150994 bytes
```

판단:

- 현재 설치본과 현재 로컬 content type 기준에서 thumbnail 생성은 성공했다.
- 단, sample content type이 LibreOffice UTI가 아니므로 이 smoke는 `org.libreoffice.hwp-document` 라우팅을 직접 검증한 것은 아니다.

### 등록 위생 확인

명령:

```bash
scripts/check-extension-registration-hygiene.sh --check-only
```

결과 요약:

```text
Development registrations:
  - (none)
Legacy app candidates:
  - (none)
Legacy extension candidates:
  - (none)
Issues:
  - (none)
Warnings:
  - development/test Alhangeul.app bundles exist under build.noindex or DerivedData; this is only a problem if they are registered.
  - Quick Look preview provider path was not reported by PlugInKit.
  - Thumbnail provider path was not reported by PlugInKit.
```

판단:

- Debug build 산출물 bundle 파일은 존재하지만, helper 기준 개발 산출물 registration 이슈는 없었다.
- PlugInKit provider path는 개별 `pluginkit -mAvvv -i ...` 명령에서 `/Applications/Alhangeul.app`으로 확인했다.

## 잔여 위험

- 로컬 sample이 `org.libreoffice.hwp-document`로 분류되지 않아 사용자 환경의 LibreOffice UTI 라우팅을 직접 재현하지 못했다.
- `qlmanage -t` smoke는 현재 active path인 `/Applications/Alhangeul.app` 설치본과 Hancom Office Viewer UTI 기준 성공이다. Stage 2 변경이 포함된 새 signed/sealed 설치본 기준 smoke는 이번 단계에서 수행하지 않았다.
- Debug build는 compile/link와 산출물 plist 반영 확인에는 유효하지만 Finder/Quick Look 등록 검증의 진실 원천은 아니다.
- 기존 Finder thumbnail cache는 Stage 2/3 변경 이후에도 즉시 갱신되지 않을 수 있다.

## 다음 단계 영향

Stage 4에서는 전체 변경을 통합 검증하고 최종 보고서에 원인 판단을 정리한다. 특히 LibreOffice Quick Look appex가 HWP를 직접 지원해서 가로챈 문제라기보다 LaunchServices content type mismatch였다는 판단, 로컬 재현 한계, 기존 thumbnail cache 잔여 위험을 최종 보고에 반영해야 한다.

## 승인 요청

Stage 3 완료 보고를 승인해 주시면 Stage 4 `통합 검증과 최종 보고`로 진행하겠다.
