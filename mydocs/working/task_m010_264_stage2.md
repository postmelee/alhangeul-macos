# Task M010 #264 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화` 구분을 release manual과 내부 release 기록 기준에 반영한다.

이번 단계에서는 문서 기준만 보강했다. `scripts/ci/write-release-notes.sh`와 `scripts/ci/check-release-notes-template.sh` 변경은 Stage 3 범위로 남겼다.

## 변경 요약

| 파일 | 변경 |
|------|------|
| `mydocs/manual/release_github_pages_sparkle_guide.md` | GitHub Release 생성 전 확인 항목에 세 구분 보정 여부 추가. `주요 변경 사항 작성 기준` subsection을 추가해 `전체 요약`, `포함된 rhwp 변화`, `알한글 앱 변화`의 목적과 작성 범위를 명시. Pages 확인 기준에 앱 변화와 `rhwp` provenance를 짧게 구분한다는 기준 추가 |
| `mydocs/manual/release_policy_guide.md` | GitHub Release body의 사용자-facing 변경사항을 세 구분으로 작성하고, Pages는 긴 검증 기록을 복제하지 않는다는 정책 연결 |
| `mydocs/manual/release_distribution_guide.md` | 최종 체크리스트에 주요 변경 사항 세 구분과 release owner 보정 확인 항목 추가 |
| `mydocs/release/index.md` | 정보 소유 기준과 릴리즈 문서 갱신 순서에 GitHub Release 세 구분, Pages 짧은 구분, 내부 delta/provenance 대조 흐름 반영 |

## 추가 보정

Stage 1에서 발견한 Homebrew 명령 불일치를 같은 release communication 문서에서 보정했다.

- 기존: `brew install --cask postmelee/tap/alhangeul-macos`
- 현재 공개 기준: `brew install --cask postmelee/tap/alhangeul`

README, Pages, `mydocs/release/v0.1.2.md`, `release_homebrew_cask_guide.md`, `scripts/ci/write-release-notes.sh`는 이미 `postmelee/tap/alhangeul`을 사용하고 있었으므로, `release_github_pages_sparkle_guide.md`의 stale 문구만 수정했다.

## 확정 기준

GitHub Release body:

- `## 이번 버전의 주요 변경 사항` 아래에 `### 전체 요약`, `### 포함된 rhwp 변화`, `### 알한글 앱 변화`를 둔다.
- `전체 요약`은 설치할 이유를 3~5개 bullet로 요약한다.
- `포함된 rhwp 변화`는 upstream `rhwp` 또는 bundled `rhwp-studio` 변경 중 앱 사용자가 체감할 영향만 적는다.
- `알한글 앱 변화`는 HostApp, Quick Look, Finder thumbnail, 설치/업데이트/배포 등 앱 저장소가 소유한 변화를 적는다.
- `rhwp` 버전 변경이 없어도 heading은 유지하고 변경 없음 판단을 짧게 적는다.

Pages 릴리즈 노트:

- GitHub Release body의 긴 검증/provenance를 복제하지 않는다.
- hero 또는 첫 section에서 전체 요약을 짧게 제공한다.
- bundled `rhwp` 변경이 있는 릴리즈는 `포함된 rhwp` section과 upstream release 링크를 유지한다.
- 앱 자체 변화는 `주요 변경` 또는 필요 시 `알한글 앱 변화` section에서 짧게 구분한다.

내부 릴리즈 기록:

- `mydocs/release/v<version>.md`는 기존처럼 detailed delta, 검증, provenance, handoff를 소유한다.
- GitHub Release body와 Pages가 내부 기록의 version, DMG filename, provenance, 알려진 한계와 충돌하지 않는지 release owner가 대조한다.

## 검증

실행한 명령:

```bash
rg -n "전체 요약|포함된 rhwp 변화|알한글 앱 변화|GitHub Release body|Pages" \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/manual/release_policy_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/release/index.md
git diff --check -- \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/manual/release_policy_guide.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/release/index.md \
  mydocs/working/task_m010_264_stage2.md
```

결과:

- release manual과 release index에 세 구분 기준이 반영되었다.
- diff whitespace 오류 없음.

## 다음 단계 승인 요청

Stage 3에서는 `scripts/ci/write-release-notes.sh`가 세 하위 heading을 생성하고, `scripts/ci/check-release-notes-template.sh`가 해당 heading을 검증하도록 보강한다.
