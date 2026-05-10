# Task M018 #215 Stage 1 완료 보고서

## 단계 목적

저장소와 HostApp bundle의 license/provenance 관련 현황을 확인하고, 이후 단계에서 추가할 app bundle legal notice resource의 배치 기준을 확정한다.

## 현재 변경 상태

- 브랜치: `local/task215`
- Stage 1 시작 전 범위 보강 커밋: `0a214a1 Task #215: 아이콘 provenance 범위 반영`
- 현재 미커밋 변경: `LICENSE` 1줄
  - `Copyright (c) 2025-2026 Edward Kim`
  - `Copyright (c) 2025-2026 Taegyu Lee`
- 이 `LICENSE` 변경은 Stage 2에서 README/third-party/contributing 문구와 함께 검증하고 커밋한다.

## 현황 inventory

### 저장소 license와 문서

- `LICENSE`는 MIT License 전문이며, 현재 작업지시자 확인에 따라 주 저작권자를 `Taegyu Lee`로 변경한 상태다.
- `THIRD_PARTY_LICENSES.md`는 현재 `rhwp` core, generated artifacts, bundled `rhwp-studio`, bundled fonts, proprietary font 미포함 정책을 다룬다.
- `THIRD_PARTY_LICENSES.md`에는 아직 Sparkle 2.9.1과 앱 아이콘/로고 provenance가 없다.
- README License 섹션은 `LICENSE`, `THIRD_PARTY_LICENSES.md`, `rhwp-core.lock`, `rhwp-studio` manifest, `FONTS.md`만 안내한다.
- README 상단 로고 alt text는 현재 `rhwp logo`다. Stage 2에서 `Alhangeul logo` 기준으로 정정한다.
- `CONTRIBUTING.md`의 license 문구는 "기여하신 모든 코드와 문서는 본 저장소의 MIT License에 따라 배포" 1문장뿐이다. Stage 2에서 기여자의 저작권 보유와 제출 권리 확인 문구를 보강한다.

### HostApp metadata와 dependency

- `Sources/HostApp/Info.plist`에는 `NSHumanReadableCopyright`가 없다.
- `project.yml`은 Sparkle package를 `https://github.com/sparkle-project/Sparkle` exactVersion `2.9.1`로 고정한다.
- `project.yml`의 HostApp source 설정은 `Sources/HostApp`을 포함하고 `Resources/rhwp-studio`만 제외한 뒤, `Sources/HostApp/Resources/rhwp-studio`를 folder resource로 별도 포함한다.
- 따라서 Stage 3에서 `Sources/HostApp/Resources/Legal/`을 추가할 경우 우선 `project.yml` 변경 없이 일반 HostApp resource로 포함되는지 검증한다. 빌드 결과에서 빠질 때만 `project.yml`을 보강한다.

### Bundled third-party와 변경 제외 항목

- `Sources/HostApp/Resources/rhwp-studio/manifest.json`은 upstream `edwardkim/rhwp.git` `v0.7.10`, resolved commit `62a458aa317e962cd3d0eec6096728c172d57110`, source path `rhwp-studio/dist`를 기록한다.
- `Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js`의 about dialog에는 `© 2026 rhwp: Edward Kim` 문구가 남아 있다.
- 이 문구는 bundled upstream `rhwp-studio`의 provenance이므로 변경하지 않는다.
- `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`는 bundled WOFF2 font 35개와 proprietary font 미포함 정책을 소유한다.

## 앱 아이콘과 로고 provenance

- 작업지시자는 앱 아이콘이 upstream `rhwp` 아이콘을 기반으로 Figma에서 편집·변형한 이미지임을 확인했다.
- app icon 입력 자산은 `Sources/HostApp/Assets.xcassets/AppIcon.appiconset`의 PNG 10개다.
- README/문서용 로고 자산은 `assets/logo-256@2x.png`다.
- `file` 확인 결과:
  - `assets/logo-256@2x.png`: PNG, 512x512, 16-bit/color RGBA
  - `Sources/HostApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`: PNG, 1024x1024, 16-bit/color RGBA
  - `Sources/HostApp/Resources/rhwp-studio/icons/icon-512.png`: PNG, 512x512, 8-bit/color RGBA
