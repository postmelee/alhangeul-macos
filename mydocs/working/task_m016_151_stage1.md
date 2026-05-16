# Task M016 #151 Stage 1 보고서

## 단계 목적

현행 Finder Quick Look/Thumbnail 설치본 smoke 절차를 변경 없이 조사하고, Stage 2에서 설계할 smoke gate의 입력을 확정한다.

이번 단계에서는 운영 문서, troubleshooting 문서, 과거 보고서, 현재 `project.yml`/`Info.plist`, `scripts/package-release.sh`, 대표 sample 파일 상태만 확인했다. 운영 문서나 script 본문은 수정하지 않았다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m016_151_stage1.md` | 현행 Finder 통합 smoke inventory와 Stage 2 입력 정리 |

## 현행 운영 기준

현재 운영 문서의 중심 기준은 다음과 같다.

| 항목 | 현재 기준 |
|------|-----------|
| package 생성 | `./scripts/package-release.sh 0.1.0` |
| staging app | `build.noindex/release/Alhangeul.app` |
| 개발/검증용 zip | `build.noindex/release/alhangeul-macos-<version>.zip` |
| 표준 설치 경로 | `$HOME/Applications/Alhangeul.app` |
| 등록 확인 | `pluginkit -mAvvv | grep com.postmelee.alhangeul` |
| cache reset | `qlmanage -r`, `qlmanage -r cache` |
| thumbnail smoke | `qlmanage -t -x -s 512 -o /tmp/alhangeul-ql samples/basic/KTX.hwp` |
| preview 확인 | `qlmanage -p samples/basic/KTX.hwp` |

`build_run_guide.md`는 Finder 통합 검증을 `compile/link`, `bundle resource 포함`, `LaunchServices/PlugInKit/Quick Look 실행 확인` 세 계층으로 이미 분리하고 있다. 실행 확인 계층은 Release package 산출물과 `lsregister`, `pluginkit`, `qlmanage -t`를 기준으로 둔다.

`release_distribution_guide.md`는 release pipeline 검증에서 Debug 산출물 금지, `package-release` 산출물 사용, 자동화 환경의 `qlmanage -t -x` 우선 판정을 명시한다.

## 현재 app/appex inventory

`project.yml` 기준:

| target | product | executable | bundle identifier |
|--------|---------|------------|-------------------|
| HostApp | `Alhangeul` | `Alhangeul` | `com.postmelee.alhangeul` |
| QLExtension | `AlhangeulPreview` | `AlhangeulPreview` | `com.postmelee.alhangeul.QLExtension` |
| ThumbnailExtension | `AlhangeulThumbnail` | `AlhangeulThumbnail` | `com.postmelee.alhangeul.ThumbnailExtension` |

`Info.plist` 기준:

| bundle | display/name | extension point | principal class | supported types |
|--------|--------------|-----------------|-----------------|-----------------|
| HostApp | `Alhangeul` | 해당 없음 | `NSApplication` | `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx`, `com.hancom.hwp`, `com.hancom.hwpx`, `com.haansoft.hancomofficeviewer.mac.hwp`, `com.haansoft.hancomofficeviewer.mac.hwpx` |
| Preview appex | `AlhangeulPreview` | `com.apple.quicklook.preview` | `$(PRODUCT_MODULE_NAME).HwpPreviewProvider` | HostApp과 동일 6개 type |
| Thumbnail appex | `AlhangeulThumbnail` | `com.apple.quicklook.thumbnail` | `$(PRODUCT_MODULE_NAME).HwpThumbnailProvider` | HostApp과 동일 6개 type |

두 appex 모두 `LSHasLocalizedDisplayName = true`, `CFBundleShortVersionString = 0.1.0`, `CFBundleVersion = 1`을 가진다.

## package-release inventory

`scripts/package-release.sh`의 현재 동작:

- 인자: version 1개
- build root: `${ALHANGEUL_BUILD_ROOT:-$ROOT/build.noindex}`
- release directory: `build.noindex/release`
- Xcode project: `Alhangeul.xcodeproj`
- Release configuration build 후 staging app을 `build.noindex/release/Alhangeul.app`으로 복사
- zip: `alhangeul-macos-<version>.zip`
- staging app filesystem name은 ASCII `Alhangeul.app`으로 유지
- non-ASCII `.app` path가 ExtensionKit lookup을 깨뜨릴 수 있다는 주석이 script에 남아 있음
- `build.noindex/.metadata_never_index`를 생성해 Spotlight 혼선을 줄임
- build 중간 산출물과 cleanup glob은 `Alhangeul*.appex`, `Alhangeul*.swiftmodule` 기준

#145 Stage 4 기준으로 `build.noindex/release/Alhangeul.app`에는 `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex`, bundled `rhwp-studio` asset이 포함됐고, local signing/sealed resources 검증이 통과했다.

## 대표 sample 입력

Stage 2의 기본 HWP/HWPX sample 후보는 모두 존재한다.

| sample | 크기 | 용도 |
|--------|------|------|
| `samples/basic/KTX.hwp` | 66048 bytes | HWP thumbnail/preview 기본 smoke |
| `samples/hwpx/hwpx-01.hwpx` | 484352 bytes | HWPX thumbnail/preview 기본 smoke |

현재 `build_run_guide.md`의 thumbnail 예시는 HWP만 기본으로 들고 있고, `release_distribution_guide.md`도 기본 샘플을 `samples/basic/KTX.hwp`로 둔다. Stage 2에서는 HWPX를 필수 gate에 포함할지 확정해야 한다.

## 현재 문서의 보정 후보

현재 운영 문서 대부분은 `Alhangeul` 기준으로 정리되어 있다. 다만 다음 파일에는 현행 기준과 다른 과거 product name이 남아 있다.

| 파일 | 상태 | Stage 3 처리 방향 |
|------|------|------------------|
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | `com.postmelee.alhangeulmac`, `AlhangeulMac.app`, `AlhangeulMacPreview.appex` 예시가 현재 진단 기준처럼 남아 있음 | 현재 운영 troubleshooting이므로 `Alhangeul` 기준으로 보정 |
| `mydocs/troubleshootings/task_m050_40_quicklook_thumbnail_registration_validation.md` | #40 당시 `AlhangeulMac` 기준 절차 기록 | 과거 기록 문서로 보존. 필요 시 상단에 역사적 기준임을 짧게 표기할지 Stage 2에서 판단 |
| `mydocs/report/task_m050_33_report.md` | #33 당시 `RhwpMac`, `AlhangeulMac`, `알한글.app` 시행착오 원문 | 과거 보고서이므로 수정하지 않음 |
| `mydocs/working/task_m050_40_stage4.md` | #40 단계 보고서 원문 | 과거 보고서이므로 수정하지 않음 |

또한 `build_run_guide.md`와 `release_distribution_guide.md`는 이전 이름 설치본 예시로 `RhwpMac.app`, `알한글.app`을 언급한다. 이는 현재 기준과 충돌하는 product name이 아니라 discovery 충돌 후보 설명이므로 유지 가능하다.

## 판정 기준 혼선

Stage 2에서 명확히 나눌 혼선은 다음과 같다.

- `qlmanage -m plugins`는 app extension 기반 Quick Look/Thumbnail 등록 상태를 직접 판정하지 않는다.
- `pluginkit -mAvvv`는 등록 후보 확인이고, 실제 렌더 smoke는 `qlmanage -t -x`로 확인한다.
- `qlmanage -p`는 preview 경로 확인에 유용하지만 GUI/user session/cache 영향이 있어 headless 자동 gate로 쓰기 어렵다.
- Debug 산출물은 compile/link와 bundle resource 확인용이고, PlugInKit registration smoke의 진실 원천이 아니다.
- 이전 이름 설치본은 충돌 후보지만 무조건 삭제하지 않는다. 발견 후 작업지시자 승인으로만 제거한다.
- `build_run_guide.md`의 손상/대용량 thumbnail fallback smoke는 #149와 맞물린다. #151의 기본 gate에는 HWP/HWPX 정상 샘플을 우선 두고, fallback 입력은 선택 항목으로 둘지 Stage 2에서 확정해야 한다.

## Stage 2 입력

Stage 2 설계에서 확정할 항목:

- bundle 정합성: app/appex 존재, `Info.plist`, bundle identifier, principal class, supported type, `codesign --verify`
- 시스템 등록: `lsregister` unregister/register, `$HOME/Applications/Alhangeul.app` 설치, `pluginkit -a`, `pluginkit -mAvvv`
- 자동 gate: `qlmanage -t -x` output 생성 기준, HWP/HWPX sample set, output directory, 실패 코드
- 수동 확인: `qlmanage -p`와 Finder Space preview의 보고 형식
- 실패 로그: `pluginkit`, `lsregister -dump`, `codesign -dv`, `plutil -p`, `qlmanage` stderr, unified log predicate 후보
- helper script: `scripts/smoke-finder-integration.sh`의 기본 입력, `--app`, `--skip-package`, 설치 경로 교체 고지, 이전 설치본 발견만 보고하는 정책

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 신규 단계 보고서만 추가했다. 기존 운영 문서, troubleshooting 문서, source, script는 수정하지 않았으므로 기존 본문 손실은 없다.

## 검증 결과

구현계획서 Stage 1 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과:

```text
## local/task151
```

```bash
rg -n "Quick Look|Thumbnail|PlugInKit|qlmanage|lsregister|package-release|Alhangeul|AlhangeulMac|RhwpMac|알한글" \
  mydocs/manual/build_run_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/troubleshootings/finder_integration_validation_pitfalls.md \
  mydocs/report/task_m050_33_report.md \
  mydocs/working/task_m050_40_stage4.md \
  mydocs/working/task_m016_145_stage4.md
