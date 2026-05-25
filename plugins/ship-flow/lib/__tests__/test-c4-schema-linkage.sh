#!/usr/bin/env bash
# test-c4-schema-linkage.sh — drift detector between entity-body-schema.yaml
# and check-invariants.sh C4 (plan-imported-design-dcs-emitted).
#
# Property: every precondition listed in the schema's
# `hand_off_to_plan.design-skipped` description corresponds to a trigger the
# C4 gate enforces. If schema adds/renames a precondition, this test fails
# until maintainer updates the C4 function AND the fixture matrix below.
#
# Background: the original bug (2026-05-24) was that the schema description
# listed 5 preconditions for design-skipped (affects_ui, domain,
# design_required, contract_decision_required, open_contract_decisions) but
# C4 only triggered on affects_ui. Three archived entities (113.5/6/7 +
# pr-merge-claude-challenge-gate + ship-flow-stage-metrics-standardization)
# slipped through. This test guards the inverse direction.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/../.."
CHECK_SCRIPT="${PLUGIN_DIR}/bin/check-invariants.sh"
SCHEMA="${PLUGIN_DIR}/references/entity-body-schema.yaml"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

mk_fixture() {
  local dir; dir=$(mktemp -d)
  mkdir -p "$dir/docs/ship-flow"
  echo "$dir"
}

mk_design_bearing_fixture() {
  local trigger_line="$1" slug="$2"
  local fx; fx=$(mk_fixture)
  mkdir -p "$fx/docs/ship-flow/${slug}/"
  cat > "$fx/docs/ship-flow/${slug}/index.md" <<EOF
---
affects_ui: false
${trigger_line}
---
EOF
  cat > "$fx/docs/ship-flow/${slug}/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
design_constraints:
  - type: contract-shape
EOF
  cat > "$fx/docs/ship-flow/${slug}/plan.md" <<'EOF'
# Plan

Standard plan body with no Imported Design DCs section.
EOF
  echo "$fx"
}

echo "=== test-c4-schema-linkage ==="

# --- Property 1: schema precondition list matches expected enumeration ---
# Extract the precondition phrases from the schema description. Anchor to the
# `design-skipped` description line; parse the "only when X, Y, Z, ..." clause.
# Expected: 5 conditions (4 frontmatter + 1 shape-output).
SCHEMA_DESC=$(awk '/^[[:space:]]*- name: design-skipped/,/^[[:space:]]*required: true/' "$SCHEMA" | grep -E '^[[:space:]]*description:')
if [ -z "$SCHEMA_DESC" ]; then
  echo "FAIL schema-desc-extractable (could not locate design-skipped description)"; FAIL=1
else
  echo "OK schema-desc-extractable"
fi

# Required preconditions per schema description (anchored substrings).
# If schema rewords any of these, this test fails — forcing review of C4 + this test.
EXPECTED_PRECONDITIONS=(
  "affects_ui=false"
  "domain is unset"
  "design_required=false"
  "contract_decision_required=false"
  "open_contract_decisions is empty"
)
MISSING_FROM_SCHEMA=0
for p in "${EXPECTED_PRECONDITIONS[@]}"; do
  if ! grep -qF "$p" <<< "$SCHEMA_DESC"; then
    echo "FAIL schema-precondition-present: '$p' not found in design-skipped description"
    MISSING_FROM_SCHEMA=1
  fi
done
if [ "$MISSING_FROM_SCHEMA" = "0" ]; then
  echo "OK schema-precondition-present (all 5 documented)"
else
  FAIL=1
fi

# --- Property 2: each frontmatter precondition fires C4 when violated ---
# (open_contract_decisions is a shape-output body field, not frontmatter;
# tracked as a known C4 gap below, not yet enforced by check-invariants.sh.)

f=$(mk_design_bearing_fixture "domain: ship-flow-pr" "994-domain")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "schema-trigger-domain"
rm -rf "$f"

f=$(mk_design_bearing_fixture "design_required: true" "995-design-req")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "schema-trigger-design-required"
rm -rf "$f"

f=$(mk_design_bearing_fixture "contract_decision_required: true" "996-contract")
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "schema-trigger-contract-decision-required"
rm -rf "$f"

# affects_ui=true is the original (pre-2026-05-24) trigger; cover it for parity.
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/993-ui/"
cat > "$f/docs/ship-flow/993-ui/index.md" <<'EOF'
---
affects_ui: true
---
EOF
cat > "$f/docs/ship-flow/993-ui/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
design_constraints:
  - type: token-binding
EOF
cat > "$f/docs/ship-flow/993-ui/plan.md" <<'EOF'
# Plan

Standard plan body with no Imported Design DCs section.
EOF
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check plan-imported-design-dcs-emitted" "schema-trigger-affects-ui"
rm -rf "$f"

# --- Known gap: open_contract_decisions ---
# Schema lists 5 preconditions but C4 enforces 4 (the frontmatter subset).
# `open_contract_decisions` lives in `## Sharp Output` (entity body), not
# frontmatter — C4 would need a body-extract pass to grep for non-empty entries.
# When/if that lands, add the 5th fixture case here and remove this banner.
echo "KNOWN-GAP open_contract_decisions: documented in schema, not yet enforced by C4 (would require body parse)"

if [ "$FAIL" = "0" ]; then
  echo ""
  echo "=== test-c4-schema-linkage: ALL TESTS PASSED ==="
else
  echo ""
  echo "=== test-c4-schema-linkage: FAILURES ABOVE ==="
fi
exit "$FAIL"
