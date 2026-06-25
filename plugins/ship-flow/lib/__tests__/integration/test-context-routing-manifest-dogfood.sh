#!/usr/bin/env bash
# integration/test-context-routing-manifest-dogfood.sh
#
# Host artifacts needed:
#   docs/ship-flow/README.md  — adopted workflow README (created by captain after commission)
#   PRODUCT.md                — repo-root product doc
#   ARCHITECTURE.md           — repo-root architecture doc
#
# Why not standalone: these docs only exist in an adopted host project (e.g. spacedock-ui).
# Run from the dogfood host: bash plugins/ship-flow/lib/__tests__/integration/test-context-routing-manifest-dogfood.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../../.." &> /dev/null && pwd)"

README="${REPO_ROOT}/docs/ship-flow/README.md"
PRODUCT="${REPO_ROOT}/PRODUCT.md"
ARCHITECTURE="${REPO_ROOT}/ARCHITECTURE.md"

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

echo "=== integration: context-routing-manifest dogfood docs ==="

check "README documents context-routing-manifest contract" \
  "grep -q 'context-routing-manifest' '${README}' && grep -q 'Context Routing Receipt' '${README}' && grep -q 'prose-only' '${README}'"

check "PRODUCT documents deterministic local context routing capability" \
  "grep -q 'deterministic local context router' '${PRODUCT}' && grep -q 'context-routing-manifest' '${PRODUCT}'"

check "ARCHITECTURE documents local registry authority and append-only providers" \
  "grep -q 'local registry remains authoritative' '${ARCHITECTURE}' && grep -q 'append-only' '${ARCHITECTURE}'"

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
