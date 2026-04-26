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

# Check if already at target status — may skip status update but still register artifact
CURRENT_STATUS="$(awk 'BEGIN{d=0} /^---$/{d++; if(d==2)exit} d==1 && /^status:[[:space:]]/{print; exit}' "$ENTITY" | awk '{print $2}')"
STATUS_ALREADY_SET=0
if [ "$CURRENT_STATUS" = "$NEW_STATUS" ]; then
  STATUS_ALREADY_SET=1
fi

# Check if stage artifact already registered — skip register+render if both already done
STAGE_ALREADY_REGISTERED="$(awk -v stage="$STAGE_NAME" '
  BEGIN{d=0;in_so=0;found=0}
  /^---$/{d++; if(d==2)exit}
  d==1 && /^stage_outputs:[[:space:]]*$/{in_so=1;next}
  d==1 && in_so && /^[[:space:]]/{
    line=$0; sub(/^[[:space:]]+/,"",line)
    split(line,p,":"); if(p[1]==stage){found=1}; next
  }
  d==1 && in_so && /^[^[:space:]]/{in_so=0}
  END{print found}
' "$ENTITY")"

# Fully idempotent: status already set AND artifact already registered
if [ "$STATUS_ALREADY_SET" = "1" ] && [ "$STAGE_ALREADY_REGISTERED" = "1" ]; then
  exit 0
fi

# Step 1: register-stage-output (writes stage_outputs.<stage>)
# Re-read hash from disk (initial hash provided by caller)
H="$(sha256_of "$ENTITY")"
[ "$H" = "$IF_HASH" ] || { echo "Error: hash mismatch before register-stage-output (expected $IF_HASH, got $H)" >&2; exit 6; }

bash "${SCRIPT_DIR}/register-stage-output.sh" \
  --entity="$ENTITY" \
  --stage="$STAGE_NAME" \
  --file="$STAGE_FILE" \
  --if-hash="$H" \
  --commit-as="${COMMIT_MSG}: register stage_outputs.${STAGE_NAME}"
RC=$?
[ "$RC" -eq 0 ] || exit "$RC"

# Step 2: update-entity-status (advances status field) — skip if already at target
if [ "$STATUS_ALREADY_SET" = "0" ]; then
  H="$(sha256_of "$ENTITY")"
  bash "${SCRIPT_DIR}/update-entity-status.sh" \
    --entity="$ENTITY" \
    --new-status="$NEW_STATUS" \
    --if-hash="$H" \
    --commit-as="${COMMIT_MSG}: advance status to ${NEW_STATUS}"
  RC=$?
  [ "$RC" -eq 0 ] || exit "$RC"
fi

# Step 3: render-stage-links (re-renders body table from frontmatter)
# Re-read hash after Step 2 modified the file
H="$(sha256_of "$ENTITY")"
bash "${SCRIPT_DIR}/render-stage-links.sh" \
  --entity="$ENTITY" \
  --if-hash="$H" \
  --commit-as="${COMMIT_MSG}: render stage-artifact-links"
RC=$?
[ "$RC" -eq 0 ] || exit "$RC"

exit 0
