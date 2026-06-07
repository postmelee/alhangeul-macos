# Task M900 #302 Stage 2 완료보고서

## 단계 목적

Stage 2의 목적은 릴리즈 entrypoint와 runbook에 signed/notarized DMG 설치 smoke가 public publish 전 필수 gate임을 명시하는 것이다.

이번 단계에서는 `release_distribution_guide.md`와 `public_release_runbook.md`만 보정했다. Pages/Sparkle 세부 가이드와 #301 관련 문서 정렬은 Stage 3 범위로 남겼다.

## 산출물

| 파일 | 줄 수 | 내용 |
|------|------:|------|
| `mydocs/manual/release_distribution_guide.md` | 169 | 전체 release flow, public release 전 확정 항목, 최종 체크리스트에 pre-public draft signed/notarized DMG smoke gate 추가 |
| `mydocs/manual/public_release_runbook.md` | 476 | Gate 4를 pre-public signed/notarized DMG smoke로 분리하고 Gate 5를 official stable publish로 신설 |
| `mydocs/working/task_m900_302_stage2.md` | 신규 | Stage 2 변경 요약, 검증 결과, 다음 단계 영향 |

## 본문 변경 정도 / 본문 무손실 여부

- 기존 권한 원칙과 secret 기록 금지 원칙은 유지했다.
- `Release Rehearsal DMG`는 그대로 unsigned rehearsal 성격으로 남겼다.
- `Release Publish DMG` workflow의 두 입력 조합을 문서상 분리했다.
  - `draft=true`, `prerelease=false`: pre-public signed/notarized DMG smoke
  - `draft=false`, `prerelease=false`: official stable publish
- runbook Gate 번호는 새 Gate 5 추가로 뒤쪽 public 확인 gate가 1씩 밀렸다.
  - Gate 6: Public artifact 확인
  - Gate 7: Pages와 Sparkle 확인
  - Gate 8: 설치본과 Finder smoke
  - Gate 9: Homebrew Cask
  - Gate 10: Release record와 최종 보고

## 변경 요약

### `release_distribution_guide.md`

- 권한 원칙에 signed/notarized DMG 설치 smoke가 public publish 전 필수 gate임을 추가했다.
- 전체 release flow를 다음 순서로 정렬했다.
  1. release tag 생성
  2. `Release Publish DMG`를 `draft=true`, `prerelease=false`로 실행해 pre-public signed/notarized DMG 생성
  3. maintainer가 draft release asset 또는 Actions artifact DMG로 설치 smoke 수행
  4. release note와 delta checklist 최종 보정
  5. 별도 승인 후 `draft=false`, `prerelease=false` official stable publish 실행
  6. GitHub Release asset, Pages, stable Sparkle appcast를 post-publish public surface로 확인
- public release 전 확정 항목에 draft DMG smoke 담당 maintainer와 기록 위치를 추가했다.
- 최종 체크리스트에서 pre-public draft DMG 생성, draft DMG SHA256/layout/universal slice/Legal 확인, maintainer 설치 smoke, official stable public DMG 산출물과 SHA256 기록을 분리했다.

### `public_release_runbook.md`

- 권한과 중단 원칙에 draft smoke와 official stable publish의 입력값 차이를 명시했다.
- Gate 1 판정 기준에서 `draft=true`, `prerelease=false`를 pre-public 검증 단계로 정의했다.
- Gate 4를 `Pre-public signed/notarized DMG smoke`로 변경했다.
  - `draft=true`, `prerelease=false` workflow 예시를 추가했다.
  - stable appcast와 Pages deploy skip을 pre-public 단계의 기대 동작으로 기록했다.
  - maintainer smoke 명령과 수동 확인 후보를 추가했다.
  - draft DMG를 Homebrew Cask, Sparkle enclosure, public Pages 다운로드 링크로 쓰지 않는다고 명시했다.
- Gate 5를 `Official stable publish`로 신설했다.
  - Gate 4 통과 후 별도 승인으로 `draft=false`, `prerelease=false` 실행만 허용했다.
  - official stable release에서만 non-draft/non-prerelease 상태, Sparkle appcast, Pages artifact deploy를 확인하도록 분리했다.

## 검증 결과

Stage 2 구현계획서의 검증 명령을 실행했다.

```bash
rg -n "draft signed/notarized DMG|draft=true|pre-public|public publish 전|official stable|post-publish" \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/public_release_runbook.md
```

결과 요약:

- `release_distribution_guide.md`에 public publish 전 필수 gate, `draft=true` pre-public 실행, `draft=false` official stable 실행, post-publish public surface 확인이 모두 검색됐다.
- `public_release_runbook.md`에 권한 원칙, Gate 1 판정 기준, Gate 4 pre-public smoke, Gate 5 official stable publish가 모두 검색됐다.

```bash
rg -n "Git tag 생성|Release Publish DMG|draft=false|prerelease=false|Homebrew" \
  mydocs/manual/public_release_runbook.md
```

결과 요약:

- Gate 4는 `draft=true`, `prerelease=false` 입력 예시를 포함한다.
- Gate 5는 `draft=false`, `prerelease=false` 입력 예시를 포함한다.
- Homebrew는 Gate 9로 남아 있고 public DMG asset과 SHA256 확정 후 별도 승인 조건을 유지한다.

```bash
git diff --check
```

결과: 출력 없음. whitespace 오류 없음.

## 잔여 위험

- `release_github_pages_sparkle_guide.md`는 아직 Stage 2에서 수정하지 않았다. draft/prerelease 실행의 stable appcast/Pages skip 의미는 Stage 3에서 해당 문서에 직접 반영해야 한다.
- #301 수행계획서와 구현계획서는 아직 기존 Stage 4/5 용어를 유지한다. Stage 3에서 #302 정책과 충돌하지 않도록 최소 문구 보정이 필요하다.
- Gate 4 maintainer smoke 명령은 산출물을 release machine의 `build.noindex/release/` 기준으로 내려받은 뒤 실행하는 형태다. 실제 workflow artifact 경로가 다르면 release record에 실제 경로를 기록해야 한다.

## 다음 단계 영향

Stage 3에서는 다음 작업을 수행한다.

1. `release_github_pages_sparkle_guide.md`에 draft/prerelease 실행이 stable appcast와 Pages를 갱신하지 않는 pre-public 검증 단계임을 명시한다.
2. #301 수행계획서와 구현계획서에서 Stage 4를 draft signed/notarized DMG smoke와 official stable publish approval gate로 읽히게 보정한다.
3. `mydocs/release/v0.1.4.md`에서 public publish 전 signed/notarized DMG smoke 조건이 명확한지 확인하고 필요 시 짧게 보정한다.

## 승인 요청

Stage 2 결과 기준으로 Stage 3 `Pages/Sparkle와 현재 Release 문서 정렬` 진행 승인을 요청한다.
