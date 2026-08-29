# Task M010 #488 Stage 1 완료 보고서

## 단계 목적

현재 endpoint verifier가 승인되지 않은 다른 HTTPS origin을 통과시키는지 재현하고, `--release-app`이 실제 release artifact 경로에 연결되지 않은 상태와 pre-signing hook 위치를 확정한다. Built `Info.plist`의 실제 출력 형식과 REXML fallback 동작을 측정해 Stage 2 구현 계약을 증거에 맞춘다.

## 산출물

| 파일 | 변경 정도 | 내용 |
|------|-----------|------|
| `mydocs/working/task_m010_488_stage1.md` | 신규 1개 | Origin 우회, release 호출 경로, plist 형식과 Stage 2 보정안 기록 |
| `mydocs/orders/20260828.md` | 1행 수정 | Stage 1 완료·Stage 2 승인 대기로 진행 상태 갱신 |

Stage 1은 조사·재현 단계이므로 verifier, fixture, workflow, release helper와 제품 source를 변경하지 않았다. 진단용 unsigned Release app은 `build.noindex/task488-stage1/` 아래에만 생성했으며 Git 추적 대상이 아니다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경: 0개
- CI·release script 변경: 0개
- 기존 계획서 본문 변경: 0개
- 신규 단계 보고서와 오늘할일 상태 외 tracked 변경: 없음
- Production endpoint 요청·앱 실행·이벤트 생성: 수행하지 않음
- Public workflow dispatch, Developer ID 서명, notarization: 수행하지 않음

Unsigned Release build 과정에서 Xcode가 `build.noindex/task488-stage1/.../Alhangeul.app`을 LaunchServices에 자동 등록했다. 검증 뒤 해당 app과 내부 Preview/Thumbnail extension 경로만 `lsregister -u`, `pluginkit -r`로 등록 해제했으며 파일과 사용자 설치본은 삭제하지 않았다.

## 조사 결과

### 1. 다른 HTTPS origin이 현재 gate를 통과한다

일회용 fixture에서 Release endpoint만 다음과 같이 교체했다.

```text
기존: https://alhangeul-install-events.postmelee.workers.dev/v1/install-events
변경: https://collector.example/v1/install-events
```

현재 verifier는 exit 0으로 통과했다.

```text
Verified analytics endpoint source configuration (Release only).
Verified current gate accepts alternate HTTPS origin: https://collector.example
```

현재 검증은 HTTPS 절대 URL과 credential·query·fragment 부재만 확인하므로 Issue #488의 production origin 고정 필요성이 재현됐다.

### 2. `--release-app`은 실제 artifact 경로에서 호출되지 않는다

`.github`, `scripts`, release manual을 검색한 결과 `--release-app`은 verifier의 help와 argument parser 세 곳에만 있었다.

```text
scripts/ci/verify-app-execution-endpoint-config.sh:20:  --release-app PATH ...
scripts/ci/verify-app-execution-endpoint-config.sh:42:    --release-app)
scripts/ci/verify-app-execution-endpoint-config.sh:43:      ...
```

`release.sh` main은 다음처럼 endpoint gate 없이 build에서 signing으로 바로 이동한다.

```text
856:  build_app
857:  sign_release_app_for_notarization
```

`release-rehearsal.yml`과 `release-publish.yml`은 모두 공통 `release.sh`를 실행한다. 따라서 `build_app` 다음, `sign_release_app_for_notarization` 이전이 두 workflow를 함께 보호하는 단일 pre-signing hook이다.

`package-release.sh`도 Release app을 staging으로 복사한 뒤 universal 검증과 zip 생성을 수행하지만 endpoint verifier를 호출하지 않는다. 개발용 zip도 동일한 Release configuration을 사용하므로 copied app 직후 verifier를 재사용하는 것으로 Stage 3 범위를 확정한다.

### 3. Built plist의 binary 전제는 현재 빌드에서 성립하지 않는다

Sandbox 제한을 해제한 동일 unsigned Release build는 31.114초에 성공했다.

```text
** BUILD SUCCEEDED ** [31.114 sec]
```

Source와 built plist는 모두 XML이었다.

```text
Sources/HostApp/Info.plist: XML 1.0 document text, Unicode text, UTF-8 text
build.noindex/task488-stage1/Build/Products/Release/Alhangeul.app/Contents/Info.plist: XML 1.0 document text, Unicode text, UTF-8 text
```

Release build setting도 이를 설명한다.

```text
GENERATE_INFOPLIST_FILE = NO
INFOPLIST_FILE = Sources/HostApp/Info.plist
INFOPLIST_OUTPUT_FORMAT = same-as-input
```

