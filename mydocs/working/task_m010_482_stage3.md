# Task #482 Stage 3 완료보고서

## 단계 목적

평문 HWP3의 HWP5/HWPX 변환 저장을 공개 fixture와 Debug HostApp으로 검증하고, 원본·기존 파일 보호, 취소, 저장 성공 뒤 후속 저장, 기존 평문 HWP5/HWPX와 #480 보호 문서 정책의 회귀가 없는지 확인한다. 실제 지원 범위에 맞춰 README와 v0.1.10 공개·내부 릴리스 문서를 보정한다.

## 산출물

- 평문 HWP3 `Command+S`의 변환 경고와 save panel 전환 smoke
- HWP3 → HWP5/HWPX 신규 destination 저장, signature, 원본 hash 보존과 후속 `Command+S` 확인
- 경고 취소, save panel 취소, 원본·다른 기존 destination 거부와 기존 bytes 보존 확인
- 평문 HWP5/HWPX same-format in-place 저장 회귀 확인
- 보호 HWP3/HWP5/HWPX의 #480 보호 해제 경고 회귀 확인
- HWP3 원형 저장과 native 암호 저장의 실제 한계를 명시한 README·v0.1.10 업데이트·릴리스 기록 보정

Stage 3에서는 제품 소스, 단위 테스트, upstream, Rust FFI, dependency pin, bundled `rhwp-studio` asset과 Xcode project를 변경하지 않았다.

## fixture와 실행 기준

