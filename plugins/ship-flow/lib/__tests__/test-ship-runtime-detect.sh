#!/usr/bin/env bash
# test-ship-runtime-detect.sh — Assert Step R5 + R6 framework detection in SKILL.md
# Entity: #106 pipeline-render-fidelity-hardening Wave 2a T2.1 + T2.2
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-ship-runtime-detect.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SKILL_FILE="${SCRIPT_DIR}/../../../../plugins/ship-flow/skills/ship-runtime-detect/SKILL.md"
STACK_MAP="${SCRIPT_DIR}/../../../../plugins/ship-flow/references/stack-skill-map.yaml"

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

echo "=== ship-runtime-detect Step R5 + R6 assertions ==="
echo ""

# --- T2.1: Step R5 framework detection in SKILL.md ---
check "Step R5 section present in SKILL.md" \
  "grep -q 'Step R5' \"$SKILL_FILE\""

check "next.config probe mentioned in R5" \
  "grep -E 'next\.config|next\.js' \"$SKILL_FILE\" | grep -q 'R5\|framework'"

check "@theme inline detection mentioned in R5" \
  "grep -q '@theme' \"$SKILL_FILE\""

check "tailwind v4 indirection detection" \
  "grep -qi 'tailwind.*v4\|theme_indirection' \"$SKILL_FILE\""

check "design_canonical_dir output variable defined" \
  "grep -q 'design_canonical_dir' \"$SKILL_FILE\""

check "framework_detected output variable defined (DC-2.4)" \
  "grep -q 'framework_detected' \"$SKILL_FILE\""

# --- T2.2: Step R6 mapping table ---
check "Step R6 section present in SKILL.md" \
  "grep -q 'Step R6' \"$SKILL_FILE\""

check "stack-skill-map.yaml exists (DC-2.2)" \
  "[ -f \"$STACK_MAP\" ]"

check "stack-skill-map.yaml contains next.js mapping" \
  "grep -q 'next.js\|next-js' \"$STACK_MAP\""

check "stack-skill-map.yaml contains tailwind-v4 mapping" \
  "grep -qi 'tailwind.*v4\|tailwind-v4' \"$STACK_MAP\""

check "vercel:nextjs skill in mapping" \
  "grep -q 'vercel:nextjs\|vercel/nextjs' \"$STACK_MAP\""

check "vercel:shadcn skill in mapping" \
  "grep -q 'vercel:shadcn\|vercel/shadcn' \"$STACK_MAP\""

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

echo "All assertions passed — ship-runtime-detect R5+R6 wired."
exit 0
