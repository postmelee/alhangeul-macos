# Task #406 구현계획서

본 문서는 [`task_m020_406.md`](task_m020_406.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) 스킬로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- Worktree: `/Users/melee/Documents/projects/rhwp-mac-task406`
- Branch: `local/task406`
- 기준 브랜치: `devel`
- 기준 이슈: [#406](https://github.com/postmelee/alhangeul-macos/issues/406)
- 마일스톤: M020 (`v0.2`)
- 범위: HOP가 등록한 HWP/HWPX UTI를 HostApp, Quick Look, Thumbnail, 앱 내부 열기 패널의 호환 타입으로 지원

## 구현 원칙

- `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`는 알한글 소유 UTI가 아니라 HOP가 소유하는 imported compatibility UTI로 취급한다.
- HOP의 identifier, filename extension, MIME type, conforming type은 확인한 HOP source 설정을 기준으로 선언한다.
- HostApp 문서 타입, Quick Look preview, Finder thumbnail, 앱 내부 열기 패널의 HOP UTI 목록을 동일하게 맞춘다.
- 기존 알한글, Hancom, Hancom Office Viewer, LibreOffice UTI 선언은 제거하거나 의미를 변경하지 않는다.
- `CFBundleTypeRole=Viewer`, `LSHandlerRank=Alternate`를 유지하며 macOS 기본 앱을 강제로 변경하지 않는다.
- 파일 parser, renderer, fallback classifier, `project.yml`, `Alhangeul.xcodeproj`는 변경하지 않는다.
- 전역 LaunchServices reset, Finder/Quick Look daemon 강제 종료, HOP 설치/삭제 자동화는 수행하지 않는다.
- 사용자 제보의 실제 content type을 확보하지 못한 상태이므로 HOP UTI 누락을 수정하되 단일 확정 원인으로 기록하지 않는다.
- 각 단계는 완료보고서와 검증을 마친 뒤 승인을 받아야 다음 단계로 넘어간다.

## Stage 1 — HOP UTI 계약과 알한글 지원 표면 재확인

### 목표

- HOP가 등록하는 HWP/HWPX UTI 계약을 source 기준으로 고정한다.
- 알한글의 네 지원 표면에서 두 HOP UTI가 누락된 상태를 표로 기록한다.
- 정적 선언 검증과 실제 LaunchServices 재현 검증의 완료 기준을 분리한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/working/task_m020_406_stage1.md` | HOP source revision, UTI 계약, 알한글 누락 matrix, 재현 한계 기록 | 조사 보고서 |
| `mydocs/orders/20260711.md` | Stage 1 완료 후 승인 대기 상태 반영 | 오늘할일 |

### 조사 기준

1. HOP `apps/desktop/src-tauri/tauri.conf.json`의 HWP/HWPX `fileAssociations`를 확인한다.
2. HWP는 identifier `net.golbin.hop.hwp`, extension `hwp`, MIME type `application/x-hwp`, conformance `public.data`인지 확인한다.
3. HWPX는 identifier `net.golbin.hop.hwpx`, extension `hwpx`, MIME type `application/vnd.hancom.hwpx`, conformance `public.data`, `public.zip-archive`인지 확인한다.
4. HOP의 Quick Look preview/thumbnail `Info.plist`에도 같은 custom UTI가 포함되는지 확인한다.
5. 알한글의 다음 네 표면에서 HOP UTI가 누락됐는지 확인한다.
   - `Sources/HostApp/Info.plist`의 `CFBundleDocumentTypes`, `UTImportedTypeDeclarations`
   - `Sources/QLExtension/Info.plist`의 `QLSupportedContentTypes`
   - `Sources/ThumbnailExtension/Info.plist`의 `QLSupportedContentTypes`
   - `Sources/HostApp/Services/DocumentOpenPanel.swift`의 `supportedContentTypes`
6. `/Applications` 또는 `$HOME/Applications`에 HOP 설치본이 있으면 bundle 선언과 샘플 `mdls` 결과를 참고 자료로 기록한다. 설치본이 없으면 source 계약 검증만 필수로 둔다.

### 단계 검증

```bash
git -C /private/tmp/hop-uti-analysis rev-parse HEAD
rg -n "net.golbin.hop.(hwp|hwpx)|application/x-hwp|application/vnd.hancom.hwpx|fileAssociations|contentTypes" \
  /private/tmp/hop-uti-analysis/apps/desktop/src-tauri
rg -n "LSItemContentTypes|UTImportedTypeDeclarations|QLSupportedContentTypes|supportedContentTypes|net.golbin.hop" \
  Sources/HostApp/Info.plist Sources/QLExtension/Info.plist \
  Sources/ThumbnailExtension/Info.plist Sources/HostApp/Services/DocumentOpenPanel.swift
git diff --check -- mydocs/working/task_m020_406_stage1.md mydocs/orders/20260711.md
```

`/private/tmp/hop-uti-analysis`가 없으면 확인한 HOP commit을 별도 임시 checkout으로 다시 준비한다. 네트워크 또는 설치본 접근이 불가능한 경우 기존 조사 결과와 GitHub source URL을 보고서에 남기고 해당 명령을 미실행 사유와 함께 기록한다.

### 단계 완료 기준

- 확인한 HOP commit과 두 UTI의 identifier, extension, MIME type, conforming type이 보고서에 기록된다.
- 알한글의 네 지원 표면별 누락 상태가 기록된다.
- HOP 설치본 또는 사용자 `mdls` 결과가 없어도 확정 가능한 수정 범위와, 설치본에서만 확인 가능한 항목이 분리된다.
- 제품 source는 변경되지 않는다.

### 커밋 메시지

```text
Task #406 Stage 1: HOP UTI 계약과 지원 표면 확인
```

## Stage 2 — HOP HWP/HWPX UTI 호환 선언 구현

### 목표

- HostApp과 두 Finder extension이 HOP HWP/HWPX UTI를 호환 문서 타입으로 선언하게 한다.
- 앱 내부 열기 패널에도 같은 UTI를 명시해 지원 타입 목록을 일치시킨다.
- plist 문법과 HostApp compile을 검증한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/HostApp/Info.plist` | 문서 타입과 imported type declaration에 HOP HWP/HWPX 추가 | LaunchServices 앱 후보 등록 |
| `Sources/QLExtension/Info.plist` | `QLSupportedContentTypes`에 HOP UTI 두 개 추가 | Quick Look preview |
| `Sources/ThumbnailExtension/Info.plist` | `QLSupportedContentTypes`에 HOP UTI 두 개 추가 | Finder thumbnail |
| `Sources/HostApp/Services/DocumentOpenPanel.swift` | `supportedContentTypes`에 HOP UTI 두 개 추가 | 앱 내부 열기 패널 |
| `mydocs/working/task_m020_406_stage2.md` | 변경 내용과 정적/build 검증 결과 기록 | 단계 완료보고서 |
| `mydocs/orders/20260711.md` | Stage 2 완료 후 승인 대기 상태 반영 | 오늘할일 |

### 구현 기준

1. HostApp `CFBundleDocumentTypes[0].LSItemContentTypes`에 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`를 추가한다.
2. HostApp `UTImportedTypeDeclarations`에 HOP HWP 타입을 다음 계약으로 추가한다.
   - `UTTypeIdentifier`: `net.golbin.hop.hwp`
   - `UTTypeConformsTo`: `public.data`
   - filename extension: `hwp`
   - MIME type: `application/x-hwp`
3. HOP HWPX 타입은 다음 계약으로 추가한다.
   - `UTTypeIdentifier`: `net.golbin.hop.hwpx`
   - `UTTypeConformsTo`: `public.data`, `public.zip-archive`
   - filename extension: `hwpx`
   - MIME type: `application/vnd.hancom.hwpx`
4. Quick Look preview와 Finder thumbnail `QLSupportedContentTypes`에 두 identifier를 같은 순서로 추가한다.
5. `DocumentOpenPanel.supportedContentTypes`에 두 identifier를 추가한다. 기존 `.data` fallback 정책은 변경하지 않는다.
6. 기존 UTI 선언의 role, rank, conformance, MIME type, 배열 순서를 불필요하게 변경하지 않는다.
7. 이 변경을 위해 `project.yml` 또는 generated `Alhangeul.xcodeproj`를 수정하지 않는다.

### 단계 검증

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
plutil -p Sources/HostApp/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|application/x-hwp|application/vnd.hancom.hwpx|LSItemContentTypes|UTImportedTypeDeclarations"
plutil -p Sources/QLExtension/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|QLSupportedContentTypes"
plutil -p Sources/ThumbnailExtension/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|QLSupportedContentTypes"
rg -n "net.golbin.hop.(hwp|hwpx)" Sources/HostApp/Services/DocumentOpenPanel.swift
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
git diff --check
```

새 worktree에 `Frameworks/Rhwp.xcframework`가 없으면 `./scripts/build-rust-macos.sh`로 먼저 생성한다. 이 산출물은 `build.noindex/`와 기존 generated artifact 정책을 따르고 커밋하지 않는다.

### 단계 완료 기준

- 세 plist가 문법 검증을 통과한다.
- HostApp 문서 타입과 imported declaration에 HOP HWP/HWPX 계약이 정확히 포함된다.
- Quick Look, Thumbnail, 앱 내부 열기 패널에 두 HOP UTI가 모두 포함된다.
- HostApp Debug build가 통과한다.
- parser, renderer, 기존 UTI 동작에는 변경이 없다.

### 커밋 메시지

```text
Task #406 Stage 2: HOP HWP/HWPX UTI 호환 선언 추가
```

## Stage 3 — HOP 공존 Finder 통합과 문서 열기 검증

### 목표

- build 또는 package 산출물에 source의 HOP UTI 선언이 반영됐는지 확인한다.
- 가능한 환경에서 LaunchServices, Finder 기본 앱 후보, Quick Look/Thumbnail, 앱 문서 열기를 검증한다.
- 재현 가능한 결과와 사용자 환경 의존 항목을 구분하고 필요한 진단 문서만 최소 보강한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | third-party UTI와 `mdls` 진단 기준 보강 | 기존 문서가 충분하면 변경 생략 |
| `mydocs/working/task_m020_406_stage3.md` | bundle, LaunchServices, 문서 열기, Quick Look/Thumbnail 결과 기록 | 단계 완료보고서 |
| `mydocs/orders/20260711.md` | Stage 3 완료 후 승인 대기 상태 반영 | 오늘할일 |

### 검증 기준

1. Debug build app과 두 appex의 built `Info.plist`에서 HOP UTI를 확인한다.
2. 설치본 기준 smoke 전 `scripts/check-extension-registration-hygiene.sh --check-only`로 개발 산출물 등록 오염 여부를 확인한다.
3. HOP가 설치돼 있으면 fresh HWP/HWPX 샘플의 `mdls` content type과 type tree를 기록한다.
4. `lsregister` 진단에서 알한글이 두 HOP UTI의 Viewer/Alternate handler로 선언되는지 확인한다.
5. Finder `정보 가져오기 > 다음으로 열기`와 우클릭 `다음으로 열기` 후보는 GUI 수동 smoke로 확인한다.
6. 앱 내부 열기 패널과 `/usr/bin/open -a <Alhangeul.app> <sample>`로 HWP/HWPX 문서 열기 handoff를 확인한다.
7. signed/sealed 설치본을 준비할 수 있으면 표준 Finder integration helper로 Quick Look/Thumbnail smoke를 수행한다.
8. HOP UTI가 실제 선택되는 환경을 재현하지 못하면 static bundle declaration과 일반 HWP/HWPX 회귀를 필수 결과로 남기고, HOP 공존 후보 노출은 수동 검증 필요 항목으로 기록한다.

### 단계 검증

```bash
APP="build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app"
plutil -p "$APP/Contents/Info.plist" | rg "net.golbin.hop.(hwp|hwpx)|LSItemContentTypes|UTImportedTypeDeclarations"
plutil -p "$APP/Contents/PlugIns/AlhangeulPreview.appex/Contents/Info.plist" | rg "net.golbin.hop.(hwp|hwpx)|QLSupportedContentTypes"
plutil -p "$APP/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/Info.plist" | rg "net.golbin.hop.(hwp|hwpx)|QLSupportedContentTypes"
scripts/check-extension-registration-hygiene.sh --check-only
mdls -name kMDItemContentType -name kMDItemContentTypeTree samples/basic/KTX.hwp
mdls -name kMDItemContentType -name kMDItemContentTypeTree samples/hwpx/hwpx-01.hwpx
git diff --check
```

설치본/Finder 통합 smoke 후보:

```bash
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension
pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension
/usr/bin/open -n -a /absolute/path/to/Alhangeul.app "$PWD/samples/basic/KTX.hwp"
/usr/bin/open -a /absolute/path/to/Alhangeul.app "$PWD/samples/hwpx/hwpx-01.hwpx"
```

설치본 등록, 앱 실행, Finder GUI 확인은 해당 단계 승인 범위에서만 수행한다. 등록 정리가 필요하면 표준 helper가 제공하는 후보 app/appex 단위 절차만 사용하며 전역 LaunchServices reset은 하지 않는다.

### 단계 완료 기준

- built app과 두 appex에 HOP UTI 선언이 포함된 것이 확인된다.
- HWP/HWPX 일반 샘플의 앱 open handoff가 회귀하지 않는다.
- 실행 가능한 LaunchServices, Finder, Quick Look, Thumbnail smoke 결과가 기록된다.
- HOP UTI가 실제 선택되는 환경을 재현하지 못한 경우 그 한계와 사용자 `mdls` 후속 확인 필요성이 명시된다.
- troubleshooting 문서는 기존 내용으로 진단이 부족한 경우에만 최소 변경된다.

### 커밋 메시지

```text
Task #406 Stage 3: HOP 공존 Finder 통합과 문서 열기 검증
```

## Stage 4 — 통합 검증과 최종 보고

### 목표

- 전체 변경과 단계별 검증 결과를 다시 확인한다.
- 사용자 제보에 대한 수정 범위, 확인된 효과, 재현 한계, 잔여 리스크를 최종 보고서에 정리한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/HostApp/Info.plist` | 필요 시 승인된 피드백 범위의 최종 보정 | UTI 선언 |
| `Sources/QLExtension/Info.plist` | 필요 시 승인된 피드백 범위의 최종 보정 | Quick Look |
| `Sources/ThumbnailExtension/Info.plist` | 필요 시 승인된 피드백 범위의 최종 보정 | Thumbnail |
| `Sources/HostApp/Services/DocumentOpenPanel.swift` | 필요 시 승인된 피드백 범위의 최종 보정 | 앱 열기 패널 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 필요 시 Stage 3 결과 보정 | 진단 문서 |
| `mydocs/report/task_m020_406_report.md` | 최종 결과보고서 작성 | 전체 결과 |
| `mydocs/orders/20260711.md` | 작업 상태 완료 처리 | 완료 시간 기록 |

### 최종 검증

```bash
git status --short --branch
git diff --check
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
plutil -p Sources/HostApp/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|LSItemContentTypes|UTImportedTypeDeclarations"
plutil -p Sources/QLExtension/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|QLSupportedContentTypes"
plutil -p Sources/ThumbnailExtension/Info.plist | rg "net.golbin.hop.(hwp|hwpx)|QLSupportedContentTypes"
rg -n "net.golbin.hop.(hwp|hwpx)" Sources/HostApp/Services/DocumentOpenPanel.swift
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
rg -n "#406|HOP|net.golbin.hop|LaunchServices|mdls|잔여" \
  mydocs/working/task_m020_406_stage*.md mydocs/report/task_m020_406_report.md mydocs/orders/20260711.md
```

### 최종 보고 기준

- 네 지원 표면에 추가된 HOP HWP/HWPX UTI를 파일별로 요약한다.
- 사용자 제보의 직접 원인을 확정할 수 있는 `mdls` 결과 확보 여부를 명시한다.
- Finder 기본 앱 후보는 앱이 강제하는 기능이 아니라 LaunchServices 선언과 사용자 선택의 결과임을 기록한다.
- HOP 설치 상태에서 실행한 smoke와 실행하지 못한 수동 검증을 구분한다.
- 기존 HWP/HWPX open, Quick Look, Thumbnail 경로의 회귀 여부를 기록한다.
- 이미 캐시된 LaunchServices/Quick Look 상태와 다른 third-party UTI는 잔여 리스크로 분리한다.

### 커밋 메시지

```text
Task #406 Stage 4 + 최종 보고서: HOP HWP/HWPX UTI 호환 지원 완료
```

## 승인 요청 사항

이 구현계획 기준으로 Stage 1 진행 승인을 요청한다. 승인 전에는 `Info.plist`, `DocumentOpenPanel.swift`, troubleshooting 문서를 변경하지 않는다.
