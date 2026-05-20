#!/usr/bin/env bash
# test-verify-reviewer-panel.sh - verify-stage reviewer panel fallback contract.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

README="${REPO_ROOT}/docs/ship-flow/README.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
EXECUTE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-execute/SKILL.md"
PANEL_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
INVARIANTS="${REPO_ROOT}/plugins/ship-flow/INVARIANTS.md"
CHECK_INVARIANTS="${REPO_ROOT}/plugins/ship-flow/bin/check-invariants.sh"

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

echo "=== test-verify-reviewer-panel.sh ==="
echo ""

check "ship-flow owns a verify reviewer panel utility fallback skill" \
  "test -f '${PANEL_SKILL}' && grep -q 'ship-flow:verify-reviewer-panel' '${PANEL_SKILL}' && grep -q 'pr-review-toolkit.*optional' '${PANEL_SKILL}'"

check "reviewer panel defines general external and silent failure fallback lenses" \
  "grep -q 'general-external-reviewer' '${PANEL_SKILL}' && grep -q 'silent-failure-reviewer' '${PANEL_SKILL}' && grep -q 'domain-expert-reviewer' '${PANEL_SKILL}'"

check "reviewer panel enforces read-only path base head changed-files self-check" \
  "grep -q 'read-only' '${PANEL_SKILL}' && grep -q 'repo path' '${PANEL_SKILL}' && grep -q 'base/head' '${PANEL_SKILL}' && grep -q 'changed files' '${PANEL_SKILL}' && grep -q 'file:line' '${PANEL_SKILL}'"

check "reviewer panel standardizes YAML key file_line with path line value format" \
  "grep -q 'file_line' '${PANEL_SKILL}' && grep -q '<path:line>' '${PANEL_SKILL}' && grep -q 'file_line' '${SCHEMA}' && ! grep -q '\"file:line\"' '${SCHEMA}'"

check "ship-verify uses reviewer panel as general external reviewer baseline" \
  "grep -q 'ship-flow:verify-reviewer-panel' '${VERIFY_SKILL}' && grep -q 'general external reviewer' '${VERIFY_SKILL}' && grep -q 'verify-check-manifest' '${VERIFY_SKILL}'"

check "ship-verify keeps pr-review-toolkit delegation optional with fallback" \
  "grep -q 'pr-review-toolkit:code-reviewer' '${VERIFY_SKILL}' && grep -q 'pr-review-toolkit:silent-failure-hunter' '${VERIFY_SKILL}' && grep -q 'fallback.*ship-flow:verify-reviewer-panel' '${VERIFY_SKILL}'"

check "schema exposes verify reviewer panel manifest and output matrix" \
  "grep -q 'review_lenses' '${SCHEMA}' && grep -q 'general-external-reviewer' '${SCHEMA}' && grep -q 'silent-failure-reviewer' '${SCHEMA}' && grep -q 'domain-expert-reviewer' '${SCHEMA}' && grep -q 'reviewer_output_matrix' '${SCHEMA}'"

check "reviewer panel output matrix supports explicit non-findings invalid context degraded confidence disposition" \
  "grep -q 'NO_FINDINGS' '${PANEL_SKILL}' && grep -q 'INVALID_CONTEXT' '${PANEL_SKILL}' && grep -q 'DEGRADED' '${PANEL_SKILL}' && grep -q 'confidence' '${PANEL_SKILL}' && grep -q 'disposition' '${PANEL_SKILL}' && grep -q 'disposition_reason' '${PANEL_SKILL}'"

check "reviewer panel explicit non-findings require lens source scope route_to none evidence" \
  "grep -q 'NO_FINDINGS.*lens' '${PANEL_SKILL}' && grep -q 'NO_FINDINGS.*source' '${PANEL_SKILL}' && grep -q 'NO_FINDINGS.*scope' '${PANEL_SKILL}' && grep -q 'route_to: none' '${PANEL_SKILL}' && grep -q 'NO_FINDINGS.*evidence' '${PANEL_SKILL}'"

check "reviewer panel nullable file_line is limited to non-findings invalid context and degraded rows" \
  "grep -q 'file_line.*null.*NO_FINDINGS.*INVALID_CONTEXT.*DEGRADED' '${PANEL_SKILL}'"

check "schema reviewer output matrix includes source scope confidence disposition fields and allowed verdicts" \
  "grep -q 'Source' '${SCHEMA}' && grep -q 'Scope' '${SCHEMA}' && grep -q 'confidence' '${SCHEMA}' && grep -q 'disposition' '${SCHEMA}' && grep -q 'disposition_reason' '${SCHEMA}' && grep -q 'NO_FINDINGS' '${SCHEMA}' && grep -q 'INVALID_CONTEXT' '${SCHEMA}' && grep -q 'DEGRADED' '${SCHEMA}'"

check "reviewer panel output matrix matches D3 source route confidence and disposition value domains" \
  "grep -q 'source: baseline|reviewer_questions|domain_acceptance_checklist|context-routing-manifest|scope-detection|inline-critical-pass' '${PANEL_SKILL}' && grep -q 'route_to: execute|plan|design|review|follow-up|captain|none' '${PANEL_SKILL}' && grep -q 'confidence: 1-10|null' '${PANEL_SKILL}' && grep -q 'disposition: pending|accepted|bounced|deferred|discarded|not-applicable' '${PANEL_SKILL}' && grep -q 'allowed_source_values:.*baseline.*reviewer_questions.*domain_acceptance_checklist.*context-routing-manifest.*scope-detection.*inline-critical-pass' '${SCHEMA}' && grep -q 'allowed_route_to_values:.*execute.*plan.*design.*review.*follow-up.*captain.*none' '${SCHEMA}' && grep -q 'allowed_confidence_values:.*1-10.*null' '${SCHEMA}' && grep -q 'allowed_disposition_values:.*pending.*accepted.*bounced.*deferred.*discarded.*not-applicable' '${SCHEMA}'"

check "README documents general external reviewer baseline and domain specialization" \
  "grep -q 'general external reviewer' '${README}' && grep -q 'ship-flow:verify-reviewer-panel' '${README}' && grep -q 'domain expert panel.*specialization' '${README}'"

check "invariants classify reviewer panel as utility skill and preserve stage cap" \
  "grep -q 'verify-reviewer-panel' '${INVARIANTS}' && grep -q 'verify-reviewer-panel' '${CHECK_INVARIANTS}' && grep -q 'Utility-skills.*verify-reviewer-panel' '${INVARIANTS}' && grep -q 'ship-design.*7 total' '${INVARIANTS}'"

check "Copilot TDD skip marker wording is canonical" \
  "grep -q 'TDD: skip -- <reason>' '${VERIFY_SKILL}' && ! grep -q 'TDD: skip -- <valid reason>' '${VERIFY_SKILL}'"

check "Copilot execute wording makes ship-flow TDD unconditional" \
  "grep -q 'ship-flow:test-driven-development.*unconditionally' '${EXECUTE_SKILL}' && ! grep -q 'ship-flow:test-driven-development.*when available' '${EXECUTE_SKILL}'"

check "Copilot schema wording says exempt tasks omit tdd_contract" \
  "grep -q 'exempt tasks omit tdd_contract' '${SCHEMA}' && grep -q 'include the TDD: skip -- <reason> marker' '${SCHEMA}'"

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
