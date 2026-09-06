# Task M900 #494 Stage 5 검증 보고서

## 현재 상태

2026-09-07 작업지시자가 Stage 4 결과를 확인한 뒤 공식 공개·Pages·Sparkle·Homebrew 진행을 승인했다. **GitHub Release·Pages·stable appcast 공개와 공식 DMG·Homebrew 검증은 완료했다. 실제 Sparkle 업데이트는 Mac 잠금 해제 대기이므로 Stage 5 전체 완료로 판정하지 않는다.**

Mac UI 도구가 잠금을 감지했고 이후 OS 상태에서도 잠금이 유지됨을 확인했다. 작업지시자에게 잠금 해제를 요청했다. 이 대기는 공개 권한 부족이나 자동 승인 검토 거절이 아니다. 이미 승인한 업데이트·Homebrew 범위를 다시 승인받을 필요는 없다.

## 공식 배포

| 항목 | 결과 |
|------|------|
| workflow | [34047148092](https://github.com/postmelee/alhangeul-macos/actions/runs/34047148092), publish·Pages 두 job success |
| tag / commit | `v0.1.11` / `abdf88f9846650e5920039f2807615ea1b285f91` |
| tag object | `7c778a75d7a911615540279fb7232d8493914b6f`; Stage 4 이후 재지정 없음 |
| 버전 / build | App·Preview·Thumbnail `0.1.11 (17)` |
| core / Studio | `v0.8.6` / `f1f9c6ae58344ee9368996d3543f76b9345cf227` |
| 입력 | previous `v0.1.10`, expected rhwp `v0.8.6`, require_latest=true, include_rhwp_in_title=true, draft=false, prerelease=false |
| 공개 시각 | 2026-09-07 02:16:00 KST |
| Release | [Alhangeul v0.1.11 (rhwp v0.8.6)](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.11), non-draft/non-prerelease/latest, ID `383597735` |
| DMG | `alhangeul-macos-0.1.11.dmg`, **180,206,064 bytes** |
| 공식 SHA256 | **`12f3263ab7a44e87f4b61dc1157590cc3a480e2cd1eabdfd78e5708836bf1e75`** |
| Homebrew tap | [commit `6f4abf8`](https://github.com/postmelee/homebrew-tap/commit/6f4abf8ff3fa8db64a0dfa27c0c22f50b86e2153) |
| 증거 경로 | `build.noindex/task494/stage5/` |

실행 직전 원격 tag object·peeled commit·main, 검증한 draft 본문, upstream latest v0.8.6, Pages workflow 설정·v* tag 허용 정책과 Sparkle secret 이름을 확인했다. secret 값은 조회하거나 문서에 기록하지 않았다. 공식 workflow는 같은 tag에서 DMG를 다시 생성했으므로 수정 draft SHA256 `99fcc789d500d13fede37e6f810653a5bdaf92372dac1094a0fdba228926069b`와 구분한다.

## 공식 산출물과 공개 채널 검증

| 검증 | 결과 |
|------|------|
| 자산 identity | public 다운로드 bytes, GitHub asset digest·size, checksum 파일, Release 본문과 workflow 로그의 digest 일치 |
| DMG trust | hdiutil verify, stapler, Gatekeeper Notarized Developer ID 통과 |
| 앱 trust | 앱·확장·Sparkle 구성요소 8개 strict 서명, 예상 Team ID, timestamp, hardened runtime, debug entitlement 부재; 앱 staple·Gatekeeper 통과 |
| bundle | App·Preview·Thumbnail 0.1.11 (17), arm64+x86_64; 앱 sandbox/user-selected read-write와 canonical Legal 확인 |
| DMG layout | 루트 앱과 `/Applications` symlink 확인, 검사 후 mount 해제 |
| Pages | home·updates·v0.1.11 note·v0.1.10 note HTTP 응답 확인, 이전 버전 최신 안내가 v0.1.11 연결 |
| appcast | 0.1.11 (17), official tag 고정 DMG URL, length 180206064, 최소 macOS 12.0 |
| EdDSA | 기존 설치 v0.1.10의 SUPublicEDKey로 official DMG의 Ed25519 서명을 CryptoKit에서 독립 검증. 새 앱 public key도 동일 |
| feed hash | `f880f5047ffea8f41f5675900a3fbb5261b9c5d1015a29f007fdbd3be604f234` — 후속 docs-only 배포에서 byte 보존할 기준 |
| 공개 본문 | Homebrew 반영 후 설치 명령 추가, template·GitHub body validator 통과와 원격 exact 본문 대조 |

공식 workflow는 tag의 `docs/`를 배포하므로 public home·updates·v0.1.11 note에는 여전히 ‘공개 준비’ 또는 Homebrew v0.1.10 문구가 남아 있다. 다운로드 자산과 feed의 배포 실패로 해석하지 않으며, 문구 정리는 README와 위 세 Pages source에 준비했다. 단일 main 종료 정리 PR과 docs-only Pages 배포에서 실제 public appcast byte를 보존해 반영해야 한다. source 수정안을 공개 반영 완료로 기록하지 않는다.

## Homebrew 검증과 원본 보존

`scripts/update-cask-sha256.sh`로 repository Cask를 official checksum에 맞추고 tap에 같은 파일을 반영했다. tap의 기존 head는 `f712c88e7e468395aeb09210cb6e24503dfb7d4f`였으며 다른 작업 변경이 없는 상태에서 Cask 두 줄만 변경했다.

| 항목 | 결과 |
|------|------|
| style / audit | `brew style --cask alhangeul`, `brew audit --cask alhangeul` exit 0 |
| 신규 Cask 참고 검사 | `brew audit --cask --new alhangeul` exit 0 |
| 실제 설치 | `brew install --cask --appdir=<stage5>/homebrew-applications postmelee/tap/alhangeul` exit 0 |
| 설치본 | 0.1.11 (17), host·Preview·Thumbnail 실행 파일이 official DMG와 byte 동일 |
| trust | deep/strict 서명·staple·Gatekeeper 통과 |
| 제거 | `brew uninstall --cask postmelee/tap/alhangeul` exit 0, 테스트 앱과 Cask 설치 상태 제거 |
| 원격 게시 | 위 tap commit push 후 GitHub main Cask가 repository Cask와 byte 동일 |
| 원본 앱 | `/Applications` v0.1.10 147개, `~/Applications` v0.1.8 146개 파일·링크 manifest 동일 |
| 확장 | 두 기존 설치 경로만 등록, HOP Thumbnail default 유지; 테스트 v0.1.11 provider 잔여 없음 |

Mac 잠금 중 실행 중인 기존 앱을 건드리지 않기 위해 Homebrew의 공식 `--appdir` 옵션으로 별도 `build.noindex` 폴더에 설치했다. `/Applications` 기본 경로 설치를 이번 Homebrew 검증에서 새로 실행했다고 주장하지 않는다. 자동 Homebrew update/autoremove는 끈 상태로 검증했고 전역 trust 설정을 바꾸지 않았다. 설치 전 두 기존 앱을 ZIP으로 백업하고 ZIP 내부 각 항목을 원본 SHA256과 대조했다.

## 남은 실제 업데이트와 종료 정리

- 기존 `/Applications/Alhangeul.app`의 About에서 **v0.1.10 (16), rhwp v0.8.4**를 확인했다. 공개 완료 후 업데이트 메뉴를 조작하려는 시점에 Mac 잠금으로 중단됐다.
- Sparkle download/install/relaunch와 기본 모드 `smoke-sparkle-extension-refresh.sh`는 **미실행**이다. feed 서명 검증이나 이전 Stage 4 설치 검증으로 이를 대체하지 않는다.
- 잠금 해제 후 기존 앱 UI의 현재 상태부터 재확인한다. 사용자의 새 편집이 있으면 보존한다. 실제 업데이트 뒤 기본 모드 provider 검증을 먼저 하고 수동 등록 보정 결과와 구분한다.
- 이번 Homebrew 검증은 이미 완료됐으므로 다시 설치·제거할 필요가 없다. Sparkle 검증 뒤 원래 두 설치본과 등록을 복원할 자료는 `restore/`에 있다.
- Stage 6은 최종 보고, 준비한 공개 문구·Cask·기록의 단일 main closeout PR, appcast 보존 배포, devel 반영과 Issue #494 종료를 다룬다. 아직 최종 보고 완료나 Issue 종료로 표시하지 않는다.
- Intel Mac/macOS 12 실기기, maintainer 직접 수동 확인과 Stage 4에 명시한 시각 정합성 한계는 여전히 별도 미실행 범위다.
