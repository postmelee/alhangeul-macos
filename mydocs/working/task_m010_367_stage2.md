# Task M010 #367 Stage 2 완료보고서

## 단계 목적

HostApp, Quick Look preview extension, Finder thumbnail extension이 LibreOffice가 `.hwp`에 선언하는 `org.libreoffice.hwp-document` UTI를 HWP 호환 타입으로 인식하도록 plist 선언을 보강했다. renderer, parser, fallback classifier 코드는 변경하지 않고 LaunchServices/Quick Look matching 표면만 넓히는 것이 목적이었다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Info.plist` | `LSItemContentTypes`와 `UTImportedTypeDeclarations`에 `org.libreoffice.hwp-document` 추가 |
| `Sources/QLExtension/Info.plist` | `QLSupportedContentTypes`에 `org.libreoffice.hwp-document` 추가 |
| `Sources/ThumbnailExtension/Info.plist` | `QLSupportedContentTypes`에 `org.libreoffice.hwp-document` 추가 |
| `mydocs/working/task_m010_367_stage2.md` | Stage 2 변경과 검증 결과 기록 |

## 본문 변경 정도 / 본문 무손실 여부

기존 Hancom 계열 UTI와 알한글 소유 UTI는 제거하지 않았다. 순서도 기존 목록 뒤에 LibreOffice HWP UTI를 추가하는 방식으로 유지했다. 문서 본문은 신규 단계 보고서만 추가했으며 기존 매뉴얼과 사용자 문서는 변경하지 않았다.

## 변경 내용

HostApp에는 `org.libreoffice.hwp-document`를 두 위치에 반영했다.

- `CFBundleDocumentTypes[0].LSItemContentTypes`
- `UTImportedTypeDeclarations`

imported UTI declaration은 Stage 1에서 확인한 LibreOffice 선언에 맞춰 다음 기준으로 추가했다.

```text
UTTypeIdentifier = org.libreoffice.hwp-document
UTTypeDescription = LibreOffice Hangul WP 97 Document
UTTypeConformsTo = public.data, public.content
public.filename-extension = hwp
public.mime-type = application/x-hwp
```

Quick Look preview와 Finder thumbnail extension에는 같은 UTI를 `QLSupportedContentTypes`에 추가했다.

## 검증 결과

### plist 문법 검증

명령:

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
```

결과:

```text
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK
```

### HostApp 선언 확인

명령:

```bash
plutil -p Sources/HostApp/Info.plist | rg "org.libreoffice.hwp-document|LibreOffice Hangul WP 97|LSItemContentTypes|UTImportedTypeDeclarations"
```

결과 요약:

```text
"LSItemContentTypes" => [
  6 => "org.libreoffice.hwp-document"
"UTImportedTypeDeclarations" => [
"UTTypeDescription" => "LibreOffice Hangul WP 97 Document"
"UTTypeIdentifier" => "org.libreoffice.hwp-document"
```

판단:

- HostApp 문서 타입 목록에 LibreOffice HWP UTI가 포함됐다.
- HostApp imported type declaration에도 같은 UTI와 설명이 포함됐다.

### Quick Look preview 선언 확인

명령:

```bash
plutil -p Sources/QLExtension/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
```

결과:

```text
"QLSupportedContentTypes" => [
  6 => "org.libreoffice.hwp-document"
```

판단: preview extension이 LibreOffice HWP UTI를 지원 타입으로 선언한다.

### Finder thumbnail 선언 확인

명령:

```bash
plutil -p Sources/ThumbnailExtension/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
```

결과:

```text
"QLSupportedContentTypes" => [
  6 => "org.libreoffice.hwp-document"
```

판단: thumbnail extension이 LibreOffice HWP UTI를 지원 타입으로 선언한다.

### Whitespace 검증

명령:

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- LaunchServices content type 선택과 Finder thumbnail cache는 설치 순서와 기존 캐시에 영향을 받는다. plist 선언 추가만으로 이미 캐시된 썸네일이 즉시 갱신된다고 보장할 수는 없다.
- 로컬 Stage 1 조사에서는 sample HWP가 `org.libreoffice.hwp-document`로 분류되는 상태를 재현하지 못했다. Stage 3에서 설치본 smoke를 수행하되 재현 한계를 별도로 기록해야 한다.
- LibreOffice 외 다른 앱이 별도 HWP UTI를 선언하는 경우는 이번 Stage 2 범위가 아니다.

## 다음 단계 영향

Stage 3에서는 Finder 통합 troubleshooting 문서에 LibreOffice UTI 공존 진단 기준을 추가하고, 가능한 범위에서 설치본 기준 `mdls`, `pluginkit`, `qlmanage -t` smoke를 수행한다. Debug build 검증도 Stage 3 계획에 포함되어 있다.

## 승인 요청

Stage 2 완료 보고를 승인해 주시면 Stage 3 `Finder 통합 문서와 설치본 smoke 검증`으로 진행하겠다.
