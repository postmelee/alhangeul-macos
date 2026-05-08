# Task M016 #151 Stage 3 보고서

## 단계 목적

Stage 2에서 확정한 설치본 smoke gate를 helper script와 운영 문서에 반영하고, 현재 `Alhangeul` product name 기준으로 troubleshooting 문서를 보정한다.

이번 단계에서는 실제 `$HOME/Applications/Alhangeul.app` 설치나 `qlmanage -t` smoke 실행은 하지 않았다. 설치본 등록과 Quick Look/Thumbnail 실행 smoke는 Stage 4에서 작업지시자 승인 후 수행한다.

## 산출물

| 파일 | 변경 내용 |
|------|-----------|
| `scripts/smoke-finder-integration.sh` | Release package 생성/재사용, bundle 정합성, 설치/등록, PlugInKit 확인, HWP/HWPX thumbnail smoke, diagnostics 수집 helper 추가 |
| `mydocs/manual/build_run_guide.md` | Finder 통합 확인을 helper script 중심으로 정리하고, `qlmanage -p` preview는 수동 확인으로 분리 |
| `mydocs/manual/release_distribution_guide.md` | release pipeline smoke 기준을 helper script와 연결하고 HWP/HWPX sample 기준을 명시 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 현재 product name과 identifier를 `Alhangeul`/`com.postmelee.alhangeul` 기준으로 보정 |
| `mydocs/working/task_m016_151_stage3.md` | Stage 3 완료 보고서 |

README는 이번 단계에서 수정하지 않았다. 기존 README의 Finder 통합 문제 진입점은 현재 `build_run_guide.md`로 이어지며, 세부 smoke 절차를 README에 중복할 필요는 없다고 판단했다.

## helper script 요약

기본 사용:

```bash
scripts/smoke-finder-integration.sh --version 0.1.0
```

이미 생성된 Release package staging app 재사용:

```bash
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
```

주요 옵션:

| 옵션 | 기본값 | 의미 |
|------|--------|------|
| `--version <version>` | `0.1.0` | package 생성 시 `scripts/package-release.sh`에 전달 |
| `--app <path>` | `build.noindex/release/Alhangeul.app` | 기존 staging app 사용. 지정 시 package 생성 생략 |
| `--skip-package` | false | package 생성 생략 |
| `--output-dir <path>` | `/tmp/alhangeul-ql` | 실행별 thumbnail/diagnostics output root |
| `--sample-hwp <path>` | `samples/basic/KTX.hwp` | HWP thumbnail smoke 입력 |
| `--sample-hwpx <path>` | `samples/hwpx/hwpx-01.hwpx` | HWPX thumbnail smoke 입력 |

script는 `$HOME/Applications/Alhangeul.app`만 교체한다. `RhwpMac.app`, `AlhangeulMac.app`, `알한글.app` 같은 이전 이름 설치본은 diagnostics와 warning에만 남기고 삭제하지 않는다.

실패 코드:

| code | 의미 |
|------|------|
| `0` | bundle 정합성, 시스템 등록, HWP/HWPX thumbnail smoke 통과 |
| `2` | 잘못된 option 또는 필수 도구/파일 없음 |
| `10` | package 생성 또는 bundle 정합성 실패 |
| `20` | 설치 경로 복사, LaunchServices 등록, PlugInKit add 실패 |
| `30` | PlugInKit 등록에서 Preview 또는 Thumbnail extension 미확인 |
| `40` | `qlmanage -t -x` 실패 또는 thumbnail output 미생성 |

## 문서 변경 요약

`build_run_guide.md`:

- 설치본 Quick Look/Thumbnail smoke의 기본 명령을 `scripts/smoke-finder-integration.sh --version 0.1.0`로 정리했다.
- staging app 재사용 명령을 `--skip-package --app build.noindex/release/Alhangeul.app`로 추가했다.
- helper가 수행하는 bundle 정합성, 설치/등록, PlugInKit 확인, HWP/HWPX thumbnail 생성, diagnostics 저장 항목을 명시했다.
- `qlmanage -p`는 preview 수동 확인으로 분리하고 HWP/HWPX sample을 모두 적었다.
- 손상/대용량 fallback thumbnail 입력은 #149 성격의 선택 smoke로 분리했다.

`release_distribution_guide.md`:

- Finder 통합 smoke test 기본 명령과 staging app 재사용 명령을 추가했다.
- 자동화 환경에서는 `qlmanage -t -x` 기준으로 판정하고, `qlmanage -p` preview는 수동 확인 결과로 기록한다고 정리했다.
- 기본 sample을 `samples/basic/KTX.hwp`, `samples/hwpx/hwpx-01.hwpx`로 명시했다.

