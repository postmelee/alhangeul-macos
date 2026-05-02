# Task M015 #106 Stage 4 완료 보고서

## 단계 목적

Stage 3 이미지 crop/effect/brightness/contrast 보강 이후 대표 이미지 포함 샘플에서 render-debug 필수 산출물이 정상 생성되고 native PNG가 non-blank인지 확인했다.

이번 단계는 source code 변경 없이 검증 산출물과 summary 값을 기록했다.

## 산출물

| 구분 | 경로 또는 값 | 요약 |
|------|--------------|------|
| render debug 출력 | `/private/tmp/rhwp-task106-stage4` | 샘플 3개 render tree JSON, core SVG, native PNG, summary 생성 |
| 단계 보고서 | `mydocs/working/task_m015_106_stage4.md` | Stage 4 검증 결과 |

## 본문 변경 정도 / 본문 무손실 여부

코드와 제품 문서는 변경하지 않았다. 이번 단계의 저장소 변경은 단계 보고서 추가뿐이다.

## 검증 결과

작업 브랜치 상태:

```text
## local/task106...origin/devel [ahead 5]
```

render debug 실행:

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-task106-stage4 --page 1 samples/복학원서.hwp samples/20250130-hongbo.hwp samples/aift.hwp
```

결과:

```text
OK 복학원서.hwp: page=1 renderTreeJSON=... coreSVG=... nativePNG=... summary=...
OK 20250130-hongbo.hwp: page=1 renderTreeJSON=... coreSVG=... nativePNG=... summary=...
OK aift.hwp: page=1 renderTreeJSON=... coreSVG=... nativePNG=... summary=...
```

summary 핵심값:

| 샘플 | PageCount | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs | Diff |
|------|-----------|---------------|----------------------|----------|------------|----------------------|------|
| `복학원서.hwp` | 1 | `794x1123` | 261727 | 102 | 25 | 0 | not generated |
| `20250130-hongbo.hwp` | 4 | `794x1123` | 84406 | 60 | 35 | 0 | not generated |
| `aift.hwp` | 77 | `794x1123` | 132970 | 25 | 15 | 0 | not generated |

필수 산출물 확인:

| 샘플 | render tree JSON | core SVG | native PNG | summary |
|------|------------------|----------|------------|---------|
| `복학원서.hwp` | 생성 | 생성 | 생성 | 생성 |
| `20250130-hongbo.hwp` | 생성 | 생성 | 생성 | 생성 |
| `aift.hwp` | 생성 | 생성 | 생성 | 생성 |

native PNG hash:

| 샘플 | SHA-256 |
|------|---------|
| `복학원서.hwp` | `d164965a236b38d28ea79d03de17f0c289aeed91c80768ad6c59dff6339f4e9c` |
| `20250130-hongbo.hwp` | `f40bf21406a4d8a2ab1ff764b4f410c145090d11357341b1de93d4f55b2c59fb` |
| `aift.hwp` | `50489f767d0abd5b2a06cfd1430f2e4b3d225f7217b010a43e71879d5208dc2a` |

`복학원서.hwp` Stage 3/Stage 4 native PNG hash는 동일하다.

```text
Stage 3: d164965a236b38d28ea79d03de17f0c289aeed91c80768ad6c59dff6339f4e9c
Stage 4: d164965a236b38d28ea79d03de17f0c289aeed91c80768ad6c59dff6339f4e9c
```

이는 Stage 4의 `복학원서.hwp` 재검증이 Stage 3 결과와 재현 가능함을 의미한다. 워터마크는 Stage 2의 풀컬러 표시에서 Stage 3/4의 grayscale 및 brightness/contrast 적용 상태로 바뀐 상태가 유지됐다.

PNG 크기 확인:

```text
복학원서.hwp: pixelWidth 794, pixelHeight 1123
20250130-hongbo.hwp: pixelWidth 794, pixelHeight 1123
aift.hwp: pixelWidth 794, pixelHeight 1123
```

whitespace 검증:

```bash
git diff --check -- mydocs/working/task_m015_106_stage4.md
```

결과: 통과.

## 잔여 위험

- `qlmanage` sandbox 오류로 core SVG rasterize와 pixel diff는 생성되지 않았다. 각 summary의 `DiffReason`은 `qlmanage rasterize failed`로 기록됐다. 필수 산출물은 모두 생성됐다.
- Stage 4는 대표 샘플 3개 기반 smoke 검증이다. 모든 이미지 effect/fill mode의 완전 parity는 수행계획서 제외 범위이며, 미지원 fill mode는 bbox draw fallback으로 남아 있다.

## 다음 단계 영향

Stage 5에서는 `check-no-appkit`, 기본 render smoke, HostApp Debug build를 수행하고 최종 보고서와 오늘할일을 정리한다.

## 승인 요청

Stage 4 완료를 승인하고 Stage 5 `통합 검증과 최종 보고`로 진행해도 되는지 승인 요청한다.
