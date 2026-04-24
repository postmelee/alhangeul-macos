# Issue #22 단계 7 완료 보고서

## 작업 내용

- 최종 보고 전 필요한 검증 항목을 다시 실행해 결과를 정리했다.
- stage 6까지 반영된 문서와 코드 변경이 현재 워크스페이스 기준으로 정합한지 확인했다.
- 최종 보고서에 넣을 검증 결과와 주의사항을 정리했다.

## 검증 결과

### 1. render smoke test

실행 명령:

- `./scripts/validate-stage3-render.sh output/stage3-render-20260424`

결과:

- `KTX.hwp`
  - `page=1`
  - `size=1123x794`
  - `textRuns=435`
  - `hangulRuns=76`
  - `hangulScalars=209`
  - `nonWhitePixels=450455`
- `request.hwp`
  - `page=1`
  - `size=567x794`
  - `textRuns=104`
  - `hangulRuns=36`
  - `hangulScalars=309`
  - `nonWhitePixels=54724`
- `exam_kor.hwp`
  - `page=1`
  - `size=1123x1588`
  - `textRuns=69`
  - `hangulRuns=51`
  - `hangulScalars=940`
  - `nonWhitePixels=96464`

출력 PNG는 아래 경로에 생성됐다.

- `output/stage3-render-20260424/KTX-page1.png`
- `output/stage3-render-20260424/request-page1.png`
- `output/stage3-render-20260424/exam_kor-page1.png`

### 2. Shared Swift bridge 경계 검사

실행 명령:

- `./scripts/check-no-appkit.sh`

결과:

- `OK: shared Swift code has no AppKit/UIKit dependencies`

즉, `Sources/RhwpCoreBridge`가 여전히 AppKit/UIKit 직접 의존 없이 유지되고 있음을 확인했다.

### 3. 문서/패치 형식 검사

실행 명령:

- `git diff --check`

결과:

- 형식 오류 없음

## 검증 중 확인한 주의사항

초기에 기본 출력 경로로 `./scripts/validate-stage3-render.sh`를 실행했을 때, 과거 다른 작업 디렉터리 경로를 포함한 Swift/Clang module cache 때문에 아래 오류가 발생했다.

- `SwiftShims` precompiled module cache path mismatch
- `missing required module 'SwiftShims'`

이 문제는 현재 코드 문제가 아니라 이전 출력 디렉터리 `output/stage3-render` 재사용으로 생긴 환경성 이슈였다.

이번 단계에서는 새 출력 경로 `output/stage3-render-20260424`를 사용해 같은 smoke test를 재실행했고, 정상 통과를 확인했다.

따라서 최종 보고에는 다음 해석을 함께 남겨야 한다.

1. 렌더 smoke test 자체는 통과했다.
2. 기본 출력 디렉터리를 계속 재사용할 경우 로컬 환경에 따라 module cache path mismatch가 재발할 수 있다.
3. 이 문제는 제품 기능 회귀와는 별개로, 검증 산출물 캐시 재사용 정책 차원의 주의사항이다.

## 판단

이 단계 기준으로 확인된 내용은 다음과 같다.

1. Rust bridge + Swift render 경로는 샘플 문서 3종에서 여전히 정상 동작한다.
2. `RhwpCoreBridge` 계층은 AppKit/UIKit 직접 의존 없이 유지된다.
3. 문서와 코드 패치 형식에도 현재 깨진 부분이 없다.
4. stage 1부터 stage 6까지의 변경은 최종 보고 단계로 넘어갈 수 있는 상태다.

## 다음 단계

- `mydocs/report/task_m050_22_report.md` 최종 결과 보고서 작성
- 필요 시 검증 주의사항으로 `validate-stage3-render` 캐시 재사용 문제를 함께 기록

## 승인 요청 사항

- 이 단계 완료 기준으로 최종 결과 보고서 작성 진행 승인 요청
