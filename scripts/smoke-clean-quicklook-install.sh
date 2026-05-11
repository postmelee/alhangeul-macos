#!/bin/bash
set -euo pipefail

VERSION="0.1.1"
APP_PATH=""
INSTALL_APP="/Applications/Alhangeul.app"
OUTPUT_ROOT="/private/tmp/alhangeul-visual-smoke"
REPLACE_APPLICATIONS_INSTALL=0
REMOVE_USER_APPLICATION_COPY=0
OPEN_FINDER=0
SKIP_PACKAGE=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_CWD="$(pwd)"
LSREGISTER=""
SMOKE_APP_PATH=""

SAMPLES=(
  "/Users/melee/Desktop/files/eq-01.hwp"
  "/Users/melee/Desktop/files/group-drawing-02.hwp"
  "$ROOT/samples/hwpx/hwpx-01.hwpx"
)

usage() {
  cat <<'USAGE'
Usage:
  scripts/smoke-clean-quicklook-install.sh [options]

Options:
  --version VERSION
      Version passed to scripts/package-release.sh. Default: 0.1.1
  --app PATH
      Existing app bundle to install. Implies --skip-package.
  --skip-package
      Reuse --app or build.noindex/release/Alhangeul.app.
  --install-app PATH
      Install target. Default: /Applications/Alhangeul.app.
      Only /Applications/Alhangeul.app and $HOME/Applications/Alhangeul.app
      are accepted.
  --replace-applications-install
      Required when --install-app is /Applications/Alhangeul.app.
  --remove-user-application-copy
      Remove $HOME/Applications/Alhangeul.app if present to avoid duplicate
      PlugInKit/LaunchServices providers.
  --output-dir PATH
      Visual smoke output root. Default: /private/tmp/alhangeul-visual-smoke
  --sample PATH
      Add a sample file. May be repeated. If used, replaces defaults.
  --open-finder
      Open the fresh sample directory in Finder after smoke setup.
  -h, --help
      Show help.

This script is for local visual smoke only. It does not create a public
release artifact and does not replace signed/notarized release validation.
USAGE
}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$ORIGINAL_CWD/$1" ;;
  esac
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required tool: $1" >&2
    exit 2
  fi
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
  local custom_samples=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --version)
        [ "$#" -ge 2 ] || { echo "ERROR: --version requires a value" >&2; exit 2; }
        VERSION="$2"
        shift 2
        ;;
      --app)
        [ "$#" -ge 2 ] || { echo "ERROR: --app requires a path" >&2; exit 2; }
        APP_PATH="$(abs_path "$2")"
        SKIP_PACKAGE=1
        shift 2
        ;;
      --skip-package)
        SKIP_PACKAGE=1
        shift
        ;;
      --install-app)
        [ "$#" -ge 2 ] || { echo "ERROR: --install-app requires a path" >&2; exit 2; }
        INSTALL_APP="$(abs_path "$2")"
        shift 2
        ;;
      --replace-applications-install)
        REPLACE_APPLICATIONS_INSTALL=1
        shift
        ;;
      --remove-user-application-copy)
        REMOVE_USER_APPLICATION_COPY=1
        shift
        ;;
      --output-dir)
        [ "$#" -ge 2 ] || { echo "ERROR: --output-dir requires a path" >&2; exit 2; }
        OUTPUT_ROOT="$(abs_path "$2")"
        shift 2
        ;;
      --sample)
        [ "$#" -ge 2 ] || { echo "ERROR: --sample requires a path" >&2; exit 2; }
        if [ "$custom_samples" -eq 0 ]; then
          SAMPLES=()
          custom_samples=1
        fi
        SAMPLES+=("$(abs_path "$2")")
        shift 2
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
        echo "ERROR: unknown option: $1" >&2
        exit 2
        ;;
    esac
  done
}

prepare_app() {
  if [ -z "$APP_PATH" ]; then
    APP_PATH="$ROOT/build.noindex/release/Alhangeul.app"
  fi

  if [ "$SKIP_PACKAGE" -eq 0 ]; then
    "$ROOT/scripts/package-release.sh" "$VERSION"
  fi

  if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: missing app bundle: $APP_PATH" >&2
    exit 10
  fi
}

