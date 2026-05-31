#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --updates-dir <dir> [--check]

Updates release note version notices in docs/updates.

Options:
  --updates-dir  Directory containing v<version>.html release note pages.
  --check        Check that notices are already up to date without writing.
  -h, --help     Show this help.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

UPDATES_DIR=""
CHECK=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --updates-dir)
      shift
      [ "$#" -gt 0 ] || fail "--updates-dir requires a value"
      UPDATES_DIR="$1"
      ;;
    --check)
      CHECK=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

[ -n "$UPDATES_DIR" ] || fail "--updates-dir is required"
[ -d "$UPDATES_DIR" ] || fail "--updates-dir does not exist or is not a directory: $UPDATES_DIR"

ruby - "$UPDATES_DIR" "$CHECK" <<'RUBY'
updates_dir = ARGV.fetch(0)
check_only = ARGV.fetch(1) == "1"

VersionPage = Struct.new(:path, :version, :parts, keyword_init: true)

pages = Dir.children(updates_dir).map do |entry|
  match = entry.match(/\Av(\d+)\.(\d+)\.(\d+)\.html\z/)
  next unless match

  VersionPage.new(
    path: File.join(updates_dir, entry),
    version: "#{match[1]}.#{match[2]}.#{match[3]}",
    parts: match.captures.map(&:to_i)
  )
end.compact

if pages.empty?
  warn "No release note pages found in #{updates_dir}"
  exit 0
end

latest = pages.max_by(&:parts)
latest_version = latest.version

notice_pattern = %r{\n?[ \t]*<aside class="release-version-notice" aria-label="최신 릴리즈 안내">\n.*?[ \t]*</aside>\n\n}m

def notice_for(version, latest_version)
  [
    '  <aside class="release-version-notice" aria-label="최신 릴리즈 안내">',
    '    <div class="release-version-notice-inner">',
    "      <p><strong>이 문서는 이전 버전(v#{version})의 릴리즈 노트입니다.</strong> 최신 버전 v#{latest_version}에서 수정 사항과 최신 설치 파일을 확인하세요.</p>",
    '      <div class="release-version-notice-actions">',
    "        <a class=\"notice-primary-link\" href=\"./v#{latest_version}.html\">최신 릴리즈 노트</a>",
    '        <a class="notice-secondary-link" href="https://github.com/postmelee/alhangeul-macos/releases/latest"',
    '          rel="noreferrer">GitHub 최신 릴리즈</a>',
    '      </div>',
    '    </div>',
    '  </aside>',
    '',
    ''
  ].join("\n")
end

changed = []

pages.sort_by(&:parts).each do |page|
  source = File.read(page.path)
  updated = source.gsub(notice_pattern, "\n")

  if page.version != latest_version
    notice = notice_for(page.version, latest_version)
    unless updated.sub!(/  <\/header>\n+/, "  </header>\n\n#{notice}")
      abort "ERROR: could not find header insertion point in #{page.path}"
    end
  end

  next if updated == source

  changed << page.path
  File.write(page.path, updated) unless check_only
end

if changed.empty?
  puts "Release version notices are up to date for latest v#{latest_version}."
elsif check_only
  warn "ERROR: release version notices are stale for latest v#{latest_version}:"
  changed.each { |path| warn "- #{path}" }
  exit 1
else
  puts "Updated release version notices for latest v#{latest_version}:"
  changed.each { |path| puts "- #{path}" }
end
RUBY
