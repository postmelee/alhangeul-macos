# Task M010 #367 최종 보고서

## 작업 요약

- 이슈: #367 LibreOffice HWP UTI 등록 시 Quick Look preview/thumbnail이 알한글 확장으로 라우팅되지 않는 문제
- 마일스톤: M010 (`v0.1`)
- 브랜치: `local/task367`
- 단계 수: 4
- 핵심 변경: LibreOffice가 `.hwp`에 선언하는 `org.libreoffice.hwp-document`를 HostApp, Quick Look preview extension, Finder thumbnail extension의 HWP 호환 UTI로 추가하고, Finder 통합 troubleshooting 문서에 진단 기준을 남김

## 완료 범위

- LibreOffice 26.2.4.2 설치본이 `.hwp`에 `org.libreoffice.hwp-document` imported UTI를 선언하는 것을 확인했다.
- LibreOffice Quick Look preview/thumbnail appex가 HWP/HWPX 타입을 직접 지원하지 않는 것을 확인했다.
- 따라서 사용자 증상은 LibreOffice Quick Look provider가 HWP preview를 직접 가로챈 문제라기보다, LaunchServices가 `.hwp`를 알한글 extension이 지원하지 않던 외부 UTI로 분류해 provider matching이 끊기는 content type mismatch 성격으로 판단했다.
- HostApp `LSItemContentTypes`와 `UTImportedTypeDeclarations`에 `org.libreoffice.hwp-document`를 추가했다.
- Quick Look preview와 Finder thumbnail extension의 `QLSupportedContentTypes`에 같은 UTI를 추가했다.
- Finder 통합 troubleshooting 문서에 LibreOffice HWP UTI 공존 진단 절을 추가했다.
- Debug build와 현재 설치본 기준 smoke를 수행하고, 로컬에서 LibreOffice UTI 선택 상태를 직접 재현하지 못한 한계를 기록했다.

## 단계별 진행

| Stage | Commit | 핵심 내용 |
|-------|--------|-----------|
| 시작 | `8954f94` | 수행계획서 작성과 오늘할일 등록 |
| 구현 계획 | `2ad1e16` | 4단계 구현계획서 작성 |
| 1 | `fbc05a5` | LibreOffice HWP UTI와 Quick Look appex 지원 타입 조사 |
| 2 | `3c6c6f2` | HostApp/Preview/Thumbnail plist에 LibreOffice HWP UTI 추가 |
| 3 | `d9e9b46` | troubleshooting 문서 보강과 설치본 smoke 기록 |
| 4 | 본 커밋 | 통합 검증, 최종 보고서, 오늘할일 완료 처리 |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Info.plist` | `LSItemContentTypes`와 `UTImportedTypeDeclarations`에 `org.libreoffice.hwp-document` 추가 |
| `Sources/QLExtension/Info.plist` | `QLSupportedContentTypes`에 `org.libreoffice.hwp-document` 추가 |
| `Sources/ThumbnailExtension/Info.plist` | `QLSupportedContentTypes`에 `org.libreoffice.hwp-document` 추가 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | LibreOffice HWP UTI 공존 진단 절 추가 |
| `mydocs/plans/task_m010_367.md` | 수행계획서 |
| `mydocs/plans/task_m010_367_impl.md` | 구현계획서 |
| `mydocs/working/task_m010_367_stage1.md` | Stage 1 조사 보고서 |
| `mydocs/working/task_m010_367_stage2.md` | Stage 2 plist 변경 보고서 |
| `mydocs/working/task_m010_367_stage3.md` | Stage 3 문서와 smoke 검증 보고서 |
| `mydocs/orders/20260622.md` | #367 완료 상태 기록 |
| `mydocs/report/task_m010_367_report.md` | 본 최종 보고서 |

## UTI 변경 기준

HostApp imported UTI declaration은 다음 기준으로 추가했다.

```text
UTTypeIdentifier = org.libreoffice.hwp-document
UTTypeDescription = LibreOffice Hangul WP 97 Document
UTTypeConformsTo = public.data, public.content
public.filename-extension = hwp
public.mime-type = application/x-hwp
```

기존 알한글 소유 UTI와 Hancom 계열 UTI는 제거하지 않았다. HWPX는 LibreOffice 설치본에서 별도 UTI 선언이 확인되지 않아 이번 범위에 포함하지 않았다.

## 검증 결과

```bash
git status --short --branch
git diff --check
```

결과: 작업 시작 시 clean 상태였고 whitespace 검증을 통과했다.

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
```

