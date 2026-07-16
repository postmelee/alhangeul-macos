# Task #406 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#406 HOP 등록 HWP/HWPX UTI 호환 지원 추가](https://github.com/postmelee/alhangeul-macos/issues/406) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 작업 브랜치 | `local/task406` |
| 단계 | Stage 1~4, Stage 3.1 보강 검증 포함 |
| HOP 기준 | `golbin/hop` v0.3.1, revision `bbd6bf69db05f275d714e7c61cef58b662809c6a` |

HOP이 등록한 HWP/HWPX 문서가 Finder `다음으로 열기` 후보에서 알한글을 찾지 못하는 호환성 문제를 수정했다. 알한글이 HOP 소유 UTI인 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`를 외부 호환 타입으로 인식하도록 HostApp, Quick Look preview, Finder thumbnail, 앱 내부 열기 패널의 지원 목록을 일치시켰다.

핵심 결과:

- HOP의 HWP/HWPX UTI 계약을 source와 로컬 설치본 v0.3.1에서 교차 확인했다.
- 기존 `Viewer` / `Alternate` 정책을 유지하고 HOP UTI만 additive하게 추가했다.
- HWPX Finder 후보에서 알한글 누락을 재현하고, 수정판 등록 후 같은 파일의 후보에 알한글이 추가되는 A/B 결과를 확보했다.
- exact HOP UTI handler 조회에서 수정판 등록 중 `com.postmelee.alhangeul`이 두 타입 모두에 추가되고 unregister 후 제거되는 것을 확인했다.
- 기존 HWP/HWPX 문서 open handoff, 일반 UTI Quick Look/Thumbnail baseline, HostApp Debug build가 회귀하지 않았다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Info.plist` | `LSItemContentTypes`에 HOP UTI 두 개 추가, HOP 계약과 일치하는 imported type declaration 두 개 추가 |
| `Sources/QLExtension/Info.plist` | `QLSupportedContentTypes`에 HOP HWP/HWPX UTI 추가 |
| `Sources/ThumbnailExtension/Info.plist` | `QLSupportedContentTypes`에 HOP HWP/HWPX UTI 추가 |
| `Sources/HostApp/Services/DocumentOpenPanel.swift` | 앱 내부 열기 패널의 명시 지원 타입에 HOP UTI 추가 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | HOP custom UTI 공존 진단, `mdls`, 선언 대조, 전역 reset 회피 기준 추가 |
| `mydocs/plans/task_m020_406.md` | 수행 범위, 제약, 수용 기준 기록 |
| `mydocs/plans/task_m020_406_impl.md` | 4단계 구현·검증 계획 기록 |
| `mydocs/working/task_m020_406_stage1.md` | HOP 계약과 알한글 지원 표면 누락 조사 |
| `mydocs/working/task_m020_406_stage2.md` | additive UTI 구현과 build 결과 |
| `mydocs/working/task_m020_406_stage3.md` | 일반 문서 open, thumbnail, registration 검증 |
| `mydocs/working/task_m020_406_stage3_followup.md` | HOP 설치 환경 exact handler 및 Finder 후보 A/B 검증 |
| `mydocs/report/task_m020_406_report.md` | 최종 결과와 잔여 위험 정리 |
| `mydocs/orders/20260711.md`, `mydocs/orders/20260716.md` | 단계 진행과 최종 완료 상태 기록 |

parser, renderer, Rust bridge, `Sources/RhwpCoreBridge`, `Sources/Shared`, `project.yml`, generated Xcode project는 변경하지 않았다. 기본 앱을 강제 설정하는 코드도 추가하지 않았다.

## 변경 전·후 비교

### 지원 표면

| 표면 | 변경 전 | 변경 후 |
|------|---------|---------|
| HostApp 문서 handler | 알한글/Hancom/Hancom Viewer/LibreOffice UTI | 기존 목록 + `net.golbin.hop.hwp`, `net.golbin.hop.hwpx` |
| HostApp imported declaration | HOP 계약 없음 | HOP HWP/HWPX extension, MIME, conformance 계약 포함 |
| Quick Look preview | HOP UTI 없음 | HOP UTI 두 개 지원 |
| Finder thumbnail | HOP UTI 없음 | HOP UTI 두 개 지원 |
| 앱 내부 열기 패널 | HOP UTI 없음, `.data` fallback 있음 | HOP UTI 두 개 추가, `.data` fallback 유지 |

제품 source 변경량은 `+51 / -0`이다. HostApp `Info.plist`가 `+45`, Quick Look/Thumbnail/OpenPanel이 각각 `+2`이며 기존 항목 삭제는 없다. troubleshooting 문서는 `+30 / -2`로 HOP 진단 절을 추가하고 뒤 절 번호만 조정했다.

### HOP 계약

| 형식 | Identifier | Extension | MIME type | Conforms to |
|------|------------|-----------|-----------|-------------|
| HWP | `net.golbin.hop.hwp` | `hwp` | `application/x-hwp` | `public.data` |
| HWPX | `net.golbin.hop.hwpx` | `hwpx` | `application/vnd.hancom.hwpx` | `public.data`, `public.zip-archive` |

