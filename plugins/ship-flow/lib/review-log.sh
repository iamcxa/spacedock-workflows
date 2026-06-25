#!/usr/bin/env bash
# review-log.sh — per-entity review-log.jsonl operations for ship-verify
# Storage: <entity-folder>/review-log.jsonl
#
# Subcommands:
#   append <entity-folder> <json>
#     Append one JSON line to the entity's review log. Adds timestamp if missing.
#
#   last-round <entity-folder>
#     Print the highest `round` integer seen in the log (0 if no log).
#
#   read-suppressed <entity-folder>
#     Print fingerprints of findings the captain explicitly skipped in prior
#     rounds, one per line. Used by Phase F cross-round dedup.
#
#   read-all <entity-folder>
#     Print the raw log content (passthrough). For debugging or display.
#
# Snapshot 2026-05-12. Extracted into ship-flow plugin as lib/review-log.sh

set -eu

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required for review-log.sh; install jq" >&2
  exit 2
fi

CMD="${1:-}"
ENTITY_DIR="${2:-}"

if [ -z "$CMD" ] || [ -z "$ENTITY_DIR" ]; then
  echo "Usage: $0 <append|last-round|read-suppressed|read-all> <entity-folder> [json]" >&2
  exit 2
fi

if [ ! -d "$ENTITY_DIR" ]; then
  echo "ERROR: entity folder not found: $ENTITY_DIR" >&2
  exit 2
fi

LOG_FILE="$ENTITY_DIR/review-log.jsonl"

case "$CMD" in
  append)
    PAYLOAD="${3:-}"
    if [ -z "$PAYLOAD" ]; then
      echo "ERROR: append requires JSON payload as 3rd arg" >&2
      exit 2
    fi
    # Validate the payload is JSON; inject timestamp if missing.
    NORMALIZED=$(echo "$PAYLOAD" | jq -c \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      'if has("timestamp") then . else . + {timestamp: $ts} end')
    echo "$NORMALIZED" >> "$LOG_FILE"
    echo "Appended round: $(echo "$NORMALIZED" | jq -r '.round // "?"')"
    ;;

  last-round)
    if [ ! -f "$LOG_FILE" ]; then
      echo "0"
      exit 0
    fi
    # Max .round seen across all lines, default 0 if no .round field.
    jq -s '[.[] | .round // 0] | max // 0' "$LOG_FILE"
    ;;

  read-suppressed)
    if [ ! -f "$LOG_FILE" ]; then
      exit 0
    fi
    # Findings where action == "skipped" — emit fingerprints.
    # Each log entry has .findings array; flatten across all rounds.
    jq -r '
      .findings // []
      | map(select(.action == "skipped"))
      | .[]
      | .fingerprint
    ' "$LOG_FILE" 2>/dev/null | sort -u
    ;;

  read-all)
    if [ ! -f "$LOG_FILE" ]; then
      exit 0
    fi
    cat "$LOG_FILE"
    ;;

  *)
    echo "ERROR: unknown subcommand: $CMD" >&2
    echo "Usage: $0 <append|last-round|read-suppressed|read-all> <entity-folder> [json]" >&2
    exit 2
    ;;
esac
