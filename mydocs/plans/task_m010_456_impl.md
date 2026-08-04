# Task #456 구현 계획서

## 작업 개요

- 이슈: #456 `HostApp의 HWP/HWPX 형식별 native 저장 경로 연결`
- 마일스톤: v0.1 (`M010`)
- 작업 브랜치: `local/task456`
- 대상 통합 브랜치: `devel`
- 수행계획서: `mydocs/plans/task_m010_456.md`
- 단계 수: 5

현재 HostApp 저장 경로는 알한글 native `NSSavePanel`과 atomic write를 제공하지만 HWP exporter와 `.hwp` source에 고정돼 있다. bundled `rhwp-studio`는 `exportHwpx`와 `notifySaved` embed RPC를 이미 제공하므로, upstream asset을 수정하지 않고 injected bridge와 HostApp coordinator를 형식 인식형으로 확장한다.

## 구현 원칙

1. 확장자, exporter와 실제 payload format을 하나의 `DocumentSaveFormat` 값에서 파생한다.
2. 명시적 형식별 메뉴가 현재 source format보다 우선하고, 일반 저장/다른 이름 저장은 현재 source format을 보존한다.
3. source format을 결정할 수 없는 새 문서·임시 문서는 기존 정책대로 HWP를 기본값으로 사용한다.
4. destination, pending format, bridge response format과 payload signature가 일치하기 전에는 파일을 쓰지 않는다.
5. 제자리 write 실패 후 fallback panel도 원래 요청 format을 유지한다.
6. 파일 write 성공과 editor clean-state 동기화를 구분한다. durable write 성공은 되돌리지 않고, `notifySaved` 실패는 별도 오류로 표시한다.
7. 기존 share와 Issue #455 전의 PDF export는 이번 작업에서 HWP payload 경로를 유지한다.
8. bundled `rhwp-studio` asset과 `Sources/RhwpCoreBridge`의 소유 경계를 변경하지 않는다.
9. `project.yml`을 Xcode project의 원본으로 사용하며 `Alhangeul.xcodeproj`를 직접 편집하지 않는다.

## 저장 형식 계약

### `DocumentSaveFormat`

HostApp 전용 Foundation 모델을 다음 두 값으로 구성한다.

| 값 | 확장자 | panel 표시 | 기본 파일명 | runtime signature |
|----|--------|------------|-------------|-------------------|
| `hwp` | `.hwp` | `HWP 문서 저장` | `document.hwp` | HWP CFB magic |
| `hwpx` | `.hwpx` | `HWPX 문서 저장` | `document.hwpx` | ZIP magic |

모델은 다음 책임을 가진다.

- raw bridge format(`hwp`, `hwpx`) decode
- URL 또는 filename의 대소문자 비구분 확장자 판정
- 지원 확장자를 선택 format 확장자로 교체하는 filename 정규화
- 빈 이름의 기본 파일명 제공
- HWP CFB/HWPX ZIP signature의 최소 runtime guard

HWPX ZIP 내부의 `mimetype`, `Contents/` 같은 container entry 검증은 UI write hot path에서 ZIP parser를 새로 도입하지 않고 Stage 4 output 검증에서 수행한다. runtime guard는 확장자와 완전히 다른 bytes를 쓰는 명백한 mismatch 방지에 집중한다.

### format 결정 우선순위

| command | format 결정 | destination |
|---------|-------------|-------------|
| `file:save` | 현재 source URL의 HWP/HWPX 확장자 → 현재 filename → 기본 HWP | 지원 source면 제자리, 없거나 write 실패면 같은 format save-as |
| `file:save-as` | 현재 source URL의 HWP/HWPX 확장자 → 현재 filename → 기본 HWP | format-aware save panel |
| `file:save-as-hwp` | 명시적 HWP | HWP save panel |
| `file:save-as-hwpx` | 명시적 HWPX | HWPX save panel |

