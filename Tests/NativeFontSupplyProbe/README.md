# Task #568 Stage 4 — native bytes 구성 실험

CoreGraphics/CoreText가 지정한 원본 TTF bytes로 Regular/Bold를 직접 구성하는지 검사하는 좁은 진단이다. 실제 문서 renderer, 설치/관리 service, 선택·캐시·Skia/FFI 연결의 완료 증거가 아니다. AppKit 및 OS 글꼴 등록을 사용하지 않는다.

승인된 고운바탕 v2.000 Regular/Bold 입력의 원본 SHA-256과 PS를 확인하고 한글/ASCII glyph 조회·CTLine 렌더를 수행한다. Regular에 0 padding을 메모리에서 붙인 대조군은 같은 PS지만 다른 bytes hash를 갖는다. 원본 파일을 바꾸지 않으며 이 대조만으로 서로 다른 버전의 캐시 일관성을 입증하지 않는다.

```bash
mkdir -p build.noindex/task568/stage4/coretext-probe
swiftc -target arm64-apple-macosx12.0 \
  -module-cache-path build.noindex/task568/stage4/coretext-probe/module-cache \
  Tests/NativeFontSupplyProbe/main.swift \
  -framework CoreGraphics -framework CoreText -framework ImageIO \
  -framework UniformTypeIdentifiers -framework CryptoKit \
  -o build.noindex/task568/stage4/coretext-probe/native-font-check
build.noindex/task568/stage4/coretext-probe/native-font-check \
  build.noindex/task568/stage4/coretext-probe \
  build.noindex/task567/fonts/gowun-batang
```

`result.json`은 입력 hash/bytes/PS/glyph와 prototype 경계를, `native-bytes.png`는 Regular/Bold의 독립 CTLine 결과를 남긴다. 위 명령은 arm64/macOS 12 target compile을 확인한다. 최신 macOS 실행을 실제 macOS 12/Intel 실행의 증거로 취급하지 않는다.