| 항목 | 기준 |
|------|------|
| Debug HostApp | `build.noindex/task482-stage3-derived-data/Build/Products/Debug/Alhangeul.app` |
| pinned core/studio | `rhwp v0.8.4`, `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| exact upstream checkout | `build.noindex/task472-stage3-upstream-rhwp` |
| 공개 fixture | upstream `samples/hwp3-sample.hwp`, `samples/hwp3-sample-hwp5.hwp`, `samples/hwp3-sample-hwpx.hwpx`, `samples/HWP3-password-123456.hwp`, `samples/hwp3-sample16-hwp5-2024-password-123456.hwp`, `samples/HWP5-password-123456.hwpx`의 일회성 복사본 |
| smoke 경로 | `build.noindex/task482-stage3-smoke/` |
| 평문 HWP3 원본 SHA-256 | `645525c8cd5ec11b1742ba7cfc759f68622861916233b5e982385cdb12f0ced2` |

모든 열기·저장·거부 smoke는 `build.noindex/` 복사본으로 수행했다. exact upstream checkout, 저장소 샘플과 사용자 문서는 수정하지 않았다.

## fixture 회귀 결과

| 입력/행위 | 실제 결과 | 판정 |
|-----------|-----------|------|
| 평문 HWP3 + `Command+S` | `HWP3 원형을 유지한 채 저장할 수 없습니다.`와 요청 형식 변환 문구 표시 뒤 save panel 진입, 원본 SHA 유지 | 통과 |
| 평문 HWP3 → HWP5 | 신규 `plain-hwp5-converted.hwp`, HWP 5.x CFB, SHA `4c537176...3d95b`, 원본 SHA 유지 | 통과 |
| HWP5 변환본 후속 `Command+S` | 추가 경고·panel 없이 `저장 완료`, 같은 URL mtime 갱신 | 통과 |
| 평문 HWP3 → HWPX | 신규 `plain-hwpx-converted.hwpx`, ZIP/HWPX, SHA `7e67c481...c9e99`, 원본 SHA 유지 | 통과 |
| HWPX 변환본 후속 `Command+S` | 추가 경고·panel 없이 `저장 완료`, 같은 URL mtime 갱신 | 통과 |
| 변환 경고 취소 | exporter 결과와 write 없이 원본 SHA 유지 | 통과 |
| save panel 취소 | 기본 이름 `plain-panel-cancel (변환 복사본).hwp` 확인 뒤 취소, 결과 파일 없음과 원본 SHA 유지 | 통과 |
| 원본 destination 선택 | macOS 대치 확인 뒤에도 HostApp이 `HWP3 변환 복사본은 원본과 다른 새 파일에 저장해야 합니다.`로 거부, 원본 SHA 유지 | 통과 |
| 다른 기존 destination 선택 | HostApp이 `HWP3 변환 복사본은 기존 파일을 덮어쓸 수 없습니다. 새 파일 이름을 선택해 주세요.`로 거부, 원본과 destination SHA 유지 | 통과 |
| 평문 HWP5 `Command+S` | 경고·panel 없는 in-place 저장, HWP 5.x 유지 | 통과 |
| 평문 HWPX `Command+S` | 경고·panel 없는 in-place 저장, ZIP/HWPX 유지 | 통과 |
| 보호 HWP3 | 보호 해제와 HWP3 → HWP5 변환을 한 alert에 표시, `평문 변환 복사본 저장` 버튼 확인 뒤 취소 | 통과 |
| 보호 HWP5/HWPX | 보호 해제 경고와 `평문 복사본 저장` 버튼 유지 확인 뒤 취소 | 통과 |

HWP3 → HWP5 결과의 후속 저장 전후 SHA는 `4c537176ce8f734ab977c7c2813c059adcfd401d6abaf364fcd93acd79b3d95b`로 같고, HWP3 → HWPX 결과도 `7e67c4818ef25adcc31996b77c85f4197673c0408414e0b6605302e8392c9e99`로 같았다. 편집하지 않은 같은 payload를 다시 저장한 결과가 결정적이었으며 mtime은 각각 후속 저장 시점으로 갱신됐다.

평문 HWP5 회귀 fixture는 in-place 저장 뒤 HWP 5.x와 SHA `c4fa65282130349dd5f450e680378279072c570140b122bc1037afbb3fceb628`을, 평문 HWPX fixture는 ZIP/HWPX와 SHA `e82790fb5c2d2ca0d957efae320b622d33b145dbe9b59cdb948cc1ba3df30a77`을 유지했다. 보호 fixture는 취소 뒤 HWP3 `db743d084efc9e08e839a5b4d978b16b8676434011776e090e4cda43e57304be`, HWP5 `59d4bed335b9552fe78fa68d2a56f7cfa3d586bcdeaaba839af80df13f3e08dc`, HWPX `93e7a62565e0f3efa4feee2812aaf518347dbbcc09d2f26a0d9385f9a4e26060` 원본 SHA를 유지했다.

## 사용자 문서 보정

### 공개 v0.1.10과 현재 수정 동작 분리

- PR #483 최초 문서는 #480/#482 수정 동작을 v0.1.10에 이미 포함된 것처럼 기술했다.
- 리뷰 보정에서 v0.1.10 업데이트 페이지와 최신 공개 릴리스 요약은 실제 배포본의 HWP3·보호 문서 원본 덮어쓰기 위험과 사본 보관 권고를 명시하도록 고쳤다.
- 수정된 평문 HWP3의 신규 HWP5/HWPX 변환 복사본 전용 저장은 README의 현재 기능 설명에 유지하고 다음 릴리스 기록으로 분리했다.

### 암호 문서 저장 범위

- upstream core/studio의 암호 parser·exporter 지원과 알한글 native 저장 경로를 분리했다.
- 암호 문서는 열 수 있지만 현재 native 저장은 보호 유지나 새 암호 설정을 지원하지 않는다고 명시했다.
- v0.1.10 배포본의 무경고 평문 원본 덮어쓰기 위험과, #480 이후 사용자 확인·신규 평문 복사본 전용 안전 경계를 서로 다른 시점으로 기록했다.

보정 대상은 `README.md`, `docs/updates/v0.1.10.html`, `mydocs/release/v0.1.10.md`다. 공개 문서에는 fixture hash나 로컬 경로를 넣지 않았다.

## 본문 변경 정도와 무손실 확인

- 제품 소스와 테스트: 변경 없음
- 사용자 문서: README와 v0.1.10 업데이트 페이지 보정
- 내부 릴리스 기록: upstream 기능과 native 저장 지원 경계, #480/#482 제한 추가
- 단계 문서: 이 Stage 3 완료보고서 신규 작성
- 오늘할일: Stage 3 완료와 최종 보고 승인 대기로 갱신
- fixture, build와 테스트 산출물: `build.noindex/`에만 존재하며 commit 대상 아님

`xcodegen generate` 뒤 `Alhangeul.xcodeproj`와 `project.yml`에는 diff가 생기지 않았다.

## 자동 검증 결과

| 명령/검증 | 결과 |
|-----------|------|
| `xcodegen generate` | 통과. project 재생성 뒤 project/source 설정 diff 없음 |
| `xcodebuild ... -scheme HostAppTests ... test` | Stage 완료 시 142 tests, 0 failures. PR 리뷰 보정 뒤 143 tests, 0 failures |
| `xcodebuild ... -scheme HostApp ... build` | 통과. Debug HostApp build 성공 |
| `./scripts/check-no-appkit.sh` | 통과. shared Swift code AppKit/UIKit 의존 없음 |
| `scripts/verify-rhwp-studio-assets.sh` | 통과. 저장소 bundled asset 무결성 확인 |
| built app `Contents/Resources/rhwp-studio` asset 검증 | 통과. Debug app 내 asset 무결성 확인 |
| `scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations` | 통과. development registration 없음 |
| `scripts/check-extension-registration-hygiene.sh --check-only` | 통과. issue 없음, build.noindex 앱은 존재하지만 등록되지 않음 |
| `git diff --check` | 통과. whitespace 오류 없음 |

첫 HostAppTests 실행은 sandbox DNS 제한으로 Sparkle checkout에 실패했다. 같은 명령을 승인된 외부 실행으로 다시 수행해 Sparkle 2.9.1을 해석하고 Stage 완료 시 전체 142개 테스트를 통과했다. PR 리뷰 보정 뒤 실패 주입 회귀 1개를 추가해 전체 143개 테스트를 다시 통과했다. 빌드에는 기존 `RhwpStudioPagePDFRenderer.swift`의 Swift 6 main-actor warning이 남지만 이번 변경과 무관하며 실패를 만들지 않았다.

UI smoke 뒤 Debug 앱과 접근성 확인용 임시 앱을 종료하고 등록 cleanup을 반복했다. 최종 helper 결과는 development registration과 legacy candidate가 없고, Quick Look/Thumbnail provider path는 PlugInKit이 보고하지 않았다는 warning만 남겼다.

## 잔여 위험과 관찰

- HWP3 변환은 container signature, 원본·destination 보호와 후속 저장까지 확인했지만 exporter의 모든 문서 요소가 의미론적으로 완전 무손실임을 보장하지 않는다.
- HWPX runtime guard는 ZIP magic을 확인하며 필수 entry 전체 검증은 bundled exporter와 재열기 smoke에 의존한다.
- HWP3 문서를 저장한 뒤 앱을 종료할 때 저장 직후에도 unsaved-changes 경고가 한 차례 다시 관찰됐다. #480 Stage 1에서도 같은 현상이 기록됐고 변환 파일 write·후속 `Command+S`와 원본 보존은 정상이다. 이번 원본 덮어쓰기 차단의 blocker로 보지 않았으며 반복 원인 조사는 별도 승인 범위로 남긴다.
- `build.noindex/` 아래 과거·현재 개발 app bundle은 남아 있지만 최종 등록 위생 검사에서 어떤 개발 경로도 등록되지 않았다.

## 다음 단계 영향

세 Stage의 구현과 검증이 완료됐다. 다음 단계는 작업지시자 승인 뒤 `task-final-report` 절차로 최종 보고서, 오늘할일 완료 처리, 최종 검증, `publish/task482` push와 `devel` 대상 PR을 준비하는 것이다. 이 Stage에서는 최종 보고서, 원격 push와 PR을 시작하지 않는다.

## 승인 요청

Stage 3 `HWP3 변환 회귀 검증과 문서 보정`을 완료했다. 단계 결과 승인과 Task #482 최종 보고·PR 단계 진입 승인을 요청한다.
