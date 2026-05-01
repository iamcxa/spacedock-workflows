#!/usr/bin/env bash
# test-captain-uat-feedback-routing.sh - verify-stage captain UAT routing contract.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
SHIP_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship/SKILL.md"

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

echo "=== test-captain-uat-feedback-routing.sh ==="
echo ""

check "ship-verify defines captain UAT feedback router" \
  "grep -q 'Captain UAT Feedback Router' '${VERIFY_SKILL}'"

check "ship-verify records Captain UAT Feedback section in verify.md" \
  "grep -q '## Captain UAT Feedback' '${VERIFY_SKILL}' && grep -q 'route_to: execute\\|design\\|plan\\|follow-up' '${VERIFY_SKILL}'"

check "captain UAT blocking/warning findings must route via SendMessage, not FO inline" \
  "awk '/Captain UAT Feedback Router/{in_block=1} in_block && /^## Step 6/{in_block=0} in_block && /BLOCKING/ && /WARNING/ && /SendMessage/ && /FO MUST NOT inline-fix/{found=1} END{exit !found}' '${VERIFY_SKILL}'"

check "captain UAT router names executer designer and planner owners" \
  "awk '/Captain UAT Feedback Router/{in_block=1} in_block && /^## Step 6/{in_block=0} in_block && /executer@pitch-XX/ && /designer@pitch-XX/ && /planner@pitch-XX/{found=1} END{exit !found}' '${VERIFY_SKILL}'"

check "captain UAT inline fix exception is limited to mechanical NITs" \
  "awk '/Captain UAT Feedback Router/{in_block=1} in_block && /^## Step 6/{in_block=0} in_block && /NIT/ && /mechanical/ && /<=5 LOC/ && /no semantic/ {found=1} END{exit !found}' '${VERIFY_SKILL}'"

check "ship orchestration distinguishes verify-stage captain UAT from post-ship smoke" \
  "grep -q 'verify-stage captain UAT feedback' '${SHIP_SKILL}' && grep -q 'not post-ship captain smoke' '${SHIP_SKILL}'"

check "ship orchestration sends verify-stage captain UAT feedback back to stage loop" \
  "awk '/Verify-stage captain UAT feedback loop/{in_block=1} in_block && /^## Step 7/{in_block=0} in_block {text=text \" \" \$0} END{exit !(text ~ /SendMessage/ && text ~ /executer/ && text ~ /designer/ && text ~ /planner/ && text ~ /MUST NOT patch inline/)}' '${SHIP_SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
