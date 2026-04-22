#!/usr/bin/env bash
# register-stage-output.sh — atomic frontmatter: set stage_outputs.<stage> = <file-path>
#
# Usage:
#   bash register-stage-output.sh \
#     --entity=<path> --stage=<name> --file=<path> \
#     [--if-hash=<sha256>] [--commit-as="<msg>"] [--no-commit]
#
# Exit codes:
#   0  success
#   1  usage / unknown option
#   3  missing file
#   6  stale hash (--if-hash mismatch)
#   7  missing --if-hash
#   8  commit failed
#  10  malformed frontmatter
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./map-helpers.sh
source "${SCRIPT_DIR}/map-helpers.sh"

ENTITY=""
STAGE=""
FILE_PATH=""
IF_HASH=""
COMMIT_MSG=""
NO_COMMIT=0

for arg in "$@"; do
  case "$arg" in
    --entity=*)    ENTITY="${arg#--entity=}" ;;
    --stage=*)     STAGE="${arg#--stage=}" ;;
    --file=*)      FILE_PATH="${arg#--file=}" ;;
    --if-hash=*)   IF_HASH="${arg#--if-hash=}" ;;
    --commit-as=*) COMMIT_MSG="${arg#--commit-as=}" ;;
    --no-commit)   NO_COMMIT=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

{ [ -n "$ENTITY" ] && [ -n "$STAGE" ] && [ -n "$FILE_PATH" ]; } || {
  echo "Usage: register-stage-output.sh --entity=<path> --stage=<name> --file=<path> [--if-hash=<sha256>] [--commit-as=<msg>] [--no-commit]" >&2
  exit 1
}

[ -f "$ENTITY" ] || { echo "Error: entity not found: $ENTITY" >&2; exit 3; }
[ -n "$IF_HASH" ] || { echo "Error: --if-hash required" >&2; exit 7; }

CURRENT_HASH="$(sha256_of "$ENTITY")"
[ "$CURRENT_HASH" = "$IF_HASH" ] || { echo "Error: hash mismatch (expected $IF_HASH, got $CURRENT_HASH)" >&2; exit 6; }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT INT TERM

# awk state machine handles 3 cases:
#   Case A: stage_outputs block exists, our stage key present → replace value
#   Case B: stage_outputs block exists, our stage key absent  → append before block-exit
#   Case C: stage_outputs block absent entirely               → inject block before closing ---
#
# State variables:
#   dash_count : 0=before fm, 1=in fm, 2+=after fm
#   in_fm      : 1 while between first and second ---
#   in_so      : 1 while inside stage_outputs: indented block
#   so_seen    : 1 if stage_outputs: header was encountered
#   replaced   : 1 if our stage entry has been written out
awk -v stage="$STAGE" -v path="$FILE_PATH" '
  BEGIN {
    dash_count = 0
    in_fm = 0
    in_so = 0
    so_seen = 0
    replaced = 0
  }

  /^---$/ {
    dash_count++
    if (dash_count == 1) {
      in_fm = 1
      print
      next
    }
    if (dash_count == 2) {
      # Closing --- of frontmatter
      # Case B: inside so block but stage key not yet emitted
      if (in_so && !replaced) {
        print "  " stage ": " path
        replaced = 1
      }
      # Case C: stage_outputs block never seen at all
      if (!so_seen) {
        print "stage_outputs:"
        print "  " stage ": " path
        so_seen = 1
        replaced = 1
      }
      in_fm = 0
      in_so = 0
      print
      next
    }
  }

  # Detect stage_outputs: block start (only inside frontmatter)
  in_fm && /^stage_outputs:[[:space:]]*$/ {
    so_seen = 1
    in_so = 1
    print
    next
  }

  # Inside stage_outputs: block — handle child key lines
  in_fm && in_so && /^[[:space:]]/ {
    # Extract the key name: trim leading whitespace, split on ':'
    line = $0
    sub(/^[[:space:]]+/, "", line)
    n = split(line, parts, ":")
    key = parts[1]
    if (key == stage && !replaced) {
      print "  " stage ": " path
      replaced = 1
    } else {
      print
    }
    next
  }

  # Leaving stage_outputs: block — hit a new top-level key (non-whitespace-prefixed)
  in_fm && in_so && /^[^[:space:]]/ {
    if (!replaced) {
      print "  " stage ": " path
      replaced = 1
    }
    in_so = 0
    print
    next
  }

  { print }
' "$ENTITY" > "$TMP"
AWK_RC=$?

if [ "$AWK_RC" != "0" ]; then
  echo "Error: awk processing failed (exit $AWK_RC)" >&2
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
