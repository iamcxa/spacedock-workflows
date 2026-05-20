#!/usr/bin/env bash
# test-parity-dc-contract.sh — Assert parity DC vocabulary and evidence contracts.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

PLAN_SKILL="${PLUGIN_ROOT}/skills/ship-plan/SKILL.md"
VERIFY_SKILL="${PLUGIN_ROOT}/skills/ship-verify/SKILL.md"
UI_VERIFY_SKILL="${PLUGIN_ROOT}/skills/ui-verify/SKILL.md"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${desc}"
    FAIL=$((FAIL + 1))
    ERRORS+=("${desc}")
  fi
}

echo "=== test-parity-dc-contract.sh ==="
echo ""

echo "Block 1: first-class parity DC vocabulary"
check "ship-plan names design-system-parity and mockup-parity" \
  "grep -q 'design-system-parity' '${PLAN_SKILL}' && grep -q 'mockup-parity' '${PLAN_SKILL}'"
check "ship-verify names design-system-parity and mockup-parity" \
  "grep -q 'design-system-parity' '${VERIFY_SKILL}' && grep -q 'mockup-parity' '${VERIFY_SKILL}'"

echo "Block 2: design-system-parity runtime evidence"
check "ship-verify requires actual_computed_value" \
  "grep -q 'actual_computed_value' '${VERIFY_SKILL}'"
check "ship-verify requires design-system-parity token comparison fields" \
  "grep -q 'token_source' '${VERIFY_SKILL}' && grep -q 'expected_token' '${VERIFY_SKILL}' && grep -q 'expected_resolved_value' '${VERIFY_SKILL}'"
check "ship-verify rejects artifact-only design-system-parity claims" \
  "grep -qiE 'design-system-parity.*artifact-only|artifact-only.*design-system-parity' '${VERIFY_SKILL}'"

echo "Block 3: mockup-parity runtime evidence"
check "ship-verify requires actual_dom_structure" \
  "grep -q 'actual_dom_structure' '${VERIFY_SKILL}'"
check "ship-verify requires mockup-parity DOM comparison fields" \
  "grep -q 'mockup_artifact' '${VERIFY_SKILL}' && grep -q 'root_selector' '${VERIFY_SKILL}' && grep -q 'expected_structure' '${VERIFY_SKILL}' && grep -q 'comparison_method' '${VERIFY_SKILL}'"
check "ship-verify rejects artifact-only mockup-parity claims" \
  "grep -qiE 'mockup-parity.*artifact-only|artifact-only.*mockup-parity' '${VERIFY_SKILL}'"

echo "Block 4: ui-verify boundary"
check "ui-verify documents design-system-parity computed-style substrate" \
  "grep -q 'design-system-parity' '${UI_VERIFY_SKILL}' && grep -q 'actual_computed_value' '${UI_VERIFY_SKILL}' && grep -q 'getComputedStyle' '${UI_VERIFY_SKILL}'"
check "ui-verify documents mockup-parity non-ownership" \
  "grep -q 'mockup-parity' '${UI_VERIFY_SKILL}' && grep -qiE 'outside fixed selector/value checks|does not own.*mockup|not.*mockup-parity' '${UI_VERIFY_SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed — parity DC contracts are documented."
exit 0
