#!/usr/bin/env bash
# integration/test-verify-reviewer-panel-dogfood.sh
#
# Host artifacts needed:
#   docs/ship-flow/README.md — adopted workflow README
#
# Why not standalone: README.md only exists in the adopted host project.

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../../.." &> /dev/null && pwd)"
README="${REPO_ROOT}/docs/ship-flow/README.md"

PASS=0; FAIL=0; ERRORS=()
check() {
  local desc="$1" cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1)); ERRORS+=("$desc")
  fi
}

echo "=== integration: verify-reviewer-panel README ==="
check "README documents general external reviewer baseline and domain specialization" \
  "grep -q 'general external reviewer' '${README}' && grep -q 'ship-flow:verify-reviewer-panel' '${README}' && grep -q 'domain expert panel.*specialization' '${README}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  for err in "${ERRORS[@]}"; do echo "  - ${err}"; done; exit 1
fi
echo "All assertions passed"