HWPX로 다른 이름 저장이 성공하면 current source URL과 filename이 `.hwpx`로 바뀐다. 이후 `file:save`는 현재 source에서 HWPX를 다시 결정하므로 같은 URL에 `exportHwpx`를 사용한다.

## bridge message 계약

### native command

`RhwpStudioHostBridgeScript.nativeCommands`와 non-mutating command set에 다음 명령을 추가한다.

- `file:save-as-hwp`
- `file:save-as-hwpx`

capture 단계에서 upstream menu handler보다 먼저 이벤트를 소비하고 기존 native command message로 전달한다. 저장 command 자체를 편집으로 오인해 dirty event를 추가하지 않는다.

### export 요청

기존 HWP 전용 export helper를 저장 format을 받는 helper와 HWP-only compatibility helper로 분리한다.

```text
save hwp  -> requestRhwp("exportHwpBase64") fallback requestRhwp("exportHwp")
save hwpx -> requestRhwp("exportHwpx") -> chunked base64 encode
share/pdf -> 기존 HWP-only helper 유지
```

HWPX는 현재 embed RPC가 `Uint8Array`를 반환하므로 기존 chunked base64 encoder를 재사용한다. 한 번에 전체 bytes를 spread하지 않아 대용량 문서의 call-stack overflow를 방지한다.

### save response

저장 response에 `format`을 명시한다.

```json
{
  "type": "save-document",
  "format": "hwpx",
  "fileName": "example.hwpx",
  "base64": "...",
  "byteCount": 1234
}
```

Swift coordinator는 다음 순서로 검증한다.

1. pending save request 존재
2. response format decode 성공
3. pending format과 response format 일치
4. base64 decode 및 `byteCount` 일치
5. payload signature가 format과 일치
6. destination extension이 format과 일치
7. atomic write

한 항목이라도 실패하면 current source, recent document와 clean state를 갱신하지 않는다.

## 저장 상태 전이

현재 `SaveDestination`과 별도 format을 흩어 두지 않고 `PendingSaveRequest`에 함께 보관한다.

```text
idle
  -> choosingDestination(format)
  -> exporting(destination, format)
  -> validating(format, payload)
  -> writing(destination)
  -> synchronizingEditor(fileName)
  -> idle
```

- panel 취소: pending request를 만들지 않고 completion `.cancelled`
- export/evaluation 실패: pending request와 completion을 한 번만 정리
- response mismatch: write 없이 `.failed`
- source write 실패: 같은 format의 panel로 fallback
- write 성공: current source/recent document 갱신 후 `notifySaved(fileName)` 요청
- `notifySaved` 성공: upstream dirty state와 recovery draft를 정리하고 저장 완료 상태 표시
- `notifySaved` 실패: 저장된 파일과 HostApp source 갱신은 유지하고 동기화 오류를 사용자에게 표시

HostApp `DocumentViewerStore.recordSavedDocument(at:)`의 dirty clear는 유지한다. upstream `notifySaved`도 호출해 browser 내부 unsaved guard와 HostApp 상태가 어긋나지 않게 한다.

## Stage 1. 현재 저장 경계와 format contract 확정

### 목표

코드 변경 전에 command별 format 결정, bridge RPC capability, pending state와 clean-state 책임을 current bundled asset 기준으로 고정한다.

### 작업

- `file:save`, `file:save-as`, `file:save-as-hwp`, `file:save-as-hwpx`의 현재 event routing을 기록한다.
- `exportHwp`, `exportHwpx`, `notifySaved` embed RPC와 response 형태를 확인한다.
- HWP/HWPX source, 새 문서, 명시적 변환 저장의 command matrix를 확정한다.
- `DocumentSaveFormat`, `PendingSaveRequest`와 save response validation 경계를 확정한다.
- HostApp dirty state와 upstream document state를 모두 정리해야 하는 이유를 단계 보고서에 기록한다.
- 구현 파일과 테스트 target 변경 범위를 확정하고 수행계획 대비 차이가 있으면 구현계획서를 보정한다.

