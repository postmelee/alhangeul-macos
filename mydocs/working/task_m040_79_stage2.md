# Task M040 #79 Stage 2 완료보고서

## 단계 목적

`mydocs/manual/public_release_runbook.md`를 신규 작성해 public release 요청을 받은 작업자와 에이전트가 최신 context 수집부터 release record 정리까지 순서대로 확인할 수 있게 했다.

작업지시자 지시에 따라 특정 버전이나 특정 현재 환경에 고정하지 않고, 장기적으로 매 릴리즈마다 다시 사용할 수 있는 일반화된 절차로 작성했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/manual/public_release_runbook.md` | public release 실행 runbook 신규 작성, 398 lines |
| `mydocs/working/task_m040_79_stage2.md` | Stage 2 완료보고서 |

## 본문 구성

신규 runbook은 다음 gate 구조로 작성했다.

| 구분 | 역할 |
|------|------|
| 목적/사용 시점 | runbook이 특정 release 기록이 아니라 반복 절차임을 명시 |
| 권한과 중단 원칙 | public release, GitHub Release, Sparkle, Pages, Homebrew 승인 gate 분리 |
| 필수 참조 문서 | 기존 세부 매뉴얼을 진실 원천으로 연결 |
| Gate 0 | 최신 공개 앱 release, upstream `rhwp`, local candidate, workflow default, Cask 상태 수집 |
| Gate 1 | `version`, `build`, `candidate commit`, `previous_release_ref`, `expected_rhwp_tag`, `require_latest_rhwp`, `include_rhwp_in_title`, `draft`, `prerelease` 확정 |
| Gate 2 | source preflight와 release candidate 정합성 확인 |
| Gate 3 | rehearsal DMG와 delta checklist 확인 |
| Gate 4 | public publish workflow 실행 전후 조건 |
| Gate 5 | public artifact, SHA256, signing/notarization/Gatekeeper 확인 |
| Gate 6 | Pages와 Sparkle appcast 확인 |
| Gate 7 | 설치본과 Finder smoke 확인 |
| Gate 8 | Homebrew Cask 별도 승인 gate |
| Gate 9 | release record와 최종 보고 |
| Rollback | 문제 발생 시 배포 표면 축소와 후속 기록 절차 |

## 일반화 반영 내용

- 특정 최신 앱 버전, 특정 최신 upstream tag, 현재 workflow default를 runbook 본문 기준값으로 고정하지 않았다.
- 모든 release identity 값은 `<version>`, `v<version>`, `<previous-release-ref>`, `<expected-rhwp-tag>`, `<candidate-ref>` placeholder로 표현했다.
- release 시작 시 `gh release view`, `rhwp-core.lock`, bundled manifest, plist, workflow input, Cask source를 다시 읽어 현재 context를 계산하도록 했다.
- workflow default는 stale할 수 있음을 명시하고, default를 그대로 쓰는 것을 금지했다.
- Homebrew는 public DMG SHA256 확정 이후 별도 승인 gate로 분리했다.
- 실행하지 않은 smoke는 성공으로 기록하지 말고 미실행 사유를 남기도록 했다.

## 본문 변경 정도 / 본문 무손실 여부

기존 문서는 변경하지 않았다. `public_release_runbook.md` 신규 추가만 수행했다.

## 검증 결과

### 파일 존재 확인

```bash
test -f mydocs/manual/public_release_runbook.md
```

결과: 통과.

### 필수 항목 검색

```bash
rg -n "previous_release_ref|expected_rhwp_tag|require_latest_rhwp|include_rhwp_in_title|draft|prerelease|SPARKLE_ED_PRIVATE_KEY|Homebrew|rollback|Rollback" mydocs/manual/public_release_runbook.md
```

결과: 통과. workflow input, Sparkle secret 이름, Homebrew gate, rollback 항목이 문서에 포함되어 있음을 확인했다.

### whitespace 검증

```bash
git diff --check
```

결과: 통과. whitespace 오류 없음.

## 잔여 위험

- runbook은 아직 `release_distribution_guide.md`에서 링크되지 않았다. Stage 3에서 기존 release guide 진입점에 연결해야 한다.
- runbook의 명령 예시는 release day 절차를 설명하기 위한 일반 예시다. 실제 실행 시에는 release owner가 확정한 입력값으로 다시 검토해야 한다.
- secret 금지 항목 이름은 문서에 등장하지만 실제 secret 값은 기록하지 않았다. Stage 4 최종 검증에서 금지 문자열 검색 후 문맥을 재확인한다.

## 다음 단계 영향

Stage 3에서는 `release_distribution_guide.md`에 `public_release_runbook.md`를 하위 매뉴얼 또는 실행 진입점으로 연결한다. 기존 가이드와 새 runbook의 역할을 구분해, 정책 설명은 기존 문서에 두고 실제 배포일 순서는 runbook으로 안내한다.

## 승인 요청

Stage 2 완료 결과를 검토한 뒤 Stage 3 `release_distribution_guide.md` 연결 보강 진행 승인을 요청한다.
