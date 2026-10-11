# Task M020 #567 — PR #578 리뷰·CI 보정

- 대상: [PR #578](https://github.com/postmelee/alhangeul-macos/pull/578), `publish/task567` → `devel`
- 승인: 2026-10-08 작업지시자 “진행해줘”. CI 확인·리뷰·필요한 보정, 필수 검증 통과 후 merge·정리 범위.
- 판정: 현재 검토한 소스에서 추가 수정이 필요한 결함은 발견하지 않았다. 필수 원격 CI가 통과해야 merge할 수 있다. Copilot은 quota로 리뷰를 수행하지 못했으며 검증 성공으로 집계하지 않았다.

## 검토 내용

| 경계 | 확인한 내용 |
|------|-------------|
| native 공급·IPC | 신뢰한 WebView/main frame·origin·loadToken/session/revision, opaque ID 허용 집합, 요청/응답·파일·chunk·두 slot 한도, 메타데이터 재검증 |
| 취소·수명 | document epoch·navigation·종료의 reset/dispose, 늦은 transfer 회수, worker 완료 전 slot 유지, snapshot lease·expiry·구독 해제 |
| 매칭·기존 메뉴 | 명시 관리 선택/충돌 차단·설치 후보와 공개 upstream matcher의 연결, 원래 이름·스타일 보존, 오래된 열린 메뉴 무효화 |
| 설정·최초 준비 | 실제 Settings Scene 진입, 기존 선택 유지, 첫 활성화와 성공한 준비의 병합, 늦은/후속 활성화·권한 실패 재검사 보존 |
| 공식 의존성·빌드 | 공식 v0.8.7 SHA와 Cargo fingerprint, upstream checkout 무변경, 3개 source anchor·typecheck·receipt, 향후 자동 sync의 동일 adapter 사용 |

## CI 실패와 수정

최초 PR head `af12e3d5c8051a0773c0042ce10b7340e8738fd3`의 [CI run 37731062293](https://github.com/postmelee/alhangeul-macos/actions/runs/37731062293)에서 Script syntax checks가 실패했다. 개별 job 로그를 확인한 결과 negative fixture의 예상 FAIL이 원인이 아니라 마지막 main/source content gate가 원인이었다.

- 비교 main: `43b4e998b93032b62bcb0517fb9c894de3dc8ae1`.
- 충돌: `README.md`의 v0.8.6/v0.8.7 배지와 `mydocs/manual/core_dependency_operation_guide.md`의 Studio 빌드 안내.
- 승인 범위를 먼저 계획서에 기록한 `7e182df` 뒤, `a2d5e401334eb9ae16ee39f3194f540fd522e18d`에서 main을 merge했다. v0.8.7 배지와 앱 소유 adapter 빌드 안내를 보존했고 기존 main 콘텐츠는 이미 동등하게 포함되어 있었다.
- merge commit의 첫 parent 대비 tree 변경은 없다. ancestry를 연결해 동일 변경의 재적용 충돌을 해결했다. rebase·squash·gate 우회는 하지 않았다.
- Stage 4/4.1의 체크섬으로 보존한 원시 로그와 OFL 원문은 재작성하지 않고 해당 5개 경로의 whitespace attribute만 제외했다. 제품 소스의 공백 검사는 유지한다.

## 로컬 재검증

| 명령/증거 | 결과 |
|-----------|------|
| `scripts/ci/check-main-devel-content.sh origin/main HEAD` | PASS. main-only 0, 예상 merge tree가 source tree와 동일 |
| `python3 scripts/ci/update-rhwp-readme-badge.py --check` | OK, v0.8.7 배지 |
| `scripts/verify-rhwp-studio-assets.sh --upstream-dir build.noindex/task567/stage3-2/upstream-v087 --tag v0.8.7 --commit 1a76570e833917d15817415a53c09ad61ab3203f` | OK, checkout·Cargo·adapter receipt·자산 |
| `node --test scripts/ci/test-studio-font-*.cjs` | 25개 통과 |
| `scripts/verify-rhwp-core-build-info.sh`, `scripts/check-no-appkit.sh` | OK |
| Stage 5 `build-receipt.json`의 현재 입력 대조 | 175개 파일 모두 동일. 기존 signed sandbox 수용을 재사용할 수 있음 |
| `git diff --check origin/devel...HEAD` | 원문/원시 로그의 한정 attribute 적용 후 오류 없음 |

로그는 `build.noindex/task567/pr578-review/`에 보존한다. 이번 보정은 제품 소스를 변경하지 않았으므로 기존 native 109·WK/sandbox 수용과 HostApp 빌드의 재사용 근거는 유지된다. 이를 새로운 원격 CI 통과로 대신 집계하지 않는다.

## 자동 동기화 PR #577

[PR #577](https://github.com/postmelee/alhangeul-macos/pull/577)의 head `e0793cd306d77826f548daf5b5f0add8f5222f0a`도 같은 공식 v0.8.7 commit/Cargo fingerprint다. 변경 20개 경로 중 17개가 #578과 겹친다. 고유 3개 경로는 `canvaskit-renderer-k8JFRBZr.js`, `index-DnqX3T-B.js`, `rhwp_bg-DLCKNCZC.wasm`의 자동 빌드 산출물이며 별도 기능 수정이 아니다. #578은 동일 소스에서 새 WASM과 앱 adapter를 포함해 빌드·검증한 대응 자산을 가진다. 자동 자산을 덮어쓰며 별도 merge할 필요는 없다. #577의 수정/close는 수행하지 않았다.
