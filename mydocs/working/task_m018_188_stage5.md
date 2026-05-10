# Task M018 #188 Stage 5 완료 보고서

## 단계 목적

기존 public `v0.1.0` 설치본의 Sparkle 업데이트 확인, public `v0.1.1` DMG 재설치 후 앱/Quick Look/Thumbnail smoke를 확인하고, 설치 후 Finder 통합 상태 이상을 진단한다.

확인 시각: `2026-05-11 02:08 KST`

## 수행 결과

| 항목 | 결과 | 비고 |
|------|------|------|
| `v0.1.0` Sparkle 업데이트 확인 | OK | 작업지시자가 직접 진행했고 `v0.1.1` 업데이트 진행까지 완료 확인 |
| `v0.1.1` public DMG 재설치 | OK | 작업지시자가 직접 진행, About window 기준 `0.1.1 (2)` 확인 |
| 설치본 app bundle | OK | `/Applications/Alhangeul.app` 존재, `0.1.1` / build `2` |
| Quick Look/Thumbnail appex 포함 | OK | `Contents/PlugIns/AlhangeulPreview.appex`, `AlhangeulThumbnail.appex` 존재 |
| Developer ID signing | OK | app, Sparkle nested components, Quick Look/Thumbnail extension deep verify 통과 |
| PlugInKit 등록 | OK | 두 extension 모두 `+` 상태, 경로 `/Applications/Alhangeul.app/...` |
| HWP/HWPX thumbnail smoke | OK | `qlmanage -t -x -s 512`로 HWP/HWPX PNG 생성 |
| About window 시스템 등록 표시 | 확인 필요 | 터미널 `pluginkit` 기준 등록은 OK지만 앱 UI에는 `시스템 등록 확인 불가`로 보일 수 있음 |
| Finder 기존 파일 thumbnail/preview | 환경 캐시 영향 | 기존 파일이 legacy `com.postmelee.rhwpmac.*` UTI로 남으면 Finder 매칭이 늦거나 누락될 수 있음 |

## 확인한 설치본 상태

`/Applications/Alhangeul.app/Contents/Info.plist` 기준:

| 항목 | 값 |
|------|----|
| `CFBundleIdentifier` | `com.postmelee.alhangeul` |
| `CFBundleShortVersionString` | `0.1.1` |
| `CFBundleVersion` | `2` |
| `SUFeedURL` | `https://postmelee.github.io/alhangeul-macos/appcast.xml` |

Extension Info.plist 기준:

| Extension | Bundle ID | Extension point | 지원 content type |
|-----------|-----------|-----------------|-------------------|
| Quick Look preview | `com.postmelee.alhangeul.QLExtension` | `com.apple.quicklook.preview` | `com.postmelee.alhangeul.*`, `com.hancom.*`, `com.haansoft.*` |
| Thumbnail | `com.postmelee.alhangeul.ThumbnailExtension` | `com.apple.quicklook.thumbnail` | `com.postmelee.alhangeul.*`, `com.hancom.*`, `com.haansoft.*` |

## 진단 내용

작업지시자 첨부 스크린샷에서는 About window의 확장 상태가 `앱에 포함됨`이지만 `시스템 등록 확인 불가`로 보였다. 실제 시스템 조회는 다음과 달랐다.

| 조회 | 결과 |
|------|------|
| `pluginkit -m -i com.postmelee.alhangeul.QLExtension -v` | `+`, `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex` |
| `pluginkit -m -i com.postmelee.alhangeul.ThumbnailExtension -v` | `+`, `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex` |
| `codesign --verify --deep --strict --verbose=4 /Applications/Alhangeul.app` | valid on disk, satisfies Designated Requirement |
| `codesign -d --entitlements :- ...AlhangeulPreview.appex` | sandbox + user-selected read-only, `get-task-allow` 없음 |
| `codesign -d --entitlements :- ...AlhangeulThumbnail.appex` | sandbox + user-selected read-only, `get-task-allow` 없음 |

따라서 설치본에 extension이 빠졌거나 서명이 깨진 상태는 아니다. 다만 현재 사용자 환경에는 과거 개발 빌드가 남긴 LaunchServices UTI 기록이 있었다.

| 파일 | 재색인 전 content type | 재색인 후 content type |
|------|-----------------------|------------------------|
| `samples/basic/KTX.hwp` | `com.postmelee.rhwpmac.hwp` | `com.postmelee.alhangeul.hwp` |
| `samples/hwpx/hwpx-01.hwpx` | `com.postmelee.rhwpmac.hwpx` | `com.postmelee.alhangeul.hwpx` |