### 검증 시나리오

- 현재 HWPX menu가 native command set에 없음을 확인
- 현재 HWP export helper와 HWP-only panel·in-place gate를 확인
- bundled RPC가 `exportHwpx`와 `notifySaved`를 제공함을 확인
- explicit format, source format과 default format의 우선순위에 빈 경우가 없는지 표로 확인

### 완료 기준

- 네 command의 destination·exporter·후속 `Command+S` 동작이 모두 결정된다.
- runtime signature guard와 Stage 4 container 검증의 책임이 구분된다.
- upstream asset 수정 없이 구현 가능한 경로가 확인된다.
- Stage 2가 사용할 파일·테스트 목록이 확정된다.

### 검증

- `rg -n "file:save|file:save-as-hwp|file:save-as-hwpx|exportHwp|exportHwpx|notifySaved|pendingSaveDestination|canSaveInPlace" Sources/HostApp`
- `rg -n -o '.{0,240}(exportHwpx|notifySaved|file:save-as-hwpx).{0,360}' Sources/HostApp/Resources/rhwp-studio/assets/*.js`
- `git diff --check`

### 커밋 메시지

- `Task #456 Stage 1: HWP/HWPX 저장 형식 계약 확정`

## Stage 2. 저장 형식 모델과 native panel 일반화

### 목표

UI와 bridge가 공유할 HWP/HWPX format 판정·filename·signature 규칙을 순수 모델과 단위 테스트로 먼저 고정한다.

### 작업

- `Sources/HostApp/Services/DocumentSaveFormat.swift`에 format enum과 판정·정규화·signature guard를 추가한다.
- `DocumentSavePanel` API가 `format`을 필수 입력으로 받고 title, filename과 allowed content type을 format에서 구성하게 한다.
- 지원 확장자 교체 시 `.hwp.hwpx` 같은 중복 suffix가 생기지 않게 한다.
- `.hwp`, `.hwpx`, 대소문자 확장자, 빈 이름, 점을 포함한 filename과 미지원 확장자 동작을 테스트한다.
- CFB/ZIP positive와 서로 바뀐 negative signature를 테스트한다.
- `project.yml`의 HostAppTests source에 format 모델을 추가하고 `xcodegen generate`로 project를 갱신한다.

### 검증 시나리오

- `sample.hwp` + HWPX → `sample.hwpx`
- `sample.HWPX` + HWP → `sample.hwp`
- `sample.final.hwp` + HWPX → `sample.final.hwpx`
- 빈 이름 + HWP/HWPX → 각 기본 파일명
- HWP format + CFB는 허용, ZIP은 거부
- HWPX format + ZIP은 허용, CFB는 거부
- `.txt` 같은 미지원 source는 command contract의 기본 format과 결합해 결정론적으로 정규화

### 완료 기준

- format 관련 문자열 분기가 panel/coordinator에 중복되지 않는다.
- panel은 요청 format과 다른 확장자를 선택 결과로 만들지 않는다.
- 순수 format 테스트가 통과한다.
- HostApp compile이 통과한다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task456/stage2-tests CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task456/stage2-build CODE_SIGNING_ALLOWED=NO build`
- `./scripts/check-no-appkit.sh`
- `git diff --check`

### 커밋 메시지

- `Task #456 Stage 2: 저장 형식 모델과 native 패널 일반화`

## Stage 3. 형식별 export와 제자리 재저장 연결

### 목표

형식별 메뉴부터 exporter, pending validation, atomic write, source 갱신과 다음 `Command+S`까지 하나의 format으로 연결한다.

### 작업

