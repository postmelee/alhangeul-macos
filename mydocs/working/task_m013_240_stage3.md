# Task M013 #240 Stage 3 완료 보고서

## 단계 목표

Stage 2에서 문서화한 Finder Quick Look/Thumbnail registration hygiene 규칙을 실제로 확인할 수 있는 독립 helper를 추가한다. 기본 동작은 check-only이며, cleanup은 작업자가 명시 옵션을 준 경우에만 파일 삭제 없이 개발 산출물 registration 해제 범위로 제한한다.

## 변경 요약

| 파일 | 변경 |
|------|------|
| `scripts/check-extension-registration-hygiene.sh` | LaunchServices/PlugInKit registration 상태를 점검하는 check-only helper 추가 |
| `CONTRIBUTING.md` | Finder Quick Look/Thumbnail PR 전 `check-extension-registration-hygiene.sh --check-only` 실행 원칙 추가 |
| `.github/pull_request_template.md` | PR 검증 checklist에 registration hygiene helper 결과 확인 항목 추가 |
| `mydocs/manual/build_run_guide.md` | helper 사용법과 cleanup 제한 범위 추가 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | helper 선택 기준 표에 check-only/cleanup-dev 모드 추가 |

## helper 동작

`scripts/check-extension-registration-hygiene.sh`는 다음 항목을 diagnostics로 남긴다.

- 기대 설치 위치: `$HOME/Applications/Alhangeul.app`, `/Applications/Alhangeul.app`, 필요 시 `--allow-installed-app`
- LaunchServices에 등록된 `Alhangeul.app` 후보
- `build.noindex/` 또는 Xcode DerivedData 아래 개발/테스트 앱 registration
- PlugInKit Preview/Thumbnail provider path와 provider app root
- legacy `RhwpMac.app`, `AlhangeulMac.app`, `알한글.app` 및 legacy extension 후보

기본 `--check-only`는 로컬 상태를 바꾸지 않는다. 문제가 있으면 non-zero로 종료하고 diagnostics 경로를 출력한다.

명시 cleanup 옵션은 다음 범위만 수행한다.

```bash
scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations
```

- 대상: 현재 저장소 `build.noindex/` 및 Xcode DerivedData 아래 `Alhangeul.app`
- 동작: 후보 `.appex`에 `pluginkit -r`, app에 `lsregister -u`, 마지막에 `qlmanage -r cache`
- 하지 않는 일: app bundle 삭제, legacy app 삭제, `/Applications`/`$HOME/Applications` 설치본 삭제, `lsregister -kill -r`, `lsregister -delete`, Finder/QuickLook daemon kill

## 검증

실행한 명령:

```bash
bash -n scripts/check-extension-registration-hygiene.sh
scripts/check-extension-registration-hygiene.sh --help
scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
```

결과:

- shell 문법 검사 통과
- help 출력 정상
- `--check-only` 실행 성공
- `git diff --check` 통과

`--check-only` diagnostics:

```text
/private/tmp/alhangeul-extension-registration-hygiene/20260513-162841
```

현재 로컬 상태에서는 개발 산출물 registration, legacy app 후보, legacy extension 후보가 없었다. 설치된 provider path도 없어서 Preview/Thumbnail provider path 미보고 warning만 남았다. 등록 오염이 없는 상태였기 때문에 cleanup 옵션은 실행하지 않았다.

## 수용 기준 진행 상황

| 수용 기준 | Stage 3 결과 |
|-----------|--------------|
| 표준 smoke 또는 별도 helper가 개발 산출물 등록 잔존 여부를 확인하거나 정리한다 | `check-extension-registration-hygiene.sh --check-only`와 `--cleanup-dev-registrations` 추가로 충족 |
| cleanup은 파일 삭제와 전역 reset 없이 registration/cache 범위에 머무른다 | 코드와 문서에 `pluginkit -r`, `lsregister -u`, `qlmanage -r cache` 범위로 제한 |
| 기여자 문서와 PR checklist에서 helper를 찾을 수 있다 | `CONTRIBUTING.md`, PR 템플릿, build/run guide, troubleshooting에 연결 |
| Debug app을 Finder extension 등록 성공 기준으로 쓰지 않는다 | Stage 2 문서 규칙을 helper 실행 항목과 연결 |

## 다음 단계

Stage 4에서는 Stage 1-3 결과를 종합 검증하고 최종 보고서를 작성한다. PR 게시 전에는 helper 문법, 문서 검색, 작업트리 상태를 다시 확인한다.
