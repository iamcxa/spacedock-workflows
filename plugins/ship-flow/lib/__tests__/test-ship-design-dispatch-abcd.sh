#!/usr/bin/env bash
# test-ship-design-dispatch-abcd.sh — 115.3 Category A-D designer dispatch contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
DESIGN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-design/SKILL.md"
SHAPE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-shape/SKILL.md"
INVARIANTS="${REPO_ROOT}/plugins/ship-flow/INVARIANTS.md"
README="${REPO_ROOT}/plugins/ship-flow/README.md"

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

echo "=== test-ship-design-dispatch-abcd.sh ==="
echo ""

echo "Block 1: Category A-D are executable, not deferred"
check "ship-design no longer says v1 ships Category 0 only" \
  "! grep -q 'v1 ships Category 0 only' '${DESIGN_SKILL}'"
check "ship-design no longer defers Category A-D to carlove dogfood" \
  "! grep -qE 'DEFERRED|deferred to carlove dogfood|Category \\{X\\} deferred' '${DESIGN_SKILL}'"
check "ship-design has no generic Category-not-zero halt rule" \
  "! grep -qE 'Category != 0|Category [^ ]+ halt' '${DESIGN_SKILL}'"
check "Category table marks A-D as active dispatch paths" \
  "awk '/5-Category classifier/{in_table=1} in_table && /Category A|A .*Net-new/{a=1} in_table && /Category B|B .*Component/{b=1} in_table && /Category C|C .*Variation/{c=1} in_table && /Category D|D .*One-off/{d=1} in_table && /ACTIVE|active|dispatch/{active=1} /^## Flow/{in_table=0} END{exit !(a&&b&&c&&d&&active)}' '${DESIGN_SKILL}'"

echo "Block 2: dispatch manifest and worker roles"
check "ship-design emits design-dispatch-manifest" \
  "grep -q 'design-dispatch-manifest' '${DESIGN_SKILL}'"
check "ship-design names ui-designer and domain-designer roles" \
  "grep -q 'ui-designer' '${DESIGN_SKILL}' && grep -q 'domain-designer' '${DESIGN_SKILL}'"
check "ship-design handles UI+domain as parallel designer dispatch" \
  "grep -qE 'parallel.*ui-designer.*domain-designer|ui-designer.*domain-designer.*parallel' '${DESIGN_SKILL}'"
check "ship-design allows single-designer route for small single-lane work" \
  "grep -qE 'single-designer|single designer' '${DESIGN_SKILL}'"
check "affects_ui true requires visible UI design output" \
  "grep -q 'affects_ui: true' '${DESIGN_SKILL}' && grep -q 'Visible UI Design Output' '${DESIGN_SKILL}' && grep -q 'design_constraints\\[\\]' '${DESIGN_SKILL}' && grep -q 'render_fidelity_targets\\[\\]' '${DESIGN_SKILL}'"
check "UI design-skipped requires explicit captain-approved bypass" \
  "grep -q 'captain-approved-design-bypass' '${DESIGN_SKILL}' && grep -q 'design-skipped: true.*invalid' '${DESIGN_SKILL}'"

echo "Block 3: UI skill mapping"
check "Category A uses full design-flow skill chain" \
  "grep -q 'design-brief' '${DESIGN_SKILL}' && grep -q 'information-architecture' '${DESIGN_SKILL}' && grep -q 'design-tokens' '${DESIGN_SKILL}' && grep -q 'brief-to-tasks' '${DESIGN_SKILL}' && grep -q 'frontend-design' '${DESIGN_SKILL}'"
check "Category B/C/D map to narrower frontend-design/design-review usage" \
  "grep -q 'Category B' '${DESIGN_SKILL}' && grep -q 'Category C' '${DESIGN_SKILL}' && grep -q 'Category D' '${DESIGN_SKILL}' && grep -q 'design-review' '${DESIGN_SKILL}'"
check "ship-design consumes adopter file-signal routing before UI designer dispatch" \
  "grep -q 'resolve-skill-routing.sh' '${DESIGN_SKILL}' && grep -q '.claude/ship-flow/skill-routing.yaml' '${DESIGN_SKILL}' && grep -q 'folder_guidance_files' '${DESIGN_SKILL}'"
check "ship-design requires design-time Context Read Receipt" \
  "grep -q 'Context Read Receipt' '${DESIGN_SKILL}' && grep -q 'refine-gotchas' '${DESIGN_SKILL}' && grep -q 'apps/refine-app/CLAUDE.md' '${DESIGN_SKILL}'"
check "ship-design treats concrete folder guidance paths as resolver output, not fixed rules" \
  "grep -q 'Example only: if an adopter' '${DESIGN_SKILL}' && grep -q 'do not invent or require' '${DESIGN_SKILL}' && grep -q 'none .* resolver reported no folder_guidance_files' '${DESIGN_SKILL}'"
check "ship-design does not hardcode apps/refine-app/CLAUDE.md outside example-only text" \
  "awk 'BEGIN{prev=\"\"} /apps\\/refine-app\\/CLAUDE.md/{count++; if (prev !~ /Example only: if an adopter/) bad=1} {prev=\$0} END{exit !((count == 1) && !bad)}' '${DESIGN_SKILL}'"

echo "Block 4: upstream docs and spawn prompts"
check "ship-shape designer spawn routes Category 0/A/B/C/D and domain triggers" \
  "grep -q 'route Category 0/A/B/C/D' '${SHAPE_SKILL}' && grep -q 'domain:' '${SHAPE_SKILL}'"
check "INVARIANTS documents Category A-D design skill mapping" \
  "grep -q 'Category A-D' '${INVARIANTS}' && grep -q 'design-brief' '${INVARIANTS}' && grep -q 'frontend-design' '${INVARIANTS}'"
check "plugin README documents domain-aware design skip and active Category A-D" \
  "grep -q 'skip-when: !affects_ui && !domain' '${README}' && grep -q 'Category A-D' '${README}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed — ship-design Category A-D dispatch wired."
exit 0
