# Task #482 Stage 1 완료보고서

## 단계 목적

v0.1.10 release app과 exact pinned `rhwp v0.8.4`의 공개 평문 HWP3 fixture를 기준으로, 일반 저장이 HWP3 원본을 경고 없이 HWP5로 덮어쓰는 회귀를 재현한다. 재현 결과를 바탕으로 Stage 2에서 적용할 source format identity, 변환 경고, 제안 파일명, 신규 destination과 후속 저장 계약을 제품 소스 변경 전에 확정한다.

## 산출물

- v0.1.10 release app에서 평문 HWP3 `Command+S`의 무경고 HWP5 원본 덮어쓰기 실증
- HWP/HWPX 다른 이름 저장 결과의 signature와 원본 보존 확인
- save panel 취소와 기존 destination 덮어쓰기 확인 취소의 원본·기존 파일 보존 확인
- 보호 상태와 HWP3 변환 여부를 합성한 네 가지 사용자 경고·버튼·제안 파일명 계약 확정
- HWP3 변환 결과를 존재하지 않는 신규 destination에만 허용하는 fail-closed 정책 확정
- upstream, Rust FFI와 bundled `rhwp-studio` 변경 없이 HostApp 내부 정책으로 Stage 2를 수행할 수 있다는 판정

제품 소스, 테스트 target, dependency pin과 bundled upstream asset은 이번 단계에서 변경하지 않았다. 재현 fixture 복사본과 export 결과는 `build.noindex/task482-stage1-reproduction/` 아래에만 두고 커밋하지 않는다.

## exact 기준과 provenance

