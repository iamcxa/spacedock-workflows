#!/usr/bin/env bash
# test-workflow-sot-sync.sh - dogfood README and adopter template stay current.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
DOGFOOD_README="${REPO_ROOT}/docs/ship-flow/README.md"
TEMPLATE="${REPO_ROOT}/plugins/ship-flow/workflow-template.yaml"
PLUGIN_README="${REPO_ROOT}/plugins/ship-flow/README.md"
SOT_SYNC="${REPO_ROOT}/plugins/ship-flow/lib/sync-workflow-sot.sh"

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

check "dogfood README design stage has no skip-when (W3 — design always runs)" \
  "! grep -A6 'name: design' '${DOGFOOD_README}' | grep -q 'skip-when:'"

check "dogfood README includes design.md in pipeline artifacts" \
  "grep -q 'design.md' '${DOGFOOD_README}' && grep -q 'Design Intent' '${DOGFOOD_README}'"

check "dogfood README keeps verify feedback-to compatible with FO single-stage routing" \
  "grep -q 'feedback-to: \"execute\"' '${DOGFOOD_README}' && ! grep -q 'feedback-to: \"execute|design|plan|follow-up\"' '${DOGFOOD_README}'"

check "dogfood README documents verify-stage captain UAT routing" \
  "grep -q 'Captain UAT Feedback Router' '${DOGFOOD_README}' && grep -q 'frontmatter \`feedback-to\` remains \`execute\`' '${DOGFOOD_README}' && grep -q 'route_to: design' '${DOGFOOD_README}' && grep -q 'must not inline-fix' '${DOGFOOD_README}'"

check "dogfood README documents design routing frontmatter fields and designer teammate" \
  "grep -q '| \`affects_ui\` | boolean |' '${DOGFOOD_README}' && grep -q '| \`domain\` | string |' '${DOGFOOD_README}' && grep -q '| \`design_required\` | boolean |' '${DOGFOOD_README}' && grep -q '| \`contract_decision_required\` | boolean |' '${DOGFOOD_README}' && grep -q '\`designer\` (opus)' '${DOGFOOD_README}'"

check "dogfood README status command discovers binary with guard" \
  "grep -q 'STATUS_BIN=' '${DOGFOOD_README}' && grep -q 'spacedock status binary not found' '${DOGFOOD_README}' && grep -q 'The examples below assume \`STATUS_BIN\` is set' '${DOGFOOD_README}'"

check "dogfood README capture command discovers installed plugin binary with guard" \
  "grep -q 'SHIP_CAPTURE_BIN=' '${DOGFOOD_README}' && grep -q 'ship-flow ship-capture.sh not found' '${DOGFOOD_README}' && ! grep -q 'bash plugins/ship-flow/bin/ship-capture.sh' '${DOGFOOD_README}'"

check "workflow template has no skip-when and states design always runs (W3)" \
  "! grep -q 'skip-when:' '${TEMPLATE}' && grep -q 'Design always runs' '${TEMPLATE}'"

check "plugin README states design always runs (no skip-when in design stage, W3)" \
  "! grep -A6 'name: design' '${PLUGIN_README}' | grep -q 'skip-when:' && grep -q 'Always runs' '${PLUGIN_README}'"

check "sync helper check mode passes on live repo" \
  "'${SOT_SYNC}' --check"

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
