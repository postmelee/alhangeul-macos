# Task M900 #472 Stage 4 완료보고서

## 단계 목적

`v0.1.10 (16)` final source candidate를 `main`과 annotated tag로 확정하고, 별도 승인된 pre-public draft Publish workflow가 만든 signed/notarized DMG에서 공개 전 차단 gate를 수행한다.

## 확정 기준점

| 항목 | 값 |
|------|----|
| source PR | [#473](https://github.com/postmelee/alhangeul-macos/pull/473), `devel` merge commit `447b31bcd1cb235980387df2a679fe243f161943` |
| main/devel 판정 PR | [#475](https://github.com/postmelee/alhangeul-macos/pull/475), history-only back-merge 생략 근거 반영 |
| release PR | [#476](https://github.com/postmelee/alhangeul-macos/pull/476), `devel -> main` merge 완료 |
| final source candidate | `34ba5127b9cd6614cffac6f0091201d3c3b1c13f` |
| release commit / tree | `fafed425d4b87162c2188d1384d618adc2211eb6` / `7320f3a7e68a7a8926a40a041f44fc612d02db27` |
| tag | annotated `v0.1.10`, tag object `cd74a7ec8f3bc5bcc5862931b1eda9bbfeecc1b3`, peeled commit `fafed425...` |
| app / extension | 모두 `0.1.10 (16)` |
| rhwp core / studio | `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| draft workflow | [run `31806721517`](https://github.com/postmelee/alhangeul-macos/actions/runs/31806721517) |
| draft release | [`Alhangeul v0.1.10 (rhwp v0.8.4)`](https://github.com/postmelee/alhangeul-macos/releases/tag/untagged-91bda2ed93cfa0d3ca56) |

Stage 1에서 제안했던 history-only `main -> devel` back-merge는 Stage 4.1에서 번복해 생략했다. 당시 `main` 전용 PR #446, #450과 #452의 merge tree는 각각 대응 `devel` 부모와 동일했고 `main` 전용 non-merge commit과 실제 content drift가 없었다. PR #475 review를 거쳐 release transport ancestry와 제품 content를 분리했으며, 장기 규칙화와 자동 gate는 Issue #474에서 추적한다.

PR #476 merge 뒤 `main` release commit tree와 final `devel` candidate tree가 동일함을 확인했다. annotated tag는 이 merge commit을 가리킨다. Stage 3 exact candidate `95800ee...`와 release tag 사이의 제품 source, tests, project, lock, workflow와 scripts diff는 없고 release communication 문서만 이동했다.

## Signed draft Publish

별도 승인을 받아 tag `v0.1.10`에서 다음 입력으로 `Release Publish DMG` workflow를 실행했다.

| 입력 | 값 |
|------|----|
| `version` | `0.1.10` |
| `previous_release_ref` | `v0.1.9` |
| `expected_rhwp_tag` | `v0.8.4` |
| `require_latest_rhwp` | `true` |
| `include_rhwp_in_title` | `true` |
| `draft` / `prerelease` | `true` / `false` |

workflow는 exact tag target `fafed425d4b87162c2188d1384d618adc2211eb6`에서 15분 25초 만에 성공했다. main job `94787323146`의 certificate와 notary credential 준비, 앱·DMG 서명, notarization, staple, Gatekeeper와 draft asset upload가 모두 통과했다. stable Sparkle appcast와 Pages 관련 step은 draft 정책에 따라 skip됐고 deployment job `94791418149`도 실행되지 않았다.

## Draft DMG와 trust 검증

| 항목 | 결과 |
|------|------|
| DMG | `alhangeul-macos-0.1.10.dmg`, 169,177,242 bytes |
| DMG SHA256 | `e54d5a1d2c4875f96ff704d61e0a8567146e00fca0cfc55cd51c04875457a7af` |
| GitHub asset digest | DMG actual SHA256와 일치 |
| code signature | 앱, Preview와 Thumbnail 모두 Developer ID 서명 검증 통과 |
| notarization / staple | 앱과 DMG 모두 통과 |
| Gatekeeper | 앱과 DMG 모두 `Notarized Developer ID` accepted |
| architecture | 앱, Preview와 Thumbnail 모두 `arm64 + x86_64` |
| version | 앱과 extension 모두 `0.1.10 (16)` |
| Legal | canonical resource 일치 |
| mounted layout | visible root는 앱과 `Applications`, background `720x460`, 별도 설치 안내 파일 없음 |

다운로드한 asset의 actual SHA256을 GitHub asset digest와 독립 대조했다. DMG를 mount해 앱을 `build.noindex/task472-stage4-draft/Alhangeul.app`에 복사한 뒤 signed app과 DMG를 로컬에서도 검증했다.

샌드박스 안의 `codesign --verify`는 동일 대조군인 TextEdit에도 `CSSMERR_TP_NOT_TRUSTED`를 반환했다. 샌드박스 밖에서는 TextEdit, 기존 public 앱과 draft 앱이 모두 정상 검증됐고 draft 앱과 DMG의 staple/Gatekeeper도 통과했다. 따라서 이 결과는 artifact defect가 아니라 샌드박스의 trustd 접근 제약으로 판정했다.

## Signed 앱 UI와 저장 smoke

기존 `/Applications/Alhangeul.app` `0.1.9 (15)`를 덮어쓰지 않고 signed candidate를 `/Users/melee/Applications/Alhangeul.app`에 설치했다. 기존 사용자 경로의 `0.1.8 (14)`는 smoke 전에 별도 백업했다.

| 경로 | 결과 |
|------|------|
| 최초 실행 | 성공, `rhwp v0.8.4 (496333b)`와 HOP `v0.7.13` 충돌 안내 표시 |
| HWP 열기 | `samples/basic/KTX.hwp`, 1페이지 non-blank render |
| HWPX 열기 | `samples/hwpx/hwpx-01.hwpx`, 9페이지 non-blank render |
| 로컬 글꼴 감지 | 현재 문서 필요 글꼴만 확인한다는 개인정보 안내 뒤 HWP 1개, HWPX 8개 저장 |
| HWP 저장·재열기 | `roundtrip-hwp.hwp`, CFB signature, 26,112 bytes, 1페이지 render |
| HWPX 저장·재열기 | `roundtrip-hwpx.hwpx`, ZIP integrity 통과, 399,194 bytes, 9페이지 render |
| 원본 무손실 | KTX SHA256 `6c1a027d...03cf1`, HWPX SHA256 `e17464a1...0f20` 유지 |

저장 결과 SHA256은 HWP `ef24cef71c83186479f79c12e7879b4150565ad88a36b776c01c8f2d3effae90`, HWPX `c00570ead34ee053b25f12e16258bd0927793a05c03282612aeaf30bf9472e10`이다. 결과는 원본과 다른 별도 파일에 저장했고 재열기 뒤 문서 page count와 non-blank render를 확인했다.

## PDF·인쇄와 WebKit 경계

| 샘플 | PDF 결과 | 인쇄 결과 |
|------|----------|-----------|
| HWP | 261,569 bytes, 1페이지, `1123 x 794` pts 가로, searchable text, non-blank | native panel `1/1페이지`, 취소 후 앱 복귀 |
| HWPX | 932,723 bytes, 9페이지, `794 x 1123` pts 세로, searchable text, 전 페이지 non-blank | native panel `9페이지 모두`, 취소 후 앱 복귀 |

HWP PDF SHA256은 `c6c98c2050da2392d9ae8d878f0f89f681dcfa576a2b0871a29e86e7f7272606`, HWPX PDF SHA256은 `84a251ab74dd91c0eeb790bfbf53002d768a06e91d74ac8e3cec383eecac3021`이다. `pdfinfo`에서 JavaScript 없음, 암호화 없음과 page geometry를 확인하고 Poppler로 HWP 1페이지와 HWPX 9페이지 전부를 rasterize해 clipping, overlap과 blank page가 없음을 시각 확인했다.

Stage 3 HostAppTests `128/128`에는 문서 유래 SVG의 script, 외부 resource, navigation 차단과 정상 page SVG 렌더가 포함돼 있다. Stage 3 candidate 이후 release tag까지 제품 source 차이가 없고, signed app에서 정상 HWP/HWPX PDF·인쇄 시작 경로가 모두 통과했다. 이번 단계에서는 malicious SVG를 signed 앱에 새로 주입하지 않고 자동 trust-boundary 회귀와 실제 정상 경로를 결합해 판정했다.

## Finder, Preview와 Thumbnail provenance

첫 `scripts/smoke-finder-integration.sh` 실행은 HWP/HWPX Thumbnail 생성과 시각 검증을 통과했지만 진단 로그에서 macOS가 같은 bundle ID의 `/Applications` v0.1.9 Thumbnail provider를 선택한 사실을 확인했다. 결과는 정상이어도 signed v0.1.10 provenance 근거로 사용하지 않았다.

기존 v0.1.9와 v0.1.8 Preview/Thumbnail 등록만 잠시 해제하고 signed v0.1.10 후보를 단독 등록해 다시 검증했다.

| 경로 | 결과 |
|------|------|
| 단독 Preview provider | `.../post-smoke-v0.1.10.app/.../AlhangeulPreview`, `0.1.10`, 유일한 등록 |
| 단독 Thumbnail provider | `.../post-smoke-v0.1.10.app/.../AlhangeulThumbnail`, `0.1.10`, 유일한 등록 |
| HWP Thumbnail | 512x363 PNG, SHA256 `4a1fc522...353b`, non-blank |
| HWPX Thumbnail | 362x512 PNG, SHA256 `3ef08ff5...6b0`, non-blank |
| HWP Finder Quick Look | KTX 1페이지 non-blank, selectable text 확인 |
| HWPX Finder Quick Look | 9페이지 sidebar와 1페이지 non-blank render 확인 |
| 실행 provenance | `ps`에서 Preview와 Thumbnail executable 모두 단독 등록된 signed 후보 경로 확인 |
| crash | smoke baseline 이후 Alhangeul/Preview/Thumbnail 신규 DiagnosticReport 없음 |

격리 산출물은 `build.noindex/task472-stage4-draft/finder-provenance/`에 보관한다. 검증 후 후보 helper가 남지 않았음을 확인했다.

## Public surface 보호와 등록 복원

draft release는 `isDraft=true`, `isPrerelease=false`, `publishedAt=null`을 유지한다. 검증 종료 시점의 공개 상태는 다음과 같다.

| 표면 | 결과 |
|------|------|
| GitHub latest Release | `v0.1.9`, non-draft / non-prerelease |
| Pages 업데이트 화면 | 다운로드, Homebrew와 최신 릴리즈 노트 모두 `v0.1.9` |
| stable appcast | `sparkle:shortVersionString=0.1.9`, build `15` |
| Homebrew | public `v0.1.9` 유지, 이번 단계 미변경 |

검증 종료 시 사용자 설치 상태를 smoke 전과 같게 복원했다.

| 경로 | smoke 전 | 복원 결과 |
|------|----------|-----------|
| `/Applications/Alhangeul.app` | `0.1.9 (15)` | 파일 미변경, registration 복원 |
| `/Users/melee/Applications/Alhangeul.app` | `0.1.8 (14)` | 백업에서 복원, signature valid |

최종 PlugInKit에는 v0.1.9과 v0.1.8의 public/user Preview·Thumbnail 두 항목만 남고 v0.1.10 후보 경로는 없다. 후보 앱은 ignored 검증 산출물로만 보관하며 등록하지 않았다. Quick Look cache를 갱신했고 후보 helper process와 신규 crash가 없으며 draft DMG도 정상 detach했다.

표준 `scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations`도 다시 실행했다. 과거 `build.noindex` LaunchServices 레코드는 각 exact path의 `lsregister -u`가 `-10814`를 반환해 Stage 3과 같이 비활성 레코드로 남았다. 이어 실행한 `--check-only`는 이 레코드와 smoke 전부터 존재한 v0.1.9/v0.1.8 두 설치 root를 보고해 exit 1이었다. PlugInKit에는 개발/후보 provider가 없고 허용된 두 설치 root만 있으며, 사용자 설치 상태 복원 원칙에 따라 전역 LaunchServices reset이나 기존 앱 삭제는 수행하지 않았다. Stage 5 실제 update smoke 전에는 public v0.1.9 baseline을 다시 격리해 provenance를 확인한다.

## 미실행 항목

Stage 4에서는 다음 public side effect와 별도 환경 검증을 실행하지 않았다.

- draft release의 official publish 전환
- stable Sparkle appcast와 Pages `v0.1.10` 배포
- public DMG URL/SHA256 확정
- 실제 `v0.1.9 -> v0.1.10` Sparkle update와 extension refresh
- Homebrew Cask 반영과 install/uninstall smoke
- Intel Mac 실기기 설치·실행

## 판정

- release PR merge commit, tree와 annotated tag가 같은 candidate를 가리킨다.
- draft Publish workflow의 Developer ID signing, notarization, staple, Gatekeeper, universal slice와 layout이 통과했다.
- signed candidate에서 HWP/HWPX 열기, 형식별 저장·재열기와 원본 무손실이 통과했다.
- HWP/HWPX PDF의 page count, geometry, searchable/non-blank 결과와 native 인쇄 panel 시작·취소가 통과했다.
- 자동 WebKit trust boundary 회귀와 signed app 정상 PDF·인쇄 경로가 함께 통과했다.
- 후보만 단독 등록한 격리 smoke에서 실제 Preview/Thumbnail executable provenance와 HWP/HWPX 결과를 확인했다.
- 신규 crash가 없고 검증 등록, 사용자 설치 상태와 DMG mount를 원상 복구했다.
- GitHub latest Release, Pages와 stable appcast는 계속 public `v0.1.9 (15)`를 유지한다.
- Stage 4 pre-public signed candidate 차단 gate를 통과로 판정한다.

## 승인 요청

Stage 4 완료보고서와 단계 커밋을 검토한 뒤 Stage 5 official stable Publish workflow 실행 승인을 별도로 요청한다. 이 승인 전에는 draft 공개 전환, stable appcast/Pages 배포, 실제 Sparkle update와 Homebrew 반영을 실행하지 않는다. Homebrew는 Stage 5에서도 별도 승인 gate를 유지한다.
