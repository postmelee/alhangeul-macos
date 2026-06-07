#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPOSITORY="${GITHUB_REPOSITORY:-postmelee/alhangeul-macos}"

usage() {
  cat >&2 <<EOF
Usage: $0 <previous-release-ref> <candidate-ref> <output-file>

merge PR metadata에서 release PR 분석 초안을 작성한다.
이 출력은 검토 보조 자료이며, release owner는 release note 게시 전에
PR body, linked Issue, 최종 보고서를 직접 읽어야 한다.
EOF
}

if [ "$#" -ne 3 ]; then
  usage
  exit 1
fi

PREVIOUS_REF="$1"
CANDIDATE_REF="$2"
OUTPUT_FILE="$3"

git rev-parse --verify "$PREVIOUS_REF^{commit}" >/dev/null
git rev-parse --verify "$CANDIDATE_REF^{commit}" >/dev/null

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/release-pr-analysis.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

MERGES_FILE="$TMP_DIR/merges.tsv"
FIRST_PARENT_PRS_FILE="$TMP_DIR/first-parent-prs.txt"
PRS_FILE="$TMP_DIR/prs.txt"
DIRECT_PRS_FILE="$TMP_DIR/direct-prs.txt"
RESOLVED_ISSUES_FILE="$TMP_DIR/resolved-issues.txt"
RELATED_ISSUES_FILE="$TMP_DIR/related-issues.txt"
RELATED_ONLY_ISSUES_FILE="$TMP_DIR/related-only-issues.txt"
TABLE_ROWS_FILE="$TMP_DIR/table-rows.md"
DETAILS_FILE="$TMP_DIR/details.md"

mkdir -p "$(dirname "$OUTPUT_FILE")"
touch "$FIRST_PARENT_PRS_FILE" "$PRS_FILE" "$DIRECT_PRS_FILE" "$RESOLVED_ISSUES_FILE" "$RELATED_ISSUES_FILE" "$RELATED_ONLY_ISSUES_FILE" "$TABLE_ROWS_FILE" "$DETAILS_FILE"

previous_commit="$(git rev-parse "$PREVIOUS_REF^{commit}")"
candidate_commit="$(git rev-parse "$CANDIDATE_REF^{commit}")"

git log --merges --format='%H%x09%s' "$PREVIOUS_REF..$CANDIDATE_REF" > "$MERGES_FILE"

append_unique_line() {
  local path="$1"
  local value="$2"

  [ -n "$value" ] || return 0
  if ! grep -Fqx "$value" "$path" 2>/dev/null; then
    printf '%s\n' "$value" >> "$path"
  fi
}

join_issue_numbers() {
  local path="$1"
  local rendered=""
  local issue

  if [ ! -s "$path" ]; then
    printf '없음'
    return
  fi

  while IFS= read -r issue; do
    [ -n "$issue" ] || continue
    if [ -n "$rendered" ]; then
      rendered="$rendered, "
    fi
    rendered="${rendered}\`#$issue\`"
  done < "$path"

  if [ -n "$rendered" ]; then
    printf '%s' "$rendered"
  else
    printf '없음'
  fi
}

join_backtick_paths() {
  local path="$1"
  local rendered=""
  local item

  if [ ! -s "$path" ]; then
    printf '없음'
    return
  fi

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    if [ -n "$rendered" ]; then
      rendered="$rendered, "
    fi
    rendered="${rendered}\`$item\`"
  done < "$path"

  if [ -n "$rendered" ]; then
    printf '%s' "$rendered"
  else
    printf '없음'
  fi
}

sanitize_cell() {
  local value="$1"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  value="${value//|//}"
  printf '%s' "$value"
}

issue_file_without() {
  local source_file="$1"
  local exclude_file="$2"
  local output_file="$3"
  local issue

  : > "$output_file"
  while IFS= read -r issue; do
    [ -n "$issue" ] || continue
    if ! grep -Fqx "$issue" "$exclude_file" 2>/dev/null; then
      append_unique_line "$output_file" "$issue"
    fi
  done < "$source_file"
}

