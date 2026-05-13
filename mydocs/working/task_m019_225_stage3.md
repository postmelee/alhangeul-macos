# Task M019 #225 Stage 3 완료보고서

## 단계 목적

About 창에 bundled `rhwp` provenance를 표시하고, 앱 업데이트 후 새 build 최초 실행 시 LaunchServices/extension registration refresh와 최근 HWP/HWPX 문서의 Finder thumbnail 재평가 유도를 수행하도록 launch maintenance를 추가했다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `Sources/HostApp/Support/RhwpProvenance.swift` | 신규 | bundled `rhwp-studio/manifest.json`에서 release tag와 resolved commit을 읽어 `rhwp v0.7.11 (a9dcdee)` 표시값 생성 |
| `Sources/HostApp/Support/BuildInfo.swift` | 수정 | About 표시용 `rhwpDisplayVersion`, maintenance marker용 build identifier 추가 |
| `Sources/HostApp/Views/AboutView.swift` | 수정 | About 정보 영역에 `rhwp` row 추가 |
| `Sources/HostApp/Services/LaunchMaintenanceService.swift` | 신규 | build-scoped launch maintenance marker와 registration/recent thumbnail refresh orchestration 추가 |
| `Sources/HostApp/Services/RecentDocumentThumbnailRefresher.swift` | 신규 | 최근 HWP/HWPX 후보만 대상으로 `NSWorkspace.noteFileSystemChanged` 수행 |
| `Sources/HostApp/HostApp.swift` | 수정 | 기존 매 실행 registration refresh를 build marker 기반 maintenance 호출로 교체 |
| `Alhangeul.xcodeproj/project.pbxproj` | 수정 | `xcodegen generate`로 신규 Swift 파일 build phase 반영 |
| `mydocs/working/task_m019_225_stage3.md` | 신규 | Stage 3 수행과 검증 결과 기록 |

## 구현 내용

### About provenance

`RhwpProvenanceLoader`는 app bundle의 `rhwp-studio/manifest.json`을 읽어 다음 manifest key를 사용한다.

```text
source_release_tag
source_resolved_commit
```

정상 load 시 About 창에는 다음 형태로 표시된다.

```text
rhwp v0.7.11 (a9dcdee)
```

manifest 누락, JSON decode 실패, 빈 tag 또는 7자 미만 commit이면 About 창 자체가 실패하지 않고 `확인 불가`를 표시한다.

### Launch maintenance

`LaunchMaintenanceService.runIfNeeded()`는 `BuildInfo.launchMaintenanceBuildIdentifier` 값인 `version-build`를 marker로 사용한다.

현재 Stage 3 기준 marker 값:

```text
0.1.1-4
```

같은 build에서 이미 maintenance가 완료된 경우 다음 실행부터는 registration/thumbnail refresh를 건너뛴다. 새 build 또는 새 version으로 바뀌면 marker가 달라져 다시 1회 실행된다.

launch maintenance에서 수행하는 작업:

1. `ExtensionSystemRegistrationRefresher.refreshCurrentBundle()` 호출
2. `RecentDocumentStore.load()`와 `NSDocumentController.shared.recentDocumentURLs`에서 recent 후보 수집
3. `.hwp`, `.hwpx` file URL만 대상으로 dedup
4. security-scoped bookmark resolve와 접근 가능 파일 확인
5. 접근 가능한 URL에만 `NSWorkspace.shared.noteFileSystemChanged(url.path)` 호출
6. 실패/skip은 `OSLog`로 남기고 app launch는 계속 진행
7. 실행 시도 후 current build marker 저장

제품 앱 자동 path에는 전역 `qlmanage -r cache`, `pluginkit` 명령 실행, Finder 강제 재시작을 추가하지 않았다.

## 검증 결과

### Source inventory

```text
$ rg -n "LaunchMaintenanceService|RecentDocumentThumbnailRefresher|RhwpProvenance|rhwpDisplayVersion|source_release_tag|source_resolved_commit" Sources/HostApp --glob '!Resources/**'
Sources/HostApp/Services/LaunchMaintenanceService.swift:14:enum LaunchMaintenanceService
Sources/HostApp/Services/RecentDocumentThumbnailRefresher.swift:10:enum RecentDocumentThumbnailRefresher
Sources/HostApp/Support/RhwpProvenance.swift:3:struct RhwpProvenance
Sources/HostApp/Support/BuildInfo.swift:26:static var rhwpDisplayVersion
Sources/HostApp/Views/AboutView.swift:17:AboutInfoRow(title: "rhwp", value: BuildInfo.rhwpDisplayVersion)
```

