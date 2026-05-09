# Task M018 #208 Stage 5 보고서

## 단계 목적

#208의 build gate, Pages 안내, release 문서/template 변경을 현 HEAD 기준으로 통합 검증한다. 실제 public DMG 생성, Developer ID 서명, notarization, Sparkle stable appcast 게시, Homebrew tap 공개는 #188/#209 범위이므로 이번 단계에서는 실행하지 않았다.

## 통합 검증 요약

| 영역 | 검증 | 결과 |
|------|------|------|
| Shell syntax | `bash -n scripts/package-release.sh scripts/release.sh scripts/ci/*.sh` | 통과 |
| XcodeGen YAML | `ruby -e 'require "psych"; Psych.parse_file("project.yml")'` | 통과. 로컬 Ruby가 `ffi-1.13.1` extension 경고를 출력했지만 YAML parse는 성공 |
| Git diff hygiene | `git diff --check` | 통과 |
| Release note template | `scripts/ci/write-release-notes.sh 0.1.1 <dummy-sha> build.noindex/release/release-notes-0.1.1-stage5.md` | 통과 |
| Release note heading gate | `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1-stage5.md` | 통과 |
| Sparkle appcast dry-run | `scripts/ci/write-sparkle-appcast.sh ... --output build.noindex/release/appcast-stage5.xml` + `xmllint --noout` | 통과 |
| Pages 정적 확인 | `curl -s http://127.0.0.1:8765/`, `/updates/` + `rg` | v0.1.1 direct DMG 링크, Intel Mac/Apple Silicon 단일 DMG 안내, main 기준 feature 영상 자산 확인 |
| 정책 문구 검색 | `rg -n "Intel Mac / Apple Silicon 선택 UI\|아키텍처별.*DMG\|on_arm\|on_intel\|분리 DMG\|서로 다른.*DMG\|latest/download/alhangeul-macos-0.1.0.dmg" ...` | 남은 항목은 모두 “분리하지 않는다/선택 UI 없이 단일 DMG” 정책 문구 또는 v0.1.0 과거 릴리즈 고정 링크로 확인 |
| 기존 stale app 검증 | `scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app` | 실패. 이 app은 #208 수정 전 arm64-only stale 산출물이므로 현재 검증 기준으로 사용하지 않음 |
| Stage 2 package 산출물 재확인 | `scripts/ci/verify-universal-macos-app.sh /private/tmp/alhangeul-task208-package/release/Alhangeul.app` | 통과 |
| 현 HEAD package 재실행 | `ALHANGEUL_BUILD_ROOT=/private/tmp/alhangeul-task208-stage5-package scripts/package-release.sh 0.1.1` | 통과 |
| 현 HEAD universal app 검증 | `scripts/ci/verify-universal-macos-app.sh /private/tmp/alhangeul-task208-stage5-package/release/Alhangeul.app` | 통과 |

## 현 HEAD package 결과

`scripts/package-release.sh 0.1.1`은 다음 build setting으로 Release app을 생성했다.

```text
-destination generic/platform=macOS
ARCHS=arm64 x86_64
ONLY_ACTIVE_ARCH=NO
```

검증된 실행 파일:

| 실행 파일 | 확인된 architecture |
|-----------|---------------------|
| `Alhangeul.app/Contents/MacOS/Alhangeul` | `x86_64 arm64` |
| `Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` | `x86_64 arm64` |
| `Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail` | `x86_64 arm64` |

산출물:

```text
/private/tmp/alhangeul-task208-stage5-package/release/Alhangeul.app
/private/tmp/alhangeul-task208-stage5-package/release/alhangeul-macos-0.1.1.zip
SHA256: cddb79e149463e17c6e642ad562ca62392b69af28779b1af57412cdca805649f
```

## 해석

- #208 수정 전 생성된 `build.noindex/release/Alhangeul.app`는 arm64-only라 실패한다. 이 파일은 현재 release gate를 검증하는 기준으로 쓰면 안 된다.
- 현 HEAD에서 새로 생성한 package 산출물은 app 본체와 Quick Look/Thumbnail extension 모두 universal 기준을 만족한다.
- Pages는 선택 UI 없이 direct DMG 버튼을 유지하고, v0.1.1 단일 DMG가 Intel Mac과 Apple Silicon Mac에서 같은 파일임을 안내한다.
- GitHub Release note template, release record, release manuals는 Sparkle appcast와 Homebrew Cask가 같은 public universal DMG URL을 유지한다는 전제로 정리됐다.

## #188 handoff

#188 public release 실행 시 다음을 반복해야 한다.

- `scripts/release.sh 0.1.1` 또는 `Release Publish DMG` workflow로 signed/notarized public DMG 생성
- public DMG 내부 `Alhangeul.app`, `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex` 실행 파일의 `arm64 + x86_64` slice 재확인
- public DMG SHA256 기록
- signed/notarized public DMG의 Gatekeeper/staple 검증
- Finder Quick Look/Thumbnail 설치본 smoke 반복
- 실제 Intel Mac 실기기 smoke 실행 여부와 결과 또는 미실행 사유 기록
- Pages latest download, Sparkle appcast enclosure, GitHub Release asset URL이 같은 public DMG 기준인지 확인

## #209 handoff

#209 Homebrew 공개 배포 시 다음을 지켜야 한다.

- #188에서 확정된 public universal DMG URL과 SHA256만 Cask에 사용
- `on_arm`/`on_intel`로 다른 DMG URL을 나누지 않음
- `postmelee/homebrew-tap` tap context에서 `brew style --cask`, `brew audit --cask`, install/uninstall smoke 수행
- tap 검증 완료 전에는 README, Pages, GitHub Release/릴리즈 노트에 Homebrew 설치 명령을 확정 설치 경로로 안내하지 않음

## 남은 작업

#208 구현/문서 변경과 Stage 5 통합 검증은 완료됐다. 다음 단계는 최종 보고서 작성, 최종 커밋 정리, publish branch/PR 준비다.

## 최종 보고 승인 요청

최종 보고 단계에서 #208 전체 변경 요약, 검증 결과, #188/#209 handoff, 남은 위험을 정리한다.
