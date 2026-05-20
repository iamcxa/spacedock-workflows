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

if command -v ruby >/dev/null 2>&1; then
  check "entity-body-schema.yaml parses as YAML" \
    "ruby -e 'require \"yaml\"; YAML.safe_load(File.read(ARGV.fetch(0)))' \"$SCHEMA_PATH\""

  check "verify verdict status enum allows blocked outcome" \
    "ruby -e 'require \"yaml\"; schema = YAML.safe_load(File.read(ARGV.fetch(0))); fields = schema.fetch(\"stages\").fetch(\"verify\").fetch(\"output\").fetch(\"subsections\").fetch(\"verdict\").fetch(\"fields\"); status = fields.find { |field| field[\"name\"] == \"status\" }; abort(\"missing status field\") unless status; values = status.fetch(\"values\"); abort(\"missing blocked\") unless values.include?(\"blocked\")' \"$SCHEMA_PATH\""

  check "verify verdict fields retain duration_minutes" \
    "ruby -e 'require \"yaml\"; schema = YAML.safe_load(File.read(ARGV.fetch(0))); fields = schema.fetch(\"stages\").fetch(\"verify\").fetch(\"output\").fetch(\"subsections\").fetch(\"verdict\").fetch(\"fields\"); abort(\"missing duration_minutes\") unless fields.any? { |field| field[\"name\"] == \"duration_minutes\" }' \"$SCHEMA_PATH\""

  check "execute report status enum allows partial outcome" \
    "ruby -e 'require \"yaml\"; schema = YAML.safe_load(File.read(ARGV.fetch(0))); fields = schema.fetch(\"stages\").fetch(\"execute\").fetch(\"report\").fetch(\"fields\"); status = fields.find { |field| field[\"name\"] == \"status\" }; abort(\"missing status field\") unless status; values = status.fetch(\"values\"); abort(\"missing partial\") unless values.include?(\"partial\")' \"$SCHEMA_PATH\""

  check "stage metrics status enums are subsets of parent report status enums" \
    "ruby -e 'require \"yaml\"; schema = YAML.safe_load(File.read(ARGV.fetch(0))); schema.fetch(\"stages\").each do |stage, data| container = data[\"report\"] || data.dig(\"output\", \"subsections\", \"verdict\"); next unless container && container.dig(\"subsections\", \"metrics\"); parent_status = container.fetch(\"fields\").find { |field| field[\"name\"] == \"status\" }; metrics_status = container.fetch(\"subsections\").fetch(\"metrics\").fetch(\"fields\").find { |field| field[\"name\"] == \"status\" }; next unless parent_status && metrics_status; missing = metrics_status.fetch(\"values\") - parent_status.fetch(\"values\"); abort(\"#{stage} missing #{missing.join(\",\")}\") unless missing.empty?; end' \"$SCHEMA_PATH\""
else
  echo "  SKIP: ruby unavailable; YAML parse assertions skipped"
fi

check "stage metrics subsections documented for shape through review" \
  "grep -q 'metrics:' \"$SCHEMA_PATH\" && grep -q 'section: \"### Metrics\"' \"$SCHEMA_PATH\" && grep -q 'open_contract_decisions_count' \"$SCHEMA_PATH\" && grep -q 'captain_decisions_count' \"$SCHEMA_PATH\" && grep -q 'verification_spec_count' \"$SCHEMA_PATH\" && grep -q 'tasks_done' \"$SCHEMA_PATH\" && grep -q 'runtime_checks_count' \"$SCHEMA_PATH\" && grep -q 'canonical_docs_updated_count' \"$SCHEMA_PATH\""

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
