# Task M010 #482 구현계획서

## 1. 개요

- 이슈: [#482 평문 HWP3 저장 시 무경고 HWP5 원본 덮어쓰기를 차단한다](https://github.com/postmelee/alhangeul-macos/issues/482)
- 마일스톤: `M010` (`v0.1`)
- 대상 통합 브랜치: `devel`
- 작업 브랜치: `local/task482`
- 게시 브랜치: `publish/task482`
- 수행계획서: `mydocs/plans/task_m010_482.md`
- 단계 수: 3

이 문서는 평문 HWP3의 저장 결과가 HWP5 또는 HWPX 변환이라는 사실을 저장 전에 사용자에게 알리고, HWP3 원본이나 다른 기존 파일을 변환 결과로 덮어쓰지 못하게 하는 구현 경계를 정한다. 구현계획 승인 전에는 Stage 1을 시작하지 않으며, 각 Stage 종료 뒤 `task-stage-report` 절차로 실제 결과와 다음 단계 진입을 다시 승인받는다.

## 2. 구현 전 확인 결과

| 항목 | 확인 결과 | 구현 영향 |
|------|-----------|-----------|
| source identity | `RhwpStudioDocumentPayload.isHWP3Source`가 원본 bytes의 `HWP Document File` magic prefix로 HWP3를 판정한다. | 확장자 대신 이 판정을 저장 정책에 전달한다. |
| 현재 in-place 조건 | `canSaveInPlace`는 `sourceProtection == .plain`과 URL 확장자/출력 형식 일치만 확인한다. | `.hwp`를 공유하는 평문 HWP3와 HWP5가 같은 경로로 처리되어 회귀가 발생한다. |
| 저장 경고 조건 | `DocumentProtectionSaveAlert`는 보호 상태가 평문이 아닐 때만 호출되며, 보호된 HWP3에는 형식 변환 문구를 이미 덧붙인다. | 평문 HWP3용 변환 경고를 추가하되 보호된 HWP3에서 중복 경고를 만들지 않는다. |
| destination 정책 | 평문 `preserveSourceProtection` 요청은 destination 제한 없이 허용된다. 보호 입력의 평문 복사본만 원본 동일 경로 또는 provenance 없는 기존 파일을 거부한다. | HWP3 변환에는 보호 정책과 독립된 `신규 destination` 검증이 필요하다. |
| pending request | revision, source protection, output protection intent와 source URL을 캡처하지만 source format identity는 보존하지 않는다. | save panel·export 대기 중 source identity도 현재 문서와 함께 재검증한다. |
| 저장 성공 상태 | `recordSavedDocument`가 current payload를 export bytes로 교체하고 source URL을 저장 결과로 갱신한다. | HWP3 → HWP5/HWPX 성공 뒤 후속 저장은 출력 bytes 기준으로 정상 전환될 수 있다. 이 동작을 회귀로 고정한다. |
| payload 검증 | 응답 format, byte count, HWP CFB/HWPX ZIP signature와 destination 확장자를 write 전에 검사한다. | 기존 검증을 유지하고 HWP3 변환 destination 정책을 응답 뒤 다시 적용한다. |
| HostAppTests 경계 | `DocumentSaveContract.swift`와 `DocumentSaveFormat.swift`는 테스트 target에 포함되지만 `RhwpStudioWebView.swift`, `RhwpStudioDocumentPayload.swift`는 포함되지 않는다. | 핵심 source-format·destination 정책은 Foundation-only 서비스에 두어 단위 테스트하고 orchestration은 build/smoke로 검증한다. |
| 재현 fixture | pinned upstream checkout에 공개 평문 HWP3 fixture가 있고 #480 Stage 1에서도 HWP3 export가 HWP5 CFB로 변환됨을 확인했다. | Stage 1에서 lock commit과 fixture magic을 다시 확인한 복사본만 사용한다. |

## 3. 공통 설계·안전 원칙

### 3.1 source format과 output format 분리

- source identity는 원본 bytes를 기준으로 `HWP3` 여부를 판정한다.
- output format은 기존 `DocumentSaveFormat.hwp`/`.hwpx`를 유지한다.
- `.hwp` 확장자는 HWP3와 HWP5를 구분하는 근거로 사용하지 않는다.
- HWP3 source에서 `.hwp`를 선택해도 HWP5 출력이므로 `형식 보존`이 아니라 `HWP3 변환`으로 취급한다.
- source identity 판정 실패를 HWP3로 오인해 모든 평문 문서를 제한하지 않는다. 현재 magic prefix로 확정된 HWP3만 변환 정책에 넣고, 보호 상태 판정 불능은 #480의 fail-closed 정책이 계속 담당한다.

### 3.2 보호 정책과 변환 정책 합성

저장 요청은 다음 두 축을 독립적으로 계산한 뒤 하나의 사용자 결정 흐름으로 합성한다.

| source protection | source format | 저장 정책 |
|-------------------|---------------|-----------|
| 평문 | HWP5/HWPX | 기존 same-format in-place 저장 유지 |
| 평문 | HWP3 | in-place 금지, 변환 경고, 신규 destination만 허용 |
| 보호/미지원/불명 | HWP5/HWPX | #480의 보호 해제 경고와 평문 복사본 정책 유지 |
| 보호/미지원/불명 | HWP3 | 보호 해제와 HWP3 변환을 한 경고에 표시하고 신규 destination만 허용 |

경고를 통과하기 전 exporter를 호출하지 않는다. 보호 해제와 형식 변환이 함께 필요한 경우 두 alert를 연속 표시하지 않고, 하나의 확인 문구가 두 변화를 모두 설명해야 한다.

### 3.3 신규 destination과 상태 일관성

- HWP3 변환은 source URL과 동일한 canonical URL을 거부한다.
- source URL 유무와 관계없이 이미 존재하는 destination을 거부한다.
- save panel 반환 뒤, exporter 호출 직전, payload 응답 검증 뒤 write 직전에 같은 정책을 반복 적용한다.
- pending request에는 document revision, source protection과 함께 `sourceWasHWP3` 또는 동등한 typed identity를 캡처한다.
- 현재 revision·protection·source identity 중 하나라도 요청과 다르면 export/write를 중단한다.
- 취소·정책 거부·export 오류·write 오류에서는 원본 bytes, source URL, current payload와 dirty/clean 상태를 변경하지 않는다.
- 성공 뒤에만 current payload를 HWP5/HWPX export bytes로 교체한다. 후속 저장은 새 source identity와 새 URL을 기준으로 동작한다.

### 3.4 파일명 규칙

제안 파일명은 변환 종류를 드러내도록 다음 규칙을 사용한다.

- 평문 HWP3 변환: `원본 (변환 복사본).hwp` 또는 `.hwpx`
- 보호 해제만 필요: 기존 `원본 (평문 복사본).hwp` 또는 `.hwpx`
- 보호 해제와 HWP3 변환이 모두 필요: `원본 (평문 변환 복사본).hwp` 또는 `.hwpx`
- 변환이나 보호 해제가 없는 저장: 기존 정규화 파일명 유지

Stage 1 재현에서 사용자 문구와 destination 정책의 충돌이 발견되면 이름만 임의 변경하지 않고 Stage 1 보고에서 대안을 승인받는다.

## 4. Stage 1 — 평문 HWP3 재현과 변환 계약 확정

### 4.1 목적

현재 `devel`과 v0.1.10 저장 경로에서 평문 HWP3 일반 저장이 HWP5 CFB로 원본을 덮어쓰는 조건을 사용자 원본 없이 재현한다. Stage 2에서 구현할 source identity, 경고, 파일명, 신규 destination과 후속 저장 계약을 소스 변경 전에 확정한다.

### 4.2 작업 범위

1. `rhwp-core.lock`의 release tag와 commit이 `v0.8.4`/`496333b27d21ddb9114ba9ae340bcb895870c9a7`인지 확인한다.
2. exact pinned upstream checkout의 공개 평문 HWP3 fixture를 `build.noindex/task482-stage1-reproduction/` 아래에 복사한다.
   - 우선 후보는 `samples/hwp3-sample.hwp`이며, checkout HEAD와 HWP3 magic을 확인한 뒤 사용한다.
   - 저장소 `samples/` 또는 사용자 문서를 원본으로 직접 수정하지 않는다.
3. 원본 SHA-256과 magic prefix를 기록하고 다음 경로를 확인한다.
   - release app 또는 exact-equivalent HostApp에서 열기
   - `Command+S` 결과의 원본 hash와 signature
   - HWP/HWPX 다른 이름 저장 결과 signature
   - 취소 시 원본 hash 유지
4. 현재 save panel에서 기존 파일을 선택했을 때 overwrite 확인과 HostApp write 시점을 확인한다.
5. 경고 문구와 파일명 네 가지 조합을 표로 확정한다.
   - plain HWP3
   - protected HWP3
   - plain HWP5/HWPX
   - protected HWP5/HWPX
6. Stage 2의 최소 정책 API를 확정한다.
   - source format identity
   - conversion intent
   - in-place eligibility
   - destination validation
   - suggested filename
   - current document validation

### 4.3 예상 산출물

- `mydocs/working/task_m010_482_stage1.md`
- `mydocs/orders/20260818.md` 상태 갱신

Stage 1에서는 production source와 test target을 변경하지 않는다. fixture 복사본, export 결과, hash 로그와 앱 산출물은 `build.noindex/`에만 두고 커밋하지 않는다.

### 4.4 검증

```bash
git -C build.noindex/task472-stage3-upstream-rhwp rev-parse HEAD
shasum -a 256 build.noindex/task482-stage1-reproduction/*.hwp
file build.noindex/task482-stage1-reproduction/*
scripts/verify-rhwp-studio-assets.sh
git diff --check
```

실제 upstream checkout 경로가 달라졌다면 `rhwp-core.lock`의 resolved commit과 일치하는 checkout을 read-only로 다시 준비한다. 경로와 fixture 값은 Stage 보고에 portability를 해치지 않는 범위에서 기록한다.

### 4.5 완료 기준

- 평문 HWP3 일반 저장 전후 hash와 HWP3 → HWP5 signature 변화가 표로 고정된다.
- 취소에서 원본 hash가 유지되는지 확인된다.
- 신규 destination 범위와 기존 파일 거부 시 사용자 문구가 확정된다.
- 보호 해제·형식 변환 조합별 alert와 제안 파일명이 확정된다.
- Stage 2가 upstream 또는 Rust FFI 변경 없이 HostApp 내부 정책으로 가능한지 판정된다.

### 4.6 커밋

`Task #482 Stage 1: 평문 HWP3 저장 회귀와 변환 계약 확정`

## 5. Stage 2 — HWP3 원본 덮어쓰기 차단

### 5.1 목적

HWP3 source identity를 저장 요청에 결합하고, 평문 HWP3의 일반 저장을 변환 경고와 save panel로 전환한다. HWP3 변환 결과는 신규 destination에만 쓰며, 기존 HWP5/HWPX와 #480 보호 문서 정책은 유지한다.

### 5.2 예상 변경 파일

- `Sources/HostApp/Services/DocumentSaveContract.swift`
- `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift`(typed identity가 필요할 때만)
- `Sources/HostApp/Services/DocumentProtectionSaveAlert.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Tests/HostAppTests/DocumentSaveContractTests.swift`
- 필요 시 `project.yml`(신규 Foundation-only 정책 파일을 분리할 때만)
- `mydocs/working/task_m010_482_stage2.md`
- `mydocs/orders/20260818.md`

핵심 정책은 가능하면 이미 HostAppTests target에 포함된 `DocumentSaveContract.swift`에 두어 별도 target 확장을 피한다. 새 파일이 필요하면 `project.yml`만 수정하고 `xcodegen generate`로 project를 재생성한다. `Alhangeul.xcodeproj`를 직접 편집하지 않는다.

### 5.3 구현 항목

1. source bytes에서 HWP3 여부를 판정하는 Foundation-only typed identity 또는 동등한 정책 입력을 정의한다.
2. 보호 intent와 독립된 HWP3 conversion intent를 계산한다.
3. in-place eligibility를 다음 조건의 합성으로 변경한다.
   - source protection이 평문
   - source가 HWP3가 아님
   - source URL 형식과 요청 output format이 일치
4. HWP3 변환용 destination 검증을 추가한다.
   - canonical source URL과 동일한 경로 거부
   - symlink·표준화·대소문자 차이로 같은 파일을 가리키는 경로 거부
   - source URL 유무와 관계없이 기존 파일 경로 거부
   - 존재하지 않는 신규 경로만 허용
5. 보호 상태와 HWP3 변환 상태를 한 alert 결정으로 합성한다.
   - 평문 HWP3에도 변환 경고 표시
   - 보호된 HWP3에는 보호 해제와 변환을 모두 표시
   - HWP5/HWPX 보호 문구는 회귀시키지 않음
6. 조합별 제안 파일명 규칙을 적용한다.
7. `PendingSaveRequest`에 source identity/conversion intent를 캡처하고 다음 시점에 current document 및 destination을 재검증한다.
   - save panel 반환 뒤
   - exporter 호출 직전
   - payload 응답 검증 뒤 write 직전
8. 저장 성공 뒤 current payload가 output bytes로 갱신되어 HWP3 identity가 해제되고 후속 저장이 정상 in-place 조건을 사용하도록 한다.
9. revision/source identity 변경, 취소와 오류 문구를 실제 검사 범위에 맞춘다.
10. 변환 payload는 destination과 같은 디렉터리의 임시 파일에 atomic write한 뒤 `renameatx_np(..., RENAME_EXCL)`로 배타적으로 게시한다. 임시 write·publish 실패에서는 destination을 만들거나 교체하지 않고 임시 파일을 정리한다.

### 5.4 단위 회귀

- HWP3 magic과 비-HWP3 bytes의 source identity 판정
- plain HWP3는 in-place 저장 불가
- plain HWP5/HWPX는 기존 same-format in-place 저장 허용
- HWP3 변환의 원본 동일 URL, 표준화 경로, 대소문자 차이, symlink 경로 거부
- HWP3 변환의 다른 기존 파일 destination 거부
- HWP3 변환의 신규 destination 허용
- 변환 임시 write 실패 뒤 destination과 임시 파일이 남지 않음
- publish 직전 destination이 생겨도 기존 bytes를 보존하고 변환 결과를 게시하지 않음
- protection-only, conversion-only, protection+conversion intent 조합
- 네 조합의 제안 파일명
- document revision·protection·source identity 변경 시 요청 거부
- 기존 plain-copy destination과 payload signature 검증 회귀 없음

WebView orchestration을 HostAppTests target에 무리하게 포함시키지 않는다. 정책 단위 테스트와 HostApp Debug build를 기본으로 하고, orchestration의 export-before-write 순서는 Stage 3 fixture smoke와 소스 검토 표로 보강한다.

### 5.5 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task482-stage2-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task482-stage2-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
git diff --check
```

### 5.6 완료 기준

- 평문 HWP3에서 원본 URL로 향하는 export/write 경로가 구조적으로 차단된다.
- 사용자 확인 전 exporter가 호출되지 않는다.
- 변환 결과는 신규 destination에만 기록된다.
- 취소·정책 거부·export/write 실패에서 원본과 current state가 유지된다.
- 기존 평문 HWP5/HWPX와 보호 문서 평문 복사본 단위 회귀가 통과한다.

### 5.7 커밋

`Task #482 Stage 2: HWP3 원본 덮어쓰기 차단`

## 6. Stage 3 — 변환 회귀 검증과 문서 보정

### 6.1 목적

평문 HWP3의 HWP5/HWPX 변환 저장을 fixture로 검증하고, 기존 저장 경로와 #480 보호 문서 정책의 회귀가 없는지 확인한다. 사용자 문서를 실제 지원 범위와 일치시킨다.

### 6.2 예상 변경 파일

- 필요한 경우 Stage 2에서 발견된 소규모 source/test 보정
- `README.md`
- `docs/updates/v0.1.10.html`
- `mydocs/release/v0.1.10.md`
- `mydocs/working/task_m010_482_stage3.md`
- `mydocs/orders/20260818.md`

Stage 3에서 새로운 구조 변경이나 범위 밖 회귀를 발견하면 같은 단계에 임의 포함하지 않고 별도 이슈 또는 구현계획 보정 승인을 받는다.

### 6.3 fixture 회귀 행렬

| 입력/행위 | 필수 확인 |
|-----------|-----------|
| 평문 HWP3 + `Command+S` | 변환 경고와 save panel 진입, 원본 hash 유지 |
| 평문 HWP3 → HWP5 | 신규 URL, CFB signature, 원본 hash 유지, 저장 성공 뒤 후속 `Command+S` 정상 |
| 평문 HWP3 → HWPX | 신규 URL, ZIP signature, 원본 hash 유지, 저장 성공 뒤 후속 `Command+S` 정상 |
| 경고 취소 | exporter/write 없음, 원본 hash와 dirty 상태 유지 |
| save panel 취소 | exporter/write 없음, 원본 hash와 dirty 상태 유지 |
| 원본 또는 기존 파일 destination | 정책 오류, 양쪽 기존 파일 hash 유지 |
| 평문 HWP5/HWPX | same-format in-place 저장 유지 |
| 보호 HWP3/HWP5/HWPX | #480 보호 해제 경고·평문 복사본 정책 유지, HWP3는 변환 문구 포함 |

### 6.4 문서 보정

- README 저장 설명에 HWP3 원형 재저장을 지원하지 않으며 HWP5/HWPX 변환 복사본만 신규 경로에 저장할 수 있음을 기록한다.
- v0.1.10 업데이트 문서는 이미 공개된 tag에 #480/#482 수정이 포함된 것처럼 기술하지 않고, 배포본의 원본 덮어쓰기 위험과 사본 보관 권고를 명시한다.
- 릴리스 기록에는 v0.1.10의 실제 위험과 다음 릴리스 후보에서 적용하는 #480/#482 수정 동작을 분리해 기록한다.
- 실제 fixture hash나 로컬 절대 경로는 Stage 보고에 필요한 재현 정보만 남기고 사용자 문서에는 기록하지 않는다.

### 6.5 검증

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task482-stage3-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task482-stage3-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/check-no-appkit.sh
scripts/verify-rhwp-studio-assets.sh
scripts/check-extension-registration-hygiene.sh --cleanup-dev-registrations
git diff --check
```

fixture smoke는 `build.noindex/` 아래의 복사본과 Debug app만 사용한다. 앱을 실행했다면 종료 후 개발 등록 cleanup을 수행하고 PlugInKit active provider에 개발 경로가 남지 않았는지 확인한다.

### 6.6 완료 기준

- HWP3 → HWP5/HWPX 변환본 signature와 신규 URL 정책이 실제 app smoke로 확인된다.
- 원본·기존 destination hash 보존과 취소·실패 계약이 확인된다.
- 저장 성공 뒤 후속 `Command+S`가 새 형식 기준으로 동작한다.
- 평문 HWP5/HWPX 및 #480 보호 문서 저장 회귀가 없다.
- 사용자 문서가 HWP3 저장 제한과 실제 변환 UX를 정확히 설명한다.

### 6.7 커밋

`Task #482 Stage 3: HWP3 변환 회귀 검증과 문서 보정`

## 7. 중단 및 분기 기준

1. exact pinned fixture에서 평문 HWP3 일반 저장이 HWP5로 변환되지 않으면 원인과 조건을 재조사하고 Stage 2를 시작하지 않는다.
2. HWP3 identity를 HostApp 원본 bytes에서 안정적으로 유지할 수 없으면 확장자 추정으로 우회하지 않고 typed source contract 보강 범위를 승인받는다.
3. HWP3 변환을 차단하려면 Rust FFI, bundled Studio asset 또는 upstream ref 변경이 필요하다고 판정되면 별도 이슈와 승인을 받는다.
4. 기존 파일 destination을 save panel 전에 판별할 수 없더라도 write 전에 반드시 거부한다. 정책 거부가 write 뒤에 발생하는 구조라면 해당 Stage를 완료 처리하지 않는다.
5. protection-only 저장 회귀가 발견되면 #480 정책을 약화하지 않고 조합 정책을 보정한다.
6. HWP3 변환 뒤 Studio current model과 native payload가 서로 다른 형식 상태를 유지한다면 후속 저장을 허용하지 않고 동기화 계약을 다시 설계한다.
7. 예상 밖 serializer content loss나 저장 실패가 발견되면 이번 overwrite 차단과 분리 가능한지 판단해 후속 이슈를 제안하고, 사용자 안내 없이 범위를 확대하지 않는다.

## 8. 단계별 승인·보고·PR 경계

- 각 Stage 종료 시 `task-stage-report`를 명시 호출해 `mydocs/working/task_m010_482_stage{N}.md`를 작성하고 해당 단계의 source·test·문서와 함께 하나의 Stage 커밋으로 묶는다.
- Stage 보고에는 실제 실행한 명령, fixture provenance, 원본/출력 hash와 signature, 실패·제한, 다음 Stage 진입 조건을 기록한다.
- Stage 1 승인 전 Stage 2 source 변경을 시작하지 않는다.
- Stage 2 승인 전 Stage 3 fixture smoke와 사용자 문서 보정을 시작하지 않는다.
- 세 Stage가 모두 승인된 뒤에만 `task-final-report`를 명시 호출해 `mydocs/report/task_m010_482_report.md`, 오늘할일 완료 처리, 최종 검증, `publish/task482` push와 `devel` 대상 PR을 수행한다.
- PR 본문에는 `Closes #482`를 사용하고 #480은 열린 상태로 유지한다.
- 서명, 공증, GitHub Release, appcast, Homebrew와 public patch release는 이 타스크 범위가 아니다.

## 9. 리뷰 포인트

- HWP3 여부가 파일 확장자가 아니라 원본 bytes에서 결정되는가?
- 평문 HWP3의 `Command+S`가 exporter 호출 전에 save-as 흐름으로 전환되는가?
- 원본 동일 경로뿐 아니라 다른 기존 파일 destination도 write 전에 거부하는가?
- 보호 해제와 형식 변환이 중복 alert 없이 모두 설명되는가?
- 요청 대기 중 revision·protection·source identity 변경을 거부하는가?
- 저장 성공 뒤 current payload가 출력 bytes로 갱신되어 변환 경고가 불필요하게 반복되지 않는가?
- 평문 HWP5/HWPX in-place 저장과 #480 plain-copy 정책이 유지되는가?

## 10. 구현계획 승인 요청

- Stage 1에서 exact plain HWP3 재현과 경고·파일명·신규 destination 계약을 확정한다.
- Stage 2에서 HostApp 내부 source-format 변환 정책과 원본·기존 파일 overwrite 차단을 구현한다.
- Stage 3에서 HWP5/HWPX 변환 smoke, 기존 저장 회귀와 사용자 문서를 완료한다.

위 단계·신규 destination 정책·파일명 조합·중단 기준 승인 후 Stage 1 조사를 시작한다.