verify_bundle() {
  local app="$1"
  local preview="$app/Contents/PlugIns/AlhangeulPreview.appex"
  local thumbnail="$app/Contents/PlugIns/AlhangeulThumbnail.appex"

  test -f "$app/Contents/Info.plist"
  test -d "$preview"
  test -d "$thumbnail"
  test -f "$preview/Contents/Info.plist"
  test -f "$thumbnail/Contents/Info.plist"

  local app_id preview_id thumbnail_id
  app_id="$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")"
  preview_id="$(plutil -extract CFBundleIdentifier raw -o - "$preview/Contents/Info.plist")"
  thumbnail_id="$(plutil -extract CFBundleIdentifier raw -o - "$thumbnail/Contents/Info.plist")"

  [ "$app_id" = "com.postmelee.alhangeul" ] || { echo "ERROR: unexpected app id: $app_id" >&2; exit 10; }
  [ "$preview_id" = "com.postmelee.alhangeul.QLExtension" ] || { echo "ERROR: unexpected preview id: $preview_id" >&2; exit 10; }
  [ "$thumbnail_id" = "com.postmelee.alhangeul.ThumbnailExtension" ] || { echo "ERROR: unexpected thumbnail id: $thumbnail_id" >&2; exit 10; }

  codesign --verify --deep --strict --verbose=2 "$app" >/dev/null
}

codesign_adhoc() {
  local path="$1"
  local entitlements="${2:-}"
  local args

  args=(
    --force
    --sign -
    --options runtime
    --timestamp=none
    --preserve-metadata=identifier,requirements
  )

  if [ -n "$entitlements" ]; then
    args+=(--entitlements "$entitlements")
  else
    args+=(--preserve-metadata=entitlements)
  fi

  codesign "${args[@]}" "$path"
}

expand_entitlements() {
  local source="$1"
  local bundle_id="$2"
  local output="$3"

  sed "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|$bundle_id|g" "$source" > "$output"
}

resign_smoke_app() {
  local app="$1"
  local signing_dir="$2"
  local sparkle_framework="$app/Contents/Frameworks/Sparkle.framework"
  local sparkle_version_dir="$sparkle_framework/Versions/B"
  local host_entitlements="$signing_dir/Alhangeul.entitlements"
  local preview_entitlements="$signing_dir/AlhangeulPreview.entitlements"
  local thumbnail_entitlements="$signing_dir/AlhangeulThumbnail.entitlements"
  local component

  mkdir -p "$signing_dir"

  if [ -d "$sparkle_version_dir" ]; then
    for component in \
      "$sparkle_version_dir/XPCServices/Downloader.xpc" \
      "$sparkle_version_dir/XPCServices/Installer.xpc" \
      "$sparkle_version_dir/Updater.app" \
      "$sparkle_version_dir/Autoupdate"
    do
      if [ -e "$component" ]; then
        codesign_adhoc "$component"
      fi
    done
    codesign_adhoc "$sparkle_framework"
  fi

  expand_entitlements \
    "$ROOT/Sources/QLExtension/QLExtension.entitlements" \
    "com.postmelee.alhangeul.QLExtension" \
    "$preview_entitlements"
  expand_entitlements \
    "$ROOT/Sources/ThumbnailExtension/ThumbnailExtension.entitlements" \
    "com.postmelee.alhangeul.ThumbnailExtension" \
    "$thumbnail_entitlements"
  expand_entitlements \
    "$ROOT/Sources/HostApp/HostApp.entitlements" \
    "com.postmelee.alhangeul" \
    "$host_entitlements"

  codesign_adhoc "$app/Contents/PlugIns/AlhangeulPreview.appex" "$preview_entitlements"
  codesign_adhoc "$app/Contents/PlugIns/AlhangeulThumbnail.appex" "$thumbnail_entitlements"
  codesign_adhoc "$app" "$host_entitlements"
  codesign --verify --deep --strict --verbose=2 "$app" >/dev/null
}

prepare_smoke_app_copy() {
  local run_dir="$1"
  local smoke_app="$run_dir/staging/Alhangeul.app"

  rm -rf "$run_dir/staging"
  mkdir -p "$run_dir/staging"
  ditto "$APP_PATH" "$smoke_app"
  resign_smoke_app "$smoke_app" "$run_dir/signing"
  APP_PATH="$smoke_app"
  SMOKE_APP_PATH="$smoke_app"
}