- injected bridge에 HWP/HWPX save-as native command를 추가하고 upstream menu event를 intercept한다.
- format-aware save export helper와 response `format` field를 추가한다.
- HWP save는 기존 base64 fast path/fallback을 유지하고 HWPX save는 `exportHwpx` RPC를 사용한다.
- `RhwpStudioWebView.Coordinator`의 pending state를 destination+format 요청으로 교체한다.
- 일반 save/save-as format 판정과 명시적 HWP/HWPX save-as handler를 추가한다.
- source `.hwp`와 `.hwpx` 모두 security-scoped in-place write를 허용한다.
- response format, byte count, signature와 destination extension 검증 후에만 write한다.
- source write 실패 시 같은 format의 save-as panel로 fallback한다.
- 저장 성공 후 current source/recent document를 갱신하고 upstream `notifySaved`를 호출한다.
- 기존 share, print와 PDF command routing이 바뀌지 않게 한다.

### 검증 시나리오

- HWP source `Command+S` → HWP exporter + source write
- HWPX source `Command+S` → HWPX exporter + source write
- HWP source `HWPX 형식으로 저장` → HWPX panel/export/write → 다음 `Command+S` HWPX
- HWPX source `HWP 형식으로 저장` → HWP panel/export/write → 다음 `Command+S` HWP
- generic save-as는 현재 source format 유지
- export response format mismatch, bad signature, byte count mismatch → write 0건
- write failure → 같은 format panel fallback
- save 취소·중복 command → pending state 누수 없음
- save 성공 → HostApp/upstream dirty state clean 및 filename 갱신

### 완료 기준

- format별 command와 exporter가 정확히 매핑된다.
- HWPX로 저장한 직후 `Command+S`가 `exportHwpx`를 유지한다.
- extension과 payload가 다른 파일을 native path가 쓰지 않는다.
- 기존 HWP save/share/print/PDF 경로가 회귀하지 않는다.

### 검증

- Stage 2 format tests와 추가 coordinator/contract tests
- `rg -n "file:save-as-hwp|file:save-as-hwpx|exportHwpx|notifySaved|PendingSaveRequest|DocumentSaveFormat" Sources Tests project.yml`
- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task456/stage3-tests CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task456/stage3-build CODE_SIGNING_ALLOWED=NO build`
- `scripts/verify-rhwp-studio-assets.sh build.noindex/task456/stage3-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
- `./scripts/check-no-appkit.sh`
- `git diff --check`

### 커밋 메시지

- `Task #456 Stage 3: HWP/HWPX native 저장 경로 연결`

## Stage 4. HWP/HWPX 저장·재열기 통합 검증

### 목표

실제 WKWebView와 `NSSavePanel` 경로에서 HWP/HWPX format 보존, 변환 저장과 후속 `Command+S`를 검증한다.

### 작업

- clean derived data에서 전체 HostAppTests와 HostApp Debug build를 실행한다.
- HWP와 HWPX 대표 샘플을 원본과 분리된 임시 경로로 복사해 저장 smoke를 수행한다.
- 각 source에서 동일 format 저장과 반대 format 저장을 수행한다.
- HWPX로 저장한 직후 추가 편집과 `Command+S`를 수행해 같은 HWPX가 갱신되는지 확인한다.
- output의 확장자, CFB/ZIP magic, HWPX container entry, 파일 크기와 수정 시각을 확인한다.
- 저장 output을 알한글과 core smoke helper로 다시 열어 page count, 대표 텍스트·표·이미지와 non-blank render를 확인한다.
- 취소, 읽기 전용 source 또는 write 실패 fallback과 중복 요청 방어를 확인한다.
- 저장 후 종료/다른 문서 열기에서 unsaved guard가 다시 나타나지 않는지 확인한다.

### 검증 시나리오

- HWP → HWP, HWP → HWPX, HWPX → HWPX, HWPX → HWP 네 조합
- HWPX save-as → 추가 편집 → `Command+S` → 동일 URL HWPX 갱신
- panel 취소, source write 실패와 동일 format fallback
- 저장 결과 재열기와 page count·대표 내용·non-blank render 확인
- 저장 직후 종료/문서 전환에서 중복 unsaved guard 없음

### 완료 기준

