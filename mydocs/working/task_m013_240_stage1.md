# Task M013 #240 Stage 1 완료 보고서

## 단계 목표

현재 문서와 smoke helper가 Finder Quick Look/Thumbnail extension registration hygiene를 어디까지 보장하는지 조사하고, #240의 남은 작업 gap을 정리한다.

## 조사 대상

| 구분 | 파일 |
|------|------|
| Agent 규칙 | `AGENTS.md` |
| 기여자 문서 | `CONTRIBUTING.md`, `.github/pull_request_template.md` |
| 매뉴얼 | `mydocs/manual/build_run_guide.md` |
| 트러블슈팅 | `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` |
| smoke helper | `scripts/smoke-clean-quicklook-install.sh`, `scripts/smoke-finder-integration.sh`, `scripts/smoke-sparkle-extension-refresh.sh` |

## 확인한 현재 방어선

### Agent/메인테이너 규칙

`AGENTS.md`에는 이미 다음 핵심 규칙이 있다.

- `.app`/`.appex` 산출물은 `build.noindex/` 아래에 둔다.
- Debug/테스트용 Quick Look/Thumbnail 등록은 표준 smoke 절차 안에서만 수행한다.
- 종료 시 개발 산출물 등록을 해제한다.

이는 에이전트와 메인테이너에게는 충분히 강한 entrypoint다. 다만 외부 기여자는 `AGENTS.md`를 반드시 읽는 흐름이 아니므로 `CONTRIBUTING.md`에도 같은 원칙을 짧게 노출해야 한다.

### 빌드/실행 매뉴얼

`build_run_guide.md`는 이미 Debug build와 Finder 통합 검증을 분리한다.

| 목적 | 현재 기준 |
|------|-----------|
| compile/link 확인 | Debug build |
| bundle resource 포함 확인 | Debug 또는 Release build |
| LaunchServices/PlugInKit/Quick Look 실행 확인 | Release package 산출물 |

또한 `CODE_SIGNING_ALLOWED=NO` Debug 산출물로 PlugInKit 등록 여부를 판정하지 않는다는 규칙, `build.noindex/`와 DerivedData 아래 개발 산출물이 LaunchServices에 등록될 수 있다는 설명, 표준 smoke helper가 개발 산출물 registration을 걷어낸다는 설명이 있다.

남은 gap은 다음과 같다.

- 외부 기여자가 바로 복사할 수 있는 PR 전 checklist 형태가 부족하다.
- 수동 등록을 했을 때의 cleanup-only 명령이 한 곳에 짧게 모여 있지 않다.
- 파일 삭제와 registration 해제의 영향 범위 구분은 있으나, 전역 `lsregister -kill -r`/`lsregister -delete`와 비교한 위험 설명이 더 필요하다.

### 트러블슈팅 문서

`finder_integration_validation_pitfalls.md`는 다음을 이미 다룬다.

- `qlmanage -m plugins`가 app extension 기반 Quick Look/Thumbnail 등록 상태를 직접 반영하지 않을 수 있음
- `pluginkit -mAvvv`와 실제 `qlmanage -t -x` 결과를 함께 봐야 함
- legacy `RhwpMac.app`, `AlhangeulMac.app`, `알한글.app` 처리 기준
- 현재 이름 개발 산출물이 `build.noindex/` 또는 Xcode DerivedData 아래에 남아 있을 때 registration 혼선이 생길 수 있음

남은 gap은 다음과 같다.

- “파일 삭제 없이 registration만 해제하는 cleanup-only 절차”가 표준 check helper와 직접 연결되어 있지 않다.
- legacy 후보 설명은 충분하지만 현재 이름 `Alhangeul.app` 개발 산출물 후보의 명령/판정/정리 절차는 더 구체화할 수 있다.
- `lsregister -u`, `pluginkit -r`, `qlmanage -r cache`와 전역 reset 명령의 차이를 더 명확히 써야 한다.

### smoke helper

`scripts/smoke-clean-quicklook-install.sh`는 가장 강한 방어선을 갖고 있다.

- `list_ephemeral_alhangeul_app_registrations`가 LaunchServices dump와 `build.noindex` 검색 결과에서 `Alhangeul.app` 후보를 수집한다.
- `unregister_ephemeral_alhangeul_app_registrations`가 `$ROOT/build.noindex/`와 `$HOME/Library/Developer/Xcode/DerivedData/` 후보만 unregister한다.
- unregister는 `pluginkit -r`와 `lsregister -u`이며 파일 삭제는 하지 않는다.
- smoke 설치본의 active provider path를 `pluginkit -mAvvv -i ...`로 확인한다.

`scripts/smoke-finder-integration.sh`는 legacy app 방어선이 있다.

- legacy app/plugin 후보를 diagnostics로 수집한다.
- 기본값에서는 legacy 후보가 있으면 실패한다.
- `--unregister-legacy-candidates`는 파일을 삭제하지 않고 `pluginkit -r`, `lsregister -u`만 수행한다.

다만 `scripts/smoke-finder-integration.sh`는 현재 이름 개발 산출물 registration cleanup을 직접 수행하지 않는다. 반면 `build_run_guide.md`의 표준 smoke helper 설명은 개발/테스트용 registration 해제를 수행한다고 일반화되어 있어 helper별 실제 coverage와 문서가 약간 어긋난다.

