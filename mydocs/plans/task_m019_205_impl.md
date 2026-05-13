# Task M019 #205 구현계획서

수행계획서: `mydocs/plans/task_m019_205.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #205 앱 버전과 bundled rhwp provenance 표기 정책 정리
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task205`
- 작업 위치: `/private/tmp/rhwp-mac-task205`
- 기준 브랜치: `devel-webview`
- 선행 상태: #185, #206, #208, #215에서 release note, Pages/appcast, universal DMG, legal notice 기준이 일부 정리되어 있다.
- 목표: 앱 버전 단독 release identity와 bundled `rhwp` provenance metadata의 경계를 문서, release script, workflow, README, Pages에 일관되게 반영한다.

## 현재 전제와 제약

- 공식 앱 release identity는 `Alhangeul v<app-version>` 하나로 유지한다.
- Git tag, `CFBundleShortVersionString`, DMG filename, Sparkle appcast version, Homebrew Cask version은 앱 버전만 사용한다.
- bundled `rhwp` provenance의 진실 원천은 `rhwp-core.lock`과 `Sources/HostApp/Resources/rhwp-studio/manifest.json`이다.
- 현재 lock/manifest 기준 `rhwp` core와 `rhwp-studio`는 모두 `v0.7.10`, commit `62a458aa317e962cd3d0eec6096728c172d57110`이다.
- `docs/updates/v0.1.1.html`에는 사용자용 수준으로 `rhwp v0.7.10` 사용 안내와 upstream release 링크를 추가한다.
- public release 실행, GitHub Release 게시, Pages deployment, Sparkle appcast 갱신은 하지 않는다.
- `rhwp-core.lock`, Rust bridge artifact, bundled `rhwp-studio` asset 자체는 변경하지 않는다.
- `Alhangeul.xcodeproj`는 생성물이고 직접 수정하지 않는다.

## 구현 원칙

- 문서의 진실 원천은 `release_policy_guide.md`에 두고, `release_github_pages_sparkle_guide.md`는 GitHub Release/Pages/Sparkle 표면별 적용 기준을 설명한다.
- README와 Pages는 사용자-facing 안내로 유지하고, 내부 release record 수준의 긴 provenance 표를 복제하지 않는다.
- GitHub Release body와 내부 release record에는 app version, `rhwp` core tag/commit, bundled `rhwp-studio` tag/commit, lock/manifest 경로를 표준 metadata로 둔다.
- GitHub Release title은 기본적으로 `Alhangeul v<app-version>`이고, upstream `rhwp` 반영 중심 release일 때만 `(rhwp vX.Y.Z)` 병기를 허용한다.
- release note script는 현재 진실 원천을 읽어 metadata를 생성한다. 수동 입력으로 `rhwp` 값을 중복 관리하지 않는다.
- workflow 입력을 늘릴 때는 release 실행자가 기본 경로에서 실수하지 않도록 기존 기본값을 유지하거나 명확한 boolean/string 입력으로 제한한다.

## Stage 1. 현황 inventory와 표기 정책 확정

### 목표

현재 release 관련 문서, 스크립트, workflow, README, Pages의 앱 버전과 `rhwp` provenance 표기 구조를 조사하고, 변경할 정책 경계를 확정한다.

### 작업

- `rhwp-core.lock`과 `Sources/HostApp/Resources/rhwp-studio/manifest.json`에서 현재 core/studio tag와 commit을 확인한다.
- `release_policy_guide.md`의 artifact/provenance 공개 기준과 기존 버전 갱신 기준을 조사한다.
- `release_github_pages_sparkle_guide.md`의 GitHub Release body, Pages 업데이트 문서, Sparkle appcast 기준을 조사한다.
- `scripts/ci/write-release-notes.sh`와 `scripts/ci/check-release-notes-template.sh`의 현재 release note section 구조를 확인한다.
- `.github/workflows/release-publish.yml`에서 GitHub Release title 생성 경로와 `expected_rhwp_tag` guard를 확인한다.
- README 최신 공개 릴리즈 요약과 `docs/updates/v0.1.1.html`의 현재 사용자-facing 문구를 확인한다.
- Stage 1 보고서에 현재 상태, 변경이 필요한 표면, 변경 제외 표면을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m019_205_stage1.md`

### 검증

```bash
git status --short --branch
sed -n '1,120p' rhwp-core.lock
plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json
rg -n "Alhangeul v|rhwp core|rhwp-studio|Release metadata|GitHub Release|Pages|appcast|expected_rhwp_tag|--title" \
  README.md docs/updates/v0.1.1.html mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh .github/workflows/release-publish.yml
