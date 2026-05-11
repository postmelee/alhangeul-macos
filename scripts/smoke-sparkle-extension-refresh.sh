#!/bin/bash
set -euo pipefail

EXPECTED_VERSION=""
EXPECTED_BUILD=""
INSTALL_APP="/Applications/Alhangeul.app"
OUTPUT_ROOT="/private/tmp/alhangeul-sparkle-extension-refresh"
REPAIR_REGISTRATION=0
OPEN_FINDER=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_CWD="$(pwd)"
LSREGISTER=""
RUN_DIR=""
DIAG_DIR=""
SAMPLE_HWP="$ROOT/samples/basic/KTX.hwp"
SAMPLE_HWPX="$ROOT/samples/hwpx/hwpx-01.hwpx"

usage() {
  cat <<'USAGE'
Usage:
  scripts/smoke-sparkle-extension-refresh.sh --expected-version VERSION --expected-build BUILD [options]

Options:
  --expected-version VERSION
      Expected CFBundleShortVersionString after Sparkle update.
  --expected-build BUILD
      Expected CFBundleVersion after Sparkle update.
  --app PATH
      Updated installed app path. Default: /Applications/Alhangeul.app.
  --output-dir PATH
      Output root for diagnostics and thumbnail smoke. Default:
      /private/tmp/alhangeul-sparkle-extension-refresh
  --sample-hwp PATH
      HWP sample for thumbnail smoke. Default: samples/basic/KTX.hwp.
  --sample-hwpx PATH
      HWPX sample for thumbnail smoke. Default: samples/hwpx/hwpx-01.hwpx.
  --repair-registration
      Triage mode only: run lsregister/pluginkit registration repair before
      provider verification. Do not use this option as the release gate.
  --open-finder
      Open the fresh sample directory in Finder after setup.
  -h, --help
      Show help.

This helper is intended to run after a real Sparkle update has completed.
The default mode validates the natural post-update state without manually
registering the app again. If default mode fails but --repair-registration
passes, the release should be treated as having an extension refresh problem.
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

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --expected-version)
        [ "$#" -ge 2 ] || fail_early "--expected-version requires a value"
        EXPECTED_VERSION="$2"
        shift 2
        ;;
      --expected-build)
        [ "$#" -ge 2 ] || fail_early "--expected-build requires a value"
        EXPECTED_BUILD="$2"
        shift 2
        ;;
      --app)
        [ "$#" -ge 2 ] || fail_early "--app requires a path"
        INSTALL_APP="$(abs_path "$2")"
        shift 2
        ;;
      --output-dir)
        [ "$#" -ge 2 ] || fail_early "--output-dir requires a path"
        OUTPUT_ROOT="$(abs_path "$2")"
        shift 2
        ;;
      --sample-hwp)
        [ "$#" -ge 2 ] || fail_early "--sample-hwp requires a path"
        SAMPLE_HWP="$(abs_path "$2")"
        shift 2
        ;;
      --sample-hwpx)
        [ "$#" -ge 2 ] || fail_early "--sample-hwpx requires a path"
        SAMPLE_HWPX="$(abs_path "$2")"
        shift 2
        ;;
      --repair-registration)
        REPAIR_REGISTRATION=1
        shift
        ;;
      --open-finder)
        OPEN_FINDER=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        fail_early "unknown option: $1"
        ;;
    esac
  done
}