`scripts/smoke-sparkle-extension-refresh.sh`는 post-update active provider 검증에는 강하다.

- expected app 내부 Preview/Thumbnail `.appex` path인지 확인한다.
- legacy provider가 남아 있으면 실패한다.
- `--repair-registration`은 release gate가 아닌 triage mode로 분리되어 있다.

다만 이 helper도 독립적인 “개발 산출물 registration hygiene check” 용도는 아니다. active provider가 설치본이면 통과하지만, 비활성 또는 stale 개발 등록 후보를 별도로 요약해 주지는 않는다.

## 주요 gap

| 우선순위 | gap | 영향 | 후속 단계 |
|----------|-----|------|-----------|
| 높음 | `CONTRIBUTING.md`에 Debug app과 Finder extension 검증의 경계가 없음 | 외부 기여자가 Debug app으로 thumbnail/Quick Look 등록 성공을 판정할 수 있음 | Stage 2 |
| 높음 | `.github/pull_request_template.md` 검증 섹션에 Finder/Quick Look/Thumbnail registration hygiene checklist가 없음 | PR 본문에서 개발 산출물 registration cleanup 여부가 누락될 수 있음 | Stage 2 |
| 높음 | 독립 실행 가능한 check-only helper가 없음 | smoke 전체 재설치 없이 현재 환경의 stale 개발 등록만 확인하기 어려움 | Stage 3 |
| 중간 | `smoke-finder-integration.sh`와 `smoke-clean-quicklook-install.sh`의 개발 산출물 cleanup coverage가 다름 | “표준 helper가 정리한다”는 문서가 helper별 실제 동작과 어긋날 수 있음 | Stage 2/3 |
| 중간 | troubleshooting 문서의 cleanup-only 절차가 전역 reset과 명확히 분리되어 있지 않음 | 기여자가 과도한 LaunchServices reset이나 파일 삭제를 선택할 수 있음 | Stage 2 |
| 낮음 | `smoke-sparkle-extension-refresh.sh`는 stale 개발 등록 후보를 별도 요약하지 않음 | post-update smoke에는 충분하지만 환경 hygiene 점검 도구로는 부족 | Stage 3 |

## Stage 2 권장 변경

- `CONTRIBUTING.md`의 PR 전 체크리스트 아래에 Finder/Quick Look/Thumbnail 변경 전용 checklist를 추가한다.
- `.github/pull_request_template.md`의 검증 섹션에 Finder integration 변경 시 적을 항목을 추가한다.
- `build_run_guide.md`에서 “표준 smoke helper” 설명을 helper별 책임으로 나눈다.
- `finder_integration_validation_pitfalls.md`에 현재 이름 개발 산출물 registration cleanup-only 절차와 전역 reset 금지/주의를 추가한다.

## Stage 3 권장 변경

새 helper는 기존 smoke helper를 대체하지 않고 사전/사후 점검 도구로 둔다.

권장 이름:

```text
scripts/check-extension-registration-hygiene.sh
```

권장 모드:

- `--check-only`: 기본값. 현재 LaunchServices/PlugInKit registration 후보를 diagnostics로 출력하고 stale 개발 registration이 있으면 non-zero로 종료한다.
- `--cleanup-dev-registrations`: 파일 삭제 없이 `build.noindex/`와 Xcode DerivedData 아래 현재 이름 `Alhangeul.app` registration만 해제한다.
- `--allow-installed-app PATH`: expected install app을 명시해 active provider path 판정에 사용한다.

금지 사항:

- 사용자 app bundle 삭제 금지
- legacy app 파일 삭제 금지
- 전역 `lsregister -kill -r`, `lsregister -delete` 자동 실행 금지
- Finder kill/restart 자동 실행 금지

## 검증

실행한 명령:

```bash
rg -n "Debug|PlugInKit|LaunchServices|lsregister|qlmanage|build\\.noindex|DerivedData|extension 등록|확장 등록" AGENTS.md CONTRIBUTING.md mydocs/manual/build_run_guide.md mydocs/troubleshootings/finder_integration_validation_pitfalls.md scripts
sed -n '1,260p' scripts/smoke-clean-quicklook-install.sh
sed -n '260,620p' scripts/smoke-clean-quicklook-install.sh
sed -n '1,260p' scripts/smoke-finder-integration.sh
sed -n '260,520p' scripts/smoke-finder-integration.sh
sed -n '1,460p' scripts/smoke-sparkle-extension-refresh.sh
sed -n '1,230p' CONTRIBUTING.md
sed -n '1,220p' .github/pull_request_template.md
sed -n '212,416p' mydocs/manual/build_run_guide.md
sed -n '1,120p' AGENTS.md
rg -n "unregister_ephemeral|list_ephemeral|legacy|DerivedData|build\\.noindex|pluginkit -r|lsregister.*-u|qlmanage -r cache|killall" scripts/smoke-clean-quicklook-install.sh scripts/smoke-finder-integration.sh scripts/smoke-sparkle-extension-refresh.sh
```

추가 검증:

```bash
git diff --check
```

## 결론

Stage 1 결과, 제품 코드 변경은 필요하지 않다. 재발 방지는 contributor-facing 문서 보강과 독립적인 registration hygiene helper 추가로 해결하는 것이 적절하다. Stage 2에서는 문서 gap을 먼저 닫고, Stage 3에서 helper를 추가해 문서의 checklist를 실행 가능한 도구와 연결한다.
