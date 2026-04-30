#!/usr/bin/env bash
# test-skill-coverage-review-factor.sh — contract coverage for #108.2 skill-coverage review factor

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
INVARIANTS_FILE="${REPO_ROOT}/plugins/ship-flow/INVARIANTS.md"

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

echo "=== test-skill-coverage-review-factor.sh ==="
echo ""

echo "Block 1: grep-testable output contract"
check "ship-plan cross-review emits skill-coverage PASS line" \
  "grep -q 'skill-coverage: PASS' '${PLAN_SKILL}'"
check "ship-plan cross-review emits skill-coverage FAIL line with task id and reason" \
  "grep -q 'skill-coverage: FAIL — task <id>: <reason>' '${PLAN_SKILL}'"
check "ship-plan cross-review names empty skills_needed as failure" \
  "grep -qE 'empty.*skills_needed|skills_needed.*empty|non-empty.*skills_needed' '${PLAN_SKILL}'"
check "ship-plan cross-review names file-glob/skill mismatch as failure" \
  "grep -qE 'glob.*match|match.*glob|mismatch|file.*skill' '${PLAN_SKILL}'"

echo "Block 2: file signal coverage rules"
check "tsx/jsx files require react or frontend-design" \
  "grep -qE '\\*\\.tsx|\\*\\.jsx' '${PLAN_SKILL}' && grep -qE 'react|frontend-design' '${PLAN_SKILL}'"
check "css/design files require frontend-design or web-design-guidelines" \
  "grep -qE '\\*\\.css|tokens\\.css|design/' '${PLAN_SKILL}' && grep -qE 'frontend-design|web-design-guidelines' '${PLAN_SKILL}'"
check "test files require test/tdd/test-driven-development" \
  "grep -qE '\\*\\.test\\.\\*|\\*\\.spec\\.\\*|__tests__' '${PLAN_SKILL}' && grep -qE 'test-driven-development|tdd|test' '${PLAN_SKILL}'"
check "shell/lib scripts require test or best-practices" \
  "grep -qE '\\*\\.sh|bin/|lib/.*\\.sh' '${PLAN_SKILL}' && grep -qE 'best-practices|test' '${PLAN_SKILL}'"

echo "Block 3: rubric/invariant bookkeeping"
check "skill-coverage is factor 7 in ship-plan cross-review rubric" \
  "grep -qE '7\\. \\*\\*Skill Coverage\\*\\*|7\\. \\*\\*skill-coverage\\*\\*' '${PLAN_SKILL}'"
check "INVARIANTS documents skill-coverage as ship-plan rubric extension" \
  "grep -q 'skill-coverage' '${INVARIANTS_FILE}' && grep -q 'ship-plan' '${INVARIANTS_FILE}'"

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

echo "All assertions passed — skill-coverage review factor wired."
exit 0