fail_early() {
  echo "ERROR: $*" >&2
  exit 2
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

collect_diagnostics() {
  [ -n "${DIAG_DIR:-}" ] || return 0
  mkdir -p "$DIAG_DIR"

  set +e
  pluginkit -mAvvv > "$DIAG_DIR/pluginkit-all.txt" 2>&1
  pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension > "$DIAG_DIR/pluginkit-preview.txt" 2>&1
  pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension > "$DIAG_DIR/pluginkit-thumbnail.txt" 2>&1

  if [ -n "${LSREGISTER:-}" ] && [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -dump 2>/dev/null \
      | grep -E "com\.postmelee\.(alhangeul|alhangeulmac|rhwpmac)|Alhangeul|알한글|RhwpMac|AlhangeulMac" \
      > "$DIAG_DIR/lsregister-alhangeul.txt"
  fi

  if [ -d "$INSTALL_APP" ]; then
    codesign --verify --deep --strict --verbose=2 "$INSTALL_APP" > "$DIAG_DIR/codesign-verify.txt" 2>&1
    plutil -p "$INSTALL_APP/Contents/Info.plist" > "$DIAG_DIR/app-info.plist.txt" 2>&1
    plutil -p "$INSTALL_APP/Contents/PlugIns/AlhangeulPreview.appex/Contents/Info.plist" > "$DIAG_DIR/preview-info.plist.txt" 2>&1
    plutil -p "$INSTALL_APP/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/Info.plist" > "$DIAG_DIR/thumbnail-info.plist.txt" 2>&1
  fi

  log show --style compact --last 10m \
    --predicate 'process == "quicklookd" OR process == "thumbnaild" OR process == "QuickLookUIService" OR process == "AlhangeulPreview" OR process == "AlhangeulThumbnail" OR eventMessage CONTAINS "com.postmelee.alhangeul."' \
    > "$DIAG_DIR/quicklook-last10m.log" 2>&1
  set -e
}

verify_expected_inputs() {
  [ -n "$EXPECTED_VERSION" ] || fail_early "--expected-version is required"
  [ -n "$EXPECTED_BUILD" ] || fail_early "--expected-build is required"
  require_dir "$INSTALL_APP" 10
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

verify_updated_bundle() {
  local app_plist="$INSTALL_APP/Contents/Info.plist"
  local preview="$INSTALL_APP/Contents/PlugIns/AlhangeulPreview.appex"
  local thumbnail="$INSTALL_APP/Contents/PlugIns/AlhangeulThumbnail.appex"
  local preview_plist="$preview/Contents/Info.plist"
  local thumbnail_plist="$thumbnail/Contents/Info.plist"

  require_file "$app_plist" 10
  require_file "$preview_plist" 10
  require_file "$thumbnail_plist" 10

  check_plist_value "$app_plist" "CFBundleIdentifier" "com.postmelee.alhangeul"
  check_plist_value "$preview_plist" "CFBundleIdentifier" "com.postmelee.alhangeul.QLExtension"
  check_plist_value "$thumbnail_plist" "CFBundleIdentifier" "com.postmelee.alhangeul.ThumbnailExtension"

  check_plist_value "$app_plist" "CFBundleShortVersionString" "$EXPECTED_VERSION"
  check_plist_value "$preview_plist" "CFBundleShortVersionString" "$EXPECTED_VERSION"
  check_plist_value "$thumbnail_plist" "CFBundleShortVersionString" "$EXPECTED_VERSION"

  check_plist_value "$app_plist" "CFBundleVersion" "$EXPECTED_BUILD"
  check_plist_value "$preview_plist" "CFBundleVersion" "$EXPECTED_BUILD"
  check_plist_value "$thumbnail_plist" "CFBundleVersion" "$EXPECTED_BUILD"

  if ! codesign --verify --deep --strict --verbose=2 "$INSTALL_APP" > "$DIAG_DIR/codesign-verify-input-app.txt" 2>&1; then
    fail 10 "codesign verification failed for $INSTALL_APP"
  fi
}

repair_registration_if_requested() {
  if [ "$REPAIR_REGISTRATION" -ne 1 ]; then
    return 0
  fi

  echo "WARNING: repairing LaunchServices/PlugInKit registration before verification."
  echo "WARNING: do not count this as the release gate; use it only to diagnose stale registration."
  "$LSREGISTER" -f -R -trusted "$INSTALL_APP"
  pluginkit -a "$INSTALL_APP"
  pluginkit -e use -i com.postmelee.alhangeul.QLExtension >/dev/null 2>&1 || true
  pluginkit -e use -i com.postmelee.alhangeul.ThumbnailExtension >/dev/null 2>&1 || true
}

verify_active_provider() {
  local id="$1"
  local expected_path="$2"
  local log_file="$3"

  if ! pluginkit -mAvvv -i "$id" > "$log_file" 2>&1; then
    fail 30 "pluginkit query failed for $id"
  fi

  if grep -F "$id" "$log_file" | grep -E "^[[:space:]]*-" >/dev/null; then
    fail 30 "provider is registered but disabled: $id"
  fi

  if ! grep -F "Path = $expected_path" "$log_file" >/dev/null; then
    fail 30 "active provider for $id is not the updated app path: $expected_path"
  fi
}

verify_no_legacy_provider() {
  local log_file="$DIAG_DIR/pluginkit-all-before-cache-reset.txt"
  pluginkit -mAvvv > "$log_file" 2>&1 || fail 30 "pluginkit full query failed"

  if grep -E "com\.postmelee\.(alhangeulmac|rhwpmac)\.(QLExtension|ThumbnailExtension)" "$log_file" >/dev/null; then
    fail 30 "legacy Alhangeul/RhwpMac provider is still registered"
  fi
}

verify_provider_paths() {
  verify_no_legacy_provider
  verify_active_provider \
    "com.postmelee.alhangeul.QLExtension" \
    "$INSTALL_APP/Contents/PlugIns/AlhangeulPreview.appex" \
    "$DIAG_DIR/pluginkit-preview-before-cache-reset.txt"
  verify_active_provider \
    "com.postmelee.alhangeul.ThumbnailExtension" \
    "$INSTALL_APP/Contents/PlugIns/AlhangeulThumbnail.appex" \
    "$DIAG_DIR/pluginkit-thumbnail-before-cache-reset.txt"
}

reset_quicklook_for_new_request() {
  killall AlhangeulPreview >/dev/null 2>&1 || true
  killall AlhangeulThumbnail >/dev/null 2>&1 || true
  killall QuickLookUIService >/dev/null 2>&1 || true
  killall quicklookd >/dev/null 2>&1 || true
  killall thumbnaild >/dev/null 2>&1 || true
  qlmanage -r > "$DIAG_DIR/qlmanage-reset.log" 2>&1 || true
  qlmanage -r cache >> "$DIAG_DIR/qlmanage-reset.log" 2>&1 || true
}

copy_samples() {
  local sample_dir="$1"
  local timestamp="$2"
  mkdir -p "$sample_dir"

  local sample base ext target index
  index=1
  for sample in "$SAMPLE_HWP" "$SAMPLE_HWPX"; do
    require_file "$sample" 2
    base="$(basename "$sample")"
    ext="${base##*.}"
    target="$sample_dir/alhangeul-sparkle-refresh-$index-$timestamp.$ext"
    ditto "$sample" "$target"
    mdimport "$target" >/dev/null 2>&1 || true
    index=$((index + 1))
  done
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift
  local pid elapsed

  "$@" &
  pid="$!"
  elapsed=0

  while kill -0 "$pid" >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$pid"
}

run_thumbnail_smoke() {
  local sample_dir="$1"
  local thumb_dir="$2"
  local log_dir="$3"
  mkdir -p "$thumb_dir" "$log_dir"

  local sample safe_label out_dir before_stamp content_type attempt generated
  while IFS= read -r sample; do
    safe_label="$(basename "$sample" | tr -c 'A-Za-z0-9._-' '_')"
    out_dir="$thumb_dir/$safe_label"
    mkdir -p "$out_dir"

    case "$sample" in
      *.hwp) content_type="com.postmelee.alhangeul.hwp" ;;
      *.hwpx) content_type="com.postmelee.alhangeul.hwpx" ;;
      *) content_type="" ;;
    esac

    generated=0
    for attempt in 1 2 3; do
      before_stamp="$log_dir/$safe_label.attempt-$attempt.before"
      touch "$before_stamp"
      if [ -n "$content_type" ]; then
        run_with_timeout 45 qlmanage -t -x -s 768 -c "$content_type" -o "$out_dir" "$sample" > "$log_dir/$safe_label.attempt-$attempt.qlmanage-thumbnail.log" 2>&1 || true
      else
        run_with_timeout 45 qlmanage -t -x -s 768 -o "$out_dir" "$sample" > "$log_dir/$safe_label.attempt-$attempt.qlmanage-thumbnail.log" 2>&1 || true
      fi

      if find "$out_dir" -maxdepth 1 -type f -newer "$before_stamp" | grep -q .; then
        generated=1
        break
      fi

      reset_quicklook_for_new_request
      sleep 2
    done

    if [ "$generated" -ne 1 ]; then
      fail 40 "qlmanage produced no thumbnail for $sample after 3 attempts"
    fi
  done < <(find "$sample_dir" -maxdepth 1 -type f \( -name "*.hwp" -o -name "*.hwpx" \) | sort)
}

