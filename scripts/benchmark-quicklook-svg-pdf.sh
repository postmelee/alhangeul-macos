#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <output-dir> [--runs N] <hwp-or-hwpx> [...]

Measures the rhwp core SVG -> PDF path through the Rust example helper.
The normal RustBridge staticlib build does not compile examples.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

OUT_DIR="$1"
shift
RUNS=3

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runs)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --runs requires a positive integer" >&2
        exit 1
      fi
      RUNS="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  echo "ERROR: missing input document" >&2
  usage
  exit 1
fi

case "$RUNS" in
  ''|*[!0-9]*)
    echo "ERROR: --runs must be a positive integer" >&2
    exit 1
    ;;
  0)
    echo "ERROR: --runs must be greater than 0" >&2
    exit 1
    ;;
esac

mkdir -p "$OUT_DIR"

cargo run \
  --manifest-path "$ROOT/RustBridge/Cargo.toml" \
  --release \
  --example svg_pdf_benchmark \
  -- "$OUT_DIR" --runs "$RUNS" "$@"
