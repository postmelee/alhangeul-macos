#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEBUG_APP=""
RELEASE_APP=""

usage() {
  cat <<'USAGE'
Usage: verify-app-execution-endpoint-config.sh [options]

Verify that the app execution analytics endpoint is disabled by default and is
configured only for Release. Source configuration checks run on every call.

Options:
  --root PATH         Repository or fixture root (default: detected repository)
  --debug-app PATH    Also verify a built Debug .app has an empty endpoint
  --release-app PATH  Also verify a built Release .app matches project.yml
  -h, --help          Show this help
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || fail "--root requires a path"
      REPO_ROOT="$2"
      shift 2
      ;;
    --debug-app)
      [[ $# -ge 2 ]] || fail "--debug-app requires a path"
      DEBUG_APP="$2"
      shift 2
      ;;
    --release-app)
      [[ $# -ge 2 ]] || fail "--release-app requires a path"
      RELEASE_APP="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

PROJECT_FILE="$REPO_ROOT/project.yml"
SOURCE_PLIST="$REPO_ROOT/Sources/HostApp/Info.plist"

[[ -f "$PROJECT_FILE" ]] || fail "missing project configuration: $PROJECT_FILE"
[[ -f "$SOURCE_PLIST" ]] || fail "missing HostApp Info.plist: $SOURCE_PLIST"
command -v ruby >/dev/null 2>&1 || fail "ruby is required"

release_endpoint="$(ruby - "$PROJECT_FILE" "$SOURCE_PLIST" <<'RUBY'
require "psych"
require "rexml/document"
require "uri"

project_path, plist_path = ARGV
setting_name = "ALHANGEUL_APP_EXECUTION_ENDPOINT"
plist_key = "AlhangeulAppExecutionEndpoint"
placeholder = "$(#{setting_name})"

def abort_check(message)
  warn "error: #{message}"
  exit 1
end

begin
  project = Psych.safe_load(File.read(project_path), aliases: false)
rescue StandardError => error
  abort_check("cannot parse #{project_path}: #{error.message}")
end

host_settings = project.dig("targets", "HostApp", "settings")
abort_check("missing HostApp settings in project.yml") unless host_settings.is_a?(Hash)

base = host_settings["base"]
abort_check("missing HostApp base settings") unless base.is_a?(Hash)
abort_check("missing #{setting_name} in HostApp base settings") unless base.key?(setting_name)
unless base[setting_name].is_a?(String) && base[setting_name].empty?
  abort_check("HostApp base #{setting_name} must be an empty string")
end

configs = host_settings["configs"]
abort_check("missing HostApp configuration overrides") unless configs.is_a?(Hash)

unexpected_overrides = configs.each_with_object([]) do |(configuration, values), result|
  result << configuration if values.is_a?(Hash) && values.key?(setting_name) && configuration != "Release"
end
unless unexpected_overrides.empty?
  abort_check("#{setting_name} must not be overridden outside Release: #{unexpected_overrides.join(", ")}")
end

release = configs["Release"]
abort_check("missing HostApp Release settings") unless release.is_a?(Hash)
endpoint = release[setting_name]
unless endpoint.is_a?(String) && !endpoint.empty?
  abort_check("HostApp Release #{setting_name} must be a non-empty string")
end

begin
  uri = URI.parse(endpoint)
rescue URI::InvalidURIError => error
  abort_check("HostApp Release endpoint is invalid: #{error.message}")
end
unless uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty?
  abort_check("HostApp Release endpoint must be an absolute HTTPS URL")
end
if uri.userinfo || uri.query || uri.fragment
  abort_check("HostApp Release endpoint must not contain credentials, query, or fragment")
end

begin
  document = REXML::Document.new(File.read(plist_path))
rescue StandardError => error
  abort_check("cannot parse #{plist_path}: #{error.message}")
end

elements = document.elements.to_a("plist/dict/*")
value = nil
elements.each_with_index do |element, index|
  next unless element.name == "key" && element.text == plist_key

  value_element = elements[index + 1]
  value = value_element&.name == "string" ? value_element.text.to_s : nil
  break
end
unless value == placeholder
  abort_check("source plist #{plist_key} must reference #{placeholder}")
end

puts endpoint
RUBY
)"

read_built_endpoint() {
  local app_path="$1"
  local plist_path="$app_path/Contents/Info.plist"

  [[ -f "$plist_path" ]] || fail "missing built Info.plist: $plist_path"
  if command -v plutil >/dev/null 2>&1; then
    plutil -extract AlhangeulAppExecutionEndpoint raw -o - "$plist_path"
    return
  fi

  ruby - "$plist_path" <<'RUBY'
require "rexml/document"

document = REXML::Document.new(File.read(ARGV.fetch(0)))
elements = document.elements.to_a("plist/dict/*")
elements.each_with_index do |element, index|
  next unless element.name == "key" && element.text == "AlhangeulAppExecutionEndpoint"

  value_element = elements[index + 1]
  abort "endpoint value is not a string" unless value_element&.name == "string"
  print value_element.text.to_s
  exit 0
end
abort "endpoint key is missing"
RUBY
}

if [[ -n "$DEBUG_APP" ]]; then
  debug_endpoint="$(read_built_endpoint "$DEBUG_APP")"
  [[ -z "$debug_endpoint" ]] || fail "Debug built endpoint must be empty, got: $debug_endpoint"
  echo "Verified Debug built endpoint is disabled: $DEBUG_APP"
fi

if [[ -n "$RELEASE_APP" ]]; then
  built_release_endpoint="$(read_built_endpoint "$RELEASE_APP")"
  [[ "$built_release_endpoint" == "$release_endpoint" ]] || \
    fail "Release built endpoint does not match project.yml"
  echo "Verified Release built endpoint: $RELEASE_APP"
fi

echo "Verified analytics endpoint source configuration (Release only)."
