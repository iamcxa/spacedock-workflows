#!/usr/bin/env bash
# advance-stage.sh — thin orchestrator: register-stage-output → update-entity-status → render-stage-links
#
# Usage:
#   bash advance-stage.sh \
#     --entity=<path to index.md> \
#     --new-status=<plan|execute|verify|ship|done> \
#     --stage-name=<plan|execute|verify|review|ship> \
#     --stage-file=<relative path to stage .md> \
#     --if-hash=<sha256> \
#     --commit-as="<message>"
#
# Each sub-step re-reads the hash from disk (read-first CAS pattern).
# Returns first non-zero exit from any helper.
#
# DESTRUCTIVE-ON-LEGACY WARNING (2026-04-26 D2-3 from pitch-099):
#   The render-stage-links sub-step rebuilds the body table from
#   `stage_outputs:` frontmatter ONLY — it does NOT preserve existing
#   body table rows whose stages are absent from the frontmatter map.
#   ~14 legacy entities (Rounds 1-3 of 2026-04-25 sweep + 098, plus any
#   entity that shipped before commit 997ea60d) have hand-Edit body tables
#   with EMPTY stage_outputs. Invoking advance-stage.sh on them will
#   silently NUKE their body table rows.
#
#   Discipline before invoking against any entity:
#     1. awk '/^---$/{c++; if(c==2)exit} c==1' index.md | grep -q '^stage_outputs:'
#     2. If empty, BACKFILL stage_outputs first by mirroring the body
#        table rows into the frontmatter map (one-time per legacy entity).
#     3. Then run advance-stage.sh — render-stage-links will preserve
#        everything because frontmatter now matches body.
#
#   Long-term fix (not built): --accept-existing or --seed-from-disk.
#   See MEMORY: advance-stage-destructive-on-legacy-bodies.md.
#
# Exit codes:
#   0  success (or no-op if already at new-status)
#   1  usage / unknown option
#   3  missing entity file
#   6  stale hash at any step
#   7  missing --if-hash
#   8  commit failed
#  10  malformed frontmatter
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./map-helpers.sh
source "${SCRIPT_DIR}/map-helpers.sh"

ENTITY=""
NEW_STATUS=""
STAGE_NAME=""
STAGE_FILE=""
IF_HASH=""
COMMIT_MSG=""

for arg in "$@"; do
  case "$arg" in
    --entity=*)     ENTITY="${arg#--entity=}" ;;
    --new-status=*) NEW_STATUS="${arg#--new-status=}" ;;
    --stage-name=*) STAGE_NAME="${arg#--stage-name=}" ;;
    --stage-file=*) STAGE_FILE="${arg#--stage-file=}" ;;
    --if-hash=*)    IF_HASH="${arg#--if-hash=}" ;;
    --commit-as=*)  COMMIT_MSG="${arg#--commit-as=}" ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

{ [ -n "$ENTITY" ] && [ -n "$NEW_STATUS" ] && [ -n "$STAGE_NAME" ] && [ -n "$STAGE_FILE" ]; } || {
  echo "Usage: advance-stage.sh --entity=<path> --new-status=<enum> --stage-name=<name> --stage-file=<path> --if-hash=<sha256> --commit-as=<msg>" >&2
  exit 1
}

[ -f "$ENTITY" ] || { echo "Error: entity not found: $ENTITY" >&2; exit 3; }
[ -n "$IF_HASH" ] || { echo "Error: --if-hash required" >&2; exit 7; }

H="$(sha256_of "$ENTITY")"
[ "$H" = "$IF_HASH" ] || { echo "Error: hash mismatch before register-stage-output (expected $IF_HASH, got $H)" >&2; exit 6; }

# Check if already at target status — may skip status update but still register artifact
CURRENT_STATUS="$(awk 'BEGIN{d=0} /^---$/{d++; if(d==2)exit} d==1 && /^status:[[:space:]]/{print; exit}' "$ENTITY" | awk '{print $2}')"
STATUS_ALREADY_SET=0
if [ "$CURRENT_STATUS" = "$NEW_STATUS" ]; then
  STATUS_ALREADY_SET=1
fi

if [ "$STATUS_ALREADY_SET" = "0" ]; then
  case "$COMMIT_MSG" in
    *": advance status to "*) ;;
    *)
      echo "Error: --commit-as for status mutation must contain ': advance status to ' for C14 invariant compatibility" >&2
      exit 1
      ;;
  esac
fi

