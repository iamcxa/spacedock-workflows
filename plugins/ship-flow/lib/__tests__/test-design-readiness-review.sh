#!/usr/bin/env bash
# test-design-readiness-review.sh - executable Design Readiness Review gate.
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-design-readiness-review.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
CHECK_SCRIPT="${PLUGIN_ROOT}/lib/check-design-readiness-review.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0
ERRORS=()

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

check_success() {
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

check_fail_stdout() {
  local desc="$1"
  local pattern="$2"
  local cmd="$3"
  local stdout_out
  set +e
  stdout_out=$(eval "$cmd" 2>/dev/null)
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ] && echo "$stdout_out" | grep -qE "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (rc=$rc, stdout did not contain '$pattern')"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

UI_SCHEMA="${TMP_DIR}/ui-schema-pass.md"
cat > "$UI_SCHEMA" <<'EOF'
---
affects_ui: true
domain: schema
---

## Design Output

design-dispatch-manifest:
  lanes:
    - role: ui-designer
    - role: domain-designer

### Hand-off to Plan

design_constraints:
- type: schema-contract
  assertion: "Use canonical customer tables."
  rationale_decision: D1
  source_artifact: "design.md"
render_fidelity_targets:
- route: /crm/customers
  selector: ".crm-shell"
  expected: "display:grid"
  rationale_decision: D2
whole_page_visual_targets:
- route: /crm/customers
  reference_artifact: plugins/example/design/crm-workspace.html
  capture: full-page screenshot
  threshold: structural parity
  rationale_decision: D2

## Design Readiness Review

risk_triggers:
- multi-domain
- high-risk-ui
reviewers: ui, schema
derived_from:
- affects_ui:true
- domain:schema
- whole_page_visual_targets[]
verdict: PASS
findings:
  - reviewer: schema
    severity: PASS
    route_to: plan
    evidence: "design.md: schema-contract"
  - reviewer: ui
    severity: PASS
    route_to: plan
    evidence: "design.md: whole_page_visual_targets[]"
EOF

SCHEMA_ONLY="${TMP_DIR}/schema-only-pass.md"
cat > "$SCHEMA_ONLY" <<'EOF'
---
affects_ui: false
domain: schema
---

## Design Output

### Touched Files
- apps/supabase/migrations/20260501090000_add_customer_tag.sql

## Design Readiness Review

risk_trigger: migration
reviewers: schema
derived_from:
- domain:schema
- apps/supabase/migrations/**
verdict: PASS
findings:
  - reviewer: schema
    severity: PASS
    route_to: plan
    evidence: "migration artifact"
EOF

HIGH_RISK_UI="${TMP_DIR}/high-risk-ui-pass.md"
cat > "$HIGH_RISK_UI" <<'EOF'
---
affects_ui: true
---

## Design Output

whole_page_visual_targets:
- route: /war-room
  reference_artifact: plugins/spacebridge/design/war-room.html
  capture: full-page screenshot
  threshold: structural parity
  rationale_decision: D1

## Design Readiness Review

risk_trigger: high-risk-ui
reviewers: ui
derived_from:
- affects_ui:true
- whole_page_visual_targets[]
verdict: PASS
findings:
  - reviewer: ui
    severity: PASS
    route_to: plan
    evidence: "whole-page reference artifact"
EOF

TRIVIAL_SKIP="${TMP_DIR}/trivial-skip.md"
cat > "$TRIVIAL_SKIP" <<'EOF'
---
affects_ui: false
appetite: trivial
---

## Design Output

docs-only: true

## Design Report

Design Readiness Review: skipped - no risk trigger
EOF

MISSING_REVIEW="${TMP_DIR}/missing-review.md"
cat > "$MISSING_REVIEW" <<'EOF'
---
affects_ui: true
domain: schema
---

## Design Output

whole_page_visual_targets:
- route: /crm/customers
  reference_artifact: plugins/example/design/crm-workspace.html
  capture: full-page screenshot
  threshold: structural parity
  rationale_decision: D1
EOF

BLOCK_VERDICT="${TMP_DIR}/block-verdict.md"
cat > "$BLOCK_VERDICT" <<'EOF'
---
affects_ui: false
domain: schema
---

## Design Readiness Review

risk_trigger: migration
reviewers: schema
derived_from:
- domain:schema
verdict: BLOCK
findings:
  - reviewer: schema
    severity: BLOCK
    route_to: design
    evidence: "migration violates canonical table ownership"
EOF

WARN_VERDICT="${TMP_DIR}/warn-verdict.md"
cat > "$WARN_VERDICT" <<'EOF'
---
affects_ui: false
domain: schema
---

## Design Readiness Review

risk_trigger: migration
reviewers: schema
derived_from:
- domain:schema
verdict: WARN
findings:
  - reviewer: schema
    severity: WARN
    route_to: plan
    evidence: "migration order requires executor attention"
EOF

MISSING_REVIEWER="${TMP_DIR}/missing-required-reviewer.md"
cat > "$MISSING_REVIEWER" <<'EOF'
---
affects_ui: true
domain: schema
---

## Design Output

whole_page_visual_targets:
- route: /crm/customers
  reference_artifact: plugins/example/design/crm-workspace.html
  capture: full-page screenshot
  threshold: structural parity
  rationale_decision: D1

## Design Readiness Review

risk_trigger: multi-domain
reviewers: ui
derived_from:
- affects_ui:true
- domain:schema
verdict: PASS
findings:
  - reviewer: ui
    severity: PASS
    route_to: plan
    evidence: "whole-page reference artifact"
EOF

echo "=== test-design-readiness-review.sh ==="
echo ""

echo "Block 1: reviewer derivation"
check_success "UI+schema design passes with required reviewers" \
  "bash '${CHECK_SCRIPT}' '${UI_SCHEMA}'"
check_stdout "UI+schema derives ui,schema reviewers" \
  '^required_reviewers=ui,schema$' \
  "bash '${CHECK_SCRIPT}' '${UI_SCHEMA}'"
check_stdout "UI+schema derives multi-domain and high-risk-ui triggers" \
  '^risk_triggers=multi-domain,high-risk-ui$' \
  "bash '${CHECK_SCRIPT}' '${UI_SCHEMA}'"
check_stdout "schema-only migration derives schema reviewer" \
  '^required_reviewers=schema$' \
  "bash '${CHECK_SCRIPT}' '${SCHEMA_ONLY}'"
check_stdout "high-risk UI whole-page derives ui reviewer" \
  '^required_reviewers=ui$' \
  "bash '${CHECK_SCRIPT}' '${HIGH_RISK_UI}'"

echo "Block 2: skip and blocking gates"
check_stdout "trivial docs-only design skips with explicit reason" \
  '^status=skipped reason=no-risk-trigger$' \
  "bash '${CHECK_SCRIPT}' '${TRIVIAL_SKIP}'"
check_fail_stdout "triggered design without review blocks before plan" \
  '^status=blocked reason=design-readiness-review-missing$' \
  "bash '${CHECK_SCRIPT}' '${MISSING_REVIEW}'"
check_fail_stdout "BLOCK verdict blocks before plan" \
  '^status=blocked reason=design-readiness-verdict-block$' \
  "bash '${CHECK_SCRIPT}' '${BLOCK_VERDICT}'"
check_stdout "WARN verdict proceeds but is preserved" \
  '^status=warn verdict=WARN$' \
  "bash '${CHECK_SCRIPT}' '${WARN_VERDICT}'"
check_fail_stdout "required reviewers missing from review block fail" \
  '^status=blocked reason=design-readiness-reviewer-missing missing=schema$' \
  "bash '${CHECK_SCRIPT}' '${MISSING_REVIEWER}'"

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