```

결과 요약:

- `build_run_guide.md`는 `Alhangeul.app`, `$HOME/Applications/Alhangeul.app`, `pluginkit -mAvvv | grep com.postmelee.alhangeul`, `qlmanage -p`, `qlmanage -t -x` 기준을 포함한다.
- `release_distribution_guide.md`는 `package-release` 산출물 기준, Debug 산출물 금지, 자동화 환경의 `qlmanage -t -x` 우선 기준을 포함한다.
- `finder_integration_validation_pitfalls.md`에는 현재 기준과 다른 `alhangeulmac`/`AlhangeulMac` 예시가 남아 있다.
- #33/#40 보고서는 과거 시행착오와 당시 product name을 기록하고 있다.
- #145 Stage 4는 현재 `Alhangeul.app`, `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex` 포함과 local signing 검증 통과를 기록한다.

```bash
plutil -p Sources/QLExtension/Info.plist
plutil -p Sources/ThumbnailExtension/Info.plist
```

결과 요약:

- Preview extension point: `com.apple.quicklook.preview`
- Preview principal class: `$(PRODUCT_MODULE_NAME).HwpPreviewProvider`
- Thumbnail extension point: `com.apple.quicklook.thumbnail`
- Thumbnail principal class: `$(PRODUCT_MODULE_NAME).HwpThumbnailProvider`
- 두 appex 모두 HWP/HWPX 관련 6개 content type을 지원한다.

```bash
rg -n "PRODUCT_NAME|EXECUTABLE_NAME|PRODUCT_BUNDLE_IDENTIFIER|AlhangeulPreview|AlhangeulThumbnail" project.yml
```

결과:

```text
32:        PRODUCT_NAME: Alhangeul
33:        EXECUTABLE_NAME: Alhangeul
34:        PRODUCT_BUNDLE_IDENTIFIER: com.postmelee.alhangeul
52:        PRODUCT_NAME: AlhangeulPreview
53:        EXECUTABLE_NAME: AlhangeulPreview
54:        PRODUCT_BUNDLE_IDENTIFIER: com.postmelee.alhangeul.QLExtension
71:        PRODUCT_NAME: AlhangeulThumbnail
72:        EXECUTABLE_NAME: AlhangeulThumbnail
73:        PRODUCT_BUNDLE_IDENTIFIER: com.postmelee.alhangeul.ThumbnailExtension
```

```bash
sed -n '1,120p' scripts/package-release.sh
```

결과 요약:

- project name은 `Alhangeul`
- build app과 staging app은 `Alhangeul.app`
- zip은 `alhangeul-macos-$VERSION.zip`
- build root는 기본 `build.noindex`
- staging app 복사 전 non-ASCII `.app` path가 ExtensionKit lookup을 깨뜨릴 수 있다는 주석이 있다.

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- `finder_integration_validation_pitfalls.md`가 현재 운영 troubleshooting 문서인데도 `AlhangeulMac` 기준을 사용한다. Stage 3에서 보정하지 않으면 #151 smoke gate와 충돌할 수 있다.
- HWPX sample을 자동 thumbnail gate에 포함할지 아직 확정되지 않았다.
- 손상/대용량 fallback thumbnail 입력은 #149 범위와 연결되므로 #151 기본 gate와 선택 gate를 분리해야 한다.
- `qlmanage -p`는 자동 gate로 쓰지 않는 방향이 맞지만, 수동 확인 결과를 보고서에 어떤 형식으로 남길지 Stage 2에서 정해야 한다.

## 다음 단계 영향

Stage 2에서는 조사 결과를 바탕으로 smoke gate를 다음 다섯 영역으로 설계한다.

1. bundle 정합성
2. 시스템 등록
3. `qlmanage -t -x` 자동 thumbnail smoke
4. `qlmanage -p`/Finder Space 수동 preview 확인
5. 실패 로그 수집과 이전 설치본 충돌 처리

Stage 3 변경 후보는 `scripts/smoke-finder-integration.sh`, `build_run_guide.md`, `release_distribution_guide.md`, `finder_integration_validation_pitfalls.md`다.

## 승인 요청

Stage 1 완료를 승인해주시면 Stage 2 `smoke gate 판정 기준 설계`로 진행한다.
