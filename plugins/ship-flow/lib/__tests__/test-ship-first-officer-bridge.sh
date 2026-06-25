#!/usr/bin/env bash
# test-ship-first-officer-bridge.sh - /ship must bootstrap Spacedock FO first.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
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

echo "=== test-ship-first-officer-bridge.sh ==="
echo ""

check "ship skill requires loading spacedock:first-officer before pipeline work" \
  "grep -q 'spacedock:first-officer' '${SHIP_SKILL}' && grep -q 'before classifying' '${SHIP_SKILL}' && grep -q 'before resolving' '${SHIP_SKILL}'"

check "ship skill treats first-officer as the orchestration authority" \
  "grep -q 'First Officer is the orchestration authority' '${SHIP_SKILL}' && grep -q 'status --boot' '${SHIP_SKILL}' && grep -q 'status --resolve' '${SHIP_SKILL}'"

check "ship skill preserves shape fallback through first-officer workflow state" \
  "grep -q 'If requirements are vague' '${SHIP_SKILL}' && grep -q 'ship-flow:ship-shape' '${SHIP_SKILL}' && grep -q 'do not bypass first-officer' '${SHIP_SKILL}'"

check "ship skill is explicit that the bridge applies to Claude Code and Codex" \
  "grep -q 'Claude Code' '${SHIP_SKILL}' && grep -q 'Codex' '${SHIP_SKILL}' && grep -q 'CLAUDECODE' '${SHIP_SKILL}' && grep -q 'CODEX_THREAD_ID' '${SHIP_SKILL}'"

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
