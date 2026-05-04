#!/usr/bin/env bash
# test-todo-lifecycle-closeout.sh - stage-wide todo capture and ship closeout prompt.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
ADD_TODOS_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/add-todos/SKILL.md"
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

echo "=== test-todo-lifecycle-closeout.sh ==="
echo ""

check "add-todos is the stage-wide out-of-scope finding capture path" \
  "grep -q 'Stage-wide capture rule' '${ADD_TODOS_SKILL}' && grep -q 'out-of-scope finding' '${ADD_TODOS_SKILL}' && grep -q 'plan/design/execute/verify/review/ship' '${ADD_TODOS_SKILL}'"

check "add-todos distinguishes follow-up candidates from rejected alternatives" \
  "grep -q 'Rejected alternatives are not todos' '${ADD_TODOS_SKILL}' && grep -q 'follow-up candidates' '${ADD_TODOS_SKILL}'"

check "ship-final requires todo digest in ship.md" \
  "grep -q 'Todo Closeout Digest' '${SHIP_SKILL}' && grep -q 'todos captured during this ship' '${SHIP_SKILL}' && grep -q 'deferred follow-ups' '${SHIP_SKILL}'"

check "ship-final asks captain to sync or continue todos" \
  "grep -q 'sync to task management' '${SHIP_SKILL}' && grep -q 'Linear' '${SHIP_SKILL}' && grep -q 'shape the next todo' '${SHIP_SKILL}' && grep -q 'leave in ROADMAP later' '${SHIP_SKILL}'"

check "ship-final keeps task-manager sync adapter-based, not Linear-hardcoded" \
  "grep -q 'adapter/mod' '${SHIP_SKILL}' && grep -qi 'do not hardcode Linear' '${SHIP_SKILL}'"

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
