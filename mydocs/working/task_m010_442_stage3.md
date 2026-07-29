# Task M010 #442 Stage 3 완료보고서

## 단계 목적

Stage 2에서 축소한 WKWebView local override가 실제 Debug app bundle에 포함되는지 확인하고, upstream v0.8.2의 1023/1024px breakpoint 전후에서 toolbar/style bar와 editor가 겹치거나 잘리지 않는지 검증한다. 빈 문서와 HWP/HWPX, light/dark theme, 실제 앱 조작과 off-screen WKWebView 수치 probe를 함께 사용해 local select 보정과 upstream layout 복원이 양립하는지 확인한다.

## 산출물

- `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app`
  - `CODE_SIGNING_ALLOWED=NO` HostApp Debug 빌드
  - source와 동일한 `alhangeul-wkwebview-overrides.css` 포함
- `build.noindex/task442-visual/`
  - 절대 경로로 지정한 Task #442 Debug 앱의 실제 window 캡처 20개
  - 900/1023/1024/1206px 빈 문서 light/dark 캡처
  - 900/1023/1024/1206px HWP/HWPX dark 캡처
  - 900/1024px HWP/HWPX light 대표 캡처
  - 900/1023/1024/1280/1600px off-screen WKWebView JSON metric과 PNG
  - 앱 이름만으로 대상이 모호했던 캡처 2개는 `rejected-app-name-targeting/`에 격리하고 판정에서 제외
- `mydocs/working/task_m010_442_stage3.md`
  - build, asset, visual matrix, interaction과 등록 정리 결과 기록
- `mydocs/orders/20260729.md`
  - Issue #442 비고를 `Stage 3 완료 · Stage 4 승인 대기`로 갱신

`build.noindex/` 산출물은 검증 증적이며 tracked source나 PR 산출물에 포함하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

- Stage 3에서는 제품 CSS, verifier, Swift, `project.yml`, generated Xcode project, upstream hashed asset, manifest와 core lock을 변경하지 않았다.
- `xcodegen generate` 뒤 tracked project drift가 없음을 확인했다.
- source와 Debug app bundle의 local override는 `cmp`로 byte-for-byte 동일했다.
- HWP/HWPX 샘플은 메모리에서만 열었다. 글자 크기와 줄 간격 interaction smoke로 생긴 변경은 원값으로 되돌렸고, 앱 종료 시 `저장하지 않음`을 선택해 sample 파일을 변경하지 않았다.
- light mode는 검증 중에만 사용하고 최종적으로 기존 system dark mode로 복원했다.
- 동일 bundle identifier의 설치본·DMG 실행본이 함께 존재해 최종 실앱 검증은 반드시 다음 절대 경로로 고정했다.

```text
/Users/melee/Documents/projects/rhwp-mac-task442/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app
```

## 빌드와 자동 검증 결과

Rust bridge strict verification은 source provenance, release tag/commit, Cargo lock, generated header와 FFI symbol 검사를 통과한 뒤 universal static archive의 byte fingerprint에서 다음 차이를 보고했다.

```text
expected sha256: b35e935283f97c20d41f634f559e623ccd510f54f1341ca83d0f2108345a58eb
actual sha256:   427e4b88300cb732c0c8986889f4ee45859a5a3e1c9a9f06569ac655d980e26f
expected size:   212505600
actual size:     212514296
```

static archive byte fingerprint는 toolchain과 build path에 따라 달라질 수 있다는 core dependency 운영 기준에 따라 다음 portable verification을 다시 실행했고 exit code 0으로 완료했다. `rhwp-core.lock`은 변경하지 않았다.

```text
PASS: ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
      ./scripts/build-rust-macos.sh --verify-lock
PASS: release tag v0.8.2 / commit 9b16aa9e23f476e2b335d7c029fc9f24a199d63c
PASS: Cargo.lock, generated header, FFI symbol verification
```

HostApp 생성과 빌드:

```text
PASS: xcodegen generate
PASS: unrelated generated project drift 없음
PASS: xcodebuild -project Alhangeul.xcodeproj \
      -scheme HostApp \
      -configuration Debug \
      -derivedDataPath build.noindex/DerivedData \
      CODE_SIGNING_ALLOWED=NO \
      build
```

source와 app bundle asset:

```text
OK: rhwp-studio assets verified at
    /Users/melee/Documents/projects/rhwp-mac-task442/Sources/HostApp/Resources/rhwp-studio
OK: rhwp-studio assets verified at
    build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
PASS: source/bundle alhangeul-wkwebview-overrides.css cmp
PASS: bundle index.html 존재, WASM asset 1개
PASS: bash -n scripts/verify-rhwp-studio-assets.sh
PASS: git diff --check
```

## Visual matrix

실제 Debug 앱 window 캡처 판정:

| 문서 상태 | theme | 확인 폭 | 판정 |
|-----------|-------|---------|------|
| 빈 문서 | light | 900, 1023, 1024, 1206px | PASS |
| 빈 문서 | dark | 900, 1023, 1024, 1206px | PASS |
| `KTX.hwp` | light | 900, 1024px | PASS |
| `KTX.hwp` | dark | 900, 1023, 1024, 1206px | PASS |
| `hwpx-01.hwpx` | light | 900, 1024px | PASS |
| `hwpx-01.hwpx` | dark | 900, 1023, 1024, 1206px | PASS |

모든 실제 캡처에서 다음을 확인했다.