알한글은 두 타입을 소유하지 않으므로 `UTImportedTypeDeclarations`로 선언한다. HOP의 `Editor` / `Owner`를 복제하지 않고 알한글의 `Viewer` / `Alternate` 역할을 유지한다.

## Finder와 LaunchServices 검증

### 수정 전 재현

HOP 0.3.1 설치 및 최초 실행 후 fresh HWPX 파일의 Finder 후보는 다음과 같았다.

```text
한컴오피스 한글 Viewer(기본), 아카이브 유틸리티,
HOP, The Unarchiver
알한글 없음
```

`NSWorkspace.shared.urlsForApplications(toOpen:)`도 HOP은 반환하고 공개 설치본 알한글 v0.1.7은 반환하지 않았다. 현재 로컬에서는 HWPX로 사용자 제보를 재현했다. HWP는 기존 공개 알한글이 이미 후보였으므로 제보 당시와 등록 상태가 달랐다.

### 수정 후 A/B

task406 Debug app을 임시 등록한 동안 exact UTI handler 결과는 다음과 같았다.

```text
net.golbin.hop.hwp:
  com.haansoft.HancomOfficeViewer.Mac
  com.postmelee.alhangeul
  net.golbin.hop

net.golbin.hop.hwpx:
  com.apple.archiveutility
  com.haansoft.HancomOfficeViewer.Mac
  com.postmelee.alhangeul
  cx.c3.theunarchiver
  net.golbin.hop
```

같은 HWPX 파일의 Finder 후보에는 `알한글`이 추가됐다.

```text
한컴오피스 한글 Viewer(기본), 아카이브 유틸리티,
알한글, HOP, The Unarchiver
```

수정판 unregister 후 exact handler에서 `com.postmelee.alhangeul`이 다시 사라졌고 `NSWorkspace` 후보에서도 task406 Debug 경로가 제거됐다. 이 A/B 결과로 HOP UTI 선언과 Finder 후보 노출의 인과 경계를 확인했다.

### `mdls` 결과 해석

현재 시스템에서는 HOP 실행 전후 fresh HWP/HWPX 복사본 모두 한컴 Viewer UTI로 분류됐다.

```text
HWP  = com.haansoft.hancomofficeviewer.mac.hwp
HWPX = com.haansoft.hancomofficeviewer.mac.hwpx
```

한컴 Viewer bundle을 일시 unregister한 뒤에도 Spotlight/LaunchServices type cache가 유지되어 `net.golbin.hop.*` 직접 분류는 재현하지 못했다. 한컴 Viewer는 즉시 다시 register했으며 앱 삭제나 전역 LaunchServices reset은 수행하지 않았다.

직접 `mdls net.golbin.*` 재현은 미완료지만, exact UTI handler A/B와 실제 HWPX Finder GUI A/B가 #406의 HostApp 후보 수정 성립을 확인하는 근거다.

## 일반 회귀 검증

### 앱 문서 열기

Debug 앱에 HWP와 HWPX를 순서대로 전달했다. 두 파일 모두 같은 `Alhangeul` 프로세스에 전달됐고 문서 창 두 개가 유지됐다. smoke 후 앱을 종료하고 개발 registration을 정리했다.

### Quick Look/Thumbnail baseline

공개 설치본 v0.1.7의 active provider로 일반 Hancom Viewer UTI HWP/HWPX 샘플 thumbnail을 생성했다.

| 샘플 | 결과 |
|------|------|
| HWP | `512x363` RGBA PNG, 문서 내용 표시, blank/fallback 아님 |
| HWPX | `363x512` RGBA PNG, 문서 내용 표시, blank/fallback 아님 |

이 결과는 기존 문서 렌더 회귀 baseline이며 HOP exact UTI extension runtime 증거로 사용하지 않는다.

## 최종 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| 세 source plist 문법 | OK | `plutil -lint` 모두 `OK` |
| HostApp 문서 타입/imported declaration | OK | HOP UTI 두 개와 extension/MIME/conformance 확인 |
| Quick Look/Thumbnail 지원 목록 | OK | source와 built appex에서 두 HOP UTI 확인 |
| 앱 내부 열기 패널 | OK | 두 HOP UTI 포함, `.data` fallback 유지 |
| `origin/devel` 통합 | OK | #408 8커밋 merge, orders add/add 한 건에서 두 task 행 보존 |
| Rust framework lock/FFI | OK | `build-rust-macos.sh --verify-lock`, 15개 FFI symbol과 `rhwp-core.lock` 검증 |
| HostApp Debug build | OK | 통합 전 `4.218 sec`, 통합 후 재생성 XCFramework 기준 `12.900 sec` 모두 `BUILD SUCCEEDED` |
| built bundle 반영 | OK | app과 두 embedded appex 최종 `Info.plist` 확인 |
| Finder 후보 수정 효과 | OK | HWPX 수정 전 누락, 수정판 등록 후 알한글 추가 |
| exact HOP UTI handler | OK | 두 타입 모두 수정판 등록 중 `com.postmelee.alhangeul` 포함 |
| 기존 HWP/HWPX open | OK | 동일 앱 프로세스에 두 문서 handoff 확인 |
| registration 정리 | OK | 통합 후 diagnostics `20260716-215244`, development registrations/issues 없음 |
| `git diff --check` | OK | whitespace 오류 없음 |