ORIGINAL_ENTITY="$(mktemp)"
INDEX_PATCH=""
INDEX_PATCH_HAS_DIFF=0
cp -p "$ENTITY" "$ORIGINAL_ENTITY"
cleanup_original() {
  rm -f "$ORIGINAL_ENTITY"
  if [ -n "$INDEX_PATCH" ]; then
    rm -f "$INDEX_PATCH"
  fi
}
restore_original() {
  cp -p "$ORIGINAL_ENTITY" "$ENTITY"
}
restore_entity_and_index() {
  local rc=0
  git -C "$GIT_CONTEXT" reset -q -- "$ENTITY_ABS" >/dev/null 2>&1 || rc=1
  restore_original
  if [ "$INDEX_PATCH_HAS_DIFF" = "1" ]; then
    git -C "$GIT_CONTEXT" apply --cached --binary "$INDEX_PATCH" >/dev/null 2>&1 || rc=1
  fi
  return "$rc"
}
trap cleanup_original EXIT INT TERM

# Step 1: register-stage-output (writes stage_outputs.<stage>)
# Re-read hash from disk (initial hash provided by caller)
bash "${SCRIPT_DIR}/register-stage-output.sh" \
  --entity="$ENTITY" \
  --stage="$STAGE_NAME" \
  --file="$STAGE_FILE" \
  --if-hash="$H" \
  --no-commit
RC=$?
if [ "$RC" -ne 0 ]; then
  restore_original
  exit "$RC"
fi

# Step 2: update-entity-status (advances status field) — skip if already at target
if [ "$STATUS_ALREADY_SET" = "0" ]; then
  H="$(sha256_of "$ENTITY")"
  bash "${SCRIPT_DIR}/update-entity-status.sh" \
    --entity="$ENTITY" \
    --new-status="$NEW_STATUS" \
    --if-hash="$H" \
    --no-commit
  RC=$?
  if [ "$RC" -ne 0 ]; then
    restore_original
    exit "$RC"
  fi
fi

# Step 3: render-stage-links (re-renders body table from frontmatter)
# Re-read hash after Step 2 modified the file
H="$(sha256_of "$ENTITY")"
bash "${SCRIPT_DIR}/render-stage-links.sh" \
  --entity="$ENTITY" \
  --if-hash="$H" \
  --no-commit
RC=$?
if [ "$RC" -ne 0 ]; then
  restore_original
  exit "$RC"
fi

ENTITY_DIR="$(cd "$(dirname "$ENTITY")" 2>/dev/null && pwd)"
ENTITY_ABS="${ENTITY_DIR}/$(basename "$ENTITY")"
GIT_CONTEXT=""
if git -C "$ENTITY_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  GIT_CONTEXT="$ENTITY_DIR"
fi

if [ -z "$GIT_CONTEXT" ]; then
  if cmp -s "$ENTITY" "$ORIGINAL_ENTITY"; then
    restore_original
  fi
  echo "Warning: not a git repo; skipping commit" >&2
  exit 0
fi

INDEX_PATCH="$(mktemp)"
git -C "$GIT_CONTEXT" diff --cached --binary -- "$ENTITY_ABS" > "$INDEX_PATCH"
if [ -s "$INDEX_PATCH" ]; then
  INDEX_PATCH_HAS_DIFF=1
fi

if cmp -s "$ENTITY" "$ORIGINAL_ENTITY"; then
  restore_original
  exit 0
fi

if ! git -C "$GIT_CONTEXT" add -- "$ENTITY_ABS"; then
  if ! restore_entity_and_index; then
    echo "Error: git add failed; index restore failed" >&2
    exit 8
  fi
  echo "Error: git add failed" >&2
  exit 8
fi
if git -C "$GIT_CONTEXT" diff --cached --quiet -- "$ENTITY_ABS"; then
  if ! restore_entity_and_index; then
    echo "Error: no diff after advance; index restore failed" >&2
    exit 8
  fi
  exit 0
fi
if ! git -c user.email="${GIT_AUTHOR_EMAIL:-author@example.com}" \
          -c user.name="${GIT_AUTHOR_NAME:-Ship-flow}" \
          -C "$GIT_CONTEXT" commit -m "$COMMIT_MSG" -- "$ENTITY_ABS"; then
  if ! restore_entity_and_index; then
    echo "Error: commit failed; index restore failed" >&2
    exit 8
  fi
  echo "Error: commit failed" >&2
  exit 8
fi

trap - EXIT INT TERM
cleanup_original

exit 0
