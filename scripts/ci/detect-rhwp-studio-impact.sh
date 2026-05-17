#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

UPSTREAM_DIR=""
CURRENT_TAG=""
CURRENT_COMMIT=""
TARGET_TAG=""
TARGET_COMMIT=""
OUTPUT_DIR="$ROOT/build.noindex/rhwp-upstream-impact"
GITHUB_OUTPUT_PATH="${GITHUB_OUTPUT:-}"

usage() {
  cat >&2 <<EOF
Usage: $0 --upstream-dir DIR --current-tag TAG --current-commit COMMIT --target-tag TAG --target-commit COMMIT [options]

Options:
  --upstream-dir DIR       Upstream edwardkim/rhwp checkout.
  --current-tag TAG        Currently bundled rhwp release tag.
  --current-commit COMMIT  Currently bundled rhwp resolved commit.
  --target-tag TAG         Target upstream rhwp release tag.
  --target-commit COMMIT   Target upstream rhwp resolved commit.
  --output-dir DIR         Directory for changed/impact path files. Defaults to build.noindex/rhwp-upstream-impact.
  --github-output FILE     GitHub Actions output file. Defaults to GITHUB_OUTPUT when set.
  -h, --help               Show this help.

Detects whether upstream changes between current and target commits affect
bundled rhwp-studio, WASM package output, or core viewer build inputs.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    fail "required tool not found: $tool"
  fi
}

require_value() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    fail "missing required option: $name"
  fi
}

validate_tag() {
  local tag="$1"
  if ! [[ "$tag" =~ ^v[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
    fail "rhwp release tag must look like vMAJOR.MINOR.PATCH, got: $tag"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --upstream-dir)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --upstream-dir"
        fi
        UPSTREAM_DIR="$2"
        shift
        ;;
      --current-tag)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --current-tag"
        fi
        CURRENT_TAG="$2"
        shift
        ;;
      --current-commit)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --current-commit"
        fi
        CURRENT_COMMIT="$2"
        shift
        ;;
      --target-tag)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --target-tag"
        fi
        TARGET_TAG="$2"
        shift
        ;;
      --target-commit)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --target-commit"
        fi
        TARGET_COMMIT="$2"
        shift
        ;;
      --output-dir)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --output-dir"
        fi
        OUTPUT_DIR="$2"
        shift
        ;;
      --github-output)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --github-output"
        fi
        GITHUB_OUTPUT_PATH="$2"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown option: $1"
        ;;
    esac
    shift
  done
}

resolve_commit() {
  local rev="$1"
  git -C "$UPSTREAM_DIR" rev-parse --verify "$rev^{commit}"
}

