# Task M010 #264 Stage 3 완료 보고서

## 단계 목적

GitHub Release body 후보 생성 스크립트와 template checker가 Stage 2에서 문서화한 `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화` 구분을 기본 구조로 생성하고 검증하도록 보강한다.

이번 단계에서는 release note 생성/검증 helper만 수정했다. 실제 `rhwp` 갱신, public GitHub Release 게시, Pages deployment, Sparkle appcast 갱신은 수행하지 않았다.

## 변경 요약

| 파일 | 변경 |
|------|------|
| `scripts/ci/write-release-notes.sh` | `## 이번 버전의 주요 변경 사항` 아래에 `### 전체 요약`, `### 포함된 rhwp 변화`, `### 알한글 앱 변화` 하위 heading을 생성하도록 보강 |
| `scripts/ci/write-release-notes.sh` | current lock/manifest 기준 `rhwp` core release tag/commit과 bundled `rhwp-studio` release tag/commit을 upstream release 링크와 함께 `포함된 rhwp 변화`에 자동 기입 |
| `scripts/ci/write-release-notes.sh` | release owner가 실제 사용자-facing 변경을 보정해야 하는 범위를 전체 요약, upstream `rhwp`, 앱 저장소 소유 변화로 나누어 안내 |
| `scripts/ci/check-release-notes-template.sh` | 위 세 하위 heading을 필수 heading으로 검사하도록 보강 |

## 생성 결과 확인

dry-run으로 생성한 `build.noindex/release/release-notes-0.1.3.md`에는 다음 구조가 포함되었다.

```md
## 이번 버전의 주요 변경 사항

### 전체 요약

### 포함된 rhwp 변화

### 알한글 앱 변화
```

현재 lock/manifest 기준 자동 기입된 upstream 정보:

- 포함된 `rhwp` core: `v0.7.11` (`a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`)
- bundled `rhwp-studio`: `v0.7.11` (`a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`)
- upstream release URL: `https://github.com/edwardkim/rhwp/releases/tag/v0.7.11`

`전체 요약`은 release owner가 직전 public release 대비 사용자가 체감할 변경을 3~5개 bullet로 보정하도록 남겼다. `포함된 rhwp 변화`는 upstream release provenance를 자동으로 제공하고, 실제 문서 열기, 렌더링, HWP/HWPX 호환성, viewer/editor 영향은 release owner가 보정하도록 안내한다. `알한글 앱 변화`는 HostApp, Quick Look, Finder thumbnail, 저장/공유/PDF/인쇄, 설치, 업데이트, About, DMG, Homebrew, Pages/Sparkle 등 앱 저장소 소유 변화를 확인하도록 안내한다.

## 검증

실행한 명령:

```bash
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
bash scripts/ci/write-release-notes.sh 0.1.3 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.3.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.3.md
rg -n "### 전체 요약|### 포함된 rhwp 변화|### 알한글 앱 변화|Release metadata|rhwp core release tag" \
  build.noindex/release/release-notes-0.1.3.md \
  scripts/ci/write-release-notes.sh \
  scripts/ci/check-release-notes-template.sh
git diff --check -- \
  scripts/ci/write-release-notes.sh \
  scripts/ci/check-release-notes-template.sh
```

결과:

- 두 shell script 문법 검사 통과.
- release note dry-run 생성 성공.
- 생성된 release note에 세 하위 heading과 release metadata가 포함됨.
- template checker가 생성 결과를 통과시킴.
- 변경된 script 파일의 diff whitespace 오류 없음.

## 다음 단계 승인 요청

Stage 4에서는 문서와 스크립트 기준의 통합 검증을 수행하고, 최종 결과보고서와 오늘할일 상태를 정리한다.
