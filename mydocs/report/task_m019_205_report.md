# Task M019 #205 최종 보고서

## 개요

- 이슈: #205 앱 버전과 bundled rhwp provenance 표기 정책 정리
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task205`
- 기준 브랜치: `devel-webview`
- 목적: 앱 release identity와 bundled `rhwp` provenance 표기 기준을 release 문서, Pages, README, release note generator, publish workflow에 일관되게 반영

## 결과

공식 앱 release identity는 `Alhangeul v<app-version>` 하나로 유지하고, bundled `rhwp` core와 `rhwp-studio` 버전은 release metadata/provenance로 분리한다는 정책을 문서화했다.

정책 기준:

- Git tag, app bundle version, DMG filename, Sparkle appcast version/build, Homebrew Cask version은 앱 버전만 사용한다.
- GitHub Release title 기본형은 `Alhangeul v<app-version>`이다.
- Upstream `rhwp` 반영이 release의 중심 사용자-facing 변화일 때만 `Alhangeul v<app-version> (rhwp v<rhwp-version>)` 병기를 허용한다.
- GitHub Release body와 내부 release record는 `Release metadata` 표준 항목을 사용한다.
- README와 Pages는 사용자용 short provenance만 표시하고, commit/manifest/checksum 등 긴 기록은 GitHub Release body와 `mydocs/release/v<version>.md`에 둔다.

## 주요 변경

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/manual/release_policy_guide.md` | 앱 release identity, `rhwp` provenance 분리, title 기본형/예외형, 표준 metadata, upstream sync handoff 기준 추가 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | GitHub Release title, `Release metadata`, Pages short provenance, Sparkle appcast 앱 버전 경계 보강 |
| `README.md` | 최신 공개 릴리즈 요약에 bundled `rhwp v0.7.10` 한 줄 provenance 추가 |
| `docs/updates/v0.1.0.html`, `docs/updates/v0.1.1.html` | 사용자용 `포함된 rhwp` section과 upstream `rhwp v0.7.10` release 링크 추가 |
| `mydocs/release/v0.1.0.md`, `mydocs/release/v0.1.1.md` | 내부 release record를 `Release metadata` 표준 형식으로 보정 |
| `scripts/ci/write-release-notes.sh`, `scripts/ci/check-release-notes-template.sh` | generated release note와 template checker를 `Release metadata` heading/table 기준으로 변경 |
| `.github/workflows/release-publish.yml` | 기본 title 유지, `include_rhwp_in_title=true`일 때만 `(rhwp vX.Y.Z)` 병기하는 input/변수 추가 |
| `mydocs/plans/*`, `mydocs/working/*`, `mydocs/report/*`, `mydocs/orders/20260511.md` | 하이퍼-워터폴 계획, 단계 보고, 최종 보고, 오늘할일 완료 처리 |

### 문서 정책

- `mydocs/manual/release_policy_guide.md`
  - release identity와 bundled `rhwp` provenance 표기 정책 추가
  - title 기본형/예외형 기준 추가
  - 표준 `Release metadata` 항목 추가
  - upstream sync PR/release handoff 최소 항목 추가
- `mydocs/manual/release_github_pages_sparkle_guide.md`
  - GitHub Release title 기준 추가
  - release note 본문 항목을 `Release metadata` 중심으로 보정
  - Pages short provenance 기준 추가
  - Sparkle appcast는 앱 version/build만 사용한다는 경계 추가

### 사용자-facing 문서

- `README.md`
  - 최신 공개 릴리즈 요약에 bundled `rhwp v0.7.10` 한 줄 추가
  - README는 최신 공개 릴리즈 1개와 short provenance만 요약한다는 기준 보강
- `docs/updates/v0.1.0.html`
  - GitHub Release 링크 추가
  - `포함된 rhwp` section 추가
  - upstream `rhwp v0.7.10` release 링크 추가
- `docs/updates/v0.1.1.html`
  - GitHub Release 링크 추가
  - `포함된 rhwp` section 추가
  - upstream `rhwp v0.7.10` release 링크 추가

### Release records

- `mydocs/release/v0.1.0.md`
  - `Release metadata` 표준 형식으로 보정
- `mydocs/release/v0.1.1.md`
  - `Release metadata` 표준 형식으로 보정

### Automation

- `scripts/ci/write-release-notes.sh`
  - generated GitHub Release body에 `Release metadata` 표 생성
  - app version, core/studio tag/commit, lock/manifest path 포함
- `scripts/ci/check-release-notes-template.sh`
  - 필수 heading을 `## Release metadata`로 보정
