# Task M019 #230 최종 보고서

## 작업 요약

- 이슈: #230 앱/DMG 용량 최적화를 위한 아키텍처별 배포와 Rust core 공유 구조 검토
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task230`
- 작업 위치: `/private/tmp/rhwp-mac-task230`
- 기준 브랜치: `devel-webview`
- 단계 수: 5단계
- 목적: `v0.1.1` public DMG와 app bundle 용량 증가 원인을 수치로 재확인하고, arch별 DMG, Rust core shared 구조, build setting 최적화 후보를 운영 비용과 함께 비교

## 결론

`v0.1.x`에서는 단일 universal DMG 정책을 유지하고, arch별 DMG 분리나 shared dynamic Rust framework 전환보다 `DEAD_CODE_STRIPPING=YES` 적용 검증을 우선하는 것을 권고한다.

근거:

- arch별 DMG는 local-only DMG 기준 `29.6-31.6%` download size 절감이 있었지만, Pages/Sparkle/Homebrew/GitHub Release 운영 표면을 모두 바꿔야 한다.
- `DEAD_CODE_STRIPPING=YES`는 단일 universal DMG 정책을 유지하면서 local-only DMG 기준 `45.7%` 절감 후보를 보였다.
- postprocessing strip까지 더해도 `45.7% -> 47.5%`로 추가 절감은 작아, 먼저 `DEAD_CODE_STRIPPING=YES` 단독 기능 smoke와 signed/notarized release 검증이 필요하다.
- shared dynamic Rust framework는 구조적으로 가능성이 있지만 rpath, signing, notarization, Sparkle update, extension load 검증 폭이 커서 `v0.1.x` 즉시 후보로는 부적합하다.

## 주요 측정 결과

### App bundle 기준

| 후보 | app KiB | universal 대비 |
|------|---------|----------------|
| current universal | `192300` | - |
| arm64-only | `113660` | `40.9%` 절감 |
| x86_64-only | `118240` | `38.5%` 절감 |
| universal + `DEAD_CODE_STRIPPING=YES` | `80424` | `58.2%` 절감 |
| universal + `DEAD_CODE_STRIPPING=YES` + postprocessing strip | `71200` | `63.0%` 절감 |

### DMG download 기준

모든 값은 local-only compressed DMG 기준이다. public signed/notarized DMG가 아니다.

| 후보 | DMG bytes | universal 대비 |
|------|-----------|----------------|
| current universal | `92949438` | - |
| arm64-only | `63565461` | `31.6%` 절감 |
| x86_64-only | `65460538` | `29.6%` 절감 |
| universal + manual `strip -x` | `88243712` | `5.1%` 절감 |
| universal + `DEAD_CODE_STRIPPING=YES` | `50425282` | `45.7%` 절감 |
| universal + `DEAD_CODE_STRIPPING=YES` + postprocessing strip | `48835652` | `47.5%` 절감 |

### 실행 파일 기준

| 후보 | HostApp bytes | Preview bytes | Thumbnail bytes | 합계 |
|------|---------------|---------------|-----------------|------|
| current universal | `53366456` | `51450544` | `51519344` | `156336344` |
| arm64-only | `25890312` | `24941152` | `24977184` | `75808648` |
| x86_64-only | `27455984` | `26501320` | `26536816` | `80494120` |
| `DEAD_CODE_STRIPPING=YES` | `15173256` | `13239424` | `13359664` | `41772344` |
| `DEAD_CODE_STRIPPING=YES` + postprocessing strip | `10714376` | `10774816` | `10840592` | `32329784` |

## 원인 요약

현재 Rust bridge는 `RustBridge/Cargo.toml`의 `crate-type = ["staticlib"]`로 빌드된다. `scripts/build-rust-macos.sh`는 arm64/x86_64 staticlib를 `Frameworks/universal/librhwp.a`로 합친 뒤 static library 기반 `Rhwp.xcframework`를 만든다.

`project.yml`에서 HostApp, QLExtension, ThumbnailExtension은 모두 같은 `Rhwp.xcframework`를 `embed: false`로 링크한다. `otool -L` 기준으로 세 실행 파일은 `Rhwp` dynamic dependency를 갖지 않고, Rust code가 각각 정적으로 포함된다.

Stage 2에서 current universal 실행 파일 세 개가 각각 약 `51-53 MB`였고, arch별 단일 slice에서는 각각 약 `24-27 MB`였다. 이는 universal slice 증가와 Rust staticlib 정적 중복 링크가 `v0.1.1` 용량 증가의 핵심이라는 이슈 가설과 일치한다.

Stage 4에서 `DEAD_CODE_STRIPPING=YES`를 켠 local-only build가 세 실행 파일 합계를 `156336344 bytes`에서 `41772344 bytes`로 줄였다. 따라서 현재 빌드에서는 사용하지 않는 Rust/native code가 final executable에 크게 남아 있었다고 판단한다.

## 후보별 판단

| 후보 | 장점 | 비용/위험 | 권고 |
|------|------|-----------|------|
| 단일 universal DMG 유지 | Pages/Sparkle/Homebrew/Release 정책 유지 | 용량 문제는 그대로 남음 | 현 정책 baseline |
| 단일 universal + `DEAD_CODE_STRIPPING=YES` | 가장 큰 절감, 운영 표면 변경 작음 | HWP/HWPX render, QL/Thumbnail, signing/notarization smoke 필요 | 1순위 후속 구현 후보 |
| 단일 universal + postprocessing strip | 추가 `1.8%p` DMG 절감 | dSYM/symbolication 영향 증가 | `DEAD_CODE_STRIPPING=YES` 검증 후 후순위 |
| arch별 DMG 분리 | download size `29.6-31.6%` 절감 | Pages UX, Sparkle enclosure, Homebrew `on_arm/on_intel`, 사용자 오선택 대응 필요 | 당장 비권고 |
| Rust LTO/strip profile | staticlib artifact `80.0%` 절감 | full app/DMG 기준 미검증, build time/lock/symbol 영향 | 별도 spike 후보 |
| shared dynamic Rust framework | 정적 중복 구조 해결 가능성 | rpath, nested signing, notarization, Sparkle update, extension load 검증 폭 큼 | `v0.2+` 구조 작업 후보 |

## 후속 작업 후보

이슈 생성은 수행하지 않았다. 필요 시 별도 승인 후 등록한다.

1. `DEAD_CODE_STRIPPING=YES` Release 설정 적용 및 smoke
   - `project.yml` Release setting 또는 release script 적용 위치 결정
   - HostApp viewer, PDF export, Quick Look preview, Thumbnail smoke
   - signed/notarized DMG에서 `verify-universal`, `codesign`, `spctl`, `stapler` 검증
   - Sparkle update archive 영향 확인
2. Rust release profile LTO/strip full app 검증
   - `lto`, `codegen-units`, `panic`, `strip` profile 조합을 실제 app link와 DMG size로 비교
   - `rhwp-core.lock` artifact hash/size 운영 영향 정리
3. `scripts/release.sh --skip-notarize` Finder layout 안정화
   - Stage 3에서 AppleScript `toolbar visible` 설정 실패가 발생했다.
   - CI/agent 환경에서도 rehearsal DMG가 안정적으로 생성되도록 layout fallback 또는 headless 경로 검토
4. shared dynamic Rust framework feasibility task
   - build setting 최적화 후에도 용량 문제가 남을 때 별도 구조 변경 작업으로 분리
   - `Rhwp.framework` install name, embed/sign 순서, extension rpath, Sparkle update 후 load smoke 포함

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `3ce279a` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `b80265d` | 구현 계획서 작성 |
| Stage 1 | `d351614` | release 구조와 용량 측정 기준 정리 |
| Stage 2 | `74bb5b8` | universal과 arch별 app bundle 용량 측정 |
| Stage 3 | `67ec8bf` | arch별 DMG 절감량과 배포 영향 비교 |
| Stage 4 | `12b4dd5` | Rust core 공유 구조와 빌드 최적화 후보 검토 |
| Stage 5 | 본 커밋 | 권고안, 최종 보고서, 오늘할일 완료 처리 |

## 검증

완료한 검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -destination "generic/platform=macOS" -derivedDataPath build.noindex/task230/DerivedData-universal ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -destination "generic/platform=macOS" -derivedDataPath build.noindex/task230/DerivedData-arm64 ARCHS="arm64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -destination "generic/platform=macOS" -derivedDataPath build.noindex/task230/DerivedData-x86_64 ARCHS="x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -destination "generic/platform=macOS" -derivedDataPath build.noindex/task230/DerivedData-universal-deadstrip-only ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO DEAD_CODE_STRIPPING=YES build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -destination "generic/platform=macOS" -derivedDataPath build.noindex/task230/DerivedData-universal-strip-settings ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO DEPLOYMENT_POSTPROCESSING=YES COPY_PHASE_STRIP=YES DEAD_CODE_STRIPPING=YES build
hdiutil verify build.noindex/task230/dmg-sim-universal/alhangeul-macos-0.1.1-universal-local-only.dmg
hdiutil verify build.noindex/task230/dmg-sim-arm64/alhangeul-macos-0.1.1-arm64-local-only.dmg
hdiutil verify build.noindex/task230/dmg-sim-x86_64/alhangeul-macos-0.1.1-x86_64-local-only.dmg
hdiutil verify build.noindex/task230/dmg-sim-universal-deadstrip-only/alhangeul-macos-0.1.1-universal-deadstrip-only-local-only.dmg
hdiutil verify build.noindex/task230/dmg-sim-universal-deadstrip/alhangeul-macos-0.1.1-universal-deadstrip-local-only.dmg
test -f mydocs/report/task_m019_230_report.md
rg -n "단일 universal|아키텍처별|Rust core|Rhwp.xcframework|Sparkle|Homebrew|권고|후속" mydocs/working/task_m019_230_stage*.md mydocs/report/task_m019_230_report.md
git diff --check
git status --short
```

