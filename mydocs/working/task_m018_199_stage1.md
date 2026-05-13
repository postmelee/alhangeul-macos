# Task M018 #199 Stage 1 완료 보고서

## 단계 목적

공식 `/Applications/Alhangeul.app` `v0.1.0` 설치본만 남긴 상태에서 Finder thumbnail 미표시가 설치/등록 문제인지, Thumbnail extension 내부 렌더 hang인지 분리했다.

## 설치본/등록 상태

정리 후 Spotlight 기준 설치본은 `/Applications/Alhangeul.app` 하나였다.

PluginKit 활성 확장:

| 항목 | 값 |
|------|----|
| Preview extension | `com.postmelee.alhangeul.QLExtension(0.1.0)` |
| Thumbnail extension | `com.postmelee.alhangeul.ThumbnailExtension(0.1.0)` |
| 활성 경로 | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex` |

즉 중복 설치본이나 disabled app bundle이 primary 원인은 아니었다.

## 재현 결과

다음 smoke에서 공식 설치본의 thumbnail 생성이 완료되지 않았다.

```bash
qlmanage -t -s 512 -o /private/tmp/alhangeul-qltest.eEmWlk \
  /Users/melee/Documents/projects/rhwp-mac/samples/exam_science.hwp
qlmanage -t -s 512 -o /private/tmp/alhangeul-qltest.eEmWlk \
  /Users/melee/Documents/projects/rhwp-mac/samples/hwpx/hwpx-01.hwpx
```

관찰:

- `qlmanage`가 PNG를 만들지 못하고 대기했다.
- `AlhangeulThumbnail` extension 프로세스가 실행됐다.
- unified log에 `Generation ... took more than 60 seconds to reply`가 기록됐다.

## sample 분석

멈춘 `AlhangeulThumbnail` 프로세스는 다음 경로에 머물렀다.

```text
HwpThumbnailRenderCache.renderedPage
-> HwpPageImageRenderer.renderFirstPage
-> HwpPageImageRenderer.renderPage
-> CGContextFillRect
-> CGColorTransformConvertColorComponents
-> CGCMSConverterCreateCachedCGvImageConverter
-> __psynch_mutexwait
```

Quick Look reply drawing thread도 다음 경로에서 같은 색 변환 mutex wait을 보였다.

```text
HwpThumbnailProvider.provideThumbnail
-> drawPageImage
-> CGContextFillRect
-> CGColorTransformConvertColorComponents
```

## 원인 가설

두 조건이 겹치면서 Finder thumbnail 생성이 timeout으로 이어진 것으로 판단했다.

1. `HwpThumbnailRenderCache`가 concurrent worker queue로 여러 CoreGraphics bitmap render를 동시에 수행한다.
2. RGB bitmap/QL drawing context에서 `CGColor(gray:alpha:)` 색을 채우면서 CoreGraphics 색 변환 캐시 mutex 경합 또는 deadlock 경로에 진입한다.

Stage 2에서는 렌더 worker를 직렬화하고, 회색조 `CGColor` 생성 경로를 RGB context setter로 바꾸는 최소 수정으로 진행한다.

## 검증 상태

Stage 1은 제품 코드 변경 없이 재현/진단만 수행했다.
