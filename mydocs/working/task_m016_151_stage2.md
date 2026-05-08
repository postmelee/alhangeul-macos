# Task M016 #151 Stage 2 보고서

## 단계 목적

설치본 smoke gate의 pass/fail 기준을 `bundle 정합성`, `시스템 등록`, `thumbnail 자동 smoke`, `preview 수동 확인`, `실패 로그 수집`으로 나누어 확정한다. 또한 Stage 3에서 추가할 helper script의 옵션, 기본 경로, 출력, 실패 코드 정책을 설계한다.

이번 단계는 설계 문서만 추가했다. 운영 문서와 script 본문은 Stage 3에서 수정한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m016_151_stage2.md` | 설치본 smoke gate 판정 기준과 helper script 설계 |

## gate 계층

Stage 3 이후 표준 smoke gate는 다음 계층으로 판정한다.

| 계층 | 자동 판정 | 실패 시 의미 |
|------|-----------|--------------|
| bundle 정합성 | 예 | Release package 산출물이 app/appex 구조, identifier, principal class, signing 기준을 만족하지 않음 |
| 시스템 등록 | 예 | 표준 설치 경로에 배치한 app이 LaunchServices/PlugInKit에 등록되지 않음 |
| thumbnail 실행 smoke | 예 | 등록된 Thumbnail extension이 대표 HWP/HWPX sample에서 headless thumbnail을 생성하지 못함 |
| preview 확인 | 아니오, 수동 | Quick Look preview GUI 확인 필요. 자동 gate와 별도 기록 |
| 실패 로그 수집 | 부분 자동 | 실패 원인 분리를 위한 진단 자료 확보 |

## bundle 정합성 기준

입력 app은 기본 `build.noindex/release/Alhangeul.app`이다. helper script에서 `--app <path>`를 받으면 해당 경로를 입력으로 쓴다.

필수 확인:

| 항목 | 기준 |
|------|------|
| app directory | `<app>/Contents/Info.plist` 존재 |
| Preview appex | `<app>/Contents/PlugIns/AlhangeulPreview.appex/Contents/Info.plist` 존재 |
| Thumbnail appex | `<app>/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/Info.plist` 존재 |
| HostApp identifier | `com.postmelee.alhangeul` |
| Preview identifier | `com.postmelee.alhangeul.QLExtension` |
| Thumbnail identifier | `com.postmelee.alhangeul.ThumbnailExtension` |
| Preview extension point | `com.apple.quicklook.preview` |
| Thumbnail extension point | `com.apple.quicklook.thumbnail` |
| Preview principal class | `AlhangeulPreview.HwpPreviewProvider` 또는 build 전 plist의 `$(PRODUCT_MODULE_NAME).HwpPreviewProvider` |
| Thumbnail principal class | `AlhangeulThumbnail.HwpThumbnailProvider` 또는 build 전 plist의 `$(PRODUCT_MODULE_NAME).HwpThumbnailProvider` |
| supported types | `com.postmelee.alhangeul.hwp`, `com.postmelee.alhangeul.hwpx`, `com.hancom.hwp`, `com.hancom.hwpx` 포함 |
| localized display | app/appex `LSHasLocalizedDisplayName = true`, `InfoPlist.strings` 포함 |
| signing/sealed resources | `codesign --verify --deep --strict --verbose=2 <app>` 성공 |

Stage 3 helper script는 built app을 대상으로 하므로 principal class는 실제 module name 기준 값을 우선 확인한다. source plist를 직접 검사하는 문서 검증에서는 `$(PRODUCT_MODULE_NAME)` 표현도 허용한다.

## 시스템 등록 기준

표준 설치 경로는 `$HOME/Applications/Alhangeul.app` 하나로 고정한다.

등록 흐름:

1. `LSREGISTER`는 우선 `/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister`를 사용한다.
2. 해당 경로가 없으면 `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister`로 fallback한다.
3. 기존 `$HOME/Applications/Alhangeul.app`만 unregister 후 교체한다.
4. `RhwpMac.app`, `AlhangeulMac.app`, `알한글.app`은 삭제하지 않는다. 발견하면 진단 출력에 warning으로 남긴다.
5. `ditto <input-app> "$HOME/Applications/Alhangeul.app"`로 설치한다.
6. `lsregister -f -R -trusted "$HOME/Applications/Alhangeul.app"`로 등록한다.
7. `pluginkit -a "$HOME/Applications/Alhangeul.app"`를 실행한다.
8. `pluginkit -mAvvv` 출력에서 `com.postmelee.alhangeul.QLExtension`과 `com.postmelee.alhangeul.ThumbnailExtension`이 모두 확인되어야 한다.

`qlmanage -m plugins`는 app extension 기반 등록 상태를 직접 반영하지 않을 수 있으므로 pass/fail 판정에 쓰지 않는다.

## thumbnail 자동 gate

자동 gate에는 정상 HWP와 정상 HWPX sample을 모두 포함한다.

| sample | 역할 | 판정 |
|--------|------|------|
| `samples/basic/KTX.hwp` | HWP 기본 thumbnail smoke | `qlmanage -t -x` exit code 0, sample별 output directory에 파일 1개 이상 생성 |
| `samples/hwpx/hwpx-01.hwpx` | HWPX 기본 thumbnail smoke | `qlmanage -t -x` exit code 0, sample별 output directory에 파일 1개 이상 생성 |

기본 output root는 `/tmp/alhangeul-ql`로 둔다. helper script는 stale output 혼선을 피하기 위해 실행별 하위 디렉터리를 만든다.

예시:

```text
/tmp/alhangeul-ql/task151-YYYYMMDD-HHMMSS/
├── diagnostics/
├── hwp/
└── hwpx/
```

각 sample은 별도 output directory를 사용한다.

```bash
qlmanage -r
qlmanage -r cache
qlmanage -t -x -s 512 -o "$RUN_DIR/hwp" samples/basic/KTX.hwp
qlmanage -t -x -s 512 -o "$RUN_DIR/hwpx" samples/hwpx/hwpx-01.hwpx
```

손상/대용량 fallback 입력은 #149와 연결되므로 #151 기본 gate에는 넣지 않는다. Stage 3 문서에는 선택 smoke로 분리해 둘 수 있다.

## preview 수동 확인

`qlmanage -p`와 Finder Space preview는 자동 pass/fail gate로 쓰지 않는다. Stage 4 리허설과 최종 보고서에는 다음 형식으로 수동 확인 결과를 남긴다.

| sample | 명령 | 결과 기록 |
|--------|------|-----------|
| HWP | `qlmanage -p samples/basic/KTX.hwp` | preview 창 표시 여부, 첫 페이지 표시 여부, 오류 문구 |
| HWPX | `qlmanage -p samples/hwpx/hwpx-01.hwpx` | preview 창 표시 여부, 첫 페이지 표시 여부, 오류 문구 |

수동 확인을 수행하지 못한 경우에는 "미수행"으로 기록하고 이유를 남긴다. 자동 thumbnail gate 통과와 preview 수동 확인 미수행은 서로 다른 판정으로 취급한다.

## 실패 로그 수집

helper script는 실패 여부와 무관하게 가능한 진단 자료를 `$RUN_DIR/diagnostics`에 남긴다.

필수 후보:

| 파일 | 명령 |
|------|------|
| `pluginkit.txt` | `pluginkit -mAvvv` |
| `lsregister-alhangeul.txt` | `lsregister -dump` 후 `com.postmelee.alhangeul`, `Alhangeul.app` 관련 줄 필터 |
| `codesign-app.txt` | `codesign -dv --verbose=4 "$APP"` |
| `codesign-verify.txt` | `codesign --verify --deep --strict --verbose=2 "$APP"` |
| `app-info.plist.txt` | `plutil -p "$APP/Contents/Info.plist"` |
| `preview-info.plist.txt` | `plutil -p "$APP/Contents/PlugIns/AlhangeulPreview.appex/Contents/Info.plist"` |
| `thumbnail-info.plist.txt` | `plutil -p "$APP/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/Info.plist"` |
| `qlmanage-hwp.log` | HWP thumbnail smoke stdout/stderr |
| `qlmanage-hwpx.log` | HWPX thumbnail smoke stdout/stderr |
| `old-install-candidates.txt` | `mdfind` 또는 `lsregister -dump`로 찾은 `RhwpMac.app`, `AlhangeulMac.app`, `알한글.app` 후보 |

수동 진단 후보:

```bash
log show --style compact --last 10m --predicate 'process == "quicklookd" OR process == "QuickLookUIService" OR eventMessage CONTAINS "com.postmelee.alhangeul"'
log stream --style compact --predicate 'process == "quicklookd" OR process == "QuickLookUIService" OR eventMessage CONTAINS "com.postmelee.alhangeul"'
```

`log show`는 Stage 3 helper script에서 실패 시 best-effort로 저장할 수 있다. `log stream`은 대화형 실시간 확인이므로 문서의 수동 진단 명령으로 둔다.

## helper script 설계

Stage 3에서 `scripts/smoke-finder-integration.sh`를 추가한다.

기본 사용:

```bash
scripts/smoke-finder-integration.sh --version 0.1.0
```

이미 생성된 app으로 실행:

```bash
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
```

옵션:

| 옵션 | 기본값 | 의미 |
|------|--------|------|
| `--version <version>` | `0.1.0` | `--skip-package`가 없고 `--app`이 없을 때 `scripts/package-release.sh <version>`에 전달 |
| `--app <path>` | `build.noindex/release/Alhangeul.app` | package 생성 없이 사용할 Release package staging app |
| `--skip-package` | false | package 생성을 생략하고 `--app` 또는 기본 app path를 사용 |
| `--output-dir <path>` | `/tmp/alhangeul-ql` | 실행별 output directory의 root |
| `--sample-hwp <path>` | `samples/basic/KTX.hwp` | HWP thumbnail smoke 입력 |
| `--sample-hwpx <path>` | `samples/hwpx/hwpx-01.hwpx` | HWPX thumbnail smoke 입력 |
| `--help` | 해당 없음 | usage 출력 |

동작 정책:

- `--app`이 주어지면 package 생성을 암묵적으로 생략한다.
- `--skip-package`와 `--app`을 함께 주는 사용법도 허용한다.
- package를 생성하는 경우 기존 `scripts/package-release.sh`를 그대로 호출하고, 실패하면 helper script도 실패한다.
- 실행 초기에 `$HOME/Applications/Alhangeul.app`을 교체한다는 notice를 stderr에 출력한다.
- script는 비대화형으로 동작한다. Stage 4에서 설치 경로 교체는 작업지시자 승인 후 수행하므로 내부 prompt는 두지 않는다.
- 교체 대상은 `$HOME/Applications/Alhangeul.app` 하나로 제한한다.
- 이전 이름 설치본은 warning과 diagnostics에만 남기고 삭제하지 않는다.
- output directory는 실행별 하위 디렉터리를 만들어 stale output을 피한다.

실패 코드 정책:

| exit code | 의미 |
|-----------|------|
| `0` | bundle 정합성, 시스템 등록, HWP/HWPX thumbnail smoke 통과 |
| `2` | 잘못된 option 또는 필수 도구/파일 없음 |
| `10` | package 생성 또는 bundle 정합성 실패 |
| `20` | 표준 설치 경로 복사, LaunchServices 등록, PlugInKit add 실패 |
| `30` | `pluginkit -mAvvv`에서 Preview 또는 Thumbnail extension 미확인 |
| `40` | `qlmanage -t -x` 실행 실패 또는 output 미생성 |

## Stage 3 변경안

Stage 3에서 수정할 파일:

| 파일 | 변경 방향 |
|------|-----------|
| `scripts/smoke-finder-integration.sh` | 설치본 smoke gate helper script 신규 추가 |
| `mydocs/manual/build_run_guide.md` | Finder 통합 확인의 표준 흐름을 helper script 우선으로 정리하고, 수동 명령은 진단용으로 유지 |
| `mydocs/manual/release_distribution_guide.md` | release pipeline smoke 기준을 helper script와 연결 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 현재 product 기준을 `Alhangeul`/`com.postmelee.alhangeul`로 보정 |
| `README.md` | 필요 시 Finder extension 등록 검증 진입점만 짧게 보강 |

수정하지 않을 파일:

| 파일 | 이유 |
|------|------|
| `mydocs/report/task_m050_33_report.md` | 과거 단계 보고서 원문 |
| `mydocs/working/task_m050_40_stage4.md` | 과거 단계 보고서 원문 |
| `mydocs/troubleshootings/task_m050_40_quicklook_thumbnail_registration_validation.md` | #40 당시 기준 기록. Stage 3에서는 현재 운영 troubleshooting인 `finder_integration_validation_pitfalls.md`에서 링크 설명을 보정하는 방식 우선 |

## 본문 변경 정도 / 본문 무손실 여부

이번 단계는 신규 Stage 2 보고서만 추가했다. 기존 운영 문서, source, script는 수정하지 않았으므로 기존 본문 손실은 없다.

## 검증 결과

구현계획서 Stage 2 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과:

```text
## local/task151
?? mydocs/working/task_m016_151_stage2.md
```

```bash
rg -n "bundle 정합성|시스템 등록|thumbnail|preview|수동|helper|smoke-finder-integration|AlhangeulPreview|AlhangeulThumbnail|KTX|hwpx-01|log show|log stream" \
  mydocs/working/task_m016_151_stage2.md
