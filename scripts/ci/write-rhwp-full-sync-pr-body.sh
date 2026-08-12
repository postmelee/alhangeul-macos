#!/bin/bash
set -euo pipefail

OUTPUT_FILE=""
CURRENT_CORE_TAG=""
CURRENT_CORE_COMMIT=""
CURRENT_STUDIO_TAG=""
CURRENT_STUDIO_COMMIT=""
TARGET_TAG=""
TARGET_COMMIT=""
TARGET_URL=""
BASE_BRANCH="devel"
MENTION="@postmelee"
CHANGED_PATHS_FILE=""
IMPACT_DETAILS_FILE=""
REPOSITORY_CHANGED_PATHS_FILE=""
VERIFICATION_FILE=""

usage() {
  cat >&2 <<EOF
Usage: $0 --output FILE --current-core-tag TAG --current-core-commit COMMIT --current-studio-tag TAG --current-studio-commit COMMIT --target-tag TAG --target-commit COMMIT [options]

Options:
  --output FILE                         PR body output file.
  --current-core-tag TAG                Current rhwp-core.lock release tag.
  --current-core-commit COMMIT          Current rhwp-core.lock resolved commit.
  --current-studio-tag TAG              Current bundled rhwp-studio release tag.
  --current-studio-commit COMMIT        Current bundled rhwp-studio resolved commit.
  --target-tag TAG                      Target upstream rhwp release tag.
  --target-commit COMMIT                Target upstream rhwp commit.
  --target-url URL                      Upstream release URL.
  --base-branch BRANCH                  PR base branch. Defaults to devel.
  --mention USER_OR_TEAM                Maintainer mention. Defaults to @postmelee.
  --changed-paths-file FILE             Upstream current..target changed paths.
  --impact-details-file FILE            TSV of impact paths and reasons.
  --repository-changed-paths-file FILE   Repository changed paths after full sync.
  --verification-file FILE              Verification command/result lines.
  -h, --help                            Show this help.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_value() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    fail "missing required option: $name"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --output)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --output"
        fi
        OUTPUT_FILE="$2"
        shift
        ;;
      --current-core-tag)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --current-core-tag"
        fi
        CURRENT_CORE_TAG="$2"
        shift
        ;;
      --current-core-commit)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --current-core-commit"
        fi
        CURRENT_CORE_COMMIT="$2"
        shift
        ;;
      --current-studio-tag)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --current-studio-tag"
        fi
        CURRENT_STUDIO_TAG="$2"
        shift
        ;;
      --current-studio-commit)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --current-studio-commit"
        fi
        CURRENT_STUDIO_COMMIT="$2"
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
      --target-url)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --target-url"
        fi
        TARGET_URL="$2"
        shift
        ;;
      --base-branch)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --base-branch"
        fi
        BASE_BRANCH="$2"
        shift
        ;;
      --mention)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --mention"
        fi
        MENTION="$2"
        shift
        ;;
      --changed-paths-file)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --changed-paths-file"
        fi
        CHANGED_PATHS_FILE="$2"
        shift
        ;;
      --impact-details-file)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --impact-details-file"
        fi
        IMPACT_DETAILS_FILE="$2"
        shift
        ;;
      --repository-changed-paths-file)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --repository-changed-paths-file"
        fi
        REPOSITORY_CHANGED_PATHS_FILE="$2"
        shift
        ;;
      --verification-file)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --verification-file"
        fi
        VERIFICATION_FILE="$2"
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

count_file_lines() {
  local path="$1"
  if [ -n "$path" ] && [ -f "$path" ]; then
    wc -l < "$path" | tr -d ' '
  else
    echo 0
  fi
}

write_path_bullets() {
  local path="$1"
  local limit="${2:-60}"
  local count=0
  local total_count

  if [ -z "$path" ] || [ ! -s "$path" ]; then
    echo "- 변경 없음"
    return
  fi

  while IFS= read -r changed_path; do
    [ -n "$changed_path" ] || continue
    count=$((count + 1))
    if [ "$count" -le "$limit" ]; then
      echo "- \`$changed_path\`"
    fi
  done < "$path"

  total_count="$(count_file_lines "$path")"
  if [ "$total_count" -gt "$limit" ]; then
    echo "- ... $((total_count - limit))개 추가 path 생략"
  fi
}

write_impact_bullets() {
  local path="$1"
  local limit="${2:-60}"
  local count=0
  local total_count

  if [ -z "$path" ] || [ ! -s "$path" ]; then
    echo "- viewer/WASM/core 영향 path 없음"
    return
  fi

  while IFS="$(printf '\t')" read -r impact_path reason; do
    [ -n "$impact_path" ] || continue
    count=$((count + 1))
    if [ "$count" -le "$limit" ]; then
      echo "- \`$impact_path\` - $reason"
    fi
  done < "$path"

  total_count="$(count_file_lines "$path")"
  if [ "$total_count" -gt "$limit" ]; then
    echo "- ... $((total_count - limit))개 추가 impact path 생략"
  fi
}

