#!/usr/bin/env bash
# test-ship-plan-stub-ack.sh — Assert T6.2 stub-captain-ack scan in ship-plan SKILL.md
# Entity: #106 pipeline-render-fidelity-hardening Wave 3 T6.2
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-ship-plan-stub-ack.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SKILL_FILE="${SCRIPT_DIR}/../../../../plugins/ship-flow/skills/ship-plan/SKILL.md"
INVARIANTS_FILE="${SCRIPT_DIR}/../../../../plugins/ship-flow/INVARIANTS.md"

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

echo "=== ship-plan stub-captain-ack assertions (T6.2) ==="
echo ""

# --- T6.2: ship-plan SKILL.md dim 10 ---
check "Stub-captain-ack scan dimension present in Step 4" \
  "grep -q 'Stub-captain-ack scan\|stub-captain-ack' \"$SKILL_FILE\""

check "stub keyword pattern mentioned (stub|fake|placeholder)" \
  "grep -qE 'stub.*fake.*placeholder|stub\|fake\|placeholder' \"$SKILL_FILE\""

check "BLOCK literal string present for test DC" \
  "grep -q 'BLOCK: stub task without captain ack' \"$SKILL_FILE\""

check "pre-acked-stubs frontmatter key mentioned" \
  "grep -q 'pre-acked-stubs' \"$SKILL_FILE\""

check "Stub Flags table mentioned in Plan Report" \
  "grep -qE 'Stub Flag|stub.*flag' \"$SKILL_FILE\""

check "UI design-skipped handoff is blocked unless captain bypassed" \
  "grep -q 'affects_ui: true' \"$SKILL_FILE\" && grep -q 'captain-approved-design-bypass' \"$SKILL_FILE\" && grep -q 'ui design handoff skipped' \"$SKILL_FILE\""

# --- T6.2: INVARIANTS.md Principle 4 extension ---
check "INVARIANTS.md mentions stub-ack as boolean predicate" \
  "grep -qiE 'stub.ack|pre-acked-stubs|stub.*boolean|stub.*captain.ack' \"$INVARIANTS_FILE\""

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "All assertions passed — stub-captain-ack T6.2 wired."
exit 0
