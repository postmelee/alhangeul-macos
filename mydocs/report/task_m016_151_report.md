# Task #151 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#151 Quick Look/Thumbnail 설치본 smoke gate 정리](https://github.com/postmelee/alhangeul-macos/issues/151) |
| 마일스톤 | M016 / v0.1 출시 전 보강 |
| 기준 브랜치 | `devel-webview` |
| 작업 브랜치 | `local/task151` |
| 단계 수 | 5단계 |
| 결론 | Finder Quick Look/Thumbnail 설치본 smoke gate를 Release package staging app 기준으로 정리했다. 자동 gate는 bundle 정합성, LaunchServices/PlugInKit 등록, HWP/HWPX `qlmanage -t -x` thumbnail smoke까지로 고정하고, `qlmanage -p`/Finder Space preview는 수동 확인 항목으로 분리했다. |

## 최종 산출물

| 파일 | 내용 |
|------|------|
| `scripts/smoke-finder-integration.sh` | Release package 생성/재사용, 설치, 등록, HWP/HWPX thumbnail smoke, diagnostics 수집 helper |
| `mydocs/manual/build_run_guide.md` | Finder 통합 확인 표준 흐름을 helper script 중심으로 정리 |
| `mydocs/manual/release_distribution_guide.md` | release pipeline smoke 기준을 Release package + helper script 기준으로 연결 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 현재 `Alhangeul` product 기준의 registration/legacy 후보 처리 기준 보정 |
| `mydocs/plans/task_m016_151.md` | 수행계획서 |
| `mydocs/plans/task_m016_151_impl.md` | 구현계획서 |
| `mydocs/working/task_m016_151_stage1.md` | 현행 smoke 절차 inventory |
| `mydocs/working/task_m016_151_stage2.md` | smoke gate 판정 기준 설계 |
| `mydocs/working/task_m016_151_stage3.md` | 문서와 helper script 보강 보고 |
| `mydocs/working/task_m016_151_stage4.md` | 설치본 smoke gate 리허설 보고 |
| `mydocs/report/task_m016_151_report.md` | 최종 보고서 |
| `mydocs/orders/20260508.md` | #151 완료 처리 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 계획 | `771b0ba` | 수행계획서와 오늘할일 등록 |
| 구현계획 | `fba672e` | 5단계 구현계획 확정 |
| Stage 1 | `bc0ae2c` | 현행 문서, package script, app/appex identifier, sample inventory 정리 |
| Stage 2 | `9e13086` | bundle 정합성, 시스템 등록, thumbnail 자동 smoke, preview 수동 확인, diagnostics 계층 설계 |
| Stage 3 | `69cb5bc` | `scripts/smoke-finder-integration.sh` 추가와 운영 문서 보강 |
| Stage 4 | `e139348` | Release package 설치본 smoke 리허설, legacy provider false positive 차단 보정 |
| Stage 5 | 이번 최종 보고 커밋 | 최종 보고서와 오늘할일 완료 처리 |

## 표준 smoke gate

기본 실행:

```bash
scripts/smoke-finder-integration.sh --version 0.1.0
```

이미 만든 Release package staging app 재사용:

```bash
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
```

이전 이름 설치본 후보가 남아 smoke 결과 오염이 의심되는 경우:

```bash
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app --unregister-legacy-candidates
```

`--unregister-legacy-candidates`는 `RhwpMac.app`, `AlhangeulMac.app`, `알한글.app` 후보 파일을 삭제하지 않는다. LaunchServices/PlugInKit 등록만 해제해 `qlmanage`가 현재 `Alhangeul.app` provider를 쓰는지 분리한다. 실제 파일 제거는 별도 작업지시자 승인 후에만 수행한다.

## pass/fail 기준

