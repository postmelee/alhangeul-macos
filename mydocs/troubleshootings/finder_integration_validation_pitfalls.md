# Finder 통합 검증 시행착오 방지 가이드

## 목적

Finder Quick Look/Thumbnail extension 등록과 검증 과정에서 반복적으로 발생하는 시행착오 패턴을 정리한다. `build_run_guide.md`의 표준 smoke test 절차에서 해결되지 않는 진단/판정 기준을 다룬다.

## 적용 시점

- `pluginkit -mAvvv | grep com.postmelee.alhangeul` 결과가 기대와 다를 때
- Finder Quick Look preview 또는 thumbnail이 표시되지 않을 때
- Spotlight/Dock/Finder 표시명이 의도와 다를 때
- 이전 이름(`RhwpMac.app`, `AlhangeulMac.app`, `알한글.app`) 설치본이 남아 충돌이 의심될 때

## 1. `qlmanage -m plugins`의 표시 한계

`qlmanage -m plugins`는 app extension 기반 Quick Look/Thumbnail 등록 상태를 직접 반영하지 않을 수 있다. 미노출이 곧 extension 실행 실패라는 직접 증거가 아니므로 실패 판정의 근거로 쓰지 않는다.

판정 기준:

- 등록 여부: `pluginkit -mAvvv | grep com.postmelee.alhangeul`
- 실제 렌더링: `qlmanage -t -x -s 512 -o /tmp/alhangeul-ql samples/basic/KTX.hwp`

두 명령이 모두 정상이면 `qlmanage -m plugins` 미노출은 무시해도 된다.

## 2. `pluginkit -mAvvv` 미노출 시 진단 순서

extension이 `pluginkit -mAvvv`에 나타나지 않으면 바로 삭제/재설치를 반복하지 않는다. 다음 순서로 산출물 상태를 먼저 확인한다.

1. `codesign -dv ~/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex` — 서명 유효성
2. `plutil -p ~/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/Info.plist` — `NSExtension` 키, supported types
3. `plutil -p ~/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/Info.plist` — `NSExtension` 키, supported types
4. `find ~/Applications/Alhangeul.app -name "InfoPlist.strings"` — 현지화 strings 포함 여부
5. `lsregister -dump | grep com.postmelee.alhangeul` — LaunchServices 등록 상태

이후에 `lsregister -u → rm -rf → ditto → lsregister -f -R -trusted` 순서로 재설치한다. (전체 명령 시퀀스는 [`build_run_guide.md`](../manual/build_run_guide.md)의 "표준 smoke test 흐름" 참조)

## 3. 이전 이름 설치본 처리

이전 이름의 설치본(`RhwpMac.app`, `AlhangeulMac.app`, `알한글.app`)은 LaunchServices/PlugInKit discovery 충돌의 원인이 될 수 있다. 이 상태에서 `qlmanage -t -x`가 성공해도 예전 provider가 만든 thumbnail일 수 있으므로 표준 helper는 레거시 후보 발견 시 기본 실패한다.

확인 방법:

```bash
lsregister -dump | grep -E "(RhwpMac|AlhangeulMac|알한글)\.app"
mdfind "kMDItemContentType == 'com.apple.application-bundle'" | grep -E "(RhwpMac|AlhangeulMac|알한글)\.app"
```

위 명령에서 결과가 보이면 작업지시자에게 보고하고, 승인 후에만 `rm -rf`로 제거하고 LaunchServices 갱신(`lsregister -u <경로>`)을 수행한다.

파일 삭제 없이 smoke gate만 격리하려면 작업지시자 승인 후 표준 helper에 `--unregister-legacy-candidates`를 붙인다. 이 옵션은 후보 app/appex를 LaunchServices/PlugInKit에서 unregister하지만 실제 파일은 삭제하지 않는다. 실제 파일 제거(`rm -rf`)는 별도 승인 후에만 수행한다.

## 4. 현재 이름 개발 산출물 등록 처리

Xcode는 Debug/Release build 중 `RegisterWithLaunchServices` 단계에서 `build.noindex/` 또는 `~/Library/Developer/Xcode/DerivedData/` 아래의 `Alhangeul.app`을 등록할 수 있다. 이 등록은 파일을 삭제하지 않아도 System Settings의 extension 목록을 늘리거나 Finder content type routing을 흐릴 수 있다.

판정 기준:

- `pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension`의 `Path`가 smoke 설치본 내부인지 확인한다.
- `lsregister -dump | grep -E "Alhangeul\.app|com\.postmelee\.alhangeul"`에서 `build.noindex/` 또는 Xcode DerivedData 경로가 보이면 개발 산출물 등록이 남은 상태로 본다.
- `mdls -name kMDItemContentType -name kMDItemContentTypeTree <fresh-sample>`로 Finder가 어떤 UTI로 파일을 분류하는지 확인한다.

표준 smoke helper는 `build.noindex/`와 Xcode DerivedData 아래의 개발 산출물 등록을 파일 삭제 없이 해제한 뒤 `$HOME/Applications/Alhangeul.app` 또는 `/Applications/Alhangeul.app` 중 하나만 등록한다. 수동 등록을 했다면 같은 검증 안에서 `pluginkit -r`, `lsregister -u`, `qlmanage -r cache`까지 수행한다.

## 5. 표시명 문제와 extension 실패 혼동 방지

Spotlight/Dock/Finder 표시명은 현재 사용자 언어와 LaunchServices/Spotlight 캐시의 영향을 받는다. 표시명이 `Alhangeul`로 보이고 `알한글`로 보이지 않더라도 extension 실행은 정상일 수 있고, 그 반대도 가능하다.

표시명 문제 진단 순서:

1. 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`이 실제 bundle filesystem name(`Alhangeul`)과 일치하는지 — 불일치 시 localized 표시명이 선택되지 않을 수 있음
2. `ko.lproj/InfoPlist.strings`와 `en.lproj/InfoPlist.strings`가 release bundle 안에 포함됐는지 (`find ... InfoPlist.strings`)
3. 각 app/extension bundle `Info.plist`에 `LSHasLocalizedDisplayName = true`가 명시됐는지
4. Spotlight 캐시 갱신: `mdimport -r ~/Applications/Alhangeul.app`

표시명 문제를 해결하려고 `.app` 또는 `.appex` 디렉터리 자체를 한글로 rename하지 않는다. ExtensionKit lookup 안정성이 깨진다.

## 관련 문서

- [`build_run_guide.md`](../manual/build_run_guide.md) — 표준 smoke test 절차와 핵심 시행착오 방지 규칙
- [`release_distribution_guide.md`](../manual/release_distribution_guide.md) — release 시 Finder 통합 smoke test 추가 기준
- [`task_m050_40_quicklook_thumbnail_registration_validation.md`](task_m050_40_quicklook_thumbnail_registration_validation.md) — `AlhangeulMac` 기준이던 과거 Quick Look/Thumbnail 등록 검증 작업 기록
