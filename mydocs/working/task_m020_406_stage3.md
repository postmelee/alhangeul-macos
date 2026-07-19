# Task M020 #406 Stage 3 완료보고서

## 단계 목적

Stage 2에서 추가한 HOP HWP/HWPX UTI 선언이 built app과 두 extension bundle에 반영됐는지 확인하고, 일반 HWP/HWPX 문서의 content type, 앱 open handoff, Quick Look/Thumbnail baseline을 검증한다.

HOP 설치본이 없는 로컬 환경에서 확정할 수 있는 결과와 실제 HOP UTI 선택 환경이 필요한 수동 검증을 분리하고, Finder 통합 troubleshooting 문서에 HOP 공존 진단 기준을 남긴다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 수정 | HOP HWP/HWPX custom UTI 공존 진단 절 추가, 뒤 절 번호 조정 |
| `mydocs/working/task_m020_406_stage3.md` | 신규 | bundle, registration, `mdls`, app open, thumbnail 검증과 재현 한계 기록 |
| `mydocs/orders/20260716.md` | 신규 | 현재 날짜 #406 상태를 `Stage 3 완료보고서 승인 대기`로 기록 |

구현계획서에는 `mydocs/orders/20260711.md` 갱신 후보가 있었지만 Stage 3 실행일이 2026년 7월 16일로 바뀌었다. 과거 작업 보드를 소급 수정하지 않고 현재 날짜 daily task board를 새로 생성했다.

Stage 3에서는 제품 source를 추가 변경하지 않았다. Stage 2에서 생성한 `build.noindex/DerivedData`와 `Frameworks/Rhwp.xcframework`를 검증에 재사용했으며 커밋하지 않는다. thumbnail 출력과 registration diagnostics는 `/private/tmp`에만 생성했다.

## 검증 결과

### Built bundle HOP UTI 반영

Debug build app과 두 appex의 최종 `Info.plist`에서 Stage 2 선언을 확인했다.

```text
Alhangeul.app/Contents/Info.plist
  LSItemContentTypes: net.golbin.hop.hwp, net.golbin.hop.hwpx
  UTImportedTypeDeclarations: net.golbin.hop.hwp, net.golbin.hop.hwpx

AlhangeulPreview.appex/Contents/Info.plist
  QLSupportedContentTypes: net.golbin.hop.hwp, net.golbin.hop.hwpx

AlhangeulThumbnail.appex/Contents/Info.plist
  QLSupportedContentTypes: net.golbin.hop.hwp, net.golbin.hop.hwpx
```

### Registration hygiene 시작 상태

문서 open smoke 전 check-only 결과는 exit 0이었다.

```text
$ scripts/check-extension-registration-hygiene.sh --check-only
Diagnostics: /private/tmp/alhangeul-extension-registration-hygiene/20260716-205736
Provider app roots: (none)
Development registrations: (none)
Legacy app candidates: (none)
Legacy extension candidates: (none)
Issues: (none)
```

`build.noindex` 아래 Debug app bundle이 존재한다는 warning만 있었고 등록된 상태는 아니었다.

### HWP/HWPX content type

sandbox 안의 `mdls`는 존재하는 상대·절대 경로를 `could not find`로 처리했다. 같은 절대 경로를 시스템 권한으로 재실행해 검증 실패를 회복했다.

```text
$ mdls -name kMDItemContentType -name kMDItemContentTypeTree KTX.hwp
kMDItemContentType = com.haansoft.hancomofficeviewer.mac.hwp
kMDItemContentTypeTree = (
    com.haansoft.hancomofficeviewer.mac.hwp,
    public.data,
    public.item
)

$ mdls -name kMDItemContentType -name kMDItemContentTypeTree hwpx-01.hwpx
kMDItemContentType = com.haansoft.hancomofficeviewer.mac.hwpx
kMDItemContentTypeTree = (
    com.haansoft.hancomofficeviewer.mac.hwpx,
    public.data,
    public.item
)
```

