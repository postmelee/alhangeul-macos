# Task M900 #494 Stage 5 검증 보고서

## 현재 상태

2026-09-07 작업지시자가 Stage 4 결과를 확인한 뒤 공식 공개·Pages·Sparkle·Homebrew 진행을 승인했다. **GitHub Release·Pages·stable appcast 공개와 공식 DMG·Homebrew 검증은 완료했다. 잠금 해제 후 실제 Sparkle 업데이트·기본 확장 검증을 통과했다. HWP/HWPX Finder 확인과 기존 설치본·등록 복원까지 완료했다.**

최초 Mac 잠금 대기 후 작업지시자가 계속 진행을 지시했다. 실제 다운로드·설치·재실행은 성공했으며, 이후 HWPX Finder 확인에서 다시 잠금이 발생했으나 두 번째 잠금 해제 뒤 9페이지 미리보기를 확인했다. 이미 승인한 업데이트·Homebrew 범위를 반복 승인받지 않았고, 공개 문구 종료 정리도 이어서 준비했다.

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

공식 workflow는 tag의 `docs/`를 배포하므로 Stage 5 배포 직후 public home·updates·v0.1.11 note에는 ‘공개 준비’ 또는 Homebrew v0.1.10 문구가 남아 있다. 다운로드 자산과 feed의 배포 실패로 해석하지 않으며, 문구 정리는 README와 위 세 Pages source에 준비했다. 후속 Stage 6 main PR #501과 docs-only Pages run 34049769039에서 public appcast byte를 보존해 반영했다. 실제 검증은 [Stage 6 보고서](task_m900_494_stage6.md)에 기록한다.

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

## 실제 Sparkle 업데이트 — 2026-09-07

| 항목 | 결과 |
|------|------|
| 기존 설치본 | `/Applications/Alhangeul.app` 0.1.10 (16), 두 기존 앱이 백업 manifest와 동일한 상태에서 시작 |
| 업데이트 발견 | 기존 앱의 업데이트 확인 메뉴에서 0.1.11 제공, 현재 버전 0.1.10 표시 |
| 다운로드·설치 | Sparkle UI로 180.2MB 다운로드·압축 해제, ‘설치 & 재실행’ 성공 |
| 실제 재실행 | host PID `20831`, `/Applications/Alhangeul.app` |
| 버전·provenance | About 0.1.11 (17), rhwp v0.8.6 (f1f9c6a) |
| binary·trust | host·Preview·Thumbnail 실행 파일이 official DMG와 byte 동일; strict 서명·staple·Gatekeeper 통과 |
| 자연 등록 | 기존 /Applications provider가 0.1.11로 교체, 사용자 경로 0.1.8은 그대로. 사전 격리나 수동 등록·election 변경 없음 |
| 기본 helper | `sparkle-default/20260907-022810/`, exit 0, `Registration repair used: 0` |
| 실제 Thumbnail | PID `21138`, `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail` |
| 실제 Preview | PID `21977`, `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` |
| 앱 HWP/HWPX | 별도 복사본 열기 1페이지 / 9페이지, 로딩 완료와 화면 확인 |
| Finder HWP | Space 미리보기에서 KTX 지도·운임표·한글 표시 확인 |
| Finder HWPX | 두 번째 잠금 해제 뒤 Space 미리보기에서 9페이지와 비어 있지 않은 첫 페이지 확인. `finder-sparkle-hwpx-ready` AX·화면 증거 보관 |

`finder-live-processes.jsonl`로 실제 새 제공자 실행 경로를 확인했다. 기존 HOP Thumbnail default, HOP Preview ignore 및 사용자 v0.1.8 등록을 그대로 둔 상태에서 위 결과를 얻었다. Stage 4에서 필요했던 충돌 제공자 격리를 이번 업데이트에서는 사용하지 않았다. 이 결과는 해당 환경·문서의 성공이며 모든 공존 환경의 자동 선택을 보장하지 않는다.

자동 다운로드·설치 체크박스는 기존 false를 유지했다. 의도적인 텍스트 편집 없이 열기·미리보기만 검증했지만 HWPX 종료 시 변경 사항 저장 확인이 표시됐다. 종료를 취소하고 `public-open-preserved.hwpx`에 다른 이름으로 저장한 뒤 정상 종료했다. 보존 사본은 399,420 bytes, ZIP 18개 항목 CRC 정상이며 원래 fixture 두 개의 SHA256은 그대로다. 이 관찰의 원인은 이번 릴리스에서 수정·확정하지 않았다. Homebrew는 앞 단계에서 완료했으므로 다시 설치·제거하지 않았다.

## 종료 정리 결과와 최종 보고 인계

- 02:38 KST에 검증 host 정상 종료, 실제 Preview·Thumbnail 프로세스 종료 후 기존 설치본을 복원했다. 새 v0.1.11 앱은 `restore/sparkle-updated.app`에 보존했다.
- `/Applications` v0.1.10의 147개 항목과 사용자 v0.1.8의 146개 항목은 백업 manifest의 파일 SHA256·size·mode·symlink와 동일하고 strict 서명 검증을 통과했다.
- 실제 bundle ID로 PlugInKit을 재조회해 두 기존 경로·버전만 등록된 것을 확인했다. 테스트 v0.1.11 및 개발 산출물 등록·프로세스는 남지 않았다. 전역 LaunchServices 잔여 목록 전체가 깨끗하다고 확대하지 않는다.
- 원본 samples 180개의 SHA256·size·mtime와 테스트 입력 두 파일의 SHA256이 동일하다. Finder 검증 창만 닫았으며 시작 전 사용자 창이 유지됐다. 상세는 `restore/restoration-complete.json`, `restore/restoration.log`, provider 재조회 기록에 보관했다.
- 최종 보고와 준비한 공개 문구·Cask·기록은 단일 main closeout PR로 반영한다. docs-only 배포에서 위 public appcast byte를 보존하고 공식 tag를 재지정하지 않는다.
- Intel Mac/macOS 12 실기기, maintainer 직접 수동 확인과 Stage 4에 명시한 시각 정합성 한계는 별도 미실행 범위다.
