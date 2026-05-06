#!/usr/bin/env bash
# test-synthetic-design-dispatch-fixture.sh — 115.4 UI+domain design dispatch fixture

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REGISTRY_SCRIPT="${SCRIPT_DIR}/../registry-resolve.sh"
RECEIPT_SCRIPT="${SCRIPT_DIR}/../check-guidance-receipt.sh"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/synthetic-design-dispatch"
ADOPTER_CONFIG="${FIXTURE_DIR}/.claude/ship-flow/domains.yaml"
SKILL_ROUTING_CONFIG="${FIXTURE_DIR}/.claude/ship-flow/skill-routing.yaml"
SPEC_FILE="${FIXTURE_DIR}/shape.md"
SHAPE_FILE="${FIXTURE_DIR}/shape.md"
DESIGN_FILE="${FIXTURE_DIR}/design.md"
MISSING_DESIGN_FILE="${FIXTURE_DIR}/design-missing-receipt.md"
NO_GUIDANCE_DESIGN_FILE="${FIXTURE_DIR}/design-no-folder-guidance.md"
PLAN_FILE="${FIXTURE_DIR}/plan.md"
EXECUTE_FILE="${FIXTURE_DIR}/execute.md"
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

echo "=== test-synthetic-design-dispatch-fixture.sh ==="
echo ""

echo "Block 1: fixture stays local and CRM-shaped"
check "synthetic UI+domain fixture files exist" \
  "[ -f '${ADOPTER_CONFIG}' ] && [ -f '${SKILL_ROUTING_CONFIG}' ] && [ -f '${SPEC_FILE}' ] && [ -f '${SHAPE_FILE}' ] && [ -f '${DESIGN_FILE}' ] && [ -f '${PLAN_FILE}' ] && [ -f '${EXECUTE_FILE}' ] && [ -f '${VERIFY_FILE}' ]"
check "fixture does not reference the real carlove checkout" \
  "! grep -R '/Users/kent/Project/carlove' '${FIXTURE_DIR}'"
check "fixture includes UI, schema, and fmodel-like file paths" \
  "grep -q 'apps/web/app/crm' '${SPEC_FILE}' && grep -q 'apps/supabase/migrations' '${SPEC_FILE}' && grep -q 'domains/crm/src/domain' '${SPEC_FILE}'"

echo "Block 2: registry resolves schema skills"
check_stdout "registry classifies fixture shape to matched=schema" \
  "matched=schema" \
  "\"${REGISTRY_SCRIPT}\" --classify \"${SPEC_FILE}\" --adopter-config=\"${ADOPTER_CONFIG}\""
check_stdout "registry emits required_skills for downstream workers" \
  "required_skills=project-db,fmodel" \
  "\"${REGISTRY_SCRIPT}\" --classify \"${SPEC_FILE}\" --adopter-config=\"${ADOPTER_CONFIG}\""
check_stdout "registry emits plan skill hints" \
  "skill_hints.plan=project-db,fmodel" \
  "\"${REGISTRY_SCRIPT}\" --classify \"${SPEC_FILE}\" --adopter-config=\"${ADOPTER_CONFIG}\""

echo "Block 3: shape and design evidence route UI+domain lanes"
check "shape evidence records affects_ui and schema domain" \
  "grep -q 'affects_ui: true' '${SHAPE_FILE}' && grep -q 'domain: schema' '${SHAPE_FILE}'"
check "design evidence includes design-dispatch-manifest" \
  "grep -q '^design-dispatch-manifest:' '${DESIGN_FILE}'"
check "design manifest has ui-designer and domain-designer lanes" \
  "grep -q 'role: ui-designer' '${DESIGN_FILE}' && grep -q 'role: domain-designer' '${DESIGN_FILE}'"
check "design manifest uses parallel integration for UI+domain" \
  "grep -q 'mode: parallel' '${DESIGN_FILE}' && grep -q 'owner: ship-design' '${DESIGN_FILE}'"
check "design evidence includes Category A UI chain and Schema Design Output" \
  "grep -q 'Category A' '${DESIGN_FILE}' && grep -q 'design-brief' '${DESIGN_FILE}' && grep -q '^## Schema Design Output$' '${DESIGN_FILE}'"
check "design evidence carries adopter routing and folder guidance receipts" \
  "grep -q 'skills_needed: refine-expert,refine-gotchas,antd-expert,react-patterns,tailwind-expert' '${DESIGN_FILE}' && grep -q 'folder_guidance_files: apps/refine-app/CLAUDE.md' '${DESIGN_FILE}' && grep -q 'Context Read Receipt' '${DESIGN_FILE}'"
