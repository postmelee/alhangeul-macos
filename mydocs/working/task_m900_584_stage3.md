# Task M900 #584 Stage 3 main 통합·실행 준비 보고

## 현재 결과와 승인 범위

**Stage 3 main 통합·v0.2.3 태그 생성/push 완료 / DMG 실행 승인 및 단계 전체 수용 대기.** 준비 PR #585와 main PR #586의 리뷰·CI를 확인한 뒤, 작업지시자의 **“main 병합·다음 실행 준비”** 승인으로 #586을 2026-10-12 07:07:47 KST에 main에 병합했다. 실제 source SHA는 `c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4`다. 이어 **“v0.2.3 태그 생성·push”** 승인으로 07:27 KST에 annotated tag를 원격에 게시하고 정확한 commit 일치를 검증했다. 서명/공증 DMG 생성과 ARM/Intel VM 설치는 아직 실행하지 않았다.

## 준비 PR 병합과 검토

[PR #585](https://github.com/postmelee/alhangeul-macos/pull/585)의 head `938b59b9705a227567227a1ab3578c4208eedeef`에서 [run 38169630236](https://github.com/postmelee/alhangeul-macos/actions/runs/38169630236)의 Classify changed files·Script syntax checks·macOS validation·Release helper checks 4개가 모두 SUCCESS였다. 변경 요청/inline 리뷰 코멘트는 없었다. Copilot 리뷰는 quota 때문에 수행되지 않았고, 앞서 직접 검토한 버전·공개 보호·지원 범위와 P3 검증 이미지 보완을 확인해 병합했다.

병합 시각은 2026-10-12 06:10:44 KST이며 merge SHA는 `5146d91e61e29959b45f6af68090cca4e9c3b97d`다. merge tree와 검증한 PR head tree는 동일하다. #584는 OPEN이며 릴리즈 수용이 남아 있어 타스크 브랜치를 유지한다. local/task584는 깨끗한 상태에서 해당 devel에 fast-forward해 준비 문서를 이어 작성했다.

## main 인계 기준과 검증

| 항목 | 확인한 실제 값·결과 |
|------|--------------------|
| main base | 43b4e998b93032b62bcb0517fb9c894de3dc8ae1 |
| devel source | 5146d91e61e29959b45f6af68090cca4e9c3b97d |
| content gate | PASS, main-only content 0. 예상 통합 tree = source tree 80fb5eadadbc9ff8f89a8652917e037715c077bd |
| 버전 | HostApp·Quick Look·Thumbnail·Spotlight source 모두 0.2.3 / 21 |
| core·Studio | v0.8.7 / 1a76570e833917d15817415a53c09ad61ab3203f, build info·자산/adapter 검증 PASS |
| 공개 앱 / upstream latest | v0.2.2 / v0.8.7, 새 조회로 확인 |
| 포함 PR | v0.2.2..5146d91e의 전체 29개, first-parent 20개. Stage 1 이후 추가는 #585 하나 |
| main PR 범위 | 792개 path. main에는 아직 없는 Mac 글꼴·core/Studio와 기존 운영/검증·안내 기록을 함께 운반 |
| 게시 전 중복 확인 | 열린 devel → main PR 없음, 원격 v0.2.3 tag 없음, v0.2.3 Release HTTP 404. 이후 승인에 따라 #586 게시 |

Stage 1의 28개 분류를 유지하고 전체 merge ancestry와 추가 #585 원문·diff·CI를 대조했다. helper delta 초안은 build.noindex/task584/stage3/preparation에 만들었으며, main/tag의 최종 source 확정 뒤 전체 PR-analysis/delta helper를 다시 갱신한다. #585 준비 작업을 Mac 기능 구현과 중복 집계하거나 해결된 #584로 표시하지 않는다.

최초 content gate는 sandbox에서 Git 임시 객체 쓰기가 제한돼 exit 2였다. raw 실패 로그를 보존하고 Git 객체 생성 권한으로 재검증해 위 PASS를 얻었다. 제품 소스·index·branch를 바꾸는 merge로 통과시키지 않았다. 이번 source tree는 검증한 준비 PR과 같으므로 로컬 Rust/Xcode 빌드를 반복하지 않았다. 새 앱·DMG·빌드 cache는 생성하지 않았다.

## Pages·Sparkle 공개 보호

main 반영 시 기존 Docs-only Pages Deploy가 시작된다. main과 source에서 해당 workflow는 byte 동일하다. 새 v0.2.3 Release가 없는 현재 상태에서는 기존 asset gate가 deploy=false를 반환해 배포를 건너뛴다. draft 후보가 생겨도 public DMG 조건을 충족하지 않는다. workflow를 제거하거나 우회하지 않는다.

현재 public appcast를 새로 내려받아 0.2.2 / build 20과 기존 DMG URL을 확인했다. SHA256은 `8b0face06819d65f60cc6e3675244eaa1cccead997927c1f27c131d523313140`으로 Stage 2 조회와 같다. 병합 후 [Pages run 38179177872](https://github.com/postmelee/alhangeul-macos/actions/runs/38179177872)은 success이며 Deploy GitHub Pages job은 skipped다. [실제 gate 증거](../report/assets/task_m900_584/stage3/main-merge/pages-gate-proof.json)에 Release 부재와 feed 유지를 대조했다. 공개 Pages·appcast·Homebrew 또는 앱 설치본은 변경하지 않았다.

## 준비한 실행 입력과 다음 승인

1. [main PR #586](https://github.com/postmelee/alhangeul-macos/pull/586): 제목 **Release v0.2.3: Mac 설치 글꼴과 rhwp v0.8.7 소스 준비**, 검토 head devel `5146d91e`, 검토 base main `43b4e998` 그대로 merge commit으로 병합했다. devel은 유지했다. [병합 증거](../report/assets/task_m900_584/stage3/main-merge/pr586-merged.json)에 exact head의 CI 4개 SUCCESS·시각·실제 merge SHA를 기록했다.
2. 실제 main `c9d59f9300ef78b4cc6a3a8e17a10a3d766d01d4`를 대상으로 **v0.2.3 annotated tag 생성·원격 push**를 별도로 승인받아 완료했다. 실제 tag object `041343f5f1c747d50ccfdaee8e8f28040527efa3`와 peeled commit의 로컬/원격 일치 PASS다. main tree는 검토 source의 `80fb5eadadbc9ff8f89a8652917e037715c077bd`와 같다. 병합 후 content gate는 PASS, transport-only 1 / content 후보 0이다. 네 source bundle 0.2.3/21과 core·Studio v0.8.7의 같은 commit도 actual main에서 확인했다.
3. **Release Publish DMG 실행**을 별도 승인받는다. ref=v0.2.3, version=0.2.3, previous_release_ref=v0.2.2, expected_rhwp_tag=v0.8.7, require_latest_rhwp=true, include_rhwp_in_title=false, draft=true, prerelease=false. 네 bundle build=21을 확인한다. upstream latest는 실행 직전 다시 확인한다.
4. 생성 후 실제 source/run/artifact/DMG SHA256·size와 파일/서명 검증 결과를 기록한다. 값을 임의로 채우지 않는다. 해당 동일 파일의 release-first-install.yml 실행은 실제 입력과 macos-15/arm64·macos-15-intel/x86_64를 제시해 승인받는다.

[초기 입력표](../report/assets/task_m900_584/stage3/release-inputs.json)와 [병합 후 입력표](../report/assets/task_m900_584/stage3/main-merge/release-inputs.json)는 각 시점 snapshot으로 보존했다. [태그 고정 후 새 입력표](../report/assets/task_m900_584/stage3/tag/release-inputs.json)와 [실행 준비안](task_m900_584_release_execution.md)에 실제 main SHA·tag object를 기록했으며, 생성되지 않은 run/artifact/hash는 null을 유지한다. main 병합과 태그 게시까지 승인·실행했으며 DMG 실행·설치·공개는 [구현계획 §4](../plans/task_m900_584_impl.md)의 이후 각각의 gate다.

## 증거와 남은 수용

- [출처·시각·기준](../report/assets/task_m900_584/stage3/context.json), [#585 병합/CI](../report/assets/task_m900_584/stage3/pr585-merged.json), [content gate](../report/assets/task_m900_584/stage3/main-devel-content.log).
- [PR 분석 갱신](../report/assets/task_m900_584/stage3/pr-analysis.json), [Pages 보호](../report/assets/task_m900_584/stage3/pages-gate-proof.json), [checksum](../report/assets/task_m900_584/stage3/SHA256SUMS).
- Stage 3.1 준비 시 상대 링크 87개·고정 SHA 공개 문서 URL 3개, Stage 2 checksum 44개와 준비 증거 checksum을 확인했다. 승인한 main PR 본문은 GitHub reference/본문 검사, 준비 커밋의 변경 문서는 git diff --check를 통과했다.
- 새 서명·공증 DMG와 ARM/Intel VM 수용은 대기다. 최종 Mac 시험·원상복원, #480/#525 실제 판정, 동일 파일 공개/Sparkle/Homebrew도 [수용표](../tech/task_m900_584_release_acceptance.md)의 대기 상태를 유지한다. Stage 3 완료나 #584 전체 완료로 표시하지 않는다.

## main PR 게시와 통합 리뷰

#586은 게시 당시 Open / devel → main이었으며 source `5146d91e`가 승인한 기준과 일치했다. PR을 task artifact로 연결했다. GitHub full diff의 300-file 제한은 전체 paginated 파일 목록과 exact local diff로 보완했고, 792개 path 및 변경 blob SHA를 모두 대조했다. [통합 리뷰](../feedback/task_m900_584_pr586_review.md)에서 제품·배포 경계를 막을 문제를 발견하지 못했다. 기존 #580 문서의 EOF 빈줄 하나는 비차단 형식 참고로 기록했다.

새 [CI run 38176121965](https://github.com/postmelee/alhangeul-macos/actions/runs/38176121965)는 완료·success이며 Classify·Script syntax·macOS·Release helper 4개 모두 SUCCESS다. exact head `5146d91e`의 MERGEABLE/CLEAN을 병합 직전 다시 확인했다. 이전 #585의 결과로 대신하지 않고 [게시 증거](../report/assets/task_m900_584/stage3/main-pr/publication-proof.json)와 [새 CI](../report/assets/task_m900_584/stage3/main-pr/ci-observed.json)를 보존했다. 이후 승인한 범위에서 main 병합과 tag push를 각각 완료했으며 workflow 실행·설치·공개는 진행하지 않았다.

## 병합 후 source 확정

[main source](../report/assets/task_m900_584/stage3/main-merge/source-identity.json), [content gate](../report/assets/task_m900_584/stage3/main-merge/main-devel-content.log), [포함 PR 갱신](../report/assets/task_m900_584/stage3/main-merge/pr-analysis.json), [checksum](../report/assets/task_m900_584/stage3/main-merge/SHA256SUMS)을 보존했다. v0.2.2..실제 main의 병합 커밋은 35개이며 PR 번호가 있는 병합은 30개다. 기존 source 분석의 29개 PR에 main 운반 #586만 추가되었고 사용자 기능이나 해결 이슈를 중복 집계하지 않았다. main 기준 first-parent PR은 10개로 devel 기준 20개와 구분한다. 전체 helper·delta는 최종 main SHA로 갱신하되 raw 초안은 공개 본문으로 사용하지 않는다.

자동 helper는 #586을 upstream sync 후보, #585의 대상 #584를 해결 이슈로 추론했지만 실제 소유자 분류는 main 운반 / #584 수용 미완료다. 이 두 추론을 채택하지 않았으며 draft 생성 후 공개 전에 실제 Release 본문을 다시 보정·검증한다. 기존 기록과 자동 후보의 추론 차이를 제품 완료로 합산하지 않는다.

태그 생성 직전에는 로컬/원격 tag와 인증된 전체 Release 목록에 v0.2.3이 없었다. 별도 승인 후 [태그 검증](../report/assets/task_m900_584/stage3/tag/tag-verification.json)과 [workflow 운영 준비](../report/assets/task_m900_584/stage3/tag/workflow-readiness.json)를 기록했다. 필수 secret 이름 5개·서명 운영 변수·workflow 활성·기존 release ref 제한 없음을 확인했으며 secret 값이나 설정은 바꾸지 않았다. 실제 인증서/공증 인증 유효성은 workflow 실행 전까지 미검증이다. 최신 public 앱 v0.2.2, upstream latest v0.8.7도 새 조회로 확인했다. 서명·공증은 workflow 실행 시 다시 latest와 source 현재성을 확인한다. local/task584의 단계 기록은 로컬 커밋으로 유지하고 source tag에 임의로 섞지 않는다. #584는 전체 릴리즈 수용이 남아 OPEN이며 타스크 브랜치·관련 증거를 유지한다.

[준비안 검증](../report/assets/task_m900_584/stage3/main-merge/validation.json)은 변경 문서의 git diff --check, 상대 링크 116개, 기존/새 증거 checksum 23개, 새 JSON 및 실제 workflow 필드 7개 대조를 통과했다. 제품 tree가 그대로여서 로컬 앱/Rust rebuild와 새 DMG cache를 만들지 않았다. 추가 validation receipt를 포함한 최종 checksum도 다시 확인했다.