unregister_app_if_present() {
  local app="$1"
  if [ -d "$app" ]; then
    if [ -d "$app/Contents/PlugIns/AlhangeulPreview.appex" ]; then
      pluginkit -r "$app/Contents/PlugIns/AlhangeulPreview.appex" >/dev/null 2>&1 || true
    fi
    if [ -d "$app/Contents/PlugIns/AlhangeulThumbnail.appex" ]; then
      pluginkit -r "$app/Contents/PlugIns/AlhangeulThumbnail.appex" >/dev/null 2>&1 || true
    fi
    "$LSREGISTER" -u "$app" >/dev/null 2>&1 || true
  fi
}

install_app() {
  case "$INSTALL_APP" in
    "/Applications/Alhangeul.app")
      if [ "$REPLACE_APPLICATIONS_INSTALL" -ne 1 ]; then
        echo "ERROR: replacing /Applications/Alhangeul.app requires --replace-applications-install" >&2
        exit 20
      fi
      ;;
    "$HOME/Applications/Alhangeul.app")
      ;;
    *)
      echo "ERROR: refusing install target outside known app paths: $INSTALL_APP" >&2
      exit 20
      ;;
  esac

  local user_copy="$HOME/Applications/Alhangeul.app"
  if [ "$INSTALL_APP" != "$user_copy" ] && [ -d "$user_copy" ]; then
    if [ "$REMOVE_USER_APPLICATION_COPY" -ne 1 ]; then
      echo "ERROR: duplicate user app copy exists: $user_copy" >&2
      echo "Rerun with --remove-user-application-copy after confirming removal." >&2
      exit 20
    fi
    unregister_app_if_present "$user_copy"
    rm -rf "$user_copy"
  fi

  unregister_app_if_present "$INSTALL_APP"
  rm -rf "$INSTALL_APP"
  mkdir -p "$(dirname "$INSTALL_APP")"
  ditto "$APP_PATH" "$INSTALL_APP"
  xattr -dr com.apple.quarantine "$INSTALL_APP" >/dev/null 2>&1 || true
  "$LSREGISTER" -f -R -trusted "$INSTALL_APP"
  pluginkit -a "$INSTALL_APP"
  pluginkit -e use -i com.postmelee.alhangeul.QLExtension >/dev/null 2>&1 || true
  pluginkit -e use -i com.postmelee.alhangeul.ThumbnailExtension >/dev/null 2>&1 || true
}

