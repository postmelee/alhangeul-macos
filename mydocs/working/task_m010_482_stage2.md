# Task #482 Stage 2 완료보고서

## 단계 목적

원본 bytes에서 얻은 HWP3 source identity를 native 저장 요청에 결합하고, 평문 HWP3의 일반 저장을 변환 경고와 다른 이름 저장 흐름으로 전환한다. HWP3 변환 결과는 존재하지 않는 신규 destination에만 기록하며, 기존 평문 HWP5/HWPX in-place 저장과 #480 보호 문서 평문 복사본 정책은 유지한다.

## 산출물

- HWP3 magic 기반 Foundation-only source format identity와 HWP3 → HWP5/HWPX conversion intent
- 보호 해제와 형식 변환을 독립 계산한 뒤 한 번의 경고로 합성하는 warning intent
- 평문 HWP3 `Command+S`의 in-place 차단과 save panel 전환
- 원본 동일·표준화·대소문자 변형·symlink·다른 기존 파일 destination의 fail-closed 거부
- 보호/변환 조합별 제안 파일명과 실제 출력 형식 안내
- pending request의 revision·보호 상태·source identity·destination 반복 재검증
- 기존 파일을 덮어쓰지 않는 HWP3 변환 write 정책과 단위 회귀

upstream, Rust FFI, `rhwp-core.lock`, bundled `rhwp-studio` asset, `project.yml`과 Xcode project는 변경하지 않았다.

## 구현 내용

### source identity와 변환 의도

`DocumentSourceFormatIdentity`가 원본 payload의 `HWP Document File` magic prefix를 기준으로 HWP3와 그 외 형식을 구분한다. `RhwpStudioDocumentPayload`는 이 Foundation-only 판정을 저장 정책의 진실 원천으로 사용한다. 확장자가 같은 HWP3와 HWP5를 URL만으로 구분하지 않는다.

`DocumentSaveConversionIntent`는 source identity와 요청 output format에서 다음을 계산한다.

| source identity | output format | conversion intent |
|-----------------|---------------|-------------------|
| HWP3 | HWP | HWP3 → HWP5 |
| HWP3 | HWPX | HWP3 → HWPX |
| 그 외 | HWP/HWPX | 변환 없음 |

저장 요청에 캡처된 conversion intent가 source identity와 output format에서 다시 계산한 값과 다르면 요청을 거부한다.

### in-place와 destination 정책

in-place 저장은 `평문 + 비-HWP3 + source URL 형식과 output format 일치`일 때만 허용한다. 따라서 평문 HWP3의 `Command+S`도 exporter로 바로 진행하지 않고 변환 경고와 save panel을 거친다.

HWP3 conversion intent가 있는 요청은 보호 상태와 source URL 유무에 관계없이 다음 조건을 강제한다.

- canonical source URL과 같은 destination 거부
- 표준화 경로, 대소문자 차이와 symlink로 같은 원본을 가리키는 destination 거부
- 원본이 아니더라도 이미 존재하는 모든 destination 거부
- 존재하지 않는 신규 destination만 허용

정책은 save panel 반환 뒤, exporter 호출 직전, payload 검증 뒤와 실제 write 직전에 반복 적용된다. pending request의 document revision, source protection과 source identity 중 하나라도 현재 문서와 달라지면 export/write를 중단한다.

### 경고와 제안 파일명

보호 해제 필요 여부와 HWP3 변환 여부를 별도 intent로 계산한 뒤 하나의 alert로 합성한다.

| source 상태 | 경고 확인 버튼 | 제안 파일명 |
|-------------|----------------|-------------|
| 평문 HWP3 | `변환 복사본 저장` | `원본 (변환 복사본).hwp` 또는 `.hwpx` |
| 보호/미지원/불명 HWP3 | `평문 변환 복사본 저장` | `원본 (평문 변환 복사본).hwp` 또는 `.hwpx` |
| 평문 비-HWP3 | 경고 없음 | 기존 정규화 파일명 |
| 보호/미지원/불명 비-HWP3 | `평문 복사본 저장` | `원본 (평문 복사본).hwp` 또는 `.hwpx` |

