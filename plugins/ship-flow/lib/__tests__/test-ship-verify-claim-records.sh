#!/usr/bin/env bash
# test-ship-verify-claim-records.sh - ship-verify claim/evidence/verdict contract.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
FIXTURE="${SCRIPT_DIR}/fixtures/ship-verify-claim-records/verify.md"

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

echo "=== test-ship-verify-claim-records.sh ==="
echo ""

check "fixture includes required verified, blocking not-verified, and advisory inconclusive claim records" \
  "grep -q '#### Verification Claim:' '${FIXTURE}' && grep -q 'verdict | \`VERIFIED\`' '${FIXTURE}' && grep -q 'verdict | \`NOT VERIFIED\`' '${FIXTURE}' && grep -q 'verdict | \`INCONCLUSIVE\`' '${FIXTURE}' && grep -q 'route_to | \`follow-up\`' '${FIXTURE}'"

check "ship-verify defines the Verification Claim Field Value table" \
  "grep -q '#### Verification Claim: <short falsifiable claim>' '${VERIFY_SKILL}' && grep -q '| Field | Value |' '${VERIFY_SKILL}'"

check "ship-verify requires all claim record fields from design D2" \
  "grep -q 'claim_source' '${VERIFY_SKILL}' && grep -q 'condition' '${VERIFY_SKILL}' && grep -q 'metric_or_observable' '${VERIFY_SKILL}' && grep -q 'threshold' '${VERIFY_SKILL}' && grep -q 'smallest_disproving_surface' '${VERIFY_SKILL}' && grep -q 'baseline' '${VERIFY_SKILL}' && grep -q 'treatment' '${VERIFY_SKILL}' && grep -q 'comparison' '${VERIFY_SKILL}' && grep -q 'verdict' '${VERIFY_SKILL}' && grep -q 'route_to' '${VERIFY_SKILL}'"

check "ship-verify ties claim records to quality gate and TDD evidence audit outcomes" \
  "grep -q 'verdict-bearing quality' '${VERIFY_SKILL}' && grep -q 'TDD Evidence Audit.*claim record' '${VERIFY_SKILL}'"

check "ship-verify ties claim records to review findings including non-blocking WARNING dispositions" \
  "grep -q 'BLOCKING findings.*claim record' '${VERIFY_SKILL}' && grep -q 'WARNING.*claim record' '${VERIFY_SKILL}'"

check "ship-verify ties claim records to UAT Done Criteria coverage" \
  "grep -q 'Each sampled, re-run, or trusted DC.*claim record' '${VERIFY_SKILL}'"

check "ship-verify verdict mapping covers VERIFIED, NOT VERIFIED, and INCONCLUSIVE dominance" \
  "grep -q 'VERIFIED.*PROCEED' '${VERIFY_SKILL}' && grep -q 'NOT VERIFIED.*VETO' '${VERIFY_SKILL}' && grep -q 'INCONCLUSIVE.*PROMPT_CAPTAIN' '${VERIFY_SKILL}' && grep -q 'INCONCLUSIVE.*follow-up' '${VERIFY_SKILL}'"

check "ship-verify final Verdict requires claim_records summary counts" \
  "grep -q 'claim_records:' '${VERIFY_SKILL}' && grep -q 'required.*VERIFIED.*NOT VERIFIED.*INCONCLUSIVE' '${VERIFY_SKILL}' && grep -q 'advisory.*VERIFIED.*NOT VERIFIED.*INCONCLUSIVE' '${VERIFY_SKILL}'"

check "ship-verify PASS gate requires valid panel coverage explicit non-findings discarded outputs excluded and verifier-owned dispositions" \
  "grep -q 'mandatory or triggered lens coverage.*PASS.*NO_FINDINGS.*accepted non-blocking.*DEGRADED' '${VERIFY_SKILL}' && grep -q 'discarded reviewer output.*excluded from coverage' '${VERIFY_SKILL}' && grep -q 'BLOCKING.*WARNING.*NIT.*verifier-owned disposition.*before PASS' '${VERIFY_SKILL}' && grep -q 'NO_FINDINGS rows.*mandatory lenses with no findings' '${VERIFY_SKILL}' && grep -q 'panel_coverage.*cross_model.*verify.md' '${VERIFY_SKILL}'"

check "ship-verify PASS gate summary uses canonical reviewer lens identifiers" \
  "grep -q 'performance, api-contract, data-migration, design, threat-surface' '${VERIFY_SKILL}' && ! grep -q 'performance, API, migration, design, threat-surface' '${VERIFY_SKILL}'"

check "ship-verify does not import forbidden Cursor runtime assumptions" \
  "! grep -q '/tmp/verify-this\\|control-ui\\|control-cli\\|workflow-from-chats\\|loop-on-ci\\|fix-ci' '${VERIFY_SKILL}'"

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
