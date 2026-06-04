#!/usr/bin/env bash
# test-reference-not-restate-fixture.sh — 129.1 schema de-dup contract.
#
# Proves an entity authored under the new entity-body-schema.yaml validates AND
# carries DC-N references downstream instead of restated DC assertion/type prose,
# while the Verify Procedure stays inline in execute/verify UAT (T2 guardrail).
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-reference-not-restate-fixture.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/reference-not-restate"
SHAPE="${FIXTURE_DIR}/shape.md"
PLAN="${FIXTURE_DIR}/plan.md"
EXECUTE="${FIXTURE_DIR}/execute.md"
VERIFY="${FIXTURE_DIR}/verify.md"

# The canonical assertion prose that lives ONLY in shape.md. Downstream stages
# must NOT restate it — they cite DC-N instead.
DC1_ASSERTION="extract-section.sh returns the Done-Criteria block for a folder-layout entity"
DC2_ASSERTION="extract-section.sh returns the Done-Criteria block for a flat-layout entity"

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

echo "=== 129.1 reference-not-restate fixture contract ==="
echo "Fixture: $FIXTURE_DIR"
echo ""

# --- Canonical home: shape.md owns the assertion + type for both DCs. ---
check "shape.md is the canonical home of the DC-1 assertion" \
  "grep -qF \"$DC1_ASSERTION\" \"$SHAPE\""
check "shape.md is the canonical home of the DC-2 assertion" \
  "grep -qF \"$DC2_ASSERTION\" \"$SHAPE\""
check "shape.md DC lines carry the typed DC-N format" \
  "grep -qE '^- \\[ \\] \`cli\` — DC-1:' \"$SHAPE\" && grep -qE '^- \\[ \\] \`cli\` — DC-2:' \"$SHAPE\""

# --- Reference-not-restate: downstream stages key by DC-N. ---
check "plan Verification Spec rows are keyed by DC-N" \
  "grep -qE '^\\| DC-1 \\|' \"$PLAN\" && grep -qE '^\\| DC-2 \\|' \"$PLAN\""
check "execute UAT rows are keyed by DC-N" \
  "grep -qE '^\\| DC-1 \\|' \"$EXECUTE\" && grep -qE '^\\| DC-2 \\|' \"$EXECUTE\""
check "verify UAT rows are keyed by DC-N" \
  "grep -qE '^\\| DC-1 \\|' \"$VERIFY\" && grep -qE '^\\| DC-2 \\|' \"$VERIFY\""

# --- Reference-not-restate: downstream stages do NOT restate the assertion prose. ---
check "plan.md does NOT restate the DC-1 assertion prose" \
  "! grep -qF \"$DC1_ASSERTION\" \"$PLAN\""
check "plan.md does NOT restate the DC-2 assertion prose" \
  "! grep -qF \"$DC2_ASSERTION\" \"$PLAN\""
check "execute.md does NOT restate the DC assertion prose" \
  "! grep -qF \"$DC1_ASSERTION\" \"$EXECUTE\" && ! grep -qF \"$DC2_ASSERTION\" \"$EXECUTE\""
check "verify.md does NOT restate the DC assertion prose" \
  "! grep -qF \"$DC1_ASSERTION\" \"$VERIFY\" && ! grep -qF \"$DC2_ASSERTION\" \"$VERIFY\""

# --- Column structure matches the new schema (Type + Assertion dropped). ---
check "plan Verification Spec header drops Type + Assertion columns" \
  "grep -qF '| DC | Verify Procedure | Expected |' \"$PLAN\""
check "execute UAT header drops Type + Assertion columns" \
  "grep -qF '| DC | Verify Procedure | Result | Evidence |' \"$EXECUTE\""
check "verify UAT header drops Type + Assertion columns" \
  "grep -qF '| DC | Verify Procedure | Execute 1st | Verify | Evidence |' \"$VERIFY\""

# --- T2 guardrail: Verify Procedure stays INLINE in execute + verify UAT. ---
check "T2: execute UAT keeps the Verify Procedure column inline (runnable command present)" \
  "grep -qF 'extract-section.sh' \"$EXECUTE\""
check "T2: verify UAT keeps the Verify Procedure column inline (runnable command present)" \
  "grep -qF 'extract-section.sh' \"$VERIFY\""

# --- Downstream reads are citations, not copy-targets. ---
check "plan reads shape.md as a citation (cite, do not restate)" \
  "grep -q 'cite, do not restate' \"$PLAN\""
check "verify reads plan + shape as citations (cite, do not restate)" \
  "[ \$(grep -c 'cite, do not restate' \"$VERIFY\" || echo 0) -ge 2 ]"

# --- Section-tag wrapping (Principle 5a) so the entity validates as active. ---
check "shape.md wraps problem/journey/done-criteria in section tags" \
  "grep -q '<!-- section:problem -->' \"$SHAPE\" && grep -q '<!-- section:done-criteria -->' \"$SHAPE\""

# --- Extractor actually resolves the canonical DC block from shape.md. ---
EXTRACTOR="${SCRIPT_DIR}/../extract-section.sh"
if [ -f "$EXTRACTOR" ]; then
  check "extract-section.sh resolves the canonical done-criteria block from shape.md" \
    "bash \"$EXTRACTOR\" \"$SHAPE\" done-criteria | grep -qF 'DC-1'"
else
  echo "  SKIP: extract-section.sh not found at $EXTRACTOR"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "All assertions passed — reference-not-restate fixture honors the 129.1 contract."
exit 0
