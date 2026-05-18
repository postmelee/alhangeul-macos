#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_ROOT="/private/tmp/alhangeul-extension-registration-hygiene"

CHECK_ONLY=1
CLEANUP_DEV_REGISTRATIONS=0
RUN_CACHE_RESET=1
ALLOWED_APPS=("$HOME/Applications/Alhangeul.app" "/Applications/Alhangeul.app")

PREVIEW_EXTENSION_ID="com.postmelee.alhangeul.QLExtension"
THUMBNAIL_EXTENSION_ID="com.postmelee.alhangeul.ThumbnailExtension"

RUN_DIR=""
DIAG_DIR=""
ISSUES_FILE=""
WARNINGS_FILE=""
LSREGISTER=""
ISSUE_COUNT=0
WARNING_COUNT=0

usage() {
  cat <<'USAGE'
Usage: scripts/check-extension-registration-hygiene.sh [options]

Checks whether local Finder Quick Look/Thumbnail registrations are clean enough
for Alhangeul release validation and contributor smoke testing.

Options:
  --check-only
      Report stale or duplicate registrations without changing local state.
      This is the default.

  --cleanup-dev-registrations
      Unregister only development/test Alhangeul.app registrations from
      build.noindex/ and Xcode DerivedData, then reset the Quick Look cache.
      This never deletes app bundles and never performs a global lsregister reset.

  --allow-installed-app PATH
      Treat PATH as an expected installed Alhangeul.app location. Can be repeated.
      Defaults are $HOME/Applications/Alhangeul.app and /Applications/Alhangeul.app.

  --output-dir PATH
      Write diagnostics under PATH. Default:
      /private/tmp/alhangeul-extension-registration-hygiene

  --no-cache-reset
      With --cleanup-dev-registrations, skip qlmanage -r cache.

  -h, --help
      Show this help.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

find_lsregister() {
  local candidate
  for candidate in \
    "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" \
    "/System/Library/Frameworks/CoreServices.framework/Support/lsregister"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

abs_path() {
  local path="$1"
  if [ "${path#/}" != "$path" ]; then
    printf '%s\n' "$path"
    return 0
  fi
  printf '%s/%s\n' "$(pwd)" "$path"
}

prepare_run_dir() {
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  RUN_DIR="$OUTPUT_ROOT/$stamp"
  DIAG_DIR="$RUN_DIR/diagnostics"
  ISSUES_FILE="$RUN_DIR/issues.txt"
  WARNINGS_FILE="$RUN_DIR/warnings.txt"
  mkdir -p "$DIAG_DIR"
  : > "$ISSUES_FILE"
  : > "$WARNINGS_FILE"
}

record_issue() {
  ISSUE_COUNT=$((ISSUE_COUNT + 1))
  printf '%s\n' "$*" >> "$ISSUES_FILE"
}

record_warning() {
  WARNING_COUNT=$((WARNING_COUNT + 1))
  printf '%s\n' "$*" >> "$WARNINGS_FILE"
}

require_tools() {
  local missing=0
  local tool
  for tool in awk grep sort sed find wc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'missing required tool: %s\n' "$tool" >&2
      missing=1
    fi
  done
  if ! command -v pluginkit >/dev/null 2>&1; then
    printf 'missing required tool: pluginkit\n' >&2
    missing=1
  fi
  if [ "$CLEANUP_DEV_REGISTRATIONS" -eq 1 ] && [ "$RUN_CACHE_RESET" -eq 1 ]; then
    if ! command -v qlmanage >/dev/null 2>&1; then
      printf 'missing required tool for cleanup: qlmanage\n' >&2
      missing=1
    fi
  fi
  if ! LSREGISTER="$(find_lsregister)"; then
    printf 'missing required tool: lsregister\n' >&2
    missing=1
  fi
  if [ "$missing" -ne 0 ]; then
    exit 2
  fi
}

is_dev_path() {
  local path="$1"
  case "$path" in
    "$ROOT/build.noindex/"*) return 0 ;;
    "$HOME/Library/Developer/Xcode/DerivedData/"*) return 0 ;;
  esac
  return 1
}

path_belongs_to_allowed_app() {
  local path="$1"
  local app
  for app in "${ALLOWED_APPS[@]}"; do
    [ -n "$app" ] || continue
    case "$path" in
      "$app"|"$app/"*) return 0 ;;
    esac
  done
  return 1
}

extract_alhangeul_app_paths() {
  awk 'match($0, /\/[^"]*(Alhangeul|알한글|RhwpMac|AlhangeulMac)\.app/) { print substr($0, RSTART, RLENGTH) }' | sort -u
}

extract_provider_paths() {
  awk -F 'Path = ' '/Path = / { print $2 }' | sed 's/[[:space:]]*$//' | sort -u
}

