#!/usr/bin/env bash
# test-ship-tdd-contract.sh - ship-flow-owned TDD fallback contract.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

TDD_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/test-driven-development/SKILL.md"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
EXECUTE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-execute/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
INVARIANTS="${REPO_ROOT}/plugins/ship-flow/INVARIANTS.md"
README="${REPO_ROOT}/docs/ship-flow/README.md"

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

echo "=== test-ship-tdd-contract.sh ==="
echo ""

check "ship-flow owns a TDD fallback skill independent of superpowers" \
  "test -f '${TDD_SKILL}' && grep -q 'superpowers.*optional enhancer' '${TDD_SKILL}' && grep -q 'adopter.*not.*required' '${TDD_SKILL}'"

check "TDD skill defines RED GREEN REFACTOR artifact contract" \
  "grep -q 'RED command' '${TDD_SKILL}' && grep -q 'Expected RED failure' '${TDD_SKILL}' && grep -q 'GREEN command' '${TDD_SKILL}' && grep -q 'REFACTOR' '${TDD_SKILL}'"

check "plan stage invokes ship-flow TDD fallback rather than relying only on superpowers" \
  "grep -q 'ship-flow:test-driven-development' '${PLAN_SKILL}' && grep -q 'TDD contract' '${PLAN_SKILL}' && grep -q 'RED command' '${PLAN_SKILL}'"

check "plan task schema exposes TDD contract fields" \
  "grep -q 'tdd_contract' '${SCHEMA}' && grep -q 'red_command' '${SCHEMA}' && grep -q 'expected_red_failure' '${SCHEMA}' && grep -q 'green_command' '${SCHEMA}'"

check "execute and verify schemas expose TDD evidence handoff" \
  "grep -q 'tdd_evidence' '${SCHEMA}' && grep -q 'tdd_evidence_summary' '${SCHEMA}' && grep -q 'tdd_evidence_audit' '${SCHEMA}'"

check "execute enforces RED before implementation for non-exempt tasks" \
  "grep -q 'RED-before-GREEN' '${EXECUTE_SKILL}' && grep -q 'expected RED failure' '${EXECUTE_SKILL}' && grep -q 'tdd_contract' '${EXECUTE_SKILL}'"

check "verify audits execute evidence for RED before GREEN" \
  "grep -q 'TDD Evidence Audit' '${VERIFY_SKILL}' && grep -q 'RED-before-GREEN' '${VERIFY_SKILL}' && grep -q 'route_to: execute' '${VERIFY_SKILL}'"

check "verify TDD audit uses existing review taxonomy and refactor label" \
  "grep -q '### Review Findings' '${VERIFY_SKILL}' && grep -q 'BLOCKING' '${VERIFY_SKILL}' && grep -q 'REFACTOR check' '${VERIFY_SKILL}' && ! grep -q 'Severity: Important' '${VERIFY_SKILL}'"

check "verify TDD audit step is ordered before per-error attribution" \
  "grep -q '### Step 2.1 — TDD Evidence Audit' '${VERIFY_SKILL}' && grep -q '### Step 2.2 — Per-error diff-aware attribution' '${VERIFY_SKILL}'"

check "TDD skip marker is grep-friendly and consistent across stage docs" \
  "grep -q 'TDD: skip -- <reason>' '${PLAN_SKILL}' && grep -q 'TDD: skip -- <reason>' '${VERIFY_SKILL}' && grep -q 'TDD: skip -- <reason>' '${EXECUTE_SKILL}' && ! grep -q 'TDD.*skip —' '${PLAN_SKILL}'"

check "execute mirrors the TDD exemption list" \
  "grep -q 'docs-only/stage-artifact' '${EXECUTE_SKILL}' && grep -q 'pure configuration' '${EXECUTE_SKILL}' && grep -q 'migrations validated by existing migration tooling' '${EXECUTE_SKILL}' && grep -q 'pure refactors with existing coverage' '${EXECUTE_SKILL}'"

check "invariants classify TDD fallback as ship-flow-owned Layer B contract" \
  "grep -q 'ship-flow:test-driven-development' '${INVARIANTS}' && grep -q 'superpowers optional' '${INVARIANTS}' && grep -q 'ship-design.*7 total' '${INVARIANTS}'"

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
