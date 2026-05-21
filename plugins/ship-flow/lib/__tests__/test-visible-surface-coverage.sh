#!/usr/bin/env bash
# test-visible-surface-coverage.sh — closed-list visible surface audit fixtures.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
CHECK_SCRIPT="${PLUGIN_ROOT}/lib/check-visible-surface-coverage.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

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

echo "=== test-visible-surface-coverage.sh ==="
echo ""

DESIGN="${TMP_DIR}/design.md"
cat > "$DESIGN" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Map visible controls.
- **D2|Captain decision**: Unmapped live surfaces block verify.
- **D3|Captain decision**: Ambiguous ownership routes to design first.

### Hand-off to Plan

design_constraints:
- type: contract
  assertion: "Map visible controls."
  rationale_decision: D1
  source_artifact: "design.md"

visible_surface_map:
- id: flow-control
  surface_type: control
  route: /war-room
  selector_hint: "[data-testid='flow-control']"
  visible_when: default
  intent_summary: "Captain can switch the flow control mode."
  coverage: mapped
  mapped_by: render_fidelity_targets
  rationale_decision: D1
- id: decorative-rule
  surface_type: region
  route: /war-room
  selector_hint: ".wr-divider"
  visible_when: default
  intent_summary: "Decorative separator."
  coverage: explicit_na
  rationale_decision: D1
  na_rationale: "Pure visual separator is intentionally outside audit scope."

open_decisions: []
render_fidelity_targets:
- selector: "[data-testid='flow-control']"
  css_property: display
  expected_value: block
  rationale_decision: D1
<!-- /section:hand-off-to-plan -->
EOF

LIVE_MISSING="${TMP_DIR}/live-missing.tsv"
cat > "$LIVE_MISSING" <<'EOF'
id	route	surface_type	selector_hint	visible_when	evidence_class
flow-control	/war-room	control	[data-testid='flow-control']	default	design-intent
missing-filter	/war-room	control	[data-testid='missing-filter']	default	design-intent
debug-switch	/war-room	control	[data-testid='debug-switch']	default	implementation-extra
status-badge	/war-room	semantic_badge	[data-testid='status-badge']	default	ambiguous
EOF

LIVE_COVERED="${TMP_DIR}/live-covered.tsv"
cat > "$LIVE_COVERED" <<'EOF'
id	route	surface_type	selector_hint	visible_when	evidence_class
flow-control	/war-room	control	[data-testid='flow-control']	default	design-intent
decorative-rule	/war-room	region	.wr-divider	default	design-intent
EOF

DESIGN_INDENTED="${TMP_DIR}/design-indented.md"
cat > "$DESIGN_INDENTED" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Map visible controls.

### Hand-off to Plan

  visible_surface_map:
  - id: flow-control
    surface_type: control
    route: /war-room
    selector_hint: "[data-testid='flow-control']"
    visible_when: default
    intent_summary: "Captain can switch the flow control mode."
    coverage: mapped
    mapped_by: render_fidelity_targets
    rationale_decision: D1

open_decisions: []
render_fidelity_targets:
- selector: "[data-testid='flow-control']"
  css_property: display
  expected_value: block
  rationale_decision: D1
<!-- /section:hand-off-to-plan -->
EOF

LIVE_INDENTED="${TMP_DIR}/live-indented.tsv"
cat > "$LIVE_INDENTED" <<'EOF'
id	route	surface_type	selector_hint	visible_when	evidence_class
flow-control	/war-room	control	[data-testid='flow-control']	default	design-intent
EOF

DESIGN_DEFERRED="${TMP_DIR}/design-deferred.md"
cat > "$DESIGN_DEFERRED" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Map visible controls.
- **D2|Captain decision**: Deferred blockers are not accepted coverage.

### Hand-off to Plan

visible_surface_map:
- id: deferred-filter
  surface_type: control
  route: /war-room
  selector_hint: "[data-testid='deferred-filter']"
  visible_when: default
  intent_summary: "Captain can filter deferred work."
  coverage: deferred_blocker
  rationale_decision: D2

open_decisions: []
render_fidelity_targets:
- selector: "[data-testid='flow-control']"
  css_property: display
  expected_value: block
  rationale_decision: D1
<!-- /section:hand-off-to-plan -->
EOF

LIVE_DEFERRED="${TMP_DIR}/live-deferred.tsv"
cat > "$LIVE_DEFERRED" <<'EOF'
id	route	surface_type	selector_hint	visible_when	evidence_class
deferred-filter	/war-room	control	[data-testid='deferred-filter']	default	ambiguous
EOF

DESIGN_REORDERED_QUOTED="${TMP_DIR}/design-reordered-quoted.md"
cat > "$DESIGN_REORDERED_QUOTED" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: YAML object key order is not semantic.