두 타입은 알한글이 기존부터 지원한다. 일반 HWP/HWPX 회귀 입력으로는 유효하지만 HOP custom UTI routing 재현은 아니다.

### HostApp 문서 open handoff

Debug app에 HWP와 HWPX를 순서대로 전달했다.

```text
$ open -n -a <task406 Debug Alhangeul.app> KTX.hwp
$ pgrep -x Alhangeul
46150
$ osascript ... name of windows
알한글

$ open -a <task406 Debug Alhangeul.app> hwpx-01.hwpx
$ pgrep -x Alhangeul
46150
$ osascript ... {name of windows, count of windows}
알한글, 알한글, 2
```

HWP와 HWPX 모두 같은 앱 프로세스에 전달됐고 두 문서 창이 유지됐다. smoke 후 bundle id `com.postmelee.alhangeul` 앱을 정상 종료했으며 프로세스가 남지 않은 것을 확인했다.

앱 내부 `NSOpenPanel`을 통한 수동 선택은 실행하지 않았다. `DocumentOpenPanel`은 Stage 2에서 compile됐고 기존 `.data` fallback도 유지되므로, HOP UTI가 실제 선택되는 환경에서의 수동 선택은 잔여 검증으로 분리한다.

### 개발 registration 정리

앱 실행 후 helper는 task406 Debug app registration이 남았다고 보고했다. 표준 `--cleanup-dev-registrations`를 실행했지만 check-only가 같은 경로를 계속 표시했다.

diagnostics를 확인한 결과 실제 LaunchServices entry는 부모 `Alhangeul.app`이 아니라 다음 nested Sparkle updater였다.

```text
/Users/melee/Documents/projects/rhwp-mac-task406/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app
```

helper의 app path 추출이 nested path 중간의 `Alhangeul.app`까지 잘라 부모 registration으로 오인했다. 두 appex는 이미 PlugInKit에서 제거된 상태였고 부모 app 직접 unregister는 `kLSApplicationNotFoundErr (-10814)`를 반환해 부모가 활성 registration이 아님을 확인했다.

실제로 등록된 nested `Updater.app` 하나만 `lsregister -u`로 해제한 뒤 check-only가 통과했다.

```text
Diagnostics: /private/tmp/alhangeul-extension-registration-hygiene/20260716-210608
Provider app roots: /Applications/Alhangeul.app
Development registrations: (none)
Legacy app candidates: (none)
Legacy extension candidates: (none)
Issues: (none)
```

개발 app bundle 파일은 삭제하지 않았고 전역 LaunchServices reset, Finder/Quick Look daemon 종료는 수행하지 않았다.

### Quick Look/Thumbnail baseline

최종 active provider는 공개 설치본 v0.1.7이었다.

```text
Quick Look provider:
  /Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
Thumbnail provider:
  /Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

공개 설치본은 HOP UTI를 포함하지 않으므로 다음 결과는 기존 Hancom Office Viewer UTI 문서의 일반 thumbnail baseline이다.

```text
$ qlmanage -t -x -s 512 -o /private/tmp/alhangeul-task406-stage3-thumbnail KTX.hwp hwpx-01.hwpx
KTX.hwp produced one thumbnail
hwpx-01.hwpx produced one thumbnail

