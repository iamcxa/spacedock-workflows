#!/usr/bin/env bash
# test-entity-body-schema.sh — Assert hand_off_to blocks present in entity-body-schema.yaml
# Entity: #106 pipeline-render-fidelity-hardening Wave 1 T1.1
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-entity-body-schema.sh
#   bash plugins/ship-flow/lib/__tests__/test-entity-body-schema.sh --schema-path <path>

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# --- Arg parsing ---
SCHEMA_PATH="${SCRIPT_DIR}/../../../../plugins/ship-flow/references/entity-body-schema.yaml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema-path) SCHEMA_PATH="$2"; shift 2 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ ! -f "$SCHEMA_PATH" ]; then
  echo "ERROR: schema file not found: $SCHEMA_PATH" >&2
  exit 2
fi

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

echo "=== entity-body-schema.yaml hand_off_to assertions ==="
echo "Schema: $SCHEMA_PATH"
echo ""

# --- Assert all 6 hand_off_to blocks are defined ---
check "hand_off_to_design block present" \
  "grep -q 'hand_off_to_design' \"$SCHEMA_PATH\""

check "hand_off_to_plan block present" \
  "grep -q 'hand_off_to_plan' \"$SCHEMA_PATH\""

check "hand_off_to_execute block present" \
  "grep -q 'hand_off_to_execute' \"$SCHEMA_PATH\""

check "hand_off_to_verify block present" \
  "grep -q 'hand_off_to_verify' \"$SCHEMA_PATH\""

check "hand_off_to_review block present" \
  "grep -q 'hand_off_to_review' \"$SCHEMA_PATH\""

check "hand_off_to_ship block present" \
  "grep -q 'hand_off_to_ship' \"$SCHEMA_PATH\""

# --- Assert count is at least 6 ---
check "at least 6 hand_off_to definitions total" \
  "[ \$(grep -c 'hand_off_to_' \"$SCHEMA_PATH\" || echo 0) -ge 6 ]"

check "reviewer_output_matrix file_line documents nullable contract for non-findings invalid context and degraded rows" \
  "grep -q 'file_line: \"<path:line|null>\"' \"$SCHEMA_PATH\" && grep -q 'file_line_nullable_for.*NO_FINDINGS.*INVALID_CONTEXT.*DEGRADED' \"$SCHEMA_PATH\""

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "All assertions passed — entity-body-schema.yaml hand_off_to blocks valid."
exit 0
