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

## Stage 4.1 — 실제 native 어댑터

`RustBridge/examples/native_font_context_probe.rs`는 새 C ABI와 public FontResolver 기반 어댑터를 실행한다. `integration/main.swift`는 Swift wrapper·CGTreeRenderer·Shared 진입점까지 대조한다. Stage 3에서 생성한 합성 `gowun-document.hwp/.hwpx`와 승인된 원본 TTF를 사용한다. 이 결과는 live catalog/관리 snapshot·lease·Finder의 수용 결과가 아니다. 지원 범위/한도/기여 후보는 [native 계약](../../mydocs/tech/task_m020_568_native_contract.md)의 5–6절을 따른다.

```bash
MACOSX_DEPLOYMENT_TARGET=12.0 cargo test --manifest-path RustBridge/Cargo.toml --locked --offline --release --target aarch64-apple-darwin
MACOSX_DEPLOYMENT_TARGET=12.0 cargo run --manifest-path RustBridge/Cargo.toml --locked --offline --release --target aarch64-apple-darwin --example native_font_context_probe -- build.noindex/task568/stage3/fixtures/gowun-document.hwpx build.noindex/task567/fonts/gowun-batang build.noindex/task568/stage4/ffi-hwpx
RustBridge/target/aarch64-apple-darwin/release/examples/native_font_context_probe build.noindex/task568/stage3/fixtures/gowun-document.hwp build.noindex/task567/fonts/gowun-batang build.noindex/task568/stage4/ffi-hwp
```

양성·missing glyph 대조 fixture는 새 경로에 생성한다. 재실행할 때 기존 생성 파일을 원본 사용자 문서로 착각해 덮어쓰지 않도록 helper는 기존 출력 경로를 거부한다.

```bash
python3 Tests/NativeFontSupplyProbe/prepare_fixture.py build.noindex/task568/stage3/fixtures/gowun-document.hwpx build.noindex/task568/stage4/regular-control.hwpx
python3 Tests/NativeFontSupplyProbe/prepare_fixture.py build.noindex/task568/stage3/fixtures/gowun-document.hwpx build.noindex/task568/stage4/missing-glyph.hwpx --missing-glyph
RustBridge/target/aarch64-apple-darwin/release/examples/native_font_context_probe build.noindex/task568/stage4/regular-control.hwpx build.noindex/task567/fonts/gowun-batang build.noindex/task568/stage4/ffi-regular regular
RustBridge/target/aarch64-apple-darwin/release/examples/native_font_context_probe build.noindex/task568/stage4/missing-glyph.hwpx build.noindex/task567/fonts/gowun-batang build.noindex/task568/stage4/ffi-missing unsupported
scripts/build-rust-macos.sh --verify-portable
swiftc -target arm64-apple-macosx12.0 -module-cache-path build.noindex/task568/stage4/swift-modules -I Frameworks/modulemap Sources/RhwpCoreBridge/RhwpDocument.swift Sources/RhwpCoreBridge/RhwpNativeFontContext.swift Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/PageOverlayImages.swift Sources/RhwpCoreBridge/FontFallback.swift Sources/RhwpCoreBridge/FontResourceRegistry.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/Shared/HwpPageImageRenderer.swift Sources/Shared/HwpNativePageCompositor.swift Tests/NativeFontSupplyProbe/integration/main.swift -L Frameworks/universal -lrhwp -framework CoreText -framework CoreGraphics -framework ImageIO -framework CryptoKit -framework Foundation -framework CoreServices -framework ApplicationServices -framework Security -framework Metal -framework QuartzCore -framework IOSurface -framework OpenGL -lc++ -lz -liconv -o build.noindex/task568/stage4/native-integration
```

실행 시 working directory는 `build.noindex/task568/stage4/swift-integration`으로 지정하고 executable과 repository 인자는 절대 경로를 사용한다. repository cwd로 실행하면 기존 registry가 번들 WOFF2를 process 등록하므로, 이것을 사용자 TTF 무등록 증거와 혼동하지 않는다. 결과의 `bundledProcessRegisteredCount`도 확인한다.

실제 글꼴 버전 변경 시험 대신, 같은 PS의 메모리 padding bytes와 원본을 연속 적용해 hash/resource identity가 교체되는지 검사한다. 성공 PNG의 face/hash·run proof, 실패 시 빈 PNG, 원본 문서 tree 보존, context 제거 뒤 기본 렌더 복원, 기본 glyph가 없는 face의 실패를 확인한다. 초기 nominal lowerer 한계와 최종 public adapter 결과를 분리해 보존한다.

## Stage 4.2 — 공통 공급 service와 native 요청

공식 matcher는 upstream v0.8.7 원본 8개 module 및 기존 앱 catalog 정책으로 생성한다. upstream source를 편집하지 않는다. 생성 bundle의 receipt는 CI에서 검사한다. 생성 도구는 build.noindex 안에 고정 설치하며 제품 실행 의존성이 아니다.

```bash
npm install --prefix build.noindex/task568/stage4/native-tooling --no-audit --no-fund --save-exact esbuild@0.25.12
node scripts/build-native-font-matcher.mjs --upstream-dir build.noindex/task567/stage3-2/upstream-v087 --tool-dir build.noindex/task568/stage4/native-tooling
node scripts/build-native-font-matcher.mjs --verify --upstream-dir build.noindex/task567/stage3-2/upstream-v087
python3 Tests/NativeFontSupplyProbe/prepare_fixture.py build.noindex/task568/stage3/fixtures/gowun-document.hwpx build.noindex/task568/stage4/installed-wide.hwpx --installed-regular
python3 -m venv build.noindex/task568/stage4/font-tooling
build.noindex/task568/stage4/font-tooling/bin/pip install fonttools==4.59.2
build.noindex/task568/stage4/font-tooling/bin/python Tests/NativeFontSupplyProbe/supply/prepare_variant.py build.noindex/task567/fonts/gowun-batang/GowunBatang-Regular.ttf build.noindex/task568/stage4/GowunBatang-Regular-outline.ttf
python3 scripts/probe-native-font-supply.py --output build.noindex/task568/stage4/supply-new-run
```

fixture helper와 수용 wrapper는 기존 출력 경로를 거부한다. 이미 생성한 입력은 재사용하고 새 수용 출력 경로를 지정한다. 현재 환경의 활성 `ArialUnicodeMS`와 기존 승인 고운바탕 입력이 필요하다. 사용자 원본은 읽기만 하고 고운바탕 설치 경로 fixture는 프로세스 한정 등록 후 해제한다. 관리 복사본은 새 격리 저장소에 import한다.

실제 서비스·선택·CG/Skia·원본 변형/복원과 metadata snapshot의 필요 object만 읽기를 검사한다. 동명/미해결 충돌 DTO, 대기 gate·문서 current는 주입 수용이다. 결과 JSON의 read count는 소비자 공급 판독 횟수이며 inspector/Skia의 전체 I/O·peak RSS를 뜻하지 않는다. 모든 시험은 앱 설치·인쇄·인증서·확장 등록 없이 CLI에서 실행하며 cwd도 격리 출력으로 고정한다. [단계 보고서](../../mydocs/working/task_m020_568_stage4.md)의 지원/미검증 범위를 따른다.
