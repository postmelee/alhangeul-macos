# Task M013 #240 Stage 2 완료 보고서

## 단계 목표

Stage 1에서 확인한 문서 gap을 닫기 위해 외부 기여자 문서, PR 템플릿, 빌드/실행 매뉴얼, Finder 통합 troubleshooting 문서에 extension registration hygiene 규칙을 보강한다.

## 변경 요약

| 파일 | 변경 |
|------|------|
| `CONTRIBUTING.md` | Finder Quick Look/Thumbnail 변경 PR에서 Debug app으로 extension 등록 성공을 판정하지 말라는 규칙과 smoke 전후 active provider path 확인 원칙 추가 |
| `.github/pull_request_template.md` | Finder/Quick Look/Thumbnail extension 관련 변경 시 PR 검증 섹션에서 유지해야 할 checklist 항목 추가 |
| `mydocs/manual/build_run_guide.md` | Debug app 실행과 Finder 통합 검증의 경계, 표준 smoke helper별 책임, 반복 시행착오 방지 규칙 보강 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | cleanup-only 기준, 수동 registration 해제 예시, 전역 reset 주의, helper 선택 기준 추가 |

## 세부 내용

### 외부 기여자 입구 보강

`CONTRIBUTING.md`의 PR 전 체크리스트에 Finder Quick Look/Thumbnail 변경 전용 원칙을 추가했다.

- Debug app은 앱 실행과 WKWebView viewer 확인용으로만 쓴다.
- Finder Quick Look/Thumbnail 검증은 Release package 또는 표준 smoke helper 설치본 기준으로 수행한다.
- 수동 `lsregister`/`pluginkit` 등록을 했다면 같은 검증 안에서 unregister와 `qlmanage -r cache`를 수행하고 PR 본문에 적는다.
- `build.noindex/` 또는 Xcode DerivedData 아래 개발 앱 registration이 남으면 active provider path를 흐릴 수 있음을 명시했다.

또한 Finder/Quick Look debugging 섹션에서 `qlmanage` 결과만으로 현재 PR의 extension이 실행됐다고 판단하지 않도록 하고, `pluginkit -mAvvv` active provider path와 troubleshooting 문서를 함께 보도록 연결했다.

### PR 템플릿 보강

`.github/pull_request_template.md`의 검증 섹션에 Finder/Quick Look/Thumbnail 변경 시 유지해야 할 checklist를 추가했다.

- Debug app이 아니라 Release package 또는 표준 smoke helper 설치본으로 확인했는지
- `pluginkit -mAvvv` active provider path가 기대 설치본 내부인지
- `build.noindex/` 또는 Xcode DerivedData 개발 산출물 registration이 남지 않았는지
- 수동 등록을 했다면 unregister와 `qlmanage -r cache`까지 수행했는지

### 매뉴얼 보강

`build_run_guide.md`에서 Debug app을 여는 행위와 Xcode build가 LaunchServices registration을 만들 수 있음을 명시했다. 이 registration은 앱 실행 smoke에는 무해할 수 있지만 Finder Quick Look/Thumbnail 판정에는 환경 오염이므로 설치본 active provider path와 개발 산출물 registration 잔존 여부를 따로 확인해야 한다.

표준 smoke helper 설명은 helper별 실제 책임으로 나눴다.

- `scripts/smoke-clean-quicklook-install.sh`: 개발/테스트용 `Alhangeul.app` registration 해제를 포함
- `scripts/smoke-finder-integration.sh`: legacy 후보 방어와 `$HOME/Applications/Alhangeul.app` 기준 smoke에 집중

반복 시행착오 방지 규칙에는 System Settings 확장 목록, Finder 아이콘, `qlmanage -m plugins`를 단독 판정 근거로 쓰지 말 것과 전역 LaunchServices reset을 일반 contributor 검증 절차로 쓰지 말 것을 추가했다.

### troubleshooting 보강

`finder_integration_validation_pitfalls.md`에 cleanup-only 기준을 추가했다.

- cleanup-only 대상은 현재 저장소의 `build.noindex/` 또는 Xcode DerivedData 아래 `Alhangeul.app`과 그 `.appex`로 제한
- `pluginkit -r`, `lsregister -u`, `qlmanage -r cache`는 registration/cache 범위 정리이며 파일 삭제가 아님
- `/Applications`, `$HOME/Applications`, legacy app 파일 삭제는 cleanup-only가 아님
- `lsregister -kill -r -domain user`, `lsregister -delete`, 재부팅, Finder/daemon kill은 일반 smoke 절차가 아니며 영향 범위를 기록해야 함

또한 helper 선택 기준 표를 추가해 `smoke-clean-quicklook-install.sh`, `smoke-finder-integration.sh`, `smoke-sparkle-extension-refresh.sh`의 역할을 분리했다.

## 검증

실행한 명령:

```bash
git diff --check
rg -n "Debug app|Release package|smoke helper|LaunchServices|PlugInKit|qlmanage -m plugins|cleanup-only|전역" CONTRIBUTING.md .github/pull_request_template.md mydocs/manual/build_run_guide.md mydocs/troubleshootings/finder_integration_validation_pitfalls.md
```

결과:

- `git diff --check` 통과
- contributor 문서, PR 템플릿, build/run 매뉴얼, troubleshooting 문서에서 핵심 문구 검색 확인

## 수용 기준 진행 상황

| 수용 기준 | Stage 2 결과 |
|-----------|--------------|
| `CONTRIBUTING.md`만 읽어도 Debug app으로 Finder extension 등록 성공을 판정하면 안 된다는 점을 알 수 있다 | 충족 |
| `build_run_guide.md`에 Debug build, release package, smoke helper의 역할이 표로 정리되어 있다 | 기존 표를 유지하고 helper별 책임을 보강 |
| `finder_integration_validation_pitfalls.md`에 중복 등록 확인 명령과 cleanup-only 절차가 정리되어 있다 | cleanup-only 기준과 수동 예시 추가 |
| 표준 smoke 또는 별도 helper가 개발 산출물 등록 잔존 여부를 확인하거나 정리한다 | Stage 3 helper에서 완료 예정 |
| 문서에는 파일 삭제와 전역 LaunchServices reset의 영향 범위가 명확히 구분되어 있다 | 충족 |

## 다음 단계

Stage 3에서는 문서 checklist와 연결되는 `scripts/check-extension-registration-hygiene.sh`를 추가한다. 이 helper는 기본 check-only 모드와 명시 cleanup 옵션을 제공하고, 파일 삭제와 전역 LaunchServices reset은 수행하지 않는다.
