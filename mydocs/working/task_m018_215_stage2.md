# Task M018 #215 Stage 2 완료 보고서

## 단계 목적

저장소 license, README, third-party notice, 외부 기여 문구를 앱 저장소 주 저작권자와 upstream/third-party 경계에 맞게 정리한다.

## 변경 파일

- `LICENSE`
- `THIRD_PARTY_LICENSES.md`
- `README.md`
- `CONTRIBUTING.md`
- `mydocs/working/task_m018_215_stage2.md`

## 변경 내용

### 저장소 license

`LICENSE`의 MIT License 저작권자 표기를 작업지시자 확인에 따라 정정했다.

```diff
-Copyright (c) 2025-2026 Edward Kim
+Copyright (c) 2025-2026 Taegyu Lee
```

이 변경은 Alhangeul macOS 저장소 자체 license의 주 저작권자를 정정하는 것이며, upstream `rhwp` 또는 bundled `rhwp-studio`의 Edward Kim 저작권 표기를 대체하지 않는다.

### README

- README 상단 로고 alt text를 `rhwp logo`에서 `Alhangeul logo`로 정정했다.
- License 섹션에 Alhangeul macOS 저장소 자체 code/license의 주 저작권자가 Taegyu Lee임을 명시했다.
- Third-party notice 진입점을 `rhwp`, `rhwp-studio`, Sparkle, WOFF2 fonts, 앱 아이콘/로고 provenance까지 포함하도록 보강했다.

### Third-party notice

`THIRD_PARTY_LICENSES.md`에 다음 항목을 추가했다.

- Alhangeul macOS 저장소 자체 코드, 문서, packaging 구성의 주 저작권자와 MIT License 경계
- Sparkle 2.9.1 dependency, resolved revision, upstream license URL, upstream contributor attribution
- Sparkle upstream `LICENSE`에 bundled external component notice가 함께 포함된다는 주의
- 앱 아이콘/로고 자산이 upstream `edwardkim/rhwp` 아이콘/로고 기반의 Figma 편집·변형 자산이라는 provenance
- Figma는 편집 도구이며 별도 Figma community asset source로 취급하지 않는다는 기준
- 이 고지가 upstream `rhwp`의 후원, 보증, 승인을 뜻하지 않는다는 disclaimer

Sparkle license 기준은 다음 source를 확인해 반영했다.

- https://sparkle-project.org/
- https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE
- `project.yml`
- `Alhangeul.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

### CONTRIBUTING

기여 문구를 다음 기준으로 보강했다.

- 기여한 코드와 문서는 본 저장소 MIT License로 배포된다.
- 별도 서면 합의가 없는 한 기여자는 자신이 작성한 기여물의 저작권을 보유한다.
- PR, patch, 문서, asset 제출 시 해당 기여물을 제출하고 MIT License로 배포할 권리가 있음을 전제로 한다.

## 변경 제외 항목

- bundled `rhwp-studio` static output은 변경하지 않았다.
- `Sources/HostApp/Resources/rhwp-studio/assets/index-BN69C-Lp.js`의 `© 2026 rhwp: Edward Kim` 문구는 upstream about copyright로 유지한다.
- AppIcon PNG, README/docs logo PNG, `Contents.json`, Swift 코드, `project.yml`은 Stage 2에서 변경하지 않았다.
- app bundle `Contents/Resources/Legal/` resource 추가는 Stage 3 범위로 남긴다.

## 검증 결과

- `git diff -- LICENSE README.md CONTRIBUTING.md THIRD_PARTY_LICENSES.md`: 변경 범위 확인
- `rg -n "Taegyu Lee|Edward Kim|Sparkle|MIT License|THIRD_PARTY_LICENSES|FONTS.md|기여물|저작권|아이콘|로고|Figma|Alhangeul logo" LICENSE README.md CONTRIBUTING.md THIRD_PARTY_LICENSES.md`: 필수 고지 키워드 확인
- `git diff --check -- LICENSE README.md CONTRIBUTING.md THIRD_PARTY_LICENSES.md`: 통과

## 잔여 위험

- Sparkle upstream `LICENSE`에는 Sparkle 자체 license 외 external component notice가 포함된다. Stage 3 legal resource에는 `THIRD_PARTY_LICENSES.md`를 포함하되, public release 전에는 app bundle 또는 release artifact에서 upstream full license 접근성이 충분한지 다시 확인해야 한다.
- 앱 아이콘/로고 provenance는 작업지시자 확인과 기존 task #77 기록에 근거한다. 원본 upstream asset이 별도 license를 명시한 것으로 확인되면 해당 조건을 우선 반영해야 한다.

## 다음 단계

Stage 2 결과를 승인하면 Stage 3에서 `NSHumanReadableCopyright`와 app bundle `Resources/Legal/` notice 파일을 추가한다.
