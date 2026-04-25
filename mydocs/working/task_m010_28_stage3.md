# Issue #28 Stage 3 완료 보고서

## 단계 목적

`scripts/validate-stage3-render.sh`의 기본 render smoke 샘플 경로를 `Vendor/rhwp/samples`에서 앱 저장소 루트 `samples/`로 변경한다.

## 변경 내용

- `RHWP_ROOT="$ROOT/Vendor/rhwp"` 변수를 제거했다.
- 인자 없이 실행할 때 사용하는 기본 샘플 경로를 다음으로 변경했다.
  - `samples/basic/KTX.hwp`
  - `samples/basic/request.hwp`
  - `samples/exam_kor.hwp`
- 출력 디렉터리와 사용자 지정 샘플 인자 구조는 유지했다.

## 변경 후 기본 동작

```bash
./scripts/validate-stage3-render.sh
```

위 명령은 다음 파일을 기본 입력으로 사용한다.

```text
samples/basic/KTX.hwp
samples/basic/request.hwp
samples/exam_kor.hwp
```

## 실행한 검증

```bash
bash -n scripts/validate-stage3-render.sh
rg -n "RHWP_ROOT|Vendor/rhwp/samples|samples/basic/KTX|samples/basic/request|samples/exam_kor" scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh output/task28-stage3-render
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455 png=/Users/melee/Documents/projects/rhwp-mac/output/task28-stage3-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724 png=/Users/melee/Documents/projects/rhwp-mac/output/task28-stage3-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464 png=/Users/melee/Documents/projects/rhwp-mac/output/task28-stage3-render/exam_kor-page1.png
```

## 생성된 로컬 산출물

다음 경로는 `.gitignore` 대상이며 커밋하지 않는다.

- `output/task28-stage3-render/`

## 완료 판단

render smoke script의 기본 경로가 `samples/` 기준으로 변경되었고, 새 기본 샘플 경로로 실제 렌더 검증이 통과했다.

## 승인 요청

이 Stage 3 완료 보고서 기준으로 Stage 4 진행 승인을 요청한다.
