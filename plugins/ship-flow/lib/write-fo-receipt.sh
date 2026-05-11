#!/usr/bin/env bash
# write-fo-receipt.sh - append an FO autonomous gate receipt ledger entry.
#
# Usage:
#   bash plugins/ship-flow/lib/write-fo-receipt.sh \
#     --entity-folder docs/ship-flow/<entity-slug> \
#     --receipt-file /tmp/receipt.yml \
#     --transition-slug verify-proceed-auto-advance

set -uo pipefail

ENTITY_FOLDER=""
RECEIPT_FILE=""
TRANSITION_SLUG=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --entity-folder)
      ENTITY_FOLDER="${2:-}"
      shift 2
      ;;
    --entity-folder=*)
      ENTITY_FOLDER="${1#--entity-folder=}"
      shift
      ;;
    --receipt-file)
      RECEIPT_FILE="${2:-}"
      shift 2
      ;;
    --receipt-file=*)
      RECEIPT_FILE="${1#--receipt-file=}"
      shift
      ;;
    --transition-slug)
      TRANSITION_SLUG="${2:-}"
      shift 2
      ;;
    --transition-slug=*)
      TRANSITION_SLUG="${1#--transition-slug=}"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

captain_route() {
  echo "FO receipt writer requires captain route: $*" >&2
}

usage() {
  echo "Usage: write-fo-receipt.sh --entity-folder <folder> --receipt-file <file> --transition-slug <slug>" >&2
}

file_hash() {
  local file="$1"
  if [ -f "$file" ]; then
    cksum "$file"
  else
    printf '%s\n' "__missing__"
  fi
}

trim_scalar() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^"//; s/"$//'
}

top_level_value() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ ("^" key ":[[:space:]]*") {
      sub("^[^:]+:[[:space:]]*", "", $0)
      print
      exit
    }
  ' "$RECEIPT_FILE"
}

has_top_level_key() {
  local key="$1"
  grep -Eq "^${key}:" "$RECEIPT_FILE"
}

open_decisions_non_empty() {
  awk '
    BEGIN { in_open = 0; value = ""; found = 0 }
    /^open_decisions:[[:space:]]*/ {
      in_open = 1
      value = $0
      sub(/^open_decisions:[[:space:]]*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value != "" && value != "[]" && value != "null" && value != "\"\"") found = 1
      next
    }
    in_open && /^[^[:space:]]/ { in_open = 0 }
    in_open && /^[[:space:]]*-/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$RECEIPT_FILE"
}

blocker_scan_has_truthy_boolean() {
  awk '
    BEGIN { in_blockers = 0; found = 0 }
    /^blocker_scan:[[:space:]]*/ {
      in_blockers = 1
      value = $0
      sub(/^blocker_scan:[[:space:]]*/, "", value)
      gsub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      value = tolower(value)
      if (value == "true" || value == "yes" || value == "on" || value == "1") found = 1
      next
    }
    in_blockers && /^[^[:space:]]/ { in_blockers = 0 }
    in_blockers && /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*/, "", value)
      gsub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      value = tolower(value)
      if (value == "true" || value == "yes" || value == "on" || value == "1") found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$RECEIPT_FILE"
}

validate_args() {
  if [ -z "$ENTITY_FOLDER" ] || [ -z "$RECEIPT_FILE" ] || [ -z "$TRANSITION_SLUG" ]; then
    usage
    exit 1
  fi
  if [ ! -d "$ENTITY_FOLDER" ] || [ ! -f "$ENTITY_FOLDER/index.md" ]; then
    captain_route "first-slice FO receipts support only folder-layout entities containing index.md"
    exit 2
  fi
  if [ ! -f "$RECEIPT_FILE" ]; then
    echo "Receipt payload not found: $RECEIPT_FILE" >&2
    exit 3
  fi
}

validate_receipt() {
  local first_line receipt_id decision key
  first_line="$(awk 'NF { print; exit }' "$RECEIPT_FILE")"
  case "$first_line" in
    receipt_id:*) ;;
    *)
      echo "Receipt payload first non-empty line must be receipt_id" >&2
      exit 4
      ;;
  esac

  receipt_id="$(trim_scalar "${first_line#receipt_id:}")"
  if [ -z "$receipt_id" ]; then
    echo "Receipt payload receipt_id must not be empty" >&2
    exit 4
  fi
  case "$receipt_id" in
    *-"$TRANSITION_SLUG") ;;
    *)
      echo "Receipt id must end with transition slug: $TRANSITION_SLUG" >&2
      exit 4
      ;;
  esac

  for key in receipt_id created_at actor transition decision verdict rule_source evidence preconditions blocker_scan next_action; do
    if ! has_top_level_key "$key"; then
      echo "Receipt payload missing required top-level key: $key" >&2
      exit 4
    fi
  done

  decision="$(trim_scalar "$(top_level_value decision)")"
  if [ "$decision" = "self-approved" ]; then
    if grep -Eq '^[[:space:]]*status:[[:space:]]*(fail|missing)([[:space:]]|$)' "$RECEIPT_FILE"; then
      captain_route "self-approved receipt has failing or missing preconditions"
      exit 5
    fi
    if grep -Eq '^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*found([[:space:]]|$)' "$RECEIPT_FILE"; then
      captain_route "self-approved receipt has blocker_scan findings"
      exit 5
    fi
    if blocker_scan_has_truthy_boolean; then
      captain_route "self-approved receipt has truthy blocker_scan boolean"
      exit 5
    fi
    if open_decisions_non_empty; then
      captain_route "self-approved receipt has open decisions"
      exit 5
    fi
  fi
}

append_receipt() {
  local ledger="$ENTITY_FOLDER/fo-receipts.md"
  local receipt_id before_hash current_hash tmp attempt
  receipt_id="$(trim_scalar "$(top_level_value receipt_id)")"

  attempt=1
  while [ "$attempt" -le 2 ]; do
    before_hash="$(file_hash "$ledger")"
    tmp="$(mktemp "${ENTITY_FOLDER}/.fo-receipts.XXXXXX")" || exit 6

    if [ -f "$ledger" ]; then
      cat "$ledger" > "$tmp"
      printf '\n' >> "$tmp"
    else
      printf '# FO Receipts\n\n' > "$tmp"
    fi

    {
      printf '## %s\n\n' "$receipt_id"
      printf '```yaml receipt\n'
      cat "$RECEIPT_FILE"
      printf '\n```\n'
    } >> "$tmp"

    current_hash="$(file_hash "$ledger")"
    if [ "$before_hash" = "$current_hash" ]; then
      mv "$tmp" "$ledger"
      return 0
    fi

    rm -f "$tmp"
    attempt=$((attempt + 1))
  done

  captain_route "fo-receipts.md changed during append; retry with fresh evidence"
  exit 6
}

validate_args
validate_receipt
append_receipt
