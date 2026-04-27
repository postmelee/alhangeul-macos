# Issue #70 Stage 3 완료 보고서

## 타스크

- GitHub Issue: #70
- 마일스톤: M040
- 제목: HostApp 디버그 사이드바를 About 패널로 이전하고 확장 상태 조회를 보정
- 작업 브랜치: `local/task70`
- Stage: 3. 확장 상태 조회와 표시 보정
- 완료 시각: 2026-04-26 17:15 KST

## 목표

확장 번들 포함 여부와 시스템 PlugInKit 등록 조회 결과를 분리해 About 화면에 표시한다. `pluginkit` 조회 실패를 실제 미등록 또는 bundle ID 불일치로 오해하지 않도록 상태 모델과 문구를 보정한다.

## 변경 내용

`Sources/HostApp/Services/ExtensionStatusModel.swift`:

- `ExtensionStatus`에 각 확장의 `.appex` bundle 이름을 추가했다.
- `ExtensionStatusSnapshot`을 추가해 `앱 번들` 상태와 `시스템 등록` 상태를 함께 전달하도록 변경했다.
- `ExtensionBundleState`를 추가해 현재 앱 bundle 내부 `Contents/PlugIns/*.appex` 존재 여부를 `앱에 포함됨`/`앱에 포함되지 않음`으로 구분한다.
- `ExtensionRegistrationState`를 `시스템 등록됨`, `시스템 등록 비활성화됨`, `시스템 등록 없음`, `시스템 등록 확인 불가`로 세분화했다.
- `pluginkit -m -i <bundle id> -v` 결과를 사용해 대상 ID만 조회하고, termination status가 0이 아니면 `시스템 등록 확인 불가`로 처리하도록 변경했다.

`Sources/HostApp/Views/AboutView.swift`:

- About 화면에서 `ExtensionStatusModel`을 소유하도록 `@StateObject`를 추가했다.
- 확장 섹션에 `상태 새로고침` 버튼을 추가했다.
- 각 확장 행에 `앱 번들`과 `시스템 등록` 상태를 별도 줄로 표시한다.

`Sources/HostApp/Services/AboutWindowPresenter.swift`:

- 확장 상태 2줄 표시와 새로고침 버튼을 수용하도록 About 창 기본 크기를 `540 x 430`으로 조정했다.

## 확인 결과

- Debug build 산출물에는 두 확장 bundle이 모두 포함됐다.
  - `AlhangeulMacPreview.appex`
  - `AlhangeulMacThumbnail.appex`
- 샌드박스 내부 `pluginkit` 조회는 `match: Connection invalid`로 실패했다.
- 샌드박스 밖 `pluginkit -m -i ... -v` 조회에서는 두 ID가 모두 등록됨으로 확인됐다.
  - `com.postmelee.alhangeulmac.QLExtension`
  - `com.postmelee.alhangeulmac.ThumbnailExtension`
- 따라서 현재 문제는 bundle ID 불일치가 아니라 실행 환경의 PlugInKit 조회 제한 또는 연결 실패로 판단한다.

## 검증

### diff check

```bash
git diff --check
```

결과:

- 통과

### AppKit 경계 검사

```bash
./scripts/check-no-appkit.sh
```

결과:

- `OK: shared Swift code has no AppKit/UIKit dependencies`

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

- `BUILD SUCCEEDED`
- CoreSimulator 관련 warning이 출력됐지만 macOS HostApp compile/link는 성공했다.

### 확장 bundle 포함 확인

```bash
find build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app/Contents/PlugIns \
  -maxdepth 1 \
  -name '*.appex' \
  -print
```

결과:

- `AlhangeulMacThumbnail.appex`
- `AlhangeulMacPreview.appex`

### PlugInKit 등록 ID 확인

```bash
/usr/bin/pluginkit -m -i com.postmelee.alhangeulmac.QLExtension -v
/usr/bin/pluginkit -m -i com.postmelee.alhangeulmac.ThumbnailExtension -v
```

결과:

- 샌드박스 내부 조회: `match: Connection invalid`
- 샌드박스 밖 조회: 두 확장 모두 `+` 등록 상태로 확인

## 미진행 항목

- 앱을 실제 실행해 viewer 화면과 About 창의 최종 시각 상태를 확인하는 작업은 Stage 4 통합 검증으로 남겼다.
- PlugInKit 조회가 앱 실행 환경에서 계속 제한될 경우 About 화면에는 `시스템 등록 확인 불가`가 표시된다. 이는 실제 미등록 상태와 구분하기 위한 의도된 문구다.

## 다음 단계

Stage 4에서 통합 검증을 수행하고 최종 보고서를 작성한다.

## 승인 요청

Stage 3 완료를 보고하며, Stage 4 진행 승인을 요청한다.