- `.github/workflows/release-publish.yml`
  - `include_rhwp_in_title` workflow input 추가
  - 기본 title은 `Alhangeul v<version>` 유지
  - `include_rhwp_in_title=true`일 때만 `(rhwp vX.Y.Z)` 병기

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `a626ca6` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `762b8e7` | 구현계획서 작성 |
| Stage 1 | `76b3bee` | release provenance 표기 현황 정리 |
| Stage 2 | `eb4af56` | release provenance 정책과 Pages 안내 보강 |
| Stage 2.1 | `f865962` | v0.1.0 release provenance 보정 |
| Stage 3 | `415389f` | release note metadata와 publish title 기준 보강 |
| Stage 4 | `35fa7cc` | 최종 보고서와 오늘할일 완료 처리 |
| PR 준비 | `55b819a` | 최신 `origin/devel-webview` 병합과 orders 충돌 해결 |

## 검증

다음 검증을 완료했다.

- `bash -n scripts/ci/write-release-notes.sh`
- `bash -n scripts/ci/check-release-notes-template.sh`
- `jq empty Sources/HostApp/Resources/rhwp-studio/manifest.json`
- workflow YAML parse
- release note dry-run
- `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.2.md`
- cross-surface keyword scan
- `git diff --check`
- 최신 `origin/devel-webview` 병합 후 `git diff --name-only origin/devel-webview...HEAD`로 PR diff 대상 확인

검증 결과 generated `build.noindex/release/release-notes-0.1.2.md`는 다음 `Release metadata` 표준 항목을 포함했다.

- App version
- rhwp core release tag
- rhwp core commit
- bundled rhwp-studio release tag
- bundled rhwp-studio commit
- core lock
- studio manifest

## 변경 전후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| GitHub Release body provenance | bullet list `포함된 rhwp core와 viewer asset provenance` | 표준 `Release metadata` table |
| Pages release note provenance | `v0.1.0`, `v0.1.1` 모두 `rhwp` 버전 링크 없음 | 두 페이지 모두 `포함된 rhwp` section과 upstream `rhwp v0.7.10` 링크 포함 |
| GitHub Release title workflow | `Alhangeul v<version>` 고정 | 기본은 동일, `include_rhwp_in_title=true`에서만 `(rhwp vX.Y.Z)` 병기 |
| Release record | 버전별 `Provenance` 형식 혼재 | `v0.1.0`, `v0.1.1` 모두 `Release metadata` 형식 |

## 수용 기준별 결과

| 수용 기준 | 결과 |
|-----------|------|
| release policy 문서에 앱 버전과 bundled `rhwp` provenance 표기 정책 명시 | OK |
| Git tag, DMG filename, Sparkle, Homebrew는 앱 버전만 사용한다는 기준 문서화 | OK |
| GitHub Release title 기본형과 `(rhwp vX.Y.Z)` 병기 허용 조건 문서화 | OK |
| GitHub Release body와 내부 release record의 표준 metadata 항목 정리 | OK |
| release note 생성 경로가 정책과 일치 | OK |
| release-publish workflow의 GitHub Release title 생성 방식이 정책과 일치 | OK |
| #204 자동 upstream sync 작업자가 참고할 PR body/release handoff 표기 기준 제공 | OK |
| `v0.1.1` Pages에 `rhwp v0.7.10`과 upstream release 링크 추가 | OK |
| `v0.1.0` Pages와 release record도 같은 일반 기준 적용 | OK |

## 미수행 범위

- public release 실행
- GitHub Release 게시
- release asset upload
- signed/notarized DMG 생성
- Sparkle appcast 갱신
- Pages deployment
- Homebrew Cask 반영
- 원격 push/PR 생성

위 항목은 별도 승인 범위에서 진행한다.

## 잔여 관리 항목

- `origin/devel-webview` 병합으로 최신 기준은 반영했다. PR 게시 전 원격이 다시 갱신되면 같은 방식으로 충돌 여부를 확인해야 한다.
- 변경 파일 겹침은 `mydocs/orders/20260511.md`에서 확인됐고, 병합 해결 시 원격 #221 완료 항목을 보존했다.
- `include_rhwp_in_title=true`는 upstream `rhwp` 반영 중심 release일 때만 사용해야 한다.
- `rhwp-core.lock`과 studio manifest가 다른 tag/commit을 가리키는 예외 상황에서는 release owner가 release note metadata와 handoff에 사유를 남겨야 한다.

## 작업지시자 승인 요청

최종 보고와 검증은 완료됐다. 다음 절차는 `publish/task205` 원격 브랜치 push와 `devel-webview` 대상 Open PR 생성이다.
