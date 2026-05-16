# Task #148 Stage 4 완료 보고서: M016 기준 배포 수준 문서 정합화

## 단계 목적

기존 `local/task148`에 남아 있던 #148 Stage 1-3 산출물을 최신 `devel-webview`와 M016 문서 규칙에 맞게 보정했다. 이 단계는 새 배포 실행이 아니라, 뒤늦게 발견된 선행 정책 작업을 현재 milestone 흐름에 정렬하는 작업이다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/plans/task_m016_148.md` | 기존 `task_m010_148.md` 수행계획서를 M016 기준과 현재 범위로 재작성 |
| `mydocs/plans/task_m016_148_impl.md` | 기존 구현계획서를 현재 worktree, 단계 상태, Stage 4/5 남은 절차에 맞게 재작성 |
| `mydocs/working/task_m016_148_stage1.md` | Stage 1 보고서를 M016 문서명과 현재 `Alhangeul.app` 기준으로 이관 |
| `mydocs/working/task_m016_148_stage2.md` | Stage 2 보고서를 M016 문서명으로 이관하고 오래된 앱명 보정 예정 사항 명시 |
| `mydocs/working/task_m016_148_stage3.md` | Stage 3 보고서를 M016 문서명으로 이관하고 Homebrew 범위를 준비 guard로 축소 해석 |
| `README.md` | Release / Install 안내의 `AlhangeulMac.app` 참조를 `Alhangeul.app`으로 수정 |
| `mydocs/manual/release_distribution_guide.md` | 사용자 설치 안내의 `AlhangeulMac.app` 참조를 `Alhangeul.app`으로 수정 |
| `mydocs/orders/20260505.md` | merge conflict 해결 과정에서 #148 이력을 M016 섹션으로 보정 |
| `mydocs/orders/20260508.md` | #148 오늘 진행 상태 추가 |

## 정합화 내용

- 오래된 `task_m010_148*` 파일명을 `task_m016_148*`로 변경했다.
- 기존 `/private/tmp/rhwp-mac-task148` worktree 기준 설명을 현재 작업 경로 `/Users/melee/Documents/projects/rhwp-mac` 기준으로 바꿨다.
- v0.1 public 기본값은 `Developer ID signed + notarized DMG`로 유지했다.
- Homebrew Cask 작업은 실제 tap 배포가 아니라 public DMG checksum을 Cask에 반영하기 위한 guard 준비로 한정했다.
- App Store 배포는 이번 task의 실제 준비 범위에서 제외하고 후속 lane으로 남겼다.
- #145에서 확정된 현재 bundle filesystem name `Alhangeul.app`과 README/release guide 설치 안내를 맞췄다.

## 검증 결과

다음 정합성 점검을 좁힌 대상으로 실행했다. 전체 `mydocs/`와 #148 계획 문서에는 과거 작업 맥락을 설명하는 legacy 문자열이 남을 수 있으므로, Stage 4 stale 검증은 현재 공개 설치 안내와 운영 기준 문서만 대상으로 한다.

```bash
rg --line-number 'AlhangeulMac|/private/tmp/rhwp-mac-task148' \
  README.md mydocs/manual/release_distribution_guide.md scripts/update-cask-sha256.sh
```

결과: 출력 없음. 현재 공개 설치 안내와 운영 기준 문서에서는 stale reference가 남지 않았다. Stage 5에서 최종 검증으로 다시 실행한다.

```bash
rg --line-number 'Developer ID|notarized|rehearsal|Homebrew Cask|sha256|Gatekeeper' \
  README.md mydocs/manual/release_distribution_guide.md Casks scripts
```

결과: v0.1 public DMG, rehearsal DMG, Cask sha256, Gatekeeper 안내 기준이 문서와 script에 남아 있음을 확인했다. Stage 5에서 shell syntax와 script guard를 함께 재검증한다.

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- 실제 public DMG 생성, notarization submission, GitHub Release, Homebrew tap 반영은 실행하지 않았다.
- #148보다 뒤에 merge된 #145/#150 문서와의 중복 표현은 남을 수 있다. Stage 5에서 release guide와 README 기준의 stale wording을 한 번 더 확인한다.
- Homebrew tap 대상은 아직 확정하지 않았다. 이는 실제 release 작업 또는 후속 배포 작업에서 작업지시자 결정이 필요하다.

## 다음 단계 영향

Stage 5에서는 최종 검증과 결과 보고서를 작성한다. #148 완료 후 #151 설치본 smoke gate와 #146 known limitations 문서가 이 배포 수준 결정을 참조할 수 있게 한다.

## 승인 요청

Stage 4를 완료했다. 이 보고서 기준으로 Stage 5 `최종 검증과 보고서 정리`를 진행할지 승인 요청한다.
