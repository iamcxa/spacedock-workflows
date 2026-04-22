#!/usr/bin/env bash
# update-entity-status.sh — atomic frontmatter 'status:' field update
#
# Usage:
#   bash update-entity-status.sh \
#     --entity=<path> --new-status=<enum> \
#     [--if-hash=<sha256>] [--commit-as="<msg>"] [--no-commit]
#
# Exit codes:
#   0  success
#   1  usage / unknown option
#   3  missing file
#   6  stale hash (--if-hash mismatch)
#   7  missing --if-hash
#   8  commit failed
#  10  malformed frontmatter (status field not found)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./map-helpers.sh
source "${SCRIPT_DIR}/map-helpers.sh"

ENTITY=""
NEW_STATUS=""
IF_HASH=""
COMMIT_MSG=""
NO_COMMIT=0

for arg in "$@"; do
  case "$arg" in
    --entity=*)     ENTITY="${arg#--entity=}" ;;
    --new-status=*) NEW_STATUS="${arg#--new-status=}" ;;
    --if-hash=*)    IF_HASH="${arg#--if-hash=}" ;;
    --commit-as=*)  COMMIT_MSG="${arg#--commit-as=}" ;;
    --no-commit)    NO_COMMIT=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

{ [ -n "$ENTITY" ] && [ -n "$NEW_STATUS" ]; } || {
  echo "Usage: update-entity-status.sh --entity=<path> --new-status=<enum> [--if-hash=<sha256>] [--commit-as=<msg>] [--no-commit]" >&2
  exit 1
}

[ -f "$ENTITY" ] || { echo "Error: entity not found: $ENTITY" >&2; exit 3; }
[ -n "$IF_HASH" ] || { echo "Error: --if-hash required" >&2; exit 7; }

CURRENT_HASH="$(sha256_of "$ENTITY")"
[ "$CURRENT_HASH" = "$IF_HASH" ] || { echo "Error: hash mismatch (expected $IF_HASH, got $CURRENT_HASH)" >&2; exit 6; }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT INT TERM

# awk state machine: replace ^status: line within frontmatter (between first and second ---)
awk -v new_status="$NEW_STATUS" '
  BEGIN { dash_count = 0; in_fm = 0; replaced = 0 }
  /^---$/ {
    dash_count++
    if (dash_count == 1) { in_fm = 1; print; next }
    if (dash_count == 2) { in_fm = 0; print; next }
  }
  in_fm && /^status:[[:space:]]/ && !replaced {
    print "status: " new_status
    replaced = 1
    next
  }
  { print }
  END { if (!replaced) exit 10 }
' "$ENTITY" > "$TMP"
AWK_RC=$?

if [ "$AWK_RC" != "0" ]; then
  echo "Error: status field not found in frontmatter (exit $AWK_RC)" >&2
  exit 10
fi

mv "$TMP" "$ENTITY"
trap - EXIT INT TERM

if [ "$NO_COMMIT" = "0" ] && [ -n "$COMMIT_MSG" ]; then
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "Warning: not a git repo; skipping commit" >&2
    exit 0
  }
  git add -- "$ENTITY"
  if git diff --cached --quiet -- "$ENTITY"; then
    # Nothing staged (no change) — treat as success
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
