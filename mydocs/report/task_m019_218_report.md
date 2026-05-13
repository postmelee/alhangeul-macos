# Task M019 #218 최종 결과 보고서

## 작업 요약

| 항목 | 값 |
|------|----|
| 이슈 | [#218 v0.1.1 release workflow 실패 사례 troubleshooting 문서화](https://github.com/postmelee/alhangeul-macos/issues/218) |
| 마일스톤 | M019 `v0.1.2` |
| 브랜치 | `local/task218` |
| 작업 위치 | `/private/tmp/rhwp-mac-task218` |
| 단계 | Stage 1-4 |

`#188` `v0.1.1` public release 실행 중 발생한 GitHub Actions, Developer ID signing, notarization, Sparkle nested signing, Rust staticlib hash 검증 실패를 troubleshooting 문서로 승격했다. 이제 `#188` Stage 4 보고서만 찾지 않아도 release maintainer가 같은 계열의 실패를 증상, 재현 조건, 원인, 수정, 예방책 순서로 진단할 수 있다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/troubleshootings/release_v0_1_1_workflow_failures.md` | `v0.1.1` release workflow 실패 7건을 진단 문서로 정리 |
| `mydocs/manual/release_distribution_guide.md` | release troubleshooting 문서 진입점 추가 |
| `mydocs/manual/release_signing_notarization_guide.md` | Sparkle nested signing, extension entitlement, notary log 문제 진단 시 troubleshooting 문서 참조 추가 |
| `mydocs/plans/task_m019_218.md` | 수행계획서 |
| `mydocs/plans/task_m019_218_impl.md` | 구현계획서 |
| `mydocs/working/task_m019_218_stage1.md` | 실패 사례 inventory와 문서 구조 확정 |
| `mydocs/working/task_m019_218_stage2.md` | troubleshooting 문서 작성 보고 |
| `mydocs/working/task_m019_218_stage3.md` | release manual 연결 보고 |
| `mydocs/working/task_m019_218_stage4.md` | 최종 검증 보고 |
| `mydocs/orders/20260511.md` | `#218` 진행 상태와 완료 상태 기록 |

## 문서화한 실패 사례

| 사례 | 정리 내용 |
|------|----------|
| `GH_TOKEN` 누락 | `gh` CLI를 사용하는 release workflow에서 `GH_TOKEN: ${{ github.token }}` 전달 필요 |
| Developer ID certificate import | `$GITHUB_OUTPUT`에 쓸 helper stdout은 keychain path만 남기고 `security` 출력은 stderr로 분리 |
| `cbindgen` 누락 | GitHub macOS runner에 `cbindgen`이 없을 수 있으므로 release/rehearsal workflow에서 필요 시 설치 |
| `librhwp.a` staticlib hash mismatch | `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`은 staticlib byte hash만 제한적으로 skip하고 source/header/symbol 검증은 유지 |
| notarization log 부족 | notary JSON status와 submission log를 출력해 `Invalid` 상태 원인을 진단 |
| Sparkle nested signing | XPC/Updater/Autoupdate nested component를 Developer ID/timestamp로 재서명 |
| app extension entitlement | Quick Look/Thumbnail extension의 `get-task-allow` 제거와 배포용 entitlements 재서명 |

## 검증 결과

| 검증 | 결과 |
|------|------|
| troubleshooting 문서 존재 | OK |
| 핵심 키워드 확인 | OK |
| release manual 링크 확인 | OK |
| `#219`, `#220`, `#227` 후속 이슈 연결 | OK |
| `git diff --check` | OK |

최종 검증 명령:

```bash
test -f mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
test -f mydocs/report/task_m019_218_report.md
rg -n "GH_TOKEN|Developer ID|GITHUB_OUTPUT|cbindgen|librhwp.a|ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|notarization|Sparkle|get-task-allow|#219|#220|#227" \
  mydocs/troubleshootings/release_v0_1_1_workflow_failures.md mydocs/report/task_m019_218_report.md
rg -n "release_v0_1_1_workflow_failures|v0.1.1 release workflow|실패 사례" \
  mydocs/manual/release_distribution_guide.md mydocs/manual/release_signing_notarization_guide.md
git diff --check
git status --short
```

## 제외한 작업

- release script 기능 변경
- release workflow YAML 변경
- notarization submit 또는 signing 실행
- GitHub Release 게시
- Pages deployment
- Homebrew tap 배포
- Rust staticlib hash 장기 정책 확정

## 잔여 위험과 후속 작업

- staticlib hash skip 허용 조건과 장기 검증 기준은 `#220`, `#227` 결과를 따라야 한다.
- Sparkle nested component discovery, app extension entitlement/timestamp preflight는 `#219`에서 validator로 보강한다.
- 본 작업은 troubleshooting 문서화만 수행했으므로 새 release run의 실제 성공을 보장하지 않는다. 다음 public release에서는 release workflow와 signing/notarization 검증을 별도로 수행해야 한다.

## 작업지시자 승인 요청

`#218` 작업은 troubleshooting 문서 작성, release manual 연결, 최종 검증까지 완료됐다. 이 최종 보고서 승인 후 PR 게시 절차로 넘어갈 수 있다.
