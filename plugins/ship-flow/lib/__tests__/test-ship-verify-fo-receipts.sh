#!/usr/bin/env bash
# test-ship-verify-fo-receipts.sh - ship-verify FO receipt writer contract.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." >/dev/null 2>&1 && pwd)"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

line_no() {
  local pattern="$1"
  awk -v pattern="$pattern" 'index($0, pattern) { print NR; exit }' "$VERIFY_SKILL"
}

echo "=== test-ship-verify-fo-receipts.sh ==="
echo ""

check "ship-verify names the shared FO receipt helper" \
  "grep -q 'plugins/ship-flow/lib/write-fo-receipt.sh' '${VERIFY_SKILL}'"

PROCEED_LINE="$(line_no 'Verdict: **PROCEED**')"
HELPER_LINE="$(line_no 'plugins/ship-flow/lib/write-fo-receipt.sh')"
ADVANCE_LINE="$(line_no 'advance-stage.sh')"

check "receipt helper appears after final PROCEED verdict handling" \
  "[ -n '${PROCEED_LINE}' ] && [ -n '${HELPER_LINE}' ] && [ '${HELPER_LINE:-0}' -gt '${PROCEED_LINE:-0}' ]"

check "receipt helper appears before advance-stage.sh status mutation" \
  "[ -n '${HELPER_LINE}' ] && [ -n '${ADVANCE_LINE}' ] && [ '${HELPER_LINE:-99999}' -lt '${ADVANCE_LINE:-0}' ]"

check "verify receipt example records verify-to-review transition trigger" \
  "grep -q 'from: verify' '${VERIFY_SKILL}' && grep -q 'to: review' '${VERIFY_SKILL}' && grep -q 'trigger: verify-proceed-auto-advance' '${VERIFY_SKILL}'"

check "verify receipt example records self-approved PROCEED rule source" \
  "grep -q 'decision: self-approved' '${VERIFY_SKILL}' && grep -q 'verdict: PROCEED' '${VERIFY_SKILL}' && grep -q 'rule_source: plugins/ship-flow/skills/ship-verify/SKILL.md' '${VERIFY_SKILL}'"

check "verify receipt example records captain prompt gate as boolean" \
  "grep -q 'prompt_captain_required: false' '${VERIFY_SKILL}' && ! grep -q 'prompt_captain: none' '${VERIFY_SKILL}'"

check "negative verify routes stay captain/block routed instead of self-approved" \
  "grep -q 'missing .*verify.md' '${VERIFY_SKILL}' && grep -q 'Missing Hand-off to Verify' '${VERIFY_SKILL}' && grep -q 'NOT VERIFIED' '${VERIFY_SKILL}' && grep -q 'invalid required .*INCONCLUSIVE' '${VERIFY_SKILL}' && grep -q 'VETO' '${VERIFY_SKILL}' && grep -q 'PROMPT_CAPTAIN' '${VERIFY_SKILL}' && grep -qi 'captain\\|block' '${VERIFY_SKILL}'"

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