전역 cache reset/외부 명령 자동 실행 부재 확인:

```text
$ rg -n "qlmanage|pluginkit|killall Finder|Finder 재시작" Sources/HostApp --glob '!Resources/**'
Sources/HostApp/Services/ExtensionStatusModel.swift:214:            // Sandboxed apps cannot reliably run /usr/bin/pluginkit for discovery:
```

위 결과는 기존 주석이며, Stage 3에서 `pluginkit` 실행 path를 추가하지 않았다.

### Project generation

```text
$ xcodegen generate
Created project at /Users/melee/Documents/projects/rhwp-mac/Alhangeul.xcodeproj
```

### HostApp Debug build

샌드박스 기본 실행은 Xcode/SwiftPM이 사용자 cache directory에 module cache와 diagnostics를 쓰지 못해 실패했다.

```text
error opening '/Users/melee/.cache/clang/ModuleCache/Swift-...swiftmodule' for output: Operation not permitted
cannot open file '/Users/melee/Library/Caches/org.swift.swiftpm/.../sparkle.dia' for diagnostics emission: Operation not permitted
```

동일 명령을 승인 경로로 재실행해 compile/link를 확인했다.

```text
$ xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
** BUILD SUCCEEDED ** [7.407 sec]
```

### Resource/provenance 확인

Debug build app bundle에 포함된 manifest가 Stage 2 provenance를 유지하는지 확인했다.

```text
$ plutil -p build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/manifest.json
"source_release_tag" => "v0.7.11"
"source_resolved_commit" => "a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"
```

### 추가 검증

```text
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies

$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio

$ git diff --check
exit 0
```

GUI smoke는 실행하지 않았다. Stage 3 계획에서 `open build.noindex/.../Alhangeul.app`은 별도 승인 대상인 선택 smoke로 분리되어 있고, Debug build와 bundled manifest 검증으로 source-level 동작을 확인했다.

## 본문 변경 정도 / 본문 무손실 여부

Swift HostApp code와 generated Xcode project만 변경했다. 문서 파일, sample 문서, bundled `rhwp-studio` asset 본문은 변경하지 않았다.

## 잔여 위험

- build-scoped marker는 `version-build` 기준이다. Stage 4에서 앱/extension version을 `0.1.2`로 올리면 marker가 바뀌어 첫 실행 maintenance가 다시 수행된다.
- `NSWorkspace.noteFileSystemChanged`는 Finder/Quick Look 재평가를 유도하지만 cache 삭제를 보장하지 않는다. recent 후보 밖 파일이나 macOS 내부 cache 상태는 release smoke에서 별도 확인해야 한다.
- Debug `CODE_SIGNING_ALLOWED=NO` 산출물은 compile/link 검증용이다. Quick Look/Thumbnail 등록 smoke는 signed/sealed Release package 기준으로 Stage 5에서 확인해야 한다.
- 현재 저장소에는 별도 test target이 없어 deterministic helper unit test는 추가하지 않았다. 대신 `isSupportedDocumentURL`과 manifest parsing path를 compile/build 검증으로 확인했다.

## 다음 단계 영향

Stage 4에서는 v0.1.2 release candidate metadata와 사용자 문서를 정리한다.

필수 후속 작업:

- HostApp/QLExtension/ThumbnailExtension version/build를 v0.1.2 후보 기준으로 갱신
- release rehearsal/publish workflow default와 `expected_rhwp_tag=v0.7.11` 정리
- README 최신 공개 릴리즈 요약, release record, Pages release note 초안 정리
- Stage 5 signed/release smoke에서 About row와 update maintenance log, Finder thumbnail refresh 효과 확인

## 승인 요청

Stage 3 완료를 승인하면 Stage 4 `v0.1.2 release metadata와 사용자 문서 정리`를 진행한다.
