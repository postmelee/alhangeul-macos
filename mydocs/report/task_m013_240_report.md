# Task M013 #240 최종 보고서

## 작업 요약

- 이슈: #240 Finder 확장 등록 중복 방지와 Debug 빌드 검증 규칙 문서화
- 마일스톤: M013 (`하이퍼-워터폴 작업환경 조성`)
- 브랜치: `local/task240`
- 기준 브랜치: `devel-webview`
- 목적: Finder Quick Look/Thumbnail 검증 중 Debug/테스트 앱 registration이 LaunchServices/PlugInKit에 누적되는 문제를 기여자 문서, 매뉴얼, troubleshooting, check-only helper로 예방한다.

## 결과

Debug app과 Finder Quick Look/Thumbnail extension 검증의 경계를 문서와 도구에 고정했다.

- Debug app은 앱 실행과 WKWebView viewer smoke용으로만 사용한다.
- Finder Quick Look/Thumbnail 검증은 Release package 또는 표준 smoke helper 설치본 기준으로 수행한다.
- `build.noindex/`와 Xcode DerivedData 아래 개발 산출물 registration은 Finder routing을 흐릴 수 있으므로 check-only helper로 확인한다.
- cleanup은 명시 옵션에서만 수행하고, 파일 삭제나 전역 LaunchServices reset 없이 app/appex 단위 unregister와 Quick Look cache reset 범위로 제한한다.

## 주요 변경 파일

| 파일 | 내용 |
|------|------|
| `CONTRIBUTING.md` | Finder Quick Look/Thumbnail 변경 PR 전 Debug app 사용 금지, Release package 기준 검증, hygiene helper 실행 원칙 추가 |
| `.github/pull_request_template.md` | Finder integration 변경 시 active provider path와 hygiene helper 결과를 적도록 checklist 추가 |
| `mydocs/manual/build_run_guide.md` | Debug/Release package/smoke helper 역할 분리, registration hygiene helper 사용법, cleanup 제한 범위 추가 |
| `mydocs/troubleshootings/finder_integration_validation_pitfalls.md` | cleanup-only 기준, 전역 reset 주의, helper 선택 기준 보강 |
| `scripts/check-extension-registration-hygiene.sh` | check-only registration hygiene helper 추가 |
| `mydocs/working/task_m013_240_stage1.md` | 현황 분석과 gap 정리 |
| `mydocs/working/task_m013_240_stage2.md` | 문서 보강 보고 |
| `mydocs/working/task_m013_240_stage3.md` | helper 추가 보고 |
| `mydocs/report/task_m013_240_report.md` | 본 최종 보고서 |

## helper 요약

`scripts/check-extension-registration-hygiene.sh`는 기본적으로 로컬 상태를 바꾸지 않는다.

```bash
scripts/check-extension-registration-hygiene.sh --check-only
```

확인 항목:

- PlugInKit Preview/Thumbnail provider path
- provider app root 중복 여부
- LaunchServices에 남은 개발/테스트 `Alhangeul.app` registration
- `build.noindex/`와 Xcode DerivedData 아래 개발 앱 bundle 존재 여부
- legacy `RhwpMac.app`, `AlhangeulMac.app`, `알한글.app` 및 extension 후보

cleanup 옵션은 개발 산출물 registration만 대상으로 한다.

```bash
scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations
```

허용 동작:

- 개발 앱 내부 `.appex`에 `pluginkit -r`
- 개발 앱에 `lsregister -u`
- `qlmanage -r cache`

금지 동작:

- app bundle 삭제
- legacy app 삭제
- `/Applications` 또는 `$HOME/Applications` 설치본 삭제
- `lsregister -kill -r`, `lsregister -delete`
- Finder 또는 QuickLook daemon kill

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `72d8dc6` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `8ad8b80` | 구현 계획서 작성 |
| Stage 1 | `94b7b61` | extension registration hygiene gap 분석 |
| Stage 2 | `86f5aed` | extension registration hygiene 문서 보강 |
| Stage 3 | `0d37152` | extension registration hygiene helper 추가 |
| Stage 4 | 본 커밋 | 최종 검증과 보고서 정리 |

