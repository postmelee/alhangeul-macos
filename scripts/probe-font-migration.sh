#!/bin/bash
# 독립 실험 전용. 제품 앱·시스템 글꼴을 변경하지 않는다.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${FONT_PROBE_PYTHON:-python3}" "$SCRIPT_DIR/font_migration_probe.py" "$@"
