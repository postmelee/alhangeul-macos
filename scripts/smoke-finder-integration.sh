#!/bin/bash
set -euo pipefail

VERSION="0.1.2"
SKIP_PACKAGE=0
APP_PATH=""
OUTPUT_ROOT="/tmp/alhangeul-ql"
UNREGISTER_LEGACY=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_CWD="$(pwd)"
SAMPLE_HWP="$ROOT/samples/basic/KTX.hwp"
SAMPLE_HWPX="$ROOT/samples/hwpx/hwpx-01.hwpx"
INSTALL_APP="$HOME/Applications/Alhangeul.app"
RUN_DIR=""
DIAG_DIR=""
DIAGNOSTICS_COLLECTED=0
OLD_INSTALL_PATTERN='(RhwpMac|AlhangeulMac|알한글)\.app'

usage() {
  cat <<'USAGE'
Usage:
  scripts/smoke-finder-integration.sh [--version VERSION]
  scripts/smoke-finder-integration.sh --skip-package [--app PATH]

Options:
  --version VERSION       Version passed to scripts/package-release.sh. Default: 0.1.2
  --app PATH             Existing Release package staging app. Implies --skip-package.
  --skip-package         Reuse --app or build.noindex/release/Alhangeul.app.
  --output-dir PATH      Output root for qlmanage thumbnails and diagnostics.
                         Default: /tmp/alhangeul-ql
  --sample-hwp PATH      HWP sample for thumbnail smoke.
                         Default: samples/basic/KTX.hwp
  --sample-hwpx PATH     HWPX sample for thumbnail smoke.
                         Default: samples/hwpx/hwpx-01.hwpx
  --unregister-legacy-candidates
                         Unregister RhwpMac/AlhangeulMac/알한글 app and
                         appex candidates from LaunchServices/PlugInKit
                         before thumbnail smoke. This does not delete files.
  -h, --help             Show this help.

This smoke installs the app to $HOME/Applications/Alhangeul.app and only
replaces that exact path. Legacy app names are never deleted. By default,
legacy candidates fail the gate because they can make qlmanage use an older
provider and create a false positive.
USAGE
}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$ORIGINAL_CWD/$1" ;;
  esac
}