- HWP/HWPX 동일 format 저장과 상호 변환 저장 output이 기대 signature/container를 가진다.
- HWPX save 후 `Command+S`가 panel 없이 같은 HWPX를 갱신한다.
- 모든 output이 재열리고 대표 내용과 페이지 수가 유지된다.
- 원본 fixture는 변경되지 않는다.
- 전체 tests, build와 asset 검증이 통과한다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task456/stage4-tests CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task456/stage4-build CODE_SIGNING_ALLOWED=NO build`
- `scripts/verify-rhwp-studio-assets.sh build.noindex/task456/stage4-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
- HWP `xxd`/`file` signature 검사
- HWPX `unzip -t`, `unzip -l` container 검사
- 저장 output 재열기 및 대표 page render smoke
- `git diff --check`

### 커밋 메시지

- `Task #456 Stage 4: HWP/HWPX 저장과 재열기 검증`

## Stage 5. 저장 정책 문서와 잔여 호환 제한 정리

### 목표

구현된 저장 ownership, format 우선순위, runtime guard와 upstream exporter 한계를 architecture 문서와 최종 인계 자료에 반영한다.

### 작업

- `mydocs/tech/project_architecture.md`의 HWP-only 저장 설명을 format-aware native 저장 구조로 갱신한다.
- 일반 저장/다른 이름 저장과 형식별 저장 command matrix를 문서화한다.
- HWPX `Command+S`, `notifySaved`, signature/runtime guard와 container smoke의 책임을 기록한다.
- HWPX exporter의 완전 무손실을 보장하지 않는 범위와 확인한 대표 fixture 결과를 기록한다.
- Stage 1~4 결과와 잔여 위험을 단계 보고서에 정리한다.
- 최종 보고서에서 재실행 가능한 검증 명령과 output 요약을 준비한다.

### 검증 시나리오

- architecture의 command matrix와 구현 분기가 일치
- runtime signature guard와 수동 container 검증 책임이 혼동 없이 구분
- HWPX 지원 범위와 완전 무손실 비보장 문구가 함께 기록
- Stage별 명령·결과·잔여 위험이 최종 보고서 입력으로 추적 가능

### 완료 기준

- architecture 문서가 실제 command/exporter/state 경로와 일치한다.
- 지원되는 format 동작과 upstream 호환 제한이 구분된다.
- 전체 diff와 테스트 결과가 최종 보고서 작성 단계에 인계 가능한 상태다.
- 작업 트리에 미보고 source 변경이 없다.

### 검증

- `rg -n "파일 > 저장|HWPX|exportHwpx|Command\\+S|notifySaved" mydocs/tech/project_architecture.md mydocs/working/task_m010_456_stage*.md`
- `git diff --check`
- Stage 4 전체 검증 결과 재확인

### 커밋 메시지

- `Task #456 Stage 5: HWP/HWPX 저장 정책과 호환 제한 정리`

## 단계 승인 게이트

- Stage 1 완료 후 저장 command matrix, RPC capability와 format/state contract를 보고하고 Stage 2 승인을 요청한다.
- Stage 2 완료 후 format 모델·panel·단위 테스트 결과를 보고하고 Stage 3 승인을 요청한다.
- Stage 3 완료 후 bridge/coordinator/in-place save 연결과 회귀 결과를 보고하고 Stage 4 승인을 요청한다.
- Stage 4 완료 후 실제 HWP/HWPX 저장·재열기 output과 실패 경로 결과를 보고하고 Stage 5 승인을 요청한다.
- Stage 5 완료 후 문서·잔여 위험을 보고하고 최종 결과보고서 및 PR 게시 단계 승인을 별도로 요청한다.

## 승인 요청 사항

이 구현계획서의 저장 format 계약과 5단계 구성을 기준으로 Stage 1을 진행해도 되는지 승인을 요청한다. 승인 전에는 HostApp 제품 코드, 테스트 target과 architecture 문서를 변경하지 않는다.
