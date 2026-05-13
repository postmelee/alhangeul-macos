# Task M019 #218 Stage 2 완료 보고서

## 단계 목적

`mydocs/troubleshootings/release_v0_1_1_workflow_failures.md`를 추가해 `v0.1.1` release workflow 실패 사례를 운영 문서로 정리한다.

확인 시각: `2026-05-11 KST`

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/troubleshootings/release_v0_1_1_workflow_failures.md` | `#188` release workflow 실패 7건의 증상, 재현 조건, 원인, 수정, 예방책 정리 |
| `mydocs/working/task_m019_218_stage2.md` | Stage 2 완료 보고서 |
| `mydocs/orders/20260511.md` | `#218` 상태 비고를 Stage 2 완료 보고서 승인 대기로 갱신 |

## 문서화한 실패 사례

| 항목 | 내용 |
|------|------|
| `GH_TOKEN` 누락 | `gh` CLI를 사용하는 release workflow에서 `GH_TOKEN: ${{ github.token }}` 전달 필요 |
| Developer ID certificate import | `$GITHUB_OUTPUT`에 쓸 helper stdout은 keychain path 하나만 남기고 `security` 출력은 stderr로 분리 |
| `cbindgen` 누락 | GitHub macOS runner에 `cbindgen`이 없을 수 있으므로 workflow에서 필요 시 설치 |
| `librhwp.a` staticlib hash mismatch | `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`은 staticlib byte hash만 제한적으로 skip하고 source/header/symbol 검증은 유지 |
| notarization log 부족 | notary JSON status와 submission log를 출력해 `Invalid` 상태 원인을 진단 |
| Sparkle nested signing | XPC/Updater/Autoupdate nested component를 Developer ID/timestamp로 재서명 |
| app extension entitlement | Quick Look/Thumbnail extension의 `get-task-allow` 제거와 배포용 entitlements 재서명 |

## 후속 이슈 연결

| 이슈 | 연결 |
|------|------|
| `#219` | signing/notarization preflight validator |
| `#220` | Rust staticlib hash 재현성 검증 정책 |
| `#227` | Rust bridge staticlib artifact 검증 정책 재정의 |

## 제외한 작업

- release script 기능 변경
- release workflow YAML 변경
- notarization submit, signing, GitHub Release 게시, Pages deployment
- Homebrew tap 배포
- staticlib hash 장기 정책 확정
- release manual 링크 추가

release manual 링크 추가는 구현계획서대로 Stage 3에서 수행한다.

## 검증 결과

```bash
test -f mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
```

결과: 통과.

```bash
rg -n "GH_TOKEN|Developer ID|GITHUB_OUTPUT|cbindgen|librhwp.a|ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|notarization|Sparkle|get-task-allow|entitlement|#219|#220|#227" \
  mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
```

결과: 주요 실패 사례, 제한적 staticlib skip 예외, 후속 이슈 연결을 모두 확인했다.

```bash
git diff --check -- mydocs/troubleshootings/release_v0_1_1_workflow_failures.md mydocs/working/task_m019_218_stage2.md mydocs/orders/20260511.md
```

결과: 통과.

## 다음 단계

Stage 3에서는 `release_distribution_guide.md`와 필요 시 `release_signing_notarization_guide.md`에서 이번 troubleshooting 문서로 연결한다. 사례 본문은 manual에 복제하지 않는다.
