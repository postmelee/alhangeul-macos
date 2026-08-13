# Task #456 Stage 4 완료보고서

## 단계 목적

실제 HostApp, WKWebView와 native `NSSavePanel` 경로에서 HWP/HWPX 동일 형식 저장, 상호 변환 저장, 저장 뒤 재열기와 후속 `Command+S` 형식 유지가 동작하는지 검증한다.

## 검증 환경과 fixture

- 앱: `build.noindex/task456/stage4-build/Build/Products/Debug/Alhangeul.app`
- HWP fixture: `samples/basic/KTX.hwp`
- HWPX fixture: `samples/hwpx/ref/ref_mixed.hwpx`
- smoke 입력: `build.noindex/task456/stage4-smoke/inputs/`
- smoke 출력: `build.noindex/task456/stage4-smoke/outputs/`
- native/core render 증거: `build.noindex/task456/stage4-smoke/evidence/render-final/`

초기 후보였던 `samples/hwpx/hwpx-01.hwpx`는 확장자와 달리 CFB signature를 가진 HWP5 파일이어서 HWPX 검증 fixture로 사용하지 않았다. ZIP signature와 표준 HWPX container를 가진 `samples/hwpx/ref/ref_mixed.hwpx`로 교체했다.

원본과 smoke 입력의 SHA-256은 각각 일치했다.

| 형식 | 저장소 원본 | smoke 입력 | SHA-256 |
|------|-------------|-------------|---------|
| HWP | `samples/basic/KTX.hwp` | `source-hwp.hwp` | `6c1a027d67b33c03f469b56548b4c7d6bca36b1c1190c7cc5eac88e35c403cf1` |
| HWPX | `samples/hwpx/ref/ref_mixed.hwpx` | `source-hwpx.hwpx` | `100dd95e7501eefe67bea35ccf8f1fa5628a0f5c982b9ad95d601bd91e77cb7e` |

검증 종료 시 두 fixture의 hash가 그대로 유지돼 원본이 변경되지 않았음을 확인했다.

## 실제 UI 저장 조합

Computer Use로 빌드 앱의 upstream 파일 메뉴, 알한글 native 저장 패널과 편집 영역을 직접 조작했다. 네 저장 조합은 모두 요청한 확장자와 payload signature로 생성됐고, 이후 알한글에서 파일 경로를 다시 선택해 열렸다.

| source → output | 출력 파일 | 크기 | signature/container | 알한글 재열기 | core page 1 render |
|-----------------|-----------|------|---------------------|---------------|--------------------|
| HWP → HWP | `output-hwp-from-hwp.hwp` | 26,112 bytes | CFB `d0cf11e0a1b11ae1` | 1페이지, 219 ms | 1123×794, textRuns 410, 한글 209 scalars, non-white 455,222 |
| HWP → HWPX | `output-hwpx-from-hwp.hwpx` | 27,801 bytes | ZIP `504b0304`, 13 entries | 1페이지, 125 ms | 1123×794, textRuns 410, 한글 209 scalars, non-white 450,615 |
| HWPX → HWPX | `output-hwpx-from-hwpx.hwpx` | 9,321 bytes | ZIP `504b0304`, 11 entries | 1페이지, 120 ms | 794×1123, textRuns 7, 한글 12 scalars, non-white 1,090 |
| HWPX → HWP | `output-hwp-from-hwpx.hwp` | 13,312 bytes | CFB `d0cf11e0a1b11ae1` | 1페이지, 132 ms | 794×1123, textRuns 8, 한글 12 scalars, non-white 1,924 |

HWPX 두 형식의 `unzip -t`가 모두 통과했고 `mimetype`, `Contents/header.xml`, `Contents/section0.xml`, `Contents/content.hpf`, `META-INF/container.xml`, `META-INF/manifest.xml`을 확인했다. HWP에서 변환한 HWPX에는 upstream exporter가 원본 HWP5를 보존하기 위한 `META-INF/rhwp-hwp5-origin`도 포함됐다.

KTX 기반 HWP/HWPX render에서 대표 한글 텍스트, 표와 노선도 이미지가 보였고, HWPX fixture 기반 두 결과도 대표 한글 text run과 non-blank page가 유지됐다. 알한글에서 HWP 결과를 처음 다시 열 때 upstream의 로컬 글꼴 감지 안내가 나타났으며 권장 감지를 수행한 뒤 정상적으로 로드됐다.

## HWPX 저장 뒤 `Command+S` 형식 유지

HWP source를 `output-hwpx-from-hwp.hwpx`로 저장한 직후 편집 영역에 `Stage 4 save check`를 추가하고 `Command+S`를 실행했다.

| 시점 | 크기 | 수정 시각 | SHA-256 |
|------|------|-----------|---------|
| 추가 편집 전 | 27,780 bytes | 17:52 | `04d0af...` |
| `Command+S` 후 | 27,801 bytes | 17:53:51 | `02c53af3b48ba318cee2657b52e3752049ae28a855b90f77f32c0de961047045` |

- 후속 저장 패널은 다시 나타나지 않았다.
- 동일 URL의 파일 크기, 수정 시각과 hash가 변경됐다.
- 갱신된 파일은 계속 ZIP signature를 가졌고 `unzip -t`와 알한글/core 재열기를 통과했다.
- render에서도 추가한 `Stage 4 save check` 문자열이 확인됐다.

