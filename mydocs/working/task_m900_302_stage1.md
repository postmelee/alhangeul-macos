# Task M900 #302 Stage 1 완료보고서

## 단계 목적

Stage 1의 목적은 릴리즈 manual과 #301 릴리즈 실행 문서에서 다음 세 범주가 어떻게 섞여 있는지 감사하고, Stage 2 이후 보정 대상을 확정하는 것이다.

- pre-public draft signed/notarized DMG smoke
- official stable publish (`draft=false`, `prerelease=false`)
- post-publish public surface 확인

이번 단계에서는 본문 정책 문서를 수정하지 않고 문맥 감사와 보정 후보 확정만 수행했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m900_302_stage1.md` | Stage 1 감사 결과, 보정 대상, 검증 결과, 다음 단계 영향 |

## 본문 변경 정도 / 본문 무손실 여부

- 릴리즈 manual 본문 변경 없음.
- #301 수행계획서, 구현계획서, `v0.1.4` release record 변경 없음.
- 이번 커밋 대상은 Stage 1 완료보고서 1개로 한정한다.

## 감사 결과

### 범주별 현재 문맥

| 범주 | 현재 확인 위치 | 판단 |
|------|----------------|------|
| pre-public draft signed/notarized DMG smoke | `public_release_runbook.md` Gate 4 사전 조건, `release_github_pages_sparkle_guide.md` release note 확인 기준 | 용어는 존재하지만 독립 gate가 아니다. public publish 사전 조건 또는 release note 재검토 조건으로만 읽힌다. |
| official stable publish | `public_release_runbook.md` Gate 1/4, `release_distribution_guide.md` 전체 flow와 최종 체크리스트, `release_github_pages_sparkle_guide.md` appcast 기준 | `draft=false`, `prerelease=false`일 때 official stable release로 보는 기준은 이미 있다. 다만 draft smoke 통과 후 official publish로 넘어간다는 순서가 entrypoint/runbook에 충분히 드러나지 않는다. |
| post-publish public surface 확인 | `public_release_runbook.md` Gate 5/6/7/8/9, #301 Stage 5 | Public artifact, Pages/Sparkle, installed smoke, Homebrew gate가 publish 이후 확인 단계로 정리되어 있다. 다만 signed/notarized 설치 smoke 일부가 이 범주로 밀려 읽힐 위험이 있다. |

### 문서별 보정 대상

| 문서 | 보정 필요성 | Stage 2/3 반영 방향 |
|------|------------|---------------------|
| `mydocs/manual/release_distribution_guide.md` | 전체 release flow에서 signed/notarized DMG 생성 뒤 바로 public DMG SHA256과 post-publish 흐름으로 넘어간다. | draft signed/notarized DMG smoke를 public publish 전 gate로 flow와 최종 체크리스트에 추가한다. |
| `mydocs/manual/public_release_runbook.md` | Gate 4가 tag, workflow input, official publish를 한 단계로 다루며 draft smoke는 사전 조건 문구에만 있다. | tag 생성 후 `draft=true`, `prerelease=false` workflow로 signed/notarized DMG smoke를 수행하는 pre-public gate를 분리한다. |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | draft/prerelease 실행에서 stable appcast skip 기준은 있으나, pre-public 검증 단계라는 의미가 약하다. | stable appcast/Pages skip이 draft signed/notarized DMG smoke의 정상 동작임을 명시한다. |
| `mydocs/plans/task_m900_301.md` | Stage 4가 public publish gate, Stage 5가 post-publish 확인으로 되어 있으나 draft signed/notarized smoke 통과 조건이 분리되어 있지 않다. | #301 범위를 흔들지 않고 Stage 4에 draft smoke gate와 official publish 승인 경계를 덧붙인다. |
| `mydocs/plans/task_m900_301_impl.md` | Stage 4 작업이 `draft=false` publish 실행 예시 중심이고, Stage 5에 installed smoke가 배치되어 있다. | Stage 4를 draft signed/notarized smoke와 official stable publish gate로 읽히게 보정하고, Stage 5는 public surface 확인과 Homebrew gate로 한정한다. |
| `mydocs/release/v0.1.4.md` | release execution gate에 signed/notarized Release package build와 설치본 smoke가 있으나 draft pre-public gate 문맥은 명확하지 않다. | 필요 시 public publish 전 조건임을 짧게 보강한다. 일회성 SHA256이나 실행 결과는 추가하지 않는다. |

## 검증 결과

Stage 1 구현계획서의 검증 명령을 실행했다.

```bash
rg -n "draft=true|draft=false|signed/notarized|pre-public|post-publish|Public artifact|Pages|Sparkle|Stage 4|Stage 5" \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/public_release_runbook.md \
  mydocs/manual/release_github_pages_sparkle_guide.md \
  mydocs/plans/task_m900_301.md \
  mydocs/plans/task_m900_301_impl.md \
  mydocs/release/v0.1.4.md
```

결과 요약:

- `release_distribution_guide.md`는 `Release Publish DMG` 공식 실행과 post-publish Pages/Sparkle 확인을 갖고 있으나, draft signed/notarized smoke gate가 별도 단계로 분리되어 있지 않다.
- `public_release_runbook.md`는 Gate 4 사전 조건에 draft signed/notarized DMG smoke 이후 재검토를 언급하고, Gate 5 이후 public artifact/Pages/Sparkle/installed smoke를 다룬다.
- `release_github_pages_sparkle_guide.md`는 draft/prerelease 실행에서 stable appcast를 갱신하지 않는다고 설명하지만, pre-public smoke 단계라는 정책 의미를 더 명시할 필요가 있다.
- #301 문서는 Stage 4 `main/tag/public publish gate`, Stage 5 `post-publish 확인과 Homebrew gate` 구조이며, #302 정책을 반영하려면 Stage 4에 draft smoke gate를 명시하는 보정이 필요하다.

```bash
git diff --check
```

결과: 출력 없음. whitespace 오류 없음.

## 잔여 위험

- `Release Publish DMG` workflow 이름이 draft 검증과 official stable publish 양쪽에 쓰이므로, Stage 2에서 같은 workflow의 입력값 차이를 명확히 써야 한다.
- Gate 번호를 바꾸면 runbook 뒤쪽 Gate 5~9 참조가 함께 밀릴 수 있다. Stage 2에서는 번호 변경 여부를 최소화할지, 새 gate로 분리할지 먼저 결정해야 한다.
- #301 문서를 과도하게 고치면 이미 승인된 release execution 계획 범위를 흔들 수 있다. Stage 3에서는 정책 충돌 제거에 필요한 문구만 보정해야 한다.

## 다음 단계 영향

Stage 2에서는 `release_distribution_guide.md`와 `public_release_runbook.md`를 보정한다. 우선순위는 다음과 같다.

1. draft signed/notarized DMG smoke를 public publish 전 필수 gate로 명시한다.
2. `draft=true`, `prerelease=false` 실행과 `draft=false`, `prerelease=false` official stable publish를 분리한다.
3. post-publish public surface 확인은 Stage 5 이후 성격으로 유지한다.
4. public release 실행, GitHub Release 게시, Pages/Sparkle 갱신, Homebrew Cask 반영의 별도 승인 원칙은 유지한다.

## 승인 요청

Stage 1 감사 결과 기준으로 Stage 2 `Pre-public DMG Smoke Gate 문서화` 진행 승인을 요청한다.
