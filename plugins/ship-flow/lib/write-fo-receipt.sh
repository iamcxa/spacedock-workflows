#!/usr/bin/env bash
# write-fo-receipt.sh - append an FO autonomous gate receipt ledger entry.
#
# Usage:
#   RECEIPT_FILE="$(mktemp "${TMPDIR:-/tmp}/fo-receipt.XXXXXX")"
#   bash plugins/ship-flow/lib/write-fo-receipt.sh \
#     --entity-folder docs/ship-flow/<entity-slug> \
#     --receipt-file "$RECEIPT_FILE" \
#     --transition-slug verify-proceed-auto-advance

set -uo pipefail

ENTITY_FOLDER=""
RECEIPT_FILE=""
TRANSITION_SLUG=""

captain_route() {
  echo "FO receipt writer requires captain route: $*" >&2
}

usage() {
  echo "Usage: write-fo-receipt.sh --entity-folder <folder> --receipt-file <file> --transition-slug <slug>" >&2
}

missing_option_value() {
  echo "Missing value for $1" >&2
  usage
  exit 1
}

require_option_value() {
  local option="$1"
  local value="${2:-}"
  if [ "$#" -lt 2 ] || [ -z "$value" ]; then
    missing_option_value "$option"
  fi
  case "$value" in
    --*)
      missing_option_value "$option"
      ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --entity-folder)
      require_option_value "$@"
      ENTITY_FOLDER="${2:-}"
      shift 2
      ;;
    --entity-folder=*)
      ENTITY_FOLDER="${1#--entity-folder=}"
      shift
      ;;
    --receipt-file)
      require_option_value "$@"
      RECEIPT_FILE="${2:-}"
      shift 2
      ;;
    --receipt-file=*)
      RECEIPT_FILE="${1#--receipt-file=}"
      shift
      ;;
    --transition-slug)
      require_option_value "$@"
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

file_hash() {
  local file="$1"
  if [ -f "$file" ]; then
    cksum "$file"
  else
    printf '%s\n' "__missing__"
  fi
}

trim_scalar() {
  printf '%s' "$1" | sed -E "s/^[[:space:]]+//; s/[[:space:]]+$//; s/^[\"']//; s/[\"']$//"
}