git diff --check
```

### 완료 기준

- Stage 1 보고서에 표기 정책의 현황과 변경 대상이 정리된다.
- app version 단독 식별자와 bundled `rhwp` provenance metadata의 경계가 기록된다.
- 아직 정책/스크립트/Pages 본문 변경은 Stage 1 보고서 외에는 하지 않는다.

### 커밋 메시지

```text
Task #205 Stage 1: release provenance 표기 현황 정리
```

## Stage 2. 정책 문서와 사용자-facing 문서 보강

### 목표

release policy와 Pages/Sparkle guide에 표준 표기 정책을 반영하고, README와 `v0.1.1` Pages 문서의 사용자용 provenance 안내를 보강한다.

### 작업

- `release_policy_guide.md`에 앱 release identity와 bundled `rhwp` provenance 표기 정책을 추가한다.
  - 앱 버전만 쓰는 배포 식별자
  - GitHub Release title 기본형과 `(rhwp vX.Y.Z)` 병기 허용 조건
  - GitHub Release body와 내부 release record 표준 metadata
  - README 최신 릴리즈 요약의 짧은 provenance 표기 기준
  - #204 upstream sync PR/release handoff 참고 문구
- `release_github_pages_sparkle_guide.md`에 GitHub Release body, Pages 업데이트 문서, Sparkle appcast별 적용 기준을 보강한다.
- README 최신 공개 릴리즈 요약에 필요한 경우 bundled `rhwp-studio v<version>` 정도의 짧은 provenance를 표시한다는 기준과 현재 최신 릴리즈 정보를 맞춘다.
- `docs/updates/v0.1.1.html`에 `rhwp v0.7.10` 사용 안내, upstream `edwardkim/rhwp` `v0.7.10` release 링크, 알한글 GitHub Release 링크를 추가한다.
- `mydocs/release/v0.1.1.md`의 release communication checklist 또는 provenance 항목이 새 정책과 어긋나면 보정한다.
- Stage 2 보고서에 사용자-facing 문구와 내부 metadata 문구의 차이를 기록한다.

### 예상 변경 파일

- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `README.md`
- `docs/updates/v0.1.1.html`
- `mydocs/release/v0.1.1.md`
- `mydocs/working/task_m019_205_stage2.md`

### 검증

```bash
rg -n "앱 release identity|Release metadata|rhwp v0.7.10|edwardkim/rhwp/releases/tag/v0.7.10|Alhangeul v0.1.1|bundled rhwp|rhwp-studio|release handoff|upstream sync" \
  README.md docs/updates/v0.1.1.html mydocs/release/v0.1.1.md mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md
git diff --check -- README.md docs/updates/v0.1.1.html mydocs/release/v0.1.1.md mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/working/task_m019_205_stage2.md
```

### 완료 기준

- 정책 문서에 앱 버전 단독 식별자와 bundled `rhwp` provenance metadata 기준이 명시된다.
- GitHub Release title 기본형과 `rhwp` 병기 허용 조건이 문서화된다.
- `docs/updates/v0.1.1.html`에서 `rhwp v0.7.10`과 upstream release 링크를 확인할 수 있다.
- README와 Pages는 내부 release metadata를 과도하게 복제하지 않고 짧은 사용자용 안내를 유지한다.
- public Pages deployment는 수행하지 않는다.

### 커밋 메시지

```text
Task #205 Stage 2: release provenance 정책과 Pages 안내 보강
```

## Stage 3. release note 생성 경로와 publish workflow 보강

### 목표

GitHub Release body 생성 경로와 release publish workflow가 Stage 2의 표기 정책과 같은 기준을 따르게 한다.

### 작업

- `scripts/ci/write-release-notes.sh`의 provenance section을 표준 `Release metadata` 구조로 보강한다.
  - app version
  - `rhwp` core release tag
  - `rhwp` core commit
  - bundled `rhwp-studio` release tag
  - bundled `rhwp-studio` commit
  - `rhwp-core.lock`
  - `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- 필요 시 `scripts/ci/check-release-notes-template.sh`의 필수 heading 목록을 새 section명에 맞춘다.
