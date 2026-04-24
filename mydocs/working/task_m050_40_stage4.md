# Issue #40 Stage 4 완료 보고서

## 타스크

- GitHub Issue: #40
- 마일스톤: M050
- 제목: Dock/Spotlight 표시명 한영 현지화
- 작업 브랜치: `local/task40`
- Stage: 4. 문서와 최종 보고

## 목표

Stage 3에서 드러난 Quick Look/Thumbnail 검증 시행착오의 원인을 문서화하고, 같은 삭제/재설치/재등록 반복을 막는 표준 검증 절차를 운영 문서에 고정한다.

## 원인 분석 요약

반복 시행착오의 핵심 원인은 검증 목적별 산출물 구분이 부족했던 것이다.

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 compile/link와 bundle resource 포함 확인용이다.
- LaunchServices/PlugInKit registration smoke test는 signed/sealed app bundle이 필요하다.
- Finder Quick Look/Thumbnail 실행 확인은 `./scripts/package-release.sh <version>`으로 만든 Release package 산출물을 기준으로 해야 한다.
- `qlmanage -m plugins`는 app extension 기반 Quick Look/Thumbnail 등록 상태를 직접 판정하는 기준이 아니다.
- `AlhangeulMac.app` filesystem path와 `알한글` 사용자 표시명 문제를 분리해야 한다.
- Spotlight/Dock/Finder 표시명은 현재 사용자 언어와 LaunchServices/Spotlight cache 영향을 받으므로 extension 실행 실패와 혼동하면 안 된다.

## 변경 문서

### `AGENTS.md`

- Quick Look/Thumbnail 등록 검증은 `CODE_SIGNING_ALLOWED=NO` Debug 산출물로 수행하지 않는다는 강제 규칙을 추가했다.
- Finder smoke test는 signed/sealed Release package 산출물을 단일 ASCII 설치 경로에 배치해 수행하도록 명시했다.
- 이전 설치본 삭제는 discovery 충돌이 의심될 때 작업지시자 승인 후 진행하도록 제한했다.
- `qlmanage -m plugins`를 판정 기준으로 쓰지 않도록 명시했다.

### `README.md`

- Debug build와 Finder smoke test의 목적을 분리했다.
- Quick Look/Thumbnail smoke test는 Release package 산출물 기준으로 확인하도록 수정했다.
- filesystem bundle name은 `AlhangeulMac.app`, 사용자 표시명은 localized `InfoPlist.strings`로 제공한다는 기준을 추가했다.
- 자동화 가능한 thumbnail smoke test 예시를 추가했다.

### `mydocs/manual/build_run_guide.md`

- 새 worktree에서 submodule과 `Rhwp.xcframework` 생성 산출물이 필요하다는 준비 절차를 추가했다.
- Debug build, bundle resource 확인, LaunchServices/PlugInKit 실행 확인을 서로 다른 검증 계층으로 분리했다.
- Finder 통합 표준 smoke test 흐름을 Release package 산출물 기준으로 정리했다.
- 반복 시행착오 방지 규칙을 별도 섹션으로 추가했다.

### `mydocs/manual/release_distribution_guide.md`

- Finder 통합 smoke test를 Debug 산출물 기준에서 Release package 산출물 기준으로 수정했다.
- `qlmanage -p` 대신 자동화 가능한 `qlmanage -t -x`를 우선 사용하도록 정리했다.
- Release staging app이 local signing과 sealed resources를 갖기 때문에 Finder 통합 smoke 기준 산출물로 쓸 수 있음을 명시했다.

### `mydocs/tech/project_architecture.md`

- 사용자 표시명이 localized `InfoPlist.strings`에서 제공된다는 기준을 반영했다.
- LaunchServices/PlugInKit 등록 검증은 signed/sealed Release package 산출물 기준으로 수행한다고 명시했다.

### `mydocs/troubleshootings/task_m050_40_quicklook_thumbnail_registration_validation.md`

- 시행착오 원인, 표준 검증 절차, 증상별 판단표, 금지할 습관을 신규 troubleshooting 문서로 정리했다.

## 검증

```bash
git diff --check
```

결과:

- 성공

문서 diff 확인:

- AGENTS/README/manual/tech/troubleshooting 문서 변경 범위가 Issue #40의 표시명 및 Quick Look/Thumbnail 검증 절차 보완에 한정됨을 확인했다.

## 남은 리스크

- Dock/Finder/Spotlight 표시명은 OS cache와 사용자 언어 설정에 따라 즉시 바뀌지 않을 수 있다.
- GUI 환경에서의 Dock/Spotlight 표시명 수동 확인은 자동화하지 않았다.
- Release package 명령은 검증용 `0.1.0` 버전을 사용했으며, 실제 공개 릴리스 버전 확정은 별도 release task에서 결정한다.

## 다음 단계

최종 보고서 승인 후 `publish/task40` 원격 브랜치로 push하고 `devel` 대상 draft PR을 생성한다.

## 승인 요청

Stage 4 완료와 최종 보고를 승인 요청한다.