검증 결과:

- Rust bridge lock 검증 통과
- universal/arm64/x86_64 local-only Release build 통과
- `DEAD_CODE_STRIPPING=YES` local-only Release build 통과
- postprocessing strip 후보 local-only Release build 통과
- local-only DMG 생성 및 `hdiutil verify` 통과
- Stage 1-5 보고서와 최종 보고서 keyword scan 통과
- 문서 diff whitespace 검증 통과

## 미수행 범위

- 실제 public release 재배포
- GitHub Release 게시 또는 asset upload
- Pages deployment
- Sparkle appcast 갱신
- Homebrew Cask 또는 tap 반영
- Developer ID signing/notarization/staple
- `project.yml`, RustBridge, release script의 실제 최적화 적용
- 후속 GitHub Issue 생성

## 잔여 위험

- 모든 DMG 수치는 local-only unsigned compressed DMG 기준이다. public signed/notarized DMG의 byte size와 완전히 같다고 볼 수 없다.
- `DEAD_CODE_STRIPPING=YES` 후보는 build/link/DMG verify만 확인했고, 제품 기능 smoke는 후속 구현 작업에서 수행해야 한다.
- `release.sh --skip-notarize`는 Stage 3에서 Finder AppleScript layout 단계 실패가 있었다. 이 작업은 원인 기록만 하고 script를 수정하지 않았다.
- Rust profile 최적화는 staticlib artifact 기준으로만 측정했다. final app/DMG 기준 효과는 별도 검증이 필요하다.

## 작업지시자 승인 요청

최종 보고와 검증은 완료됐다. 다음 절차는 작업지시자 승인 후 `publish/task230` 원격 브랜치 push와 `devel-webview` 대상 PR 생성이다.