find_lsregister() {
  local candidate
  for candidate in \
    "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister" \
    "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

collect_diagnostics() {
  if [ "$DIAGNOSTICS_COLLECTED" -eq 1 ] || [ -z "${DIAG_DIR:-}" ]; then
    return 0
  fi
  DIAGNOSTICS_COLLECTED=1

  set +e
  mkdir -p "$DIAG_DIR"

  local diag_app="$INSTALL_APP"
  if [ ! -d "$diag_app" ] && [ -n "${APP_PATH:-}" ]; then
    diag_app="$APP_PATH"
  fi

  if command -v pluginkit >/dev/null 2>&1; then
    pluginkit -mAvvv > "$DIAG_DIR/pluginkit.txt" 2>&1
  fi

  if [ -n "${LSREGISTER:-}" ] && [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -dump 2>/dev/null \
      | grep -E "com\.postmelee\.alhangeul|Alhangeul\.app|AlhangeulPreview|AlhangeulThumbnail|$OLD_INSTALL_PATTERN" \
      > "$DIAG_DIR/lsregister-alhangeul.txt"
  fi

  if [ -d "$diag_app" ]; then
    codesign -dv --verbose=4 "$diag_app" > "$DIAG_DIR/codesign-app.txt" 2>&1
    codesign --verify --deep --strict --verbose=2 "$diag_app" > "$DIAG_DIR/codesign-verify.txt" 2>&1
    plutil -p "$diag_app/Contents/Info.plist" > "$DIAG_DIR/app-info.plist.txt" 2>&1
    plutil -p "$diag_app/Contents/PlugIns/AlhangeulPreview.appex/Contents/Info.plist" > "$DIAG_DIR/preview-info.plist.txt" 2>&1
    plutil -p "$diag_app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/Info.plist" > "$DIAG_DIR/thumbnail-info.plist.txt" 2>&1
  fi

  : > "$DIAG_DIR/old-install-candidates.txt"
  if command -v mdfind >/dev/null 2>&1; then
    mdfind "kMDItemContentType == 'com.apple.application-bundle'" \
      | grep -E "$OLD_INSTALL_PATTERN" >> "$DIAG_DIR/old-install-candidates.txt"
  fi
  if [ -n "${LSREGISTER:-}" ] && [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -dump 2>/dev/null \
      | grep -E "$OLD_INSTALL_PATTERN" >> "$DIAG_DIR/old-install-candidates.txt"
  fi
  list_legacy_app_paths > "$DIAG_DIR/old-install-apps.txt"
  list_legacy_plugin_paths > "$DIAG_DIR/old-install-plugins.txt"

  if command -v log >/dev/null 2>&1; then
    log show --style compact --last 10m \
      --predicate 'process == "quicklookd" OR process == "QuickLookUIService" OR process == "AlhangeulPreview" OR process == "AlhangeulThumbnail" OR eventMessage CONTAINS "com.postmelee.alhangeul."' \
      > "$DIAG_DIR/quicklook-last10m.log" 2>&1
  fi
  set -e
}

fail() {
  local code="$1"
  shift
  echo "ERROR: $*" >&2
  collect_diagnostics || true
  if [ -n "${DIAG_DIR:-}" ]; then
    echo "Diagnostics: $DIAG_DIR" >&2
  fi
  exit "$code"
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail 2 "missing required tool: $1"
  fi
}

require_file() {
  if [ ! -f "$1" ]; then
    fail "$2" "missing file: $1"
  fi
}

require_dir() {
  if [ ! -d "$1" ]; then
    fail "$2" "missing directory: $1"
  fi
}

plist_raw() {
  /usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null
}

check_plist_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local actual
  actual="$(plist_raw "$plist" "$key" || true)"
  if [ "$actual" != "$expected" ]; then
    fail 10 "plist mismatch: $plist $key expected '$expected' got '${actual:-<missing>}'"
  fi
}

check_principal_class() {
  local plist="$1"
  local expected="$2"
  local placeholder="$3"
  local actual
  actual="$(plist_raw "$plist" "NSExtension.NSExtensionPrincipalClass" || true)"
  if [ "$actual" != "$expected" ] && [ "$actual" != "$placeholder" ]; then
    fail 10 "principal class mismatch: $plist expected '$expected' got '${actual:-<missing>}'"
  fi
}

check_plist_contains() {
  local plist="$1"
  local needle="$2"
  if ! /usr/bin/plutil -p "$plist" | grep -F "$needle" >/dev/null 2>&1; then
    fail 10 "plist does not contain '$needle': $plist"
  fi
}

parse_args() {
  local positional_version_seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --version)
        [ "$#" -ge 2 ] || fail 2 "--version requires a value"
        VERSION="$2"
        shift 2
        ;;
      --app)
        [ "$#" -ge 2 ] || fail 2 "--app requires a path"
        APP_PATH="$(abs_path "$2")"
        SKIP_PACKAGE=1
        shift 2
        ;;
      --skip-package)
        SKIP_PACKAGE=1
        shift
        ;;
      --output-dir)
        [ "$#" -ge 2 ] || fail 2 "--output-dir requires a path"
        OUTPUT_ROOT="$(abs_path "$2")"
        shift 2
        ;;
      --sample-hwp)
        [ "$#" -ge 2 ] || fail 2 "--sample-hwp requires a path"
        SAMPLE_HWP="$(abs_path "$2")"
        shift 2
        ;;
      --sample-hwpx)
        [ "$#" -ge 2 ] || fail 2 "--sample-hwpx requires a path"
        SAMPLE_HWPX="$(abs_path "$2")"
        shift 2
        ;;
      --unregister-legacy-candidates)
        UNREGISTER_LEGACY=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        usage >&2
        fail 2 "unknown option: $1"
        ;;
      *)
        if [ "$positional_version_seen" -eq 1 ]; then
          usage >&2
          fail 2 "unexpected argument: $1"
        fi
        VERSION="$1"
        positional_version_seen=1
        shift
        ;;
    esac
  done
}

