#!/usr/bin/env bash
# test-import-design-dcs.sh — contract tests for design hand-off DC import.
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-import-design-dcs.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
IMPORT_SCRIPT="${PLUGIN_ROOT}/lib/import-design-dcs.sh"
VALIDATE_SCRIPT="${PLUGIN_ROOT}/lib/validate-handoff-schema.sh"

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

echo "=== test-import-design-dcs.sh ==="
echo ""

GOOD_DESIGN="${TMP_DIR}/good-design.md"
cat > "$GOOD_DESIGN" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Keep canonical tables.
- **D2|Captain decision**: Preserve shared filter contract.
- **D3|Captain decision**: Reject read-only writes.

### Hand-off to Plan

design_constraints:
- type: schema-contract
  assertion: "Use canonical tag tables; do not add parallel tag tables."
  rationale_decision: D1
  source_artifact: "design.md"
- type: filter-contract
  assertion: "Use catalog filter keys; reject private keys."
  rationale_decision: D2
  source_artifact: "design.md"
- type: interaction
  assertion: "Read-only dimensions remain visible but reject writes."
  rationale_decision: D3
  source_artifact: "design.md"

open_decisions: []
artifact_paths:
- `design.md`
visible_surface_map:
- id: flow-control
  surface_type: control
  route: /war-room
  selector_hint: "[data-testid='flow-control']"
  visible_when: default
  intent_summary: "Captain can switch the flow control mode."
  coverage: mapped
  mapped_by: design_constraints
  rationale_decision: D1
- id: decorative-rule
  surface_type: region
  route: /war-room
  selector_hint: ".wr-divider"
  visible_when: default
  intent_summary: "Pure visual separator with no interaction or semantic status."
  coverage: explicit_na
  rationale_decision: D3
  na_rationale: "Decorative-only separator is intentionally out of audit scope."
render_fidelity_targets: []
<!-- /section:hand-off-to-plan -->
EOF

BAD_DESIGN="${TMP_DIR}/bad-design.md"
cat > "$BAD_DESIGN" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Keep canonical tables.

### Hand-off to Plan

design_constraints:
- assertion: "Missing type should fail."
  rationale_decision: D1
  source_artifact: "design.md"

open_decisions: []
render_fidelity_targets: []
<!-- /section:hand-off-to-plan -->
EOF

BAD_VISIBLE="${TMP_DIR}/bad-visible.md"
cat > "$BAD_VISIBLE" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Map visible controls.

### Hand-off to Plan

design_constraints:
- type: contract
  assertion: "Map visible controls."
  rationale_decision: D1
  source_artifact: "design.md"

visible_surface_map:
- id: missing-mapped-by
  surface_type: control
  route: /war-room
  selector_hint: "[data-testid='missing']"
  visible_when: default
  intent_summary: "This mapped row lacks mapped_by."
  coverage: mapped
  rationale_decision: D1

open_decisions: []
render_fidelity_targets: []
<!-- /section:hand-off-to-plan -->
EOF

BAD_VISIBLE_ID="${TMP_DIR}/bad-visible-id.md"
cat > "$BAD_VISIBLE_ID" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Map visible controls.

### Hand-off to Plan

design_constraints:
- type: contract
  assertion: "Map visible controls."
  rationale_decision: D1
  source_artifact: "design.md"

visible_surface_map:
- id: "Flow Control"
  surface_type: control
  route: /war-room
  selector_hint: "[data-testid='flow-control']"
  visible_when: default
  intent_summary: "This id violates the kebab-case schema pattern."
  coverage: mapped
  mapped_by: render_fidelity_targets
  rationale_decision: D1

open_decisions: []
render_fidelity_targets: []
<!-- /section:hand-off-to-plan -->
EOF

MISSING_VISIBLE_WITH_RFT="${TMP_DIR}/missing-visible-with-rft.md"
cat > "$MISSING_VISIBLE_WITH_RFT" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: UI render target exists.

### Hand-off to Plan

design_constraints:
- type: contract
  assertion: "Map visible controls."
  rationale_decision: D1
  source_artifact: "design.md"

open_decisions: []
render_fidelity_targets:
- selector: "[data-testid='flow-control']"
  css_property: display
  expected_value: block
  rationale_decision: D1
<!-- /section:hand-off-to-plan -->
EOF

INDENTED_VISIBLE="${TMP_DIR}/indented-visible.md"
cat > "$INDENTED_VISIBLE" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Map visible controls.

### Hand-off to Plan

design_constraints:
- type: contract
  assertion: "Map visible controls."
  rationale_decision: D1
  source_artifact: "design.md"

  visible_surface_map:
  - id: indented-control
    surface_type: control
    route: /war-room
    selector_hint: "[data-testid='indented-control']"
    visible_when: default
    intent_summary: "Captain can use the indented control."
    coverage: mapped
    mapped_by: render_fidelity_targets
    rationale_decision: D1

open_decisions: []
render_fidelity_targets: []
<!-- /section:hand-off-to-plan -->
EOF

BAD_INDENTED_VISIBLE="${TMP_DIR}/bad-indented-visible.md"
cat > "$BAD_INDENTED_VISIBLE" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Map visible controls.

