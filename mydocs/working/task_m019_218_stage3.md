# Task M019 #218 Stage 3 완료 보고서

## 단계 목적

release manual에서 `v0.1.1` release workflow 실패 사례 troubleshooting 문서로 진입할 수 있게 연결한다.

확인 시각: `2026-05-11 KST`

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/manual/release_distribution_guide.md` | 문제 해결 기록 섹션을 추가하고 `release_v0_1_1_workflow_failures.md` 링크 제공 |
| `mydocs/manual/release_signing_notarization_guide.md` | signing/notarization 실패 시 `v0.1.1` release workflow 실패 사례 문서 참조 추가 |
| `mydocs/working/task_m019_218_stage3.md` | Stage 3 완료 보고서 |
| `mydocs/orders/20260511.md` | `#218` 상태 비고를 Stage 3 완료 보고서 승인 대기로 갱신 |

## 변경 내용

`release_distribution_guide.md`에는 troubleshooting 문서의 위치와 읽는 시점을 짧게 추가했다. 기존 release 매뉴얼 본문에는 실패 사례 세부 내용을 복제하지 않았다.

`release_signing_notarization_guide.md`에는 Sparkle nested component signing, app extension entitlement, notary log 부족이 의심될 때 `release_v0_1_1_workflow_failures.md`를 함께 확인하도록 링크만 추가했다.

## 정책 충돌 점검

| 항목 | 결과 |
|------|------|
| release 실행 권한 원칙 | 변경 없음 |
| signing/notarization credential 기록 금지 | 변경 없음 |
| troubleshooting 문서 분리 기준 | 유지, 특정 사례 문서 링크만 추가 |
| staticlib hash 장기 정책 | `#220`, `#227`로 남김 |
| preflight validator 구현 | `#219`로 남김 |

## 검증 결과

```bash
rg -n "release_v0_1_1_workflow_failures|v0.1.1 release workflow|troubleshooting|실패 사례|문제 해결" \
  mydocs/manual/release_distribution_guide.md mydocs/manual/release_signing_notarization_guide.md mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
```

결과: release distribution guide, signing/notarization guide, troubleshooting 문서에서 연결 키워드를 확인했다.

```bash
rg -n "#220|#227|staticlib|ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY" \
  mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
```

결과: staticlib hash 예외는 `#220`, `#227` 후속 정책 의존성으로 남아 있음을 확인했다.

```bash
git diff --check -- mydocs/manual/release_distribution_guide.md mydocs/manual/release_signing_notarization_guide.md mydocs/working/task_m019_218_stage3.md mydocs/orders/20260511.md
```

결과: 통과.

## 다음 단계

Stage 4에서는 전체 문서 변경을 최종 검증하고, 오늘할일 완료 처리와 최종 보고서를 작성한다.
