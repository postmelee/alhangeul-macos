# Issue #28 Stage 2 완료 보고서

## 단계 목적

루트 `samples/`를 앱 저장소가 소유하는 fixture 경로로 Git 추적 대상에 편입한다.

## 변경 내용

- `samples/` 하위 샘플 파일을 Git 추적 대상으로 추가했다.
- 기존 `.gitignore`의 `.DS_Store` 규칙에 따라 `samples/.DS_Store`는 제외했다.
- 대표 render smoke 샘플 3개가 현재 경로에 존재함을 확인했다.

## 편입 결과

- `samples/` 전체 파일 수: 180개
- Git 추적 대상 샘플 파일 수: 179개
- 제외 파일: `samples/.DS_Store`
- 전체 크기: 약 60MB

대표 render smoke 샘플:

| 경로 | 상태 |
|------|------|
| `samples/basic/KTX.hwp` | 존재 |
| `samples/basic/request.hwp` | 존재 |
| `samples/exam_kor.hwp` | 존재 |

## 실행한 검증

```bash
git check-ignore -v samples/.DS_Store
test -f samples/basic/KTX.hwp
test -f samples/basic/request.hwp
test -f samples/exam_kor.hwp
git diff --cached --name-only -- samples | wc -l
git diff --cached --name-only -- samples | rg "\\.DS_Store" || true
du -sh samples
find samples -type f | wc -l
find samples -type f ! -name .DS_Store | wc -l
```

결과:

- `samples/.DS_Store`는 `.gitignore:1:.DS_Store` 규칙으로 제외됨
- 대표 3개 샘플 존재 확인 통과
- staged sample 파일 수는 179개
- staged 파일 목록에 `.DS_Store` 없음

## 참고 사항

작업 중 `samples/`가 자동 stash의 untracked 영역으로 이동된 상태를 확인했고, `stash@{0}^3`에서 `samples/`만 복원했다. `README.md`의 기존 미커밋 변경은 이번 Stage 2 범위에 포함하지 않았다.

## 완료 판단

`samples/` fixture 편입 조건을 충족했다. 다음 단계에서는 `scripts/validate-stage3-render.sh`의 기본 샘플 경로를 `Vendor/rhwp/samples`에서 `samples/`로 변경한다.

## 승인 요청

이 Stage 2 완료 보고서 기준으로 Stage 3 진행 승인을 요청한다.
