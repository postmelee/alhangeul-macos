# Task M018 #184 최종 결과 보고서

## 작업 요약

- 이슈: [#184](https://github.com/postmelee/alhangeul-macos/issues/184) DMG 설치 창 안내와 첫 실행 안내 개선
- 마일스톤: M018 / `v0.1.1`
- 통합 대상: `devel-webview`
- 작업 브랜치: `local/task184`
- 단계: Stage 1~4 완료, Stage 5 최종 검증/보고 완료

`scripts/release.sh`의 DMG 생성 경로에 Finder 설치 창 layout을 추가했다. rehearsal/public DMG가 같은 layout path를 사용하며, DMG 창에는 `알한글.app`을 `Applications`로 드래그하는 안내와 설치 후 첫 실행 필요 문구가 표시된다.

사용자 시각 검증 결과를 반영해 root `설치 안내.txt`는 제거했고, Finder에서 안정적으로 표시되는 720x460 PNG background를 public 기준으로 확정했다. multi-representation TIFF는 현재 Finder 환경에서 2x representation이 실제 background 크기로 선택되어 확대/잘림이 재현되어 제외했다.

public signed/notarized DMG 생성, GitHub Release 게시, appcast/Cask 갱신은 #188 범위로 남겼다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `scripts/release.sh` | DMG staging, background 생성, read-write DMG layout 적용, UDZO 변환 경로 추가 |
| `scripts/create-dmg-background.swift` | 720x460 PNG DMG background 생성 스크립트 추가 |
| `mydocs/manual/release_distribution_guide.md` | DMG layout smoke, root 구성, background 기준, public DMG 반복 검증 기준 추가 |
| `mydocs/orders/20260509.md` | #184 진행 상태 갱신 및 완료 처리 |
| `mydocs/plans/task_m018_184.md` | 수행계획서 추가 |
| `mydocs/plans/task_m018_184_impl.md` | 구현계획서 추가 |
| `mydocs/working/task_m018_184_stage1.md` | DMG layout 방식 조사와 기준 확정 보고 |
| `mydocs/working/task_m018_184_stage2.md` | DMG layout asset과 release script 구현 보고 |
| `mydocs/working/task_m018_184_stage3.md` | rehearsal DMG 생성과 mounted layout smoke 보고 |
| `mydocs/working/task_m018_184_stage4.md` | public release 호환성과 배포 가이드 보강 보고 |

`project.yml`, `Alhangeul.xcodeproj`, Swift 앱/extension source, Rust bridge, `rhwp-core.lock`은 수정하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 결과 |
|------|------|
| 기준 diff | `origin/devel-webview..local/task184` |
| 변경 파일 | 10개 |
| 라인 변화 | 1311 insertions, 7 deletions |
| 단계 커밋 | 8개 |
| background 기준 | 720x460 PNG |
| rehearsal DMG | `alhangeul-macos-0.1.0-rehearsal.dmg` |
| rehearsal SHA256 | `0bbc54790aff25c0236ec0630812aa78d33f8989f528f23ae61d6777779482ee` |

## 검증 결과

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| release script syntax 정상 | OK | `bash -n scripts/release.sh` 통과 |
| release script lint 정상 | OK | `shellcheck scripts/release.sh` 통과 |
| help 출력 정상 | OK | `./scripts/release.sh --help` 통과 |
| public mode credential guard | OK | signing identity 미설정 시 `ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release`로 build 전 중단 |
| background 생성 정상 | OK | Swift generator 통과, `sips` 기준 720x460 |
| rehearsal DMG verify | OK | `hdiutil verify build.noindex/release/alhangeul-macos-0.1.0-rehearsal.dmg` 통과 |
| rehearsal checksum | OK | `shasum -a 256 -c alhangeul-macos-0.1.0-rehearsal.dmg.sha256` 통과 |
| mounted DMG layout smoke | OK | Stage 3에서 root 구성, background, Finder bounds/icon position 확인 |
| 사용자 시각 검증 | OK | PNG fallback DMG 화면을 작업지시자가 확인 |
| 배포 가이드 handoff | OK | public DMG layout smoke 기준 추가 |
| whitespace 검사 | OK | `git diff --check` 통과 |
| 최신 기준 브랜치 반영 | OK | `local/task184`를 `origin/devel-webview` 위로 rebase해 #199 변경 보존 |

## #188 release handoff

[#188](https://github.com/postmelee/alhangeul-macos/issues/188) `v0.1.1 patch release 준비와 public 배포 실행`에서 다음 항목을 signed/notarized public DMG로 반복한다.

1. DMG root에 사용자 노출 항목이 `Alhangeul.app`, `Applications` symlink뿐인지 확인한다.
2. `설치 안내.txt` 같은 보조 안내 파일이 root에 노출되지 않는지 확인한다.
3. `.background/alhangeul-dmg-background.png`가 포함되어 있고 720x460 PNG인지 확인한다.
4. Finder 창에서 toolbar/statusbar가 숨겨지고 icon view가 적용되는지 확인한다.
5. `알한글.app을 Applications로 드래그해 설치하세요.` 문구가 보이는지 확인한다.
6. `설치 후 앱을 한 번 실행해야 Quick Look/Thumbnail이 활성화됩니다.` 문구가 보이는지 확인한다.
7. app icon과 Applications symlink 위치가 화살표 흐름과 맞고 텍스트/아이콘이 겹치지 않는지 확인한다.
8. signing/notarization/staple 후에도 Finder metadata와 background 표시가 유지되는지 확인한다.

## 잔여 위험과 후속 작업

- 이번 작업은 signed/notarized public DMG를 만들지 않았다. 최종 사용자 배포본 검증은 #188에서 반복해야 한다.
- Finder layout metadata는 macOS/Finder 환경에 영향을 받을 수 있다. public release machine에서 동일 smoke를 수행해야 한다.
- multi-representation TIFF는 현재 환경에서 실패로 정리했다. Retina background 재도입은 별도 호환성 검증과 시각 검증 후에만 진행한다.
- 설치 안내의 접근성 보조 설명은 DMG root 텍스트 파일이 아니라 release note, README, Homebrew caveats에서 유지한다.

## 작업지시자 승인 요청

최종 보고서와 PR 게시 준비가 완료됐다. PR 리뷰 후 merge 여부를 결정한다.
