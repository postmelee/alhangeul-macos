# Task M020 #406 Stage 3.1 보강 검증 보고서

## 단계 목적

HOP 설치본이 없었던 Stage 3의 재현 한계를 보완한다. HOP이 실제로 등록하는 HWP/HWPX UTI 계약을 설치 bundle과 LaunchServices에서 확인하고, 수정 전후의 exact UTI handler 및 Finder `다음으로 열기` 후보를 A/B 비교한다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/working/task_m020_406_stage3_followup.md` | 신규 | HOP 설치 환경의 UTI routing과 Finder 후보 A/B 검증 기록 |
| `mydocs/orders/20260716.md` | 수정 | #406 상태를 `Stage 3.1 완료보고서 승인 대기`로 갱신 |

제품 source와 Stage 2 UTI 선언은 변경하지 않았다. 검증용 HWP/HWPX 복사본은 `/private/tmp/alhangeul-task406-hop-routing`에만 생성했고 검증 후 삭제했다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음
- 기존 Stage 1~3 보고서 변경 없음
- 설치된 HOP과 한컴 Viewer app bundle 변경 없음
- 기본 앱 설정 변경 없음
- 전역 LaunchServices reset 및 Finder/Quick Look daemon 종료 없음
- task406 Debug app/appex는 검증 중에만 등록하고 종료 전에 정확한 bundle 경로로 해제

따라서 Stage 3.1은 설치 환경의 runtime routing 보강 검증이며 제품 본문은 무손실이다.

## 검증 결과

### HOP 설치 bundle 계약

설치본은 `/Applications/HOP.app`, 버전은 `0.3.1`, bundle identifier는 `net.golbin.hop`이었다. `Info.plist`에서 다음 계약을 확인했다.

```text
CFBundleDocumentTypes
  HWP:  Editor / Owner
        net.golbin.hop.hwp
        com.hancom.hwp
        com.haansoft.hancomofficeviewer.mac.hwp
  HWPX: Editor / Owner
        net.golbin.hop.hwpx
        com.hancom.hwpx
        com.haansoft.hancomofficeviewer.mac.hwpx

UTExportedTypeDeclarations
  net.golbin.hop.hwp
    conforms: public.data
    extension: hwp
    MIME: application/x-hwp
  net.golbin.hop.hwpx
    conforms: public.data, public.zip-archive
    extension: hwpx
    MIME: application/vnd.hancom.hwpx
```

Quick Look Preview/Thumbnail appex도 두 HOP UTI와 Hancom 계열 UTI를 지원한다. Stage 2에서 알한글에 추가한 imported declaration은 이 설치 계약과 일치한다.

HOP 디스크 이미지가 `/Volumes/HOP`에 마운트되어 동일 bundle identifier가 두 위치에 있었고, 최초 LaunchServices entry는 `/Applications/HOP.app`을 `launch-disabled`로 표시했다. 설치본을 한 번 실행한 뒤 해당 flag가 사라지고 두 Quick Look extension도 설치본 경로로 등록됐다.

### 실제 파일 content type

HOP 실행 전후에 새 복사본을 만들었지만, 현재 시스템에서는 한컴 Viewer의 exported UTI가 우선됐다.

```text
HWP  kMDItemContentType = com.haansoft.hancomofficeviewer.mac.hwp
HWPX kMDItemContentType = com.haansoft.hancomofficeviewer.mac.hwpx
```

한컴 Viewer를 bundle 경로로 잠시 unregister한 뒤 만든 새 복사본도 같은 결과였다. LaunchServices/Spotlight의 기존 type declaration cache가 유지된 것으로 판단하며, 한컴 Viewer는 즉시 다시 register했다. 앱 삭제나 전역 registry reset은 수행하지 않았다.

따라서 이 환경에서는 파일의 `mdls` 값을 `net.golbin.hop.*`로 직접 전환하지 못했다. 대신 exact UTI handler API와 실제 Finder 후보를 함께 검증했다.

### 수정 전 Finder/NSWorkspace 기준선

HOP 최초 실행 후 새 파일에서 확인한 결과는 다음과 같다.

```text
HWP Finder 후보
  한컴오피스 한글 Viewer(기본), 알한글, LibreOffice, LibreOfficeDev

HWPX Finder 후보
  한컴오피스 한글 Viewer(기본), 아카이브 유틸리티,
  HOP, The Unarchiver
  알한글 없음
```

`NSWorkspace.shared.urlsForApplications(toOpen:)`도 HWPX에서 HOP은 반환하고 공개 설치본 알한글 v0.1.7은 반환하지 않았다. 현재 로컬 상태에서는 사용자 제보를 HWPX에서 재현했다. HWP는 공개 설치본 알한글이 이미 후보였으므로 제보 당시와 등록 상태가 달랐다.

### 수정판 임시 등록 A/B

task406 Debug app의 built `Info.plist`에 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`가 포함된 것을 재확인한 뒤 해당 app bundle만 `lsregister -f`로 임시 등록했다.