| 항목 | 확인 결과 |
|------|-----------|
| release app | `/Applications/Alhangeul.app` |
| app version | `0.1.10` (`CFBundleVersion` 16) |
| pinned core | `rhwp v0.8.4` |
| resolved commit | `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| exact upstream checkout | `build.noindex/task472-stage3-upstream-rhwp`의 HEAD가 resolved commit과 일치 |
| 공개 fixture | upstream `samples/hwp3-sample.hwp`의 일회성 복사본 |
| fixture SHA-256 | `645525c8cd5ec11b1742ba7cfc759f68622861916233b5e982385cdb12f0ced2` |
| fixture identity | `HWP Document File V3.00` magic, `file` 판정 HWP 3.0 |

`scripts/verify-rhwp-studio-assets.sh`도 저장소에 bundled된 Studio asset 무결성을 통과했다. 저장소 `samples/`, exact upstream checkout과 사용자 문서는 수정하지 않고 `build.noindex/` 복사본만 앱에 열었다.

## release app 재현 결과

각 행은 같은 HWP3 fixture에서 별도로 만든 복사본으로 수행했다. 글꼴 확인에서는 `대체 글꼴로 보기`를 선택했으며 문서 내용을 편집하지 않았다.

| 경로 | 저장 전 SHA-256 | 저장 후/출력 SHA-256 | 결과 signature | 원본 보존 | 관찰 결과 |
|------|-----------------|----------------------|------------------|-----------|-----------|
| `Command+S` | `645525c8...f0ced2` | `4c537176...3d95b` | CFB `d0 cf 11 e0 a1 b1 1a e1`, HWP 5.x | 아니요 | 경고·save panel 없이 `저장 완료`가 표시되고 같은 URL을 HWP5로 덮어씀 |
| HWP 다른 이름 저장 | `645525c8...f0ced2` | `4c537176...3d95b` | CFB `d0 cf 11 e0 a1 b1 1a e1`, HWP 5.x | 예 | `converted-copy.hwp` 생성, 원본 HWP3 hash 유지 |
| HWPX 다른 이름 저장 | `645525c8...f0ced2` | `7e67c481...9e99` | ZIP `50 4b 03 04`, HWPX | 예 | `converted-copy.hwpx` 생성, 원본 HWP3 hash 유지 |
| save panel 취소 | `645525c8...f0ced2` | `645525c8...f0ced2` | `HWP Document File V3.00` | 예 | export 결과 파일 없이 문서 화면으로 복귀 |

HWP 다른 이름 저장의 기본 이름은 원본과 같은 `save-as-hwp.hwp`였고, HWPX 다른 이름 저장은 확장자만 정규화한 `save-as-hwpx.hwpx`였다. 현재 UI에는 HWP3가 HWP5/HWPX로 변환된다는 경고나 변환을 드러내는 기본 파일명이 없다.

`Command+S` 결과와 HWP 다른 이름 저장 결과의 SHA-256이 같은 점도 확인됐다. 따라서 회귀의 핵심은 HWP3용 별도 exporter 유무가 아니라, 동일한 HWP5 export 결과를 평문 `.hwp`라는 이유만으로 원본 URL에 쓰도록 허용하는 HostApp in-place 판단이다.

## 현재 save panel과 write 시점

별도 HWP3 복사본 `existing-target.hwp`를 기존 destination으로 준비하고 다음 순서를 확인했다.

1. HWP3 문서에서 `Command+Shift+S`로 native HWP save panel을 열었다.
2. 기존 `existing-target.hwp`를 이름으로 지정하고 `저장`을 눌렀다.
3. macOS가 `파일이 이미 존재합니다. 대치하겠습니까?` 확인을 표시했다.
4. `취소`한 뒤 save panel도 취소했다.
5. 열려 있던 `cancel.hwp`와 기존 destination의 SHA-256이 모두 원래 fixture hash를 유지했다.

현재 코드 흐름에서도 `DocumentSavePanel.chooseDestinationURL`이 완료된 뒤에야 `PendingSaveRequest` 생성과 Studio export 요청이 이어진다. 따라서 macOS overwrite 확인은 HostApp export/write 전에 발생한다. 다만 사용자가 `대치`를 선택하면 현행 평문 HWP3 정책은 그 기존 파일을 HWP5 결과로 덮어쓸 수 있으므로, Stage 2는 운영체제 확인창에 안전을 위임하지 않는다.

## Stage 2 사용자 경고·파일명 계약

HWP3의 `.hwp` 출력 표시는 단순 `HWP`가 아니라 실제 결과인 `HWP5`로 설명한다. 보호 해제와 HWP3 변환이 동시에 필요한 경우 두 alert를 연속 표시하지 않고 하나의 alert가 두 변화를 모두 알린다.

| source protection | source format | alert 제목·설명 | 확인 버튼 | 제안 파일명 |
|-------------------|---------------|-----------------|-----------|-------------|
| 평문 | HWP3 | `HWP3 원형을 유지한 채 저장할 수 없습니다.` / `현재 편집 내용은 HWP5 또는 HWPX 형식으로 변환됩니다. 원본은 변경하지 않고 새 변환 복사본으로 저장합니다.` | `변환 복사본 저장` | `원본 (변환 복사본).hwp` 또는 `.hwpx` |
| 보호/미지원/불명 | HWP3 | 기존 보호 상태별 설명 뒤 `HWP3 원형은 보존되지 않으며 HWP5 또는 HWPX 형식으로 변환됩니다. 원본은 변경하지 않고 새 파일에만 저장합니다.`를 한 alert에 표시 | `평문 변환 복사본 저장` | `원본 (평문 변환 복사본).hwp` 또는 `.hwpx` |
| 평문 | HWP5/HWPX | 변환·보호 경고 없음. 기존 same-format 저장 유지 | 해당 없음 | 기존 정규화 파일명 |
| 보호/미지원/불명 | HWP5/HWPX | 기존 `원본의 문서 보호를 유지한 채 저장할 수 없습니다.`와 보호 상태별 평문 복사본 설명 유지 | `평문 복사본 저장` | `원본 (평문 복사본).hwp` 또는 `.hwpx` |

표의 `HWP5 또는 HWPX`는 한 alert에 두 형식을 나열한다는 의미가 아니다. 실제 요청 output format에 따라 HWP3 → HWP5 또는 HWP3 → HWPX 중 하나만 표시한다.

경고를 취소하면 exporter를 호출하지 않고 current payload, source URL, dirty/clean 상태와 원본 bytes를 바꾸지 않는다.

## 신규 destination 계약

HWP3 변환 의도가 있는 요청은 보호 상태와 무관하게 다음 규칙을 적용한다.

- canonical source URL과 같은 destination은 거부한다.
- symlink 해소, 표준화와 대소문자 비구분 비교 뒤 같은 파일을 가리키는 경로도 거부한다.
- source URL 유무와 관계없이 이미 존재하는 모든 destination을 거부한다.
- 존재하지 않는 신규 경로만 허용한다.
- save panel 반환 뒤, exporter 호출 직전, payload 검증 뒤 write 직전에 같은 정책을 재검증한다.
- 기존 파일을 선택했을 때 오류 문구는 `HWP3 변환 복사본은 기존 파일을 덮어쓸 수 없습니다. 새 파일 이름을 선택해 주세요.`로 한다.
- 원본과 동일한 경로를 선택했을 때 오류 문구는 `HWP3 변환 복사본은 원본과 다른 새 파일에 저장해야 합니다.`로 한다.

이 계약은 macOS overwrite 확인에서 사용자가 `대치`를 선택해도 HostApp write가 실행되지 않게 한다. 취소·정책 거부·export 오류·payload 오류·write 오류에서는 성공 상태나 source URL을 갱신하지 않는다.

## Stage 2 최소 정책 API 계약

Stage 2의 Foundation-only 정책 표면은 다음 책임을 제공해야 한다. 실제 타입 이름은 기존 `DocumentSaveContract.swift`와의 일관성에 맞춰 정하되 의미는 축소하지 않는다.

| 책임 | 최소 입력·결과 |
|------|----------------|
| source format identity | 원본 bytes의 HWP3 magic을 typed identity(`hwp3`/`other`)로 판정 |
| conversion intent | source identity와 output format에서 HWP3 → HWP5/HWPX 변환 여부 계산 |
| in-place eligibility | source가 평문이고 HWP3가 아니며 source URL 형식과 output format이 같은 경우만 허용 |
| destination validation | conversion intent, source URL, destination URL과 파일 존재 여부를 받아 신규 destination만 허용 |
| suggested filename | protection intent와 conversion intent를 합성해 세 종류의 복사본 suffix 적용 |
| current document validation | request의 revision, source protection, source identity가 현재 문서와 모두 같은지 확인 |

`PendingSaveRequest`는 revision, source protection, output protection intent와 함께 source identity/conversion intent를 캡처한다. 저장 성공 뒤에만 export bytes와 destination URL을 current document에 기록한다. HWP5/HWPX 결과가 current payload가 되면 source identity는 더 이상 HWP3가 아니므로, 후속 same-format `Command+S`는 기존 평문 HWP5/HWPX in-place 규칙을 사용할 수 있다.

## 본문 변경 정도와 무손실 확인

- 제품 소스와 테스트: 변경 없음
- bundled `rhwp-studio` asset: 변경 없음
- `rhwp-core.lock`, Xcode project와 dependency: 변경 없음
- 조사 문서: 이 Stage 1 완료보고서 신규 작성
- 오늘할일: Stage 1 완료와 Stage 2 승인 대기로 상태 갱신
- 재현 fixture와 export 산출물: `build.noindex/`에만 존재하며 commit 대상 아님

upstream fixture와 저장소 샘플, 사용자 문서는 수정하지 않았다. `Command+S`로 변경한 파일도 독립된 일회성 복사본이다. 취소·기존 destination 검증용 두 파일은 종료 시 원래 HWP3 SHA-256을 유지했다. 설치된 release app만 사용했으므로 개발용 `.app`/`.appex`를 LaunchServices에 새로 등록하지 않았고, UI smoke 뒤 앱을 종료했다.

## 검증 결과

| 명령/검증 | 결과 |
|-----------|------|
| `git -C build.noindex/task472-stage3-upstream-rhwp rev-parse HEAD` | 통과. `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| `shasum -a 256 build.noindex/task482-stage1-reproduction/*.hwp` | 통과. 원본·취소·기존 destination은 fixture hash 유지, `Command+S`와 HWP 변환 결과만 HWP5 hash로 변경 |
| `file build.noindex/task482-stage1-reproduction/*` | 통과. 입력·보존본 HWP 3.0, HWP 결과 HWP 5.x, HWPX 결과 ZIP 판정 |
| magic prefix 보조 확인 | HWP3 `HWP Document File V3.00`, HWP5 CFB `d0 cf 11 e0 a1 b1 1a e1`, HWPX ZIP `50 4b 03 04` |
| `scripts/verify-rhwp-studio-assets.sh` | 통과. `OK: rhwp-studio assets verified` |
| `git diff --check` | 통과. whitespace 오류 없음 |
| v0.1.10 release app UI smoke | 평문 HWP3 `Command+S` 무경고 HWP5 덮어쓰기 재현, 다른 이름 HWP/HWPX 변환·취소·기존 destination 확인 완료 |

