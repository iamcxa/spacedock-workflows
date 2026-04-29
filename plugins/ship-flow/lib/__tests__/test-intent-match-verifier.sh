#!/usr/bin/env bash
# test-intent-match-verifier.sh — DC-runner for #113.4 intent-match verifier
# Tests ship-verify SKILL.md contract for schema-domain design/execute drift checks.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
SKILL_FILE="${PLUGIN_ROOT}/skills/ship-verify/SKILL.md"
INTENT_SKILL_DIR="${PLUGIN_ROOT}/skills/intent-match-verifier"

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

echo "=== test-intent-match-verifier.sh ==="
echo ""

echo "Block 1: ship-verify owns the intent-match verifier contract"
check "ship-verify defines Intent-match verifier section" \
  "grep -qE 'Intent-match verifier' '${SKILL_FILE}'"
check "intent verifier remains embedded; no eighth stage skill exists" \
  "[ ! -d '${INTENT_SKILL_DIR}' ]"

echo "Block 2: schema design output is the source contract"
check "ship-verify references Schema Design Output" \
  "grep -qE '## Schema Design Output' '${SKILL_FILE}'"
check "ship-verify compares execute evidence or diff against design intent" \
  "grep -qE 'execute (evidence|diff)|execute diff|execute evidence' '${SKILL_FILE}' && grep -qE 'design intent|intent checklist' '${SKILL_FILE}'"

echo "Block 3: findings format routes design drift"
check "ship-verify emits Intent Match Findings" \
  "grep -qE '## Intent Match Findings' '${SKILL_FILE}'"
check "ship-verify tags incomplete design intent as route_to: design" \
  "grep -qE 'route_to: design' '${SKILL_FILE}'"
check "ship-verify also distinguishes execute-routed drift" \
  "grep -qE 'route_to: execute|otherwise route to execute' '${SKILL_FILE}'"

echo "Block 4: registry consumer and schema checklist"
check "ship-verify consults registry-resolve.sh" \
  "grep -qE 'registry-resolve\\.sh' '${SKILL_FILE}'"
check "ship-verify schema checklist covers L1/L2/L3, event-saga, RBAC, and fstore rebuild" \
  "grep -qE 'L1' '${SKILL_FILE}' && grep -qE 'L2' '${SKILL_FILE}' && grep -qE 'L3' '${SKILL_FILE}' && grep -qE 'event-saga' '${SKILL_FILE}' && grep -qE 'RBAC' '${SKILL_FILE}' && grep -qE 'fstore rebuild' '${SKILL_FILE}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed — intent-match verifier 113.4 wired."
exit 0
