#!/usr/bin/env bash
# test-entity-entrypoint-index.sh — folder entities use index.md, never README.md.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
IMPORT_SCRIPT="${REPO_ROOT}/plugins/ship-flow/lib/import-design-dcs.sh"
UI_VERIFY_SCRIPT="${REPO_ROOT}/plugins/ship-flow/lib/generate-ui-verify-spec.sh"

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

echo "=== test-entity-entrypoint-index.sh ==="
echo ""

echo "Block 1: public ship-flow contract names folder entity entrypoint index.md"
check "README folder layout documents index.md as entity metadata file" \
  "grep -q '^[[:space:]]*index\\.md[[:space:]]*# entity metadata' '${REPO_ROOT}/docs/ship-flow/README.md'"
check "ship-shape entity id routing documents folder index.md" \
  "grep -q 'docs/<wf>/<id>-<slug>/index\\.md' '${REPO_ROOT}/plugins/ship-flow/skills/ship-shape/SKILL.md'"
check "ship skill entity id routing documents folder index.md" \
  "grep -Fq 'docs/<workflow>/<id>-*/index.md' '${REPO_ROOT}/plugins/ship-flow/skills/ship/SKILL.md'"
check "ship-verify reads folder index.md, not folder README.md" \
  "grep -q 'folder \`index\\.md\`' '${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md'"

echo "Block 2: folder helpers are not confused by stale README.md"
ENTITY_DIR="${TMP_DIR}/docs/ship-flow/123-index-entrypoint"
mkdir -p "$ENTITY_DIR"
cat > "${ENTITY_DIR}/README.md" <<'EOF'
# Legacy stale folder README

This file intentionally has no hand-off block. Folder entity routing must not
treat it as the entity or design hand-off source.
EOF
cat > "${ENTITY_DIR}/index.md" <<'EOF'
---
id: "123"
title: "Index entrypoint"
affects_ui: true
---

<!-- section:stage-artifact-links -->
| Stage | Artifact | Status |
|---|---|---|
| design | [design.md](design.md) | done |
<!-- /section:stage-artifact-links -->
EOF
cat > "${ENTITY_DIR}/design.md" <<'EOF'
## Design Output

### Captain Decisions

- **D1|Captain decision**: Use token-aligned primary button.

### Hand-off to Plan

design_constraints:
- type: token-binding
  assertion: "Primary CTA uses the canonical token."
  rationale_decision: D1
  source_artifact: "design.md"
open_decisions: []
artifact_paths:
- `design.md`
render_fidelity_targets:
  - selector: .primary-cta
    css_property: background-color
    expected_value: var(--primary)
    rationale_decision: D1
<!-- /section:hand-off-to-plan -->
EOF

IMPORT_OUT="${TMP_DIR}/import.out"
UI_VERIFY_OUT="${TMP_DIR}/ui-verify.yaml"

check "import-design-dcs reads folder design.md despite stale README.md" \
  "bash '${IMPORT_SCRIPT}' '${ENTITY_DIR}' > '${IMPORT_OUT}'"
check "import-design-dcs imports token-binding constraint" \
  "grep -q '| 1 | token-binding |' '${IMPORT_OUT}'"
check "generate-ui-verify-spec reads folder design.md despite stale README.md" \
  "bash '${UI_VERIFY_SCRIPT}' '${ENTITY_DIR}' 'spacebridge' > '${UI_VERIFY_OUT}'"
check "generate-ui-verify-spec emits backgroundColor check" \
  "grep -q 'backgroundColor:' '${UI_VERIFY_OUT}' && grep -q 'var(--primary)' '${UI_VERIFY_OUT}'"

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
