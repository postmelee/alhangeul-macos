#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEBUG_APP=""
RELEASE_APP=""
EXPECTED_PRODUCTION_ORIGIN="https://alhangeul-install-events.postmelee.workers.dev"

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

release_endpoint="$(ruby - "$PROJECT_FILE" "$SOURCE_PLIST" "$EXPECTED_PRODUCTION_ORIGIN" <<'RUBY'
require "psych"
require "rexml/document"
require "uri"

project_path, plist_path, expected_origin_value = ARGV
setting_name = "ALHANGEUL_APP_EXECUTION_ENDPOINT"
plist_key = "AlhangeulAppExecutionEndpoint"
placeholder = "$(#{setting_name})"

def abort_check(message)
  warn "error: #{message}"
  exit 1
end

def normalized_origin(uri)
  [uri.scheme.downcase, uri.host.downcase, uri.port]
end

def origin_label(uri)
  port = uri.port == 443 ? "" : ":#{uri.port}"
  "#{uri.scheme.downcase}://#{uri.host.downcase}#{port}"
end

begin
  expected_origin = URI.parse(expected_origin_value)
rescue URI::InvalidURIError => error
  abort_check("expected production origin is invalid: #{error.message}")
end
unless expected_origin.is_a?(URI::HTTPS) && expected_origin.host && !expected_origin.host.empty?
  abort_check("expected production origin must be an absolute HTTPS origin")
end
unless expected_origin.userinfo.nil? && expected_origin.query.nil? && expected_origin.fragment.nil?
  abort_check("expected production origin must not contain credentials, query, or fragment")
end
unless expected_origin.path.nil? || expected_origin.path.empty? || expected_origin.path == "/"
  abort_check("expected production origin must not contain a path")
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
unless normalized_origin(uri) == normalized_origin(expected_origin)
  abort_check(
    "HostApp Release endpoint origin must be #{origin_label(expected_origin)}, got: #{origin_label(uri)}"
  )
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
  local endpoint_type
  local plist_path="$app_path/Contents/Info.plist"

  [[ -f "$plist_path" ]] || fail "missing built Info.plist: $plist_path"
  if command -v plutil >/dev/null 2>&1; then
    plutil -lint "$plist_path" >/dev/null 2>&1 || \
      fail "cannot parse built Info.plist: $plist_path"
    endpoint_type="$(
      plutil -type AlhangeulAppExecutionEndpoint "$plist_path" 2>/dev/null
    )" || fail "endpoint key is missing: $plist_path"
    [[ "$endpoint_type" == "string" ]] || \
      fail "endpoint value is not a string: $plist_path"
    plutil -extract AlhangeulAppExecutionEndpoint raw -expect string -o - "$plist_path"
    return
  fi

  # Xcode currently preserves the tracked XML plist because
  # INFOPLIST_OUTPUT_FORMAT is same-as-input. Keep a portable XML-only reader,
  # but never pretend that REXML can decode a binary plist without plutil.
  ruby - "$plist_path" <<'RUBY'
require "rexml/document"

def abort_check(message)
  warn "error: #{message}"
  exit 1
end

plist_path = ARGV.fetch(0)
contents = File.binread(plist_path)
if contents.start_with?("bplist")
  abort_check("plutil is required to read binary built Info.plist: #{plist_path}")
end

begin
  document = REXML::Document.new(contents)
rescue StandardError => error
  abort_check("cannot parse XML built Info.plist without plutil: #{error.message}")
end
elements = document.elements.to_a("plist/dict/*")
elements.each_with_index do |element, index|
  next unless element.name == "key" && element.text == "AlhangeulAppExecutionEndpoint"

  value_element = elements[index + 1]
  abort_check("endpoint value is not a string") unless value_element&.name == "string"
  print value_element.text.to_s
  exit 0
end
abort_check("endpoint key is missing")
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
