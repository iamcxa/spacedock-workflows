#!/usr/bin/env bash
# test-canonical-context-lifecycle.sh - canonical docs are read and maintained across stages.
# HOST ARTIFACTS: docs/ship-flow/ entities, .claude/settings.json, or plugins/spacebridge/ — not present in standalone clone.
# Run only from the dogfood host project. See lib/__tests__/integration/README.md

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../../.." &> /dev/null && pwd)"

README="${REPO_ROOT}/docs/ship-flow/README.md"
TEMPLATE="${REPO_ROOT}/plugins/ship-flow/workflow-template.yaml"
SHAPE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-shape/SKILL.md"
DESIGN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-design/SKILL.md"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
REVIEW_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-review/SKILL.md"
CANONICAL_MOD="${REPO_ROOT}/docs/ship-flow/_mods/canonical-doc-sync.md"

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

echo "=== test-canonical-context-lifecycle.sh ==="
echo ""

check "README states canonical context control-plane meaning" \
  "grep -q 'Canonical context control plane' '${README}' && grep -q 'ROADMAP.md' '${README}' && grep -q 'PRODUCT.md' '${README}' && grep -q 'ARCHITECTURE.md' '${README}'"

check "workflow template shape description reads all canonical context docs" \
  "grep -q 'Reads PRODUCT.md + ROADMAP.md + ARCHITECTURE.md' '${TEMPLATE}'"

check "shape reads product and roadmap, and emits canonical intent instead of direct patches" \
  "grep -q 'Canonical context preflight' '${SHAPE_SKILL}' && grep -q 'PRODUCT.md' '${SHAPE_SKILL}' && grep -q 'ROADMAP.md' '${SHAPE_SKILL}' && grep -q 'ARCHITECTURE.md' '${SHAPE_SKILL}' && grep -q 'emit architecture-impact' '${SHAPE_SKILL}' && grep -q 'emit product-impact' '${SHAPE_SKILL}'"

check "design has a canonical context preflight for contract-bearing work" \
  "grep -q 'Canonical context preflight' '${DESIGN_SKILL}' && grep -q 'contract-bearing' '${DESIGN_SKILL}' && grep -q 'ARCHITECTURE.md' '${DESIGN_SKILL}' && grep -q 'PRODUCT.md' '${DESIGN_SKILL}' && grep -q 'canonical_context' '${DESIGN_SKILL}'"

check "design_required is a first-class design trigger in shape and design" \
  "grep -q 'design_required: true' '${DESIGN_SKILL}' && grep -q '!affects_ui && !domain && !design_required' '${DESIGN_SKILL}' && grep -q 'design_required: false' '${SHAPE_SKILL}' && grep -q '!affects_ui && !domain && !design_required' '${SHAPE_SKILL}' && grep -q 'affects_ui:true OR domain: OR design_required:true' '${SHAPE_SKILL}' && grep -q 'Conditional design-stage trigger' '${SHAPE_SKILL}' && grep -q 'design_required:true' '${SHAPE_SKILL}'"

check "plan turns canonical context into task-level update or skip decisions" \
  "grep -q 'Canonical context planning' '${PLAN_SKILL}' && grep -q 'canonical_doc_actions' '${PLAN_SKILL}' && grep -q 'ARCHITECTURE.md' '${PLAN_SKILL}' && grep -q 'PRODUCT.md' '${PLAN_SKILL}' && grep -q 'skip_rationale' '${PLAN_SKILL}'"

check "verify checks architecture drift when touched files trigger canonical review" \
  "grep -q 'Canonical drift check' '${VERIFY_SKILL}' && grep -q 'ARCHITECTURE.md' '${VERIFY_SKILL}' && grep -q 'canonical_doc_actions' '${VERIFY_SKILL}' && grep -q 'route_to: review' '${VERIFY_SKILL}'"

check "review remains the canonical write gate and blocks silent omissions" \
  "grep -q 'Canonical docs update' '${REVIEW_SKILL}' && grep -q 'Silent omission' '${CANONICAL_MOD}' && grep -q 'ARCHITECTURE.md' '${REVIEW_SKILL}' && grep -q 'PRODUCT.md' '${REVIEW_SKILL}' && grep -q 'ROADMAP.md' '${REVIEW_SKILL}'"

check "review consumes plan canonical_doc_actions at write gate" \
  "grep -q 'canonical_doc_actions' '${REVIEW_SKILL}' && grep -q 'source: plan' '${REVIEW_SKILL}' && grep -q 'source: touched-files' '${REVIEW_SKILL}'"

check "ship SOT names architecture updates with roadmap and product" \
  "grep -q 'ROADMAP.md + PRODUCT.md + ARCHITECTURE.md updates' '${TEMPLATE}' && grep -q 'ARCHITECTURE.md Update' '${README}' && grep -q 'ARCHITECTURE.md updated' '${README}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
