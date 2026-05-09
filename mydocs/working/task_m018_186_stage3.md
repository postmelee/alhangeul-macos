# Task M018 #186 Stage 3 완료 보고서

## 단계 목적

JavaScript action runtime warning 대응 기준과 이후 official action major 갱신 판단 절차를 문서화했다. 리뷰 중 manual 문서 중립성 기준을 보정해, 특정 deprecation 사건의 구체 값은 troubleshooting으로 분리하고 manual에는 반복 적용 가능한 원칙만 남겼다.

## 변경 요약

| 문서 | 변경 내용 |
|------|-----------|
| `mydocs/manual/document_structure_guide.md` | manual 문서 중립성 정책 추가 |
| `mydocs/manual/ci_workflow_guide.md` | JavaScript action runtime 기준을 version-neutral 절차로 추가 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | Pages 배포 모델 기준을 이슈 번호 없이 일반화 |
| `mydocs/troubleshootings/github_actions_node20_deprecation.md` | Node.js 20 deprecation warning 대응 사건의 증상, 원인, 대응 버전, 검증 기록 분리 |

## 문서화한 기준

`document_structure_guide.md`에 다음 기준을 추가했다.

- manual은 반복 적용 가능한 원칙, 절차, 판단 기준을 기록한다.
- 특정 릴리즈, 특정 이슈, 특정 deprecation 사건, 일회성 검증 결과는 manual 본문에 누적하지 않는다.
- 특정 사건의 증상, 원인, 재발 방지 절차는 `mydocs/troubleshootings/`로 분리한다.
- 큰 주제의 반복 절차가 길어지면 neutral entrypoint와 하위 manual로 소분화한다.

`ci_workflow_guide.md`에 다음 기준을 추가했다.

- GitHub Actions에서 JavaScript action runtime deprecation annotation이 발생하면 workflow의 `uses:` action을 먼저 전수 확인한다.
- official action repository의 `action.yml`에서 `runs.using` 값을 확인한다.
- official action의 release note와 README에서 major 변경의 breaking change를 확인한다.
- runner/runtime 강제 또는 deprecated runtime 허용 환경변수는 상시 대응책으로 쓰지 않는다.
- `.github/workflows/**` 변경은 PR 변경 범위 분류에서 `run_release_checks=true`가 되어야 한다.
- PR CI annotation에서 JavaScript action runtime deprecation warning 잔존 여부를 확인한다.
- 특정 deprecation 사건의 구체 값은 troubleshooting으로 분리한다.

`release_github_pages_sparkle_guide.md`에는 현재 Pages/appcast 갱신이 `main` 브랜치 `docs/` source를 쓰는 branch publishing 기준임을 남겼다. Actions 기반 Pages deployment workflow 전환은 branch publishing, release appcast push, permissions, Pages source 설정을 별도 작업에서 함께 재검토하도록 일반화했다.

`github_actions_node20_deprecation.md`에는 이번 #186의 구체 기록을 분리했다.

- Node.js 20 deprecation warning 증상과 위험
- `actions/checkout@v4`와 `actions/upload-artifact@v4` 사용 현황
- `actions/checkout@v6`, `actions/upload-artifact@v7` 선택 근거와 `node24` runtime 확인
- 사용하지 않은 우회 환경변수
- 검증 명령과 기대 결과
- Pages deployment model 전환은 #206에서 추적한다는 handoff

## 검증 결과

```bash
git status --short --branch
```

결과: `local/task186`에서 manual 문서 변경, troubleshooting 문서 추가, Stage 3 보고서 수정을 확인했다.

```bash
rg -n "Node.js 20|Node.js 24|node24|checkout@v6|upload-artifact@v7|FORCE_JAVASCRIPT_ACTIONS_TO_NODE24|ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION|#206" mydocs/manual
```

결과: 출력 없음, exit code 1. 특정 Node.js 20/24 사건, action major, #206 맥락은 manual 본문에서 제거했다.

```bash
rg -n "JavaScript action runtime|runs.using|deprecation|troubleshootings|Manual 문서 중립성|특정 릴리즈|특정 이슈|특정 deprecation" mydocs/manual
```

결과 요약:

- `document_structure_guide.md`에서 manual 문서 중립성 정책을 확인했다.
- `ci_workflow_guide.md`에서 version-neutral JavaScript action runtime 기준을 확인했다.

```bash
rg -n "Node.js 20|Node.js 24|node24|checkout@v6|upload-artifact@v7|FORCE_JAVASCRIPT_ACTIONS_TO_NODE24|ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION|#206|deploy-pages" mydocs/troubleshootings/github_actions_node20_deprecation.md .github/workflows
```

결과 요약:

- workflow reference는 `actions/checkout@v6` 7곳, `actions/upload-artifact@v7` 5곳으로 확인된다.
- troubleshooting 문서에서 Node.js 20/24 대응 기록, 선택 action major, 우회 환경변수, #206 handoff를 확인했다.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

## 다음 단계 영향

Stage 4에서는 전체 workflow parse, shell syntax, release helper dry-run, action reference 검색을 반복하고 최종 보고서와 PR 준비를 진행한다. PR이 게시된 뒤 실제 PR CI run에서 Node.js 20 deprecation annotation이 해소됐는지 확인해야 한다.

## 승인 요청

Stage 3 산출물 승인을 요청한다.

승인 후 Stage 4 `최종 dry-run, 보고, PR 준비`로 진행한다.