| 계층 | 자동 판정 | 기준 |
|------|-----------|------|
| bundle 정합성 | 예 | `Alhangeul.app`, `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex`, bundle id, principal class, localized strings, `codesign --verify --deep --strict` |
| 시스템 등록 | 예 | `$HOME/Applications/Alhangeul.app` 설치, `lsregister`, `pluginkit -a`, `pluginkit -mAvvv`에서 current Preview/Thumbnail extension 확인 |
| legacy 후보 | 예 | 기본값에서는 이전 이름 후보 발견 시 exit code `30` 실패. 명시 옵션에서만 등록 격리 |
| thumbnail smoke | 예 | `samples/basic/KTX.hwp`, `samples/hwpx/hwpx-01.hwpx` 각각 `qlmanage -t -x` exit code 0과 output 파일 생성 |
| preview 확인 | 아니오 | `qlmanage -p`와 Finder Space preview는 GUI/user session/cache 영향으로 수동 확인 항목 |

실패 코드:

| code | 의미 |
|------|------|
| `0` | bundle 정합성, 등록, HWP/HWPX thumbnail smoke 통과 |
| `2` | 잘못된 option 또는 필수 도구/파일 없음 |
| `10` | package 생성 또는 bundle 정합성 실패 |
| `20` | 표준 설치 경로 복사, LaunchServices 등록, PlugInKit add 실패 |
| `30` | PlugInKit 등록 미확인 또는 legacy 후보로 인한 false positive 위험 |
| `40` | `qlmanage -t -x` 실패 또는 thumbnail output 미생성 |

## 리허설 결과

Stage 4에서 `./scripts/package-release.sh 0.1.0`으로 Release package를 생성했다.

| 항목 | 결과 |
|------|------|
| Release build | `** BUILD SUCCEEDED **` |
| staging app | `build.noindex/release/Alhangeul.app` |
| zip | `build.noindex/release/alhangeul-macos-0.1.0.zip` |
| zip sha256 | `d9bbd8f601fbacb7ddd622dd3822933e7a70ce177b6c9e5edb3c4f2281029a31` |
| zip size | 57 MB |
| codesign verify | 통과 |

처음 warning-only gate는 thumbnail 생성까지 통과했지만 Quick Look 로그에 `com.postmelee.alhangeulmac.ThumbnailExtension` 실행 흔적이 같이 남았다. 따라서 legacy provider가 남은 환경에서 `qlmanage -t -x` 성공만으로 current 설치본 smoke 통과를 판단할 수 없다고 결론냈다.

보정 후 기본 gate는 legacy 후보를 발견하고 의도대로 실패했다.

```text
exit code 30
legacy candidates can make qlmanage use an older Quick Look provider
Diagnostics: /tmp/alhangeul-ql/task151-20260508-152041/diagnostics
```

등록 격리 옵션을 붙인 current 설치본 smoke는 통과했다.

| 항목 | 결과 |
|------|------|
| 명령 | `scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app --unregister-legacy-candidates` |
| exit code | 0 |
| 설치 경로 | `/Users/melee/Applications/Alhangeul.app` |
| output directory | `/tmp/alhangeul-ql/task151-20260508-152126` |
| diagnostics directory | `/tmp/alhangeul-ql/task151-20260508-152126/diagnostics` |
| HWP thumbnail | `/tmp/alhangeul-ql/task151-20260508-152126/hwp/KTX.hwp.png`, PNG 512 x 363 |
| HWPX thumbnail | `/tmp/alhangeul-ql/task151-20260508-152126/hwpx/hwpx-01.hwpx.png`, PNG 363 x 512 |
| PlugInKit current extension | `com.postmelee.alhangeul.QLExtension`, `com.postmelee.alhangeul.ThumbnailExtension` 확인 |

Stage 4 diagnostics 기준으로 legacy app 후보 10개와 legacy appex 후보 2개가 보고됐다. 파일은 삭제하지 않았고, smoke 격리를 위해 등록만 해제했다.

## diagnostics 경로

helper script는 실행마다 `/tmp/alhangeul-ql/task151-YYYYMMDD-HHMMSS/diagnostics` 아래에 진단 자료를 남긴다.

