# Task M018 #184 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 `background PNG 생성 스크립트 + Finder icon view metadata + root 안내 텍스트` 방식으로 DMG 설치 안내 layout 생성 경로를 구현한다. 기존 public release의 signing, notarization, staple, Gatekeeper, checksum 순서는 유지한다.

## 산출물

- `scripts/release.sh`
  - 총 512라인
  - DMG staging helper, install note 생성, Swift background generator 호출, Finder layout AppleScript, RW DMG attach/UDZO convert 경로를 추가했다.
- `scripts/create-dmg-background.swift`
  - 총 171라인
  - DMG background PNG를 staging 내부에 생성하는 Swift/AppKit 스크립트를 추가했다.

## 변경 내용

`scripts/release.sh`의 DMG 생성 경로를 다음 순서로 바꿨다.

1. `prepare_dmg_staging`
   - `Alhangeul.app` 복사
   - `Applications -> /Applications` symlink 생성
   - `설치 안내.txt` 생성
   - `.background/alhangeul-dmg-background.png` 생성
2. `hdiutil create -format UDRW -fs HFS+`
   - Finder metadata를 적용할 read-write temporary DMG를 만든다.
3. `hdiutil attach`
   - staging mount point에 attach한다.
4. `apply_dmg_finder_layout`
   - Finder icon view, window bounds, toolbar/statusbar 숨김, background picture, icon position을 AppleScript로 설정한다.
5. `hdiutil detach`
   - layout metadata를 포함한 뒤 detach한다.
6. `hdiutil convert -format UDZO`
   - 최종 rehearsal/public DMG 파일명으로 압축 이미지 변환한다.

추가한 안내 문구:

- background primary: `Alhangeul.app을 Applications로 드래그해 설치하세요.`
- background secondary: `Drag Alhangeul.app to Applications.`
- background first-run notice: `설치 후 앱을 한 번 실행하면 Quick Look/Thumbnail이 활성화됩니다.`
- root guide: `설치 후 Alhangeul.app을 한 번 실행하면 macOS가 Quick Look 및 Thumbnail 확장을 등록합니다.`

`swift`가 sandbox 환경에서 기본 module cache를 홈 디렉터리에 쓰지 않도록 `SWIFT_MODULE_CACHE_DIR`을 release staging 아래로 지정했다. 이 보정은 CI에서도 cache 위치를 release artifact staging 내부로 고정한다.

## Public Release 영향

- `create_dmg` 이후의 `sign_dmg`, `notarize_and_staple_dmg`, `verify_release_artifacts`, `write_checksum` 호출 순서는 유지했다.
- rehearsal mode와 public mode는 같은 `create_dmg` path를 사용한다.
- public mode credential guard는 기존처럼 build 전에 실패한다.
- 실제 signed/notarized public DMG 생성과 GitHub Release 게시, appcast/Cask 갱신은 수행하지 않았다.

## 검증 결과

```text
$ git status --short --branch
## local/task184
 M scripts/release.sh
?? scripts/create-dmg-background.swift
```

```text
$ bash -n scripts/release.sh
# 출력 없음, 성공
```

```text
$ ./scripts/release.sh --help
Usage: ./scripts/release.sh [options] <version>

Options:
  --skip-notarize    Build a local rehearsal DMG without notarization or staple.
  --output <dir>     Write artifacts to the given directory. Defaults to build.noindex/release.
  --keep-staging     Keep intermediate files after the script exits.
  -h, --help         Show this help.
```

```text
$ env -u ALHANGEUL_DEVELOPER_ID_APPLICATION -u ALHANGEUL_NOTARY_PROFILE ./scripts/release.sh 0.1.1
ERROR: ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release
```

위 실패는 의도한 fail-fast 결과다. public mode에서 Developer ID signing identity가 없으면 build, DMG 생성, notarization으로 진행하지 않는다.

```text
$ swift -module-cache-path build.noindex/SwiftModuleCache scripts/create-dmg-background.swift build.noindex/stage2-background-test.png
# 출력 없음, 성공
```

```text
$ file build.noindex/stage2-background-test.png
build.noindex/stage2-background-test.png: PNG image data, 720 x 460, 8-bit/color RGBA, non-interlaced
```

생성된 background PNG를 시각 확인했다. 한국어/영어 설치 문구와 첫 실행 안내가 보이며, app icon과 Applications icon이 놓일 위치 사이에 drag arrow가 표시된다.

```text
$ shellcheck scripts/release.sh
# 출력 없음, 성공
```

```text
$ git diff --check
# 출력 없음, 성공
```

## 잔여 위험

- Finder AppleScript layout은 실제 mounted DMG에서만 최종 확인할 수 있다. Stage 3에서 rehearsal DMG를 생성하고 mount해 검증한다.
- GitHub Actions `macos-15`에서 Finder layout AppleScript가 로컬과 다르게 실패할 가능성은 남아 있다.
- `hdiutil convert` 이후 `.DS_Store`/background metadata 보존은 Stage 3 rehearsal DMG에서 확인해야 한다.
- public signing/notarization/staple 이후 layout 보존은 #188 public release 실행 때 다시 확인해야 한다.

## 다음 단계 영향

Stage 3에서는 현재 source plist version이 아직 `0.1.0`이므로, version bump가 선행되지 않은 상태라면 `./scripts/release.sh --skip-notarize 0.1.0`으로 rehearsal DMG를 생성한다. `0.1.1` version bump가 먼저 반영되면 `0.1.1`로 실행한다.

확인 항목:

- rehearsal DMG 생성
- `hdiutil verify`
- checksum 검증
- mounted volume 내부의 `Alhangeul.app`, `Applications`, `설치 안내.txt`, `.background/alhangeul-dmg-background.png`
- Finder 창에서 background, icon position, 설치 안내, 첫 실행 안내 표시

## 승인 요청

Stage 2 결과를 승인해주면 Stage 3 `Rehearsal DMG 생성과 mounted layout smoke`로 진행한다.
