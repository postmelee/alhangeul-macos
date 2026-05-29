# Task M014 #292 최종 보고서 - AppIcon macOS 관행 여백 보강

## 작업 요약

- 이슈: [#292 앱 아이콘이 너무 커요](https://github.com/postmelee/alhangeul-macos/issues/292)
- 마일스톤: M014 `v0.1.4 Native Preview/Viewer Parity`
- 브랜치: `local/task292`
- 기준 브랜치: `devel`
- 단계 수: 계획/구현 포함 5단계, 세부 보강 2개

Dock/Finder에서 알한글 앱 아이콘의 흰색 배경판이 다른 macOS 앱보다 크게 보일 수 있는 문제를 줄이기 위해 HostApp `AppIcon.appiconset` PNG 10개를 Apple macOS Sequoia production template의 `824 / 1024` keyline 기준으로 재생성했다.

최종 결과는 다음과 같다.

- 기존 AppIcon은 강한 불투명 영역이 캔버스 전체 `1.0000 x 1.0000`을 채웠다.
- Apple 기본 앱과 대표 앱의 중앙값은 `0.8047 x 0.8047`였다.
- 최종 AppIcon은 128px 이상 슬롯에서 `0.8047 x 0.8047`로 맞췄다.
- Debug build, Release 후보, `/Applications` 실제 교체 smoke에서 새 keyline이 확인됐다.
- `Contents.json`, `project.yml`, Swift source, Rust source는 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_16x16.png` | AppIcon 16px 슬롯을 새 keyline 기준으로 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png` | AppIcon 32px 실제 픽셀 슬롯 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_32x32.png` | AppIcon 32px 슬롯 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png` | AppIcon 64px 실제 픽셀 슬롯 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_128x128.png` | AppIcon 128px 슬롯을 `824 / 1024` keyline 계열로 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png` | AppIcon 256px 실제 픽셀 슬롯 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png` | AppIcon 256px 슬롯 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png` | AppIcon 512px 실제 픽셀 슬롯 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_512x512.png` | AppIcon 512px 슬롯 재생성 |
| `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png` | AppIcon 1024px master 슬롯 재생성 |
| `mydocs/orders/20260529.md` | #292 진행 상태와 완료 상태 기록 |
| `mydocs/plans/task_m014_292.md` | 수행계획서 |
| `mydocs/plans/task_m014_292_impl.md` | 구현계획서 |
| `mydocs/working/task_m014_292_stage1.md` | 현행/참조 앱 점유율 조사와 후보 비교 |
| `mydocs/working/task_m014_292_stage2.md` | AppIcon PNG 10개 재생성 결과 |
| `mydocs/working/task_m014_292_stage3.md` | Debug build 산출물 검증 |
| `mydocs/working/task_m014_292_stage4.md` | 표시/캐시 영향 검증과 `/Applications` 교체 smoke |
| `mydocs/report/task_m014_292_report.md` | 최종 보고서 |

## 변경 전·후 정량 비교

대표 1024px master 기준:

| 항목 | 변경 전 | 84% 1차 후보 | 최종 `824 / 1024` keyline |
|------|---------|--------------|---------------------------|
| strong bbox width | `1.0000` | `0.8398` | `0.8047` |
| strong bbox height | `1.0000` | `0.8398` | `0.8047` |
| strong coverage | `0.9392` | `0.6624` | `0.6081` |
| non-white bbox width | `0.7900` | `0.6641` | `0.6367` |
| non-white bbox height | `0.7471` | `0.6270` | `0.6016` |

참조 앱 측정값:

| 대상 | strong bbox width 중앙값 | strong bbox height 중앙값 | strong coverage 중앙값 |
|------|--------------------------|---------------------------|------------------------|
| Apple 기본 앱/대표 앱 | `0.8047` | `0.8047` | `0.6189` |
| 최종 알한글 AppIcon master | `0.8047` | `0.8047` | `0.6081` |

설치본 교체 전후:

| 항목 | 교체 전 `/Applications` | 교체 후 `/Applications` |
|------|--------------------------|--------------------------|
| `AppIcon.icns` | `91K` | `51K` |
| `Assets.car` | `4.6M` | `743K` |
| file icon strong bbox | cache 영향으로 새 아이콘처럼 보였으나 resource는 old | `0.8047 x 0.8047` |
| running icon strong bbox | cache 영향으로 새 아이콘처럼 보였으나 resource는 old | `0.8047 x 0.8047` |

작업 브랜치 변경량:

| 항목 | 값 |
|------|----|
| AppIcon PNG 변경 | 10개 |
| 계획/단계/최종 보고 문서 | 7개 |
| 오늘할일 문서 | 1개 |
| 최종 보고 전 task commit 수 | 8개 |
| `Contents.json` 변경 | 없음 |
| `project.yml` 변경 | 없음 |
| Swift/Rust source 변경 | 없음 |

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | 현재 AppIcon이 `1.0000 x 1.0000`으로 캔버스 전체를 채우고, 참조 앱 중앙값이 `0.8047 x 0.8047`임을 확인 |
| Stage 2 | Apple macOS Sequoia production template의 `1024` frame / `824` mask 기준으로 AppIcon PNG 10개 재생성 |
| Stage 2.1 | 84% 후보에서 Apple keyline 기준인 `824 / 1024 = 0.8046875`로 보정 |
| Stage 3 | HostApp Debug build 성공, `Assets.car` AppIcon rendition 10개 포함, `AppIcon.icns` 128px 이상 슬롯에서 `0.8047` 확인 |
| Stage 4 | About/Finder/IconServices/running icon 표시 경로와 cache 영향을 분리 |
| Stage 4.1 | Release 후보를 `/Applications/Alhangeul.app`에 실제 교체하는 clean install/update smoke 성공 |

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `sips -g pixelWidth -g pixelHeight -g hasAlpha Sources/HostApp/Assets.xcassets/AppIcon.appiconset/*.png` | OK | 10개 PNG 모두 기존 슬롯 해상도와 alpha 유지 |
| `python3 -m json.tool Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json` | OK | `Contents.json` 자체 변경 없음 |
| `git diff -- Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json project.yml` | OK | 출력 없음 |
| `xcodegen generate --spec project.yml` | OK | project 재생성 후 추적 diff 없음 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask292 CODE_SIGNING_ALLOWED=NO build` | OK | HostApp Debug build 성공 |
| `iconutil -c iconset ... AppIcon.icns` | OK | 128px 이상 추출 슬롯 `0.8047 x 0.8047` |
| `xcrun assetutil --info ... Assets.car` | OK | AppIcon rendition 10개 확인 |
| `scripts/package-release.sh` | OK | Release 후보와 zip 생성, SHA-256 `d33337e9821b616be10fae544becb36ca43cdbd504f75e4203fc9004bb5e807b` |
| `scripts/smoke-clean-quicklook-install.sh --replace-applications-install ...` | OK | `/Applications` 실제 교체, Quick Look provider 등록, HWP/HWPX thumbnail 생성 |
| `scripts/ci/verify-universal-macos-app.sh /Applications/Alhangeul.app` | OK | 본체/Preview/Thumbnail 모두 `x86_64 arm64` |
| `codesign --verify --deep --strict --verbose=2 /Applications/Alhangeul.app` | OK | ad-hoc smoke copy 기준 `valid on disk` |
| `build.noindex/task292/clean-install-smoke/20260529-125625/check-crashes.command` | OK | 새 extension crash report 없음 |
| `git diff --check` | OK | 공백 오류 없음 |
| `git status --short --branch` | OK | 최종 보고서 작성 전 clean 상태 확인 |

참고: 이 환경의 `plutil -lint Sources/HostApp/Assets.xcassets/AppIcon.appiconset/Contents.json`은 JSON 파일을 plist로 해석하지 못해 `Unexpected character { at line 1`로 실패한다. Xcode asset catalog의 `Contents.json`은 JSON parser 검증을 통과했고, 이번 작업에서 파일 내용은 변경하지 않았다.

## 사용자 업데이트 체감 가능성

이번 smoke 결과 기준으로, 새 bundle resource가 실제 `/Applications/Alhangeul.app`에 들어가면 업데이트만으로도 변화는 체감될 수 있다.

- `/Applications` 설치본 resource 자체가 새 `824 / 1024` keyline으로 바뀐다.
- 교체 후 IconServices file icon과 running app icon이 설치본 resource와 같은 `0.8047 x 0.8047` bbox를 반환했다.
- Quick Look extension provider도 `/Applications/Alhangeul.app` 경로로 재등록됐다.

다만 macOS IconServices/LaunchServices/Dock cache 상태에 따라 화면 갱신은 지연될 수 있다. 사용자 안내가 필요하면 영향이 작은 순서로 앱 재실행, Finder 재실행, Dock 재시작, 필요 시 IconServices cache reset을 분리해서 안내하는 편이 안전하다.

## 잔여 위험과 후속 작업

| 항목 | 상태 |
|------|------|
| 배포 서명/공증 | 이번 범위 아님. Stage 4.1은 Release 후보를 ad-hoc re-sign한 로컬 smoke다. |
| Homebrew Cask/Sparkle 실제 업데이트 경로 | 이번 범위 아님. 릴리스 단계에서 별도 검증 필요. |
| IconServices 전역 cache 삭제 | 수행하지 않음. 새 resource 설치만으로 file/running icon 갱신을 확인했다. |
| 작은 슬롯 반올림 | 16px/32px는 정수 pixel 반올림 때문에 `0.8125` 단위가 되지만 식별성은 유지됐다. |
| 기준 브랜치 최신화 | `devel`에 #293 merge가 추가되어 PR 생성 시 base/head 상태를 확인해야 한다. 충돌이 있으면 별도 승인 후 통합 방식 결정. |

## PR 공유용 요약

- 알한글 AppIcon PNG 10개를 Apple macOS Sequoia production template의 `824 / 1024` keyline 기준으로 재생성했다.
- 기존 master strong bbox `1.0000 x 1.0000`을 `0.8047 x 0.8047`로 줄여 Apple 기본 앱 중앙값과 맞췄다.
- Debug build와 Release 후보에서 `Assets.car` AppIcon rendition 10개, `AppIcon.icns` 추출 슬롯, IconServices/running icon 표시를 검증했다.
- Release 후보를 `/Applications/Alhangeul.app`에 실제 교체하는 clean install/update smoke를 추가로 수행해 사용자 업데이트 체감 가능성을 확인했다.

## 작업지시자 승인 요청

#292 구현과 최종 보고서 작성은 완료됐다. 다음 단계는 `publish/task292` 원격 브랜치 push와 `devel` 대상 Open PR 생성이다.
