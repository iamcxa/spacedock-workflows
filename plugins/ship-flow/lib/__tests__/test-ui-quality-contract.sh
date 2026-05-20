#!/usr/bin/env bash
# test-ui-quality-contract.sh - ship-flow UI quality contract distillation.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

REFERENCE="${REPO_ROOT}/plugins/ship-flow/references/ui-quality-contract.md"
DESIGN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-design/SKILL.md"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"

CONTRACT_SURFACES=(
  "${REFERENCE}"
  "${DESIGN_SKILL}"
  "${PLAN_SKILL}"
  "${VERIFY_SKILL}"
  "${SCHEMA}"
)

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

assert_no_forbidden_runtime_coupling() {
  local file="$1"
  ! grep -Eq '/Users/kent/\.claude|_archive|/gsd-ui-phase|/gsd-ui-review|UI-SPEC\.md|\.planning/' "$file"
}

assert_no_new_harness_requirement() {
  local file="$1"
  ! grep -Eiq 'new screenshot harness|new browser harness|requires Playwright|requires browser screenshot' "$file"
}

echo "=== test-ui-quality-contract.sh ==="
echo ""

echo "Block 1: reusable reference"
check "ui quality contract reference exists" \
  "test -f '${REFERENCE}'"

for field in copy visual_hierarchy color typography spacing interaction_states source_safety; do
  check "reference defines ${field}" \
    "grep -q '${field}' '${REFERENCE}'"
done

check "reference documents stage ownership" \
  "grep -q 'Design declares' '${REFERENCE}' && grep -q 'Plan imports' '${REFERENCE}' && grep -q 'Verify audits' '${REFERENCE}'"

check "reference documents evidence or explicit N/A" \
  "grep -q 'evidence or explicit N/A' '${REFERENCE}'"

echo ""
echo "Block 2: design handoff emission"
check "ship-design references ui_quality_contract and reference file" \
  "grep -q 'ui_quality_contract' '${DESIGN_SKILL}' && grep -q 'references/ui-quality-contract.md' '${DESIGN_SKILL}'"

for field in copy visual_hierarchy color typography spacing interaction_states source_safety; do
  check "ship-design names ${field}" \
    "grep -q '${field}' '${DESIGN_SKILL}'"
done

echo ""
echo "Block 3: plan import consumption"
check "ship-plan references ui_quality_contract and reference file" \
  "grep -q 'ui_quality_contract' '${PLAN_SKILL}' && grep -q 'references/ui-quality-contract.md' '${PLAN_SKILL}'"

check "ship-plan turns contract groups into DCs or reviewer questions" \
  "grep -q 'DCs' '${PLAN_SKILL}' && grep -q 'reviewer questions' '${PLAN_SKILL}' && grep -q 'explicit N/A' '${PLAN_SKILL}'"

for field in copy visual_hierarchy color typography spacing interaction_states source_safety; do
  check "ship-plan names ${field}" \
    "grep -q '${field}' '${PLAN_SKILL}'"
done

echo ""
echo "Block 4: verify evidence consumption"
check "ship-verify references ui_quality_contract and reference file" \
  "grep -q 'ui_quality_contract' '${VERIFY_SKILL}' && grep -q 'references/ui-quality-contract.md' '${VERIFY_SKILL}'"

check "ship-verify requires evidence or explicit N/A" \
  "grep -q 'evidence or explicit N/A' '${VERIFY_SKILL}'"

for field in copy visual_hierarchy color typography spacing interaction_states source_safety; do
  check "ship-verify names ${field}" \
    "grep -q '${field}' '${VERIFY_SKILL}'"
done

echo ""
echo "Block 5: schema allowance"
check "entity body schema allows ui_quality_contract in design handoff" \
  "awk '/hand_off_to_plan:/{in_block=1} in_block && /^  plan:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'ui_quality_contract'"

echo ""
echo "Block 6: boundaries"
for surface in "${CONTRACT_SURFACES[@]}"; do
  check "$(basename "$surface") has no archived GSD runtime coupling" \
    "assert_no_forbidden_runtime_coupling '${surface}'"
done

for surface in "${REFERENCE}" "${DESIGN_SKILL}" "${PLAN_SKILL}" "${VERIFY_SKILL}"; do
  check "$(basename "$surface") does not require a new browser/screenshot harness" \
    "assert_no_new_harness_requirement '${surface}'"
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