`lsregister -dump`에서 `/Users/melee/Documents/projects/rhwp-mac/build/release/알한글.app`의 `com.postmelee.rhwpmac` 등록 기록이 파일은 없는 상태로 남아 있었고, `com.postmelee.rhwpmac.hwp/hwpx` UTI가 active로 남아 있었다. 이 때문에 기존 파일의 Spotlight metadata가 새 `com.postmelee.alhangeul.*` UTI로 갱신되기 전까지 Finder 표시가 혼동될 수 있다.

`lsregister -gc`, `/Applications/Alhangeul.app` 강제 재등록, `pluginkit -a`, `pluginkit -e use`, `qlmanage -r`, `qlmanage -r cache`를 실행했지만 기존 파일의 content type은 즉시 바뀌지 않았다. 해당 파일에 `mdimport`를 실행한 뒤 새 UTI로 갱신됐다.

## Smoke 결과

| 명령/확인 | 결과 | 비고 |
|-----------|------|------|
| `mdls ... samples/basic/KTX.hwp` | OK | `mdimport` 후 `com.postmelee.alhangeul.hwp` |
| `mdls ... samples/hwpx/hwpx-01.hwpx` | OK | `mdimport` 후 `com.postmelee.alhangeul.hwpx` |
| `qlmanage -t -x -s 512 -o /tmp/alhangeul-stage5-hwp samples/basic/KTX.hwp` | OK | `KTX.hwp.png`, `512 x 363` |
| `qlmanage -t -x -s 512 -o /tmp/alhangeul-stage5-hwpx samples/hwpx/hwpx-01.hwpx` | OK | `hwpx-01.hwpx.png`, `363 x 512` |
| `qlmanage -t -x -s 512 -o /tmp/alhangeul-stage5-hwp /tmp/alhangeul-stage5-new.hwp` | OK | 새 복사본은 즉시 새 UTI로 분류 |
| `qlmanage -t -x -s 512 -o /tmp/alhangeul-stage5-hwpx /tmp/alhangeul-stage5-new.hwpx` | OK | 새 복사본은 즉시 새 UTI로 분류 |

## 판단

이번 Stage 5에서 발견한 문제는 `v0.1.1` public app bundle의 누락, signing/notarization 실패, PlugInKit 미등록이 아니다. 실제 원인은 로컬 개발 환경에 남아 있던 legacy `com.postmelee.rhwpmac.*` UTI metadata와 기존 파일 Spotlight cache다.

clean user 환경이나 새로 생성/복사된 파일은 `com.postmelee.alhangeul.hwp/hwpx`로 분류되고 thumbnail smoke가 통과한다. 기존 개발/테스트 파일은 `mdimport <file>` 또는 상위 폴더 재색인 후 Finder/Quick Look이 정상 경로를 탈 수 있다.

About window의 `시스템 등록 확인 불가` 표시는 실제 등록 상태와 다를 수 있으므로 후속 보강이 필요하다. sandboxed 앱 내부에서 `pluginkit` 실행 결과를 사용자에게 직접 신뢰 지표로 보여주는 현재 방식은 배포 앱의 진단 UI로 충분히 견고하지 않다.

## 후속 필요

- About window의 extension 상태 표시를 실제 배포 앱에서 신뢰 가능한 방식으로 재설계하거나, `pluginkit` 호출 실패를 “확인 불가”가 아닌 안내성 메시지로 낮춘다.
- Finder 통합 troubleshooting에 legacy UTI cache와 `mdimport` 재색인 절차를 추가한다.
- 필요하면 `com.postmelee.rhwpmac.hwp/hwpx` legacy UTI를 v0.1.2 extension 지원 content type에 포함할지 검토한다.

## 실행하지 않은 항목

- Intel Mac 실기기 smoke는 이번 로컬 환경에서 실행하지 않았다.
- `qlmanage -p` GUI preview 자동 판정은 실행하지 않았다. `qlmanage -t` thumbnail 생성과 PlugInKit 등록으로 자동 smoke를 제한했다.
- LaunchServices DB `-delete`는 실행하지 않았다. 현재 macOS의 `lsregister -delete`는 reboot가 필요하고 사용자 환경 영향이 커서 Stage 5 조치 범위에서 제외했다.
