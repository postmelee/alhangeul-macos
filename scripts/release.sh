#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="Alhangeul"
SCHEME_NAME="HostApp"
BUILD_APP_NAME="Alhangeul.app"
APP_NAME="Alhangeul.app"
BUILD_ROOT_INPUT="${ALHANGEUL_BUILD_ROOT:-$ROOT/build.noindex}"
OUTPUT_DIR_INPUT=""
VERSION=""
SKIP_NOTARIZE=0
KEEP_STAGING=0

DEVELOPER_ID_APPLICATION="${ALHANGEUL_DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${ALHANGEUL_NOTARY_PROFILE:-}"
DEVELOPER_ID_DMG="${ALHANGEUL_DEVELOPER_ID_DMG:-$DEVELOPER_ID_APPLICATION}"

usage() {
  cat <<EOF
Usage: $0 [options] <version>

Options:
  --skip-notarize    Build a local rehearsal DMG without notarization or staple.
  --output <dir>     Write artifacts to the given directory. Defaults to build.noindex/release.
  --keep-staging     Keep intermediate files after the script exits.
  -h, --help         Show this help.

Public release environment:
  ALHANGEUL_DEVELOPER_ID_APPLICATION   Developer ID Application signing identity.
  ALHANGEUL_NOTARY_PROFILE             notarytool keychain profile name.
  ALHANGEUL_DEVELOPER_ID_DMG           Optional DMG signing identity. Defaults to app identity.
  ALHANGEUL_BUILD_ROOT                 Optional build root. Defaults to build.noindex.

Examples:
  ALHANGEUL_DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \\
  ALHANGEUL_NOTARY_PROFILE="alhangeul-notary" \\
  $0 0.1.1

  $0 --skip-notarize 0.1.1
EOF
}

info() {
  echo "INFO: $*"
}

