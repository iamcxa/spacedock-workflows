#!/usr/bin/env bash
# integration/test-contract-design-gate-dogfood.sh
#
# Host artifacts needed:
#   docs/ship-flow/README.md — adopted workflow README
#
# Why not standalone: README.md only exists in the adopted host project.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../../.." &> /dev/null && pwd)"
README="${REPO_ROOT}/docs/ship-flow/README.md"

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

echo "=== integration: contract-design-gate README ==="

check "README says design covers contract/interface design" \
  "grep -q 'contract/interface design' '${README}' && grep -q 'selector grammar' '${README}'"
check "README design stage no longer has skip-when (W3 — design always runs per pitch 116)" \
  "! grep -A6 'name: design' '${README}' | grep -q 'skip-when:'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  for err in "${ERRORS[@]}"; do echo "  - ${err}"; done
  exit 1
fi
echo "All assertions passed"
