#!/usr/bin/env bash
# test-built-in-ui-verify.sh — ship-flow owns ui-verify as a built-in utility skill.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${PLUGIN_ROOT}/../.." &> /dev/null && pwd)"

SKILL_DIR="${PLUGIN_ROOT}/skills/ui-verify"
SKILL_FILE="${SKILL_DIR}/SKILL.md"
RUNNER="${SKILL_DIR}/bin/run.js"
VERIFY_SKILL="${PLUGIN_ROOT}/skills/ship-verify/SKILL.md"
PLAN_SKILL="${PLUGIN_ROOT}/skills/ship-plan/SKILL.md"
GENERATOR="${PLUGIN_ROOT}/lib/generate-ui-verify-spec.sh"
INVARIANTS="${PLUGIN_ROOT}/INVARIANTS.md"
CHECKER="${PLUGIN_ROOT}/bin/check-invariants.sh"

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

echo "=== test-built-in-ui-verify.sh ==="
echo ""

echo "Block 1: built-in skill files"
check "ship-flow includes ui-verify SKILL.md" \
  "[ -f '${SKILL_FILE}' ]"
check "ui-verify has an executable Node runner" \
  "[ -x '${RUNNER}' ]"
check "ui-verify frontmatter is discoverable as a ship-flow utility" \
  "grep -q '^name: ui-verify$' '${SKILL_FILE}' && grep -q '^description: Use when' '${SKILL_FILE}'"
check "ui-verify documents computed-style and whole-page boundaries" \
  "grep -q 'getComputedStyle' '${SKILL_FILE}' && grep -q 'fragment-level' '${SKILL_FILE}' && grep -q 'whole-page' '${SKILL_FILE}'"
check "runner validates YAML/mapping and drives agent-browser" \
  "grep -q 'agent-browser' '${RUNNER}' && grep -q '.claude/e2e/mappings' '${RUNNER}' && grep -q 'getComputedStyle' '${RUNNER}'"

echo "Block 2: ship-flow routes use built-in skill"
check "ship-verify invokes ship-flow:ui-verify instead of external e2e-pipeline ui-verify" \
  "grep -q 'ship-flow:ui-verify' '${VERIFY_SKILL}' && ! grep -q 'e2e-pipeline:ui-verify' '${VERIFY_SKILL}'"
check "ship-plan names ship-flow ui-verify schema for generated specs" \
  "grep -q 'schema: ship-flow:ui-verify' '${PLAN_SKILL}'"
check "generator describes built-in ship-flow ui-verify target" \
  "grep -q 'ship-flow:ui-verify' '${GENERATOR}'"

echo "Block 3: utility skill classification"
check "check-invariants allowlists ui-verify as utility skill" \
  "grep -q 'ui-verify' '${CHECKER}'"
check "INVARIANTS utility inventory lists ui-verify" \
  "grep -q 'ui-verify' '${INVARIANTS}'"
check "skill-count still passes with built-in ui-verify" \
  "bash '${CHECKER}' --check skill-count"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed — ship-flow owns ui-verify."
exit 0
