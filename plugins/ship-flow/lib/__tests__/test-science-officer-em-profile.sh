#!/usr/bin/env bash
# Regression guard for 130.1 Science Officer (EM) standing profile.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
PLUGIN_MOD="${ROOT}/plugins/ship-flow/_mods/science-officer-em.md"
WORKFLOW_MOD="${ROOT}/docs/ship-flow/_mods/science-officer-em.md"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Science Officer (EM) profile contract ==="

for mod in "$PLUGIN_MOD" "$WORKFLOW_MOD"; do
  rel="${mod#"${ROOT}"/}"
  check "${rel}: file exists" "test -f '$mod'"
  check "${rel}: name is science-officer-em" "grep -q '^name: science-officer-em$' '$mod'"
  check "${rel}: standing teammate" "grep -q '^standing: true$' '$mod'"
  check "${rel}: startup hook" "grep -q '^## Hook: startup$' '$mod' && grep -q 'name: science-officer-em' '$mod'"
  check "${rel}: Agent Prompt section" "grep -q '^## Agent Prompt$' '$mod'"
  check "${rel}: anti-relay criterion" "grep -qi 'anti-relay' '$mod' && grep -qi 'status-only relay' '$mod'"
  check "${rel}: costly no authority" "grep -qi 'costly no' '$mod' && grep -qi 'say no' '$mod'"
  check "${rel}: independent synthesis" "grep -qi 'independent synthesis' '$mod' && grep -qi 'FO state' '$mod'"
  check "${rel}: FO boundary" "grep -qi 'FO owns' '$mod' && grep -qi 'EM owns' '$mod'"
  check "${rel}: upward report block named" "grep -q 'science_officer_em_upward_report' '$mod'"
  check "${rel}: upward report required fields named" "grep -q 'em_judgment' '$mod' && grep -q 'evidence_synthesis' '$mod' && grep -q 'risk_tradeoff_call' '$mod' && grep -q 'recommendation' '$mod' && grep -q 'route' '$mod' && grep -q 'confidence' '$mod' && grep -q 'fo_boundary' '$mod'"
  check "${rel}: upward report route enum named" "grep -q 'proceed' '$mod' && grep -q 'narrow' '$mod' && grep -q 'return' '$mod' && grep -q 'block' '$mod' && grep -q 'costly_no' '$mod'"
  check "${rel}: report shape without FO mechanics" "grep -qi 'upward report shape' '$mod' && grep -qi 'Do not directly advance stages' '$mod' && ! grep -qi 'EM owns.*stage advancement' '$mod'"
  check "${rel}: AI review adjudication classifications" \
    "grep -qi 'AI / external PR review adjudication' '$mod' && grep -q 'accepted' '$mod' && grep -q 'false_positive' '$mod' && grep -q 'out_of_scope' '$mod'"
  check "${rel}: false positives require evidence-bearing gh api replies" \
    "grep -q 'gh api' '$mod' && grep -qi 'evidence-bearing' '$mod' && grep -qi 'resolve/dismiss' '$mod'"
  check "${rel}: forbids author self-approval bypass" \
    "grep -qi 'author self-approval' '$mod' && grep -qi 'must not' '$mod'"
  check "${rel}: references are portable plugin contracts" \
    "! grep -q 'docs/ship-flow/130\\.' '$mod' && grep -q 'render-science-officer-em-stewardship-contract.sh' '$mod' && grep -q 'render-science-officer-em-upward-report-contract.sh' '$mod'"
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
