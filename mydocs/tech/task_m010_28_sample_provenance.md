# Issue #28 샘플 provenance 기록

## 목적

`Vendor/rhwp` submodule 제거 또는 RustBridge git dependency 전환에 앞서, 앱 저장소가 직접 소유할 render smoke fixture의 출처와 사용 목적을 기록한다.

## 현재 샘플 경로

- 앱 저장소 fixture 경로: `samples/`
- 현재 상태: Git 기준 untracked
- 파일 수: 180개
- 전체 크기: 약 60MB
- 제외 대상: `samples/.DS_Store`

`samples/.DS_Store`는 기존 `.gitignore`의 `.DS_Store` 규칙으로 제외한다.

## 원본 경로

- 원본 저장소: `edwardkim/rhwp`
- 원본 저장소 URL: `https://github.com/edwardkim/rhwp.git`
- 원본 submodule commit: `1e9d78a1d40c71779d81c6ec6870cd301d912626`
- 원본 license: MIT License

대표 3개 샘플의 `edwardkim/rhwp` 내 변경 이력:

```text
91d9374 Task #142: 수식 레이아웃 보정 — OVER 파서 재설계 및 TAC 너비/폭 추정 개선
f0f7f1a Initial commit: rhwp v0.5.0
```

## 대표 render smoke 샘플

| 사용 목적 | 현재 경로 | 원본 경로 | sha256 | size |
|-----------|-----------|-----------|--------|------|
| 2단/도형/한글 텍스트 렌더 smoke | `samples/basic/KTX.hwp` | `Vendor/rhwp/samples/basic/KTX.hwp` | `6c1a027d67b33c03f469b56548b4c7d6bca36b1c1190c7cc5eac88e35c403cf1` | `66048` |
| 일반 문서/이미지/한글 텍스트 렌더 smoke | `samples/basic/request.hwp` | `Vendor/rhwp/samples/basic/request.hwp` | `99e63b90f4aa3197029299ab087bc46225b3c27c0d07d424145b20879b45f12e` | `65536` |
| 긴 한글 시험지 문서 렌더 smoke | `samples/exam_kor.hwp` | `Vendor/rhwp/samples/exam_kor.hwp` | `0315576fb25dd29ad3b6b188ee2539d0e8d31c15b74847be801c2186a97aac69` | `10418688` |

## 동일성 확인

`samples/`의 대표 3개 파일은 `Vendor/rhwp/samples`의 대응 파일과 sha256이 동일하며, `cmp -s` 결과도 모두 `0`이다.

검증 명령:

```bash
shasum -a 256 samples/basic/KTX.hwp Vendor/rhwp/samples/basic/KTX.hwp samples/basic/request.hwp Vendor/rhwp/samples/basic/request.hwp samples/exam_kor.hwp Vendor/rhwp/samples/exam_kor.hwp
cmp -s samples/basic/KTX.hwp Vendor/rhwp/samples/basic/KTX.hwp
cmp -s samples/basic/request.hwp Vendor/rhwp/samples/basic/request.hwp
cmp -s samples/exam_kor.hwp Vendor/rhwp/samples/exam_kor.hwp
```

## 라이선스/재배포 판단

`Vendor/rhwp` 저장소는 MIT License를 포함한다. MIT License는 Software와 관련 documentation files의 사용, 복사, 수정, 병합, 게시, 배포, sublicense, 판매를 허용하며, copyright notice와 permission notice 포함을 조건으로 한다.

이번 작업에서는 `samples/`를 별도 제품 리소스가 아니라 개발/검증 fixture로 취급한다. 개별 HWP 샘플 파일의 외부 원출처가 저장소 내 별도 문서로 명확히 분리되어 있지는 않으므로, 다음 제한을 기록한다.

- 이 fixture는 앱 저장소의 render/Quick Look/Thumbnail smoke test를 위한 개발 검증 자료다.
- 사용자 배포 app bundle에 포함하지 않는다.
- 후속 작업에서 샘플별 외부 원출처가 확인되면 이 문서를 갱신한다.

## 적용 방침

- `scripts/validate-stage3-render.sh`의 기본 샘플 경로는 `samples/` 기준으로 변경한다.
- README와 manual의 기본 render smoke 경로는 `Vendor/rhwp/samples`가 아니라 `samples/`를 사용한다.
- 과거 완료 보고서의 역사적 `Vendor/rhwp/samples` 기록은 수정하지 않는다.
