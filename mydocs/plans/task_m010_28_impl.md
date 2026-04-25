# Issue #28 구현 계획서

## 작업명

hwpql 장점 반영 1: 렌더 검증 샘플을 앱 저장소 소유로 독립화

## 구현 원칙

- 작업지시자가 이미 추가한 루트 `samples/`를 공식 fixture 경로로 채택한다.
- `Vendor/rhwp/samples`를 새로 복사하지 않는다.
- `.DS_Store` 같은 로컬 메타데이터는 커밋하지 않는다.
- 과거 완료 보고서의 역사적 경로 기록은 수정하지 않는다.
- 현재 운영 문서와 검증 스크립트의 기본 경로만 변경한다.

## Stage 1: 샘플 상태와 provenance 확정

작업:

- `samples/` 파일 수와 전체 크기를 기록한다.
- 대표 3개 샘플이 `Vendor/rhwp/samples` 원본과 동일한지 sha256/cmp로 확인한다.
- `Vendor/rhwp` license와 샘플 파일 commit provenance를 조사한다.
- `mydocs/tech/task_m010_28_sample_provenance.md`를 작성한다.

완료 조건:

- provenance 문서에 원본 경로, 현재 경로, sha256, 사용 목적, 재배포 판단을 기록한다.
- Stage 1 완료 보고서를 작성한다.

검증:

```bash
shasum -a 256 samples/basic/KTX.hwp Vendor/rhwp/samples/basic/KTX.hwp samples/basic/request.hwp Vendor/rhwp/samples/basic/request.hwp samples/exam_kor.hwp Vendor/rhwp/samples/exam_kor.hwp
cmp -s samples/basic/KTX.hwp Vendor/rhwp/samples/basic/KTX.hwp
cmp -s samples/basic/request.hwp Vendor/rhwp/samples/basic/request.hwp
cmp -s samples/exam_kor.hwp Vendor/rhwp/samples/exam_kor.hwp
```

## Stage 2: `samples/` fixture 편입

작업:

- 루트 `samples/`를 Git 추적 대상으로 편입한다.
- `.DS_Store`는 기존 `.gitignore` 규칙에 따라 제외한다.
- 대표 3개 샘플 경로가 존재하는지 확인한다.

완료 조건:

- `git status --short -- samples`에서 필요한 fixture 파일만 추가 대상으로 보인다.
- Stage 2 완료 보고서를 작성한다.

검증:

```bash
git status --short -- samples
test -f samples/basic/KTX.hwp
test -f samples/basic/request.hwp
test -f samples/exam_kor.hwp
```

## Stage 3: render smoke script 기본 경로 변경

작업:

- `scripts/validate-stage3-render.sh`의 기본 샘플 경로를 `samples/` 기준으로 변경한다.
- 인자로 샘플을 직접 전달하는 기존 구조는 유지한다.
- `Vendor/rhwp`는 기본 샘플 경로 계산에서 제거한다.

완료 조건:

- 인자 없이 `./scripts/validate-stage3-render.sh`를 실행하면 `samples/basic/KTX.hwp`, `samples/basic/request.hwp`, `samples/exam_kor.hwp`를 사용한다.
- Stage 3 완료 보고서를 작성한다.

검증:

```bash
bash -n scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh
```

## Stage 4: README/manual 경로 갱신

작업:

- `README.md`의 기본 render smoke 샘플 경로를 `samples/` 기준으로 변경한다.
- `mydocs/manual/build_run_guide.md`의 render/Quick Look/Thumbnail 예시 경로를 갱신한다.
- `mydocs/manual/release_distribution_guide.md`의 Finder smoke test 예시 경로를 갱신한다.
- `mydocs/manual/core_submodule_operation_guide.md`에서 필요한 경우 `Vendor/rhwp/samples` 의존이 없음을 명확히 한다.

완료 조건:

- 현재 운영 문서와 script에서 기본 검증 경로로 `Vendor/rhwp/samples`를 안내하지 않는다.
- Stage 4 완료 보고서를 작성한다.

검증:

```bash
rg -n "Vendor/rhwp/samples|Vendor/rhwp/samples/basic|Vendor/rhwp/samples/exam_kor" README.md scripts mydocs/manual
```

## Stage 5: 전체 검증과 최종 보고

작업:

- 최소 빌드/렌더 검증을 수행한다.
- 최종 결과 보고서를 작성한다.
- 오늘할일 상태를 갱신한다.

완료 조건:

- render smoke test가 `samples/` 기본 경로로 통과한다.
- build와 문서 검증 결과가 최종 보고서에 기록된다.

검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
git diff --check
```

## 승인 요청

이 구현 계획서 기준으로 Stage 1 구현을 진행할지 승인 요청한다.
