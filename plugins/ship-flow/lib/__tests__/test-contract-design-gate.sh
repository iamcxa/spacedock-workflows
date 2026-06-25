#!/usr/bin/env bash
# test-contract-design-gate.sh — non-UI contract decisions route through design.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
README="${REPO_ROOT}/docs/ship-flow/README.md"
SHAPE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-shape/SKILL.md"
DESIGN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-design/SKILL.md"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
CONTRACT_DOMAINS="agent-contract api-vocabulary selector-grammar tool-protocol dsl message-format"

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

echo "=== test-contract-design-gate.sh ==="
echo ""

echo "Block 1: schema exposes non-UI contract decisions"
check "frontmatter exposes contract_decision_required as a design trigger" \
  "grep -q 'contract_decision_required' '${SCHEMA}' && grep -q 'set_at: shape' '${SCHEMA}'"
check "shape hand-off schema exposes open_contract_decisions" \
  "grep -q 'open_contract_decisions' '${SCHEMA}' && grep -q 'selector grammar' '${SCHEMA}'"

echo "Block 2: shape routes unresolved contract choices to design"
check "shape names selector grammar/API vocabulary/protocol as contract-design triggers" \
  "grep -q 'selector grammar' '${SHAPE_SKILL}' && grep -q 'API vocabulary' '${SHAPE_SKILL}' && grep -q 'protocol' '${SHAPE_SKILL}'"
check "shape sets contract_decision_required when open contract decisions exist" \
  "grep -q 'contract_decision_required: true' '${SHAPE_SKILL}' && grep -q 'open_contract_decisions\\[\\]' '${SHAPE_SKILL}'"
check "shape design skip gate includes contract_decision_required" \
  "grep -q '!contract_decision_required' '${SHAPE_SKILL}' && grep -q 'advance to design stage' '${SHAPE_SKILL}'"

echo "Block 3: design resolves contract decisions before plan"
check "ship-design trigger accepts contract_decision_required" \
  "grep -q 'contract_decision_required: true' '${DESIGN_SKILL}' && grep -q '!contract_decision_required' '${DESIGN_SKILL}'"
check "ship-design has a contract/interface designer lane" \
  "grep -q 'contract/interface-designer' '${DESIGN_SKILL}' && grep -q 'selector grammar' '${DESIGN_SKILL}'"
check "ship-design requires open_contract_decisions to become captain decisions or open_decisions" \
  "grep -q 'open_contract_decisions' '${DESIGN_SKILL}' && grep -q 'Captain Decisions' '${DESIGN_SKILL}' && grep -q 'open_decisions\\[\\]' '${DESIGN_SKILL}'"

echo "Block 4: plan blocks if shape skipped design with unresolved contract decisions"
check "ship-plan blocks design-skipped handoff with unresolved open_contract_decisions" \
  "grep -q 'open_contract_decisions' '${PLAN_SKILL}' && grep -q 'design-bearing decision skipped' '${PLAN_SKILL}'"
check "ship-plan treats design-skipped valid only when no contract_decision_required" \
  "grep -q 'contract_decision_required: false' '${PLAN_SKILL}' && grep -q 'design-skipped' '${PLAN_SKILL}'"
check "ship-plan treats design-skipped valid only when no domain or design_required signal exists" \
  "grep -q 'domain.*unset' '${PLAN_SKILL}' && grep -q 'design_required: false' '${PLAN_SKILL}' && grep -q 'design-bearing decision skipped' '${PLAN_SKILL}'"

echo "Block 6: registry-backed contract domains route to contract-interface design"
check "shape documents registry-backed contract domains as no-UI/no-schema design triggers" \
  "grep -q 'registry-backed contract domains' '${SHAPE_SKILL}' && grep -q 'no UI or schema trigger' '${SHAPE_SKILL}'"
check "shape names the full portable contract domain set" \
  "for domain in ${CONTRACT_DOMAINS}; do grep -q \"\${domain}\" '${SHAPE_SKILL}' || exit 1; done"
check "shape handles comma-separated contract domain matches" \
  "grep -q 'comma-separated' '${SHAPE_SKILL}' && grep -q 'split the matched list' '${SHAPE_SKILL}' && grep -q 'any matched domain' '${SHAPE_SKILL}'"
check "shape says matched contract domains set contract_decision_required true" \
  "grep -q 'contract_decision_required:true' '${SHAPE_SKILL}' && grep -q 'registry evidence' '${SHAPE_SKILL}'"
check "ship-design exposes the contract-interface designer anchor" \
  "grep -q 'ship-design#contract-interface-designer' '${DESIGN_SKILL}' && grep -q 'Contract Interface Designer' '${DESIGN_SKILL}'"
check "ship-design maps registry contract domains to the existing contract-interface lane" \
  "grep -q 'registry target for portable contract/interface domains' '${DESIGN_SKILL}' && grep -q 'contract-interface lane' '${DESIGN_SKILL}'"
check "ship-design excludes contract-interface anchor domains from generic domain specialist path" \
  "grep -q 'skip the generic domain specialist path' '${DESIGN_SKILL}' && grep -q 'contract-interface anchor' '${DESIGN_SKILL}'"
check "ship-design keeps empty knowledge modules scoped to contract-interface anchor only" \
  "grep -q 'does not make empty knowledge modules generally acceptable' '${DESIGN_SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
