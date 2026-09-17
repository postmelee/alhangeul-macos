#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/build.noindex/font-library-tests"
mkdir -p "$OUT"
python3 - "$ROOT" <<'PY'
import hashlib
import plistlib
import sys
from pathlib import Path
root = Path(sys.argv[1])
info = plistlib.loads((root / 'Sources/HostApp/Info.plist').read_bytes())
entitlements = plistlib.loads((root / 'Sources/HostApp/HostApp.entitlements').read_bytes())
group = info['AlhangeulFontLibraryGroupIdentifier']
assert group in entitlements['com.apple.security.application-groups'], 'App Group 설정 불일치'
assert '$(' not in group, '로컬 재서명 경로에 미치환 변수를 남기지 않음'
fixtures = root / 'Tests/FontLibraryTests/Fixtures'
for line in (fixtures / 'SHA256SUMS').read_text().splitlines():
    expected, name = line.split()
    assert hashlib.sha256((fixtures / name).read_bytes()).hexdigest() == expected, name
print('PASS: App Group 설정 일치·fixture 해시')
PY
xcodegen generate
# 테스트 번들은 인증서가 필요 없는 ad-hoc 서명을 사용한다.
# 로컬 Xcode 26의 testmanager 번들 로드 오류와 분리하여 XCTest 실행기로 직접 검증한다.
XCODE_ARGS=(-project Alhangeul.xcodeproj -scheme FontLibraryTests
  -configuration Debug -destination 'platform=macOS'
  -derivedDataPath "$OUT/DerivedData" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-)
xcodebuild "${XCODE_ARGS[@]}" build-for-testing
LLVM_PROFILE_FILE="$OUT/coverage-%p.profraw" \
  xcrun xctest "$OUT/DerivedData/Build/Products/Debug/FontLibraryTests.xctest"
