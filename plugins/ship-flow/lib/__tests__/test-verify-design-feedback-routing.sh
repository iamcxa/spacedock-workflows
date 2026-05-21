#!/usr/bin/env bash
# test-verify-design-feedback-routing.sh — verify-stage design feedback routing contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"

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

echo "=== test-verify-design-feedback-routing.sh ==="
echo ""

check "ship-verify defines a Design Feedback Router" \
  "grep -q 'Design Feedback Router' '${VERIFY_SKILL}'"

check "router classifies semantic design/IA/affordance gaps to design" \
  "awk '/Design Feedback Router/{in_block=1} in_block && /^## Step 4/{in_block=0} in_block && /semantic/ && /information architecture/ && /affordance/ && /route_to: design/{found=1} END{exit !found}' '${VERIFY_SKILL}'"

check "router classifies implementation/runtime drift to execute" \
  "awk '/Design Feedback Router/{in_block=1} in_block && /^## Step 4/{in_block=0} in_block && /implementation/ && /runtime/ && /route_to: execute/{found=1} END{exit !found}' '${VERIFY_SKILL}'"

check "designer parity BLOCKING no longer always feeds back to execute" \
  "! grep -q 'BLOCKING design-parity finding .*feedback to execute' '${VERIFY_SKILL}'"

check "mechanical UI parity can route missing baseline to design" \
  "awk '/Design Feedback Router/{in_block=1} in_block && /^## Step 4/{in_block=0} in_block && /Baseline screenshot missing/ && /route_to: design/{found=1} END{exit !found}' '${VERIFY_SKILL}'"

check "visible surface coverage routes missing design intent to design" \
  "awk '/Design Feedback Router/{in_block=1} in_block && /^## Step 4/{in_block=0} in_block && /visible_surface_map/ && /design intent/ && /route_to: design/{found=1} END{exit !found}' '${VERIFY_SKILL}'"

check "visible surface coverage routes implementation-only extra UI to execute" \
  "awk '/Design Feedback Router/{in_block=1} in_block && /^## Step 4/{in_block=0} in_block && /implementation-only extra UI/ && /route_to: execute/{found=1} END{exit !found}' '${VERIFY_SKILL}'"

check "visible surface coverage audit remains non-screenshot infrastructure" \
  "awk '/Visible surface coverage audit/{in_block=1} in_block && /^### Step 3\\.6\\.5/{in_block=0} in_block && /not screenshot diff infrastructure/ && /closed-list coverage audit/{found=1} END{exit !found}' '${VERIFY_SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed — verify design feedback routing wired."
exit 0
