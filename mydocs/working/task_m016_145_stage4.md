# Task M016 #145 Stage 4 보고서

## 단계 목적

`scripts/package-release.sh 0.1.0`으로 Release package staging app과 개발/검증용 zip을 생성하고, app bundle 안에 HostApp, Quick Look Preview extension, Thumbnail extension, bundled `rhwp-studio` 필수 asset이 포함되는지 확인한다.

이번 단계는 local archive validation이다. public DMG rehearsal, Developer ID signing, notarization, Gatekeeper public assessment, GitHub Release upload, Homebrew Cask checksum 교체는 실행하지 않았다.

## 실행 산출물

```bash
./scripts/package-release.sh 0.1.0
```

결과: 성공.

주요 출력:

```text
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
** BUILD SUCCEEDED ** [26.335 sec]
e21542e8b997717e1c7388d2bd557007bccf39d3d78bb3fc80a78e79e45b5f6c  alhangeul-macos-0.1.0.zip
```

Xcode/CoreSimulator 관련 sandbox 경고가 출력되었지만 macOS Release build와 package 생성은 성공했다. 해당 경고는 iOS Simulator service/log 접근 경고이며 이번 packaging 실패로 분류하지 않는다.

## artifact 정보

| artifact | 위치 | 크기 | SHA256 |
|----------|------|------|--------|
| staging app | `build.noindex/release/Alhangeul.app` | `108M` | 별도 checksum 파일 없음 |
| 개발/검증용 zip | `build.noindex/release/alhangeul-macos-0.1.0.zip` | `57M` (`60231843` bytes) | `e21542e8b997717e1c7388d2bd557007bccf39d3d78bb3fc80a78e79e45b5f6c` |

zip은 `Alhangeul.app/` parent directory를 포함한다.

```text
Archive:  build.noindex/release/alhangeul-macos-0.1.0.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
        0  05-07-2026 09:21   Alhangeul.app/
        0  05-07-2026 09:21   Alhangeul.app/Contents/
```

## bundle 포함 검증

### app bundle과 extension

```bash
test -d build.noindex/release/Alhangeul.app
test -f build.noindex/release/alhangeul-macos-0.1.0.zip
find build.noindex/release/Alhangeul.app/Contents/PlugIns -maxdepth 1 -type d -name '*.appex' -print | sort
```

결과:

```text
build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex
build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex
```

구현계획서의 Stage 4 검증 예시는 `AlhangeulQuickLook.appex`였지만 실제 product bundle name은 `AlhangeulPreview.appex`다. Stage 4에서 구현계획서 검증 명령도 실제 산출물명으로 보정했다.

### bundle identifier와 version

| bundle | identifier | version |
|--------|------------|---------|
| HostApp | `com.postmelee.alhangeul` | `0.1.0` |
| Preview appex | `com.postmelee.alhangeul.QLExtension` | `0.1.0` |
| Thumbnail appex | `com.postmelee.alhangeul.ThumbnailExtension` | `0.1.0` |

HostApp `CFBundleVersion`은 `1`이다.

### bundled rhwp-studio

```bash
test -f build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
test -f build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm
test -f build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/assets/index-BN69C-Lp.js
test -f build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/assets/index-ro3nVBB2.css
test -f build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/manifest.json
find build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio/fonts -maxdepth 1 -name '*.woff2' -type f | wc -l
scripts/verify-rhwp-studio-assets.sh build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio
```

결과:

```text
35
OK: rhwp-studio assets verified at build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio
```

bundle 내부 manifest 기준:

| 항목 | 값 |
|------|----|
| `source_release_tag` | `v0.7.10` |
| `source_resolved_commit` | `62a458aa317e962cd3d0eec6096728c172d57110` |
| WASM | `assets/rhwp_bg-BZNodj2e.wasm` |
| main JS | `assets/index-BN69C-Lp.js` |
| main CSS | `assets/index-ro3nVBB2.css` |

### localization resource

```bash
find build.noindex/release/Alhangeul.app/Contents/Resources -maxdepth 2 \( -name 'InfoPlist.strings' -o -name 'rhwp-studio' \) -print | sort
```

결과:

```text
build.noindex/release/Alhangeul.app/Contents/Resources/en.lproj/InfoPlist.strings
build.noindex/release/Alhangeul.app/Contents/Resources/ko.lproj/InfoPlist.strings
build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio
```

## signing 검증

```bash
codesign --verify --deep --strict --verbose=2 build.noindex/release/Alhangeul.app
codesign -dv --verbose=4 build.noindex/release/Alhangeul.app
```

결과:

```text
build.noindex/release/Alhangeul.app: valid on disk
build.noindex/release/Alhangeul.app: satisfies its Designated Requirement
Signature=adhoc
TeamIdentifier=not set
Sealed Resources version=2 rules=13 files=62
```

이 결과는 `Sign to Run Locally` package 산출물 기준으로 유효하다. public 배포 가능성을 의미하지 않으며, Developer ID signing/notarization/staple/Gatekeeper 검증은 public release 단계에서 별도로 수행해야 한다.

## 추가 검증

```bash
git diff --check
```

결과: 통과.

## 판정

Stage 4 기준은 충족했다.

- Release package staging app과 개발/검증용 zip이 `build.noindex/release` 아래에 생성되었다.
- zip checksum을 기록했다.
- HostApp, Preview appex, Thumbnail appex가 app bundle 안에 포함되었다.
- bundled `rhwp-studio` 필수 entrypoint와 WOFF2 35개가 app bundle 안에 포함되었다.
- local signing/sealed resource 검증은 통과했다.
- public DMG, Developer ID signing, notarization, Gatekeeper public assessment는 실행하지 않았고 Stage 5 잔여 조건으로 남긴다.

다음 단계는 Stage 5 `최종 보고와 후속 gate 연결`이다.