run_package_if_needed() {
  if [ -z "$APP_PATH" ]; then
    APP_PATH="$ROOT/build.noindex/release/Alhangeul.app"
  fi

  if [ "$SKIP_PACKAGE" -eq 0 ]; then
    echo "Packaging Release app for version $VERSION..."
    if ! (cd "$ROOT" && "$ROOT/scripts/package-release.sh" "$VERSION") > "$DIAG_DIR/package-release.log" 2>&1; then
      fail 10 "scripts/package-release.sh failed; see $DIAG_DIR/package-release.log"
    fi
  else
    echo "Skipping package generation; using app: $APP_PATH"
  fi
}

check_bundle_integrity() {
  local app="$1"
  local app_plist="$app/Contents/Info.plist"
  local preview="$app/Contents/PlugIns/AlhangeulPreview.appex"
  local thumbnail="$app/Contents/PlugIns/AlhangeulThumbnail.appex"
  local preview_plist="$preview/Contents/Info.plist"
  local thumbnail_plist="$thumbnail/Contents/Info.plist"

  require_dir "$app" 10
  require_file "$app_plist" 10
  require_file "$preview_plist" 10
  require_file "$thumbnail_plist" 10

  check_plist_value "$app_plist" "CFBundleIdentifier" "com.postmelee.alhangeul"
  check_plist_value "$preview_plist" "CFBundleIdentifier" "com.postmelee.alhangeul.QLExtension"
  check_plist_value "$thumbnail_plist" "CFBundleIdentifier" "com.postmelee.alhangeul.ThumbnailExtension"
  check_plist_value "$preview_plist" "NSExtension.NSExtensionPointIdentifier" "com.apple.quicklook.preview"
  check_plist_value "$thumbnail_plist" "NSExtension.NSExtensionPointIdentifier" "com.apple.quicklook.thumbnail"
  check_principal_class "$preview_plist" "AlhangeulPreview.HwpPreviewProvider" '$(PRODUCT_MODULE_NAME).HwpPreviewProvider'
  check_principal_class "$thumbnail_plist" "AlhangeulThumbnail.HwpThumbnailProvider" '$(PRODUCT_MODULE_NAME).HwpThumbnailProvider'

  check_plist_contains "$preview_plist" "com.postmelee.alhangeul.hwp"
  check_plist_contains "$preview_plist" "com.postmelee.alhangeul.hwpx"
  check_plist_contains "$thumbnail_plist" "com.postmelee.alhangeul.hwp"
  check_plist_contains "$thumbnail_plist" "com.postmelee.alhangeul.hwpx"
  check_plist_value "$app_plist" "LSHasLocalizedDisplayName" "true"
  check_plist_value "$preview_plist" "LSHasLocalizedDisplayName" "true"
  check_plist_value "$thumbnail_plist" "LSHasLocalizedDisplayName" "true"
  require_file "$app/Contents/Resources/ko.lproj/InfoPlist.strings" 10
  require_file "$app/Contents/Resources/en.lproj/InfoPlist.strings" 10
  require_file "$preview/Contents/Resources/ko.lproj/InfoPlist.strings" 10
  require_file "$preview/Contents/Resources/en.lproj/InfoPlist.strings" 10
  require_file "$thumbnail/Contents/Resources/ko.lproj/InfoPlist.strings" 10
  require_file "$thumbnail/Contents/Resources/en.lproj/InfoPlist.strings" 10

  if ! codesign --verify --deep --strict --verbose=2 "$app" > "$DIAG_DIR/codesign-verify-input-app.txt" 2>&1; then
    fail 10 "codesign verification failed for $app"
  fi
}