따라서 HWPX로 저장한 뒤 current source가 HWPX URL로 전환되고, 다음 일반 저장이 HWP exporter로 되돌아가지 않고 `exportHwpx`를 계속 사용하는 요구사항을 실제 UI 왕복으로 확인했다.

## 실패·취소·중복 요청 경로

### 저장 패널 취소

- HWP source에서 다른 이름 저장 패널을 열고 취소했다.
- 편집기로 정상 복귀했으며 이어지는 `Command+S`에서 패널이 다시 나타나지 않았다.
- 기존 HWP 제자리 저장 경로가 유지돼 취소된 pending request가 다음 저장에 누수되지 않았다.

### 읽기 전용 source fallback

- 별도 HWPX fixture의 파일 권한을 `444`, 부모 폴더 권한을 `555`로 설정하고 편집했다.
- `Command+S`의 source write가 실패하자 `HWPX 문서 저장` native panel이 나타났다.
- `output-hwpx-readonly-fallback.hwpx`로 저장한 결과는 9,321 bytes, ZIP signature와 11개 표준 container entry를 가졌고 `unzip -t`와 core render를 통과했다.
- 저장 뒤 status filename이 fallback destination으로 바뀌었다.
- 검증 직후 임시 fixture와 폴더 권한을 각각 `644`, `755`로 복구했다.

### 중복 저장과 unsaved guard

- 편집 상태의 HWP 결과에서 `Command+S`를 빠르게 두 번 보냈다.
- 중복 패널이나 오류 없이 한 개의 유효한 CFB/HWP가 남았고 수정 시각과 hash가 한 번의 정상 저장 결과로 갱신됐다.
- 저장 완료 뒤 다른 결과 파일 네 개를 차례로 열 때 잘못된 unsaved guard가 나타나지 않았다.

## 자동 검증 결과

| 명령 | 결과 |
|------|------|
| `xcodegen generate` | 통과. `project.yml`에서 Xcode project를 재생성했다. |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task456/stage4-tests CODE_SIGNING_ALLOWED=NO test` | 통과. 전체 100개, 실패 0개. |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task456/stage4-build CODE_SIGNING_ALLOWED=NO build` | 통과. `** BUILD SUCCEEDED **`. |
| `scripts/verify-rhwp-studio-assets.sh build.noindex/task456/stage4-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio` | 통과. 빌드 앱의 bundled upstream asset과 manifest를 확인했다. |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code에 AppKit/UIKit 의존이 없다. |
| `file` / `xxd -l 8` | HWP 두 결과는 CFB, HWPX 세 결과는 ZIP signature로 판정됐다. |
| HWPX 세 결과 `unzip -t` | 모두 통과. 압축/container 오류가 없다. |
| `./scripts/validate-stage3-render.sh ...` | 저장 결과와 읽기 전용 fallback 결과 5개가 모두 page 1 non-blank render를 통과했다. |
| 알한글 UI 재열기 | 네 변환 결과가 모두 완료 상태와 실제 filename으로 다시 열렸다. |
| 원본/입력 `shasum -a 256` | 각 쌍이 일치해 fixture 무변경을 확인했다. |
| `git diff --check` | 통과. whitespace 오류가 없다. |

번들 asset 검증의 첫 호출에서 앱 bundle root를 resource directory로 잘못 전달해 `missing index.html`이 발생했다. 계획서에 명시된 `Contents/Resources/rhwp-studio` 경로로 다시 실행해 통과했으며 제품 또는 asset 결함은 아니었다.

## 본문 보존 범위와 잔여 위험

- 이번 단계에서 제품 source와 bundled upstream asset은 변경하지 않았다. 검증 결과와 단계 보고서만 추가한다.
- 저장은 upstream exporter가 반환한 bytes를 그대로 native atomic write하므로 HostApp이 본문을 별도 중간 형식으로 재구성하지 않는다.
- 대표 fixture의 페이지, 텍스트, 표·이미지와 non-blank render는 확인했지만 모든 HWP/HWPX 기능의 의미론적 완전 무손실을 보장하지 않는다.
- HWPX runtime write guard는 ZIP magic을 검사하고, 전체 container entry 검증은 이번 smoke처럼 별도 검증 단계에서 수행한다.
- exporter 결과 전체를 JS와 Swift 메모리에 보유하는 비용은 대용량 문서에서 남아 있다.
- upstream 로컬 글꼴 감지와 대체 글꼴 선택에 따라 렌더링 세부가 달라질 수 있다.

## 다음 단계 영향

Stage 5에서는 실제 구현과 이번 검증 결과를 기준으로 다음 내용을 architecture 문서에 반영한다.

- 일반 저장과 형식별 저장의 format 우선순위
- 알한글 native menu/panel, upstream exporter와 atomic write의 소유 경계
- HWPX 저장 뒤 `Command+S`, `notifySaved`와 current source 전환
- runtime signature guard와 별도 HWPX container 검증의 책임 분리
- upstream exporter 호환 범위와 완전 무손실 비보장

## 승인 요청

Stage 4 `HWP/HWPX 저장·재열기 통합 검증`을 완료했다. Stage 5 `저장 정책 문서와 잔여 호환 제한 정리` 진행 승인을 요청한다.