- toolbar와 style bar가 서로 겹치지 않는다.
- style bar와 document editor 시작점이 겹치지 않는다.
- select text, dropdown indicator와 arrow가 control 안에 표시된다.
- 1023px까지 field 행과 command 행의 tablet grid를 유지한다.
- 1024px부터 label과 group separator를 포함한 desktop ribbon으로 전환한다.
- HWP/HWPX가 로드된 뒤에도 같은 layout 경계를 유지한다.
- light/dark에서 disabled surface와 indicator 대비가 유지된다.

현재 디스플레이에서 실제 앱 window의 최대 캡처 폭은 1206px였다. 정확한 1280px와 더 넓은 구간은 저장소를 변경하지 않는 임시 off-screen WKWebView probe로 실제 Debug app bundle resource를 로드해 보완했다.

| CSS viewport | display | style bar 높이 | min-height | visible controls | 경계 이탈 | 수평 overflow |
|--------------|---------|------------------|------------|------------------|-----------|---------------|
| 900px | grid | 86px | 0px | 22 | 0 | 없음 |
| 1023px | grid | 86px | 0px | 22 | 0 | 없음 |
| 1024px | flex | 69px | 68px | 22 | 0 | 없음 |
| 1280px | flex | 69px | 68px | 22 | 0 | 없음 |
| 1600px (wide) | flex | 69px | 68px | 22 | 0 | 없음 |

probe는 `window.innerWidth`, `documentElement.clientWidth/scrollWidth`, `#style-bar.getBoundingClientRect()`와 visible `select/input/button`의 bounding rectangle를 측정했다. 900/1023px의 grid와 1024px 이상의 flex 전환, 1280/1600px의 68px 최소 desktop ribbon, visible control 경계 이탈 0건과 horizontal overflow 없음이 수치로 확인됐다.

## Interaction smoke

`KTX.hwp`를 연 dark 900px Debug 앱에서 다음을 확인했다.

- 스타일 popup: 현재 `바탕글`과 스타일 목록 표시
- 언어 popup: `대표`, 한글, 영문, 한자, 일어 등 목록 표시
- 글꼴 popup: 현재 `한컴 윤체 B`와 글꼴 목록 표시
- 줄 간격 popup: 현재 `160 %`와 preset 목록 표시
- 글자 크기 arrow: `20 → 21 → 20` 정상 변경·원복
- 줄 간격 arrow: `160 % → 165 % → 160 %` 정상 변경·원복
- 글자 모양과 문단 정렬 button이 style bar 경계 안에서 접근성 button으로 노출

popup은 열린 상태에서 style bar 밖에 표시될 수 있으므로 closed control clipping 판정과 구분했다.

## 개발 등록 정리

Debug 앱 종료 뒤 표준 helper의 최초 check는 Task #442 개발 app 등록을 탐지했다.

```text
development/test Alhangeul.app registrations remain in LaunchServices.
```

`--cleanup-dev-registrations`는 본 앱과 Preview/Thumbnail appex 등록 및 Quick Look cache를 정리했다. 다만 LaunchServices dump에 남은 Sparkle 내부 `Updater.app` 경로를 helper가 상위 `Alhangeul.app`으로 집계해 issue가 한 번 더 남았다. 진단에 표시된 정확한 내부 Updater 경로만 `lsregister -u`로 해제했고, 파일은 삭제하지 않았다.

최종 표준 helper 결과:

```text
PASS: scripts/check-extension-registration-hygiene.sh --check-only
Development registrations: (none)
Legacy app candidates: (none)
Legacy extension candidates: (none)
Issues: (none)
Provider app roots:
  - /Users/melee/Applications/Alhangeul.app
```

`build.noindex/`의 Debug app bundle은 빌드 증적으로 남아 있지만 등록되지 않았으므로 Finder/Quick Look 환경을 오염하지 않는다.

## 잔여 위험

- universal static archive의 exact byte hash와 size는 현재 toolchain/build path에서 lock의 reference fingerprint와 달랐다. source provenance, Cargo lock, header, FFI symbol과 portable verification은 통과했으며 lock은 변경하지 않았다.
- light mode의 HWP/HWPX는 900/1024px 대표 구간을 직접 확인했고, 1023/1206px은 빈 문서 light와 문서 dark matrix 및 theme-independent bounding probe를 교차 적용했다.
- 실제 1280/1600px native window는 현재 디스플레이 크기상 만들 수 없어 off-screen WKWebView로 확인했다. 900~1206px은 실제 Debug app에서 확인했다.
- standard registration helper가 Sparkle 내부 Updater 등록을 상위 앱으로 집계하는 동작은 이번 UI blocker 범위 밖의 운영 도구 보완 후보다.
- Task #442가 merge돼도 기존 Issue #441 rehearsal run `30365232108`과 candidate `1d358103a877a9d0b6c924a280b84e60e94d6739`는 재사용할 수 없다.

## 다음 단계 영향

Stage 4에서는 Stage 1~3의 원인, CSS ownership, verifier guard, build와 visual matrix를 최종 보고서에 정리한다. `publish/task442`를 게시하고 `devel` 대상 ready PR을 만든 뒤 CI의 change classification, asset verification, Rust/core provenance, HostApp build와 release helper checks를 확인한다.

Task #442 PR에는 Stage 2의 local CSS/verifier와 task 문서만 포함한다. version/build, release record, tag, GitHub Release와 Issue #441 release workflow는 변경하지 않는다. merge 전에는 Issue #441 candidate를 새로 만들거나 rehearsal을 실행하지 않는다.

## 승인 요청

이 Stage 3 결과를 승인하고 Stage 4의 최종 보고서 작성, `publish/task442` 게시와 `devel` 대상 ready PR 생성 절차를 진행할지 승인 요청한다.

Stage 4 승인 전에는 최종 보고서 커밋, 원격 push와 PR 생성을 진행하지 않는다.
