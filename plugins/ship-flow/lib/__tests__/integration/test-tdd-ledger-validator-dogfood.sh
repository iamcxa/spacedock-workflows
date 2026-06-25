#!/usr/bin/env bash
# integration/test-tdd-ledger-validator-dogfood.sh
#
# Host artifacts needed:
#   docs/ship-flow/README.md — adopted workflow README with TDD ledger docs
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

echo "=== integration: tdd-ledger-validator README ==="
check "README documents TDD ledger gate and core/domain-pack boundary" \
  "grep -q 'tdd-ledger.jsonl' '${README}' && grep -q 'core gate' '${README}' && grep -q 'domain-pack' '${README}' && grep -q -- '--require-ledger-jsonl' '${README}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  for err in "${ERRORS[@]}"; do echo "  - ${err}"; done; exit 1
fi
echo "All assertions passed"
