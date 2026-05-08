# Task M016 #151 Stage 4 보고서

## 단계 목적

Release package staging app을 실제 설치 경로에 배치하고 Stage 3에서 추가한 Finder 통합 smoke gate가 설치본 기준으로 작동하는지 리허설한다. 자동 thumbnail smoke와 preview 수동 확인 가능성은 별도 결과로 기록한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `scripts/smoke-finder-integration.sh` | 레거시 설치본 후보가 있는 환경에서 false positive를 막도록 기본 실패 처리와 `--unregister-legacy-candidates` 옵션 추가 |
| `mydocs/manual/build_run_guide.md` | 레거시 후보 발견 시 기본 실패와 등록 격리 옵션 설명 추가 |
| `mydocs/manual/release_distribution_guide.md` | release smoke에서 레거시 후보 처리 기준 보강 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | 이전 이름 설치본이 `qlmanage` 결과를 오염시킬 수 있음을 명시 |
| `mydocs/working/task_m016_151_stage4.md` | 설치본 smoke gate 리허설 결과 |

## 리허설 요약

`./scripts/package-release.sh 0.1.0`은 성공했다. Xcode Release build는 `** BUILD SUCCEEDED **`로 종료됐고, `build.noindex/release/Alhangeul.app`과 zip 산출물 `build.noindex/release/alhangeul-macos-0.1.0.zip`이 생성됐다.

zip checksum:

```text
d9bbd8f601fbacb7ddd622dd3822933e7a70ce177b6c9e5edb3c4f2281029a31  build.noindex/release/alhangeul-macos-0.1.0.zip
```

산출물 구조와 signing 확인:

| 항목 | 결과 |
|------|------|
| `build.noindex/release/Alhangeul.app` | 존재 |
| `AlhangeulPreview.appex` | 존재 |
| `AlhangeulThumbnail.appex` | 존재 |
| zip size | 57 MB |
| `codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app` | 통과 |

## 발견한 gate 오염 가능성

처음 실행한 warning-only helper는 `/tmp/alhangeul-ql/task151-20260508-151620`에서 thumbnail 생성까지 통과했다. 하지만 diagnostics의 Quick Look 로그에 `com.postmelee.alhangeulmac.ThumbnailExtension` 실행 흔적이 함께 잡혔다. 즉, 기존 `AlhangeulMac.app` provider가 남아 있으면 `qlmanage -t -x` 성공만으로는 현재 설치본이 렌더링했다고 증명할 수 없다.

이에 따라 helper를 보정했다.

- 기본값: `RhwpMac.app`, `AlhangeulMac.app`, `알한글.app` 후보가 발견되면 exit code `30`으로 실패
- 명시 옵션: `--unregister-legacy-candidates` 지정 시 파일은 삭제하지 않고 LaunchServices/PlugInKit 등록만 해제한 뒤 smoke 계속 진행
- diagnostics: `old-install-apps.txt`, `old-install-plugins.txt`, `unregister-legacy.log` 추가

보정 후 기본 gate 확인:

```text
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
```

결과는 의도한 실패였다.

```text
exit code 30
legacy candidates can make qlmanage use an older Quick Look provider
Diagnostics: /tmp/alhangeul-ql/task151-20260508-152041/diagnostics
```

## 설치본 smoke 결과

등록 격리 옵션을 붙여 현재 설치본 기준 smoke를 다시 실행했다.

```text
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app --unregister-legacy-candidates
```

결과:

| 항목 | 결과 |
|------|------|
| exit code | 0 |
| 설치 경로 | `/Users/melee/Applications/Alhangeul.app` |
| output directory | `/tmp/alhangeul-ql/task151-20260508-152126` |
| diagnostics directory | `/tmp/alhangeul-ql/task151-20260508-152126/diagnostics` |
| HWP sample | `samples/basic/KTX.hwp` thumbnail 1개 생성 |
| HWPX sample | `samples/hwpx/hwpx-01.hwpx` thumbnail 1개 생성 |

생성된 thumbnail:

| 파일 | 결과 |
|------|------|
| `/tmp/alhangeul-ql/task151-20260508-152126/hwp/KTX.hwp.png` | PNG, 512 x 363, RGBA |
| `/tmp/alhangeul-ql/task151-20260508-152126/hwpx/hwpx-01.hwpx.png` | PNG, 363 x 512, RGBA |

PlugInKit diagnostics에서 현재 extension만 확인됐다.

```text
com.postmelee.alhangeul.QLExtension(0.1.0)
com.postmelee.alhangeul.ThumbnailExtension(0.1.0)
```

`com.postmelee.alhangeulmac.QLExtension`과 `com.postmelee.alhangeulmac.ThumbnailExtension`은 보정 후 `pluginkit.txt`에 남지 않았다. Quick Look 로그에서도 `com.postmelee.alhangeul.ThumbnailExtension` launch가 확인됐다.

레거시 파일은 삭제하지 않았다. diagnostics 기준으로 app 후보 10개와 appex 후보 2개가 보고됐고, `--unregister-legacy-candidates`는 해당 후보의 LaunchServices/PlugInKit 등록만 해제했다.

## preview 수동 확인

`qlmanage -p`와 Finder Space preview는 GUI foreground 상태와 사용자 확인이 필요한 수동 항목이므로 이번 자동 gate pass/fail에는 포함하지 않았다. helper는 다음 수동 확인 후보를 출력했다.

```bash
qlmanage -p /Users/melee/Documents/projects/rhwp-mac/samples/basic/KTX.hwp
qlmanage -p /Users/melee/Documents/projects/rhwp-mac/samples/hwpx/hwpx-01.hwpx
```

Stage 4 자동 gate 결과와 preview 수동 확인 결과는 별도 판정으로 유지한다.

## 검증 결과

구현계획서 Stage 4 검증과 보정 후 추가 검증을 실행했다.

```bash
./scripts/package-release.sh 0.1.0
codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app
scripts/smoke-finder-integration.sh --skip-package --app build.noindex/release/Alhangeul.app --unregister-legacy-candidates
bash -n scripts/package-release.sh scripts/smoke-finder-integration.sh
plutil -lint Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
scripts/smoke-finder-integration.sh --help
git diff --check
```

결과:

- Release package 생성 성공
- app/Preview appex/Thumbnail appex 존재 확인
- Release app codesign 검증 통과
- 레거시 후보가 있는 기본 gate는 의도대로 exit code `30` 실패
- `--unregister-legacy-candidates`를 붙인 설치본 smoke는 통과
- HWP/HWPX thumbnail output 생성 확인
- script syntax check 통과
- plist lint 통과
- 문서/스크립트 검색 확인 통과
- whitespace check 통과

## 본문 변경 정도 / 본문 무손실 여부

Stage 4에서 운영 문서와 helper script에 레거시 후보 처리 기준을 추가했다. 기존 문서 본문은 삭제하지 않고, 설치본 smoke gate가 false positive를 만들 수 있는 조건과 등록 격리 옵션을 필요한 위치에 보강했다. 과거 보고서 원문은 수정하지 않았다.