write_preview_helper() {
  local sample_dir="$1"
  local preview_command="$RUN_DIR/open-preview.command"
  local guide="$RUN_DIR/POST_SPARKLE_EXTENSION_REFRESH.md"

  {
    echo "#!/bin/bash"
    echo "set -euo pipefail"
    echo "while IFS= read -r sample; do"
    echo "  case \"\$sample\" in"
    echo "    *.hwp) content_type=\"com.postmelee.alhangeul.hwp\" ;;"
    echo "    *.hwpx) content_type=\"com.postmelee.alhangeul.hwpx\" ;;"
    echo "    *) content_type=\"\" ;;"
    echo "  esac"
    echo "  if [ -n \"\$content_type\" ]; then"
    echo "    qlmanage -p -x -c \"\$content_type\" \"\$sample\" >/dev/null 2>&1"
    echo "  else"
    echo "    qlmanage -p -x \"\$sample\" >/dev/null 2>&1"
    echo "  fi"
    echo "done <<'SAMPLES'"
    find "$sample_dir" -maxdepth 1 -type f \( -name "*.hwp" -o -name "*.hwpx" \) | sort
    echo "SAMPLES"
  } > "$preview_command"
  chmod +x "$preview_command"

  {
    echo "# Post-Sparkle Extension Refresh Smoke"
    echo
    echo "- Installed app: \`$INSTALL_APP\`"
    echo "- Expected version: \`$EXPECTED_VERSION ($EXPECTED_BUILD)\`"
    echo "- Registration repair used: \`$REPAIR_REGISTRATION\`"
    echo "- Fresh samples: \`$sample_dir\`"
    echo "- Thumbnail output: \`$RUN_DIR/thumbnails\`"
    echo "- Diagnostics: \`$DIAG_DIR\`"
    echo
    echo "## Manual Preview Check"
    echo
    echo "Run:"
    echo
    echo "\`\`\`bash"
    echo "$preview_command"
    echo "\`\`\`"
  } > "$guide"
}

