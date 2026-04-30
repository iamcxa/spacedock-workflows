#!/usr/bin/env bash
# test-shape-domain-validation.sh — contract for 113.5 shape-stage domain validation
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-shape-domain-validation.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
SKILL_FILE="${PLUGIN_ROOT}/skills/ship-shape/SKILL.md"

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

echo "=== test-shape-domain-validation.sh ==="
echo ""

echo "Block 1: shape has a named domain-registry validation gate"
check "ship-shape SKILL.md includes Domain Registry Validation evidence heading" \
  "grep -q 'Domain Registry Validation' '${SKILL_FILE}'"

echo "Block 2: shape classification is mandatory for possible non-UI domains"
check "ship-shape instructs registry-resolve.sh --classify against spec/entity file" \
  "grep -qE 'registry-resolve\\.sh --classify <(spec-or-entity-file|entity-folder>/spec\\.md|.*spec.*entity)' '${SKILL_FILE}'"
check "classification result writes domain: <name> at shape stage" \
  "grep -qE 'domain: <(name|domain)>|set \`domain: <[^\`]+>\`|set \`domain: [^\`]+\`' '${SKILL_FILE}'"

echo "Block 3: explicit captain/shape domain values are validated at shape gate"
check "ship-shape validates explicit domain via registry-resolve.sh --validate --domain=<domain>" \
  "grep -qE 'registry-resolve\\.sh --validate --domain=<domain>' '${SKILL_FILE}'"
check "invalid or missing-specialist validation blocks at shape gate with HALT-with-options" \
  "grep -qE 'HALT-with-options' '${SKILL_FILE}' && grep -qE 'specialist_missing|knowledge_module_missing|parse_error|invalid_trigger_config' '${SKILL_FILE}'"

echo "Block 4: evidence output remains grep-friendly"
check "shape output records classify command evidence" \
  "awk '/Domain Registry Validation/{in_block=1; next} in_block && /^## /{in_block=0} in_block && /registry-resolve\\.sh --classify/{found=1} END{exit !found}' '${SKILL_FILE}'"
check "shape output records validate command evidence" \
  "awk '/Domain Registry Validation/{in_block=1; next} in_block && /^## /{in_block=0} in_block && /registry-resolve\\.sh --validate --domain=<domain>/{found=1} END{exit !found}' '${SKILL_FILE}'"
check "shape output records resolved domain evidence" \
  "awk '/Domain Registry Validation/{in_block=1; next} in_block && /^## /{in_block=0} in_block && /domain: <name>/{found=1} END{exit !found}' '${SKILL_FILE}'"
check "shape output records HALT-with-options evidence for blocked validation" \
  "awk '/Domain Registry Validation/{in_block=1; next} in_block && /^## /{in_block=0} in_block && /HALT-with-options/{found=1} END{exit !found}' '${SKILL_FILE}'"

echo "Block 5: stale HALT resolution is explicit"
check "ship-shape defines Registry Validation Resolution block for superseded HALT evidence" \
  "grep -q 'Registry Validation Resolution' '${SKILL_FILE}'"
check "resolution block records superseded_by_design_stage_validation" \
  "grep -q 'superseded_by_design_stage_validation' '${SKILL_FILE}'"
check "unresolved shape HALT remains blocking evidence" \
  "grep -q 'otherwise a shape \`HALT-with-options\` remains blocking evidence' '${SKILL_FILE}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
exit 0