HWP3의 `.hwp` 출력은 단순 HWP가 아니라 실제 변환 결과인 HWP5로 안내한다. 보호된 HWP3는 보호 해제와 형식 변환을 두 개의 연속 alert로 나누지 않고 한 alert에서 함께 설명한다.

### write와 성공 상태

일반 저장은 기존 `.atomic` write를 유지한다. Stage 2 최초 구현은 HWP3 변환 저장에 `.withoutOverwriting`을 사용했지만, PR #483 리뷰에서 write 도중 실패하면 잘린 destination이 남을 수 있음이 확인됐다. 최종 PR 후보는 변환 payload를 destination과 같은 디렉터리의 고유 임시 파일에 atomic write한 뒤 `renameatx_np(..., RENAME_EXCL)`로 배타적으로 게시한다. 임시 write 또는 publish가 실패하면 destination을 만들거나 교체하지 않고 임시 파일을 정리한다.

저장 성공 뒤에만 export bytes와 destination URL을 current document에 기록한다. HWP5/HWPX output bytes로 payload가 교체되면 source identity가 `other`로 전환되므로 후속 same-format `Command+S`는 기존 평문 in-place 조건을 사용할 수 있다. 취소·정책 거부·export/payload/write 오류에서는 성공 상태를 기록하지 않는다.

## 안전 경계와 write 시점

| 시점 | 검증/동작 | 실패 시 결과 |
|------|-----------|--------------|
| 경고 전 | protection과 conversion warning intent 계산 | 경고 없는 HWP3 export 불가 |
| 경고 확인 후 | revision·protection·source identity 재검증 | save panel 진입 전 중단 |
| save panel 반환 후 | current document와 destination 정책 검증 | exporter 호출 전 중단 |
| exporter 호출 직전 | pending request 전체 재검증 | export 요청 미등록 |
| payload 응답 검증 | current document, signature·byte count·format·destination 재검증 | write 미실행 |
| 실제 write 직전 | pending request 전체 재검증 | write 미실행 |
| conversion temporary write | 같은 디렉터리 고유 임시 파일에 atomic write | 실패 시 destination 미생성, 임시 파일 정리 |
| conversion publish | `renameatx_np(..., RENAME_EXCL)` 배타적 rename | 경쟁 중 생성된 기존 파일 보존, 완성된 payload만 노출 |
| write 성공 후 | payload·source URL·저장 상태 갱신 | 새 output 형식으로 전환 |

## 단위 회귀

다음 항목을 `DocumentSaveContractTests`에 추가하거나 기존 회귀를 보정했다.

- HWP3 magic과 비-HWP3 bytes 판정
- HWP3 → HWP5/HWPX conversion intent 및 불일치 요청 거부
- 평문 비-HWP3만 in-place 허용
- protection-only, conversion-only, protection+conversion 경고 intent
- 변환 write의 기존 destination 거부·기존 bytes 보존·신규 경로 성공과 일반 atomic write 유지
- 임시 write가 일부 bytes를 남긴 뒤 실패해도 destination과 임시 파일이 남지 않음
- 원본 동일 URL, 표준화 경로, 대소문자 변형과 symlink destination 거부
- 다른 기존 destination과 source URL 없는 기존 destination 거부
- 평문/보호 HWP3의 신규 destination 허용
- 보호/변환 네 조합의 제안 파일명
- revision·protection·source identity 변경 시 current document 요청 거부
- 기존 plain-copy destination과 HWP/HWPX payload 검증 회귀 유지

## 본문 변경 정도와 무손실 확인

- 제품 소스: HostApp 서비스·WebView 5개 파일 수정
- 테스트: HostAppTests 1개 파일 수정
- 단계 문서: 이 Stage 2 완료보고서 신규 작성
- 오늘할일: Stage 2 완료와 Stage 3 승인 대기로 갱신
- upstream/Rust/asset/dependency/Xcode project: 변경 없음
- fixture와 사용자 문서: 변경 없음

