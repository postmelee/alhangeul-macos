# Issue #28 Stage 4 완료 보고서

## 단계 목적

README와 운영 manual의 기본 render/Quick Look/Thumbnail smoke test 샘플 경로를 앱 저장소 루트 `samples/` 기준으로 갱신한다.

## 변경 내용

### README

- render smoke 기본 샘플 경로를 `samples/` 기준으로 변경했다.
  - `samples/basic/KTX.hwp`
  - `samples/basic/request.hwp`
  - `samples/exam_kor.hwp`
- 기본 render smoke fixture는 앱 저장소 루트 `samples/`가 소유한다고 명시했다.

### build/run guide

- render smoke 기본 샘플 경로를 `samples/` 기준으로 변경했다.
- Quick Look preview 예시를 `samples/basic/KTX.hwp`로 변경했다.
- thumbnail smoke 예시를 `samples/basic/KTX.hwp`로 변경했다.

### release/distribution guide

- Finder 통합 smoke test의 `qlmanage -t` 예시를 `samples/basic/KTX.hwp`로 변경했다.
- 실제 사용자 파일 검증 시에는 해당 `.hwp`/`.hwpx` 경로를 명시하도록 보강했다.

### core submodule operation guide

- core submodule 갱신 후에도 render smoke 기본 경로가 submodule 내부 샘플 디렉터리에 의존하지 않아야 한다는 운영 기준을 추가했다.

## 실행한 검증

```bash
rg -n "Vendor/rhwp/samples|Vendor/rhwp/samples/basic|Vendor/rhwp/samples/exam_kor" README.md scripts mydocs/manual
rg -n "samples/basic/KTX|samples/basic/request|samples/exam_kor|samples/" README.md mydocs/manual/build_run_guide.md mydocs/manual/release_distribution_guide.md mydocs/manual/core_submodule_operation_guide.md
git diff --check
```

결과:

- 운영 문서와 script에서 기본 검증 경로로 쓰이던 submodule 샘플 경로 제거
- `samples/` 기준 경로 반영 확인
- diff whitespace 검사 통과

## 참고 사항

README에는 Stage 4 이전부터 존재한 미커밋 변경이 있었으므로, 이번 커밋에는 #28 샘플 경로 변경 hunk만 선별해 포함했다.

## 완료 판단

현재 운영 문서와 render smoke script의 기본 샘플 경로가 앱 저장소 루트 `samples/` 기준으로 정렬되었다.

## 승인 요청

이 Stage 4 완료 보고서 기준으로 Stage 5 전체 검증과 최종 보고서 작성을 진행할지 승인 요청한다.
