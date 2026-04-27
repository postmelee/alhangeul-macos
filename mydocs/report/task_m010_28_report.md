# Issue #28 최종 결과 보고서

## 목적

렌더 검증과 Finder/Quick Look/Thumbnail smoke test 문서가 `Vendor/rhwp/samples`에 의존하지 않도록, 앱 저장소 루트의 `samples/`를 공식 fixture 경로로 채택했다.

## 최종 변경 요약

- 루트 `samples/` fixture 179개 파일을 Git 추적 대상으로 편입
- `samples/.DS_Store`는 기존 `.gitignore` 규칙으로 제외
- 대표 render smoke 샘플 3개 provenance 기록
  - `samples/basic/KTX.hwp`
  - `samples/basic/request.hwp`
  - `samples/exam_kor.hwp`
- `scripts/validate-stage3-render.sh` 기본 샘플 경로를 `samples/` 기준으로 변경
- README와 manual의 기본 render/Quick Look/Thumbnail smoke test 경로를 `samples/` 기준으로 갱신
- `mydocs/tech/task_m010_28_sample_provenance.md` 작성

## 대표 샘플 provenance

원본:

- `Vendor/rhwp` commit: `1e9d78a1d40c71779d81c6ec6870cd301d912626`
- license: MIT License

| 현재 경로 | 원본 경로 | sha256 | size |
|-----------|-----------|--------|------|
| `samples/basic/KTX.hwp` | `Vendor/rhwp/samples/basic/KTX.hwp` | `6c1a027d67b33c03f469b56548b4c7d6bca36b1c1190c7cc5eac88e35c403cf1` | `66048` |
| `samples/basic/request.hwp` | `Vendor/rhwp/samples/basic/request.hwp` | `99e63b90f4aa3197029299ab087bc46225b3c27c0d07d424145b20879b45f12e` | `65536` |
| `samples/exam_kor.hwp` | `Vendor/rhwp/samples/exam_kor.hwp` | `0315576fb25dd29ad3b6b188ee2539d0e8d31c15b74847be801c2186a97aac69` | `10418688` |

## 검증 결과

통과:

```bash
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh output/task28-stage5-render
rg -n "Vendor/rhwp/samples|Vendor/rhwp/samples/basic|Vendor/rhwp/samples/exam_kor" README.md scripts mydocs/manual
git diff --check
```

`validate-stage3-render.sh` 결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

실패:

```bash
./scripts/build-rust-macos.sh --verify-lock
```

실패 내용:

- `Frameworks/universal/librhwp.a` expected sha256: `725b65ad445660292bb1a5f2a0f9107ff810e65a699ade78e0a3b26dd901dd50`
- actual sha256: `5e1255b5eb30cef156c43d123faa177c3014ebfa3a4fd4daf5764f025a80db2f`
- expected size: `102627384`
- actual size: `102631504`

`Vendor/rhwp` commit과 generated header hash는 lock과 일치했다. 이번 작업은 샘플 fixture 독립화이므로 `rhwp-core.lock`은 변경하지 않았다.

## 남은 리스크

- `rhwp-core.lock`의 `librhwp.a` 검증 불일치는 별도 후속 조사가 필요하다. 동일 core commit에서 workspace 경로나 build 환경에 따라 static archive hash/size가 달라지는지 확인해야 한다.
- `samples/` 전체는 약 60MB로 repository size를 증가시킨다.
- 개별 HWP 샘플 파일의 외부 원출처가 저장소 내 별도 문서로 모두 분리되어 있지는 않다. 현재는 `Vendor/rhwp` MIT license와 동일 복사본 provenance를 근거로 개발 검증 fixture로 편입했다.

## 완료 판단

Issue #28의 목표인 “기본 검증 명령이 `Vendor/rhwp` 샘플 경로 없이 동작하게 만드는 선행 조건”은 충족했다.

## 승인 요청

이 최종 결과 보고서 기준으로 PR 생성 절차를 진행할지 승인 요청한다.