따라서 이슈 본문의 “Xcode built plist는 binary이므로 REXML fallback이 동작하지 않는다”는 전제는 현재 project/release 경로에서는 사실이 아니다. REXML로 실제 built plist를 읽는 실험도 성공했다. `plutil` 우선 경로의 exact endpoint 검증 역시 통과했다.

```text
Verified Release built endpoint: build.noindex/task488-stage1/Build/Products/Release/Alhangeul.app
Verified analytics endpoint source configuration (Release only).
```

Stage 2에서는 동작하는 fallback을 근거 없이 삭제하지 않는다. 대신 다음 계약으로 구현계획을 보정하는 편이 정확하다.

- macOS release 경로에서는 기존처럼 `plutil`을 우선 사용한다.
- `plutil`이 없는 환경의 REXML fallback은 현재 `same-as-input` XML built plist만 지원한다고 주석·오류로 명시한다.
- Binary plist가 입력됐는데 `plutil`이 없으면 명확히 실패한다.
- Synthetic binary fixture는 macOS `plutil` 경로가 읽는지 검증하되, 실제 current Release output은 XML이라는 사실을 문서에 유지한다.

이 보정은 수행계획서의 “fallback 제거 또는 동등한 의도 명시” 범위 안이지만, 승인된 구현계획서의 “fallback 제거” 문구는 Stage 2 진입 승인 후 위 계약으로 함께 정정한다.

## 검증 결과

| 검증 | 결과 | 핵심 출력 |
|------|------|-----------|
| `scripts/ci/test-app-execution-endpoint-config.sh` | OK | 정상 configuration과 invalid base/release/plist fixture 통과 |
| `scripts/ci/verify-app-execution-endpoint-config.sh` | OK | Current Release-only source configuration 통과 |
| 다른 HTTPS origin fixture | 재현 성공 | `https://collector.example`이 현재 gate에서 exit 0 |
| `rg -n -- '--release-app' .github scripts mydocs/manual` | 확인 | Verifier 정의 3곳 외 호출 없음 |
| `release.sh` main 순서 검색 | 확인 | `build_app` 직후 `sign_release_app_for_notarization` |
| Unsigned Release build | OK | `BUILD SUCCEEDED`, 31.114초 |
| Built plist 형식 | 확인 | XML 1.0, `same-as-input` |
| Current built `--release-app` | OK | `project.yml` exact endpoint 일치 |
| REXML built plist parse | OK | 실제 XML built plist parse 성공 |
| `git diff --check` | OK | 오류 없음 |

첫 sandbox 내부 build는 Sparkle package cache/network 접근 제한으로 dependency resolution에서 중단됐다. 동일 명령을 로컬 Xcode 권한으로 재실행해 성공했으므로 source·project 실패가 아니라 실행 환경 제한으로 판정했다.

## 잔여 위험

- 다른 HTTPS host가 아직 gate를 통과하므로 Stage 2 완료 전 source configuration 변경을 production destination 승인으로 간주할 수 없다.
- `--release-app`은 아직 release helper에서 호출되지 않으므로 실제 rehearsal/public artifact 자동 검증은 Stage 3 전까지 없다.
- Current built plist는 XML이지만 향후 `INFOPLIST_OUTPUT_FORMAT` 변경으로 binary가 될 수 있다. `plutil` 없는 fallback은 형식을 판별해 binary를 조용히 처리하지 않아야 한다.
- Expected origin을 별도 상수로 고정하면 intentional host 이전 시 `project.yml`, verifier, fixture와 운영 문서를 함께 변경해야 한다. 이는 의도한 review gate다.
- Unsigned Release app에는 production endpoint가 포함된다. Stage 1에서는 plist만 읽고 app을 실행하지 않았다.

## 다음 단계 영향

Stage 2는 다음 범위로 진행한다.

1. Expected production origin을 verifier에 독립적으로 고정한다.
2. 다른 HTTPS origin 실패 fixture를 portable source gate에 추가한다.
3. Current XML output을 반영해 REXML fallback을 삭제하지 않고 XML-only 지원과 binary/plutil 요구를 명시한다.
4. macOS fixture에서 current XML과 synthetic binary plist의 `plutil` 경로, Release exact-match와 mismatch를 검증한다.
5. PR CI의 Ubuntu source fixture와 macOS built fixture 책임을 분리한다.

Stage 3의 `release.sh` pre-signing hook과 `package-release.sh` copied app gate 방향은 구현계획대로 유지한다.

## 승인 요청

Stage 1 조사·재현과 검증을 완료했다. 다음 두 사항을 포함해 Stage 2 진입 승인을 요청한다.

1. Production origin 고정과 다른 HTTPS origin 실패 fixture를 구현한다.
2. 실제 Release plist가 XML이라는 증거에 따라 REXML fallback을 제거하지 않고, XML-only fallback과 binary 입력의 `plutil` 요구를 명시하는 방향으로 구현계획을 보정한다.