최종 실행 명령:

```bash
plutil -lint Sources/HostApp/Info.plist \
  Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
plutil -p Sources/HostApp/Info.plist | rg "net.golbin.hop.(hwp|hwpx)"
plutil -p Sources/QLExtension/Info.plist | rg "net.golbin.hop.(hwp|hwpx)"
plutil -p Sources/ThumbnailExtension/Info.plist | rg "net.golbin.hop.(hwp|hwpx)"
rg -n "net.golbin.hop.(hwp|hwpx)" Sources/HostApp/Services/DocumentOpenPanel.swift
./scripts/build-rust-macos.sh --verify-lock
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
```

## 단계 요약

| Stage | 커밋 | 요약 |
|-------|------|------|
| 계획 | `29c2f9e` | 수행계획서와 오늘할일 작성 |
| 구현계획 | `61eedec` | 4단계 구현·검증 계획 작성 |
| Stage 1 | `a39d343` | HOP UTI 계약과 알한글 누락 표면 확인 |
| Stage 2 | `3766442` | 네 지원 표면에 HOP HWP/HWPX UTI 추가 |
| Stage 3 | `80256a1` | 일반 문서 open, thumbnail, registration 검증 |
| Stage 3.1 | `995b6a0` | HOP 설치 환경 exact handler와 Finder 후보 A/B 검증 |
| Stage 4 | `92fc683` | 통합 검증과 최종 보고 |

## 통합 브랜치 상태

최종 검증 후 `origin/devel`의 #408 RustBridge external image context C ABI 작업 8커밋을 `local/task406`에 merge했다.

사전 `git merge-tree` 결과와 동일하게 #406 제품 source 및 troubleshooting 문서는 충돌 없이 병합됐다. 양쪽 브랜치가 각각 추가한 `mydocs/orders/20260711.md`에서만 add/add 충돌이 발생했고, #406과 #408 행을 모두 보존해 해결했다.

통합 후 `build-rust-macos.sh --verify-lock`으로 #408의 새 FFI 15개와 framework lock을 검증하고 XCFramework를 재생성했다. 해당 framework로 HostApp, Quick Look, Thumbnail을 다시 compile/link했으며 `BUILD SUCCEEDED` (`12.900 sec`)를 확인했다. 최종 registration hygiene diagnostics `20260716-215244`도 development registrations와 issues가 없었다.

## 잔여 위험과 후속 작업

| 항목 | 상태 | 처리 |
|------|------|------|
| 실제 파일의 `net.golbin.hop.*` `mdls` 분류 | 한컴 Viewer UTI cache 우선으로 미재현 | 깨끗한 사용자 계정/VM의 HOP 단독 환경에서 릴리스 smoke로 보강 가능. #406 merge blocker는 아님 |
| HOP exact UTI Quick Look/Thumbnail active provider | Debug unsigned/unsealed 산출물이라 runtime 미검증 | 서명된 설치본 release smoke에서 확인. source/built bundle 선언은 확인 완료 |
| HWP Finder GUI 직접 A/B | 현재 공개 알한글이 이미 후보여서 누락 미재현 | exact `net.golbin.hop.hwp` handler A/B로 지원 자격 확인. 직접 Finder 재현 입력은 HWPX |
| LaunchServices/Spotlight cache | 설치·실행 순서와 기존 owner UTI에 영향받음 | troubleshooting 기준에 설치 위치, 최초 실행, `mdls`, 선언 대조 순서 기록 |
| `origin/devel` 통합 | `mydocs/orders/20260711.md` add/add 한 건 해결 | #406과 #408 행을 모두 보존했으며 제품 source 충돌 없음 |

## 결론

#406의 핵심 문제는 알한글이 HOP 소유 HWP/HWPX UTI를 문서 handler로 선언하지 않은 호환성 누락이다. 두 UTI를 HostApp과 Finder extension, 앱 내부 열기 패널에 일관되게 추가했고, 수정판 등록 전후 exact handler와 Finder HWPX 후보가 함께 바뀌는 것을 확인했다.

Finder 기본 앱은 알한글이 강제로 변경하지 않는다. 이번 수정은 사용자가 Finder `정보 가져오기 > 다음으로 열기 > 모두 변경`을 선택할 수 있도록 알한글을 호환 후보로 등록하는 변경이다.

## 승인 요청

`origin/devel` 통합과 최종 검증 결과를 포함한 Open PR의 리뷰 및 merge 승인을 요청한다.
