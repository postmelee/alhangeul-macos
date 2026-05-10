#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 <base-ref> <head-ref>

Classifies changed files for PR CI and writes GitHub Actions outputs when
GITHUB_OUTPUT is set.

Outputs:
  docs_only
  run_macos_build
  run_rust_verify
  run_render_smoke
  run_release_checks
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 2 ]; then
  usage
  exit 1
fi

BASE_REF="$1"
HEAD_REF="$2"

git rev-parse --verify "$BASE_REF^{commit}" >/dev/null
git rev-parse --verify "$HEAD_REF^{commit}" >/dev/null

changed_files="$(git diff --name-only "$BASE_REF..$HEAD_REF")"

docs_only=true
run_macos_build=false
run_rust_verify=false
run_render_smoke=false
run_release_checks=false

macos_reasons=""
rust_reasons=""
render_reasons=""
release_reasons=""
non_docs_reasons=""

append_reason() {
  local current="$1"
  local reason="$2"

  if [ -z "$current" ]; then
    printf '%s' "$reason"
  else
    printf '%s\n%s' "$current" "$reason"
  fi
}

set_non_docs() {
  local reason="$1"
  docs_only=false
  non_docs_reasons="$(append_reason "$non_docs_reasons" "$reason")"
}

enable_macos_build() {
  local reason="$1"
  run_macos_build=true
  macos_reasons="$(append_reason "$macos_reasons" "$reason")"
}

enable_rust_verify() {
  local reason="$1"
  run_rust_verify=true
  rust_reasons="$(append_reason "$rust_reasons" "$reason")"
}

enable_render_smoke() {
  local reason="$1"
  run_render_smoke=true
  render_reasons="$(append_reason "$render_reasons" "$reason")"
}

enable_release_checks() {
  local reason="$1"
  run_release_checks=true
  release_reasons="$(append_reason "$release_reasons" "$reason")"
}

is_docs_path() {
  local path="$1"

  case "$path" in
    README.md|*.md|docs/*|mydocs/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

classify_path() {
  local path="$1"
  local matched=0

  if ! is_docs_path "$path"; then
    set_non_docs "$path is not a docs-only path"
  fi

  case "$path" in
    docs/appcast.xml|docs/index.html|docs/updates/*|mydocs/manual/release*.md|mydocs/release/*|mydocs/tech/release_environment.md)
      enable_release_checks "$path affects release communication"
      matched=1
      ;;
  esac

  case "$path" in
    Sources/*|project.yml|Alhangeul.xcodeproj/*)
      enable_macos_build "$path affects app or Xcode build inputs"
      matched=1
      ;;
  esac

  case "$path" in
    RustBridge/*|rhwp-core.lock|Frameworks/*|Vendor/rhwp/*|rust-toolchain.toml|scripts/build-rust-macos.sh|scripts/update-rhwp-core.sh|scripts/sync-rhwp-studio.sh|scripts/verify-rhwp-studio-assets.sh)
      enable_macos_build "$path affects Rust bridge/core artifacts"
      enable_rust_verify "$path affects Rust bridge/core lock verification"
      matched=1
      ;;
  esac

  case "$path" in
    Sources/RhwpCoreBridge/*|Sources/Shared/*|Sources/QLExtension/*|Sources/ThumbnailExtension/*|samples/*|scripts/stage3_render_check.swift|scripts/validate-stage3-render.sh|scripts/render-debug-compare.sh|scripts/render_debug_compare.swift)
      enable_macos_build "$path affects renderer or extension paths"
      enable_render_smoke "$path affects renderer smoke coverage"
      matched=1
      ;;
  esac

  case "$path" in
    .github/workflows/*|scripts/release.sh|scripts/package-release.sh|scripts/create-dmg-background.swift|scripts/ci/*|scripts/update-cask-sha256.sh|Casks/*)
      set_non_docs "$path affects CI/release automation"
      enable_release_checks "$path affects release scripts, workflows, or Cask automation"
      matched=1
      ;;
  esac

  if [ "$matched" -eq 0 ] && ! is_docs_path "$path"; then
    enable_macos_build "$path is unclassified non-docs change"
  fi
}

while IFS= read -r path; do
  [ -n "$path" ] || continue
  classify_path "$path"
done <<< "$changed_files"

if [ "$run_macos_build" = true ]; then
  enable_rust_verify "macOS build requires generated Frameworks/Rhwp.xcframework in fresh CI worktree"
fi

write_output() {
  local name="$1"
  local value="$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$name=$value" >> "$GITHUB_OUTPUT"
  fi
}

write_output "docs_only" "$docs_only"
write_output "run_macos_build" "$run_macos_build"
write_output "run_rust_verify" "$run_rust_verify"
write_output "run_render_smoke" "$run_render_smoke"
write_output "run_release_checks" "$run_release_checks"

print_reasons() {
  local title="$1"
  local reasons="$2"

  echo "### $title"
  echo
  if [ -z "$reasons" ]; then
    echo "- 없음"
  else
    while IFS= read -r reason; do
      [ -n "$reason" ] || continue
      echo "- $reason"
    done <<< "$reasons"
  fi
  echo
}

write_summary_body() {
  {
    echo "## PR change classification"
    echo
    echo "- base ref: \`$BASE_REF\`"
    echo "- head ref: \`$HEAD_REF\`"
    echo
    echo "| Flag | Value |"
    echo "|------|-------|"
    echo "| docs_only | \`$docs_only\` |"
    echo "| run_macos_build | \`$run_macos_build\` |"
    echo "| run_rust_verify | \`$run_rust_verify\` |"
    echo "| run_render_smoke | \`$run_render_smoke\` |"
    echo "| run_release_checks | \`$run_release_checks\` |"
    echo
    echo "### Changed files"
    echo
    if [ -z "$changed_files" ]; then
      echo "- 변경 없음"
    else
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        echo "- \`$path\`"
      done <<< "$changed_files"
    fi
    echo
    print_reasons "Non-docs reasons" "$non_docs_reasons"
    print_reasons "macOS build reasons" "$macos_reasons"
    print_reasons "Rust verify reasons" "$rust_reasons"
    print_reasons "Render smoke reasons" "$render_reasons"
    print_reasons "Release check reasons" "$release_reasons"
  }
}

write_summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    write_summary_body >> "$GITHUB_STEP_SUMMARY"
  else
    write_summary_body
  fi
}

write_summary
