# Task #371 구현 계획서

본 문서는 [`task_m040_371.md`](task_m040_371.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- Worktree: `/private/tmp/rhwp-mac-task371`
- Branch: `local/task371`
- 기준 브랜치: `devel`
- 기준 이슈: [#371](https://github.com/postmelee/alhangeul-macos/issues/371)
- 마일스톤: M040 (`v0.4`)
- 범위: HostApp 문서 열기 사전 검증과 bundled `rhwp-studio` URL byte guard에서 HWP 3.0 문서를 허용

## 구현 원칙

- HWP 3.0 허용은 core가 이미 처리 가능한 문서를 HostApp이 사전에 차단하지 않도록 하는 최소 변경으로 제한한다.
- 기존 HWP5 CFB magic, HWPX ZIP magic 허용 경로는 유지한다.
- 비지원 파일, HTML 오류 응답, 손상 파일을 지원 문서로 오인하지 않도록 HWP 3.0 signature는 명시적인 prefix 기반으로만 허용한다.
- 오류 문구, fallback UX, WebView 보존/재시도 모달은 이번 task에서 바꾸지 않는다. 해당 UX 변경은 #372 범위로 남긴다.
- `rhwp` core, Quick Look, Thumbnail extension은 수정하지 않는다.
- bundled Studio asset을 직접 수정하는 경우 minified asset 변경 위험과 향후 upstream 갱신 시 확인 필요성을 단계 보고서에 기록한다.

## Stage 1 — Swift 입력 검증에서 HWP 3.0 허용

### 목표

- HostApp 파일 열기 초기에 호출되는 `HwpDocumentInputValidator`가 HWP 3.0 signature를 지원 문서로 인정하도록 한다.
- 기존 HWP5/HWPX 판정과 빈 문서/미지원 문서 오류 동작은 유지한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/Shared/HwpDocumentInputValidator.swift` | `HWP Document File V3.` prefix 판정 추가 | 핵심 Swift 변경 |
| `mydocs/working/task_m040_371_stage1.md` | Stage 1 완료보고서 작성 | 변경 내용, 검증 결과, 잔여 Studio 차단 위험 기록 |

### 구현 기준

1. HWP 3.0 signature는 제보 샘플 헤더 `HWP Document File V3.00`에서 확인한 `HWP Document File V3.` prefix를 기준으로 판정한다.
2. Swift 구현은 ASCII byte 배열 또는 `Data`로 signature를 명시해 인코딩 의존성을 줄인다.
3. `isSupportedDocumentSignature(_:)`는 HWP5 CFB, HWP 3.x prefix, HWPX ZIP 중 하나를 만족할 때만 `true`를 반환한다.
4. `validateOpeningData(_:)`의 빈 문서 오류와 `unsupportedOrCorrupt` 오류 문구는 변경하지 않는다.
5. `HwpDocumentFallbackClassifier`와 Quick Look/Thumbnail fallback 메시지는 변경하지 않는다.

### 단계 검증

```bash
git diff --check
rg -n "HWP Document File V3|hwp3|isSupportedDocumentSignature|hwpMagic|hwpxMagics" Sources/Shared/HwpDocumentInputValidator.swift
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

### 단계 완료 기준

- Swift validator가 HWP 3.0 prefix를 지원 문서로 허용한다.
- HWP5/HWPX 기존 판정 코드가 유지된다.
- 빈 파일과 비지원 파일에 대한 오류 정책이 변경되지 않았다.
- HostApp Debug build가 통과한다.

### 커밋 메시지

```text
Task #371 Stage 1: HWP 3.0 Swift 입력 검증 허용
```

## Stage 2 — bundled Studio URL byte guard에서 HWP 3.0 허용

### 목표

- HostApp이 `alhangeul-document://` URL을 `rhwp-studio`에 넘긴 뒤에도 Studio의 원격 문서 byte guard가 HWP 3.0 문서를 차단하지 않도록 한다.
- HTML 오류 응답과 알 수 없는 byte stream 거부 경로는 유지한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js` | minified bundle의 문서 byte kind 판정에 HWP 3.0 prefix 추가 | bundled Studio asset 변경 |
| `mydocs/working/task_m040_371_stage2.md` | Stage 2 완료보고서 작성 | asset 직접 수정 사유와 검증 결과 기록 |

### 구현 기준

1. 현재 bundle의 HWP5 magic 배열 `Df`, HWPX magic 배열 `Of`, prefix helper `kf`, 문서 종류 판정 함수 `Af` 흐름을 유지한다.
2. HWP 3.0 prefix byte 배열을 추가하고, `Af`가 HWP5 CFB 또는 HWP 3.x prefix를 만나면 동일하게 `hwp`로 반환하도록 한다.
3. HWPX ZIP 판정, HTML content-type/본문 판정, `unknown` fallback은 기존 순서를 유지한다.
4. 로컬 file input/drag extension gate, 이미지 drop, error toast, modal UX는 변경하지 않는다.
5. 가능한 경우 변경 위치가 minified asset임을 stage 보고서에 명시하고, upstream Studio source 갱신 시 같은 guard 반영이 필요하다는 잔여 리스크를 남긴다.

### 단계 검증

```bash
git diff --check
node --check Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js
rg -n "HWP Document File V3|72,87,80,32|Df=|Of=|function Af|function jf" Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

### 단계 완료 기준

- Studio URL byte guard가 HWP 3.0 prefix를 `hwp`로 분류한다.
- HTML 오류 응답과 unknown byte stream은 여전히 `jf`에서 오류로 거부된다.
- bundled asset이 JavaScript syntax check를 통과한다.
- HostApp Debug build가 통과한다.

### 커밋 메시지

```text
Task #371 Stage 2: Studio URL guard에서 HWP 3.0 허용
```

## Stage 3 — 통합 검증과 최종 보고

### 목표

- Swift validator와 bundled Studio guard 변경이 함께 작동하는지 확인한다.
- 제보 샘플, 기존 HWP/HWPX, 미지원 파일 경로의 기대 동작을 보고서에 정리한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `Sources/Shared/HwpDocumentInputValidator.swift` | 필요 시 Stage 1 피드백 반영 | 최종 보정 |
| `Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js` | 필요 시 Stage 2 피드백 반영 | 최종 보정 |
| `mydocs/report/task_m040_371_report.md` | 최종 결과보고서 작성 | 모든 단계 완료 후 |
| `mydocs/orders/20260624.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 최종 검증

```bash
git status --short --branch
git diff --check
node --check Sources/HostApp/Resources/rhwp-studio/assets/index-2nxfiXnQ.js
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
test "$(find build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/assets -maxdepth 1 -name 'rhwp_bg-*.wasm' -type f | wc -l | tr -d ' ')" = "1"
./scripts/render-debug-compare.sh /private/tmp/alhangeul-hwp3-sample16-task371 --page 1 /Users/melee/Documents/projects/forks/rhwp/samples/hwp3-sample16.hwp
```

### 수동 확인 후보

- Debug `Alhangeul.app`에서 `/Users/melee/Documents/projects/forks/rhwp/samples/hwp3-sample16.hwp`를 열었을 때 기존 미지원 오류 화면이 아니라 문서가 로드되는지 확인
- 기존 HWP5 샘플과 HWPX 샘플이 계속 열리는지 확인
- PDF 또는 임의 텍스트 파일을 열었을 때 지원 문서로 오인하지 않고 기존 오류 경로로 남는지 확인
- 오류 화면 복구 UX는 #372에서 처리하므로 이번 task 결과에 포함하지 않음

### 커밋 메시지

```text
Task #371 Stage 3 + 최종 보고서: HWP 3.0 HostApp 열기 검증 보강 완료
```

## 승인 요청 사항

이 구현 계획 기준으로 Stage 1 진행 승인을 요청한다. 승인 전에는 `HwpDocumentInputValidator` 코드 변경을 시작하지 않는다.
