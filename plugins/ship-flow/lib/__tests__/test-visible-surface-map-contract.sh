#!/usr/bin/env bash
# test-visible-surface-map-contract.sh — visible_surface_map stage contract checks.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
DESIGN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-design/SKILL.md"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
IMPORTER="${REPO_ROOT}/plugins/ship-flow/lib/import-design-dcs.sh"

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

echo "=== test-visible-surface-map-contract.sh ==="
echo ""

check "schema defines visible_surface_map handoff field" \
  "grep -q 'name: visible_surface_map' '${SCHEMA}'"

check "schema keeps compact surface_type enum" \
  "grep -q 'region, control, state_indicator, semantic_badge' '${SCHEMA}'"

check "importer emits visible_surface_map plan import section" \
  "grep -q 'Imported visible_surface_map' '${IMPORTER}'"

check "ship-design names visible_surface_map in Hand-off to Plan" \
  "awk '/Hand-off to Plan/{in_block=1} in_block && /visible_surface_map/ && /id/ && /surface_type/ && /selector_hint/ {found=1} END{exit !found}' '${DESIGN_SKILL}'"

check "ship-design documents all-or-block visible surface coverage" \
  "awk '/visible_surface_map/{in_block=1} in_block && /all-or-block/ && /BLOCKING/ && /explicit_na/ {found=1} END{exit !found}' '${DESIGN_SKILL}'"

check "ship-design requires visible_surface_map when UI target lists are emitted" \
  "awk '/visible_surface_map/{in_block=1} in_block && /render_fidelity_targets/ && /whole_page_visual_targets/ && /must not be omitted/ {found=1} END{exit !found}' '${DESIGN_SKILL}'"

check "ship-plan imports visible_surface_map into structural or mockup parity DCs" \
  "awk '/Step 1.6/{in_block=1} in_block && /visible_surface_map/ && /structural/ && /mockup-parity/ && /explicit N\\/A/ {found=1} END{exit !found}' '${PLAN_SKILL}'"

check "ship-plan preserves visible_surface_map row count" \
  "awk '/visible_surface_map/{in_block=1} in_block && /row count/ && /BLOCK/ {found=1} END{exit !found}' '${PLAN_SKILL}'"

check "ship-verify requires rendered DOM derived visible-surface inventories" \
  "awk '/Visible surface coverage audit/{in_block=1} in_block && /rendered DOM/ && /manual TSV/ && /BLOCKING/ {found=1} END{exit !found}' '${VERIFY_SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed — visible_surface_map stage contract is wired."
exit 0