- 기존 task #77은 AppIcon PNG 10개를 교체했고, `Contents.json`, Swift 코드, `project.yml`은 변경하지 않았다고 기록했다.
- `git log` 기준 AppIcon 교체 커밋은 `fa298b5 Task #77 Stage 2: HostApp AppIcon 이미지 교체`다.
- `assets/logo-256@2x.png`는 `8b606cc Docs: README 제품 정체성 재정의`에서 기록된다.

Stage 2에서는 `THIRD_PARTY_LICENSES.md`에 다음 원칙으로 고지한다.

- Alhangeul 앱 아이콘/로고 자산은 upstream `rhwp` 아이콘/로고 기반 변형 자산이다.
- Figma는 편집 도구로만 언급한다.
- 별도 Figma community asset 사용 근거가 없으므로 Figma를 별도 third-party license 항목으로 만들지 않는다.
- 이 고지는 upstream `rhwp` 프로젝트의 후원, 승인, 보증을 뜻하지 않는다.

## Legal resource 배치 결정

Stage 3에서 다음 경로를 추가한다.

```text
Sources/HostApp/Resources/Legal/LICENSE
Sources/HostApp/Resources/Legal/THIRD_PARTY_LICENSES.md
Sources/HostApp/Resources/Legal/FONTS.md
```

각 파일의 canonical source는 다음으로 둔다.

| Bundle legal resource | Canonical source |
|-----------------------|------------------|
| `Legal/LICENSE` | `LICENSE` |
| `Legal/THIRD_PARTY_LICENSES.md` | `THIRD_PARTY_LICENSES.md` |
| `Legal/FONTS.md` | `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` |

Stage 4에서는 canonical source와 Legal resource copy의 내용 차이를 확인한다.

## 검증 결과

- `git status --short --branch`: `local/task215`, `LICENSE` 미커밋 변경 확인
- `git diff -- LICENSE`: 저작권자 1줄 변경 확인
- `rg --files | rg '(^|/)(LICENSE|THIRD_PARTY_LICENSES.md|FONTS.md|Info.plist|project.yml|README.md|CONTRIBUTING.md)$'`: license 관련 주요 파일 확인
- `rg -n "Edward Kim|Taegyu Lee|Copyright|MIT License|THIRD_PARTY|Sparkle|NSHumanReadableCopyright|Legal|기여하신" ...`: 현재 문구 위치 확인
- `rg -n "아이콘|로고|Figma|AppIcon|logo-256|rhwp logo|Alhangeul logo" ...`: README alt text와 기존 task #77 기록 확인
- `find Sources/HostApp/Resources -maxdepth 3 -type f`: 현재 HostApp resource 구조 확인
- `find Sources/HostApp/Assets.xcassets/AppIcon.appiconset -maxdepth 1 -type f`: AppIcon PNG 10개와 `Contents.json` 확인
- `plutil -p Sources/HostApp/Info.plist`: `NSHumanReadableCopyright` 부재 확인
- `rg -n -o "© 2026 rhwp: Edward Kim" Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js`: upstream about copyright 문구 확인

## 잔여 위험

- `Sources/HostApp/Resources/Legal/`이 `project.yml` 변경 없이 bundle에 포함될 것으로 판단하지만, 실제 산출물 검증은 Stage 3에서 수행해야 한다.
- 앱 아이콘/로고 provenance는 작업지시자 확인과 기존 task #77 기록을 근거로 운영 문서에 남긴다. 법률 자문 수준의 판단은 이번 범위에서 제외한다.
- upstream `rhwp-studio`의 minified JS/CSS는 큰 단일 파일이므로 문구 검색 시 출력이 과도할 수 있다. 이후 검증은 `-o` 또는 특정 파일/패턴으로 제한한다.

## 다음 단계

Stage 1 결과를 승인하면 Stage 2에서 저장소 license와 문서 고지를 보강한다.