install_and_register() {
  if [ "$INSTALL_APP" != "$HOME/Applications/Alhangeul.app" ]; then
    fail 20 "refusing to install outside the standard app path: $INSTALL_APP"
  fi

  echo "NOTICE: this smoke replaces $INSTALL_APP"
  mkdir -p "$HOME/Applications" || fail 20 "failed to create $HOME/Applications"
  if [ -d "$INSTALL_APP" ]; then
    "$LSREGISTER" -u "$INSTALL_APP" >/dev/null 2>&1 || true
  fi
  rm -rf "$INSTALL_APP" || fail 20 "failed to remove existing $INSTALL_APP"
  ditto "$APP_PATH" "$INSTALL_APP" || fail 20 "failed to copy app to $INSTALL_APP"
  "$LSREGISTER" -f -R -trusted "$INSTALL_APP" || fail 20 "lsregister failed for $INSTALL_APP"
  pluginkit -a "$INSTALL_APP" || fail 20 "pluginkit add failed for $INSTALL_APP"
}

list_legacy_app_paths() {
  {
    if command -v mdfind >/dev/null 2>&1; then
      mdfind "kMDItemContentType == 'com.apple.application-bundle'" || true
    fi
    if [ -n "${LSREGISTER:-}" ] && [ -x "$LSREGISTER" ]; then
      "$LSREGISTER" -dump 2>/dev/null || true
    fi
  } | awk 'match($0, /\/[^"]*(RhwpMac|AlhangeulMac|알한글)\.app/) { print substr($0, RSTART, RLENGTH) }' \
    | sort -u
}

list_legacy_plugin_paths() {
  {
    if [ -n "${LSREGISTER:-}" ] && [ -x "$LSREGISTER" ]; then
      "$LSREGISTER" -dump 2>/dev/null || true
    fi
    list_legacy_app_paths | while IFS= read -r legacy_app; do
      if [ -d "$legacy_app/Contents/PlugIns" ]; then
        find "$legacy_app/Contents/PlugIns" -maxdepth 1 -type d -name "*.appex" 2>/dev/null || true
      fi
    done
  } | awk 'match($0, /\/[^"]*(RhwpMac|AlhangeulMac|알한글)\.app\/Contents\/PlugIns\/[^" )]+\.appex/) { print substr($0, RSTART, RLENGTH) }' \
    | sort -u
}

