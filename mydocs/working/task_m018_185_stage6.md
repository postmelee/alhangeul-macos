# Task M018 #185 Stage 6 완료 보고서

## 단계 목적

`release_distribution_guide.md`가 600줄을 넘어 AI agent가 릴리즈 작업 일부만 수행할 때도 과도한 컨텍스트를 읽게 되는 문제를 줄였다. entrypoint는 권한 원칙, 하위 문서 맵, 전체 flow, 최종 체크리스트로 축소하고, 실행 세부사항은 주제별 하위 매뉴얼로 분리했다.

## 산출물

| 파일 | 줄 수 | 역할 |
|------|------:|------|
| `mydocs/manual/release_distribution_guide.md` | 113 | 릴리즈 작업 entrypoint, 안전 게이트, 문서 라우터 |
| `mydocs/manual/release_policy_guide.md` | 133 | 운영 기준, 배포 브랜치, public 배포 수준, artifact/provenance, 알려진 한계 |
| `mydocs/manual/release_packaging_dmg_guide.md` | 240 | build 검증, 개발용 zip, public/rehearsal DMG, DMG layout, Finder smoke |
| `mydocs/manual/release_signing_notarization_guide.md` | 89 | Developer ID, notarytool, credential 기록 금지, signing/notarization 검증 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | 131 | GitHub Release body, delta checklist, Pages, Sparkle appcast |
| `mydocs/manual/release_homebrew_cask_guide.md` | 72 | Homebrew Cask source, SHA256 교체, tap 반영, audit |
| `mydocs/manual/document_structure_guide.md` | - | 릴리즈 매뉴얼 entrypoint와 하위 문서 분리 정책 추가 |

## 분리 기준

| 영역 | 분리 판단 |
|------|-----------|
| 권한 원칙과 고위험 승인 조건 | entrypoint에 유지하고 관련 하위 문서에 짧게 반복 |
| 배포 정책과 산출물 기준 | `release_policy_guide.md`로 분리 |
| package/release script와 DMG smoke | `release_packaging_dmg_guide.md`로 분리 |
| Developer ID와 notarization | `release_signing_notarization_guide.md`로 분리 |
| GitHub Release, Pages, Sparkle | `release_github_pages_sparkle_guide.md`로 분리 |
| Homebrew Cask | `release_homebrew_cask_guide.md`로 분리 |
| rollback | 짧은 전체 대응 흐름이므로 entrypoint에 유지 |
| troubleshooting | 실제 실패 증상/원인/재발 방지 절차가 생길 때만 `mydocs/troubleshootings/`로 승격 |

## 검증 결과

구현계획서 Stage 6 검증 명령을 수행했다.

```bash
git status --short --branch
wc -l mydocs/manual/release_distribution_guide.md mydocs/manual/release_policy_guide.md mydocs/manual/release_packaging_dmg_guide.md mydocs/manual/release_signing_notarization_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/release_homebrew_cask_guide.md
rg -n "명시 지시|승인|private key|password|token|public release" mydocs/manual/release_distribution_guide.md mydocs/manual/release_policy_guide.md mydocs/manual/release_packaging_dmg_guide.md mydocs/manual/release_signing_notarization_guide.md mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/release_homebrew_cask_guide.md
rg -n "release_policy_guide|release_packaging_dmg_guide|release_signing_notarization_guide|release_github_pages_sparkle_guide|release_homebrew_cask_guide" mydocs/manual/release_distribution_guide.md mydocs/manual/document_structure_guide.md
rg -n "scripts/ci/write-release-notes.sh|scripts/ci/write-release-delta-checklist.sh|ALHANGEUL_PAGES_BRANCH|SPARKLE_ED_PRIVATE_KEY" mydocs/manual/release_github_pages_sparkle_guide.md
rg -n "scripts/release.sh|scripts/package-release.sh|smoke-finder-integration|alhangeul-macos-<version>" mydocs/manual/release_packaging_dmg_guide.md
rg -n "Developer ID|notarytool|codesign|stapler|spctl" mydocs/manual/release_signing_notarization_guide.md
rg -n "Homebrew|Cask|update-cask-sha256|brew style|brew audit" mydocs/manual/release_homebrew_cask_guide.md
git diff --check
```

검증 요약:

- entrypoint 줄 수가 659줄에서 113줄로 감소했다.
- 하위 매뉴얼은 72~240줄 범위로 분리되어 주제별 부분 읽기가 가능해졌다.
- entrypoint와 하위 문서 모두에 명시 승인, 민감 정보 기록 금지, public release guardrail이 남아 있다.
- release note/delta helper, Pages branch, Sparkle secret, package/release script, Finder smoke, signing/notary 검증, Homebrew 검증 키워드가 각 담당 문서에서 확인된다.
- `git diff --check` 통과.

## 잔여 위험

- 하위 문서가 늘어났으므로 장기적으로 링크 rot과 중복 guardrail의 불일치 가능성이 있다.
- 일부 절차는 의도적으로 중복했다. 특히 명시 승인, 민감 정보 기록 금지, public artifact 기준은 누락 비용이 더 크므로 중복을 허용한다.
- #188에서 실제 public release를 수행할 때는 entrypoint의 전체 flow를 먼저 읽고, 필요한 하위 문서를 순서대로 확인해야 한다.

## 다음 단계 영향

최종 PR에서는 `release_distribution_guide.md`가 기존 AGENTS/README 링크의 진입점으로 계속 동작한다. AI agent는 세부 작업별로 하위 문서를 선택해 읽으면 된다.
