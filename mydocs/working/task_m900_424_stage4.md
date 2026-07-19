# Task M900 #424 Stage 4 완료보고서

## 단계 목적

`v0.1.8 (14)` release candidate를 `main`과 annotated tag로 확정하고, 별도 승인된 pre-public draft Publish workflow가 만든 signed/notarized DMG에서 배포 전 차단 smoke를 수행한다.

## 확정 기준점

| 항목 | 값 |
|------|----|
| Task #424 source PR | [#425](https://github.com/postmelee/alhangeul-macos/pull/425), `devel` merge 완료 |
| main back-merge PR | [#427](https://github.com/postmelee/alhangeul-macos/pull/427), `devel` merge 완료 |
| release PR | [#426](https://github.com/postmelee/alhangeul-macos/pull/426), `devel -> main` merge 완료 |
| release commit | `542a35f2179e5499996b2ab7d2b1a94774b544a2` |
| tag | annotated `v0.1.8`, peeled commit `542a35f2179e5499996b2ab7d2b1a94774b544a2` |
| app / extension | `0.1.8 (14)` |
| rhwp core / studio | `v0.7.18` / `93862a4e16df59834ebce46d91e948cd739208e9` |
| draft workflow | [run 29670015725](https://github.com/postmelee/alhangeul-macos/actions/runs/29670015725) |

Task #424 source PR merge 뒤 `main`에만 있던 v0.1.7 종료 기록을 `devel`로 되돌리는 merge를 먼저 수행했다. 이력 보존을 위해 squash나 cherry-pick으로 재작성하지 않고 PR #427의 merge commit으로 반영한 뒤 release PR #426을 merge했다.

## Draft Publish 실행

별도 승인을 받아 tag `v0.1.8`에서 다음 입력으로 `Release Publish DMG` workflow를 실행했다.

| 입력 | 값 |
|------|----|
| `version` | `0.1.8` |
| `previous_release_ref` | `v0.1.7` |
| `expected_rhwp_tag` | `v0.7.18` |
| `require_latest_rhwp` | `false` |
| `include_rhwp_in_title` | `true` |
| `draft` / `prerelease` | `true` / `false` |

workflow는 release commit과 동일한 `542a35f...`에서 성공했다. `require_latest_rhwp=false`는 upstream `v0.7.19`의 custom scheme legacy RPC 회귀 `edwardkim/rhwp#2396`을 피하기 위한 승인된 실행별 예외이며 workflow 기본값은 변경하지 않았다.

draft 실행에서는 stable Sparkle appcast 갱신과 Pages deploy가 모두 skip됐다. 검증 중 public stable appcast와 Pages 최신 릴리즈 표시는 계속 `v0.1.7`이었다.

## Draft DMG와 서명 검증

| 항목 | 결과 |
|------|------|
| draft release title | `Alhangeul v0.1.8 (rhwp v0.7.18)` |
| DMG | `alhangeul-macos-0.1.8.dmg`, 161,077,475 bytes |
| DMG SHA256 | `5d16eced64f1aef95cc5dd9704a93c4acd30f80ee40ce49352854d1b99995250` |
| checksum | `shasum -a 256 -c` 통과 |
| `hdiutil verify` | 통과 |
| Gatekeeper | app과 DMG 모두 Notarized Developer ID accepted |
| staple | app과 DMG 모두 `xcrun stapler validate` 통과 |
| code signature | Developer ID Application: Taegyu Lee (XH6JHKYXV8), hardened runtime, timestamp |
| architecture | app, Preview, Thumbnail 모두 `arm64 + x86_64` |
| version | app과 extension 모두 `0.1.8 (14)` |
| Legal | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` canonical 일치 |
| mounted layout | 앱과 Applications symlink만 visible, `720x460` background와 기존 icon layout 일치 |

검증용 signed candidate는 기존 `/Applications/Alhangeul.app` v0.1.7을 덮어쓰지 않고 `/Users/melee/Applications/Alhangeul.app`에 설치했다.

## Finder와 HOP exact UTI 차단 smoke

signed candidate의 built Info.plist가 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx`를 document type과 imported UTI에 포함하는지 확인했다.

exact handler 조회 결과:

| UTI | 알한글 포함 여부 | 함께 조회된 주요 앱 |
|-----|------------------|---------------------|
| `net.golbin.hop.hwp` | `com.postmelee.alhangeul` 포함 | HOP, 한컴 Viewer |
| `net.golbin.hop.hwpx` | `com.postmelee.alhangeul` 포함 | HOP, 한컴 Viewer, Archive Utility, The Unarchiver |

`scripts/smoke-finder-integration.sh`를 signed candidate로 실행해 HWP와 HWPX Thumbnail 생성을 모두 통과했다. 검증 산출물은 `/private/tmp/alhangeul-v018-draft-finder/task151-20260719-113920`에 보관했다. 다만 같은 bundle identifier를 사용하는 v0.1.7 provider가 함께 등록된 상태였으므로 이 실행만으로 signed v0.1.8 Thumbnail provenance를 단정하지 않았다.

첫 Finder Space HWPX Quick Look은 9페이지를 표시했지만 실행 프로세스가 `/Applications/Alhangeul.app` v0.1.7의 `AlhangeulPreview.appex`임을 확인했다. 이 결과는 signed v0.1.8 통과 근거에서 제외했다.

provider provenance를 분리하기 위해 기존 v0.1.7과 HOP의 Preview/Thumbnail 등록을 잠시 해제하고 `/Users/melee/Applications/Alhangeul.app` v0.1.8 provider만 활성화했다. 기존 파일과 byte hash가 다른 유효한 ZIP HWPX `/private/tmp/Alhangeul-v018-alhangeul-preview.hwpx`를 사용한 결과는 다음과 같다.

| 경로 | 결과 |
|------|------|
| Finder Quick Look | `/Users/melee/Applications/Alhangeul.app/.../AlhangeulPreview` 프로세스 실행 확인, 9페이지 non-blank render |
| Thumbnail | `/Users/melee/Applications/Alhangeul.app/.../AlhangeulThumbnail` 프로세스 실행 확인, 566x800 PNG 생성 |
| Thumbnail SHA256 | `0bd1bdae4b85f1f2e87b5174e022a05c8a657808219f5f249f34d47697d260e9` |
| Thumbnail 산출물 | `/private/tmp/alhangeul-v018-isolated-thumbnail-1219/Alhangeul-v018-alhangeul-preview.hwpx.png` |

이 환경의 `mdls`는 테스트 HWPX를 `com.haansoft.hancomofficeviewer.mac.hwpx`로 분류했다. 설치 앱에 따라 한 개의 실제 content type이 우선되는 macOS 특성 때문에 `net.golbin.hop.*` 직접 분류는 재현하지 못했지만, signed built plist의 선언과 exact handler 조회로 두 HOP UTI의 후보 자격을 확인했고 실제 Finder open, Preview와 Thumbnail은 동일 호환 선언에 포함된 문서 형식으로 통과했다. 전역 LaunchServices 또는 Quick Look cache reset은 수행하지 않았다.

격리 smoke 뒤 HOP과 `/Applications/Alhangeul.app` v0.1.7 등록을 모두 복원했다. 최종 `pluginkit` 조회에서 Alhangeul Preview와 Thumbnail은 각각 v0.1.7 및 v0.1.8 두 항목, HOP Preview와 Thumbnail은 각각 한 항목이 다시 등록된 상태를 확인했다.

Finder에서 임시 `Alhangeul-v018-routing.hwpx`를 우클릭한 결과 `다음으로 열기` 하위 메뉴에 `알한글.app`이 표시됐다. 해당 항목을 실제 선택했고 `/Users/melee/Applications/Alhangeul.app` 프로세스가 문서를 받아 9페이지 HWPX로 비어 있지 않게 렌더링했다. 전역 LaunchServices reset이나 기본 앱 변경은 수행하지 않았다.

## Host RPC와 앱 UI 차단 smoke

signed candidate의 bundled `rhwp-studio` resource를 사용해 다음 자동 smoke를 실행했다.

```text
scripts/preview-visual-diff-harness.sh \
  /private/tmp/alhangeul-v018-draft-host-rpc \
  --resource-dir /Users/melee/Applications/Alhangeul.app/Contents/Resources/rhwp-studio \
  samples/basic/KTX.hwp \
  samples/hwpx/hwpx-01.hwpx
```

| 샘플 | 전략 | 페이지 | 결과 |
|------|------|--------|------|
| `KTX.hwp` | `rhwp-request` | 1 | readiness, `loadFile`, page count, non-white canvas/snapshot 통과 |
| `hwpx-01.hwpx` | `rhwp-request` | 9 | readiness, `loadFile`, page count, non-white canvas/snapshot 통과 |

실제 signed app UI에서는 다음을 확인했다.

| 경로 | 결과 |
|------|------|
| HWP 열기 | `KTX.hwp`, 1페이지, non-blank render |
| HWP 다른 이름으로 저장 | `HWP 문서 저장` panel 진입 후 취소, 원본 미변경 |
| 공유 | macOS share popover와 AirDrop/Mail/메시지 등 후보 표시 후 취소, 전송 없음 |
| PDF 내보내기 | `/private/tmp/Alhangeul-v018-KTX.pdf`, 490,220 bytes, PDF 1.3, 1페이지 |
| 인쇄 | `Command-P`로 1/1페이지 print preview 표시 후 취소, print job 없음 |
| HWPX Finder open | `Alhangeul-v018-routing.hwpx`, 9페이지 render |

인쇄 대화상자가 표시되기 전에 studio의 `print-document` payload에 포함된 SVG page를 native `RhwpStudioPrintController`가 WKWebView PDF로 변환한다. 따라서 1/1페이지 print preview 확인은 SVG payload와 PDF 변환 경로가 함께 통과했다는 근거다.

첫 `파일 > 인쇄...` AX 메뉴 클릭은 대화상자를 표시하지 않았지만 같은 command의 `Command-P` 실행에서는 정상적으로 print preview가 열렸다. 제품 기능 실패로 판정할 근거는 없으며 실제 인쇄 작업은 실행하지 않았다.

## 미실행 항목

Stage 4에서는 다음 public side effect를 실행하지 않았다.

- draft release의 official publish 전환
- stable Sparkle appcast와 Pages v0.1.8 배포
- v0.1.7에서 v0.1.8로 Sparkle update와 extension refresh
- public DMG URL/SHA256을 사용하는 Homebrew Cask 반영
- Intel Mac 실기기 실행

## 판단

- `main` release commit과 annotated tag가 동일한 candidate를 가리킨다.
- draft DMG의 Developer ID signing, notarization, staple, Gatekeeper, universal slice와 layout이 모두 통과했다.
- signed candidate에서 HOP exact UTI Finder 후보와 handler diagnostics, 실제 HWPX open이 통과했다.
- 기존 provider를 배제한 격리 smoke에서 signed v0.1.8 Preview와 Thumbnail의 실제 프로세스 경로와 non-blank 산출물을 확인했다.
- bundled `rhwp-studio v0.7.18` custom scheme legacy RPC readiness/load와 HWP/HWPX page count가 통과했다.
- 저장, 공유, SVG/PDF, 인쇄 시작 경로가 실제 UI에서 통과했다.
- 검증 중 변경한 provider 등록을 원상 복구했으며 public stable surface는 계속 v0.1.7을 유지한다.
- Stage 4 pre-public signed candidate 차단 gate를 통과로 판정한다.

## 승인 요청

Stage 4 완료보고서와 단계 커밋 승인 후 Stage 5 official stable Publish workflow 실행 승인을 별도로 요청한다. 이 승인 전에는 draft release 공개 전환, stable appcast/Pages 배포와 Homebrew 반영을 실행하지 않는다.
