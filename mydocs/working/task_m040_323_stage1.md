# Task M040 #323 Stage 1 완료보고서

## 단계 목적

HostApp 실행 시 `UpdateController` 초기화 중 Sparkle 백그라운드 업데이트 확인을 1회 요청한다. 사용자가 자동 업데이트 확인을 꺼 둔 경우에는 강제 확인하지 않고, 기존 수동 메뉴의 `checkForUpdates(nil)` 경로는 유지한다.

## 산출물

| 파일 | 요약 |
|------|------|
| `Sources/HostApp/Services/UpdateController.swift` | `SPUStandardUpdaterController` 생성 직후 `requestLaunchUpdateCheckIfAllowed()` 호출 추가. `automaticallyChecksForUpdates`가 켜진 경우에만 `checkForUpdatesInBackground()` 실행 |
| `mydocs/working/task_m040_323_stage1.md` | Stage 1 변경과 검증 결과 기록 |
| `mydocs/orders/20260601.md` | #323 비고를 Stage 1 완료 후 승인 대기로 갱신 |

라인 수:

```text
50 Sources/HostApp/Services/UpdateController.swift
7 mydocs/orders/20260601.md
```

## 본문 변경 정도 / 본문 무손실 여부

사용자 문서 본문 변경은 없다. 코드 변경은 `UpdateController`에 9줄을 추가한 범위이며, 기존 수동 업데이트 확인 버튼과 `checkForUpdates(nil)` 호출은 유지했다.

## 검증 결과

```bash
git diff --check
```

결과: 통과.

```bash
plutil -lint Sources/HostApp/Info.plist
```

결과:

```text
Sources/HostApp/Info.plist: OK
```

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

첫 실행은 sandbox 내부에서 Swift/Xcode 캐시 접근이 막혀 실패했다.

```text
error opening '/Users/melee/.cache/clang/ModuleCache/Swift-5SCGS38H536W.swiftmodule' for output: /Users/melee/.cache/clang/ModuleCache: Operation not permitted
cannot open file '/Users/melee/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading/sparkle.dia' for diagnostics emission (Operation not permitted)
```

같은 명령을 Xcode/SwiftPM 캐시 접근 허용 상태로 재실행했다.

결과:

```text
** BUILD SUCCEEDED ** [7.190 sec]
```

Sparkle API 확인:

```bash
rg -n "checkForUpdatesInBackground|automaticallyChecksForUpdates|checkForUpdates\(" Sources/HostApp/Services/UpdateController.swift
```

결과:

```text
28:    func checkForUpdates() {
29:        updaterController.checkForUpdates(nil)
33:        guard updaterController.updater.automaticallyChecksForUpdates else {
37:        updaterController.updater.checkForUpdatesInBackground()
46:            updateController.checkForUpdates()
```

## 잔여 위험

- 실제 새 버전 안내 UI 표시는 public appcast, 설치본 버전, Sparkle 사용자 defaults, foreground 세션 상태의 영향을 받으므로 이번 Stage 1에서는 빌드 검증까지만 완료했다.
- 최신 상태에서 불필요한 "최신 버전입니다" 모달이 뜨지 않는지는 설치본 또는 foreground 실행 smoke에서 별도로 확인해야 한다.
- 자동 확인을 끈 사용자 설정에서 guard가 동작하는지는 Sparkle settings/defaults를 조정한 수동 smoke 후보로 남는다.

## 다음 단계 영향

Stage 2에서는 실행 시 background check 정책과 수동 메뉴 확인의 차이를 `release_github_pages_sparkle_guide.md`에 문서화한다. Stage 1 코드가 `checkForUpdatesInBackground()`와 `automaticallyChecksForUpdates`를 사용하므로 문서도 같은 용어로 맞춘다.

## 승인 요청

Stage 1 결과 검토 후 Stage 2 진행 승인을 요청한다.
