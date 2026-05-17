#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UPSTREAM_REPO="edwardkim/rhwp"
TARGET_TAG=""
RUN_COMPATIBILITY_CHECK="true"
COMPATIBILITY_LOG=""

usage() {
  cat >&2 <<EOF
Usage: $0 [options]

Options:
  --target-tag TAG                 Check a specific rhwp release tag. Defaults to upstream latest release.
  --run-compatibility-check BOOL   true or false. Defaults to true.
  -h, --help                       Show this help.

Compares rhwp-core.lock with the upstream rhwp release and optionally runs:
  ./scripts/update-rhwp-core.sh --check --channel stable --tag <tag>
EOF
}

cleanup() {
  if [ -n "$COMPATIBILITY_LOG" ] && [ -f "$COMPATIBILITY_LOG" ]; then
    rm -f "$COMPATIBILITY_LOG"
  fi
}
trap cleanup EXIT

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

normalize_bool() {
  case "$1" in
    true|TRUE|1|yes|YES)
      echo "true"
      ;;
    false|FALSE|0|no|NO)
      echo "false"
      ;;
    *)
      fail "boolean value must be true or false, got: $1"
      ;;
  esac
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
      --target-tag)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --target-tag"
        fi
        TARGET_TAG="$2"
        shift
        ;;
      --run-compatibility-check)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --run-compatibility-check"
        fi
        RUN_COMPATIBILITY_CHECK="$(normalize_bool "$2")"
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

release_field() {
  local release_ref="$1"
  local field="$2"
  if [ -n "$release_ref" ]; then
    gh release view "$release_ref" -R "$UPSTREAM_REPO" --json "$field" --jq ".$field"
  else
    gh release view -R "$UPSTREAM_REPO" --json "$field" --jq ".$field"
  fi
}

append_output() {
  if [ -z "${GITHUB_OUTPUT:-}" ]; then
    return
  fi
  {
    echo "current_tag=$CURRENT_TAG"
    echo "current_commit=$CURRENT_COMMIT"
    echo "latest_tag=$LATEST_TAG"
    echo "target_tag=$CHECK_TAG"
    echo "target_url=$CHECK_URL"
    echo "outdated=$OUTDATED"
    echo "compatibility_status=$COMPATIBILITY_STATUS"
  } >> "$GITHUB_OUTPUT"
}

append_summary() {
  local summary_file="${GITHUB_STEP_SUMMARY:-}"
  local destination="/dev/stdout"
  if [ -n "$summary_file" ]; then
    destination="$summary_file"
  fi

  {
    echo "## rhwp upstream release check"
    echo
    echo "- current lock tag: \`$CURRENT_TAG\`"
    echo "- current lock commit: \`$CURRENT_COMMIT\`"
    echo "- upstream latest release: \`$LATEST_TAG\`"
    echo "- check target: \`$CHECK_TAG\`"
    echo "- target URL: $CHECK_URL"
    echo "- outdated: \`$OUTDATED\`"
    echo "- compatibility status: \`$COMPATIBILITY_STATUS\`"

    if [ -n "${CHECK_NAME:-}" ]; then
      echo "- release name: $CHECK_NAME"
    fi
    if [ -n "${CHECK_PUBLISHED_AT:-}" ]; then
      echo "- published at: \`$CHECK_PUBLISHED_AT\`"
    fi
    if [ -n "${CHECK_TARGET_COMMITISH:-}" ]; then
      echo "- target commitish: \`$CHECK_TARGET_COMMITISH\`"
    fi

    if [ -n "$COMPATIBILITY_LOG" ] && [ -s "$COMPATIBILITY_LOG" ]; then
      echo
      echo "### Compatibility check output"
      echo
      echo '```text'
      sed -n '1,120p' "$COMPATIBILITY_LOG"
      echo '```'
    fi
  } >> "$destination"
}

main() {
  parse_args "$@"
  require_tool gh
  require_tool git
  require_tool awk

  if [ -n "$TARGET_TAG" ]; then
    validate_tag "$TARGET_TAG"
  fi

  CURRENT_TAG="$(bash "$ROOT/scripts/ci/read-rhwp-core-lock.sh" rhwp_release_tag)"
  CURRENT_COMMIT="$(bash "$ROOT/scripts/ci/read-rhwp-core-lock.sh" rhwp_commit)"

  LATEST_TAG="$(release_field "" tagName)"
  validate_tag "$LATEST_TAG"

  if [ -n "$TARGET_TAG" ]; then
    CHECK_TAG="$TARGET_TAG"
  else
    CHECK_TAG="$LATEST_TAG"
  fi
  validate_tag "$CHECK_TAG"

  CHECK_URL="$(release_field "$CHECK_TAG" url)"
  CHECK_NAME="$(release_field "$CHECK_TAG" name)"
  CHECK_PUBLISHED_AT="$(release_field "$CHECK_TAG" publishedAt)"
  CHECK_TARGET_COMMITISH="$(release_field "$CHECK_TAG" targetCommitish)"

  if [ "$CURRENT_TAG" = "$CHECK_TAG" ]; then
    OUTDATED="false"
  else
    OUTDATED="true"
  fi

  COMPATIBILITY_STATUS="skipped_current"
  if [ "$RUN_COMPATIBILITY_CHECK" = "false" ]; then
    COMPATIBILITY_STATUS="skipped_by_input"
  elif [ "$OUTDATED" = "true" ]; then
    COMPATIBILITY_LOG="$(mktemp "${TMPDIR:-/tmp}/rhwp-compatibility.XXXXXX")"
    if "$ROOT/scripts/update-rhwp-core.sh" --check --channel stable --tag "$CHECK_TAG" > "$COMPATIBILITY_LOG" 2>&1; then
      COMPATIBILITY_STATUS="passed"
    else
      COMPATIBILITY_STATUS="failed"
    fi
  fi

  append_output
  append_summary

  echo "current_tag=$CURRENT_TAG"
  echo "latest_tag=$LATEST_TAG"
  echo "target_tag=$CHECK_TAG"
  echo "outdated=$OUTDATED"
  echo "compatibility_status=$COMPATIBILITY_STATUS"

  if [ "$COMPATIBILITY_STATUS" = "failed" ]; then
    fail "compatibility check failed for $CHECK_TAG"
  fi
}

main "$@"
