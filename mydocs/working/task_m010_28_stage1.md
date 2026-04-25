# Issue #28 Stage 1 완료 보고서

## 단계 목적

루트 `samples/`의 상태와 대표 render smoke 샘플의 provenance를 확인해, 이후 단계에서 앱 저장소 소유 fixture로 채택할 수 있는 근거를 마련한다.

## 확인 결과

### `samples/` 상태

- 경로: `samples/`
- Git 상태: untracked
- 파일 수: 180개
- 전체 크기: 약 60MB
- 로컬 메타데이터: `samples/.DS_Store`

`samples/.DS_Store`는 기존 `.gitignore`의 `.DS_Store` 규칙으로 제외된다.

### 원본 submodule 상태

- 원본 경로: `Vendor/rhwp/samples`
- 원본 저장소: `https://github.com/postmelee/rhwp.git`
- 원본 submodule commit: `1e9d78a1d40c71779d81c6ec6870cd301d912626`
- license: MIT License

대표 3개 샘플의 원본 변경 이력:

```text
91d9374 Task #142: 수식 레이아웃 보정 — OVER 파서 재설계 및 TAC 너비/폭 추정 개선
f0f7f1a Initial commit: rhwp v0.5.0
```

### 대표 3개 샘플 동일성

| 현재 경로 | 원본 경로 | sha256 | size | cmp |
|-----------|-----------|--------|------|-----|
| `samples/basic/KTX.hwp` | `Vendor/rhwp/samples/basic/KTX.hwp` | `6c1a027d67b33c03f469b56548b4c7d6bca36b1c1190c7cc5eac88e35c403cf1` | `66048` | 동일 |
| `samples/basic/request.hwp` | `Vendor/rhwp/samples/basic/request.hwp` | `99e63b90f4aa3197029299ab087bc46225b3c27c0d07d424145b20879b45f12e` | `65536` | 동일 |
| `samples/exam_kor.hwp` | `Vendor/rhwp/samples/exam_kor.hwp` | `0315576fb25dd29ad3b6b188ee2539d0e8d31c15b74847be801c2186a97aac69` | `10418688` | 동일 |

## 작성 문서

- `mydocs/tech/task_m010_28_sample_provenance.md`

## 실행한 검증

```bash
git -C Vendor/rhwp rev-parse HEAD
git -C Vendor/rhwp log --oneline -- samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
du -sh samples
find samples -type f | wc -l
find samples -name .DS_Store -print
shasum -a 256 samples/basic/KTX.hwp Vendor/rhwp/samples/basic/KTX.hwp samples/basic/request.hwp Vendor/rhwp/samples/basic/request.hwp samples/exam_kor.hwp Vendor/rhwp/samples/exam_kor.hwp
cmp -s samples/basic/KTX.hwp Vendor/rhwp/samples/basic/KTX.hwp
cmp -s samples/basic/request.hwp Vendor/rhwp/samples/basic/request.hwp
cmp -s samples/exam_kor.hwp Vendor/rhwp/samples/exam_kor.hwp
```

결과:

- 대표 3개 샘플의 sha256 일치
- 대표 3개 샘플의 `cmp -s` 결과 모두 `0`
- provenance 문서 작성 완료

## 판단

루트 `samples/`는 `Vendor/rhwp/samples` 복사본으로 확인되었고, #28 대표 render smoke 샘플 3개는 원본과 byte-for-byte 동일하다. 다음 단계에서는 `samples/`를 Git 추적 대상으로 편입하고 `.DS_Store`는 제외한다.

## 승인 요청

이 Stage 1 완료 보고서 기준으로 Stage 2 진행 승인을 요청한다.
