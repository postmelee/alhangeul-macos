# Task M018 #188 Stage 8 작업 보고서

## 단계 목적

public `v0.1.1` build `2` 설치 사용자가 Sparkle 업데이트로 Quick Look/Thumbnail hotfix를 받을 수 있도록, 같은 short version `0.1.1`에서 respin build를 `3`으로 올리고 로컬 Release package smoke를 반복한다.

확인 시각: `2026-05-11 KST`

## 판단

`v0.1.1`은 이미 public appcast에 `sparkle:version=2`, `sparkle:shortVersionString=0.1.1`로 배포됐다. hotfix DMG를 같은 `0.1.1 (2)`로 덮어쓰면 기존 `0.1.1 (2)` 사용자에게는 새 업데이트로 보이지 않을 수 있다.

따라서 respin 기준은 다음과 같이 둔다.

| 항목 | 값 |
|------|----|
| `CFBundleShortVersionString` | `0.1.1` |
| 기존 public build | `2` |
| respin candidate build | `3` |
| Sparkle stable appcast 기대값 | `sparkle:shortVersionString=0.1.1`, `sparkle:version=3` |
| DMG 파일명 | `alhangeul-macos-0.1.1.dmg` |

## 변경 내용

| 파일 | 변경 |
|------|------|
| `Sources/HostApp/Info.plist` | `CFBundleVersion=3` |
| `Sources/QLExtension/Info.plist` | `CFBundleVersion=3` |
| `Sources/ThumbnailExtension/Info.plist` | `CFBundleVersion=3` |
| `.github/workflows/pr-ci.yml` | appcast helper 검증 build 값을 `3`으로 갱신 |
| `README.md` | 최신 공개 릴리즈를 `v0.1.1`로 갱신하고 respin build 기준 기록 |
| `docs/updates/v0.1.1.html` | Quick Look/Thumbnail crash hotfix를 사용자-facing 릴리즈 노트에 추가 |
| `mydocs/release/v0.1.1.md` | original public build `2`와 respin candidate build `3` 구분 |

## 로컬 검증 결과

| 항목 | 결과 |
|------|------|
| plist version/build matrix | OK, HostApp/QLExtension/ThumbnailExtension 모두 `0.1.1 (3)` |
| Sparkle appcast helper build `3` XML | OK, `sparkle:version=3`, `sparkle:shortVersionString=0.1.1`, XML lint 통과 |
| local Release package | OK, `scripts/package-release.sh 0.1.1` 통과 |
| local package checksum | `e87720ac0ae4aafa96cd1f86590aba4adb66f96dbf56eb8169053138e4cd12cb  alhangeul-macos-0.1.1.zip` |
| local Release app signing verify | OK, `codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app` 통과 |
| local Release app version/build | OK, `build.noindex/release/Alhangeul.app` 기준 app/preview/thumbnail 모두 build `3` |
| clean visual smoke install | OK, `/Applications/Alhangeul.app`에 build `3` local ad-hoc smoke app 설치 |
| installed app version/build | OK, `/Applications/Alhangeul.app` 기준 app/preview/thumbnail 모두 build `3` |
| active preview provider path | OK, `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex` |
| active thumbnail provider path | OK, `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex` |
| fresh sample folder | `/private/tmp/alhangeul-visual-smoke/20260511-092330/samples` |
| visual guide | `/private/tmp/alhangeul-visual-smoke/20260511-092330/VISUAL_CHECK.md` |
| direct preview helper | `/private/tmp/alhangeul-visual-smoke/20260511-092330/open-preview.command` |
| fresh thumbnail output | OK, 3개 HWP/HWPX sample 모두 `544 x 768` PNG 생성 |
| crash report check | OK, smoke setup 이후 새 `AlhangeulPreview`/`AlhangeulThumbnail` crash report 없음 |

첫 HWP sample의 첫 thumbnail 요청은 Stage 7과 동일하게 `No thumbnail created`로 끝났고, cache reset 후 2회차에서 정상 생성됐다. 나머지 HWP/HWPX sample은 1회차에서 thumbnail을 생성했다. 이는 등록 직후 Quick Look server warm-up으로 보고, extension crash와는 구분한다.

## public respin 전 남은 승인 지점

Stage 8은 source와 local smoke 준비 단계다. 다음 작업은 public release를 다시 쓰는 외부 영향 작업이므로 별도 승인 지점으로 남긴다.

1. `v0.1.1` tag를 Stage 8 이후 respin commit으로 이동할지 확정
2. `Release Publish DMG` workflow를 `version=0.1.1`, `draft=false`, `prerelease=false`로 재실행할지 확정
3. 기존 GitHub Release asset을 `--clobber`로 교체하는 방식 확정
4. stable Pages appcast를 build `3`으로 재배포하는 방식 확정
5. Homebrew Cask SHA256을 새 public DMG checksum으로 다시 갱신하는 방식 확정
6. Sparkle 업데이트 설치 후 `scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.1 --expected-build 3` 기본 모드로 active provider가 새 build `3` app 내부 `.appex`를 가리키는지 확인

## Stage 9 이월

build `3` local smoke 이후 About window의 `시스템 등록 확인 불가` 표시가 남아 Stage 9로 분리했다. 이미 `0.1.1 (3)` 설치 사용자가 생길 수 있으므로 다음 respin 후보는 build `4`로 올린다. 상세는 `task_m018_188_stage9.md`를 따른다.
