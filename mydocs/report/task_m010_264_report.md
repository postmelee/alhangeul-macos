# Task M010 #264 최종 보고서

## 작업 요약

- 이슈: #264 릴리즈 안내 변경사항 구분 기준 도입
- 마일스톤: M010 (`v0.1`)
- 브랜치: `local/task264`
- 단계 수: 4
- 핵심 변경: GitHub Release body와 Pages 릴리즈 안내가 사용자-facing 변경사항을 `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화` 기준으로 작성하도록 문서와 생성 helper를 보강

## 완료 범위

- 현재 GitHub Release body, Pages 릴리즈 노트, 내부 release record, 생성 스크립트의 변경사항 구조를 조사했다.
- GitHub Release body는 기존 `## 이번 버전의 주요 변경 사항` 아래에 다음 세 하위 heading을 필수로 두도록 확정했다.
  - `### 전체 요약`
  - `### 포함된 rhwp 변화`
  - `### 알한글 앱 변화`
- Pages 릴리즈 노트는 GitHub Release body의 긴 검증/provenance를 복제하지 않고, 사용자용 짧은 안내 표면으로 같은 정보를 짧게 대조하도록 정리했다.
- `mydocs/release/index.md`에 GitHub Release, Pages, 내부 release record의 정보 소유 경계를 반영했다.
- release manual에 `rhwp` 변화와 앱 변화의 작성 범위를 명시했다.
- `scripts/ci/write-release-notes.sh`가 세 하위 heading과 current `rhwp`/`rhwp-studio` release provenance를 생성하도록 보강했다.
- `scripts/ci/check-release-notes-template.sh`가 세 하위 heading을 필수로 검사하도록 보강했다.
- release communication 문서의 stale Homebrew 설치 명령을 현재 공개 기준인 `brew install --cask postmelee/tap/alhangeul`로 맞췄다.

## 단계별 진행

| Stage | Commit | 핵심 내용 |
|-------|--------|-----------|
| 시작 | `3f75f24` | 수행계획서 작성과 오늘할일 등록 |
| 구현 계획 | `f9c5782` | 4단계 구현계획서 작성 |
| 1 | `6602af1` | release 안내 표면 inventory와 정보 구조 확정 |
| 2 | `924aec0` | release manual, release index, distribution checklist 기준 문서화 |
| 3 | `6c2ffc6` | release note 생성/검증 스크립트 보강 |
| 4 | 본 커밋 | 통합 검증, 최종 보고서, 오늘할일 완료 처리 |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/manual/release_github_pages_sparkle_guide.md` | GitHub Release body 세 구분 작성 기준, Pages 짧은 구분 기준, Homebrew 명령 정합성 보정 |
| `mydocs/manual/release_policy_guide.md` | bundled `rhwp` 표기 정책과 사용자-facing 변경사항 구분 기준 연결 |
| `mydocs/manual/release_distribution_guide.md` | 최종 release checklist에 세 구분 보정 확인 추가 |
| `mydocs/release/index.md` | GitHub Release, Pages, 내부 release record의 정보 소유 기준과 갱신 순서 보강 |
| `scripts/ci/write-release-notes.sh` | 세 하위 heading 생성, `rhwp`/`rhwp-studio` upstream release 링크와 commit 자동 기입 |
| `scripts/ci/check-release-notes-template.sh` | 세 하위 heading 필수 검사 추가 |
| `mydocs/plans/task_m010_264.md` | 수행계획서 |
| `mydocs/plans/task_m010_264_impl.md` | 구현계획서 |
| `mydocs/working/task_m010_264_stage1.md` | Stage 1 조사 보고서 |
| `mydocs/working/task_m010_264_stage2.md` | Stage 2 문서화 보고서 |
| `mydocs/working/task_m010_264_stage3.md` | Stage 3 스크립트 보강 보고서 |
| `mydocs/working/task_m010_264_stage4.md` | Stage 4 통합 검증 보고서 |
| `mydocs/orders/20260518.md` | #264 완료 상태 기록 |
| `mydocs/report/task_m010_264_report.md` | 본 최종 보고서 |

## 생성 release note 기준

dry-run으로 생성한 `build.noindex/release/release-notes-0.1.3.md`는 다음 구조를 포함한다.

```md
## 이번 버전의 주요 변경 사항

### 전체 요약

### 포함된 rhwp 변화

### 알한글 앱 변화
```

현재 lock/manifest 기준 자동 기입되는 upstream provenance:

- 포함된 `rhwp` core: `v0.7.11` (`a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`)
- bundled `rhwp-studio`: `v0.7.11` (`a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`)
- upstream release URL: `https://github.com/edwardkim/rhwp/releases/tag/v0.7.11`

## 검증 결과

```bash
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
```

결과: 성공. 두 shell script 문법 검사를 각각 통과했다.

```bash
bash scripts/ci/write-release-notes.sh 0.1.3 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.3.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.3.md
```

결과: 성공. release note dry-run 생성 후 template checker가 `Release note template check passed`로 통과했다.

```bash
rg -n "전체 요약|포함된 rhwp 변화|알한글 앱 변화|GitHub Release body|Pages|Release metadata" \
  build.noindex/release/release-notes-0.1.3.md \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/release/index.md \
  scripts/ci/write-release-notes.sh \
  scripts/ci/check-release-notes-template.sh
```

결과: 성공. generated release note, manual, release index, script, checker에서 세 구분과 `Release metadata` 연결을 확인했다.

```bash
git diff --check
```

결과: 성공. diff whitespace 오류 없음.

## 수행하지 않은 작업

- upstream `rhwp` 새 릴리즈 반영은 수행하지 않았다.
- public DMG 생성, 서명, 공증, GitHub Release 게시, Pages deployment, Sparkle appcast 갱신은 수행하지 않았다.
- 기존 public GitHub Release body와 기존 public Pages HTML은 소급 수정하지 않았다.
- release note의 실제 사용자-facing bullet 작성은 다음 실제 release 작업의 release owner 보정 범위로 남겼다.

## 잔여 리스크

- 생성 스크립트는 실제 변경사항을 자동 요약하지 않는다. 직전 public release 대비 user-facing 변경은 release owner가 내부 release record, Issue/PR, upstream `rhwp` release note를 대조해 보정해야 한다.
- Pages 릴리즈 노트는 HTML 작성물이라, 다음 실제 release에서 manual 기준대로 `rhwp` 변화와 앱 변화를 짧게 분리했는지 별도 review가 필요하다.
- `rhwp` version이 변경되지 않는 앱-only release에서도 `포함된 rhwp 변화` heading은 유지해야 하므로, release owner가 "변경 없음" 문구를 명시해야 한다.

## 완료 판단

#264는 릴리즈 안내의 변경사항 작성 기준을 문서화하고, GitHub Release 후보 생성과 template 검증이 그 기준을 따르도록 연결했다. 다음 릴리즈에서는 전체 요약, 포함된 `rhwp` 변화, 알한글 앱 변화를 구분한 상태에서 GitHub Release와 Pages 안내를 작성할 수 있다.

## 다음 단계

작업지시자 승인 후 `publish/task264` 브랜치 게시와 PR 생성 절차로 넘길 수 있다.