## 검증

실행한 명령:

```bash
git diff --check
bash -n scripts/check-extension-registration-hygiene.sh
scripts/check-extension-registration-hygiene.sh --help
scripts/check-extension-registration-hygiene.sh --check-only
rg -n "Debug app|Release package|smoke helper|LaunchServices|PlugInKit|registration hygiene|확장 등록" CONTRIBUTING.md .github/pull_request_template.md mydocs/manual/build_run_guide.md mydocs/troubleshootings/finder_integration_validation_pitfalls.md scripts/check-extension-registration-hygiene.sh
git status --short
```

결과:

- `git diff --check` 통과
- shell 문법 검사 통과
- helper `--help` 출력 정상
- helper `--check-only` 실행 성공
- 문서와 helper에서 핵심 규칙 검색 확인
- 최종 보고서 작성 전 작업트리 clean 확인

`--check-only` diagnostics:

```text
/private/tmp/alhangeul-extension-registration-hygiene/20260513-163219
```

현재 로컬 상태:

- 개발 산출물 registration 없음
- 개발 앱 bundle 발견 없음
- legacy app 후보 없음
- legacy extension 후보 없음
- 설치된 provider path 없음

설치본 provider가 없는 상태이므로 Preview/Thumbnail provider path 미보고 warning은 남았지만, registration 오염은 발견되지 않았다. cleanup 옵션은 실행하지 않았다.

## 수용 기준별 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| `CONTRIBUTING.md`만 읽어도 Debug app으로 Finder extension 등록 성공을 판정하면 안 된다는 점을 알 수 있다 | OK | 기여자용 Finder Quick Look/Thumbnail 전용 원칙 추가 |
| PR 템플릿에서 active provider path와 개발 산출물 registration 잔존 여부를 확인한다 | OK | `.github/pull_request_template.md` checklist 추가 |
| `build_run_guide.md`에 Debug build, Release package, smoke helper 역할이 분리되어 있다 | OK | 표준 smoke helper 역할과 반복 시행착오 방지 규칙 보강 |
| troubleshooting 문서에 cleanup-only와 전역 reset 영향 범위가 구분되어 있다 | OK | `finder_integration_validation_pitfalls.md` 보강 |
| 표준 helper 또는 별도 helper가 개발 산출물 registration을 확인/정리한다 | OK | `scripts/check-extension-registration-hygiene.sh` 추가 |
| helper 기본 동작이 파일 삭제나 전역 reset을 수행하지 않는다 | OK | `--check-only` 기본값, cleanup 옵션 범위 제한 |

## 미수행 범위

- 제품 app/extension bundle identifier 변경
- UTI 변경
- signing entitlement 변경
- Finder/Quick Look renderer 기능 수정
- 사용자 설치본 또는 legacy app 파일 삭제 자동화
- 전역 LaunchServices reset 자동화
- release packaging, signing, notarization, public release

## 잔여 위험

- PlugInKit/LaunchServices 출력 형식은 macOS 버전에 따라 달라질 수 있다. helper는 diagnostics 파일을 남기므로 포맷 차이는 후속 조정이 필요할 수 있다.
- `--cleanup-dev-registrations`는 현재 이름 개발 산출물 registration만 정리한다. legacy app 파일 삭제나 사용자 설치본 정리는 의도적으로 포함하지 않았다.
- 설치본 provider가 없는 clean 상태에서는 helper가 warning을 남긴다. 이는 release smoke 실패가 아니라 “현재 등록된 provider가 없음”을 알리는 진단 정보다.

## 다음 절차

작업지시자 승인 후 `publish/task240` 원격 브랜치 push와 `devel-webview` 대상 PR 생성을 진행한다. PR 본문에는 `Closes #240`와 helper cleanup 제한 범위를 명시한다.
