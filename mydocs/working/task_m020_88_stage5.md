# Task M020 #88 Stage 5 완료보고서

## 단계 개요

- 단계: Stage 5. Quick Look/Thumbnail runtime smoke와 성능 관측
- 수행 범위: Release package 기준 Finder integration smoke, installed app bundle 설정 확인, Thumbnail smoke, Quick Look manual preview 로그 확인, extension registration hygiene 확인
- 결론: Release package smoke와 Thumbnail smoke는 통과했다. 설치된 release bundle은 현재 data-based PDF preview 설정을 가진다. 다만 local LaunchServices database에 build 산출물 stale registration이 남아 hygiene check는 최종 실패했고, manual `qlmanage -p` 로그도 `/Applications/Alhangeul.app` 경로를 실행한 것으로 기록되어 이번 환경에서는 새 `/Users/melee/Applications/Alhangeul.app` bundle의 preview 성능을 직접 측정하지 못했다.

## Release package smoke

실행한 명령:

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  scripts/smoke-finder-integration.sh \
  --version 0.2.0 \
  --output-dir /private/tmp/rhwp-task88-finder-smoke
```

결과:

```text
OK: Finder integration smoke passed
Installed app: /Users/melee/Applications/Alhangeul.app
Output: /private/tmp/rhwp-task88-finder-smoke/task151-20260520-234427
Diagnostics: /private/tmp/rhwp-task88-finder-smoke/task151-20260520-234427/diagnostics
```

확인된 산출물:

- HWP thumbnail: `/private/tmp/rhwp-task88-finder-smoke/task151-20260520-234427/hwp/KTX.hwp.png`
- HWPX thumbnail: `/private/tmp/rhwp-task88-finder-smoke/task151-20260520-234427/hwpx/hwpx-01.hwpx.png`
- preview plist diagnostics: `/private/tmp/rhwp-task88-finder-smoke/task151-20260520-234427/diagnostics/preview-info.plist.txt`
- pluginkit diagnostics: `/private/tmp/rhwp-task88-finder-smoke/task151-20260520-234427/diagnostics/pluginkit.txt`

`preview-info.plist.txt` 기준 installed release preview extension은 다음 상태다.

- `NSExtensionPrincipalClass = AlhangeulPreview.HwpPreviewProvider`
- `QLIsDataBasedPreview = true`
- HWP/HWPX supported content types 유지

따라서 Stage 4 결정대로 현재 Quick Look PDF UI를 제공하는 data-based PDF reply 경로가 유지된다.

## Provider registration 확인

실행한 명령:

```bash
pluginkit -m -A -v -i com.postmelee.alhangeul.QLExtension
pluginkit -m -A -v -i com.postmelee.alhangeul.ThumbnailExtension
```

결과:

```text
com.postmelee.alhangeul.QLExtension(0.1.3)
  /Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex

com.postmelee.alhangeul.ThumbnailExtension(0.1.3)
  /Users/melee/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

PlugInKit 관점의 active provider root는 `/Users/melee/Applications/Alhangeul.app` 하나로 확인됐다.

## Manual Quick Look preview 확인

실행한 명령:

```bash
qlmanage -r
perl -e 'alarm 8; exec @ARGV' qlmanage -p samples/hwp-multi-001.hwp
/usr/bin/log show --style compact --last 1m \
  --predicate 'process CONTAINS "AlhangeulPreview" OR subsystem == "com.postmelee.alhangeul.QLExtension"'
```

관측 결과:

- `qlmanage -p`는 crash 없이 preview session을 열었다.
- unified log의 extension launch path는 `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`로 기록됐다.
- 이 환경에는 `/Applications/Alhangeul.app`와 `/Users/melee/Applications/Alhangeul.app`가 동시에 존재한다. PlugInKit은 `/Users/melee/Applications` provider를 active로 보고하지만, manual `qlmanage -p` log는 `/Applications` 경로를 기록한다.

