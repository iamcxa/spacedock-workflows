#!/usr/bin/env bash
# integration/test-rebase-resolve-additive-dogfood.sh
#
# Host artifacts needed:
#   docs/ship-flow/_mods/pr-merge.md — adopted workflow pr-merge mod
#
# Why not standalone: pr-merge.md only exists in the adopted host project.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../.." && pwd)"
FAIL=0

pass() { echo "OK $1"; }
fail() { echo "FAIL $1"; FAIL=1; }

echo "--- integration: rebase-resolve-additive — dogfood pr-merge mod ---"
if grep -q "rebase-resolve-additive.sh" "${REPO_ROOT}/docs/ship-flow/_mods/pr-merge.md"; then
  pass "pr-merge mod wires rebase-resolve-additive.sh"
else
  fail "pr-merge mod missing rebase-resolve-additive.sh reference"
fi

exit "$FAIL"
