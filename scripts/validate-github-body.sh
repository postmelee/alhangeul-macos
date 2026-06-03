#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/validate-github-body.sh <github-body-file> [...]

Fails when a GitHub PR/Issue reference token is immediately followed by
Hangul text, such as "#328으로", "PR #328은", or "Issue #132를".
Write references as separate tokens instead, such as "#328 반영으로" or
"Issue #132 이슈를".
USAGE
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required." >&2
  exit 2
fi

if ! printf '#1가\n' | rg --pcre2 -q '#[0-9]+\p{Hangul}' >/dev/null 2>&1; then
  echo "error: rg must support --pcre2 and Unicode property matching." >&2
  exit 2
fi

for path in "$@"; do
  if [[ ! -f "$path" ]]; then
    echo "error: not a file: $path" >&2
    exit 2
  fi
done

pattern='(?:(?:PR|Issue)[[:space:]]+)?#[0-9]+\p{Hangul}'
matches_file="$(mktemp "${TMPDIR:-/tmp}/github-body-matches.XXXXXX")"
trap 'rm -f "$matches_file"' EXIT

if rg --pcre2 -n --color never "$pattern" "$@" >"$matches_file"; then
  cat >&2 <<'ERROR'
error: GitHub reference tokens must be separated from Korean particles.

Use forms like "#328 반영으로", "PR #328 반영은", or "Issue #132 이슈를".
Problem lines:
ERROR
  cat "$matches_file" >&2
  exit 1
else
  status=$?
  if [[ $status -ne 1 ]]; then
    echo "error: rg failed while checking GitHub body files." >&2
    exit "$status"
  fi
fi