```

결과: 모든 키워드가 Stage 2 보고서에 존재한다.

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- Stage 3 helper script가 실제 LaunchServices/PlugInKit 상태를 바꾸므로 Stage 4 실행 전 명시 승인을 다시 확인해야 한다.
- HWPX thumbnail이 현재 시스템 상태에서 실패하면 gate는 실패로 처리한다. 실패 시 content type routing, PlugInKit 등록, renderer fallback을 분리해야 한다.
- `log show` predicate는 macOS 로그 상태와 권한에 따라 충분한 정보를 못 줄 수 있다. 따라서 실패 원인 판정의 필수 조건이 아니라 보조 진단으로 둔다.
- `qlmanage -p` preview는 여전히 수동 확인이 필요하며, 자동 gate 통과만으로 preview 시각 품질을 보장하지 않는다.

## 다음 단계 영향

Stage 3에서는 이 설계를 기준으로 `scripts/smoke-finder-integration.sh`를 추가하고 운영 문서를 현재 product 기준에 맞게 보강한다. 특히 `finder_integration_validation_pitfalls.md`의 `AlhangeulMac`/`alhangeulmac` 예시는 `Alhangeul`/`com.postmelee.alhangeul` 기준으로 정리해야 한다.

## 승인 요청

Stage 2 완료를 승인해주시면 Stage 3 `문서와 helper script 보강`으로 진행한다.
