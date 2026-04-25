# Issue #26 구현 계획서

## 구현 목표

Thumbnail embedded preview fast path의 성능 이점은 유지하면서, 요청 크기에 비해 지나치게 작은 embedded preview가 큰 Finder thumbnail에 확대 표시되는 회귀를 막는다.

## 단계 계획

### 1단계. embedded preview 품질 게이트 구현

- `decodeEmbeddedThumbnail(from:maximumPixelSize:)`에서 실제 디코딩 이미지 크기를 확인한다.
- `maximumPixelSize`가 없으면 기존 동작을 유지한다.
- 요청 긴 변이 `128px` 이하인 작은 요청은 embedded preview를 계속 허용한다.
- 큰 요청에서는 embedded preview 긴 변이 요청 긴 변의 `75%` 이상일 때만 fast path를 사용한다.
- 기준에 못 미치면 full render fallback으로 전환한다.

### 2단계. 분기 확인

- 임시 probe로 `group-drawing-02.hwp`와 `pic-in-head-02.hwp`의 64px/512px 요청 결과를 확인한다.
- `group-drawing-02.hwp`는 512px 요청에서 full render fallback으로 전환되는지 확인한다.
- `pic-in-head-02.hwp`는 512px 요청에서도 충분한 embedded preview fast path가 유지되는지 확인한다.

### 3단계. 빌드와 Finder thumbnail 검증

- Shared bridge 경계를 검사한다.
- Xcode project를 재생성한다.
- HostApp Debug build로 Thumbnail extension 빌드 포함 여부를 확인한다.
- `qlmanage`로 재현 샘플과 비교 샘플의 thumbnail 생성을 확인한다.

### 4단계. 보고서 정리

- 단계 완료 보고서와 최종 보고서를 작성한다.
- Finder 직접 확인에서 드러난 full render 공통 품질 문제는 별도 이슈로 분리한다.

## 예상 변경 파일

- `Sources/Shared/HwpPageImageRenderer.swift`
- `mydocs/orders/20260425.md`
- `mydocs/working/task_m050_26_stage1.md`
- `mydocs/report/task_m050_26_report.md`

## 단계별 검증

```bash
git diff --check -- Sources/Shared/HwpPageImageRenderer.swift
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project RhwpMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
qlmanage -r cache
qlmanage -t -x -s 512 -o /tmp/rhwp-task26-ql-512 /Users/melee/Documents/samples/group-drawing-02.hwp
qlmanage -t -x -s 512 -o /tmp/rhwp-task26-ql-512 /Users/melee/Documents/samples/pic-in-head-02.hwp
qlmanage -t -x -s 64 -o /tmp/rhwp-task26-ql-64 /Users/melee/Documents/samples/group-drawing-02.hwp
git diff --check
```

## 보류 기준

1. 품질 게이트가 정상 크기 embedded preview까지 과도하게 fallback시키는 경우
2. full render fallback이 재현 파일에서 실패하는 경우
3. 실제 Finder 확인 결과 full render fallback 후에도 저해상도 문제가 남는 경우

## 승인 요청 사항

이 구현 계획서 기준으로 1단계 구현에 들어갈지 승인 요청한다.
