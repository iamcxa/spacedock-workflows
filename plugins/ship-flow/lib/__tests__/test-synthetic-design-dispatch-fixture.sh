#!/usr/bin/env bash
# test-synthetic-design-dispatch-fixture.sh — 115.4 UI+domain design dispatch fixture

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REGISTRY_SCRIPT="${SCRIPT_DIR}/../registry-resolve.sh"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/synthetic-design-dispatch"
ADOPTER_CONFIG="${FIXTURE_DIR}/.claude/ship-flow/domains.yaml"
SPEC_FILE="${FIXTURE_DIR}/spec.md"
SHAPE_FILE="${FIXTURE_DIR}/shape.md"
DESIGN_FILE="${FIXTURE_DIR}/design.md"
PLAN_FILE="${FIXTURE_DIR}/plan.md"

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
  "[ -f '${ADOPTER_CONFIG}' ] && [ -f '${SPEC_FILE}' ] && [ -f '${SHAPE_FILE}' ] && [ -f '${DESIGN_FILE}' ] && [ -f '${PLAN_FILE}' ]"
check "fixture does not reference the real carlove checkout" \
  "! grep -R '/Users/kent/Project/carlove' '${FIXTURE_DIR}'"
check "fixture includes UI, schema, and fmodel-like file paths" \
  "grep -q 'apps/web/app/crm' '${SPEC_FILE}' && grep -q 'apps/supabase/migrations' '${SPEC_FILE}' && grep -q 'domains/crm/src/domain' '${SPEC_FILE}'"

echo "Block 2: registry resolves schema skills"
check_stdout "registry classifies fixture spec to matched=schema" \
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

echo "Block 4: plan preserves downstream skills"
check "plan includes UI skills and domain skills in task-level skills_needed" \
  "grep -q 'frontend-design' '${PLAN_FILE}' && grep -q 'project-db' '${PLAN_FILE}' && grep -q 'fmodel' '${PLAN_FILE}'"
check "plan records skill-coverage PASS" \
  "grep -q 'skill-coverage: PASS' '${PLAN_FILE}'"

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
