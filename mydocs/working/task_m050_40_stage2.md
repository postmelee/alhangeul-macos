# Issue #40 Stage 2 완료 보고서

## 타스크

- GitHub Issue: #40
- 마일스톤: M050
- 제목: Dock/Spotlight 표시명 한영 현지화
- 작업 브랜치: `local/task40`
- Stage: 2. XcodeGen 리소스 포함 및 프로젝트 재생성

## 목표

Stage 1에서 추가한 target별 `ko.lproj`/`en.lproj` `InfoPlist.strings`가 Xcode project에 localized resource로 포함되도록 `AlhangeulMac.xcodeproj`를 재생성하고 포함 상태를 확인한다.

## 변경 내용

- `xcodegen generate`를 실행해 `AlhangeulMac.xcodeproj`를 재생성했다.
- `project.yml` 수정은 필요하지 않았다.
  - HostApp은 `Sources/HostApp` 전체를 sources로 포함한다.
  - QLExtension은 `Sources/QLExtension` 전체를 sources로 포함한다.
  - ThumbnailExtension은 `Sources/ThumbnailExtension` 전체를 sources로 포함한다.
  - XcodeGen이 각 target 하위의 `Resources/*/*.lproj/InfoPlist.strings`를 localized resource variant group으로 감지했다.

## 확인 결과

`AlhangeulMac.xcodeproj/project.pbxproj`에 다음 항목이 추가됐다.

- `PBXVariantGroup` 3개
  - HostApp `InfoPlist.strings`
  - QLExtension `InfoPlist.strings`
  - ThumbnailExtension `InfoPlist.strings`
- Copy Bundle Resources 항목 3개
  - HostApp `InfoPlist.strings in Resources`
  - QLExtension `InfoPlist.strings in Resources`
  - ThumbnailExtension `InfoPlist.strings in Resources`
- project `knownRegions`에 `ko` 추가

## 검증

### XcodeGen

```bash
xcodegen generate
```

결과:

- 성공
- `AlhangeulMac.xcodeproj` 재생성 완료

### pbxproj lint

```bash
plutil -lint AlhangeulMac.xcodeproj/project.pbxproj
```

결과:

- `AlhangeulMac.xcodeproj/project.pbxproj: OK`

### resource 포함 확인

```bash
rg -n "InfoPlist\\.strings in Resources|PBXVariantGroup|knownRegions|ko," \
  AlhangeulMac.xcodeproj/project.pbxproj
```

결과:

- target별 `InfoPlist.strings in Resources` 3개 확인
- `PBXVariantGroup` 3개 확인
- `knownRegions`에 `ko` 포함 확인

### project 목록 확인

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp \
  -derivedDataPath build/DerivedDataList \
  -list
```

결과:

- 종료 코드 0
- targets: `HostApp`, `QLExtension`, `ThumbnailExtension`
- schemes: `HostApp`, `QLExtension`, `ThumbnailExtension`
- CoreSimulatorService와 provisioning profile 관련 경고가 출력됐으나 macOS project 목록 확인 자체는 성공했다.

## 미진행 항목

- Debug build와 실제 bundle 내부 리소스 포함 확인은 Stage 3 범위로 남겼다.
- `/Users/melee/Applications/AlhangeulMac.app` 설치본 갱신과 PlugInKit 등록 확인도 Stage 3 범위로 남겼다.

## 다음 단계

Stage 3에서 Debug build를 실행하고, build 산출물 및 설치본에서 localized `InfoPlist.strings` 포함 여부와 PlugInKit 등록 상태를 확인한다.

## 승인 요청

Stage 2 완료를 보고하며, Stage 3 진행 승인을 요청한다.