KTX.hwp.png: 512 x 363 RGBA PNG
hwpx-01.hwpx.png: 363 x 512 RGBA PNG
```

두 PNG를 시각 확인한 결과 KTX 노선도/소요시간 표와 보도자료 본문/표가 표시됐고 blank 또는 generic fallback tile이 아니었다.

수정된 Debug extension은 signing/sealing된 Finder provider 검증 기준이 아니므로 등록하지 않았다. release packaging과 signing은 이 타스크 범위에서 제외했으며, HOP UTI를 통한 실제 Quick Look/Thumbnail routing은 재현하지 못했다.

### Troubleshooting 문서

`finder_integration_validation_pitfalls.md`에 다음 기준을 추가했다.

- HOP custom UTI `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`와 `Editor` / `Owner` 등록 특성
- HWP/HWPX 각각의 `mdls` content type 확인
- HostApp 문서 타입/imported declaration과 두 extension 지원 목록 대조
- Hancom/Hancom Office Viewer/LibreOffice UTI가 선택된 경우 HOP 원인으로 단정하지 않는 기준
- 기본 앱은 알한글이 강제하지 않고 LaunchServices와 사용자가 결정한다는 경계
- HOP 제거와 전역 LaunchServices reset을 기본 해결책으로 쓰지 않는 기준

문서 구조를 유지하기 위해 기존 `표준 helper 선택 기준`, `표시명 문제와 extension 실패 혼동 방지` 절 번호를 각각 7, 8로 조정했다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음
- Stage 2 UTI 구현 변경 없음
- troubleshooting 문서는 HOP 공존 진단 절만 추가하고 기존 LibreOffice/registration/표시명 본문은 유지
- 기존 절 번호 두 개만 순차 조정
- 과거 `mydocs/orders/20260711.md` 변경 없음
- 현재 날짜 `mydocs/orders/20260716.md` 신규 생성
- sample 문서 변경 없음
- Debug app, generated framework, thumbnail, diagnostics는 커밋 대상에서 제외

따라서 Stage 3은 검증·진단 문서 단계이며 제품 동작 본문은 무손실이다.

## 잔여 위험

- 로컬에 HOP 설치본이 없어 실제 파일이 `net.golbin.hop.hwp` 또는 `net.golbin.hop.hwpx`로 분류되는 상태를 재현하지 못했다.
- 사용자 제보 파일의 `mdls` 결과를 확보하지 못해 제보 환경의 직접 원인을 확정하지 못했다.
- Finder `다음으로 열기`와 기본 앱 후보에서 수정된 알한글 설치본이 표시되는지 HOP 공존 GUI smoke를 수행하지 못했다.
- 수정된 Quick Look/Thumbnail extension은 signed/sealed 설치본으로 등록하지 않았으므로 HOP UTI 기반 provider routing은 정적 bundle 선언까지만 확인했다.
- public v0.1.7 thumbnail 성공은 기존 일반 UTI 렌더 baseline이며 이번 HOP UTI 변경의 runtime 증거가 아니다.
- registration helper는 nested Sparkle `Updater.app` 경로를 parent app registration으로 오인할 수 있다. helper 보정은 #406 범위 밖이므로 이번 보고서에만 기록한다.
- `local/task406`은 Stage 3 시작 시 `origin/devel`보다 8커밋 뒤였다. 최종 PR 준비 전 integration conflict 여부를 확인해야 한다.

## 다음 단계 영향

Stage 4에서는 다음을 최종 gate로 사용한다.

1. source와 built bundle의 HOP UTI 선언 재검증
2. 세 plist lint와 HostApp Debug build 재검증
3. Stage 2/3 보고서의 HOP 계약, 재현 범위, 잔여 위험 일치 확인
4. troubleshooting HOP 공존 진단 절과 `mdls` 명령 확인
5. 변경 파일과 `origin/devel` 진행분의 conflict 가능성 확인
6. 최종 결과보고서에 사용자 영향, 실행한 smoke, 실행하지 못한 HOP 공존 수동 검증을 구분

HOP 설치 환경 또는 사용자 `mdls` 결과가 추가로 확보되면 Stage 4에 참고할 수 있지만, 정적 UTI 지원과 일반 HWP/HWPX 회귀 검증은 완료됐다.

## 승인 요청

Stage 3의 Finder 통합 검증 결과, HOP 공존 진단 문서, 재현 한계 검토를 요청한다. 승인 후 Stage 4 `통합 검증과 최종 보고`로 진행한다.
