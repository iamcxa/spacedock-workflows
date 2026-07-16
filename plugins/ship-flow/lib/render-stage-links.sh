#!/usr/bin/env bash
# render-stage-links.sh — print a Markdown view of canonical frontmatter stage_outputs
#
# Usage:
#   bash render-stage-links.sh \
#     --entity=<path to index.md>
#
# Exit codes:
#   0  success (or no-op when section unchanged)
#   1  usage / unknown option
#   3  missing entity file
#   4  malformed or noncanonical authority tail
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./completion-v1.sh
# shellcheck disable=SC1091 # resolved beside this script at runtime
source "${SCRIPT_DIR}/completion-v1.sh"

ENTITY=""
IF_HASH=""
COMMIT_MSG=""
NO_COMMIT=0

for arg in "$@"; do
  case "$arg" in
    --entity=*)    ENTITY="${arg#--entity=}" ;;
    --if-hash=*)   IF_HASH="${arg#--if-hash=}" ;;
    --commit-as=*) COMMIT_MSG="${arg#--commit-as=}" ;;
    --no-commit)   NO_COMMIT=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

[ -z "$IF_HASH$COMMIT_MSG" ] && [ "$NO_COMMIT" = 0 ] || { echo "Unknown legacy mutation option" >&2; exit 1; }
[ -n "$ENTITY" ] || { echo "Usage: render-stage-links.sh --entity=<path>" >&2; exit 1; }
[ -f "$ENTITY" ] || { echo "Error: entity not found: $ENTITY" >&2; exit 3; }
[ ! -L "$ENTITY" ] || { echo "Error: entity is not a regular file: $ENTITY" >&2; exit 3; }
completion_parse_entity "$ENTITY" '' shape shape.md >/dev/null || {
  echo "Error: malformed or noncanonical frontmatter authority tail: $ENTITY" >&2
  exit 4
}

# Extract stage_outputs from frontmatter and build table rows
# Reads: stage_outputs block (indented key: value pairs under stage_outputs:)
TABLE_BODY="$(awk '
  BEGIN { dash_count=0; in_fm=0; in_so=0; rows="" }
  /^---$/ {
    dash_count++
    if (dash_count == 1) { in_fm=1; next }
    if (dash_count == 2) { in_fm=0; in_so=0; next }
  }
  in_fm && /^stage_outputs:[[:space:]]*$/ { in_so=1; next }
  in_fm && in_so && /^[[:space:]]/ {
    line = $0
    sub(/^[[:space:]]+/, "", line)
    n = split(line, parts, ":")
    stage = parts[1]
    path = parts[2]
    # trim leading/trailing whitespace from path
    sub(/^[[:space:]]+/, "", path)
    sub(/[[:space:]]+$/, "", path)
    if (stage != "" && path != "") {
      rows = rows "| " stage " | [" path "](" path ") |\n"
    }
    next
  }
  in_fm && in_so && /^[^[:space:]]/ { in_so=0 }
  END { printf "%s", rows }
' "$ENTITY")"

# Build new section content
NEW_SECTION="| Stage | File |
|-------|------|
${TABLE_BODY}"

BODY_TMP="$(mktemp)"
trap 'rm -f "$BODY_TMP"' EXIT INT TERM
printf '%s' "$NEW_SECTION" > "$BODY_TMP"
cat "$BODY_TMP"
rm -f "$BODY_TMP"
trap - EXIT INT TERM
exit 0
