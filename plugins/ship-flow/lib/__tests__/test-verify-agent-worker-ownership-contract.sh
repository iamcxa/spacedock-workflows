#!/usr/bin/env bash
# test-verify-agent-worker-ownership-contract.sh - verify owns agent/worker routing and auto-merge policy alignment.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
REVIEWER_PANEL="${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md"
PR_MERGE_MOD="${REPO_ROOT}/docs/ship-flow/_mods/pr-merge.md"
SEMANTIC_POLICY="${REPO_ROOT}/plugins/ship-flow/bin/semantic-review-policy.mjs"
README="${REPO_ROOT}/plugins/ship-flow/README.md"

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

echo "=== test-verify-agent-worker-ownership-contract.sh ==="
echo ""

check "ship-verify declares a single verifier integrator with pass ownership" \
  "grep -q 'Agent/worker ownership contract' '${VERIFY_SKILL}' && grep -q 'verifier is the single integrator' '${VERIFY_SKILL}' && grep -q 'one primary owner' '${VERIFY_SKILL}'"

check "ship-verify distinguishes local verifier primitives from agent-owned judgment reviews" \
  "grep -q 'Local verifier primitives' '${VERIFY_SKILL}' && grep -q 'Agent-owned judgment reviews' '${VERIFY_SKILL}' && grep -q 'Mixed ownership rule' '${VERIFY_SKILL}'"

check "ship-verify pass ownership table maps core dimensions to owners" \
  "grep -q 'verify_agent_worker_ownership' '${VERIFY_SKILL}' && grep -q 'cross_model_challenge' '${VERIFY_SKILL}' && grep -q 'runtime_uat' '${VERIFY_SKILL}' && grep -q 'workflow_ci' '${VERIFY_SKILL}'"

check "ship-verify requires explicit coverage verdicts for every triggered pass" \
  "grep -q 'PASS | NO_FINDINGS | BLOCKING | WARNING | NIT | DEGRADED' '${VERIFY_SKILL}' && grep -q 'missing owner output is a coverage gap' '${VERIFY_SKILL}'"

check "ship-verify makes pass ownership coverage blocking before PASS" \
  "grep -q 'Pass ownership rows are PASS-blocking' '${VERIFY_SKILL}' && ! grep -q 'Panel Coverage.*never blocks' '${VERIFY_SKILL}'"

check "Panel Coverage template exposes pass ownership and semantic packet mapping" \
  "grep -q 'Pass ownership:' '${VERIFY_SKILL}' && grep -q 'Semantic packet dimensions:' '${VERIFY_SKILL}' && grep -q 'cross_model_challenge' '${VERIFY_SKILL}' && grep -q '<verdict>' '${VERIFY_SKILL}' && ! grep -q 'PASS|NO_FINDINGS|BLOCKING' '${VERIFY_SKILL}'"

check "verify-reviewer-panel output carries dimension key and owner handoff fields" \
  "grep -q 'dimension_key:' '${REVIEWER_PANEL}' && grep -q 'primary_owner:' '${REVIEWER_PANEL}' && grep -q 'verifier-owned aggregation' '${REVIEWER_PANEL}'"

check "semantic review default policy requires verify ownership and cross-model dimensions" \
  "grep -q 'verify_agent_worker_ownership' '${SEMANTIC_POLICY}' && grep -q 'cross_model_challenge' '${SEMANTIC_POLICY}'"

check "pr-merge auto-merge step requires semantic packet policy alignment with verify coverage" \
  "grep -q 'verify_agent_worker_ownership' '${PR_MERGE_MOD}' && grep -q 'cross_model_challenge' '${PR_MERGE_MOD}' && grep -q 'semantic review packet policy' '${PR_MERGE_MOD}' && grep -q -- '--verify-md' '${PR_MERGE_MOD}' && grep -q -- '--mode off' '${PR_MERGE_MOD}'"

check "README documents verify ownership dimensions as auto-merge readiness inputs" \
  "grep -q 'verify_agent_worker_ownership' '${README}' && grep -q 'cross_model_challenge' '${README}' && grep -q 'auto-merge readiness' '${README}' && grep -q -- '--verify-md' '${README}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