### Hand-off to Plan

visible_surface_map:
- surface_type: "control"
  id: "quoted-control"
  route: "/war-room"
  selector_hint: "[data-testid='quoted-control']"
  visible_when: "default"
  intent_summary: "Captain can use the quoted control."
  coverage: "mapped"
  mapped_by: "render_fidelity_targets"
  rationale_decision: "D1"

open_decisions: []
render_fidelity_targets:
- selector: "[data-testid='quoted-control']"
  css_property: display
  expected_value: block
  rationale_decision: D1
<!-- /section:hand-off-to-plan -->
EOF

LIVE_REORDERED_QUOTED="${TMP_DIR}/live-reordered-quoted.tsv"
cat > "$LIVE_REORDERED_QUOTED" <<'EOF'
id	route	surface_type	selector_hint	visible_when	evidence_class
quoted-control	/war-room	control	[data-testid='quoted-control']	default	design-intent
EOF

DESIGN_MAPPED_NOT_LIVE="${TMP_DIR}/design-mapped-not-live.md"
cat > "$DESIGN_MAPPED_NOT_LIVE" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: The flow control must exist.

### Hand-off to Plan

visible_surface_map:
- id: flow-control
  surface_type: control
  route: /war-room
  selector_hint: "[data-testid='flow-control']"
  visible_when: default
  intent_summary: "Captain can switch the flow control mode."
  coverage: mapped
  mapped_by: render_fidelity_targets
  rationale_decision: D1

open_decisions: []
render_fidelity_targets:
- selector: "[data-testid='flow-control']"
  css_property: display
  expected_value: block
  rationale_decision: D1
<!-- /section:hand-off-to-plan -->
EOF

LIVE_EMPTY="${TMP_DIR}/live-empty.tsv"
cat > "$LIVE_EMPTY" <<'EOF'
id	route	surface_type	selector_hint	visible_when	evidence_class
EOF

RENDER_PASS="${TMP_DIR}/render-pass.md"
cat > "$RENDER_PASS" <<'EOF'
#### Mechanical UI Parity

render_fidelity_targets_passed=true
16/16 PASS
EOF

RENDER_ZERO_PASS="${TMP_DIR}/render-zero-pass.md"
cat > "$RENDER_ZERO_PASS" <<'EOF'
#### Mechanical UI Parity

0/16 PASS
EOF

RENDER_PARTIAL_PASS="${TMP_DIR}/render-partial-pass.md"
cat > "$RENDER_PARTIAL_PASS" <<'EOF'
#### Mechanical UI Parity

3/16 PASS
EOF

RENDER_STAGE_TABLE_PASS="${TMP_DIR}/render-stage-table-pass.md"
cat > "$RENDER_STAGE_TABLE_PASS" <<'EOF'
#### Verify Report

| DC-6 | PASS: coverage test 8/8 PASS |
EOF

MISSING_OUT="${TMP_DIR}/missing.out"
COVERED_OUT="${TMP_DIR}/covered.out"
INDENTED_OUT="${TMP_DIR}/indented.out"
DEFERRED_OUT="${TMP_DIR}/deferred.out"
REORDERED_QUOTED_OUT="${TMP_DIR}/reordered-quoted.out"
MAPPED_NOT_LIVE_OUT="${TMP_DIR}/mapped-not-live.out"
ZERO_PASS_OUT="${TMP_DIR}/zero-pass.out"
PARTIAL_PASS_OUT="${TMP_DIR}/partial-pass.out"
STAGE_TABLE_PASS_OUT="${TMP_DIR}/stage-table-pass.out"
SIDECAR_TMP="${TMP_DIR}/sidecar-tmp"
FAKE_BIN="${TMP_DIR}/fake-bin"
mkdir -p "$SIDECAR_TMP"
mkdir -p "$FAKE_BIN"
cat > "${FAKE_BIN}/mktemp" <<EOF
#!/usr/bin/env bash
tmp_path="${SIDECAR_TMP}/visible-map"
: > "\$tmp_path"
printf '%s\\n' "\$tmp_path"
EOF
chmod +x "${FAKE_BIN}/mktemp"

check "covered live surfaces pass" \
  "bash '${CHECK_SCRIPT}' --design '${DESIGN}' --live-surfaces '${LIVE_COVERED}' --render-report '${RENDER_PASS}' > '${COVERED_OUT}'"

check "coverage report uses ship-verify visible surface heading" \
  "grep -q '^#### Visible Surface Coverage$' '${COVERED_OUT}'"

