#!/usr/bin/env bash
# render-stage-links.sh — re-render <!-- section:stage-artifact-links --> from frontmatter stage_outputs
#
# Usage:
#   bash render-stage-links.sh \
#     --entity=<path to index.md> \
#     --if-hash=<sha256> \
#     [--commit-as="<msg>"] [--no-commit]
#
# Exit codes:
#   0  success (or no-op when section unchanged)
#   1  usage / unknown option
#   3  missing entity file
#   6  stale hash (--if-hash mismatch)
#   7  missing --if-hash
#   8  commit failed
#  10  section markers missing or unbalanced in entity file
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./map-helpers.sh
source "${SCRIPT_DIR}/map-helpers.sh"

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

[ -n "$ENTITY" ] || { echo "Usage: render-stage-links.sh --entity=<path> --if-hash=<sha256> [--commit-as=<msg>] [--no-commit]" >&2; exit 1; }
[ -f "$ENTITY" ] || { echo "Error: entity not found: $ENTITY" >&2; exit 3; }
[ -n "$IF_HASH" ] || { echo "Error: --if-hash required" >&2; exit 7; }

CURRENT_HASH="$(sha256_of "$ENTITY")"
[ "$CURRENT_HASH" = "$IF_HASH" ] || { echo "Error: hash mismatch (expected $IF_HASH, got $CURRENT_HASH)" >&2; exit 6; }

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

# Write to temp file for atomic_replace
BODY_TMP="$(mktemp)"
trap 'rm -f "$BODY_TMP"' EXIT INT TERM
printf '%s' "$NEW_SECTION" > "$BODY_TMP"

# Use atomic_replace from map-helpers.sh to swap the section in-place
atomic_replace "$ENTITY" "stage-artifact-links" "$BODY_TMP"
REPLACE_RC=$?
rm -f "$BODY_TMP"
trap - EXIT INT TERM

if [ "$REPLACE_RC" -ne 0 ]; then
  echo "Error: section markers <!-- section:stage-artifact-links --> missing or unbalanced in $ENTITY" >&2
  exit 10
fi

if [ "$NO_COMMIT" = "0" ] && [ -n "$COMMIT_MSG" ]; then
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "Warning: not a git repo; skipping commit" >&2
    exit 0
  }
  git add -- "$ENTITY"
  if git diff --cached --quiet -- "$ENTITY"; then
    exit 0
  fi
  if ! git -c user.email="${GIT_AUTHOR_EMAIL:-author@example.com}" \
            -c user.name="${GIT_AUTHOR_NAME:-Ship-flow}" \
            commit -m "$COMMIT_MSG" -- "$ENTITY"; then
    echo "Error: commit failed" >&2
    exit 8
  fi
fi

exit 0