- `.github/workflows/release-publish.yml`의 GitHub Release title 생성 경로를 점검한다.
  - 기본 title은 `Alhangeul v<version>`으로 유지한다.
  - upstream `rhwp` 반영 중심 release일 때만 `(rhwp vX.Y.Z)`를 병기할 수 있는 입력 또는 내부 title 변수 도입 여부를 결정한다.
  - 새 입력을 추가할 경우 기본값은 기존 동작과 같게 둔다.
- Stage 3 보고서에 스크립트 생성 결과와 workflow title 정책을 기록한다.

### 예상 변경 파일

- `scripts/ci/write-release-notes.sh`
- `scripts/ci/check-release-notes-template.sh`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m019_205_stage3.md`

### 검증

```bash
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
bash scripts/ci/write-release-notes.sh 0.1.2 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.2.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md
rg -n "Release metadata|App version|rhwp core release tag|rhwp core commit|bundled rhwp-studio release tag|bundled rhwp-studio commit|release_title|Alhangeul \\$tag_name|expected_rhwp_tag" \
  build.noindex/release/release-notes-0.1.2.md scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh .github/workflows/release-publish.yml
git diff --check -- scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh .github/workflows/release-publish.yml mydocs/working/task_m019_205_stage3.md
```

### 완료 기준

- generated GitHub Release body에 표준 metadata 항목이 포함된다.
- release note template checker가 새 구조를 확인한다.
- release-publish workflow의 title 생성 방식이 정책과 일치한다.
- 기존 기본 release title은 `Alhangeul v<version>`으로 유지된다.
- workflow 실행, release asset upload, GitHub Release 게시, Sparkle/Pages 배포는 수행하지 않는다.

### 커밋 메시지

```text
Task #205 Stage 3: release note metadata와 publish title 기준 보강
```

## Stage 4. 통합 검증과 최종 정리

### 목표

문서, Pages HTML, release note generator, workflow 변경을 통합 검증하고 최종 보고서와 오늘할일을 정리한다.

### 작업

- Stage 1-3 결과를 전체 keyword scan으로 확인한다.
- release note dry-run output이 정책 문서의 표준 metadata와 일치하는지 대조한다.
- `docs/updates/v0.1.1.html`의 링크와 문구가 사용자-facing 수준인지 확인한다.
- `.github/workflows/release-publish.yml`의 변경이 release 실행 권한 원칙을 바꾸지 않았는지 확인한다.
- `mydocs/orders/20260511.md`의 #205 상태를 완료로 갱신한다.
- 최종 보고서 `mydocs/report/task_m019_205_report.md`를 작성한다.
- Stage 4 보고서를 작성한다.

### 예상 변경 파일

- `mydocs/orders/20260511.md`
- `mydocs/working/task_m019_205_stage4.md`
- `mydocs/report/task_m019_205_report.md`

### 검증

```bash
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
bash scripts/ci/write-release-notes.sh 0.1.2 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.2.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md
plutil -lint Sources/HostApp/Resources/rhwp-studio/manifest.json
rg -n "Release metadata|App version|rhwp v0.7.10|edwardkim/rhwp/releases/tag/v0.7.10|Alhangeul v0.1.1|bundled rhwp-studio|release title|expected_rhwp_tag" \
  README.md docs/updates/v0.1.1.html mydocs/release/v0.1.1.md mydocs/manual/release_policy_guide.md mydocs/manual/release_github_pages_sparkle_guide.md scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh .github/workflows/release-publish.yml build.noindex/release/release-notes-0.1.2.md
git diff --check
git status --short
```

### 완료 기준

- 문서, Pages, release note generator, workflow가 같은 표기 정책을 따른다.
- `v0.1.1` Pages 문서가 bundled `rhwp v0.7.10`과 upstream release 링크를 안내한다.
- 검증 명령 결과가 단계 보고서와 최종 보고서에 기록된다.
- 최종 보고서와 오늘할일 갱신이 커밋된다.
- PR 생성 전 미커밋 변경이 없다.

### 커밋 메시지

```text
Task #205 Stage 4 + 최종 보고서: release provenance 표기 정책 정리
```

## 승인 요청 사항

1. 위 4단계 구현계획 승인
2. Stage 1에서 현황 inventory와 표기 정책 확정부터 진행 승인
