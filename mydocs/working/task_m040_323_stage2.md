# Task M040 #323 Stage 2 완료보고서

## 단계 목적

앱 실행 시 Sparkle 백그라운드 확인 정책과 사용자가 직접 누르는 수동 업데이트 확인 경로의 차이를 release/appcast 운영 문서에 남긴다. 자동 설치 정책과 public appcast 배포 승인 gate는 기존 정책을 유지한다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/manual/release_github_pages_sparkle_guide.md` | `Sparkle appcast` 섹션에 `앱 업데이트 확인 동작` 하위 섹션 추가. 실행 시 `checkForUpdatesInBackground()` 요청 조건, 수동 메뉴의 `checkForUpdates(nil)` 경로, `SUAutomaticallyUpdate=false` 정책을 문서화 |
| `mydocs/working/task_m040_323_stage2.md` | Stage 2 변경과 검증 결과 기록 |
| `mydocs/orders/20260601.md` | #323 비고를 Stage 2 완료 후 승인 대기로 갱신 |

라인 수:

```text
262 mydocs/manual/release_github_pages_sparkle_guide.md
7 mydocs/orders/20260601.md
```

## 본문 변경 정도 / 본문 무손실 여부

`release_github_pages_sparkle_guide.md`에는 stable feed URL 바로 아래에 새 하위 섹션만 추가했다. 기존 appcast 생성, Pages deployment, secret 관리, release 승인 gate 문구는 삭제하거나 이동하지 않았다.

오늘할일 문서는 #323 비고만 Stage 2 상태에 맞게 갱신했다.

## 검증 결과

```bash
git diff --check
```

결과: 통과.

```bash
rg -n "checkForUpdatesInBackground|백그라운드|업데이트 확인|appcast.xml|SUAutomaticallyUpdate" mydocs/manual/release_github_pages_sparkle_guide.md
```

결과:

```text
90:- 업데이트 확인 방법
158:- 사용자가 필요한 설치 방법, 첫 실행 안내, 업데이트 확인, 알려진 한계를 간결하게 확인할 수 있는가
177:Pages/appcast 배포는 GitHub Actions Pages deployment 기준이다. repository Pages source는 `build_type=workflow`이어야 하며, `Release Publish DMG` workflow의 official stable release path가 generated `appcast.xml`을 포함한 Pages artifact를 업로드한 뒤 `deploy-pages` job으로 배포한다.
187:- `scripts/ci/prepare-pages-artifact.sh`가 release tag에 포함된 `docs/` 정적 파일과 generated `appcast.xml`을 Pages artifact directory로 조립한다.
206:- public `https://postmelee.github.io/alhangeul-macos/appcast.xml`을 다운로드해 `test -s`와 `xmllint --noout` 검증을 통과한 파일만 Pages artifact root의 `appcast.xml`로 사용한다.
207:- repository의 `docs/appcast.xml`은 stale copy일 수 있으므로 docs-only 배포 source로 사용하지 않는다.
209:- stale `docs/appcast.xml` fallback은 허용하지 않는다.
216:https://postmelee.github.io/alhangeul-macos/appcast.xml
219:### 앱 업데이트 확인 동작
221:HostApp은 Sparkle updater를 시작한 뒤, `automaticallyChecksForUpdates`가 켜진 경우에만 `checkForUpdatesInBackground()`를 1회 요청한다. 이 경로는 앱 실행 시 새 release 안내를 더 빨리 받을 수 있게 하기 위한 백그라운드 확인이며, 최신 상태 안내 모달을 강제로 띄우는 수동 확인 경로가 아니다.
223:앱 메뉴의 `알한글 > 업데이트 확인...`은 사용자가 직접 요청한 확인으로 유지한다. 이 메뉴는 `checkForUpdates(nil)` 경로를 사용하므로, 최신 상태 안내나 이미 진행 중인 업데이트 UI가 사용자에게 표시될 수 있다.
225:`SUEnableAutomaticChecks`는 자동 확인 기본값을 켜지만, 사용자가 자동 확인을 끈 상태에서는 앱 실행 시 백그라운드 확인을 강제하지 않는다. `SUAutomaticallyUpdate`는 `false`로 유지하며, 새 버전이 발견되어도 설치 여부는 Sparkle 표준 UI에서 사용자가 선택한다.
243:- `scripts/ci/write-sparkle-appcast.sh`가 tag 고정 DMG URL과 release notes URL로 `appcast.xml`을 생성한다.
244:- workflow는 generated `appcast.xml`을 Pages artifact root의 `appcast.xml`로 포함한다.
262:- `https://postmelee.github.io/alhangeul-macos/appcast.xml`이 새 release item과 Sparkle EdDSA signature를 포함하는가
```

## 잔여 위험

- Sparkle 실제 UI 노출 여부는 public appcast, 설치본 버전, Sparkle 사용자 defaults에 따라 달라지므로 Stage 2에서는 문서 정합성만 검증했다.
- 실행 시 백그라운드 확인이 최신 상태에서 조용히 종료되는지는 Stage 3 통합 검증과 수동 smoke 후보로 남긴다.

## 다음 단계 영향

Stage 3에서는 Stage 1 코드와 Stage 2 문서를 함께 다시 검증하고, 자동화 검증 가능 항목과 설치본/foreground 세션에서만 가능한 수동 확인 항목을 최종 보고서에 분리해 기록한다.

## 승인 요청

Stage 2 결과 검토 후 Stage 3 진행 승인을 요청한다.