등록 중 exact UTI handler 결과는 다음과 같았다.

```text
net.golbin.hop.hwp =
  com.haansoft.HancomOfficeViewer.Mac
  com.postmelee.alhangeul
  net.golbin.hop

net.golbin.hop.hwpx =
  com.apple.archiveutility
  com.haansoft.HancomOfficeViewer.Mac
  com.postmelee.alhangeul
  cx.c3.theunarchiver
  net.golbin.hop
```

같은 HWPX 파일을 Finder에서 다시 확인하자 후보가 다음과 같이 바뀌었다.

```text
한컴오피스 한글 Viewer(기본), 아카이브 유틸리티,
알한글, HOP, The Unarchiver
```

`NSWorkspace`도 `/Users/melee/Documents/projects/rhwp-mac-task406/build.noindex/.../Alhangeul.app`을 HWPX 후보로 반환했다. 수정판 등록 전에는 없던 `알한글` 후보가 등록 후 추가됐으므로 Stage 2의 HOP UTI 선언이 문제의 routing 원인을 직접 해소함을 확인했다.

### 검증 환경 정리

task406 Debug Preview/Thumbnail appex, nested Sparkle `Updater.app`, parent `Alhangeul.app`을 각각 정확한 경로로 unregister하고 Quick Look cache를 reset했다. 정리 후 exact HOP UTI handler에서 `com.postmelee.alhangeul`이 다시 사라져 A/B 경계도 확인했다.

```text
net.golbin.hop.hwp =
  com.haansoft.HancomOfficeViewer.Mac, net.golbin.hop

net.golbin.hop.hwpx =
  com.apple.archiveutility, com.haansoft.HancomOfficeViewer.Mac,
  cx.c3.theunarchiver, net.golbin.hop
```

최종 hygiene helper 결과는 다음과 같았다.

```text
Diagnostics: /private/tmp/alhangeul-extension-registration-hygiene/20260716-212857
Provider app roots: /Applications/Alhangeul.app
Development registrations: (none)
Legacy app candidates: (none)
Legacy extension candidates: (none)
Issues: (none)
```

HOP 프로세스와 검증용 임시 파일도 남지 않았다. `/Applications/HOP.app`과 사용자가 마운트한 `/Volumes/HOP`은 변경하지 않았다.

## 잔여 위험

- 한컴 Viewer UTI cache가 우선되어 실제 파일의 `mdls` 값을 `net.golbin.hop.hwp` 또는 `net.golbin.hop.hwpx`로 만드는 재현은 완료하지 못했다.
- 수정된 Quick Look/Thumbnail extension은 Debug unsigned/unsealed 산출물이므로 HOP exact UTI 기반 active provider runtime은 검증하지 않았다. source와 built bundle의 지원 선언만 Stage 2/3에서 확인했다.
- 현재 로컬에서는 HWP가 기존 공개 알한글 후보를 반환했다. 사용자 제보 당시 HWP 누락은 설치/등록 상태 차이일 수 있으며, 이번 A/B의 직접 재현 입력은 HWPX다.
- HOP 디스크 이미지가 계속 마운트되어 같은 bundle identifier가 `/Applications`와 `/Volumes/HOP`에 중복 존재한다. 이번 결과에는 두 경로가 함께 관찰됐으나 수정판 HWPX 후보 추가 여부에는 영향을 주지 않았다.
- `local/task406`은 `origin/devel`보다 8커밋 뒤이므로 Stage 4에서 integration conflict를 확인해야 한다.

## 다음 단계 영향

Stage 4 최종 보고에서는 Stage 3의 HOP 미설치 한계를 이 보강 보고서로 대체한다. 다음 내용을 최종 근거로 사용한다.

1. HOP 0.3.1 설치 bundle 계약과 Stage 2 imported declaration의 일치
2. 수정판 등록 전 HWPX Finder/NSWorkspace에서 알한글 누락 재현
3. 수정판 등록 후 exact `net.golbin.hop.*` handler에 `com.postmelee.alhangeul` 추가
4. 같은 HWPX Finder 후보에 알한글 추가
5. 수정판 unregister 후 handler와 개발 registration 원상 복구

signed/sealed extension provider runtime은 #406의 HostApp `다음으로 열기` 수정 성립 여부와 분리해 잔여 위험으로 유지한다.

## 승인 요청

Stage 3.1의 HOP 설치 환경 UTI routing, Finder 후보 A/B 결과, 검증 환경 정리 검토를 요청한다. 승인 후 Stage 4 `통합 검증과 최종 보고`로 진행한다.
