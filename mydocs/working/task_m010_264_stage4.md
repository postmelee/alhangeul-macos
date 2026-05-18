# Task M010 #264 Stage 4 완료 보고서

## 단계 목적

Stage 1-3에서 정리한 release communication 기준과 생성 스크립트가 같은 구조를 따르는지 통합 검증하고, 최종 결과보고서와 오늘할일 상태를 정리한다.

이번 단계에서는 public release 게시, upstream `rhwp` 갱신, Pages deployment, Sparkle appcast 갱신을 수행하지 않았다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m010_264_stage4.md` | Stage 4 통합 검증 보고서 |
| `mydocs/report/task_m010_264_report.md` | 최종 결과보고서 |
| `mydocs/orders/20260518.md` | #264 상태를 완료로 갱신 |

## 통합 확인 결과

GitHub Release body의 기준 구조는 다음 표면에 같은 이름으로 연결되어 있다.

| 구분 | 문서 기준 | 생성/검증 기준 |
|------|-----------|----------------|
| `전체 요약` | `release_github_pages_sparkle_guide.md`, `release_policy_guide.md`, `release_distribution_guide.md`, `mydocs/release/index.md` | `write-release-notes.sh`, `check-release-notes-template.sh` |
| `포함된 rhwp 변화` | upstream `rhwp` 또는 bundled `rhwp-studio`가 사용자에게 미치는 영향만 쓰도록 manual에 명시 | current lock/manifest의 release tag, commit, upstream release URL 자동 생성 |
| `알한글 앱 변화` | HostApp, Quick Look, Finder thumbnail, 설치/업데이트/배포 등 앱 저장소 소유 변화를 쓰도록 manual에 명시 | 생성 template이 앱 영향 영역을 release owner 보정 대상으로 안내 |

Pages 릴리즈 노트는 GitHub Release body의 긴 provenance를 복제하지 않고, 같은 `rhwp` version, DMG filename, 설치/업데이트 안내, 알려진 한계를 짧게 대조하는 표면으로 정리되어 있다.

## 검증

실행한 명령:

```bash
bash -n scripts/ci/write-release-notes.sh
bash -n scripts/ci/check-release-notes-template.sh
bash scripts/ci/write-release-notes.sh 0.1.3 0000000000000000000000000000000000000000000000000000000000000000 build.noindex/release/release-notes-0.1.3.md
bash scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.3.md
rg -n "전체 요약|포함된 rhwp 변화|알한글 앱 변화|GitHub Release body|Pages|Release metadata" \
  build.noindex/release/release-notes-0.1.3.md \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/release/index.md \
  scripts/ci/write-release-notes.sh \
  scripts/ci/check-release-notes-template.sh
git diff --check
```

결과:

- 두 shell script 문법 검사 통과.
- release note dry-run 생성 성공.
- generated release note template check 통과.
- generated release note, manual, release index, script, checker에서 세 구분과 `Release metadata` 연결 확인.
- diff whitespace 오류 없음.

구현계획서의 shell 문법 검증 예시는 실제 실행 시 두 스크립트를 각각 `bash -n`으로 검사했다. `bash -n script1 script2` 형식은 첫 번째 script만 parse하고 두 번째 파일명은 argument가 되기 때문이다.

## 완료 판단

#264의 목표인 "릴리즈마다 사용자가 체감할 변경사항을 전체/rhwp/앱으로 구분해 작성하도록 문서화하고, 생성 helper와 checker가 그 지침을 따르게 하는 것"은 완료되었다.

다음 실제 release 작업에서는 자동 생성된 GitHub Release body 후보를 그대로 게시하지 않고, `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`를 release owner가 직전 public release 대비 실제 사용자-facing 내용으로 보정해야 한다.

## 다음 단계 승인 요청

최종 보고서 승인 후 PR 게시 절차로 넘긴다.