Stage 1 계획대로 production source와 test target을 변경하지 않았으므로 Xcode build와 unit test는 실행하지 않았다.

## 잔여 위험

- HWP3 magic 판정과 pending request capture가 서로 다른 bytes나 revision을 참조하면 문서 교체 직후 잘못된 저장이 가능하다. source identity를 revision과 함께 재검증해야 한다.
- save panel이 기존 파일 확인을 처리하더라도 확인 뒤 destination 상태가 바뀌는 TOCTOU가 있다. exporter 전과 write 직전의 파일 존재 여부 재검증이 필요하다.
- `FileManager.fileExists`만으로 source와 symlink·대소문자 변형 경로의 동일성을 판정할 수 없다. canonical URL 비교와 기존 파일 거부를 함께 적용해야 한다.
- HWP3를 HWP5/HWPX로 저장한 뒤 current payload identity와 source URL을 성공 시점에 정확히 갱신해야 후속 저장이 불필요한 변환 경고에 머물지 않는다.
- 보호된 HWP3는 #480의 보호 해제 정책과 이번 변환 정책을 함께 거쳐야 한다. 어느 한쪽만 검사하면 원본 보호 또는 원형 보존 오해가 다시 생긴다.
- Stage 1 UI smoke는 설치된 v0.1.10 release app의 현재 동작을 관찰한 것이다. Stage 2 구현 뒤 실제 신규 destination 거부와 후속 저장 상태는 unit test와 Debug app fixture smoke로 다시 검증해야 한다.

## 다음 단계 영향

Stage 2는 `DocumentSaveContract.swift`를 중심으로 HWP3 source identity와 conversion intent를 추가하고, `RhwpStudioWebView`의 in-place 판단·pending request·destination 재검증과 `DocumentProtectionSaveAlert`의 단일 합성 경고를 연결한다. 핵심 정책은 Foundation-only 단위 테스트로 고정하고 WebView orchestration은 HostApp build와 Stage 3 fixture smoke로 보강한다.

원인과 안전 경계가 모두 HostApp 저장 정책에 있으므로 upstream, Rust FFI, `rhwp-core.lock` 또는 bundled `rhwp-studio`를 변경할 필요가 없다. 기존 평문 HWP5/HWPX same-format 저장과 #480 보호 문서 평문 복사본 정책은 회귀 테스트 대상으로 유지한다.

## 승인 요청

Stage 1 평문 HWP3 저장 회귀 재현과 변환·destination 계약 확정을 완료했다. Stage 2 `HWP3 원본 덮어쓰기 차단` 구현 진행 승인을 요청한다.