`finder_integration_validation_pitfalls.md`:

- `com.postmelee.alhangeulmac`를 `com.postmelee.alhangeul` 기준으로 보정했다.
- `AlhangeulMac.app`, `AlhangeulMacPreview.appex` 진단 경로를 `Alhangeul.app`, `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex`로 보정했다.
- 이전 이름 설치본 후보에 `AlhangeulMac.app`을 명시해 과거 산출물 충돌을 감지할 수 있게 했다.
- #40 상세 기록은 `AlhangeulMac` 기준이던 과거 작업 기록으로 설명했다.

## preview 수동 확인 한계

`qlmanage -p`와 Finder Space preview는 GUI session, Quick Look cache, foreground 상태의 영향을 받는다. 따라서 Stage 3 helper script의 pass/fail 조건에는 넣지 않았고, Stage 4와 최종 보고서에서 다음 형식으로 수동 결과를 별도 기록한다.

| sample | 명령 | 기록할 내용 |
|--------|------|-------------|
| HWP | `qlmanage -p samples/basic/KTX.hwp` | preview 창 표시 여부, 첫 페이지 표시 여부, 오류 문구 |
| HWPX | `qlmanage -p samples/hwpx/hwpx-01.hwpx` | preview 창 표시 여부, 첫 페이지 표시 여부, 오류 문구 |

## 본문 변경 정도 / 본문 무손실 여부

운영 문서는 Finder 통합 smoke 절차와 troubleshooting 기준만 수정했다. 과거 단계 보고서와 과거 troubleshooting 상세 기록(`task_m050_40_quicklook_thumbnail_registration_validation.md`)은 원문 보존했다. README는 수정하지 않았다.

## 검증 결과

구현계획서 Stage 3 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과 요약:

```text
## local/task151
 M mydocs/manual/build_run_guide.md
 M mydocs/manual/release_distribution_guide.md
 M mydocs/troubleshootings/finder_integration_validation_pitfalls.md
?? scripts/smoke-finder-integration.sh
```

```bash
bash -n scripts/package-release.sh scripts/smoke-finder-integration.sh
```

결과: 통과.

```bash
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
```

결과:

```text
Sources/HostApp/Info.plist: OK
Sources/QLExtension/Info.plist: OK
Sources/ThumbnailExtension/Info.plist: OK
```

```bash
rg -n "smoke-finder-integration|Alhangeul.app|AlhangeulPreview.appex|AlhangeulThumbnail.appex|com\\.postmelee\\.alhangeul|qlmanage -t|qlmanage -p|pluginkit|lsregister|수동 확인" \
  README.md \
  mydocs/manual/build_run_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/troubleshootings/finder_integration_validation_pitfalls.md \
  scripts/smoke-finder-integration.sh
```

결과: 관련 키워드가 README 진입점, 운영 문서, troubleshooting, helper script에서 확인됐다.

추가 확인:

```bash
scripts/smoke-finder-integration.sh --help
```

결과: usage 출력 성공. 설치나 package 생성은 수행하지 않았다.

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- helper script는 Stage 4에서 처음 실제 설치/등록/thumbnail smoke로 검증된다.
- script가 `$HOME/Applications/Alhangeul.app`을 교체하므로 Stage 4 실행 전 승인 상태를 다시 확인해야 한다.
- `qlmanage -t -x`가 실패하면 content type routing, PlugInKit 등록, renderer fallback 중 어느 계층인지 Stage 4에서 분리해야 한다.
- `log show` diagnostics는 macOS 로그 보존 상태에 따라 충분하지 않을 수 있다.
- preview 시각 품질은 자동 gate가 아니라 수동 확인과 #146 known limitations로 이어진다.

## 다음 단계 영향

Stage 4에서는 `scripts/package-release.sh 0.1.0` 또는 helper script의 package 생성 경로를 통해 Release package staging app을 만들고, `$HOME/Applications/Alhangeul.app` 설치본 기준으로 smoke gate를 리허설한다.

Stage 4 실행 후보:

```bash
./scripts/package-release.sh 0.1.0
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
qlmanage -p samples/basic/KTX.hwp
qlmanage -p samples/hwpx/hwpx-01.hwpx
```

## 승인 요청

Stage 3 완료를 승인해주시면 Stage 4 `설치본 smoke gate 리허설`로 진행한다.
