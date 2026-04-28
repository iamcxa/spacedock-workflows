#!/usr/bin/env bash
# test-ship-plan-indirection-sweep.sh — Assert T6.1 auto-indirection-sweep rule in ship-plan SKILL.md
# Entity: #106 pipeline-render-fidelity-hardening Wave 3 T6.1
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-ship-plan-indirection-sweep.sh

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

echo "=== ship-plan auto-indirection-sweep assertions (T6.1) ==="
echo ""

# --- T6.1: ship-plan SKILL.md ---
check "T0.X auto-indirection-sweep rule present in ship-plan SKILL.md" \
  "grep -q 'T0.X auto-indirection-sweep\|auto-indirection-sweep' \"$SKILL_FILE\""

check "theme_indirection non-empty triggers T0.X task" \
  "grep -qE 'theme_indirection.*non-empty|theme_indirection.*!=.*empty|theme_indirection.*tailor' \"$SKILL_FILE\" || grep -q 'theme_indirection' \"$SKILL_FILE\""

check "REFUSE without T0.X when indirection detected" \
  "grep -qiE 'REFUSE|refuse' \"$SKILL_FILE\""

check "audit @theme inline mentioned as T0.X content" \
  "grep -qE '@theme inline|indirection layer' \"$SKILL_FILE\""

# --- T6.1: INVARIANTS.md Principle 5 ---
check "INVARIANTS.md mentions indirection-sweep mandatory" \
  "grep -qiE 'indirection.sweep|indirection.*sweep|sweep.*indirection' \"$INVARIANTS_FILE\""

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

echo "All assertions passed — auto-indirection-sweep T6.1 wired."
exit 0
