#!/bin/bash
set -euo pipefail

OUTPUT_FILE=""
CURRENT_TAG=""
CURRENT_COMMIT=""
TARGET_TAG=""
TARGET_COMMIT=""
TARGET_URL=""
BASE_BRANCH="devel"
MENTION="@postmelee"
CHANGED_PATHS_FILE=""
IMPACT_DETAILS_FILE=""
REPOSITORY_CHANGED_PATHS_FILE=""
VERIFICATION_FILE=""

usage() {
  cat >&2 <<EOF
Usage: $0 --output FILE --current-tag TAG --current-commit COMMIT --target-tag TAG --target-commit COMMIT [options]

Options:
  --output FILE                         PR body output file.
  --current-tag TAG                     Previously bundled rhwp-studio release tag.
  --current-commit COMMIT               Previously bundled rhwp-studio commit.
  --target-tag TAG                      Target upstream rhwp release tag.
  --target-commit COMMIT                Target upstream rhwp commit.
  --target-url URL                      Upstream release URL.
  --base-branch BRANCH                  PR base branch. Defaults to devel.
  --mention USER_OR_TEAM                Maintainer mention. Defaults to @postmelee.
  --changed-paths-file FILE             Upstream current..target changed paths.
  --impact-details-file FILE            TSV of impact paths and reasons.
  --repository-changed-paths-file FILE   Repository changed paths after sync.
  --verification-file FILE              Verification command/result lines.
  -h, --help                            Show this help.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_value() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    fail "missing required option: $name"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --output)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --output"
        fi
        OUTPUT_FILE="$2"
        shift
        ;;
      --current-tag)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --current-tag"
        fi
        CURRENT_TAG="$2"
        shift
        ;;
      --current-commit)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --current-commit"
        fi
        CURRENT_COMMIT="$2"
        shift
        ;;
      --target-tag)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --target-tag"
        fi
        TARGET_TAG="$2"
        shift
        ;;
      --target-commit)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --target-commit"
        fi
        TARGET_COMMIT="$2"
        shift
        ;;
      --target-url)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --target-url"
        fi
        TARGET_URL="$2"
        shift
        ;;
      --base-branch)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --base-branch"
        fi
        BASE_BRANCH="$2"
        shift
        ;;
      --mention)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --mention"
        fi
        MENTION="$2"
        shift
        ;;
      --changed-paths-file)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --changed-paths-file"
        fi
        CHANGED_PATHS_FILE="$2"
        shift
        ;;
      --impact-details-file)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --impact-details-file"
        fi
        IMPACT_DETAILS_FILE="$2"
        shift
        ;;
      --repository-changed-paths-file)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --repository-changed-paths-file"
        fi
        REPOSITORY_CHANGED_PATHS_FILE="$2"
        shift
        ;;
      --verification-file)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --verification-file"
        fi
        VERIFICATION_FILE="$2"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown option: $1"
        ;;
    esac
    shift
  done
}

count_file_lines() {
  local path="$1"
  if [ -n "$path" ] && [ -f "$path" ]; then
    wc -l < "$path" | tr -d ' '
  else
    echo 0
  fi
}

write_path_bullets() {
  local path="$1"
  local limit="${2:-40}"
  local count=0

  if [ -z "$path" ] || [ ! -s "$path" ]; then
    echo "- 변경 없음"
    return
  fi

  while IFS= read -r changed_path; do
    [ -n "$changed_path" ] || continue
    count=$((count + 1))
    if [ "$count" -le "$limit" ]; then
      echo "- \`$changed_path\`"
    fi
  done < "$path"

  total_count="$(count_file_lines "$path")"
  if [ "$total_count" -gt "$limit" ]; then
    echo "- ... $((total_count - limit))개 추가 path 생략"
  fi
}

write_impact_bullets() {
  local path="$1"
  local limit="${2:-40}"
  local count=0

  if [ -z "$path" ] || [ ! -s "$path" ]; then
    echo "- viewer/WASM/core 영향 path 없음"
    return
  fi

  while IFS="$(printf '\t')" read -r impact_path reason; do
    [ -n "$impact_path" ] || continue
    count=$((count + 1))
    if [ "$count" -le "$limit" ]; then
      echo "- \`$impact_path\` - $reason"
    fi
  done < "$path"

  total_count="$(count_file_lines "$path")"
  if [ "$total_count" -gt "$limit" ]; then
    echo "- ... $((total_count - limit))개 추가 impact path 생략"
  fi
}

write_verification_bullets() {
  local path="$1"

  if [ -z "$path" ] || [ ! -s "$path" ]; then
    echo "- 자동 PR workflow에서 검증 결과를 채우지 못함"
    return
  fi

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "- $line"
  done < "$path"
}

main() {
  parse_args "$@"

  require_value "--output" "$OUTPUT_FILE"
  require_value "--current-tag" "$CURRENT_TAG"
  require_value "--current-commit" "$CURRENT_COMMIT"
  require_value "--target-tag" "$TARGET_TAG"
  require_value "--target-commit" "$TARGET_COMMIT"

  mkdir -p "$(dirname "$OUTPUT_FILE")"

  upstream_changed_count="$(count_file_lines "$CHANGED_PATHS_FILE")"
  impact_count="$(count_file_lines "$IMPACT_DETAILS_FILE")"
  repo_changed_count="$(count_file_lines "$REPOSITORY_CHANGED_PATHS_FILE")"

  cat > "$OUTPUT_FILE" <<EOF
# Update bundled rhwp-studio to rhwp $TARGET_TAG

$MENTION upstream \`edwardkim/rhwp\` release 감지 결과 bundled \`rhwp-studio\` 업데이트 후보를 생성했습니다.

## Summary

- base branch: \`$BASE_BRANCH\`
- upstream release: ${TARGET_URL:-"(URL unavailable)"}
- previous bundled tag: \`$CURRENT_TAG\`
- previous bundled commit: \`$CURRENT_COMMIT\`
- new bundled tag: \`$TARGET_TAG\`
- new bundled commit: \`$TARGET_COMMIT\`
- upstream changed paths: \`$upstream_changed_count\`
- viewer/WASM/core impact paths: \`$impact_count\`
- repository changed paths: \`$repo_changed_count\`

## Upstream impact detection

EOF

  write_impact_bullets "$IMPACT_DETAILS_FILE" >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<EOF

## Upstream changed paths

EOF

  write_path_bullets "$CHANGED_PATHS_FILE" >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<EOF

## Repository changes

EOF

  write_path_bullets "$REPOSITORY_CHANGED_PATHS_FILE" >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<EOF

## Verification

EOF

  write_verification_bullets "$VERIFICATION_FILE" >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<EOF

## Maintainer checklist

- [ ] bundled \`rhwp-studio\` manifest의 tag/commit과 upstream release가 맞는지 확인
- [ ] PR CI의 macOS build, Rust/core verify, release helper checks 결과 확인
- [ ] viewer/editor smoke 필요 여부 판단
- [ ] release note에 upstream \`rhwp\` 반영을 표시할지 판단
- [ ] public release version, release rehearsal, protected \`Release Publish DMG\` 실행 여부 별도 승인

## Release boundary

이 PR은 bundled \`rhwp-studio\` 업데이트 후보만 생성합니다. Signed/notarized DMG, GitHub Release, Sparkle stable appcast, Homebrew 배포는 자동으로 실행하지 않으며, 별도 release 승인과 protected workflow를 거쳐야 합니다.

Automation source: #204
EOF
}

main "$@"
