#!/usr/bin/env bash
# test-review-checklists-index.sh - review checklist snapshot routing contract.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

INDEX="${INDEX:-${REPO_ROOT}/plugins/ship-flow/lib/review-checklists/INDEX.md}"
VERIFY_SKILL="${VERIFY_SKILL:-${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md}"
PANEL_SKILL="${PANEL_SKILL:-${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md}"

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

echo "=== test-review-checklists-index.sh ==="
echo ""

check "review checklist index and verify skill targets exist" \
  "test -f '${INDEX}' && test -f '${VERIFY_SKILL}' && test -f '${PANEL_SKILL}'"

check "review checklist index documents ship-verify security always-on non-trivial rule and conditional threat-surface review" \
  "grep -Eq 'security.*always-on.*non-trivial' '${INDEX}' && grep -Eq 'threat-surface-review.*conditional' '${INDEX}'"

check "review checklist index records ship-flow orchestration supersedes copied specialist scope notes" \
  "grep -q 'ship-flow orchestration supersedes copied specialist scope notes' '${INDEX}'"

check "ship-flow verify skills have no live GStack runtime path dependency" \
  "! grep -n '~/.claude/skills/gstack\\|~/.agents/skills/gstack' '${VERIFY_SKILL}' '${PANEL_SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
