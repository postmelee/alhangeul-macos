#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="${1:-$ROOT/build.noindex/DerivedData}"
mkdir -p "$OUT"
xcodegen generate
# 인증서 없이 실제 WebKit과 XCTest를 실행한다. 인쇄 검사는 상태 정책만 검사한다.
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath "$OUT" \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing
LLVM_PROFILE_FILE="$OUT/coverage-%p.profraw" xcrun xctest \
  -XCTest HostAppTests.RhwpStudioOutputFontPreparationTests,HostAppTests.RhwpStudioPagePDFRendererTests,HostAppTests.RhwpStudioPDFExportControllerTests,HostAppTests.RhwpStudioPagePayloadTests,HostAppTests.RhwpStudioPDFExportStateTests,HostAppTests.RhwpStudioPrintLifecycleTests,HostAppTests.RhwpStudioPrintOrientationPolicyTests,HostAppTests.SpotlightReindexServiceTests \
  "$OUT/Build/Products/Debug/HostAppTests.xctest"