check "indented visible_surface_map rows cover live surfaces" \
  "bash '${CHECK_SCRIPT}' --design '${DESIGN_INDENTED}' --live-surfaces '${LIVE_INDENTED}' --render-report '${RENDER_PASS}' > '${INDENTED_OUT}'"

check "unmapped live surfaces fail even when render targets passed" \
  "! bash '${CHECK_SCRIPT}' --design '${DESIGN}' --live-surfaces '${LIVE_MISSING}' --render-report '${RENDER_PASS}' > '${MISSING_OUT}'"

check "failure report preserves render fidelity pass evidence" \
  "grep -q 'render_fidelity_targets_passed=true' '${MISSING_OUT}'"

check "design-intent missing surface routes to design" \
  "grep -q 'missing-filter' '${MISSING_OUT}' && grep -q 'route_to: design' '${MISSING_OUT}'"

check "implementation-extra missing surface routes to execute" \
  "grep -q 'debug-switch' '${MISSING_OUT}' && grep -q 'route_to: execute' '${MISSING_OUT}'"

check "ambiguous missing surface routes to design first" \
  "grep -q 'status-badge' '${MISSING_OUT}' && grep -q 'ambiguous ownership' '${MISSING_OUT}' && grep -q 'route_to: design' '${MISSING_OUT}'"

check "blocking severity emitted for missing live surfaces" \
  "grep -q 'BLOCKING' '${MISSING_OUT}'"

check "deferred_blocker map row remains blocking and routes design first when ownership is ambiguous" \
  "! bash '${CHECK_SCRIPT}' --design '${DESIGN_DEFERRED}' --live-surfaces '${LIVE_DEFERRED}' --render-report '${RENDER_PASS}' > '${DEFERRED_OUT}' && grep -q 'deferred-filter' '${DEFERRED_OUT}' && grep -q 'BLOCKING' '${DEFERRED_OUT}' && grep -q 'route_to: design' '${DEFERRED_OUT}' && grep -q 'ambiguous ownership' '${DEFERRED_OUT}'"

check "valid YAML key order and quoted map values cover live surfaces" \
  "bash '${CHECK_SCRIPT}' --design '${DESIGN_REORDERED_QUOTED}' --live-surfaces '${LIVE_REORDERED_QUOTED}' --render-report '${RENDER_PASS}' > '${REORDERED_QUOTED_OUT}' && grep -q 'status=pass missing_visible_surfaces=0' '${REORDERED_QUOTED_OUT}'"

check "mapped design surface missing from live inventory fails and routes to execute" \
  "! bash '${CHECK_SCRIPT}' --design '${DESIGN_MAPPED_NOT_LIVE}' --live-surfaces '${LIVE_EMPTY}' --render-report '${RENDER_PASS}' > '${MAPPED_NOT_LIVE_OUT}' && grep -q 'mapped design surface absent from live inventory' '${MAPPED_NOT_LIVE_OUT}' && grep -q 'flow-control' '${MAPPED_NOT_LIVE_OUT}' && grep -q 'route_to: execute' '${MAPPED_NOT_LIVE_OUT}'"

check "0/N PASS render report does not set render_fidelity_targets_passed true" \
  "bash '${CHECK_SCRIPT}' --design '${DESIGN}' --live-surfaces '${LIVE_COVERED}' --render-report '${RENDER_ZERO_PASS}' > '${ZERO_PASS_OUT}' && grep -q 'render_fidelity_targets_passed=false' '${ZERO_PASS_OUT}'"

check "partial N/M PASS render report does not set render_fidelity_targets_passed true" \
  "bash '${CHECK_SCRIPT}' --design '${DESIGN}' --live-surfaces '${LIVE_COVERED}' --render-report '${RENDER_PARTIAL_PASS}' > '${PARTIAL_PASS_OUT}' && grep -q 'render_fidelity_targets_passed=false' '${PARTIAL_PASS_OUT}'"

check "unrelated stage report fraction PASS does not set render_fidelity_targets_passed true" \
  "bash '${CHECK_SCRIPT}' --design '${DESIGN}' --live-surfaces '${LIVE_COVERED}' --render-report '${RENDER_STAGE_TABLE_PASS}' > '${STAGE_TABLE_PASS_OUT}' && grep -q 'render_fidelity_targets_passed=false' '${STAGE_TABLE_PASS_OUT}'"

check "temporary map file is cleaned up without missing-count sidecar" \
  "! PATH='${FAKE_BIN}':\$PATH bash '${CHECK_SCRIPT}' --design '${DESIGN}' --live-surfaces '${LIVE_MISSING}' --render-report '${RENDER_PASS}' > /dev/null && [ -z \"\$(find '${SIDECAR_TMP}' -mindepth 1 -print -quit)\" ]"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed — visible surface coverage rejects closed-list false positives."
exit 0
