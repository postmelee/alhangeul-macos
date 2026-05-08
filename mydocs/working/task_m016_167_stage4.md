# Task #167 Stage 4 보고서

## 단계 목적

`rhwp` core와 bundled `rhwp-studio` asset을 `v0.7.10` 기준으로 갱신한 뒤, M16 release 직전 기준에서 앱 빌드와 native render smoke가 통과하는지 확인한다. 또한 살아있는 릴리스 기준 문서가 더 이상 `v0.7.9`를 현재 기준으로 설명하지 않도록 정리한다.

이번 단계는 실제 release package 생성, 서명, 공증, Homebrew Cask 게시를 수행하지 않는다. 해당 절차는 #166 release artifact/provenance 작업과 release workflow가 소유한다. 설치본 기준 Quick Look/Thumbnail smoke gate는 #151에서 별도 판정한다.

## 변경 파일

| 파일 | 내용 |
|------|------|
| `README.md` | MVP viewer의 upstream `rhwp-studio` snapshot 표기를 `v0.7.10`으로 갱신 |
| `mydocs/tech/project_architecture.md` | 현재 core lock 기준을 `v0.7.10` release tag와 resolved commit으로 갱신 |
| `mydocs/tech/core_release_compatibility.md` | 현재 Stable release 상태, Cargo source, artifact hash/size, Stage 4 검증 범위를 `v0.7.10` 기준으로 갱신 |
| `mydocs/manual/core_dependency_operation_guide.md` | core 운영 가이드의 현재 pin 설명을 `v0.7.10` 기준으로 갱신 |
| `mydocs/manual/build_run_guide.md` | WKWebView smoke 명령의 WASM 파일명을 `rhwp_bg-BZNodj2e.wasm`으로 갱신 |

## 빌드 검증

### Xcode project 생성

```bash
xcodegen generate
```

결과: 성공. `Alhangeul.xcodeproj`에는 tracked diff가 남지 않았다.

### HostApp Debug build

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: `** BUILD SUCCEEDED ** [14.016 sec]`

Xcode sandbox 환경에서 CoreSimulator service와 user Library log/cache 접근 경고가 출력되었지만 macOS HostApp build는 성공했다. 이 경고는 이번 변경의 컴파일 또는 링크 실패로 분류하지 않는다.

### Debug app bundle asset 확인

```bash
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/assets/index-BN69C-Lp.js
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css
find build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/fonts -name '*.woff2' -type f | wc -l
```

결과:

```text
35
```

### HostApp Release build

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: `** BUILD SUCCEEDED ** [26.801 sec]`

## Render smoke

```bash
./scripts/validate-stage3-render.sh
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=454739
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=69375
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=174843
```

기존 native renderer layout overflow 진단 로그는 일부 샘플에서 계속 출력된다. 명령은 exit code 0으로 완료했고 PNG 산출물은 `output/stage3-render/`에 생성되었다. 이 산출물은 검증 부산물이며 commit 대상이 아니다.

## 문서 기준 검증

살아있는 기준 문서와 스크립트에서 이전 release 기준이 남아 있는지 확인했다.

```bash
rg -n "v0\.7\.9|0fb3e6758b8ad11d2f3c3849c83b914684e83863|DtQ01XFR" \
  README.md mydocs/tech mydocs/manual scripts .github THIRD_PARTY_LICENSES.md \
  RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
```

결과: 검색 결과 없음.

`mydocs/working`과 `mydocs/report`의 과거 단계 보고서에는 당시 기준이었던 `v0.7.9` 기록이 남아 있다. 이는 이력 문서이므로 이번 단계에서 고치지 않았다.

## 추가 검증

```bash
scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
git diff --check
```

결과:

```text
OK: rhwp-studio assets verified at /private/tmp/rhwp-mac-task167/Sources/HostApp/Resources/rhwp-studio
OK: shared Swift code has no AppKit/UIKit dependencies
```

`git diff --check` 결과 whitespace 오류는 없었다.

## 판정

Stage 4 기준은 충족했다.

- `v0.7.10` core lock과 bundled `rhwp-studio` asset 기준으로 HostApp Debug/Release build가 통과했다.
- Debug app bundle에 `rhwp-studio` index, main JS, WASM, local override CSS, WOFF2 35개가 포함됨을 확인했다.
- native render smoke는 기존 샘플 3개에서 통과했다.
- release 기준 문서에서 현재 pin을 `v0.7.9`로 설명하는 항목을 제거했다.

다음 단계에서는 Stage 1-4 결과를 종합해 #167 최종 보고서와 PR 게시 전 검증을 정리한다.
