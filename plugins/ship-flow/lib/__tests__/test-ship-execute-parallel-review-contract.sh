#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
EXECUTE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-execute/SKILL.md"

PASS=0
FAIL=0

check() {
  local description="$1"
  local pattern="$2"

  if grep -Fq -- "$pattern" "$EXECUTE_SKILL"; then
    printf '  PASS: %s\n' "$description"
    PASS=$((PASS + 1))
  else
    printf '  FAIL: %s\n' "$description"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== test-ship-execute-parallel-review-contract.sh ==="

check \
  "eligible sibling task reviewers dispatch in parallel" \
  "dispatch all eligible task reviewers in one parallel tool-call block"

check \
  "one review loop cannot block an eligible sibling reviewer" \
  "Do not wait for one task's review/fix loop before starting an eligible sibling's reviewer."

check \
  "serial commit integration remains explicit" \
  "Review loops may run concurrently; commit integration remains serial and pathspec-locked."

echo "Results: ${PASS} passed, ${FAIL} failed"
test "$FAIL" -eq 0
