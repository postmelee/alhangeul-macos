# Task M900 #584 Stage 3 main 인계 준비 보고

## 현재 결과와 승인 범위

**Stage 3 준비 완료 / 단계 전체 수용 미완료.** 작업지시자의 “CI 상태를 다시 확인하고, 모두 통과했으면 PR #585를 병합한 뒤 #584 Stage 3 준비”에 따라 최신 CI를 확인하고 준비 PR을 병합했다. main 통합 PR의 초안·출처·Pages 영향과 이후 실행 입력을 준비했다. main PR 게시·병합, tag, 서명/공증 DMG 생성과 ARM/Intel VM 설치는 아직 실행하지 않았다.

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
| 중복 확인 | 열린 devel → main PR 없음, 원격 v0.2.3 tag 없음, v0.2.3 Release HTTP 404 |

Stage 1의 28개 분류를 유지하고 전체 merge ancestry와 추가 #585 원문·diff·CI를 대조했다. helper delta 초안은 build.noindex/task584/stage3/preparation에 만들었으며, main/tag의 최종 source 확정 뒤 전체 PR-analysis/delta helper를 다시 갱신한다. #585 준비 작업을 Mac 기능 구현과 중복 집계하거나 해결된 #584로 표시하지 않는다.

최초 content gate는 sandbox에서 Git 임시 객체 쓰기가 제한돼 exit 2였다. raw 실패 로그를 보존하고 Git 객체 생성 권한으로 재검증해 위 PASS를 얻었다. 제품 소스·index·branch를 바꾸는 merge로 통과시키지 않았다. 이번 source tree는 검증한 준비 PR과 같으므로 로컬 Rust/Xcode 빌드를 반복하지 않았다. 새 앱·DMG·빌드 cache는 생성하지 않았다.

## Pages·Sparkle 공개 보호

main 반영 시 기존 Docs-only Pages Deploy가 시작된다. main과 source에서 해당 workflow는 byte 동일하다. 새 v0.2.3 Release가 없는 현재 상태에서는 기존 asset gate가 deploy=false를 반환해 배포를 건너뛴다. draft 후보가 생겨도 public DMG 조건을 충족하지 않는다. workflow를 제거하거나 우회하지 않는다.

현재 public appcast를 새로 내려받아 0.2.2 / build 20과 기존 DMG URL을 확인했다. SHA256은 `8b0face06819d65f60cc6e3675244eaa1cccead997927c1f27c131d523313140`으로 Stage 2 조회와 같다. 공개 Pages·appcast·Homebrew 또는 앱 설치본은 변경하지 않았다.

## 준비한 실행 입력과 다음 승인

1. [main PR 초안](task_m900_584_main_pr_draft.md): 제목 **Release v0.2.3: Mac 설치 글꼴과 rhwp v0.8.7 소스 준비**, head devel `5146d91e`, base main `43b4e998`. 게시 직전 두 ref를 다시 확인한다. 게시와 CI 확인 후 정확한 head로 병합 승인을 받는다.
2. main 병합 후 실제 main SHA를 tag 대상으로 제시하고 **v0.2.3 tag 생성**을 별도로 승인받는다. 현재 준비 source를 최종 tag 대상이라고 확정하지 않는다.
3. **Release Publish DMG 실행**을 별도 승인받는다. ref=v0.2.3, version=0.2.3, previous_release_ref=v0.2.2, expected_rhwp_tag=v0.8.7, require_latest_rhwp=true, include_rhwp_in_title=false, draft=true, prerelease=false. 네 bundle build=21을 확인한다. upstream latest는 실행 직전 다시 확인한다.
4. 생성 후 실제 source/run/artifact/DMG SHA256·size와 파일/서명 검증 결과를 기록한다. 값을 임의로 채우지 않는다. 해당 동일 파일의 release-first-install.yml 실행은 실제 입력과 macos-15/arm64·macos-15-intel/x86_64를 제시해 승인받는다.

실행 입력의 미확정 main SHA·run/artifact/hash는 [입력표](../report/assets/task_m900_584/stage3/release-inputs.json)에 null로 남겼다. main PR 게시·병합은 [구현계획 §4](../plans/task_m900_584_impl.md)의 “영향을 설명한 뒤 게시/병합 승인을 받는다” 규칙을 따른다. tag·DMG 실행·설치·공개는 이후 각각의 gate다.

## 증거와 남은 수용

- [출처·시각·기준](../report/assets/task_m900_584/stage3/context.json), [#585 병합/CI](../report/assets/task_m900_584/stage3/pr585-merged.json), [content gate](../report/assets/task_m900_584/stage3/main-devel-content.log).
- [PR 분석 갱신](../report/assets/task_m900_584/stage3/pr-analysis.json), [Pages 보호](../report/assets/task_m900_584/stage3/pages-gate-proof.json), [checksum](../report/assets/task_m900_584/stage3/SHA256SUMS).
- 준비 문서의 상대 링크 87개·고정 SHA의 공개 문서 URL 3개, Stage 2 checksum 44개와 새 준비 증거 checksum을 확인했다. main PR 본문은 GitHub reference/본문 검사, 변경 문서는 git diff --check를 통과했다.
- 새 서명·공증 DMG와 ARM/Intel VM 수용은 대기다. 최종 Mac 시험·원상복원, #480/#525 실제 판정, 동일 파일 공개/Sparkle/Homebrew도 [수용표](../tech/task_m900_584_release_acceptance.md)의 대기 상태를 유지한다. Stage 3 완료나 #584 전체 완료로 표시하지 않는다.
