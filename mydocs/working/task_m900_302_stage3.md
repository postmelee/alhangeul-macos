# Task M900 #302 Stage 3 완료보고서

## 단계 목적

Stage 3의 목적은 Pages/Sparkle 가이드와 현재 `v0.1.4` release 문서를 Stage 2에서 확정한 gate 정책에 맞추는 것이다.

핵심 기준은 다음과 같다.

- `draft=true`, `prerelease=false` 실행은 pre-public signed/notarized DMG smoke 단계다.
- draft/prerelease 실행에서 stable appcast와 Pages deployment가 skip되는 것은 정상 동작이다.
- `draft=false`, `prerelease=false` 실행만 official stable publish로 보며, Stage 5는 post-publish public surface 확인과 Homebrew gate로 둔다.

## 산출물

| 파일 | 줄 수 | 내용 |
|------|------:|------|
| `mydocs/manual/release_github_pages_sparkle_guide.md` | 264 | draft/prerelease appcast skip의 pre-public 검증 의미와 official stable publish 전 release body/Pages 재검토 기준 보강 |
| `mydocs/plans/task_m900_301.md` | 176 | #301 수행계획서 Stage 4/5 용어와 workflow 입력 예시 정렬 |
| `mydocs/plans/task_m900_301_impl.md` | 317 | #301 구현계획서 Stage 4를 pre-public smoke와 official publish gate로 분리 |
| `mydocs/release/v0.1.4.md` | 177 | release execution gate에 pre-public draft DMG smoke와 official stable publish 조건 반영 |
| `mydocs/working/task_m900_302_stage3.md` | 신규 | Stage 3 변경 요약, 검증 결과, 다음 단계 영향 |

## 본문 변경 정도 / 본문 무손실 여부

- #301의 source metadata, release note 후보, 검증 결과 SHA256은 변경하지 않았다.
- #301 release execution 자체를 실행하지 않았고, workflow run 결과를 새로 단정하지 않았다.
- `release_github_pages_sparkle_guide.md`에는 반복 적용 가능한 정책만 추가했고, 특정 release 결과값은 넣지 않았다.
- Stage 3 변경은 기존 문서의 Gate 구조와 승인 경계를 보정하는 문구 변경에 한정했다.

## 변경 요약

### `release_github_pages_sparkle_guide.md`

- 권한 원칙에 `draft=true`, `prerelease=false` 실행이 pre-public signed/notarized DMG smoke 단계임을 추가했다.
- draft smoke 이후 official stable publish 전에 GitHub Release body와 Pages 업데이트 문서를 다시 검토해야 한다고 명시했다.
- `Release Publish DMG` appcast 동작 기준을 다음처럼 분리했다.
  - official stable release에서만 stable appcast 갱신
  - `draft=true`, `prerelease=false`에서는 stable appcast skip
  - prerelease 실행도 stable appcast와 Pages deployment skip
  - official stable release에서만 generated `appcast.xml`과 Pages artifact 배포 성공을 appcast 배포 성공으로 판정

### #301 수행계획서와 구현계획서

- Stage 4를 `main/tag/pre-public smoke와 official publish gate`로 보정했다.
- Stage 4 작업에 `draft=true`, `prerelease=false` pre-public signed/notarized DMG smoke를 추가했다.
- Stage 4 작업에 draft smoke 통과 후 `draft=false`, `prerelease=false` official stable publish를 별도 승인 gate로 추가했다.
- Stage 5를 post-publish public surface 확인과 Homebrew gate로 정렬했다.
- workflow 입력 예시에 pre-public draft smoke와 official stable publish 입력을 모두 남겼다.
- rehearsal DMG, 개발용 zip, pre-public draft DMG, official stable public DMG의 산출물 계층을 섞지 않는다고 보강했다.

### `mydocs/release/v0.1.4.md`

- 상태를 Stage 4 pre-public signed/notarized DMG smoke 승인 대기로 정리했다.
- Stage 4 이후 보강할 검증에 pre-public draft DMG smoke와 official stable public DMG 확인을 분리했다.
- release execution gate에 `draft=true`, `prerelease=false` pre-public DMG 생성, maintainer 설치 smoke, `draft=false`, `prerelease=false` official stable publish 조건을 추가했다.

## 검증 결과

Stage 3 구현계획서의 검증 명령을 실행했다.

```bash
rg -n "draft|prerelease|stable appcast|Pages deployment|pre-public|official stable" \
  mydocs/manual/release_github_pages_sparkle_guide.md
```

결과 요약:

- 권한 원칙에 pre-public 검증 단계와 skip 정상 동작이 검색됐다.
- GitHub Release 생성 전 확인과 주요 변경 사항 작성 기준에 official stable publish 전 재검토 문구가 검색됐다.
- appcast 동작 기준에 `draft=false`, `draft=true`, prerelease, official stable release 조건이 모두 검색됐다.

```bash
rg -n "Stage 4|Stage 5|draft signed/notarized|pre-public|post-publish|Homebrew gate|draft=true|draft=false" \
  mydocs/plans/task_m900_301.md \
  mydocs/plans/task_m900_301_impl.md \
  mydocs/release/v0.1.4.md
```

결과 요약:

- #301 수행계획서와 구현계획서에 Stage 4 pre-public smoke와 official publish gate가 검색됐다.
- #301 구현계획서에 `draft=true`와 `draft=false` workflow 입력 예시가 모두 검색됐다.
- #301 Stage 5는 post-publish public surface 확인과 Homebrew gate로 검색됐다.
- `v0.1.4` release record에 pre-public signed/notarized DMG smoke 승인 대기와 official stable publish 조건이 검색됐다.

```bash
git diff --check
```

결과: 출력 없음. whitespace 오류 없음.

## 잔여 위험

- #301 release execution은 아직 실제 Stage 4 승인 대기 상태다. 이 문서 보정은 실행 순서 정렬이며, 실제 tag/workflow/release asset 결과를 보장하지 않는다.
- `draft=true` workflow 실행 산출물이 draft release asset과 Actions artifact 중 어디에 남는지는 실제 workflow run 결과에 따라 release record에 기록해야 한다.
- Stage 4 최종 검증에서는 세 릴리즈 manual과 #301 관련 문서 전체에서 같은 gate 용어가 유지되는지 다시 확인해야 한다.

## 다음 단계 영향

Stage 4에서는 다음을 수행한다.

1. 릴리즈 manual 3개와 #301 관련 문서 전체에서 gate 용어를 최종 검색한다.
2. public publish, GitHub Release 게시, Pages/Sparkle 갱신, Homebrew Cask 반영이 별도 승인 gate로 유지되는지 확인한다.
3. secret 값, credential payload, 일회성 SHA256 또는 workflow 실행 결과가 manual에 추가되지 않았는지 확인한다.
4. Stage 4 완료보고서와 최종 결과보고서를 작성하고 오늘할일을 완료로 갱신한다.

## 승인 요청

Stage 3 결과 기준으로 Stage 4 `통합 검증과 최종 보고` 진행 승인을 요청한다.
