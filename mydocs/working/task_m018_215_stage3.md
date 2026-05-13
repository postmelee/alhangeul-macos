# Task M018 #215 Stage 3 완료 보고서

## 단계 목적

HostApp bundle metadata와 app bundle resource 안에서 사람이 읽을 수 있는 copyright/license notice를 확인할 수 있게 한다.

## 변경 파일

- `Sources/HostApp/Info.plist`
- `Sources/HostApp/Resources/Legal/LICENSE`
- `Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md`
- `Sources/HostApp/Resources/Legal/FONTS.md`
- `project.yml`
- `Alhangeul.xcodeproj/project.pbxproj`
- `mydocs/working/task_m018_215_stage3.md`

## 변경 내용

### HostApp metadata

`Sources/HostApp/Info.plist`에 다음 metadata를 추가했다.

```xml
<key>NSHumanReadableCopyright</key>
<string>Copyright © 2025-2026 Taegyu Lee</string>
```

### Legal resource

Stage 1에서 확정한 위치에 legal notice 파일 3개를 추가했다.

```text
Sources/HostApp/Resources/Legal/LICENSE
Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md
Sources/HostApp/Resources/Legal/FONTS.md
```

각 파일은 다음 canonical source의 사본이다.

| Bundle legal resource | Canonical source |
|-----------------------|------------------|
| `Legal/LICENSE` | `LICENSE` |
| `Legal/THIRD_PARTY_LICENSES.md` | `THIRD_PARTY_LICENSES.md` |
| `Legal/FONTS.md` | `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` |

### XcodeGen resource 설정

초기 `xcodegen generate` 확인 결과, `Sources/HostApp` 일반 source 포함만으로는 확장자 없는 `LICENSE`가 Copy Bundle Resources phase에 들어가지 않았다. 또한 파일별 resource는 bundle 안의 `Legal/` 폴더 구조 보존이 불명확하다.

따라서 `project.yml`에서 `Resources/Legal`을 일반 HostApp source scan에서는 제외하고, 별도 folder resource로 추가했다.

```yaml
- path: Sources/HostApp
  excludes:
    - Resources/rhwp-studio
    - Resources/Legal
- path: Sources/HostApp/Resources/Legal
  type: folder
```

`Alhangeul.xcodeproj/project.pbxproj`는 `xcodegen generate`로 재생성했다. 직접 수동 수정하지 않았다.

## 검증 결과

### Plist와 canonical copy

- `plutil -lint Sources/HostApp/Info.plist`: 통과
- `cmp -s LICENSE Sources/HostApp/Resources/Legal/LICENSE`: 통과
- `cmp -s THIRD_PARTY_LICENSES.md Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md`: 통과
- `cmp -s Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md Sources/HostApp/Resources/Legal/FONTS.md`: 통과

### XcodeGen

- `xcodegen dump --type parsed-yaml`: 통과
- `xcodegen generate`: 통과
- generated project 확인:
  - `project.pbxproj`에 `Legal in Resources` 추가
  - `project.pbxproj`의 `Legal` file reference는 `lastKnownFileType = folder`

### Debug build

첫 `xcodebuild`는 sandbox 환경에서 Sparkle package fetch가 DNS 제한으로 실패했다.

```text
fatal: unable to access 'https://github.com/sparkle-project/Sparkle/': Could not resolve host: github.com
```

같은 명령을 네트워크 허용 상태로 재실행해 성공했다.

```text
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [12.550 sec]
```

### Built app bundle

빌드 산출물에서 metadata와 resource를 확인했다.

```text
build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Info.plist
NSHumanReadableCopyright = "Copyright © 2025-2026 Taegyu Lee"
```

```text
build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/LICENSE
build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/FONTS.md
build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/THIRD_PARTY_LICENSES.md
```

다음 파일 존재 검증도 통과했다.

- `test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/LICENSE`
- `test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/THIRD_PARTY_LICENSES.md`
- `test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/Legal/FONTS.md`

빌드 산출물의 `Legal` 파일과 source `Legal` 파일의 `cmp -s` 비교도 통과했다.

### Diff check

- `git diff --check`: 통과

## 잔여 위험

- Stage 3는 Debug build 기준 검증이다. signed/notarized public DMG 내부 검증은 release 실행 범위에서 다시 확인해야 한다.
- Legal resource는 canonical 문서의 사본이므로, 이후 canonical 문서를 바꾸면 Stage 4 또는 release gate에서 copy drift를 반드시 확인해야 한다.

## 다음 단계

Stage 3 결과를 승인하면 Stage 4에서 통합 keyword scan, canonical copy drift 확인, 최종 보고서, 오늘할일 완료 갱신을 진행한다.