main() {
  parse_args "$@"
  verify_expected_inputs

  require_tool codesign
  require_tool ditto
  require_tool find
  require_tool grep
  require_tool mdimport
  require_tool plutil
  require_tool pluginkit
  require_tool qlmanage
  require_tool sort
  require_tool tr
  LSREGISTER="$(find_lsregister)" || fail 2 "missing lsregister"

  local timestamp sample_dir
  timestamp="$(date +%Y%m%d-%H%M%S)"
  RUN_DIR="$OUTPUT_ROOT/$timestamp"
  DIAG_DIR="$RUN_DIR/diagnostics"
  sample_dir="$RUN_DIR/samples"
  mkdir -p "$DIAG_DIR" "$sample_dir"

  verify_updated_bundle
  repair_registration_if_requested
  verify_provider_paths
  reset_quicklook_for_new_request
  copy_samples "$sample_dir" "$timestamp"
  run_thumbnail_smoke "$sample_dir" "$RUN_DIR/thumbnails" "$RUN_DIR/logs"
  collect_diagnostics || true
  write_preview_helper "$sample_dir"

  if [ "$OPEN_FINDER" -eq 1 ]; then
    open "$sample_dir"
  fi

  echo "OK: post-Sparkle extension refresh smoke passed"
  echo "Installed app: $INSTALL_APP"
  echo "Expected: $EXPECTED_VERSION ($EXPECTED_BUILD)"
  echo "Registration repair used: $REPAIR_REGISTRATION"
  echo "Output: $RUN_DIR"
  echo "Diagnostics: $DIAG_DIR"
  echo "Preview command: $RUN_DIR/open-preview.command"
}

main "$@"
