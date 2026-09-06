# Task M900 #494 Stage 1 완료보고서

## 단계 목적

[구현계획서](../plans/task_m900_494_impl.md)의 Stage 1에 따라 최신 release context와 main/devel content를 확인하고, 앱·extension 및 release workflow 입력을 `v0.1.11 (17)`, rhwp `v0.8.6` 기준으로 정렬한다.

2026-09-06 작업지시자가 구현계획과 Stage 1 진행을 승인했다. 작업 브랜치는 `local/task494`이며 단계 시작 HEAD는 `12cbbe7a531e2b21d4e6092997c1b7cde5b1e47c`다.

## 산출물

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Info.plist` | version `0.1.10 → 0.1.11`, build `16 → 17` |
| `Sources/QLExtension/Info.plist` | version `0.1.10 → 0.1.11`, build `16 → 17` |
| `Sources/ThumbnailExtension/Info.plist` | version `0.1.10 → 0.1.11`, build `16 → 17` |
| `.github/workflows/release-rehearsal.yml` | 기본 입력 `0.1.11`, `v0.1.10`, `v0.8.6` |
| `.github/workflows/release-publish.yml` | 기본 입력 `0.1.11`, `v0.1.10`, `v0.8.6` |
| `mydocs/plans/task_m900_494.md`, `task_m900_494_impl.md` | 구현계획 승인 및 Stage 1 결과 상태 반영 |
| `mydocs/orders/20260906.md` | Stage 1 완료·Stage 2 승인 대기 반영 |
| 이 보고서 | release context, content 보존 판정과 검증 결과 기록 |

## 본문 변경 정도와 무손실 여부

제품 metadata와 workflow 변경은 **5개 파일, 12줄 추가·12줄 삭제**다. 세 plist는 각 2개 version key, 두 workflow는 각 3개 input default만 바뀌었다.

변경 전후 plist를 구조적으로 비교해 version/build 외 key·value가 동일함을 확인했다. workflow도 원본의 승인된 default 세 값만 치환한 구조와 현재 YAML 전체를 비교해 같음을 확인했다. 따라서 trigger, permissions, environment, concurrency, job/step, `require_latest_rhwp`, `include_rhwp_in_title`, draft/prerelease 정책은 유지된다.

core lock, Cargo dependency/lock, Swift build-info, bundled Studio/WASM, `project.yml`과 generated Xcode project는 변경하지 않았다. README·Pages·Cask의 현재 공개 버전 안내는 Stage 2 이후 해당 절차에서 정렬한다.

## 검증 결과

2026-09-06 live 조회 및 로컬 검증 결과다. 원격 조회·fetch는 성공했고 새로운 branch 이동은 없었다.

| 확인 항목 | 결과 |
|-----------|------|
| 최신 공개 앱 | `v0.1.10`, non-draft / non-prerelease, 게시 `2026-08-14T15:19:19Z` |
| 최신 공개 upstream | `v0.8.6`, non-draft / non-prerelease, 게시 `2026-09-02T03:00:31Z` |
| 새 tag | `git ls-remote --tags origin refs/tags/v0.1.11` 결과 없음 |
| Issue #494 | `OPEN`, `Release Operations` |
| previous_release_ref | `v0.1.10` / `fafed425d4b87162c2188d1384d618adc2211eb6` |
| origin/main | `7162a80fdadf4e121623be1da9c1a7d933ef0fac` |
| origin/devel | `eec7869fb958aec8e30df3a4e6cdaf67253c5a5a` |
| core / Cargo / Studio | `v0.8.6` / `f1f9c6ae58344ee9368996d3543f76b9345cf227`로 일치 |

### main/devel content 판정

`origin/main...origin/devel`의 이력 차이는 `5 / 69`다. main 전용 5개 commit은 모두 merge이며 non-merge commit은 없다.

| main 전용 PR | merge commit | merge tree와 두 번째 parent tree |
|--------------|--------------|----------------------------------|
| #477 | `7162a80` | 동일 |
| #476 | `fafed42` | 동일 |
| #452 | `26f3104` | 동일 |
| #450 | `ab7a74b` | 동일 |
| #446 | `1e7f5df` | 동일 |

공통 조상은 `12234b63c4d0e4ab82fb4b3c30fdcbd585134e8a`이며 현재 main과 공통 조상의 전체 tree는 모두 `496a625684055f69dd5e07193de1be31b1aae4d3`다. PR #477 종료 정리의 source commit이 공통 조상이므로 해당 내용은 devel 이력에 이미 포함돼 있다. 이후 devel의 PR #478 종료 기록과 앱 수정은 이 기준 위에 누적됐다.

따라서 **현재 후보의 main → devel 역병합은 필요하지 않다.** branch나 content를 바꾸지 않고 이력 차이를 허용한다. Stage 4에서 실제 release PR 직전 main/devel이 이동했는지 다시 확인한다.

`v0.1.10..HEAD`의 first-parent merge PR은 #478, #481, #483, #485, #486, #487, #489, #490, #493, #491 총 10개다. Stage 2에서 이 목록의 사용자 변화·운영 기록·해결/관련 이슈를 구분한다.

### 로컬 검증

| 검증 | 결과 |
|------|------|
| 세 plist `plutil -lint` | 모두 OK |
| 세 plist version/build 추출 | 모두 `0.1.11` / `17` |
| plist 구조 비교 | version/build 두 key만 변경 |
| 두 workflow Psych parse | 모두 OK |
| workflow 전체 구조 비교 | 승인된 input default 세 값만 변경 |
| `scripts/verify-rhwp-core-build-info.sh` | canonical build-info와 core lock 일치 |
| `scripts/verify-rhwp-studio-assets.sh --tag v0.8.6 --commit f1f9c6a...` | bundled asset 검증 통과 |
| core lock·Cargo.toml·Cargo.lock·Studio identity 대조 | tag/commit 일치 |
| `git diff --check` | 통과 |

검증 출력 요약:

```text
HostApp: 0.1.11 (17); only two version keys changed
QLExtension: 0.1.11 (17); only two version keys changed
ThumbnailExtension: 0.1.11 (17); only two version keys changed
release-rehearsal.yml: only the three approved workflow defaults changed
release-publish.yml: only the three approved workflow defaults changed
RhwpCoreBuildInfo.swift matches rhwp-core.lock
rhwp-studio assets verified
main content is already in the common ancestor
```

원본 로컬 근거는 `build.noindex/task494/stage1/branch-context.json`, `verification.log`, `identity-check.log`, `workflow-check.log`에 있다. Ruby 실행 시 기존 `ffi-1.13.1` native extension 경고가 출력됐지만 YAML 구문·구조 검증은 모두 exit 0으로 통과했다. 이 단계에서 개발 도구 환경은 변경하지 않았다.

## 잔여 위험

- Stage 1은 version/workflow identity 정렬이다. 새 앱 build, Rust artifact hash, GUI·Finder·signed DMG 설치 검증은 아직 수행하지 않았으며 Stage 3~5 범위다.
- main/devel이나 upstream latest가 이동하면 지금의 content 판정과 릴리스 입력을 실행 시점에 재확인해야 한다.
- README·Pages와 public Cask는 현재 공개 v0.1.10 기준이다. 아직 새 release note, tag, DMG 또는 public 배포가 생성된 상태가 아니다.

## 다음 단계 영향

Stage 2에서 `mydocs/release/v0.1.11.md`와 포함 PR 분석을 작성하고 README·Pages·GitHub Release 본문 후보를 정렬한다. Issue #480 항목은 안전 차단 반영과 남은 암호 저장 구현을 구분하고, upstream Issue #6635 항목의 repository 소속을 보정한다. 이전 릴리스 종료 정리와 개발·배포 항목은 새 사용자 기능으로 나열하지 않는다.

## 승인 요청

Stage 1 변경과 검증을 완료했다. **Stage 2: 포함 PR 분석과 릴리스 문서 준비**로 진행할지 승인을 요청한다. 다음 단계는 문서 후보 작성이며 workflow 실행·tag 생성·public 배포는 해당 실행 승인 범위에서 진행한다.
