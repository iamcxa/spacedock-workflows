#!/usr/bin/env bash
# test-ship-flow-ci-scope.sh - ship-flow CI full-suite path scoping.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/ship-flow-invariants.yml"

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

echo "=== test-ship-flow-ci-scope.sh ==="
echo ""

check "workflow triggers when ship-flow workflow changes" \
  "grep -q \"'.github/workflows/ship-flow-invariants.yml'\" '${WORKFLOW}'"

check "workflow detects changed-file scope before full suite" \
  "grep -q 'id: ship_flow_scope' '${WORKFLOW}' && grep -q 'git diff --name-only' '${WORKFLOW}'"

check "full suite is limited to plugin or workflow changes" \
  "awk '/Run full ship-flow shell test suite/{in_step=1} in_step && /^      - name: / && !/Run full ship-flow shell test suite/{in_step=0} in_step && /if: steps\\.ship_flow_scope\\.outputs\\.full_suite == '\\''true'\\''/{found=1} END{exit !found}' '${WORKFLOW}'"

check "docs-only PRs keep lightweight gate without full suite" \
  "grep -q 'docs_only_lightweight=true' '${WORKFLOW}' && grep -q 'full_suite=false' '${WORKFLOW}'"

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
