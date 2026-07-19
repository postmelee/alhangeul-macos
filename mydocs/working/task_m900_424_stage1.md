# Task M900 #424 Stage 1 완료보고서

## 단계 목적

`v0.1.8 (14)` public release 후보의 source metadata와 Release Rehearsal/Publish workflow 기본 입력을 `rhwp v0.7.18` 기준으로 정렬한다.

## 산출물

- `Sources/HostApp/Info.plist`
  - `CFBundleShortVersionString`: `0.1.7` -> `0.1.8`
  - `CFBundleVersion`: `13` -> `14`
- `Sources/QLExtension/Info.plist`
  - `CFBundleShortVersionString`: `0.1.7` -> `0.1.8`
  - `CFBundleVersion`: `13` -> `14`
- `Sources/ThumbnailExtension/Info.plist`
  - `CFBundleShortVersionString`: `0.1.7` -> `0.1.8`
  - `CFBundleVersion`: `13` -> `14`
- `.github/workflows/release-rehearsal.yml`
  - `version=0.1.8`
  - `previous_release_ref=v0.1.7`
  - `expected_rhwp_tag=v0.7.18`
- `.github/workflows/release-publish.yml`
  - `version=0.1.8`
  - `previous_release_ref=v0.1.7`
  - `expected_rhwp_tag=v0.7.18`
  - `require_latest_rhwp=true`, `include_rhwp_in_title=true` 기본값 유지
- `mydocs/working/task_m900_424_stage1.md`
  - Stage 1 변경과 검증 결과 기록

보고서 제외 source 변경량은 5개 파일, 12줄 추가와 12줄 삭제다.

## 본문 변경 정도 / 본문 무손실 여부

세 plist는 version/build 문자열만 교체했다. bundle identifier, document type, imported UTI, extension 설정과 나머지 plist 본문은 변경하지 않았다.

두 workflow는 `workflow_dispatch`의 release identity 기본 입력 세 항목만 교체했다. workflow job, permission, signing/notary, release guard와 publish 동작은 변경하지 않았다. 특히 upstream latest guard의 `require_latest_rhwp=true` 기본값은 유지했다. 이번 `v0.7.18` 예외는 Stage 4/5의 workflow 실행 시 별도 승인과 `require_latest_rhwp=false` 입력으로만 처리한다.

## 검증 결과

### 앱과 확장 version/build

다음 값으로 세 target이 일치했다.

```text
HostApp: 0.1.8 (14)
QLExtension: 0.1.8 (14)
ThumbnailExtension: 0.1.8 (14)
```

`plutil -lint` 결과:

```text
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK
```

### core와 bundled studio provenance

```text
rhwp_release_tag: v0.7.18
rhwp_commit: 93862a4e16df59834ebce46d91e948cd739208e9
OK: rhwp-studio assets verified
```

`rhwp-core.lock`과 bundled `rhwp-studio` asset manifest가 계획의 expected tag/commit과 일치했다.

### workflow 구문과 기본 입력

Ruby `Psych.parse_file`로 `.github/workflows/release-rehearsal.yml`과 `.github/workflows/release-publish.yml`을 파싱했으며 exit code 0으로 통과했다. 로컬 Ruby가 사용하지 않는 `ffi-1.13.1` native extension 미빌드 경고를 출력했지만 YAML parse 결과에는 영향을 주지 않았다.

두 workflow에서 다음 기본 입력을 확인했다.

```text
version: 0.1.8
previous_release_ref: v0.1.7
expected_rhwp_tag: v0.7.18
```

Publish workflow의 boolean guard는 다음과 같이 유지됐다.

```text
require_latest_rhwp: true
include_rhwp_in_title: true
```

`git diff --check`도 통과했다.

## 잔여 위험

- upstream latest는 `v0.7.19`이므로 Publish workflow를 기본값 그대로 실행하면 latest guard가 후보를 차단한다. 이는 의도한 안전 동작이며 Stage 4/5에서 Task #422와 upstream #2396 근거로 실행별 예외 승인을 받아야 한다.
- 이번 단계는 source metadata 정렬만 소유한다. 앱 build, universal slice, package, signed/notarized artifact와 실제 설치 smoke는 Stage 3~5에서 검증한다.
- public release note, Pages, README와 release record는 아직 `v0.1.8` 기준으로 작성하지 않았다.
- candidate commit은 Stage 2~3 변경과 release PR 반영 후 다시 확정해야 한다.

## 다음 단계 영향

Stage 2는 정렬된 `0.1.8 (14)` / `rhwp v0.7.18` identity를 기준으로 release communication을 작성한다. `v0.1.7..candidate` 포함 PR을 먼저 분석하고, 다음 공개 문구 경계를 유지해야 한다.

- `rhwp v0.7.18`과 실제 앱에서 확인된 bundled editor 변화
- HOP 문서 형식에서 Finder 후보 경로 보강
- `rhwp v0.7.19`, external linked image 완료, Skia default와 기본 앱 자동 설정 주장은 제외

## 승인 요청

Stage 1 source metadata 정렬과 검증 결과를 승인하고, Stage 2 `Release Communication 작성` 진입을 요청한다.