check "design evidence records whole-page parity target beyond fragment ui-verify checks" \
  "grep -q 'whole_page_visual_targets:' '${DESIGN_FILE}' && grep -q 'reference_artifact: plugins/example/design/crm-workspace.html' '${DESIGN_FILE}' && grep -q 'capture: full-page screenshot' '${DESIGN_FILE}'"
check "design evidence records risk-gated readiness review before plan" \
  "grep -q '^## Design Readiness Review$' '${DESIGN_FILE}' && grep -q 'risk_triggers:' '${DESIGN_FILE}' && grep -q 'multi-domain' '${DESIGN_FILE}' && grep -q 'derived_from:' '${DESIGN_FILE}' && grep -q 'reviewers: ui, schema, fmodel' '${DESIGN_FILE}' && grep -q 'verdict: PASS' '${DESIGN_FILE}'"
check "design readiness checker passes synthetic dispatch artifact" \
  "'${SCRIPT_DIR}/../check-design-readiness-review.sh' '${DESIGN_FILE}'"
check "design receipt checker passes complete design artifact" \
  "cd '${FIXTURE_DIR}' && '${RECEIPT_SCRIPT}' --config='${SKILL_ROUTING_CONFIG}' --files='apps/refine-app/src/pages/crm/leads/list.tsx' --artifact='${DESIGN_FILE}'"
check "design receipt checker blocks missing receipt artifact" \
  "cd '${FIXTURE_DIR}' && ! '${RECEIPT_SCRIPT}' --config='${SKILL_ROUTING_CONFIG}' --files='apps/refine-app/src/pages/crm/leads/list.tsx' --artifact='${MISSING_DESIGN_FILE}'"
check_stdout "resolver emits no folder guidance when no non-root CLAUDE/AGENTS exists" \
  '^folder_guidance_files=$' \
  "cd '${FIXTURE_DIR}' && '${SCRIPT_DIR}/../resolve-skill-routing.sh' --config='${SKILL_ROUTING_CONFIG}' --files='apps/plain-web/src/pages/home.tsx'"
check "design receipt checker allows no-guidance design artifact" \
  "cd '${FIXTURE_DIR}' && '${RECEIPT_SCRIPT}' --config='${SKILL_ROUTING_CONFIG}' --files='apps/plain-web/src/pages/home.tsx' --artifact='${NO_GUIDANCE_DESIGN_FILE}'"

echo "Block 4: plan preserves downstream skills"
check "plan includes UI skills and domain skills in task-level skills_needed" \
  "grep -q 'frontend-design' '${PLAN_FILE}' && grep -q 'refine-gotchas' '${PLAN_FILE}' && grep -q 'apps/refine-app/CLAUDE.md' '${PLAN_FILE}' && grep -q 'project-db' '${PLAN_FILE}' && grep -q 'fmodel' '${PLAN_FILE}'"
check "plan records design routing propagation PASS" \
  "grep -q 'design-routing-propagation: PASS' '${PLAN_FILE}'"
check "plan records skill-coverage PASS" \
  "grep -q 'skill-coverage: PASS' '${PLAN_FILE}'"
check "plan preserves whole-page visual parity as a verify DC" \
  "grep -q 'whole-page visual parity DC' '${PLAN_FILE}' && grep -q 'plugins/example/design/crm-workspace.html' '${PLAN_FILE}'"

echo "Block 5: stage-contract handoff reaches execute and verify"
check "execute consumes design-routed guidance receipt" \
  "grep -q 'design-routing-consumed: PASS' '${EXECUTE_FILE}' && grep -q 'apps/refine-app/CLAUDE.md' '${EXECUTE_FILE}' && grep -q 'refine-gotchas' '${EXECUTE_FILE}'"
check "execute receipt checker passes Refine task artifact" \
  "cd '${FIXTURE_DIR}' && '${RECEIPT_SCRIPT}' --config='${SKILL_ROUTING_CONFIG}' --files='apps/refine-app/src/pages/crm/leads/list.tsx' --artifact='${EXECUTE_FILE}'"
check "verify records shape-to-design-to-plan-to-execute receipt gates" \
  "grep -q 'shape-to-design: PASS' '${VERIFY_FILE}' && grep -q 'design-to-plan: PASS' '${VERIFY_FILE}' && grep -q 'plan-to-execute: PASS' '${VERIFY_FILE}' && grep -q 'execute receipt: PASS' '${VERIFY_FILE}'"
check "verify records whole-page visual parity in addition to ui-verify fragments" \
  "grep -q 'whole-page visual parity: PASS' '${VERIFY_FILE}' && grep -q 'fragment ui-verify: PASS' '${VERIFY_FILE}'"

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
