# Task M013 #240 구현계획서

## 구현 목표

Finder Quick Look/Thumbnail extension 검증에서 Debug/테스트 build 등록이 누적되는 문제를 문서와 표준 helper로 예방한다. 최종 산출물은 contributor가 읽는 짧은 규칙, agent/manual용 상세 절차, cleanup 범위가 제한된 registration hygiene helper, 검증 보고서다.

## Stage 1: 현황 분석과 gap 정리

### 작업 범위

- `CONTRIBUTING.md`, `AGENTS.md`, `mydocs/manual/build_run_guide.md`, `mydocs/troubleshootings/finder_integration_validation_pitfalls.md`의 현재 registration hygiene 문구를 조사한다.
- 기존 smoke helper인 `scripts/smoke-clean-quicklook-install.sh`, `scripts/smoke-finder-integration.sh`, `scripts/smoke-sparkle-extension-refresh.sh`에서 개발 산출물 등록 해제와 diagnostics coverage를 확인한다.
- 문서와 helper 사이의 누락 지점을 Stage 1 보고서에 정리한다.

### 산출물

- `mydocs/working/task_m013_240_stage1.md`

### 검증

```bash
rg -n "Debug|PlugInKit|LaunchServices|lsregister|qlmanage|build\\.noindex|DerivedData|extension 등록|확장 등록" AGENTS.md CONTRIBUTING.md mydocs/manual/build_run_guide.md mydocs/troubleshootings/finder_integration_validation_pitfalls.md scripts
git diff --check
```

### 커밋

```text
Task #240 Stage 1: extension registration hygiene gap 분석
```

## Stage 2: 기여자/매뉴얼/troubleshooting 문서 보강

### 작업 범위

- `CONTRIBUTING.md`에 기여자용 Finder/Quick Look/Thumbnail 검증 주의사항과 PR 전 checklist를 추가한다.
- `mydocs/manual/build_run_guide.md`에서 Debug build, Release package, smoke helper의 역할 차이를 표와 금지 규칙으로 보강한다.
- `mydocs/troubleshootings/finder_integration_validation_pitfalls.md`에 중복 등록 확인 명령, cleanup-only 절차, 전역 reset 영향 범위 구분을 보강한다.

### 산출물

- `CONTRIBUTING.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/troubleshootings/finder_integration_validation_pitfalls.md`
- `mydocs/working/task_m013_240_stage2.md`

### 검증

```bash
git diff --check
rg -n "Debug app|Release package|smoke helper|LaunchServices|PlugInKit|qlmanage -m plugins|cleanup-only|전역" CONTRIBUTING.md mydocs/manual/build_run_guide.md mydocs/troubleshootings/finder_integration_validation_pitfalls.md
```

### 커밋

```text
Task #240 Stage 2: extension registration hygiene 문서 보강
```

## Stage 3: registration hygiene helper 추가

### 작업 범위

- `scripts/check-extension-registration-hygiene.sh`를 추가한다.
- 기본 모드는 확인 전용으로 두고, `--cleanup-dev-registrations` 같은 명시 옵션에서만 파일 삭제 없이 개발 산출물 registration을 해제한다.
- helper는 다음을 확인한다.
  - LaunchServices에 `build.noindex/` 또는 DerivedData 아래 `Alhangeul.app`이 남아 있는지
  - PlugInKit의 active provider path가 설치본 또는 개발 산출물 중 어디를 가리키는지
  - legacy app 이름 등록 후보가 남아 있는지
  - cleanup 모드가 `lsregister -u`, `pluginkit -r`, `qlmanage -r cache` 범위에 머무르는지
- 기존 smoke helper에서 이 helper를 안내하거나, 재사용이 자연스러운 경우 내부 호출로 연결한다.

### 산출물

- `scripts/check-extension-registration-hygiene.sh`
- 필요 시 `scripts/smoke-clean-quicklook-install.sh` 또는 관련 문서 링크 보강
- `mydocs/working/task_m013_240_stage3.md`

### 검증

```bash
bash -n scripts/check-extension-registration-hygiene.sh
scripts/check-extension-registration-hygiene.sh --help
scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
```

cleanup 옵션은 파일 삭제를 포함하지 않는지 코드로 확인한다. 실제 cleanup 실행은 현재 로컬 등록 상태와 사용자 승인 필요성을 보고 결정한다.

### 커밋

```text
Task #240 Stage 3: extension registration hygiene helper 추가
```

## Stage 4: 통합 검증과 최종 보고

### 작업 범위

- Stage 1-3 수용 기준을 종합 검증한다.
- 최종 결과보고서를 작성하고 오늘할일 상태를 갱신한다.
- PR 게시 전 작업트리가 깨끗한지 확인한다.

### 산출물

- `mydocs/report/task_m013_240_report.md`
- `mydocs/orders/20260513.md`

### 검증

```bash
git diff --check
bash -n scripts/check-extension-registration-hygiene.sh
scripts/check-extension-registration-hygiene.sh --help
rg -n "Debug app|Release package|smoke helper|LaunchServices|PlugInKit|registration hygiene|확장 등록" CONTRIBUTING.md mydocs/manual/build_run_guide.md mydocs/troubleshootings/finder_integration_validation_pitfalls.md scripts/check-extension-registration-hygiene.sh
git status --short
```

### 커밋

```text
Task #240 Stage 4 + 최종 보고서: registration hygiene 검증 정리
```

## PR 계획

- 작업 브랜치: `local/task240`
- 게시 브랜치: `publish/task240`
- 대상 브랜치: `devel-webview`
- PR 제목 후보: `Document Finder extension registration hygiene`
- PR 본문에는 #240 수용 기준별 결과와 helper의 cleanup 제한 범위를 명시한다.

## 변경 금지 사항

- 제품 bundle id, UTI, signing entitlement는 변경하지 않는다.
- 사용자 앱 파일, 설치본, legacy app 파일을 자동 삭제하지 않는다.
- `lsregister -kill -r`, `lsregister -delete`, Finder kill/restart 같은 전역 reset을 helper 기본 동작으로 넣지 않는다.
- Debug build를 Finder Quick Look/Thumbnail 등록 검증의 성공 기준으로 문서화하지 않는다.
