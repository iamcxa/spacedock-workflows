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
# shellcheck disable=SC1091 # resolved relative to this script at runtime
source "${SCRIPT_DIR}/map-helpers.sh"
# shellcheck disable=SC1091 # resolved relative to this script at runtime
source "${SCRIPT_DIR}/completion-v1.sh"

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

completion_parse_entity "$ENTITY" '' shape shape.md >/dev/null 2>&1 || {
  echo "Error: malformed canonical frontmatter authority" >&2
  exit 10
}

FINAL_LF=0
[ "$(LC_ALL=C tail -c 1 "$ENTITY" | od -An -t u1 | tr -d ' ')" = 10 ] && FINAL_LF=1
awk -v new_status="$NEW_STATUS" -v final_lf="$FINAL_LF" '
  {
    line=$0
    if (line=="---") { dash_count++; if (dash_count==1) in_fm=1; else if (dash_count==2) in_fm=0 }
    else if (in_fm && line ~ /^status:[[:space:]]/ && !replaced) { line="status: " new_status; replaced=1 }
    if (have) print previous
    previous=line; have=1
  }
  END { if (have) { printf "%s", previous; if (final_lf) printf "%s", ORS }; if (!replaced) exit 10 }
' "$ENTITY" > "$TMP"
AWK_RC=$?

if [ "$AWK_RC" != "0" ]; then
  echo "Error: status field not found in frontmatter (exit $AWK_RC)" >&2
  exit 10
fi
completion_parse_entity "$TMP" "$NEW_STATUS" shape shape.md >/dev/null 2>&1 || {
  echo "Error: invalid status or malformed canonical frontmatter authority" >&2
  exit 10
}

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