### Hand-off to Plan

design_constraints:
- type: contract
  assertion: "Map visible controls."
  rationale_decision: D1
  source_artifact: "design.md"

  visible_surface_map:
  - id: indented-missing-mapped-by
    surface_type: control
    route: /war-room
    selector_hint: "[data-testid='indented-missing']"
    visible_when: default
    intent_summary: "This indented mapped row lacks mapped_by."
    coverage: mapped
    rationale_decision: D1

open_decisions: []
render_fidelity_targets: []
<!-- /section:hand-off-to-plan -->
EOF

REORDERED_QUOTED_VISIBLE="${TMP_DIR}/reordered-quoted-visible.md"
cat > "$REORDERED_QUOTED_VISIBLE" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: YAML map key order is not semantic.

### Hand-off to Plan

design_constraints:
- type: contract
  assertion: "Map visible controls."
  rationale_decision: D1
  source_artifact: "design.md"

visible_surface_map:
- surface_type: "control"
  route: "/war-room"
  selector_hint: "[data-testid='quoted-control']"
  visible_when: "default"
  intent_summary: "Captain can use the quoted control."
  coverage: "mapped"
  mapped_by: "render_fidelity_targets"
  rationale_decision: "D1"
  id: "quoted-control"

open_decisions: []
render_fidelity_targets: []
<!-- /section:hand-off-to-plan -->
EOF

IMPORT_OUT="${TMP_DIR}/import.out"
INDENTED_IMPORT_OUT="${TMP_DIR}/indented-import.out"
REORDERED_QUOTED_IMPORT_OUT="${TMP_DIR}/reordered-quoted-import.out"

echo "Block 1: top-level YAML list design_constraints import 1:1"
check "validator accepts domain constraint types" \
  "bash '${VALIDATE_SCRIPT}' '${GOOD_DESIGN}'"
check "importer succeeds on top-level '- type:' items" \
  "bash '${IMPORT_SCRIPT}' '${GOOD_DESIGN}' > '${IMPORT_OUT}'"
check "importer emits all source design constraints" \
  "[ \$(awk '/### Imported design_constraints/{in_block=1; next} /### Imported visible_surface_map/{in_block=0} in_block && /^\\| [0-9]/{n++} END{print n+0}' '${IMPORT_OUT}') -eq 3 ]"
check "importer preserves schema-contract type" \
  "grep -q '| 1 | schema-contract |' '${IMPORT_OUT}'"
check "importer preserves filter-contract type" \
  "grep -q '| 2 | filter-contract |' '${IMPORT_OUT}'"
check "importer emits visible_surface_map section" \
  "grep -q '### Imported visible_surface_map' '${IMPORT_OUT}'"
check "importer preserves mapped visible surface row" \
  "grep -q 'flow-control' '${IMPORT_OUT}'"
check "importer preserves explicit N/A visible surface row" \
  "grep -q 'explicit_na' '${IMPORT_OUT}' && grep -q 'decorative-rule' '${IMPORT_OUT}'"

echo "Block 2: malformed structured hand-off fails before partial import"
check "validator rejects item missing type" \
  "! bash '${VALIDATE_SCRIPT}' '${BAD_DESIGN}'"
check "importer rejects item missing type" \
  "! bash '${IMPORT_SCRIPT}' '${BAD_DESIGN}' > /dev/null"
check "validator rejects mapped visible surface without mapped_by" \
  "! bash '${VALIDATE_SCRIPT}' '${BAD_VISIBLE}'"
check "importer rejects mapped visible surface without mapped_by" \
  "! bash '${IMPORT_SCRIPT}' '${BAD_VISIBLE}' > /dev/null"
check "validator rejects visible surface id outside schema pattern" \
  "! bash '${VALIDATE_SCRIPT}' '${BAD_VISIBLE_ID}'"
check "validator requires visible_surface_map when render targets are present" \
  "! bash '${VALIDATE_SCRIPT}' '${MISSING_VISIBLE_WITH_RFT}'"
check "validator rejects indented mapped visible surface without mapped_by" \
  "! bash '${VALIDATE_SCRIPT}' '${BAD_INDENTED_VISIBLE}'"
check "validator accepts indented visible_surface_map" \
  "bash '${VALIDATE_SCRIPT}' '${INDENTED_VISIBLE}'"
check "importer preserves indented visible_surface_map row" \
  "bash '${IMPORT_SCRIPT}' '${INDENTED_VISIBLE}' > '${INDENTED_IMPORT_OUT}' && grep -q 'indented-control' '${INDENTED_IMPORT_OUT}'"
check "validator accepts reordered keys and quoted visible surface values" \
  "bash '${VALIDATE_SCRIPT}' '${REORDERED_QUOTED_VISIBLE}'"
check "importer preserves reordered quoted visible_surface_map row" \
  "bash '${IMPORT_SCRIPT}' '${REORDERED_QUOTED_VISIBLE}' > '${REORDERED_QUOTED_IMPORT_OUT}' && grep -q 'quoted-control' '${REORDERED_QUOTED_IMPORT_OUT}' && grep -q '| mapped |' '${REORDERED_QUOTED_IMPORT_OUT}'"

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