warn() {
  echo "WARN: $*" >&2
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

resolve_path() {
  local path="$1"
  case "$path" in
    /*)
      echo "$path"
      ;;
    *)
      echo "$ROOT/$path"
      ;;
  esac
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    fail "required tool not found: $tool"
  fi
}

require_xcrun_tool() {
  local tool="$1"
  if ! xcrun --find "$tool" >/dev/null 2>&1; then
    fail "required Xcode tool not found: $tool"
  fi
}

require_signing_identity() {
  local identity="$1"
  if ! security find-identity -v -p codesigning | grep -F -- "$identity" >/dev/null 2>&1; then
    fail "signing identity not found in keychain: $identity"
  fi
}

require_clean_worktree() {
  local status
  status="$(git -C "$ROOT" status --porcelain)"
  if [ -n "$status" ]; then
    fail "working tree must be clean for public release"
  fi
}

version_from_plist() {
  local plist="$1"
  plutil -extract CFBundleShortVersionString raw -o - "$plist"
}

validate_source_versions() {
  local plist
  local plist_version
  local relative_plist
  for plist in \
    "$ROOT/Sources/HostApp/Info.plist" \
    "$ROOT/Sources/QLExtension/Info.plist" \
    "$ROOT/Sources/ThumbnailExtension/Info.plist"
  do
    plist_version="$(version_from_plist "$plist")"
    if [ "$plist_version" != "$VERSION" ]; then
      relative_plist="${plist#"$ROOT"/}"
      fail "input version $VERSION does not match CFBundleShortVersionString $plist_version in $relative_plist"
    fi
  done
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --skip-notarize)
        SKIP_NOTARIZE=1
        ;;
      --output)
        shift
        if [ "$#" -eq 0 ]; then
          fail "--output requires a directory"
        fi
        OUTPUT_DIR_INPUT="$1"
        ;;
      --keep-staging)
        KEEP_STAGING=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        fail "unknown option: $1"
        ;;
      *)
        if [ -n "$VERSION" ]; then
          fail "unexpected argument: $1"
        fi
        VERSION="$1"
        ;;
    esac
    shift
  done

  if [ -z "$VERSION" ]; then
    usage >&2
    exit 1
  fi

  if ! [[ "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
    fail "version must look like semantic version, got: $VERSION"
  fi
}

prepare_paths() {
  BUILD_ROOT="$(resolve_path "$BUILD_ROOT_INPUT")"
  if [ -z "$OUTPUT_DIR_INPUT" ]; then
    OUTPUT_DIR_INPUT="$BUILD_ROOT/release"
  fi
  OUTPUT_DIR="$(resolve_path "$OUTPUT_DIR_INPUT")"

  mkdir -p "$BUILD_ROOT" "$OUTPUT_DIR"
  touch "$BUILD_ROOT/.metadata_never_index"

  BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
  OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"

  case "$OUTPUT_DIR" in
    "$BUILD_ROOT"|"$BUILD_ROOT"/*)
      ;;
    *)
      fail "output directory must be under $BUILD_ROOT"
      ;;
  esac

  STAGING_DIR="$OUTPUT_DIR/staging"
  XCODE_BUILD_DIR="$STAGING_DIR/xcodebuild"
  DERIVED_DATA_DIR="$STAGING_DIR/DerivedData"
  SWIFT_MODULE_CACHE_DIR="$STAGING_DIR/SwiftModuleCache"
  DMG_STAGING_DIR="$STAGING_DIR/dmg-root"
  DMG_MOUNT_DIR="$STAGING_DIR/dmg-mount"
  DMG_BACKGROUND_DIR="$DMG_STAGING_DIR/.background"
  DMG_BACKGROUND_IMAGE="$DMG_BACKGROUND_DIR/alhangeul-dmg-background.png"
  APP_OUTPUT="$OUTPUT_DIR/$APP_NAME"
  APP_NOTARY_ZIP="$STAGING_DIR/alhangeul-macos-$VERSION-app-notary.zip"
  DMG_RW_OUTPUT="$STAGING_DIR/alhangeul-macos-$VERSION-layout.dmg"

  if [ "$SKIP_NOTARIZE" -eq 1 ]; then
    DMG_NAME="alhangeul-macos-$VERSION-rehearsal.dmg"
  else
    DMG_NAME="alhangeul-macos-$VERSION.dmg"
  fi
  DMG_OUTPUT="$OUTPUT_DIR/$DMG_NAME"
  CHECKSUM_OUTPUT="$OUTPUT_DIR/$DMG_NAME.sha256"
}

cleanup() {
  if [ -n "${DMG_DEVICE:-}" ]; then
    hdiutil detach "$DMG_DEVICE" -quiet >/dev/null 2>&1 || true
    DMG_DEVICE=""
  fi
  if [ "${KEEP_STAGING:-0}" -eq 0 ] && [ -n "${STAGING_DIR:-}" ]; then
    rm -rf "$STAGING_DIR"
  fi
}

run_preflight() {
  local required_tools
  required_tools=(
    git
    xcodegen
    xcodebuild
    xcrun
    ditto
    hdiutil
    osascript
    codesign
    spctl
    shasum
    plutil
    security
    swift
  )

  local tool
  for tool in "${required_tools[@]}"; do
    require_tool "$tool"
  done

  if [ "$SKIP_NOTARIZE" -eq 0 ]; then
    if [ -z "$DEVELOPER_ID_APPLICATION" ]; then
      fail "ALHANGEUL_DEVELOPER_ID_APPLICATION is required for public release"
    fi
    if [ -z "$NOTARY_PROFILE" ]; then
      fail "ALHANGEUL_NOTARY_PROFILE is required for public release"
    fi
    require_xcrun_tool notarytool
    require_xcrun_tool stapler
    require_signing_identity "$DEVELOPER_ID_APPLICATION"
    require_signing_identity "$DEVELOPER_ID_DMG"
    require_clean_worktree
  else
    warn "Apple notarization is skipped. This rehearsal artifact is not a public release."
    if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
      require_signing_identity "$DEVELOPER_ID_APPLICATION"
      require_signing_identity "$DEVELOPER_ID_DMG"
    fi
  fi

  validate_source_versions
}

reset_output() {
  rm -rf "$STAGING_DIR"
  rm -rf "$APP_OUTPUT" "$APP_OUTPUT.dSYM"
  rm -f "$DMG_OUTPUT" "$CHECKSUM_OUTPUT"
  rm -f "$APP_NOTARY_ZIP"
  rm -f "$DMG_RW_OUTPUT"
  mkdir -p "$STAGING_DIR" "$XCODE_BUILD_DIR" "$DERIVED_DATA_DIR" "$SWIFT_MODULE_CACHE_DIR" "$DMG_STAGING_DIR" "$DMG_MOUNT_DIR"
}

build_rust_bridge() {
  info "Verifying Rust bridge artifacts"
  "$ROOT/scripts/build-rust-macos.sh" --verify-lock
}

generate_project() {
  info "Generating Xcode project"
  (cd "$ROOT" && xcodegen generate)
}

check_shared_code() {
  info "Checking shared Swift code boundaries"
  "$ROOT/scripts/check-no-appkit.sh"
}

build_app() {
  info "Building Release app"
  if [ -n "$DEVELOPER_ID_APPLICATION" ]; then
    xcodebuild -project "$ROOT/$PROJECT_NAME.xcodeproj" \
      -scheme "$SCHEME_NAME" \
      -configuration Release \
      -destination "generic/platform=macOS" \
      -derivedDataPath "$DERIVED_DATA_DIR" \
      CONFIGURATION_BUILD_DIR="$XCODE_BUILD_DIR" \
      ARCHS="arm64 x86_64" \
      ONLY_ACTIVE_ARCH=NO \
      CODE_SIGN_STYLE=Manual \
      CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
      ENABLE_HARDENED_RUNTIME=YES \
      build
  else
    xcodebuild -project "$ROOT/$PROJECT_NAME.xcodeproj" \
      -scheme "$SCHEME_NAME" \
      -configuration Release \
      -destination "generic/platform=macOS" \
      -derivedDataPath "$DERIVED_DATA_DIR" \
      CONFIGURATION_BUILD_DIR="$XCODE_BUILD_DIR" \
      ARCHS="arm64 x86_64" \
      ONLY_ACTIVE_ARCH=NO \
      CODE_SIGNING_ALLOWED=NO \
      build
  fi

  if [ ! -d "$XCODE_BUILD_DIR/$BUILD_APP_NAME" ]; then
    fail "missing app bundle: $XCODE_BUILD_DIR/$BUILD_APP_NAME"
  fi

  # Keep the filesystem bundle name ASCII. Localized user-facing names are
  # provided by Info.plist; a non-ASCII .app path can break ExtensionKit lookup.
  ditto "$XCODE_BUILD_DIR/$BUILD_APP_NAME" "$APP_OUTPUT"
}

verify_universal_app() {
  info "Verifying universal app architectures"
  "$ROOT/scripts/ci/verify-universal-macos-app.sh" "$APP_OUTPUT"
}

verify_app_signature() {
  if [ -z "$DEVELOPER_ID_APPLICATION" ]; then
    warn "Skipping codesign verification because this rehearsal build is unsigned."
    return
  fi

  info "Verifying app code signature"
  codesign --verify --deep --strict --verbose=2 "$APP_OUTPUT"
  codesign --display --verbose=4 "$APP_OUTPUT" >/dev/null

  if [ -d "$APP_OUTPUT/Contents/PlugIns" ]; then
    while IFS= read -r appex; do
      codesign --verify --strict --verbose=2 "$appex"
    done < <(find "$APP_OUTPUT/Contents/PlugIns" -maxdepth 1 -type d -name "*.appex" -print)
  fi
}

notarize_and_staple_app() {
  if [ "$SKIP_NOTARIZE" -eq 1 ]; then
    return
  fi

  info "Submitting app bundle for notarization"
  ditto -c -k --keepParent "$APP_OUTPUT" "$APP_NOTARY_ZIP"
  xcrun notarytool submit "$APP_NOTARY_ZIP" \
    --wait \
    --keychain-profile "$NOTARY_PROFILE"

  info "Stapling app bundle"
  xcrun stapler staple "$APP_OUTPUT"
}

prepare_dmg_staging() {
  rm -rf "$DMG_STAGING_DIR"
  mkdir -p "$DMG_STAGING_DIR" "$DMG_BACKGROUND_DIR"
  ditto "$APP_OUTPUT" "$DMG_STAGING_DIR/$APP_NAME"
  ln -s /Applications "$DMG_STAGING_DIR/Applications"
  swift -module-cache-path "$SWIFT_MODULE_CACHE_DIR" \
    "$ROOT/scripts/create-dmg-background.swift" \
    "$DMG_BACKGROUND_IMAGE"
}

apply_dmg_finder_layout() {
  local mounted_volume="$1"

  osascript - "$mounted_volume" "$APP_NAME" <<'APPLESCRIPT'
on run argv
  set volumePath to item 1 of argv
  set appName to item 2 of argv
  set backgroundPath to volumePath & "/.background/alhangeul-dmg-background.png"

  tell application "Finder"
    set volumeFolder to POSIX file volumePath as alias
    set backgroundImage to POSIX file backgroundPath as alias
    open volumeFolder

    set volumeWindow to container window of volumeFolder
    set current view of volumeWindow to icon view
    set toolbar visible of volumeWindow to false
    set statusbar visible of volumeWindow to false
    set bounds of volumeWindow to {120, 120, 840, 680}

    set viewOptions to icon view options of volumeWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to backgroundImage

    set position of item appName of volumeFolder to {178, 268}
    set position of item "Applications" of volumeFolder to {542, 268}

    update volumeFolder without registering applications
    delay 2
    close volumeWindow
  end tell
end run
APPLESCRIPT
}

create_dmg() {
  info "Creating DMG"
  prepare_dmg_staging

  hdiutil create \
    -volname "Alhangeul $VERSION" \
    -srcfolder "$DMG_STAGING_DIR" \
    -format UDRW \
    -fs HFS+ \
    -ov \
    "$DMG_RW_OUTPUT"

  rm -rf "$DMG_MOUNT_DIR"
  mkdir -p "$DMG_MOUNT_DIR"
  DMG_DEVICE="$(hdiutil attach "$DMG_RW_OUTPUT" \
    -mountpoint "$DMG_MOUNT_DIR" \
    -readwrite \
    -noverify \
    -noautoopen \
    -nobrowse | awk 'END {print $1}')"

  apply_dmg_finder_layout "$DMG_MOUNT_DIR"
  sync
  hdiutil detach "$DMG_DEVICE" -quiet
  DMG_DEVICE=""

  hdiutil convert "$DMG_RW_OUTPUT" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_OUTPUT"
}

sign_dmg() {
  if [ -z "$DEVELOPER_ID_DMG" ]; then
    warn "Skipping DMG signing because this rehearsal build is unsigned."
    return
  fi

  info "Signing DMG"
  codesign --force --sign "$DEVELOPER_ID_DMG" "$DMG_OUTPUT"
  codesign --verify --verbose=2 "$DMG_OUTPUT"
}

notarize_and_staple_dmg() {
  if [ "$SKIP_NOTARIZE" -eq 1 ]; then
    return
  fi

  info "Submitting DMG for notarization"
  xcrun notarytool submit "$DMG_OUTPUT" \
    --wait \
    --keychain-profile "$NOTARY_PROFILE"

  info "Stapling DMG"
  xcrun stapler staple "$DMG_OUTPUT"
}

verify_release_artifacts() {
  if [ "$SKIP_NOTARIZE" -eq 1 ]; then
    info "Verifying rehearsal DMG"
    hdiutil verify "$DMG_OUTPUT"
    return
  fi

  info "Running Gatekeeper assessments"
  spctl --assess --type execute --verbose "$APP_OUTPUT"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG_OUTPUT"
}

write_checksum() {
  info "Writing sha256 checksum"
  (
    cd "$OUTPUT_DIR"
    shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
  )
}

main() {
  parse_args "$@"
  prepare_paths
  trap cleanup EXIT
  run_preflight
  reset_output
  build_rust_bridge
  check_shared_code
  generate_project
  build_app
  verify_universal_app
  verify_app_signature
  notarize_and_staple_app
  create_dmg
  sign_dmg
  notarize_and_staple_dmg
  verify_release_artifacts
  write_checksum

  info "Release artifact: $DMG_OUTPUT"
  info "Checksum: $CHECKSUM_OUTPUT"
  if [ "$SKIP_NOTARIZE" -eq 1 ]; then
    warn "Rehearsal artifact complete. Do not use it for public release or Homebrew Cask."
  fi
}

main "$@"