reset_quicklook() {
  killall AlhangeulPreview >/dev/null 2>&1 || true
  killall AlhangeulThumbnail >/dev/null 2>&1 || true
  killall QuickLookUIService >/dev/null 2>&1 || true
  killall quicklookd >/dev/null 2>&1 || true
  qlmanage -r >/dev/null 2>&1 || true
  qlmanage -r cache >/dev/null 2>&1 || true
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

verify_active_provider_path() {
  local run_dir="$1"
  local expected_preview="$INSTALL_APP/Contents/PlugIns/AlhangeulPreview.appex"
  local expected_thumbnail="$INSTALL_APP/Contents/PlugIns/AlhangeulThumbnail.appex"
  local preview_log="$run_dir/pluginkit-preview.txt"
  local thumbnail_log="$run_dir/pluginkit-thumbnail.txt"

  pluginkit -mAvvv -i com.postmelee.alhangeul.QLExtension > "$preview_log"
  pluginkit -mAvvv -i com.postmelee.alhangeul.ThumbnailExtension > "$thumbnail_log"

  if ! grep -F "Path = $expected_preview" "$preview_log" >/dev/null; then
    echo "ERROR: active preview provider is not the installed app. See $preview_log" >&2
    exit 30
  fi
  if ! grep -F "Path = $expected_thumbnail" "$thumbnail_log" >/dev/null; then
    echo "ERROR: active thumbnail provider is not the installed app. See $thumbnail_log" >&2
    exit 30
  fi
}

copy_visual_samples() {
  local sample_dir="$1"
  local timestamp="$2"
  mkdir -p "$sample_dir"

  local sample base ext name index
  index=1
  for sample in "${SAMPLES[@]}"; do
    if [ ! -f "$sample" ]; then
      echo "ERROR: missing sample: $sample" >&2
      exit 2
    fi
    base="$(basename "$sample")"
    ext="${base##*.}"
    name="$(printf 'alhangeul-smoke-%02d-%s.%s' "$index" "$timestamp" "$ext")"
    ditto "$sample" "$sample_dir/$name"
    mdimport "$sample_dir/$name" >/dev/null 2>&1 || true
    index=$((index + 1))
  done
}

run_thumbnail_smoke() {
  local sample_dir="$1"
  local thumb_dir="$2"
  local log_dir="$3"
  mkdir -p "$thumb_dir" "$log_dir"

  local sample label safe_label out_dir before_stamp content_type attempt generated
  while IFS= read -r sample; do
    label="$(basename "$sample")"
    safe_label="$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')"
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

      reset_quicklook
      sleep 2
    done

    if [ "$generated" -ne 1 ]; then
      echo "ERROR: qlmanage produced no thumbnail for $sample after 3 attempts" >&2
      echo "Logs: $log_dir/$safe_label.attempt-*.qlmanage-thumbnail.log" >&2
      exit 40
    fi
  done < <(find "$sample_dir" -maxdepth 1 -type f \( -name "*.hwp" -o -name "*.hwpx" \) | sort)
}

write_visual_helpers() {
  local run_dir="$1"
  local sample_dir="$2"
  local stamp_file="$3"
  local preview_command="$run_dir/open-preview.command"
  local crash_command="$run_dir/check-crashes.command"
  local guide="$run_dir/VISUAL_CHECK.md"

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
    echo "#!/bin/bash"
    echo "set -euo pipefail"
    echo "crashes=\$(find \"$HOME/Library/Logs/DiagnosticReports\" -maxdepth 1 \\( -name 'AlhangeulPreview*.ips' -o -name 'AlhangeulThumbnail*.ips' \\) -newer \"$stamp_file\" -print 2>/dev/null || true)"
    echo "if [ -n \"\$crashes\" ]; then"
    echo "  echo \"New Alhangeul extension crash reports:\""
    echo "  echo \"\$crashes\""
    echo "  exit 1"
    echo "fi"
    echo "echo \"OK: no new AlhangeulPreview/AlhangeulThumbnail crash reports since smoke setup.\""
  } > "$crash_command"
  chmod +x "$crash_command"

  {
    echo "# Alhangeul Quick Look Visual Smoke"
    echo
    echo "- Installed app: \`$INSTALL_APP\`"
    echo "- Fresh samples: \`$sample_dir\`"
    echo "- Generated thumbnails: \`$run_dir/thumbnails\`"
    echo
    echo "## Manual Checks"
    echo
    echo "1. Open the fresh sample folder in Finder."
    echo "2. Use icon view and confirm thumbnails render as page images, not broken stripes or blank generic icons."
    echo "3. Select each sample and press Space. Single-page documents should show a large page preview, not the metadata card."
    echo "4. Run \`$preview_command\` to open Quick Look directly for all fresh samples."
    echo "5. After closing Quick Look, run \`$crash_command\`."
  } > "$guide"
}

main() {
  parse_args "$@"

  require_tool codesign
  require_tool ditto
  require_tool find
  require_tool grep
  require_tool mdimport
  require_tool plutil
  require_tool pluginkit
  require_tool qlmanage
  require_tool xattr
  LSREGISTER="$(find_lsregister)" || { echo "ERROR: missing lsregister" >&2; exit 2; }

  local timestamp run_dir sample_dir stamp_file
  timestamp="$(date +%Y%m%d-%H%M%S)"
  run_dir="$OUTPUT_ROOT/$timestamp"
  sample_dir="$run_dir/samples"
  stamp_file="$run_dir/smoke-start.stamp"
  mkdir -p "$run_dir"
  touch "$stamp_file"

  prepare_app
  verify_bundle "$APP_PATH"
  prepare_smoke_app_copy "$run_dir"
  verify_bundle "$APP_PATH"
  install_app
  reset_quicklook
  verify_active_provider_path "$run_dir"
  copy_visual_samples "$sample_dir" "$timestamp"
  run_thumbnail_smoke "$sample_dir" "$run_dir/thumbnails" "$run_dir/logs"
  write_visual_helpers "$run_dir" "$sample_dir" "$stamp_file"

  if [ "$OPEN_FINDER" -eq 1 ]; then
    open "$sample_dir"
  fi

  echo "OK: clean Quick Look visual smoke setup complete"
  echo "Installed app: $INSTALL_APP"
  echo "Fresh samples: $sample_dir"
  echo "Generated thumbnails: $run_dir/thumbnails"
  echo "Visual guide: $run_dir/VISUAL_CHECK.md"
  echo "Preview command: $run_dir/open-preview.command"
  echo "Crash check: $run_dir/check-crashes.command"
}

main "$@"
