#!/usr/bin/env bash
# test-workflow-sot-sync.sh - dogfood README and adopter template stay current.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
DOGFOOD_README="${REPO_ROOT}/docs/ship-flow/README.md"
TEMPLATE="${REPO_ROOT}/plugins/ship-flow/workflow-template.yaml"
PLUGIN_README="${REPO_ROOT}/plugins/ship-flow/README.md"

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

echo "=== test-workflow-sot-sync.sh ==="
echo ""

check "dogfood README states design is mandatory for design-bearing work" \
  "grep -q 'Design is mandatory for UI work, matched-domain work, or any change with schema/API/domain/architecture contract impact' '${DOGFOOD_README}'"

check "dogfood README frontmatter uses design-bearing skip semantics" \
  "grep -q 'skip-when: \"!affects_ui && !domain && !design_required\"' '${DOGFOOD_README}'"

check "dogfood README includes design.md in pipeline artifacts" \
  "grep -q 'design.md' '${DOGFOOD_README}' && grep -q 'Design Intent' '${DOGFOOD_README}'"

check "dogfood README frontmatter allows routed verify feedback" \
  "grep -q 'feedback-to: \"execute|design|plan|follow-up\"' '${DOGFOOD_README}'"

check "dogfood README documents verify-stage captain UAT routing" \
  "grep -q 'Captain UAT Feedback' '${DOGFOOD_README}' && grep -q 'route_to: design' '${DOGFOOD_README}' && grep -q 'must not inline-fix' '${DOGFOOD_README}'"

check "workflow template uses design-bearing skip semantics" \
  "grep -q 'skip-when: \"!affects_ui && !domain && !design_required\"' '${TEMPLATE}' && grep -q 'Design is mandatory for UI, matched-domain, or contract-bearing work' '${TEMPLATE}'"

check "plugin README agrees with dogfood design-bearing semantics" \
  "grep -q 'skip-when: !affects_ui && !domain && !design_required' '${PLUGIN_README}' && grep -q 'schema/API/domain/architecture contract impact' '${PLUGIN_README}'"

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