write_legacy_diagnostics() {
  : > "$DIAG_DIR/old-install-candidates.txt"
  if command -v mdfind >/dev/null 2>&1; then
    mdfind "kMDItemContentType == 'com.apple.application-bundle'" \
      | grep -E "$OLD_INSTALL_PATTERN" >> "$DIAG_DIR/old-install-candidates.txt" || true
  fi
  if [ -n "${LSREGISTER:-}" ] && [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -dump 2>/dev/null \
      | grep -E "$OLD_INSTALL_PATTERN" >> "$DIAG_DIR/old-install-candidates.txt" || true
  fi
  list_legacy_app_paths > "$DIAG_DIR/old-install-apps.txt"
  list_legacy_plugin_paths > "$DIAG_DIR/old-install-plugins.txt"
}

handle_legacy_install_candidates() {
  write_legacy_diagnostics

  if [ ! -s "$DIAG_DIR/old-install-apps.txt" ] && [ ! -s "$DIAG_DIR/old-install-plugins.txt" ]; then
    return 0
  fi

  if [ "$UNREGISTER_LEGACY" -eq 0 ]; then
    echo "ERROR: legacy app install candidates were found." >&2
    echo "They were not removed. See: $DIAG_DIR/old-install-candidates.txt" >&2
    fail 30 "legacy candidates can make qlmanage use an older Quick Look provider; rerun with --unregister-legacy-candidates after approval"
  fi

  echo "WARNING: unregistering legacy app install candidates for smoke isolation." >&2
  echo "Files are not deleted. See: $DIAG_DIR/old-install-candidates.txt" >&2

  : > "$DIAG_DIR/unregister-legacy.log"
  while IFS= read -r legacy_plugin; do
    [ -n "$legacy_plugin" ] || continue
    pluginkit -r "$legacy_plugin" >> "$DIAG_DIR/unregister-legacy.log" 2>&1 || true
  done < "$DIAG_DIR/old-install-plugins.txt"

  while IFS= read -r legacy_app; do
    [ -n "$legacy_app" ] || continue
    "$LSREGISTER" -u "$legacy_app" >> "$DIAG_DIR/unregister-legacy.log" 2>&1 || true
  done < "$DIAG_DIR/old-install-apps.txt"

  pluginkit -mAvvv > "$DIAG_DIR/pluginkit.txt" 2>&1 || true
  if grep -E "com\.postmelee\.alhangeulmac\.(QLExtension|ThumbnailExtension)" "$DIAG_DIR/pluginkit.txt" >/dev/null 2>&1; then
    fail 30 "legacy Quick Look extensions are still registered after unregister attempt"
  fi
}

verify_plugin_registration() {
  local attempt
  for attempt in 1 2 3 4 5; do
    pluginkit -mAvvv > "$DIAG_DIR/pluginkit.txt" 2>&1 || true
    if grep -F "com.postmelee.alhangeul.QLExtension" "$DIAG_DIR/pluginkit.txt" >/dev/null 2>&1 \
      && grep -F "com.postmelee.alhangeul.ThumbnailExtension" "$DIAG_DIR/pluginkit.txt" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  fail 30 "Preview or Thumbnail extension not found in pluginkit registration"
}

run_thumbnail_smoke() {
  local label="$1"
  local sample="$2"
  local out_dir="$3"
  local log_file="$4"

  require_file "$sample" 2
  mkdir -p "$out_dir"
  if ! qlmanage -t -x -s 512 -o "$out_dir" "$sample" > "$log_file" 2>&1; then
    fail 40 "qlmanage thumbnail smoke failed for $label sample: $sample"
  fi
  if ! find "$out_dir" -maxdepth 1 -type f | grep -q .; then
    fail 40 "qlmanage produced no thumbnail files for $label sample: $sample"
  fi
}

main() {
  parse_args "$@"

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  RUN_DIR="$OUTPUT_ROOT/task151-$timestamp"
  DIAG_DIR="$RUN_DIR/diagnostics"
  mkdir -p "$DIAG_DIR" "$RUN_DIR/hwp" "$RUN_DIR/hwpx"

  require_tool codesign
  require_tool ditto
  require_tool find
  require_tool grep
  require_tool plutil
  require_tool pluginkit
  require_tool qlmanage
  require_tool sort
  require_tool awk

  LSREGISTER="$(find_lsregister)" || fail 2 "missing lsregister"

  run_package_if_needed
  check_bundle_integrity "$APP_PATH"
  install_and_register
  handle_legacy_install_candidates
  verify_plugin_registration

  qlmanage -r > "$DIAG_DIR/qlmanage-reset.log" 2>&1 || true
  qlmanage -r cache >> "$DIAG_DIR/qlmanage-reset.log" 2>&1 || true
  run_thumbnail_smoke "HWP" "$SAMPLE_HWP" "$RUN_DIR/hwp" "$DIAG_DIR/qlmanage-hwp.log"
  run_thumbnail_smoke "HWPX" "$SAMPLE_HWPX" "$RUN_DIR/hwpx" "$DIAG_DIR/qlmanage-hwpx.log"

  collect_diagnostics || true
  echo "OK: Finder integration smoke passed"
  echo "Installed app: $INSTALL_APP"
  echo "Output: $RUN_DIR"
  echo "Diagnostics: $DIAG_DIR"
  echo "Manual preview checks:"
  echo "  qlmanage -p $SAMPLE_HWP"
  echo "  qlmanage -p $SAMPLE_HWPX"
}

main "$@"