extract_issue_refs() {
  local body_file="$1"
  local pr_number="$2"
  local resolved_output="$3"
  local related_output="$4"
  local all_refs_file="$TMP_DIR/all-refs-$pr_number.txt"
  local resolved_refs_file="$TMP_DIR/resolved-refs-$pr_number.txt"
  local related_refs_file="$TMP_DIR/related-refs-$pr_number.txt"
  local issue

  : > "$all_refs_file"
  : > "$resolved_refs_file"
  : > "$related_refs_file"

  if [ ! -s "$body_file" ] || ! command -v rg >/dev/null 2>&1; then
    return
  fi

  rg -o '#[0-9]+' "$body_file" | tr -d '#' | sort -n -u > "$all_refs_file" || true
  rg -i '(^|[^A-Za-z])(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)[^[:cntrl:]]*#[0-9]+' "$body_file" \
    | rg -o '#[0-9]+' | tr -d '#' | sort -n -u > "$resolved_refs_file" || true

  while IFS= read -r issue; do
    [ -n "$issue" ] || continue
    [ "$issue" != "$pr_number" ] || continue
    append_unique_line "$resolved_output" "$issue"
  done < "$resolved_refs_file"

  issue_file_without "$all_refs_file" "$resolved_refs_file" "$related_refs_file"
  while IFS= read -r issue; do
    [ -n "$issue" ] || continue
    [ "$issue" != "$pr_number" ] || continue
    append_unique_line "$related_output" "$issue"
  done < "$related_refs_file"
}

extract_task_issue_from_subject() {
  local subject="$1"
  local output_file="$2"
  local issue=""

  if [[ "$subject" =~ task[-_/]?([0-9]+) ]]; then
    issue="${BASH_REMATCH[1]}"
  fi

  if [ -n "$issue" ]; then
    append_unique_line "$output_file" "$issue"
  fi
}

collect_report_candidates() {
  local issues_file="$1"
  local output_file="$2"
  local issue

  : > "$output_file"
  while IFS= read -r issue; do
    [ -n "$issue" ] || continue
    find "$ROOT/mydocs/report" -maxdepth 1 -type f -name "task_*_${issue}_report.md" -print 2>/dev/null \
      | sed "s#^$ROOT/##" >> "$output_file"
  done < "$issues_file"

  sort -u "$output_file" -o "$output_file"
}