provider_app_root() {
  local path="$1"
  case "$path" in
    */Alhangeul.app/Contents/PlugIns/*) printf '%s\n' "${path%%/Contents/PlugIns/*}" ;;
    */알한글.app/Contents/PlugIns/*) printf '%s\n' "${path%%/Contents/PlugIns/*}" ;;
    */RhwpMac.app/Contents/PlugIns/*) printf '%s\n' "${path%%/Contents/PlugIns/*}" ;;
    */AlhangeulMac.app/Contents/PlugIns/*) printf '%s\n' "${path%%/Contents/PlugIns/*}" ;;
  esac
}

list_registered_alhangeul_apps() {
  "$LSREGISTER" -dump 2>/dev/null | extract_alhangeul_app_paths
}

list_dev_registered_apps() {
  local app
  list_registered_alhangeul_apps | while IFS= read -r app; do
    [ -n "$app" ] || continue
    if is_dev_path "$app"; then
      printf '%s\n' "$app"
    fi
  done | sort -u
}

list_dev_filesystem_apps() {
  if [ -d "$ROOT/build.noindex" ]; then
    find "$ROOT/build.noindex" -type d -name "Alhangeul.app" -prune 2>/dev/null || true
  fi
  if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
    find "$HOME/Library/Developer/Xcode/DerivedData" -type d -name "Alhangeul.app" -prune 2>/dev/null || true
  fi
}

list_legacy_apps() {
  {
    "$LSREGISTER" -dump 2>/dev/null | extract_alhangeul_app_paths
    if command -v mdfind >/dev/null 2>&1; then
      mdfind 'kMDItemContentType == "com.apple.application-bundle" && (kMDItemFSName == "RhwpMac.app" || kMDItemFSName == "AlhangeulMac.app" || kMDItemFSName == "알한글.app")' 2>/dev/null || true
    fi
  } | awk '/\/(RhwpMac|AlhangeulMac|알한글)\.app$/ { print }' | sort -u
}

list_legacy_plugins() {
  local app
  {
    "$LSREGISTER" -dump 2>/dev/null | awk 'match($0, /\/[^"]*(RhwpMac|AlhangeulMac|알한글)\.app\/Contents\/PlugIns\/[^"]*\.appex/) { print substr($0, RSTART, RLENGTH) }'
    list_legacy_apps | while IFS= read -r app; do
      [ -d "$app/Contents/PlugIns" ] || continue
      find "$app/Contents/PlugIns" -type d -name "*.appex" -prune 2>/dev/null || true
    done
  } | sort -u
}

collect_diagnostics() {
  printf '%s\n' "${ALLOWED_APPS[@]}" | sort -u > "$DIAG_DIR/allowed-installed-apps.txt"

  {
    "$LSREGISTER" -dump 2>/dev/null | grep -E "com\.postmelee\.(alhangeul|alhangeulmac|rhwpmac)|Alhangeul|알한글|RhwpMac|AlhangeulMac" || true
  } > "$DIAG_DIR/lsregister-alhangeul-filtered.txt"

  list_registered_alhangeul_apps > "$DIAG_DIR/registered-alhangeul-apps.txt"
  list_dev_registered_apps > "$DIAG_DIR/dev-registered-apps.txt"
  list_dev_filesystem_apps | sort -u > "$DIAG_DIR/dev-filesystem-apps.txt"
  list_legacy_apps > "$DIAG_DIR/legacy-apps.txt"
  list_legacy_plugins > "$DIAG_DIR/legacy-plugins.txt"

  pluginkit -mAvvv -i "$PREVIEW_EXTENSION_ID" > "$DIAG_DIR/pluginkit-preview.txt" 2>&1 || true
  pluginkit -mAvvv -i "$THUMBNAIL_EXTENSION_ID" > "$DIAG_DIR/pluginkit-thumbnail.txt" 2>&1 || true
  pluginkit -mAvvv > "$DIAG_DIR/pluginkit-all.txt" 2>&1 || true

  extract_provider_paths < "$DIAG_DIR/pluginkit-preview.txt" > "$DIAG_DIR/provider-preview-paths.txt"
  extract_provider_paths < "$DIAG_DIR/pluginkit-thumbnail.txt" > "$DIAG_DIR/provider-thumbnail-paths.txt"

  {
    cat "$DIAG_DIR/provider-preview-paths.txt"
    cat "$DIAG_DIR/provider-thumbnail-paths.txt"
  } | while IFS= read -r path; do
    [ -n "$path" ] || continue
    provider_app_root "$path"
  done | sort -u > "$DIAG_DIR/provider-app-roots.txt"
}

unregister_app_registration() {
  local app="$1"
  {
    printf 'unregister app: %s\n' "$app"
    if [ -d "$app/Contents/PlugIns" ]; then
      find "$app/Contents/PlugIns" -type d -name "*.appex" -prune 2>/dev/null | while IFS= read -r appex; do
        printf 'unregister appex: %s\n' "$appex"
        pluginkit -r "$appex" || true
      done
    fi
    "$LSREGISTER" -u "$app" || true
  } >> "$RUN_DIR/cleanup.log" 2>&1
}

cleanup_dev_registrations() {
  local app
  {
    cat "$DIAG_DIR/dev-registered-apps.txt"
    cat "$DIAG_DIR/dev-filesystem-apps.txt"
  } | sort -u | while IFS= read -r app; do
    [ -n "$app" ] || continue
    if is_dev_path "$app"; then
      unregister_app_registration "$app"
    fi
  done

  if [ "$RUN_CACHE_RESET" -eq 1 ]; then
    {
      printf 'reset Quick Look cache\n'
      qlmanage -r cache || true
    } >> "$RUN_DIR/cleanup.log" 2>&1
  fi
}

evaluate_provider_paths() {
  local role="$1"
  local file="$2"
  local path
  if [ ! -s "$file" ]; then
    record_warning "$role provider path was not reported by PlugInKit."
    return 0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if is_dev_path "$path"; then
      record_issue "$role provider is registered from a development artifact: $path"
    elif ! path_belongs_to_allowed_app "$path"; then
      record_issue "$role provider is registered from an unexpected app location: $path"
    fi
  done < "$file"
}

evaluate_hygiene() {
  local provider_root_count
  ISSUE_COUNT=0
  WARNING_COUNT=0
  : > "$ISSUES_FILE"
  : > "$WARNINGS_FILE"

  if [ -s "$DIAG_DIR/dev-registered-apps.txt" ]; then
    record_issue "development/test Alhangeul.app registrations remain in LaunchServices."
  fi
  if [ -s "$DIAG_DIR/dev-filesystem-apps.txt" ]; then
    record_warning "development/test Alhangeul.app bundles exist under build.noindex or DerivedData; this is only a problem if they are registered."
  fi
  if [ -s "$DIAG_DIR/legacy-apps.txt" ]; then
    record_issue "legacy RhwpMac/AlhangeulMac/알한글 app registrations remain."
  fi
  if [ -s "$DIAG_DIR/legacy-plugins.txt" ]; then
    record_issue "legacy RhwpMac/AlhangeulMac/알한글 extension registrations remain."
  fi

  evaluate_provider_paths "Quick Look preview" "$DIAG_DIR/provider-preview-paths.txt"
  evaluate_provider_paths "Thumbnail" "$DIAG_DIR/provider-thumbnail-paths.txt"

  provider_root_count="$(wc -l < "$DIAG_DIR/provider-app-roots.txt" | tr -d '[:space:]')"
  if [ "${provider_root_count:-0}" -gt 1 ]; then
    record_issue "multiple Alhangeul provider app roots are visible to PlugInKit."
  fi
}

print_file_list() {
  local label="$1"
  local file="$2"
  printf '%s\n' "$label"
  if [ -s "$file" ]; then
    sed 's/^/  - /' "$file"
  else
    printf '  - (none)\n'
  fi
}

print_summary() {
  printf 'Alhangeul extension registration hygiene\n'
  printf 'Diagnostics: %s\n\n' "$RUN_DIR"
  print_file_list "Allowed installed app locations:" "$DIAG_DIR/allowed-installed-apps.txt"
  print_file_list "Provider app roots:" "$DIAG_DIR/provider-app-roots.txt"
  print_file_list "Development registrations:" "$DIAG_DIR/dev-registered-apps.txt"
  print_file_list "Development app bundles found:" "$DIAG_DIR/dev-filesystem-apps.txt"
  print_file_list "Legacy app candidates:" "$DIAG_DIR/legacy-apps.txt"
  print_file_list "Legacy extension candidates:" "$DIAG_DIR/legacy-plugins.txt"
  print_file_list "Issues:" "$ISSUES_FILE"
  print_file_list "Warnings:" "$WARNINGS_FILE"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=1
      CLEANUP_DEV_REGISTRATIONS=0
      shift
      ;;
    --cleanup-dev-registrations)
      CHECK_ONLY=0
      CLEANUP_DEV_REGISTRATIONS=1
      shift
      ;;
    --allow-installed-app)
      [ "$#" -ge 2 ] || die "--allow-installed-app requires a path"
      ALLOWED_APPS+=("$(abs_path "$2")")
      shift 2
      ;;
    --output-dir)
      [ "$#" -ge 2 ] || die "--output-dir requires a path"
      OUTPUT_ROOT="$(abs_path "$2")"
      shift 2
      ;;
    --no-cache-reset)
      RUN_CACHE_RESET=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

require_tools
prepare_run_dir
collect_diagnostics

if [ "$CLEANUP_DEV_REGISTRATIONS" -eq 1 ]; then
  cleanup_dev_registrations
  collect_diagnostics
fi

evaluate_hygiene
print_summary

if [ "$ISSUE_COUNT" -ne 0 ]; then
  if [ "$CHECK_ONLY" -eq 1 ]; then
    printf '\nRun with --cleanup-dev-registrations to unregister development/test app registrations only.\n'
  fi
  exit 1
fi