`xcodegen generate` 뒤 `Alhangeul.xcodeproj`와 `project.yml`에는 diff가 생기지 않았다. Stage 2는 정책·단위·build 검증까지만 수행했으며 계획상 Stage 3 범위인 Debug app HWP3 fixture smoke와 사용자 문서 보정은 시작하지 않았다.

## 검증 결과

| 명령/검증 | 결과 |
|-----------|------|
| `xcodegen generate` | 통과. project 재생성 뒤 project/source 설정 diff 없음 |
| `xcodebuild ... -scheme HostAppTests ... test` | Stage 완료 시 142 tests, 0 failures. PR 리뷰 보정 뒤 143 tests, 0 failures |
| `xcodebuild ... -scheme HostApp ... build` | 통과. Debug HostApp build 성공 |
| `./scripts/check-no-appkit.sh` | 통과. `RhwpCoreBridge` AppKit 의존 없음 |
| `scripts/verify-rhwp-studio-assets.sh` | 통과. 저장소 bundled asset 무결성 확인 |
| built app 대상 `scripts/verify-rhwp-studio-assets.sh` | 통과. Debug app 내 asset 무결성 확인 |
| `git diff --check` | 통과. whitespace 오류 없음 |
| LaunchServices 개발 등록 확인 | repo `build.noindex` 아래 Sparkle `Updater.app` 21개 정확한 경로를 등록 해제한 뒤 development registration 없음 |

첫 HostAppTests 실행은 sandbox DNS 제한으로 dependency 조회에 실패해 동일 명령을 허용된 외부 네트워크 환경에서 재실행했다. 구현 중 Swift의 optional switch 결과 타입 추론 오류는 명시적 `String?`으로 보정했다. 변환 write 테스트가 `.atomic + .withoutOverwriting` 조합의 Foundation fatal을 드러내어 최초 Stage에서는 두 옵션을 분리했다. PR #483 리뷰 뒤 임시 atomic write와 `RENAME_EXCL` 배타적 게시로 다시 보정하고 실패 주입 회귀를 추가했으며, 최종 전체 143개 테스트가 통과했다.

빌드에는 기존 `RhwpStudioPagePDFRenderer.swift`의 Swift 6 main-actor 관련 warning이 남지만 이번 변경 파일과 무관하며 실패를 만들지 않았다.

## 잔여 위험

- Stage 2 단위 테스트는 Foundation-only 정책을 검증한다. 실제 alert 문구, save panel 전환, exporter 호출 순서와 저장 성공 뒤 후속 `Command+S`는 Stage 3 Debug app fixture smoke로 확인해야 한다.
- 변환 저장의 임시 write·배타적 publish 실패는 destination을 만들지 않도록 자동 회귀로 고정했다. 지원하지 않는 파일시스템에서 `RENAME_EXCL`이 실패하면 저장은 실패하지만 기존 destination과 원본은 보존된다.
- LaunchServices development registration은 정리 후 없지만 PlugInKit에는 설치본 provider가 `/Applications/Alhangeul.app`과 `/Users/melee/Applications/Alhangeul.app` 두 위치에 남아 있다. 설치본 파일이나 provider 등록 변경은 Stage 2 권한·범위 밖이므로 건드리지 않았다.
- 실제 HWP3 → HWP5/HWPX content fidelity는 serializer 범위이며 이번 단계는 원본·기존 파일 덮어쓰기 차단을 담당한다. fixture smoke에서 예상 밖 content loss를 발견하면 계획의 분기 기준에 따라 별도 범위를 제안한다.

## 다음 단계 영향

Stage 3는 공개 HWP3 fixture의 `build.noindex/` 복사본과 Debug app으로 경고 취소, save panel 취소, 원본·기존 destination 거부, HWP5/HWPX 신규 저장, 원본 hash 보존과 변환본의 후속 `Command+S`를 검증한다. 평문 HWP5/HWPX와 #480 보호 문서 정책 회귀도 함께 확인하고, 실제 결과에 맞춰 README·v0.1.10 업데이트·릴리스 문서를 보정한다.

## 승인 요청

Stage 2 `HWP3 원본 덮어쓰기 차단` 구현과 자동 검증을 완료했다. Stage 3 `변환 회귀 검증과 문서 보정` 진행 승인을 요청한다.
