# Task M900 #301 최종 보고서 - v0.1.4 public release 준비와 배포 실행

## 요약

- 이슈: [#301 v0.1.4 public release 준비와 배포 실행](https://github.com/postmelee/alhangeul-macos/issues/301)
- 마일스톤: Release Operations
- 버전/build: `0.1.4 (10)`
- Git tag: `v0.1.4`
- Tag commit: `e7ebfd9db97ddfb44139db96dad93189717cbee4`
- Public DMG SHA256: `cf04cb23e9bd072d9852cc404d092824446c7177ffb23a9bf16d1d1438317c6b`

`v0.1.4` public release는 GitHub Release, signed/notarized DMG, Pages, Sparkle stable appcast, Homebrew Cask 반영까지 완료됐다. post-publish 문구 정정 과정에서 PR이 과도하게 나뉜 점은 최종 기록에 남기고, 앞으로는 릴리즈 문서/Pages/GitHub Release 문구 정정을 종료 정리 단일 단계와 단일 PR로 묶도록 규칙을 보강했다.

## 최종 배포 결과

| 항목 | 결과 |
|------|------|
| GitHub Release | https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.4 |
| Release workflow | https://github.com/postmelee/alhangeul-macos/actions/runs/26710019767 |
| Public DMG | https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.4/alhangeul-macos-0.1.4.dmg |
| Public DMG SHA256 | `cf04cb23e9bd072d9852cc404d092824446c7177ffb23a9bf16d1d1438317c6b` |
| Public DMG size | `153214843` bytes |
| Pages 릴리즈 노트 | https://postmelee.github.io/alhangeul-macos/updates/v0.1.4.html |
| Sparkle appcast | https://postmelee.github.io/alhangeul-macos/appcast.xml |
| Homebrew Cask | `brew install --cask postmelee/tap/alhangeul` |
| Homebrew tap commit | `5c3d4ee` |

## 실제 PR 목록

| 구분 | PR | 내용 |
|------|----|------|
| Release prep | [#303](https://github.com/postmelee/alhangeul-macos/pull/303) | `v0.1.4` source metadata, release communication, rehearsal 검증 |
| Main release | [#304](https://github.com/postmelee/alhangeul-macos/pull/304) | 최초 `v0.1.4` release PR |
| Bugfix | [#306](https://github.com/postmelee/alhangeul-macos/pull/306) | #305 CoreGraphics PUA 표시 최소 보정 |
| Bugfix | [#308](https://github.com/postmelee/alhangeul-macos/pull/308) | #307 CoreGraphics text shade sentinel 보정 |
| Main refresh | [#309](https://github.com/postmelee/alhangeul-macos/pull/309) | public publish 전 bugfix refresh |
| Homebrew | [#310](https://github.com/postmelee/alhangeul-macos/pull/310) | Homebrew Cask source를 `v0.1.4` public DMG 기준으로 갱신 |
| Homebrew | [#311](https://github.com/postmelee/alhangeul-macos/pull/311) | Homebrew Cask source main sync |
| Post-publish docs | [#312](https://github.com/postmelee/alhangeul-macos/pull/312) | 이전 릴리즈 안내 banner 자동화 |
| Post-publish docs | [#313](https://github.com/postmelee/alhangeul-macos/pull/313) | 이전 릴리즈 안내 자동화 main 반영 |
| Post-publish docs | [#314](https://github.com/postmelee/alhangeul-macos/pull/314) | Docs-only Pages XML tool 설치 보강 |
| Post-publish docs | [#315](https://github.com/postmelee/alhangeul-macos/pull/315) | Docs-only Pages XML tool main 반영 |
| Post-publish copy | [#316](https://github.com/postmelee/alhangeul-macos/pull/316) | v0.1.4 릴리즈 노트 사용자 문구 보정 |
| Post-publish copy | [#317](https://github.com/postmelee/alhangeul-macos/pull/317) | 사용자 문구 보정 main 반영 |
| Rule | [#318](https://github.com/postmelee/alhangeul-macos/pull/318) | GitHub Release 기술 세부 규칙 문서화 |
| Rule | [#319](https://github.com/postmelee/alhangeul-macos/pull/319) | 기술 세부 규칙 main 반영 |
| Rule/copy | [#320](https://github.com/postmelee/alhangeul-macos/pull/320) | release note heading을 `변경 요약`으로 정리 |
| Rule/copy | [#321](https://github.com/postmelee/alhangeul-macos/pull/321) | `변경 요약` heading main 반영 |

이번 릴리즈의 PR 수가 늘어난 직접 원인은 public publish 이후 문구 보정, 이전 버전 안내 자동화, docs-only Pages workflow 보정, GitHub Release 문서 규칙 정리를 별도 PR로 순차 처리했기 때문이다. 같은 유형의 release closeout 작업은 이후부터 `릴리즈 종료 정리` 단계에서 한 번에 묶는다.

## GitHub Release 본문 정리

GitHub Release v0.1.4는 사용자-facing 요약을 유지하고 하단에 `기술 세부` section을 추가했다.

기술 세부에 기록한 내용:

- `samples/복학원서.hwp` 재현 샘플
- PUA 보정: `U+F012B`를 `(인)`으로 표시, `U+F081C` filler 숨김
- text shade/background sentinel: `TextStyle.shadeColor == 0xFFFFFFFF`를 no-shade로 처리
- 구현 경로: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 적용 표면: Quick Look preview와 Finder thumbnail native/CoreGraphics renderer path

Pages 릴리즈 노트는 사용자-facing 표면으로 유지하고, 샘플 파일명/PUA/sentinel/CoreGraphics 같은 구현 용어는 넣지 않았다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| Source preflight | OK | version/build, core lock, studio manifest, release helper dry-run 확인 |
| Local rehearsal DMG | OK | `./scripts/release.sh --skip-notarize 0.1.4`, `hdiutil verify` 통과 |
| Public Release workflow | OK | `26710019767` success |
| GitHub Release state | OK | public, non-prerelease |
| Public DMG checksum | OK | SHA256 일치 |
| Signing/notarization/Gatekeeper | OK | stapler/Gatekeeper accepted |
| App/extension version | OK | mounted app 기준 `0.1.4 (10)` |
| Universal slice | OK | `x86_64 arm64` |
| Pages | OK | v0.1.4 접근 가능, `변경 요약` heading 확인 |
| Sparkle appcast | OK | `shortVersionString=0.1.4`, `version=10`, EdDSA signature 존재 |
| Homebrew Cask | OK | style/audit/install/uninstall smoke 통과 |
| Public installed smoke | OK | 작업지시자 수동 확인 완료 |

## 산출 문서

| 문서 | 내용 |
|------|------|
| `mydocs/release/v0.1.4.md` | public 결과 기준 release record |
| `mydocs/report/task_m900_301_report.md` | #301 최종 보고서 |
| `mydocs/manual/public_release_runbook.md` | 종료 정리 단일 PR 규칙 |
| `mydocs/manual/release_github_pages_sparkle_guide.md` | post-publish 문구 정정 묶음 규칙 |
| `mydocs/orders/20260601.md` | #301 종료 정리 작업 상태 |

## 잔여 리스크

| 항목 | 판단 |
|------|------|
| Quick Look/Thumbnail과 앱 viewer 표시 차이 | 구조적으로 남는다. Quick Look/Thumbnail은 native/CoreGraphics, 앱 viewer는 WKWebView/rhwp-studio 경로다. |
| PUA 보정 범위 | 확인된 두 codepoint에 대한 최소 보정이다. 장기적으로는 PageLayerTree display text 소비 경로 전환이 적절하다. |
| text shade sentinel | `0xFFFFFFFF` no-shade 처리는 현재 샘플과 core SVG 기준으로 일관되지만, 실제 흰색 shade 문서 가능성은 잔여 리스크로 남긴다. |
| Intel Mac 실기기 smoke | universal binary와 Gatekeeper 검증은 완료했지만 별도 Intel 실기기 수동 smoke는 수행하지 않았다. |
| PR 수 증가 | 이번 릴리즈 기록에 명시하고, 이후 release closeout에서 단일 단계/단일 PR 규칙을 적용한다. |

## 종료 처리 계획

1. 종료 정리 PR을 `main`에 merge한다.
2. #301 issue를 close한다.
3. `publish/task301` 원격 브랜치를 삭제한다.
4. 로컬 작업 브랜치를 통합 브랜치로 되돌리고 불필요한 task branch를 정리한다.

## PR 공유용 요약

- `mydocs/release/v0.1.4.md`를 public 배포 완료 기준으로 정리했다.
- `task_m900_301_report.md` 최종 보고서를 작성하고 실제 PR 목록을 묶어 기록했다.
- GitHub Release v0.1.4에 `기술 세부` section을 추가해 샘플/PUA/sentinel/CoreGraphics 정보를 요약과 분리했다.
- 앞으로 릴리즈 문서/Pages/GitHub Release 문구 정정은 종료 정리 단일 단계와 단일 PR로 묶도록 runbook/가이드를 보강했다.
