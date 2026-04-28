# Task #78 Stage 4 완료 보고서

## 단계 목적

README의 release packaging 안내가 상세 credential 절차를 중복하지 않고 `release_distribution_guide.md`로 연결되는지 확인하고, 매뉴얼에 남은 stale credential 표현을 보정한다.

## 산출물

- `README.md`: release packaging 링크 문구 보강
- `mydocs/manual/release_distribution_guide.md`: public mode 주의 문구 보정
- `mydocs/working/task_m050_78_stage4.md`: Stage 4 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

- README에는 상세 Developer ID, `notarytool`, secret 관리 절차를 추가하지 않았다.
- README의 기존 매뉴얼 링크를 `release packaging, signing, notarization` 범위가 드러나도록 보강했다.
- release manual에서는 "credential 없이 실행하지 않는다" 표현을 준비 완료 상태에 맞게 "Developer ID signing identity와 `notarytool` keychain profile이 확인된 환경에서만 실행한다"로 보정했다.
- 기존 public/rehearsal DMG 절차, GitHub Release, Homebrew Cask, rollback, checklist 내용은 유지했다.

## 검증 결과

구현 계획서의 Stage 4 검증 명령을 실행했다.

```bash
rg --line-number 'release packaging|릴리스/배포|signed|notarized|공증|Developer ID|notarytool' README.md mydocs/manual/release_distribution_guide.md
```

결과:

- README에서 v0.5 signed/notarized 목표와 `release packaging, signing, notarization` 매뉴얼 링크 확인
- `release_distribution_guide.md`에서 Developer ID, `notarytool`, public/rehearsal DMG, signing/notarization 절차 확인

```bash
rg --line-number 'credential 없이|credential이 없|Apple Developer Program credential이 없' mydocs/manual/release_distribution_guide.md
```

결과:

- 일치 항목 없음

```bash
git diff --check
```

결과: 통과

## 잔여 위험

- README는 공개 개요 문서라 배포 credential 상세를 의도적으로 복제하지 않는다. 배포 절차 변경 시 `release_distribution_guide.md`를 우선 갱신해야 한다.
- 실제 signed/notarized public DMG 생성은 아직 실행하지 않았다.

## 다음 단계 영향

Stage 5에서는 최종 검증 명령을 실행하고 최종 보고서와 오늘할일 완료 처리를 정리한다.

## 승인 요청

Stage 5 진행 승인을 요청한다.
