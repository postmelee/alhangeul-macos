# Task M010 #367 Stage 1 완료보고서

## 단계 목적

LibreOffice HWP UTI 공존 문제의 구현 전제를 재확인했다. 현재 알한글이 선언한 HWP/HWPX UTI, LibreOffice 설치본이 선언한 HWP UTI, LibreOffice Quick Look appex의 지원 타입, 로컬 LaunchServices 분류 상태를 대조해 Stage 2의 plist 변경 범위를 확정하는 것이 목적이었다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m010_367_stage1.md` | Stage 1 조사 결과와 검증 출력 요약 |

소스, plist, 매뉴얼 본문은 이 단계에서 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

본문 변경은 신규 단계 보고서 작성뿐이다. 기존 코드, plist, 매뉴얼, 사용자 문서의 본문은 변경하지 않았으므로 무손실이다.

## 검증 결과

### 알한글 HostApp UTI 선언

명령:

```bash
plutil -p Sources/HostApp/Info.plist | rg "com.postmelee.alhangeul.hwp|com.hancom.hwp|com.haansoft.hancomofficeviewer.mac.hwp|org.libreoffice.hwp-document"
```

결과 요약:

- `LSItemContentTypes`와 `UTTypeIdentifier`에 알한글 소유 UTI, Hancom UTI, Hancom Office Viewer UTI가 있다.
- `org.libreoffice.hwp-document`는 없다.

확인된 HWP/HWPX 타입:

```text
com.postmelee.alhangeul.hwp
com.postmelee.alhangeul.hwpx
com.hancom.hwp
com.hancom.hwpx
com.haansoft.hancomofficeviewer.mac.hwp
com.haansoft.hancomofficeviewer.mac.hwpx
```

### 알한글 Quick Look/Thumbnail UTI 선언

명령:

```bash
plutil -p Sources/QLExtension/Info.plist | rg "QLSupportedContentTypes|hwp|hwpx"
plutil -p Sources/ThumbnailExtension/Info.plist | rg "QLSupportedContentTypes|hwp|hwpx"
```

결과 요약:

- Quick Look preview와 Finder thumbnail extension 모두 같은 6개 타입만 지원한다.
- 두 extension 모두 `org.libreoffice.hwp-document`는 없다.

확인된 supported content types:

```text
com.postmelee.alhangeul.hwp
com.postmelee.alhangeul.hwpx
com.hancom.hwp
com.hancom.hwpx
com.haansoft.hancomofficeviewer.mac.hwp
com.haansoft.hancomofficeviewer.mac.hwpx
```

### LibreOffice HWP UTI 선언

명령:

```bash
plutil -p /Applications/LibreOffice.app/Contents/Info.plist | rg "org.libreoffice.hwp-document|Hangul WP 97|hwp|hwpx"
```

결과:

```text
28 => "org.libreoffice.hwp-document"
"UTTypeDescription" => "Hangul WP 97 Document"
"UTTypeIdentifier" => "org.libreoffice.hwp-document"
0 => "hwp"
0 => "application/x-hwp"
```

판단:

- LibreOffice 26.2.4.2 설치본은 `.hwp`를 `org.libreoffice.hwp-document` imported UTI로 선언한다.
- 같은 명령에서 `hwpx` 출력은 없었다. 이번 범위에서 HWPX 공존 대응을 제외한 수행계획 판단은 유지한다.

### LibreOffice Quick Look appex 지원 타입

명령:

```bash
plutil -p /Applications/LibreOffice.app/Contents/PlugIns/QuickLookPreview.appex/Contents/Info.plist | rg "QLSupportedContentTypes|hwp|hwpx"
plutil -p /Applications/LibreOffice.app/Contents/PlugIns/QuickLookThumbnail.appex/Contents/Info.plist | rg "QLSupportedContentTypes|hwp|hwpx"
```

결과:

```text
"QLSupportedContentTypes" => [
```

판단:

- 두 명령 모두 `QLSupportedContentTypes` 키만 출력했고 `hwp`, `hwpx`, `org.libreoffice.hwp-document` 값은 출력하지 않았다.
- 전체 plist 확인 결과 LibreOffice preview/thumbnail appex는 OpenOffice/OpenDocument 계열 타입을 지원하지만 HWP/HWPX 타입은 지원하지 않는다.
- 따라서 사용자 증상은 LibreOffice Quick Look provider가 HWP preview를 직접 가로챈 문제라기보다, LaunchServices가 `.hwp`를 알한글 extension이 지원하지 않는 `org.libreoffice.hwp-document`로 분류해 알한글 provider matching이 끊기는 content type mismatch 성격이 강하다.

### PlugInKit 등록 상태

샌드박스 내부 `pluginkit` 조회는 `Connection invalid`로 실패해 외부 실행으로 확인했다.

결과 요약:

- `com.postmelee.alhangeul.QLExtension` 등록됨: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`, version `0.1.6`
- `com.postmelee.alhangeul.ThumbnailExtension` 등록됨: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex`, version `0.1.6`
- `org.libreoffice.script.quicklookthumbnail` 등록됨: `/Applications/LibreOffice.app/Contents/PlugIns/QuickLookThumbnail.appex`, version `26.2.4.2`
- `org.libreoffice.script.quicklookpreview`는 현재 `pluginkit -mAvvv -i` 조회에서 `no matches`

이 결과는 LibreOffice thumbnail appex가 등록될 수 있음을 보여주지만, 해당 appex의 supported content types에는 HWP/HWPX가 없으므로 HWP 라우팅 문제의 핵심 원인은 UTI mismatch로 보는 것이 타당하다.

### 로컬 LaunchServices 분류 상태

명령:

```bash
cp samples/basic/KTX.hwp /tmp/alhangeul-task367-KTX.hwp
mdls -name kMDItemContentType -name kMDItemContentTypeTree /tmp/alhangeul-task367-KTX.hwp
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

- 로컬 fresh sample은 아직 `org.libreoffice.hwp-document`가 아니라 알한글이 이미 지원하는 Hancom Office Viewer UTI로 분류된다.
- 따라서 이 환경에서는 사용자가 겪은 content type 선택 상태를 그대로 재현하지 못한다.
- 그래도 LibreOffice가 별도 HWP UTI를 선언하고 알한글이 이를 지원하지 않는다는 누락 사실은 확인됐다.

### Whitespace 검증

명령:

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- LaunchServices의 content type 선택은 설치 순서, 기존 UTI 캐시, 한컴/LibreOffice/알한글 설치 상태에 따라 달라진다. 로컬에서는 LibreOffice UTI가 선택되지 않아 사용자 환경과 같은 `mdls` 상태를 재현하지 못했다.
- `org.libreoffice.hwp-document`를 추가해도 기존 Finder thumbnail cache는 즉시 갱신되지 않을 수 있다. Stage 3 smoke에서 fresh sample과 cache 갱신 범위를 구분해야 한다.
- 다른 앱이 별도 HWP UTI를 선언하면 같은 종류의 공존 문제가 남을 수 있다. 이번 작업은 확인된 LibreOffice UTI만 다룬다.

## 다음 단계 영향

Stage 2에서는 다음 세 파일에 `org.libreoffice.hwp-document`를 같은 기준으로 추가하면 된다.

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`

HostApp에는 imported UTI declaration과 `LSItemContentTypes` 연결이 모두 필요하다. Quick Look preview와 Finder thumbnail extension에는 `QLSupportedContentTypes` 추가가 필요하다. HWPX는 이번 단계 조사에서 LibreOffice 설치본 선언이 확인되지 않았으므로 Stage 2 범위에 넣지 않는다.

## 승인 요청

Stage 1 완료 보고를 승인해 주시면 Stage 2 `LibreOffice HWP UTI 호환 선언 추가`로 진행하겠다.
