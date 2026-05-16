# Task M018 #215 최종 보고서

## 개요

- 이슈: #215 저작권자 정정과 release legal notice 포함 기준 보강
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task215`
- 목적: Alhangeul macOS 저장소 주 저작권자, upstream/third-party 고지, 앱 bundle legal notice 포함 기준을 release 기준으로 정합화

## 결과

Alhangeul macOS 저장소 자체 MIT License의 주 저작권자를 Taegyu Lee로 정정했다. Upstream `rhwp`/`rhwp-studio`의 Edward Kim 저작권 표기는 third-party provenance로 유지했고, bundled viewer output 내부 문구는 수정하지 않았다.

`THIRD_PARTY_LICENSES.md`에는 다음 고지를 보강했다.

- 저장소 자체 코드, 문서, packaging 구성의 주 저작권자는 Taegyu Lee
- `rhwp`/`rhwp-studio` upstream provenance는 `edwardkim/rhwp` `v0.7.10`
- Sparkle 2.9.1, resolved revision, upstream license URL, upstream contributor attribution
- 앱 아이콘/로고는 upstream `rhwp` 자산 기반 Figma 편집·변형 자산
- Figma는 편집 도구이며, 별도 community asset source로 취급하지 않음
- 이 고지는 upstream `rhwp`의 후원, 보증, 승인을 뜻하지 않음

HostApp에는 다음 release legal notice 기준을 추가했다.

- `NSHumanReadableCopyright`: `Copyright © 2025-2026 Taegyu Lee`
- app bundle resource: `Contents/Resources/Legal/LICENSE`
- app bundle resource: `Contents/Resources/Legal/THIRD_PARTY_LICENSES.md`
- app bundle resource: `Contents/Resources/Legal/FONTS.md`

## 주요 변경 파일

- `LICENSE`
- `README.md`
- `CONTRIBUTING.md`
- `THIRD_PARTY_LICENSES.md`
- `Sources/HostApp/Info.plist`
- `Sources/HostApp/Resources/Legal/*`
- `project.yml`
- `Alhangeul.xcodeproj/project.pbxproj`
- `mydocs/orders/20260510.md`
- `mydocs/plans/task_m018_215.md`
- `mydocs/plans/task_m018_215_impl.md`
- `mydocs/working/task_m018_215_stage1.md`
- `mydocs/working/task_m018_215_stage2.md`
- `mydocs/working/task_m018_215_stage3.md`
- `mydocs/working/task_m018_215_stage4.md`

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 계획 | `71db0fc` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `d0aeb8c` | 구현계획서 작성 |
| 범위 보강 | `0a214a1` | 아이콘 provenance 범위 반영 |
| Stage 1 | `0172dfa` | legal notice 현황과 배치 기준 확정 |
| Stage 2 | `d24e2f9` | 저장소 license와 third-party 고지 보강 |
| Stage 3 | `069933d` | HostApp legal notice resource 포함 |

## 검증

다음 검증을 완료했다.

- `plutil -lint Sources/HostApp/Info.plist`
- `xcodegen dump --type parsed-yaml`
- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- built app bundle `Contents/Info.plist`의 `NSHumanReadableCopyright` 확인
- built app bundle `Contents/Resources/Legal/{LICENSE,THIRD_PARTY_LICENSES.md,FONTS.md}` 존재 확인
- canonical 문서와 source Legal resource copy 비교
- source Legal resource copy와 built app bundle copy 비교
- license/provenance keyword scan
- `git diff --check`

`xcodebuild -list`와 Debug build는 sandbox 내부 SwiftPM/Xcode cache 또는 network 제한으로 첫 실행이 실패한 지점이 있었고, 권한 허용 상태 재실행에서 통과했다.

## 미수행 범위

- public DMG 생성
- Developer ID signing
- notarization
- Homebrew Cask 배포
- Sparkle stable appcast 게시
- release artifact 최종 smoke

위 항목은 release 실행 이슈의 명시 승인 범위에서 검증한다.

## 잔여 관리 항목

- `LICENSE`, `THIRD_PARTY_LICENSES.md`, `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md`를 수정하면 `Sources/HostApp/Resources/Legal/*` 사본도 함께 갱신해야 한다.
- 원본 upstream `rhwp` 아이콘/로고 자산에 별도 license 조건이 확인되면 `THIRD_PARTY_LICENSES.md`에 우선 반영해야 한다.
- public release 전에는 signed/notarized DMG 내부에서도 `Contents/Resources/Legal/` 포함 여부를 재확인해야 한다.

위 운영 기준은 후속 보강으로 `mydocs/manual/release_policy_guide.md`, `mydocs/manual/release_distribution_guide.md`, `mydocs/manual/release_packaging_dmg_guide.md`, `mydocs/release/v0.1.1.md`에 반영했다. #188 public release 실행 시 signed/notarized public DMG를 mount한 뒤 app bundle `Contents/Info.plist`의 `NSHumanReadableCopyright`와 `Contents/Resources/Legal/{LICENSE,THIRD_PARTY_LICENSES.md,FONTS.md}` 존재 및 canonical 문서 대비 동일성을 반복 검증한다.
