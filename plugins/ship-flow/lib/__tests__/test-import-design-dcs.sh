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

IMPORT_OUT="${TMP_DIR}/import.out"

echo "Block 1: top-level YAML list design_constraints import 1:1"
check "validator accepts domain constraint types" \
  "bash '${VALIDATE_SCRIPT}' '${GOOD_DESIGN}'"
check "importer succeeds on top-level '- type:' items" \
  "bash '${IMPORT_SCRIPT}' '${GOOD_DESIGN}' > '${IMPORT_OUT}'"
check "importer emits all source design constraints" \
  "[ \$(grep -c '^| [0-9]' '${IMPORT_OUT}') -eq 3 ]"
check "importer preserves schema-contract type" \
  "grep -q '| 1 | schema-contract |' '${IMPORT_OUT}'"
check "importer preserves filter-contract type" \
  "grep -q '| 2 | filter-contract |' '${IMPORT_OUT}'"

echo "Block 2: malformed structured hand-off fails before partial import"
check "validator rejects item missing type" \
  "! bash '${VALIDATE_SCRIPT}' '${BAD_DESIGN}'"
check "importer rejects item missing type" \
  "! bash '${IMPORT_SCRIPT}' '${BAD_DESIGN}' > /dev/null"

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