따라서 이번 환경에서는 수동 preview 로그만으로 Stage 4 최적화가 적용된 release bundle의 preview latency를 측정했다고 말할 수 없다. 다만 사용자가 요구한 현재 PDF preview UI 자체는 data-based PDF provider 유지로 보존된다.

## Hygiene 확인

실행한 명령:

```bash
scripts/check-extension-registration-hygiene.sh \
  --check-only \
  --output-dir /private/tmp/rhwp-task88-hygiene

scripts/check-extension-registration-hygiene.sh \
  --cleanup-dev-registrations \
  --output-dir /private/tmp/rhwp-task88-hygiene-cleanup

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u -f build.noindex/DerivedDataTask88/Build/Products/Debug/Alhangeul.app

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u -f build.noindex/release/Alhangeul.app

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -gc

rm -rf build.noindex/DerivedDataTask88 build.noindex/release/Alhangeul.app build.noindex/release/xcodebuild

scripts/check-extension-registration-hygiene.sh \
  --check-only \
  --output-dir /private/tmp/rhwp-task88-hygiene-final3
```

최종 hygiene 결과:

```text
Provider app roots:
  - /Users/melee/Applications/Alhangeul.app
Development registrations:
  - /Users/melee/Documents/projects/rhwp-mac/build.noindex/DerivedDataTask88/Build/Products/Debug/Alhangeul.app
  - /Users/melee/Documents/projects/rhwp-mac/build.noindex/release/Alhangeul.app
  - /Users/melee/Documents/projects/rhwp-mac/build.noindex/release/xcodebuild/Alhangeul.app
Development app bundles found:
  - (none)
Issues:
  - development/test Alhangeul.app registrations remain in LaunchServices.
Warnings:
  - (none)
```

해석:

- PlugInKit provider root는 release installed app 하나로 정리됐다.
- generated app bundle 파일은 제거했지만 LaunchServices dump에는 build 산출물 경로가 stale record로 남아 있다.
- 표준 cleanup, force unregister, LaunchServices garbage collection으로도 stale record가 즉시 사라지지 않았다.
- global LaunchServices database delete/reset은 재부팅을 요구하고 사용자 환경 영향이 커서 수행하지 않았다.

## 성능 관측

이번 Stage 5에서 수치화한 first preview latency는 확보하지 못했다. 이유는 manual `qlmanage -p` runtime path가 `/Applications/Alhangeul.app`로 기록되어 Stage 4 변경이 들어간 `/Users/melee/Applications/Alhangeul.app` bundle을 직접 실행했다고 단정할 수 없기 때문이다.

대신 Stage 4의 성능 개선 근거는 code path 기준으로 유지한다.

- Quick Look PNG/PDF preview는 file load 이후 `RhwpDocument` open을 2회에서 1회로 줄였다.
- HostApp PDF export도 같은 중복 open을 제거했다.
- data-based PDF reply를 유지하므로 현재 PDF UI는 유지된다.

## 잔여 리스크

- 이 로컬 머신에는 `/Applications/Alhangeul.app` 설치본이 남아 있어 manual Quick Look preview path가 흔들린다.
- LaunchServices stale record 때문에 hygiene script는 실패 상태다. 다만 PlugInKit provider path는 installed release app 하나로 확인된다.
- 새 bundle의 preview latency를 정확히 측정하려면 `/Applications/Alhangeul.app`를 임시 unregister 또는 교체한 격리 환경에서 다시 `qlmanage -p`를 실행해야 한다.

## 다음 단계

Stage 6에서는 최종 보고서에 다음 결론을 명확히 적는다.

- `PDFView` lazy 제품화는 채택하지 않았다.
- 현재 PDF UI는 data-based PDF reply 유지로 보존했다.
- 이번 구현의 성능 개선은 중복 `RhwpDocument` open 제거다.
- Release package smoke와 Thumbnail smoke는 통과했지만, 이 머신의 LaunchServices stale registration 때문에 manual preview latency는 잔여 리스크로 남는다.
