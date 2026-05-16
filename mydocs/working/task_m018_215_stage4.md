# Task M018 #215 Stage 4 완료 보고서

## 단계 목적

Stage 1-3에서 정리한 license/provenance 문서, HostApp metadata, app bundle Legal resource를 통합 검증하고 최종 보고서와 오늘할일을 정리한다.

## 변경 파일

- `mydocs/orders/20260510.md`
- `mydocs/working/task_m018_215_stage4.md`
- `mydocs/report/task_m018_215_report.md`

## 통합 검증 결과

### 현재 project shape

- Xcode project: `Alhangeul.xcodeproj`
- Schemes: `HostApp`, `QLExtension`, `ThumbnailExtension`
- Stage 4 build 대상: `HostApp`

`xcodebuild -list -project Alhangeul.xcodeproj`는 sandbox 내부에서 SwiftPM/Xcode cache 쓰기 제한으로 처음 실패했다.

```text
error opening '/Users/melee/.cache/clang/ModuleCache/Swift-BF86GRDXI25I.swiftmodule' for output: Operation not permitted
```

같은 명령을 권한 허용 상태로 재실행해 scheme 목록을 확인했다.

### 문서와 resource drift 확인

다음 canonical source와 Legal resource 사본 비교가 모두 통과했다.

- `cmp -s LICENSE Sources/HostApp/Resources/Legal/LICENSE`
- `cmp -s THIRD_PARTY_LICENSES.md Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md`
- `cmp -s Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md Sources/HostApp/Resources/Legal/FONTS.md`

빌드 산출물의 `Contents/Resources/Legal` 파일과 source `Legal` 파일 비교도 모두 통과했다.

- `cmp -s Sources/HostApp/Resources/Legal/LICENSE build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/LICENSE`
- `cmp -s Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/THIRD_PARTY_LICENSES.md`
- `cmp -s Sources/HostApp/Resources/Legal/FONTS.md build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/FONTS.md`

### Static checks

- `plutil -lint Sources/HostApp/Info.plist`: 통과
- `xcodegen dump --type parsed-yaml`: 통과
- `xcodegen generate`: 통과, 재생성 후 작업트리 변경 없음
- keyword scan:
  - `Taegyu Lee`
  - `Edward Kim`
  - `Sparkle`
  - `THIRD_PARTY_LICENSES`
  - `NSHumanReadableCopyright`
  - `Legal`
  - `아이콘`
  - `로고`
  - `Figma`
  - `AppIcon`
  - `logo-256`
- `git diff --check`: 통과

### Debug build

다음 명령을 권한 허용 상태로 실행해 성공했다.

```text
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [1.567 sec]
```

### Built app bundle 확인

빌드 산출물 `Info.plist`에서 다음 metadata를 확인했다.

```text
NSHumanReadableCopyright = "Copyright © 2025-2026 Taegyu Lee"
```

빌드 산출물에 다음 legal notice 파일이 포함됨을 확인했다.

```text
build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/LICENSE
build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/FONTS.md
build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/THIRD_PARTY_LICENSES.md
```

## 오늘할일 갱신

`mydocs/orders/20260510.md`의 #215 상태를 `완료`로 갱신했다.

## 잔여 위험

- Stage 4는 Debug build 기준 검증이다. public DMG, signing, notarization, Homebrew Cask, Sparkle stable appcast 게시 검증은 release 실행 범위에서 다시 확인해야 한다.
- Legal resource는 canonical 문서 사본이므로, 향후 `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md`가 바뀌면 release gate에서 copy drift를 다시 확인해야 한다.

## 다음 단계

최종 보고서 작성 후 Stage 4 묶음 커밋을 생성한다.
