# Task #367 구현 계획서

본 문서는 [`task_m010_367.md`](task_m010_367.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- Worktree: `/Users/melee/Documents/projects/rhwp-mac`
- Branch: `local/task367`
- 기준 브랜치: `devel`
- 기준 이슈: [#367](https://github.com/postmelee/alhangeul-macos/issues/367)
- 마일스톤: M010 (`v0.1`)
- 범위: LibreOffice HWP UTI와 알한글 Quick Look/Thumbnail 라우팅 공존 보강

## 구현 원칙

- `org.libreoffice.hwp-document`는 알한글 소유 UTI가 아니라 외부 앱이 선언한 imported compatibility UTI로 취급한다.
- HostApp, Quick Look preview, Finder thumbnail의 HWP 지원 타입 목록은 같은 기준으로 맞춘다.
- 파일 파서, renderer, fallback classifier 동작은 변경하지 않는다.
- `project.yml`이 Xcode project 원본이라는 기준은 유지하며, `Alhangeul.xcodeproj`를 직접 수정하지 않는다.
- LibreOffice 설치/삭제 자동화와 전역 LaunchServices reset은 구현 범위에 넣지 않는다.
- 각 단계는 승인 전 다음 단계 작업으로 넘어가지 않는다.

## Stage 1 — UTI/등록 현황 재확인

### 목표

- 현재 알한글이 선언한 HWP/HWPX UTI 목록과 LibreOffice 설치본이 선언한 HWP UTI를 다시 대조한다.
- LibreOffice Quick Look appex가 HWP UTI를 직접 지원하지 않는다는 전제를 검증 기록으로 남긴다.
- HWPX에 해당하는 LibreOffice UTI가 이번 범위에 없는지 확인한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m010_367_stage1.md` | UTI/PlugInKit 현황과 로컬 재현 한계 기록 | 조사 보고서 |

### 조사 기준

1. `Sources/HostApp/Info.plist`, `Sources/QLExtension/Info.plist`, `Sources/ThumbnailExtension/Info.plist`의 현재 supported content types를 확인한다.
2. `/Applications/LibreOffice.app/Contents/Info.plist`의 `org.libreoffice.hwp-document` 선언을 확인한다.
3. LibreOffice `QuickLookPreview.appex`, `QuickLookThumbnail.appex`의 `QLSupportedContentTypes`가 HWP를 포함하는지 확인한다.
4. 같은 설치본에서 HWPX UTI가 따로 선언되는지 확인한다.

### 단계 검증

```bash
plutil -p Sources/HostApp/Info.plist | rg "com.postmelee.alhangeul.hwp|com.hancom.hwp|com.haansoft.hancomofficeviewer.mac.hwp|org.libreoffice.hwp-document"
plutil -p Sources/QLExtension/Info.plist | rg "QLSupportedContentTypes|hwp|hwpx"
plutil -p Sources/ThumbnailExtension/Info.plist | rg "QLSupportedContentTypes|hwp|hwpx"
plutil -p /Applications/LibreOffice.app/Contents/Info.plist | rg "org.libreoffice.hwp-document|Hangul WP 97|hwp|hwpx"
plutil -p /Applications/LibreOffice.app/Contents/PlugIns/QuickLookPreview.appex/Contents/Info.plist | rg "QLSupportedContentTypes|hwp|hwpx" || true
plutil -p /Applications/LibreOffice.app/Contents/PlugIns/QuickLookThumbnail.appex/Contents/Info.plist | rg "QLSupportedContentTypes|hwp|hwpx" || true
git diff --check
```

### 단계 완료 기준

- 알한글 현재 지원 UTI와 누락된 LibreOffice HWP UTI가 보고서에 정리된다.
- LibreOffice Quick Look appex가 HWP UTI를 직접 지원하지 않는지 여부가 기록된다.
- HWPX 범위 제외 판단 근거가 기록된다.

### 커밋 메시지

```text
Task #367 Stage 1: LibreOffice HWP UTI 현황 확인
```

## Stage 2 — LibreOffice HWP UTI 호환 선언 추가

### 목표

- HostApp과 두 Quick Look extension이 `org.libreoffice.hwp-document`를 HWP 호환 타입으로 인식하게 한다.
- plist 문법과 선언 위치를 검증한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/HostApp/Info.plist` | `CFBundleDocumentTypes`와 `UTImportedTypeDeclarations`에 LibreOffice HWP UTI 반영 | 앱/LaunchServices 문서 타입 |
| `Sources/QLExtension/Info.plist` | `QLSupportedContentTypes`에 LibreOffice HWP UTI 추가 | Quick Look preview |
| `Sources/ThumbnailExtension/Info.plist` | `QLSupportedContentTypes`에 LibreOffice HWP UTI 추가 | Finder thumbnail |
| `mydocs/working/task_m010_367_stage2.md` | Stage 2 완료보고서 작성 | 변경/검증 결과 |

### 구현 기준

1. `org.libreoffice.hwp-document`는 `UTImportedTypeDeclarations`에 추가한다.
2. `UTTypeConformsTo`는 기존 HWP 호환 타입과 같이 `public.data`, `public.content` 기준으로 둔다.
3. `UTTypeTagSpecification`에는 `public.filename-extension = hwp`, `public.mime-type = application/x-hwp`를 반영한다.
4. HostApp `CFBundleDocumentTypes`의 `LSItemContentTypes`에 같은 UTI를 추가한다.
5. Quick Look preview/thumbnail extension의 `QLSupportedContentTypes`에 같은 UTI를 추가한다.
6. 기존 Hancom 계열 UTI와 알한글 소유 UTI는 제거하거나 순서를 크게 흔들지 않는다.

### 단계 검증

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
plutil -p Sources/HostApp/Info.plist | rg "org.libreoffice.hwp-document|Hangul WP 97|LSItemContentTypes|UTImportedTypeDeclarations"
plutil -p Sources/QLExtension/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
plutil -p Sources/ThumbnailExtension/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
git diff --check
```

### 단계 완료 기준

- 세 plist 모두 문법 검증을 통과한다.
- HostApp과 Quick Look/Thumbnail extension 모두 LibreOffice HWP UTI를 포함한다.
- renderer나 parser 코드 변경 없이 라우팅 선언만 보강된다.

### 커밋 메시지

```text
Task #367 Stage 2: LibreOffice HWP UTI 호환 선언 추가
```

## Stage 3 — Finder 통합 문서와 설치본 smoke 검증

### 목표

- LibreOffice 공존 진단 기준을 Finder 통합 troubleshooting 문서에 남긴다.
- 가능한 범위에서 설치본 기준 Quick Look/Thumbnail smoke를 수행하고, 로컬 재현 한계를 분리해 기록한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | LibreOffice UTI 공존 진단 기준 추가 | 필요 시 최소 보강 |
| `mydocs/working/task_m010_367_stage3.md` | Stage 3 완료보고서 작성 | 문서 변경, smoke 결과 |

### 문서 반영 기준

1. LibreOffice 설치 시 `.hwp`가 `org.libreoffice.hwp-document`로 분류될 수 있음을 진단 항목으로 추가한다.
2. `mdls -name kMDItemContentType -name kMDItemContentTypeTree <file.hwp>`로 실제 content type을 먼저 확인하도록 적는다.
3. 알한글이 지원하지 않는 외부 HWP UTI로 분류되면 Quick Look provider가 호출되지 않을 수 있다고 설명한다.
4. 해결책은 앱 제거가 아니라 알한글 supported content type 보강과 설치본 registration/cache 검증으로 정리한다.
5. 전역 LaunchServices reset, Finder/quicklook daemon kill은 기존 경고 기준을 유지한다.

### 단계 검증

```bash
git diff --check
rg -n "LibreOffice|org\\.libreoffice\\.hwp-document|mdls|Quick Look|Thumbnail" mydocs/troubleshootings/finder_integration_validation_pitfalls.md
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

### 설치본/Finder 통합 smoke 후보

```bash
mdls -name kMDItemContentType -name kMDItemContentTypeTree /tmp/alhangeul-KTX.hwp
pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension
pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension
mkdir -p /tmp/alhangeul-ql-libreoffice
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql-libreoffice /tmp/alhangeul-KTX.hwp
```

필요하면 signed/sealed 설치본 기준으로 기존 Finder integration helper를 사용한다. 이 경우 helper가 수행하는 등록/cache 갱신 범위와 결과 directory를 stage report에 기록한다.

### 단계 완료 기준

- LibreOffice 공존 진단 기준이 troubleshooting 문서에 남아 있다.
- HostApp Debug build가 통과한다.
- `pluginkit`, `mdls`, `qlmanage -t` 중 실행 가능한 smoke 결과와 실행 불가 사유가 보고서에 기록된다.

### 커밋 메시지

```text
Task #367 Stage 3: LibreOffice 공존 진단과 smoke 검증
```

## Stage 4 — 통합 검증과 최종 보고

### 목표

- 전체 변경을 다시 검증하고 최종 결과를 정리한다.
- 사용자가 보고한 증상에 대한 원인 판단, 수정 범위, 잔여 리스크를 기록한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/HostApp/Info.plist` | 필요 시 Stage 2/3 피드백 보정 | 최종 보정 |
| `Sources/QLExtension/Info.plist` | 필요 시 Stage 2/3 피드백 보정 | 최종 보정 |
| `Sources/ThumbnailExtension/Info.plist` | 필요 시 Stage 2/3 피드백 보정 | 최종 보정 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 필요 시 Stage 3 피드백 보정 | 최종 보정 |
| `mydocs/report/task_m010_367_report.md` | 최종 결과보고서 작성 | 모든 단계 완료 후 |
| `mydocs/orders/20260622.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
git status --short --branch
git diff --check
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
plutil -p Sources/HostApp/Info.plist | rg "org.libreoffice.hwp-document|LSItemContentTypes|UTImportedTypeDeclarations"
plutil -p Sources/QLExtension/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
plutil -p Sources/ThumbnailExtension/Info.plist | rg "org.libreoffice.hwp-document|QLSupportedContentTypes"
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
rg -n "LibreOffice|org\\.libreoffice\\.hwp-document|mdls" mydocs/troubleshootings/finder_integration_validation_pitfalls.md mydocs/report/task_m010_367_report.md
```

### 최종 보고 기준

- `org.libreoffice.hwp-document`를 지원하게 된 plist 변경 범위를 파일별로 요약한다.
- LibreOffice Quick Look appex가 HWP를 직접 지원하지 않아 provider 우선순위 경쟁보다는 content type mismatch 성격이 강하다는 판단을 기록한다.
- 로컬에서 LibreOffice UTI 선택 상태를 완전히 재현하지 못했다면 그 한계를 명확히 적는다.
- 이미 캐시된 Finder thumbnail은 즉시 갱신되지 않을 수 있음을 잔여 리스크로 남긴다.
- 후속으로 다른 앱의 별도 HWP UTI가 발견되면 같은 compatibility UTI 방식으로 별도 이슈를 등록할 수 있음을 남긴다.

### 커밋 메시지

```text
Task #367 Stage 4 + 최종 보고서: LibreOffice HWP UTI 공존 보강 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다. 승인 전에는 `Info.plist` 또는 troubleshooting 문서 변경을 시작하지 않는다.