write_verification_bullets() {
  local path="$1"

  if [ -z "$path" ] || [ ! -s "$path" ]; then
    echo "- 자동 PR workflow에서 검증 결과를 채우지 못함"
    return
  fi

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "- $line"
  done < "$path"
}

main() {
  parse_args "$@"

  require_value "--output" "$OUTPUT_FILE"
  require_value "--current-core-tag" "$CURRENT_CORE_TAG"
  require_value "--current-core-commit" "$CURRENT_CORE_COMMIT"
  require_value "--current-studio-tag" "$CURRENT_STUDIO_TAG"
  require_value "--current-studio-commit" "$CURRENT_STUDIO_COMMIT"
  require_value "--target-tag" "$TARGET_TAG"
  require_value "--target-commit" "$TARGET_COMMIT"

  mkdir -p "$(dirname "$OUTPUT_FILE")"

  upstream_changed_count="$(count_file_lines "$CHANGED_PATHS_FILE")"
  impact_count="$(count_file_lines "$IMPACT_DETAILS_FILE")"
  repo_changed_count="$(count_file_lines "$REPOSITORY_CHANGED_PATHS_FILE")"

  cat > "$OUTPUT_FILE" <<EOF
# Sync rhwp upstream $TARGET_TAG

$MENTION upstream \`edwardkim/rhwp\` release 감지 결과 full upstream sync 후보를 생성했습니다.

## Summary

- base branch: \`$BASE_BRANCH\`
- upstream release: ${TARGET_URL:-"(URL unavailable)"}
- previous core tag: \`$CURRENT_CORE_TAG\`
- previous core commit: \`$CURRENT_CORE_COMMIT\`
- previous studio tag: \`$CURRENT_STUDIO_TAG\`
- previous studio commit: \`$CURRENT_STUDIO_COMMIT\`
- target tag: \`$TARGET_TAG\`
- target commit: \`$TARGET_COMMIT\`
- upstream changed paths: \`$upstream_changed_count\`
- viewer/WASM/core impact paths: \`$impact_count\`
- repository changed paths: \`$repo_changed_count\`

## Full sync scope

- \`rhwp-core.lock\`, \`RustBridge/Cargo.toml\`, \`RustBridge/Cargo.lock\` are updated to the target upstream release provenance.
- \`Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift\` is regenerated from the completed \`rhwp-core.lock\`.
- Bundled \`rhwp-studio\` and WASM assets are rebuilt from the same target commit.
- Bundled \`rhwp-studio\` manifest records the target upstream root \`Cargo.lock\` fingerprint.
- Generated \`Frameworks/\` artifacts are not committed; their reference metadata is recorded in \`rhwp-core.lock\`.

## Upstream impact detection

EOF

  write_impact_bullets "$IMPACT_DETAILS_FILE" >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<EOF

## Upstream changed paths

EOF

  write_path_bullets "$CHANGED_PATHS_FILE" >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<EOF

## Repository changes

EOF

  write_path_bullets "$REPOSITORY_CHANGED_PATHS_FILE" >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<EOF

## Verification

EOF

  write_verification_bullets "$VERIFICATION_FILE" >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<EOF

## Maintainer checklist

- [ ] \`rhwp-core.lock\` tag/commit and \`RustBridge/Cargo.lock\` resolved commit match the upstream release.
- [ ] \`RhwpCoreBuildInfo.swift\` release tag, commit, and enabled features match \`rhwp-core.lock\`.
- [ ] bundled \`rhwp-studio\` manifest tag/commit matches the upstream release.
- [ ] bundled \`rhwp-studio\` manifest \`source_cargo_lock_sha256\` matches the target upstream root \`Cargo.lock\`.
- [ ] PR CI macOS build, Rust/core verify, bundled studio verify, and release helper checks pass.
- [ ] upstream \`rhwp\` release notes and source changes are reviewed for app-facing impact.
- [ ] viewer/editor smoke need is decided before merge.
- [ ] public app release version, release rehearsal, and protected \`Release Publish DMG\` execution are approved separately.

## Release boundary

This PR only syncs upstream \`rhwp\` into the app repository as a review candidate. Signed/notarized DMG, GitHub Release, Sparkle stable appcast, and Homebrew distribution are not executed automatically.

Automation source: rhwp Upstream Sync PR
EOF
}

main "$@"