all_paths_match_docs_only() {
  local paths_file="$1"
  local path
  local saw_path=0

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    saw_path=1
    case "$path" in
      README.md|mydocs/*)
        ;;
      *)
        return 1
        ;;
    esac
  done < "$paths_file"

  [ "$saw_path" -eq 1 ]
}

path_matches_any() {
  local paths_file="$1"
  local pattern="$2"

  if grep -Eq "$pattern" "$paths_file" 2>/dev/null; then
    return 0
  fi
  return 1
}

classify_hint() {
  local title="$1"
  local paths_file="$2"
  local lowered_title

  lowered_title="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]')"

  if printf '%s\n' "$lowered_title" | grep -Eq 'sync rhwp|rhwp upstream'; then
    printf '확인 필요 (upstream sync 후보)'
    return
  fi
  if path_matches_any "$paths_file" '^(rhwp-core\.lock|RustBridge/|Sources/HostApp/Resources/rhwp-studio/)'; then
    printf '확인 필요 (upstream sync 후보)'
    return
  fi
  if path_matches_any "$paths_file" '^(\.github/workflows/release|scripts/(release|package-release|update-cask-sha256|ci/write-release|ci/check-release|ci/write-sparkle|ci/prepare-pages)|docs/updates/|docs/index\.html|Casks/|mydocs/release/)'; then
    printf '확인 필요 (운영/배포 후보)'
    return
  fi
  if path_matches_any "$paths_file" '^(Sources/HostApp/|Sources/QLExtension/|Sources/ThumbnailExtension/|Sources/RhwpCoreBridge/|Sources/Shared/)'; then
    printf '확인 필요 (사용자-facing 후보)'
    return
  fi
  if all_paths_match_docs_only "$paths_file"; then
    printf '확인 필요 (문서-only 후보)'
    return
  fi
  if path_matches_any "$paths_file" '^(\.github/|scripts/|mydocs/skills/|mydocs/manual/|mydocs/plans/|mydocs/working/|mydocs/report/)'; then
    printf '확인 필요 (개발자-facing 후보)'
    return
  fi

  printf '확인 필요'
}

write_path_preview() {
  local paths_file="$1"
  local limit="${2:-20}"
  local count=0
  local total=0
  local path

  if [ ! -s "$paths_file" ]; then
    echo "- 변경 파일 확인 필요"
    return
  fi

  total="$(wc -l < "$paths_file" | tr -d ' ')"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    count=$((count + 1))
    if [ "$count" -le "$limit" ]; then
      echo "- \`$path\`"
    fi
  done < "$paths_file"

  if [ "$total" -gt "$limit" ]; then
    echo "- ... $((total - limit))개 추가 path 생략"
  fi
}

collect_merge_prs() {
  local input_file="$1"
  local output_file="$2"
  local merge_hash
  local subject
  local pr_number
  local tab

  tab="$(printf '\t')"
  while IFS="$tab" read -r merge_hash subject; do
    [ -n "$merge_hash" ] || continue
    if [[ "$subject" =~ Merge[[:space:]]pull[[:space:]]request[[:space:]]#([0-9]+) ]]; then
      pr_number="${BASH_REMATCH[1]}"
      append_unique_line "$output_file" "$pr_number"
    fi
  done < "$input_file"
}

collect_merge_prs "$MERGES_FILE" "$PRS_FILE"
git log --first-parent --merges --format='%s' "$PREVIOUS_REF..$CANDIDATE_REF" \
  | while IFS= read -r subject; do
      if [[ "$subject" =~ Merge[[:space:]]pull[[:space:]]request[[:space:]]#([0-9]+) ]]; then
        append_unique_line "$FIRST_PARENT_PRS_FILE" "${BASH_REMATCH[1]}"
      fi
    done

write_pr_row() {
  local pr_number="$1"
  local merge_hash="$2"
  local subject="$3"
  local title="$subject"
  local pr_title
  local body_file="$TMP_DIR/body-$pr_number.md"
  local paths_file="$TMP_DIR/paths-$pr_number.txt"
  local issues_file="$TMP_DIR/issues-$pr_number.txt"
  local resolved_file="$TMP_DIR/resolved-$pr_number.txt"
  local related_file="$TMP_DIR/related-$pr_number.txt"
  local related_clean_file="$TMP_DIR/related-clean-$pr_number.txt"
  local reports_file="$TMP_DIR/reports-$pr_number.txt"
  local gh_status="git metadata only"
  local merge_commit="$merge_hash"
  local classification
  local resolved_cell
  local related_cell
  local reports_cell
  local evidence_cell
  local note_cell
  local title_cell

  : > "$body_file"
  : > "$paths_file"
  : > "$issues_file"
  : > "$resolved_file"
  : > "$related_file"
  : > "$reports_file"

  if command -v gh >/dev/null 2>&1; then
    if pr_title="$(gh pr view "$pr_number" --repo "$REPOSITORY" --json title --jq '.title' 2>/dev/null)"; then
      title="$pr_title"
      gh_status="PR body"
      gh pr view "$pr_number" --repo "$REPOSITORY" --json body --jq '.body // ""' > "$body_file" 2>/dev/null || : > "$body_file"
      gh pr view "$pr_number" --repo "$REPOSITORY" --json files --jq '.files[].path' > "$paths_file" 2>/dev/null || : > "$paths_file"
      merge_commit="$(gh pr view "$pr_number" --repo "$REPOSITORY" --json mergeCommit --jq '.mergeCommit.oid // ""' 2>/dev/null || printf '%s' "$merge_hash")"
    fi
  fi

  if [ ! -s "$paths_file" ] && [ -n "$merge_hash" ]; then
    git diff --name-only "$merge_hash^1" "$merge_hash" > "$paths_file" 2>/dev/null || : > "$paths_file"
  fi

  extract_issue_refs "$body_file" "$pr_number" "$resolved_file" "$related_file"
  extract_task_issue_from_subject "$subject" "$related_file"
  issue_file_without "$related_file" "$resolved_file" "$related_clean_file"
  mv "$related_clean_file" "$related_file"

  cat "$resolved_file" "$related_file" 2>/dev/null | sort -n -u > "$issues_file"
  collect_report_candidates "$issues_file" "$reports_file"

  while IFS= read -r issue; do
    [ -n "$issue" ] || continue
    append_unique_line "$RESOLVED_ISSUES_FILE" "$issue"
  done < "$resolved_file"

  while IFS= read -r issue; do
    [ -n "$issue" ] || continue
    if ! grep -Fqx "$issue" "$RESOLVED_ISSUES_FILE" 2>/dev/null; then
      append_unique_line "$RELATED_ISSUES_FILE" "$issue"
    fi
  done < "$related_file"

  append_unique_line "$DIRECT_PRS_FILE" "$pr_number"

  classification="$(classify_hint "$title" "$paths_file")"
  resolved_cell="$(join_issue_numbers "$resolved_file")"
  related_cell="$(join_issue_numbers "$related_file")"
  reports_cell="$(join_backtick_paths "$reports_file")"
  title_cell="$(sanitize_cell "$title")"
  evidence_cell="$gh_status"
  if [ "$reports_cell" != "없음" ]; then
    evidence_cell="$evidence_cell, $reports_cell"
  fi

  note_cell="merge commit \`$merge_commit\`"
  if grep -Fqx "$pr_number" "$FIRST_PARENT_PRS_FILE" 2>/dev/null; then
    note_cell="$note_cell, first-parent release transport 후보"
  else
    note_cell="$note_cell, 포함 작업 PR 후보"
  fi

  printf '| `#%s` | %s | %s | 확인 필요 | 확인 필요 | %s | %s | %s | %s |\n' \
    "$pr_number" \
    "$title_cell" \
    "$classification" \
    "$resolved_cell" \
    "$related_cell" \
    "$evidence_cell" \
    "$note_cell" >> "$TABLE_ROWS_FILE"

  {
    echo "### PR #$pr_number"
    echo
    echo "- 제목: $title_cell"
    echo "- merge commit: \`${merge_commit:-$merge_hash}\`"
    echo "- metadata 출처: $gh_status"
    echo "- 분류 hint: $classification"
    echo "- 사용자-facing: 확인 필요"
    echo "- 공개 요약 반영: 확인 필요"
    echo "- 해결된 Issue 후보: $resolved_cell"
    echo "- 관련 Issue 후보: $related_cell"
    echo "- 보고서 후보: $reports_cell"
    echo
    echo "변경 path preview:"
    echo
    write_path_preview "$paths_file"
    echo
  } >> "$DETAILS_FILE"
}

if [ -s "$PRS_FILE" ]; then
  while IFS= read -r pr_number; do
    merge_line="$(grep -E "^[0-9a-f]+[[:space:]].*Merge pull request #$pr_number([^0-9]|$)" "$MERGES_FILE" | head -1 || true)"
    merge_hash="$(printf '%s' "$merge_line" | awk '{print $1}')"
    subject="$(printf '%s' "$merge_line" | cut -f2-)"
    if [ -z "$subject" ]; then
      subject="Merge pull request #$pr_number"
    fi
    write_pr_row "$pr_number" "$merge_hash" "$subject"
  done < "$PRS_FILE"
fi

if [ ! -s "$TABLE_ROWS_FILE" ]; then
  echo '| 없음 | merge PR 없음 | 확인 필요 | 확인 필요 | 확인 필요 | 없음 | 없음 | git log | 범위에 merge PR subject가 없음 |' > "$TABLE_ROWS_FILE"
fi

issue_file_without "$RELATED_ISSUES_FILE" "$RESOLVED_ISSUES_FILE" "$RELATED_ONLY_ISSUES_FILE"

cat > "$OUTPUT_FILE" <<EOF
# Release PR 분석 초안

## 범위

- previous release ref: \`$PREVIOUS_REF\`
- previous release commit: \`$previous_commit\`
- candidate ref: \`$CANDIDATE_REF\`
- candidate commit: \`$candidate_commit\`
- repository: \`$REPOSITORY\`

이 문서는 merge PR, PR body, linked Issue, 최종 보고서 후보를 모으는 초안이다. release owner가 각 PR의 실제 사용자-facing 여부, 공개 요약 반영 여부, 해결된 Issue를 확인한 뒤 \`mydocs/release/v<version>.md\`의 \`포함 PR 분석\` 표에 반영한다.

## 포함 PR 분석

| PR | 제목 | 분류 | 사용자-facing | 공개 요약 반영 | 해결된 Issue | 관련 Issue | 근거 문서 | 비고 |
|----|------|------|---------------|----------------|---------------|-------------|-----------|------|
$(cat "$TABLE_ROWS_FILE")

## 직접 반영된 PR과 Issue 후보

### 직접 반영된 PR 후보

$(if [ -s "$DIRECT_PRS_FILE" ]; then while IFS= read -r pr; do echo "- \`#$pr\` 확인 필요"; done < "$DIRECT_PRS_FILE"; else echo "- 없음"; fi)

### 해결된 Issue 후보

$(if [ -s "$RESOLVED_ISSUES_FILE" ]; then while IFS= read -r issue; do echo "- \`#$issue\` closing keyword 또는 release record 확인 필요"; done < "$RESOLVED_ISSUES_FILE"; else echo "- 없음"; fi)

### 관련 Issue 후보

$(if [ -s "$RELATED_ONLY_ISSUES_FILE" ]; then while IFS= read -r issue; do echo "- \`#$issue\` 관련 Issue 여부 확인 필요"; done < "$RELATED_ONLY_ISSUES_FILE"; else echo "- 없음"; fi)

## PR별 상세 후보

$(cat "$DETAILS_FILE")

## release owner 보정 항목

- first-parent release transport PR과 실제 포함 작업 PR을 구분한다.
- 각 PR의 title/body, linked Issue, 최종 보고서를 읽고 분류를 확정한다.
- \`변경 요약\`과 \`알한글 앱 변화\`에는 사용자-facing으로 확정된 항목만 반영한다.
- closing keyword 또는 release record 완료 확정 항목만 해결된 Issue로 쓴다.
- \`Refs\`, \`Related\`, \`대상 타스크\`, \`관련 이슈\`, \`선행/연관\`은 관련 Issue로 분리한다.
- path 기반 delta checklist는 누락 확인과 smoke 영역 점검용 보조 자료로만 사용한다.
EOF