결과:

```text
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK
```

```bash
plutil -p Sources/HostApp/Info.plist | rg "org.libreoffice.hwp-document|LSItemContentTypes|UTImportedTypeDeclarations"
plutil -p Sources/QLExtension/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
plutil -p Sources/ThumbnailExtension/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
```

결과 요약:

```text
HostApp LSItemContentTypes: 6 => "org.libreoffice.hwp-document"
HostApp UTImportedTypeDeclarations: "UTTypeIdentifier" => "org.libreoffice.hwp-document"
Preview QLSupportedContentTypes: 6 => "org.libreoffice.hwp-document"
Thumbnail QLSupportedContentTypes: 6 => "org.libreoffice.hwp-document"
```

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [0.436 sec]
```

```bash
rg -n "LibreOffice|org\\.libreoffice\\.hwp-document|mdls" \
  mydocs/troubleshootings/finder_integration_validation_pitfalls.md \
  mydocs/report/task_m010_367_report.md
```

결과: troubleshooting 문서와 최종 보고서에서 LibreOffice UTI 공존 진단 기준을 확인했다.

## Smoke 결과와 재현 한계

Stage 3에서 현재 설치본 기준으로 다음을 확인했다.

```text
com.postmelee.alhangeul.QLExtension(0.1.6)
Path = /Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex

com.postmelee.alhangeul.ThumbnailExtension(0.1.6)
Path = /Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

```text
/tmp/alhangeul-KTX.hwp produced one thumbnail
/tmp/alhangeul-ql-libreoffice/alhangeul-KTX.hwp.png 150994 bytes
```

다만 로컬 fresh sample은 다음처럼 분류됐다.

```text
kMDItemContentType = "com.haansoft.hancomofficeviewer.mac.hwp"
```

따라서 이번 로컬 환경에서는 사용자가 겪은 `org.libreoffice.hwp-document` 선택 상태를 직접 재현하지 못했다. Stage 2 변경은 해당 UTI가 선택되는 사용자 환경에서 알한글 provider matching이 가능하도록 supported content type 표면을 넓히는 보강이다.

## 수행하지 않은 작업

- LibreOffice 설치/삭제 자동화는 수행하지 않았다.
- 전역 LaunchServices reset, Finder 종료, `quicklookd`/`thumbnaild` kill은 수행하지 않았다.
- Release package 생성, 서명, 공증, 배포는 수행하지 않았다.
- 다른 앱이 선언할 수 있는 미확인 HWP UTI는 이번 범위에 포함하지 않았다.

## 잔여 리스크

- LaunchServices의 `.hwp` content type 선택은 설치 순서, 기존 UTI cache, 한컴/LibreOffice/알한글 설치 상태에 영향을 받는다.
- 기존 Finder thumbnail cache가 남아 있으면 plist 변경 후에도 기존 썸네일이 즉시 갱신되지 않을 수 있다.
- 사용자가 이미 설치한 알한글 버전에는 이번 plist 변경이 포함되지 않는다. 새 빌드/배포본 설치 후 active provider path와 cache 상태를 다시 확인해야 한다.
- 후속으로 다른 앱의 별도 HWP UTI가 발견되면 같은 compatibility UTI 방식으로 별도 이슈를 등록해 처리해야 한다.

## 완료 판단

#367은 LibreOffice가 `.hwp`를 `org.libreoffice.hwp-document`로 분류하는 환경에서도 알한글 HostApp, Quick Look preview, Finder thumbnail extension이 같은 HWP 문서 타입으로 matching될 수 있도록 plist 선언을 보강했다. 또한 향후 비슷한 Finder 통합 이슈에서 LibreOffice 제거를 우선 안내하지 않고, `mdls` 기반 content type 확인과 supported content type 보강 여부를 먼저 판단할 수 있도록 troubleshooting 기준을 남겼다.

## 다음 단계

작업지시자 승인 후 `publish/task367` 브랜치 게시와 PR 생성 절차로 넘길 수 있다.
