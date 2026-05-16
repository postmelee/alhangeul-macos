# Task M018 #184 Stage 1 완료 보고서

## 단계 목적

DMG 설치 창 안내 개선을 구현하기 전에 현재 `scripts/release.sh`의 DMG 생성 구조와 release workflow 실행 환경을 확인하고, Stage 2에서 적용할 layout 방식을 확정한다.

## 산출물

- `mydocs/working/task_m018_184_stage1.md`
  - Stage 1 조사 결과, 후보 비교, 확정 layout 기준, 검증 결과를 기록했다.

제품 코드와 release script는 아직 변경하지 않았다.

## 조사 결과

현재 `scripts/release.sh`는 `prepare_paths`에서 `DMG_STAGING_DIR`, `DMG_OUTPUT`, `CHECKSUM_OUTPUT`을 정하고, `create_dmg`에서 다음 두 항목만 staging한 뒤 `hdiutil create -srcfolder`로 바로 UDZO DMG를 만든다.

- `Alhangeul.app`
- `Applications -> /Applications` symlink

따라서 현재 DMG는 사용자가 앱을 Applications로 드래그해야 한다는 점과, 설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail extension이 등록된다는 점을 창 안에서 직접 보여주지 않는다.

릴리스 관련 workflow 확인 결과:

- `.github/workflows/release-rehearsal.yml`은 `macos-15`에서 `./scripts/release.sh --skip-notarize "$VERSION"`을 실행한다.
- `.github/workflows/release-publish.yml`은 `macos-15`에서 `./scripts/release.sh "$VERSION"`을 실행한다.
- 두 workflow 모두 같은 release script를 사용하므로 Stage 2 layout 변경은 rehearsal/public DMG에 공통 적용된다.

설치 안내 문구의 기존 진실 원천:

- `README.md`는 설치 후 `Alhangeul.app`을 한 번 실행하면 macOS가 Quick Look 및 Thumbnail extension을 발견하고 등록한다고 안내한다.
- `Casks/alhangeul-macos.rb` caveats도 앱을 한 번 실행하면 Quick Look 및 Thumbnail 확장이 등록된다고 안내한다.
- `release_distribution_guide.md`도 DMG를 열고 `Alhangeul.app`을 `/Applications`로 복사한 뒤 앱을 한 번 실행하는 기준을 이미 갖고 있다.

현재 source plist의 `CFBundleShortVersionString`은 HostApp, QLExtension, ThumbnailExtension 모두 `0.1.0`이다. Stage 3 rehearsal 명령은 version bump가 아직 없으면 `0.1.0`으로 실행하고, `0.1.1` bump가 먼저 merge되면 `0.1.1`로 실행한다.

## 후보 비교

| 후보 | 장점 | 리스크 | 판단 |
|------|------|--------|------|
| `.background` 이미지 + Finder icon view metadata | DMG 창을 열자마자 설치 흐름과 첫 실행 안내가 보인다. 일반 macOS DMG UX와 가장 가깝다. | Finder/AppleScript layout 설정이 CI/macOS runner 환경에 영향받을 수 있다. | 선택. macOS 기본 도구만 쓰고 실패를 숨기지 않는다. |
| DMG root README/텍스트 안내만 추가 | headless/CI에서 안정적이고 구현이 단순하다. | 사용자가 파일을 열지 않으면 설치 방향을 바로 이해하기 어렵다. | 보완책으로 포함. 단독안으로는 부족하다. |
| 안내 이미지 파일만 root에 추가 | Finder에서 파일명과 thumbnail로 일부 안내 가능하다. | 배경이 아니면 사용자가 직접 열어야 하고 icon view 크기에 따라 안내가 묻힌다. | 단독안으로 기각. |
| 외부 도구(`create-dmg`, `dmgbuild` 등) 도입 | 사례가 많고 기능이 풍부하다. | Homebrew/pip/network 의존성이 release workflow에 추가된다. | 기각. |
| 사전 생성 `.DS_Store` 바이너리 커밋 | CI에서 deterministic하게 layout을 재사용할 수 있다. | 창 크기/문구 수정이 어렵고 유지보수성이 낮다. | 기각. |

## 확정 기준

Stage 2에서는 다음 조합으로 구현한다.

1. `scripts/release.sh`에 DMG layout helper를 추가한다.
2. background PNG는 바이너리 asset을 직접 커밋하지 않고, repository script로 생성한다.
   - 후보 위치: `scripts/create-dmg-background.swift`
   - 사용 도구: `/usr/bin/swift`와 AppKit/CoreGraphics 기반 offscreen rendering
   - 생성 위치: staging 내부 `.background/alhangeul-dmg-background.png`