file_mode() {
  local file="$1"
  if stat -f '%OLp' "$file" >/dev/null 2>&1; then
    stat -f '%OLp' "$file"
  else
    stat -c '%a' "$file"
  fi
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

open_decisions_has_unsafe_value() {
  awk '
    function trim_safe_value(raw, value) {
      value = raw
      gsub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["\047]/, "", value)
      gsub(/["\047]$/, "", value)
      return tolower(value)
    }
    function is_empty_sentinel(raw, value) {
      value = trim_safe_value(raw)
      return value == "[]" || value == "{}" || value == "none" || value == "false" || value == "no" || value == "0"
    }
    BEGIN { in_open = 0; value = ""; found = 0; explicit_safe = 0 }
    /^open_decisions:[[:space:]]*/ {
      in_open = 1
      value = $0
      sub(/^open_decisions:[[:space:]]*/, "", value)
      value = trim_safe_value(value)
      if (value == "") next
      if (is_empty_sentinel(value)) {
        explicit_safe = 1
      } else {
        found = 1
      }
      next
    }
    in_open && /^[^[:space:]]/ { in_open = 0 }
    in_open {
      value = trim_safe_value($0)
      if (value == "") next
      if ($0 ~ /^[[:space:]]*-/ || !is_empty_sentinel(value)) {
        found = 1
      } else {
        explicit_safe = 1
      }
    }
    END { exit (found || !explicit_safe) ? 0 : 1 }
  ' "$RECEIPT_FILE"
}

blocker_scan_has_unsafe_value() {
  awk '
    function unsafe_blocker_value(raw, value) {
      value = raw
      gsub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["\047]/, "", value)
      gsub(/["\047]$/, "", value)
      value = tolower(value)
      return value != "" && value != "{}" && value != "none" && value != "false" && value != "no" && value != "0"
    }
    function safe_blocker_value(raw, value) {
      value = raw
      gsub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["\047]/, "", value)
      gsub(/["\047]$/, "", value)
      value = tolower(value)
      return value == "{}" || value == "none" || value == "false" || value == "no" || value == "0"
    }
    BEGIN { in_blockers = 0; found = 0; explicit_safe = 0 }
    /^blocker_scan:[[:space:]]*/ {
      in_blockers = 1
      value = $0
      sub(/^blocker_scan:[[:space:]]*/, "", value)
      if (safe_blocker_value(value)) {
        explicit_safe = 1
      } else if (unsafe_blocker_value(value)) {
        found = 1
      }
      next
    }
    in_blockers && /^[^[:space:]]/ { in_blockers = 0 }
    in_blockers {
      value = $0
      sub(/^[[:space:]]*-?[[:space:]]*/, "", value)
      if (value ~ /^[A-Za-z0-9_-]+:[[:space:]]*/) {
        sub(/^[A-Za-z0-9_-]+:[[:space:]]*/, "", value)
      }
      if (safe_blocker_value(value)) {
        explicit_safe = 1
      } else if (unsafe_blocker_value(value)) {
        found = 1
      }
    }
    END { exit (found || !explicit_safe) ? 0 : 1 }
  ' "$RECEIPT_FILE"
}

preconditions_have_fail_or_missing() {
  awk '
    BEGIN { in_preconditions = 0; found = 0 }
    /^preconditions:[[:space:]]*/ {
      in_preconditions = 1
      next
    }
    in_preconditions && /^[^[:space:]]/ { in_preconditions = 0 }
    in_preconditions && /^[[:space:]]*status:[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]*status:[[:space:]]*/, "", value)
      gsub(/#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["\047]/, "", value)
      gsub(/["\047]$/, "", value)
      value = tolower(value)
      if (value == "fail" || value == "missing") found = 1
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

  for key in receipt_id created_at actor transition decision verdict rule_source evidence preconditions blocker_scan open_decisions next_action; do
    if ! has_top_level_key "$key"; then
      echo "Receipt payload missing required top-level key: $key" >&2
      exit 4
    fi
  done

  decision="$(trim_scalar "$(top_level_value decision)")"
  if [ "$decision" = "self-approved" ]; then
    if preconditions_have_fail_or_missing; then
      captain_route "self-approved receipt has failing or missing preconditions"
      exit 5
    fi
    if blocker_scan_has_unsafe_value; then
      captain_route "self-approved receipt has unsafe blocker_scan value"
      exit 5
    fi
    if open_decisions_has_unsafe_value; then
      captain_route "self-approved receipt has open decisions"
      exit 5
    fi
  fi
}

append_receipt() {
  local ledger="$ENTITY_FOLDER/fo-receipts.md"
  local receipt_id before_hash current_hash tmp attempt ledger_mode
  receipt_id="$(trim_scalar "$(top_level_value receipt_id)")"

  attempt=1
  while [ "$attempt" -le 2 ]; do
    before_hash="$(file_hash "$ledger")"
    if [ -f "$ledger" ]; then
      ledger_mode="$(file_mode "$ledger")" || exit 6
    else
      ledger_mode="644"
    fi
    tmp="$(mktemp "${ENTITY_FOLDER}/.fo-receipts.XXXXXX")" || exit 6
    if ! chmod "$ledger_mode" "$tmp"; then
      rm -f "$tmp"
      captain_route "could not prepare receipt ledger mode"
      exit 6
    fi

    if [ -f "$ledger" ]; then
      if ! cat "$ledger" > "$tmp"; then
        rm -f "$tmp"
        captain_route "could not read existing ledger before append"
        exit 6
      fi
      if ! printf '\n' >> "$tmp"; then
        rm -f "$tmp"
        captain_route "could not prepare receipt ledger append"
        exit 6
      fi
    else
      if ! printf '# FO Receipts\n\n' > "$tmp"; then
        rm -f "$tmp"
        captain_route "could not initialize receipt ledger"
        exit 6
      fi
    fi

    if ! printf '## %s\n\n' "$receipt_id" >> "$tmp"; then
      rm -f "$tmp"
      captain_route "could not append receipt payload"
      exit 6
    fi
    if ! printf '```yaml receipt\n' >> "$tmp"; then
      rm -f "$tmp"
      captain_route "could not append receipt payload"
      exit 6
    fi
    if ! cat "$RECEIPT_FILE" >> "$tmp"; then
      rm -f "$tmp"
      captain_route "could not append receipt payload"
      exit 6
    fi
    if ! printf '\n```\n' >> "$tmp"; then
      rm -f "$tmp"
      captain_route "could not append receipt payload"
      exit 6
    fi

    current_hash="$(file_hash "$ledger")"
    if [ "$before_hash" = "$current_hash" ]; then
      if mv "$tmp" "$ledger"; then
        return 0
      fi
      rm -f "$tmp"
      captain_route "could not move receipt ledger into place"
      exit 6
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