impact_reason() {
  local path="$1"

  case "$path" in
    rhwp-studio/*)
      echo "rhwp-studio source or build input"
      return 0
      ;;
    pkg/*)
      echo "WASM package output"
      return 0
      ;;
    Cargo.toml|Cargo.lock|rust-toolchain.toml|rust-toolchain|.cargo/*|crates/*|src/*)
      echo "Rust/core source or build input"
      return 0
      ;;
    package.json|package-lock.json|pnpm-lock.yaml|yarn.lock|bun.lockb|vite.config.*|tsconfig*.json)
      echo "repository-level web build input"
      return 0
      ;;
    fonts/*|font/*|LICENSE|LICENSE.*|COPYING|COPYING.*|NOTICE|NOTICE.*|THIRD_PARTY*|licenses/*)
      echo "font, license, or provenance input"
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

safe_name() {
  local value="$1"
  value="${value//[^A-Za-z0-9._-]/_}"
  printf '%s\n' "$value"
}

write_output() {
  local name="$1"
  local value="$2"
  if [ -n "$GITHUB_OUTPUT_PATH" ]; then
    echo "$name=$value" >> "$GITHUB_OUTPUT_PATH"
  fi
}

write_summary_body() {
  local changed_count="$1"
  local impact_count="$2"

  echo "## rhwp-studio impact detection"
  echo
  echo "- current tag: \`$CURRENT_TAG\`"
  echo "- current commit: \`$RESOLVED_CURRENT_COMMIT\`"
  echo "- target tag: \`$TARGET_TAG\`"
  echo "- target commit: \`$RESOLVED_TARGET_COMMIT\`"
  echo "- changed paths: \`$changed_count\`"
  echo "- impact paths: \`$impact_count\`"
  echo "- has viewer impact: \`$HAS_VIEWER_IMPACT\`"
  echo "- changed paths file: \`$CHANGED_PATHS_FILE\`"
  echo "- impact paths file: \`$IMPACT_PATHS_FILE\`"

  if [ "$impact_count" -gt 0 ]; then
    echo
    echo "### Impact paths"
    echo
    while IFS="$(printf '\t')" read -r path reason; do
      [ -n "$path" ] || continue
      echo "- \`$path\` ($reason)"
    done < "$IMPACT_DETAILS_FILE"
  fi
}

append_summary() {
  local changed_count="$1"
  local impact_count="$2"
  local summary_file="${GITHUB_STEP_SUMMARY:-}"

  if [ -n "$summary_file" ]; then
    write_summary_body "$changed_count" "$impact_count" >> "$summary_file"
  else
    write_summary_body "$changed_count" "$impact_count"
  fi
}

main() {
  parse_args "$@"

  require_tool git
  require_tool wc

  require_value "--upstream-dir" "$UPSTREAM_DIR"
  require_value "--current-tag" "$CURRENT_TAG"
  require_value "--current-commit" "$CURRENT_COMMIT"
  require_value "--target-tag" "$TARGET_TAG"
  require_value "--target-commit" "$TARGET_COMMIT"

  validate_tag "$CURRENT_TAG"
  validate_tag "$TARGET_TAG"

  if [ ! -d "$UPSTREAM_DIR/.git" ]; then
    fail "missing upstream git checkout: $UPSTREAM_DIR"
  fi

  RESOLVED_CURRENT_COMMIT="$(resolve_commit "$CURRENT_COMMIT")"
  RESOLVED_TARGET_COMMIT="$(resolve_commit "$TARGET_COMMIT")"

  safe_current_tag="$(safe_name "$CURRENT_TAG")"
  safe_target_tag="$(safe_name "$TARGET_TAG")"
  mkdir -p "$OUTPUT_DIR"

  CHANGED_PATHS_FILE="$OUTPUT_DIR/changed-${safe_current_tag}-to-${safe_target_tag}.txt"
  IMPACT_PATHS_FILE="$OUTPUT_DIR/impact-${safe_current_tag}-to-${safe_target_tag}.txt"
  IMPACT_DETAILS_FILE="$OUTPUT_DIR/impact-details-${safe_current_tag}-to-${safe_target_tag}.tsv"

  git -C "$UPSTREAM_DIR" diff --name-only \
    "$RESOLVED_CURRENT_COMMIT..$RESOLVED_TARGET_COMMIT" > "$CHANGED_PATHS_FILE"
  : > "$IMPACT_PATHS_FILE"
  : > "$IMPACT_DETAILS_FILE"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if reason="$(impact_reason "$path")"; then
      printf '%s\n' "$path" >> "$IMPACT_PATHS_FILE"
      printf '%s\t%s\n' "$path" "$reason" >> "$IMPACT_DETAILS_FILE"
    fi
  done < "$CHANGED_PATHS_FILE"

  changed_count="$(wc -l < "$CHANGED_PATHS_FILE" | tr -d ' ')"
  impact_count="$(wc -l < "$IMPACT_PATHS_FILE" | tr -d ' ')"

  HAS_VIEWER_IMPACT="false"
  if [ "$impact_count" -gt 0 ]; then
    HAS_VIEWER_IMPACT="true"
  fi

  write_output "current_tag" "$CURRENT_TAG"
  write_output "current_commit" "$RESOLVED_CURRENT_COMMIT"
  write_output "target_tag" "$TARGET_TAG"
  write_output "target_commit" "$RESOLVED_TARGET_COMMIT"
  write_output "has_viewer_impact" "$HAS_VIEWER_IMPACT"
  write_output "changed_paths_file" "$CHANGED_PATHS_FILE"
  write_output "impact_paths_file" "$IMPACT_PATHS_FILE"
  write_output "impact_details_file" "$IMPACT_DETAILS_FILE"
  write_output "impact_reason_count" "$impact_count"

  append_summary "$changed_count" "$impact_count"

  echo "current_tag=$CURRENT_TAG"
  echo "current_commit=$RESOLVED_CURRENT_COMMIT"
  echo "target_tag=$TARGET_TAG"
  echo "target_commit=$RESOLVED_TARGET_COMMIT"
  echo "has_viewer_impact=$HAS_VIEWER_IMPACT"
  echo "impact_reason_count=$impact_count"
  echo "changed_paths_file=$CHANGED_PATHS_FILE"
  echo "impact_paths_file=$IMPACT_PATHS_FILE"
  echo "impact_details_file=$IMPACT_DETAILS_FILE"
}

main "$@"