3. DMG root에는 접근성과 metadata 실패 시 보완을 위해 짧은 안내 텍스트 파일을 둔다.
   - 후보 파일명: `설치 안내.txt`
   - 내용: `Alhangeul.app`을 `Applications`로 드래그해 설치하고, 설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail이 활성화된다는 문구
4. Finder layout은 read-write DMG를 attach한 뒤 AppleScript로 설정한다.
   - icon view
   - toolbar/statusbar 숨김
   - window bounds
   - background picture
   - `Alhangeul.app`, `Applications`, `설치 안내.txt` icon position
5. layout 설정 실패는 official path에서 조용히 무시하지 않는다.
   - rehearsal/public workflow가 같은 path를 쓰므로 Stage 3에서 실패가 나면 Stage 2 구현을 보정한다.
   - 안내 텍스트 파일은 fallback UX 보완이지 layout 실패를 성공으로 간주하기 위한 장치가 아니다.

## Layout 초안

- DMG window size: 약 `720 x 460`
- background: 밝은 중립 배경, 과한 장식 없이 설치 흐름 중심
- app icon position: 왼쪽 하단 또는 왼쪽 중앙
- `Applications` symlink position: 오른쪽 하단 또는 오른쪽 중앙
- `설치 안내.txt` position: 하단 또는 우측 보조 위치
- primary copy:
  - `Alhangeul.app을 Applications로 드래그해 설치하세요.`
- secondary copy:
  - `설치 후 앱을 한 번 실행하면 Quick Look/Thumbnail이 활성화됩니다.`
- 짧은 영어 병기 후보:
  - `Drag Alhangeul.app to Applications.`
  - `Launch once to enable Quick Look and thumbnails.`

`Applications` symlink 이름은 기존 관례와 Homebrew/사용자 문서와의 일관성을 위해 유지한다. 한국어 안내는 background와 `설치 안내.txt`에 둔다.

## 검증 결과

```text
$ git status --short --branch
## local/task184
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
$ rg -n "create_dmg|hdiutil|Applications|DMG_STAGING_DIR|DMG_OUTPUT" scripts/release.sh mydocs/manual/release_distribution_guide.md
scripts/release.sh:188:  DMG_STAGING_DIR="$STAGING_DIR/dmg-root"
scripts/release.sh:197:  DMG_OUTPUT="$OUTPUT_DIR/$DMG_NAME"
scripts/release.sh:215:    hdiutil
scripts/release.sh:337:create_dmg() {
scripts/release.sh:342:  ln -s /Applications "$DMG_STAGING_DIR/Applications"
scripts/release.sh:344:  hdiutil create \
mydocs/manual/release_distribution_guide.md:107:- 설치 방식: DMG를 열고 `Alhangeul.app`을 `/Applications`로 복사
mydocs/manual/release_distribution_guide.md:119:- 앱을 `/Applications`에 복사한 뒤 한 번 실행했는가
```

```text
$ command -v osascript
/usr/bin/osascript

$ command -v swift
/usr/bin/swift

$ command -v SetFile
/usr/bin/SetFile
```

```text
$ plutil -extract CFBundleShortVersionString raw -o - Sources/HostApp/Info.plist
0.1.0

$ plutil -extract CFBundleShortVersionString raw -o - Sources/QLExtension/Info.plist
0.1.0

$ plutil -extract CFBundleShortVersionString raw -o - Sources/ThumbnailExtension/Info.plist
0.1.0
```

```text
$ find build.noindex/release -maxdepth 2 -type f -o -type l -o -type d
find: build.noindex/release: No such file or directory
```

기존 release output directory가 없어서 mounted DMG 실물 확인은 Stage 3으로 넘겼다. Stage 1 완료 기준은 source 구조와 구현 방식 확정이므로 이 실패는 단계 미완료 사유가 아니다.

```text
$ git diff --check
# 출력 없음, 성공
```

## 잔여 위험

- GitHub Actions `macos-15`에서 Finder AppleScript layout 설정이 로컬과 다르게 실패할 수 있다.
- Swift background generator가 AppKit offscreen rendering을 사용하므로 CI에서 font availability 또는 rendering 차이가 있을 수 있다.
- background text는 accessibility 측면에서 완전하지 않으므로 root 안내 텍스트 파일을 함께 둔다.
- Finder metadata가 signing/notarization/staple 후에도 보존되는지는 Stage 3 rehearsal와 #188 public DMG에서 다시 확인해야 한다.

## 다음 단계 영향

Stage 2는 `scripts/release.sh`와 새 background generator script를 수정한다. 구현 방향은 다음으로 고정한다.

- read-write temporary DMG 생성
- attach 후 Finder layout 설정
- UDZO final DMG 변환
- rehearsal/public mode 공통 적용
- root 안내 텍스트 포함

## 승인 요청

Stage 1 결과와 위 layout 방식 확정을 승인해주면 Stage 2 `DMG layout asset과 release script 구현`으로 진행한다.