| 파일 | 내용 |
|------|------|
| `pluginkit.txt` | PlugInKit 등록 상태 |
| `lsregister-alhangeul.txt` | LaunchServices의 `Alhangeul` 관련 등록 상태 |
| `codesign-app.txt` | signing 상세 |
| `codesign-verify.txt` | 설치본 codesign verify 결과 |
| `codesign-verify-input-app.txt` | 입력 staging app codesign verify 결과 |
| `app-info.plist.txt` | Host app plist |
| `preview-info.plist.txt` | Preview appex plist |
| `thumbnail-info.plist.txt` | Thumbnail appex plist |
| `qlmanage-hwp.log` | HWP thumbnail smoke 로그 |
| `qlmanage-hwpx.log` | HWPX thumbnail smoke 로그 |
| `old-install-candidates.txt` | legacy 후보 원시 목록 |
| `old-install-apps.txt` | legacy app path 목록 |
| `old-install-plugins.txt` | legacy appex path 목록 |
| `unregister-legacy.log` | 등록 격리 실행 로그 |
| `quicklook-last10m.log` | best-effort unified log snapshot |

## 수동 확인과 미실행 범위

`qlmanage -p`와 Finder Space preview는 자동 gate에 포함하지 않았다. 이번 task의 설치본 자동 gate는 HWP/HWPX thumbnail smoke까지 통과했다.

수동 확인 후보:

```bash
qlmanage -p samples/basic/KTX.hwp
qlmanage -p samples/hwpx/hwpx-01.hwpx
```

미실행 범위:

| 항목 | 이유 |
|------|------|
| `qlmanage -p` 자동 판정 | GUI foreground 확인이 필요해 자동 pass/fail로 고정하지 않음 |
| Finder Space preview | 사용자 조작과 Finder 상태 의존 |
| Developer ID signing/notarization | #151 범위 밖, #148 release policy와 실제 release 실행 시점으로 분리 |
| public DMG Gatekeeper 검증 | notarized public DMG 산출 후 수행 |
| native renderer 시각 품질 검증 | #146 known limitations와 후속 renderer 개선 범위 |
| 손상/대용량 fallback 구현 변경 | #149 범위 |

## release gate 연결

v0.1 release 전에 연결할 항목:

| 항목 | 연결 대상 |
|------|-----------|
| 개발/검증용 Release package smoke | `scripts/smoke-finder-integration.sh --version 0.1.0` |
| staging app 재사용 smoke | `scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app` |
| legacy 후보가 있는 로컬 환경 smoke | 작업지시자 승인 후 `--unregister-legacy-candidates` |
| public 배포 artifact smoke | Developer ID signed + notarized DMG 생성 후 별도 Gatekeeper 검증 |
| release note | HWP/HWPX thumbnail smoke 통과, preview 수동 확인 필요성, legacy 후보 처리 기준 |
| #146 known limitations | 자동 thumbnail gate 통과와 preview/renderer 시각 품질 보장은 별도라는 점 명시 |

## 검증 결과

Stage 5에서 최종 문서 검증을 실행했다.

```bash
git status --short --branch
rg -n "#151|Quick Look|Thumbnail|smoke-finder-integration|qlmanage|pluginkit|수동 확인|known limitation|완료" \
  mydocs/report/task_m016_151_report.md mydocs/orders/20260508.md
git diff --check
```

결과:

- 최종 보고서와 오늘할일에서 #151, Quick Look/Thumbnail, helper script, `qlmanage`, `pluginkit`, 수동 확인, known limitation, 완료 상태 확인
- whitespace check 통과

## 완료 판단

#151의 수용 기준은 충족했다.

- Release package staging app 기준으로 설치본 smoke gate가 문서와 helper script에 반영됐다.
- 자동 gate와 수동 preview 확인의 경계가 명확해졌다.
- 대표 HWP/HWPX sample의 thumbnail smoke 결과가 기록됐다.
- legacy provider가 current 설치본 smoke를 오염시키는 false positive 조건을 발견하고 기본 실패로 차단했다.
- 실패 시 diagnostics 수집 경로와 legacy 후보 처리 원칙이 문서화됐다.

## 작업지시자 승인 요청

Task #151의 Quick Look/Thumbnail 설치본 smoke gate 정리를 완료했다. 다음 단계는 `publish/task151` 브랜치 push와 `devel-webview` 대상 PR 생성 승인이다.

