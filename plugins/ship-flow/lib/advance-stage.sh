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

# Check if already at target status — idempotent no-op
CURRENT_STATUS="$(awk 'BEGIN{d=0} /^---$/{d++; if(d==2)exit} d==1 && /^status:[[:space:]]/{print; exit}' "$ENTITY" | awk '{print $2}')"
if [ "$CURRENT_STATUS" = "$NEW_STATUS" ]; then
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

# Step 2: update-entity-status (advances status field)
# Re-read hash after Step 1 modified the file
H="$(sha256_of "$ENTITY")"
bash "${SCRIPT_DIR}/update-entity-status.sh" \
  --entity="$ENTITY" \
  --new-status="$NEW_STATUS" \
  --if-hash="$H" \
  --commit-as="${COMMIT_MSG}: advance status to ${NEW_STATUS}"
RC=$?
[ "$RC" -eq 0 ] || exit "$RC"

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
