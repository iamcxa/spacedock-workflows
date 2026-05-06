#!/usr/bin/env bash
# test-synthetic-schema-pitch-fixture.sh — 113.7 synthetic schema pitch evidence chain
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-synthetic-schema-pitch-fixture.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REGISTRY_SCRIPT="${SCRIPT_DIR}/../registry-resolve.sh"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/synthetic-schema-pitch"
ADOPTER_CONFIG="${FIXTURE_DIR}/.claude/ship-flow/domains.yaml"
SPEC_FILE="${FIXTURE_DIR}/shape.md"
SHAPE_FILE="${FIXTURE_DIR}/shape.md"
DESIGN_FILE="${FIXTURE_DIR}/design.md"
VERIFY_FILE="${FIXTURE_DIR}/verify.md"

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

check_stdout() {
  local desc="$1"
  local pattern="$2"
  local cmd="$3"
  local stdout_out
  stdout_out=$(eval "$cmd" 2>/dev/null || true)
  if echo "$stdout_out" | grep -qE "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (stdout did not contain '$pattern')"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

echo "=== test-synthetic-schema-pitch-fixture.sh ==="
echo ""

echo "Block 1: fixture stays local but is carlove-shaped"
check "synthetic fixture files exist" \
  "[ -f '${ADOPTER_CONFIG}' ] && [ -f '${SPEC_FILE}' ] && [ -f '${SHAPE_FILE}' ] && [ -f '${DESIGN_FILE}' ] && [ -f '${VERIFY_FILE}' ]"
check "fixture does not reference the real carlove checkout" \
  "! grep -R '/Users/kent/Project/carlove' '${FIXTURE_DIR}'"
check "fixture includes representative carlove schema paths" \
  "grep -qE 'domains/.+/src/(schema|.+\\.table\\.ts)|apps/supabase/migrations' '${SPEC_FILE}'"

echo "Block 2: shape evidence resolves schema domain"
check_stdout "registry classifies fixture shape to matched=schema" \
  "matched=schema" \
  "\"${REGISTRY_SCRIPT}\" --classify \"${SPEC_FILE}\" --adopter-config=\"${ADOPTER_CONFIG}\""
check "shape evidence includes Domain Registry Validation block" \
  "grep -q '^## Domain Registry Validation$' '${SHAPE_FILE}'"
check "shape evidence records domain: schema" \
  "grep -q 'domain: schema' '${SHAPE_FILE}'"
check "shape evidence records proceed result" \
  "grep -q 'result: proceed' '${SHAPE_FILE}'"

echo "Block 3: design and verify evidence chain"
check "design evidence includes Schema Design Output block" \
  "grep -q '^## Schema Design Output$' '${DESIGN_FILE}'"
check "schema design output covers L1/L2/L3 layers" \
  "grep -q 'L1 decider' '${DESIGN_FILE}' && grep -q 'L2 fstore' '${DESIGN_FILE}' && grep -q 'L3 view' '${DESIGN_FILE}'"
check "schema design output covers migration, RBAC, and rebuild concerns" \
  "grep -q 'Migration safety' '${DESIGN_FILE}' && grep -q 'RBAC and tenancy' '${DESIGN_FILE}' && grep -q 'Projection / fstore rebuild' '${DESIGN_FILE}'"
check "verify evidence includes Intent Match Findings block" \
  "grep -q '^## Intent Match Findings$' '${VERIFY_FILE}'"
check "intent findings compare design intent to execute evidence" \
  "grep -qE 'design intent|execute evidence|execute diff' '${VERIFY_FILE}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
exit 0
