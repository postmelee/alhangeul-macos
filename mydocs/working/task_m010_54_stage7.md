# Issue #54 Stage 7 완료 보고서

## 단계 목적

release tag dependency 전환을 막고 있는 선행 설계 작업을 별도 GitHub Issue로 분리하고, 관련 후속 이슈의 작업 순서를 정리한다.

## GitHub Issue 변경

신규 생성:

- Issue #55: release tag dependency 전환을 위한 core API compatibility와 update architecture 정리
- URL: https://github.com/postmelee/alhangeul-macos/issues/55

Issue #55 범위:

- 현재 `RustBridge`가 요구하는 core API contract 정리
- upstream release tag compatibility gate 정의
- `NativeRenderTreeBackend`/`SVGBackend` 경계 검토
- release tag update script 구조 설계
- #30 unblock checklist 제공

Issue #30 변경:

- Issue #30에 #55 완료 후 target release tag가 required bridge API compatibility gate를 통과할 때 진행한다는 코멘트를 남겼다.
- 코멘트 URL: https://github.com/postmelee/alhangeul-macos/issues/30#issuecomment-4320258708

## 권장 진행 순서

1. Issue #52
   - 기존 PR 문서 링크 보정 작업이다.
   - core dependency 구조와 독립적이고 리스크가 낮아 먼저 정리하는 편이 좋다.

2. Issue #55
   - Issue #30의 blocker다.
   - release tag 전환 조건, core API contract, update architecture를 먼저 확정한다.

3. Issue #31
   - README와 architecture 문서를 제품 경계 중심으로 재정렬한다.
   - #55에서 확정한 core dependency 방향을 반영해 문서 구조를 정리한다.

4. Issue #30
   - #55 완료 후 target release tag가 compatibility gate를 통과할 때 진행한다.
   - 실제 `Vendor/rhwp` 제거와 `RustBridge` release tag dependency 전환을 수행한다.

5. Issue #32
   - signed release pipeline은 core dependency 구조가 안정된 뒤 진행한다.
   - release script가 최종 lock/update 정책을 기준으로 검증할 수 있어야 한다.

## 검증

확인:

```bash
gh issue view 55 --repo postmelee/alhangeul-macos --json number,title,url,state
gh issue view 30 --repo postmelee/alhangeul-macos --json number,title,url,state
git diff --check
```

결과:

- Issue #55 생성 확인
- Issue #30 코멘트 기록 확인
- 로컬 문서 diff check 통과

## 완료 판단

Issue #30의 선행 설계 작업이 #55로 분리되었고, #52, #55, #31, #30, #32 순서로 진행하는 기준이 정리되었다.
