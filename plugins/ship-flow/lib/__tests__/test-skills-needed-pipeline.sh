#!/usr/bin/env bash
# test-skills-needed-pipeline.sh — contract coverage for #108.1 skills_needed pipeline

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
SCHEMA_FILE="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
EXECUTE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-execute/SKILL.md"

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

echo "=== test-skills-needed-pipeline.sh ==="
echo ""

echo "Block 1: plan task schema exposes skills_needed"
check "entity-body-schema plan tasks include skills_needed" \
  "grep -q 'skills_needed' '${SCHEMA_FILE}'"
check "skills_needed schema is a string list" \
  "grep -qE 'skills_needed.*type: list|skills_needed.*string array' '${SCHEMA_FILE}'"

echo "Block 2: planner derives non-boilerplate task skill lists"
check "ship-plan derives skills_needed from files_modified" \
  "grep -q 'files_modified' '${PLAN_SKILL}' && grep -q 'skills_needed' '${PLAN_SKILL}'"
check "ship-plan uses framework_detected and density skill set as inputs" \
  "grep -q 'framework_detected' '${PLAN_SKILL}' && grep -q 'density' '${PLAN_SKILL}'"
check "ship-plan requires at least two distinct skills_needed lists on non-trivial plans" \
  "grep -qE 'two distinct|≥2 distinct|>=2 distinct' '${PLAN_SKILL}'"
check "ship-plan maps common file globs to skills" \
  "grep -qE '\\*\\.tsx|tsx' '${PLAN_SKILL}' && grep -qE '\\*\\.css|css' '${PLAN_SKILL}' && grep -qE 'test-driven-development|test' '${PLAN_SKILL}'"

echo "Block 3: execute consumes skills_needed in troop prompts"
check "ship-execute reads tasks skills_needed from plan" \
  "grep -q 'skills_needed' '${EXECUTE_SKILL}'"
check "ship-execute dispatch prompt includes Skills required block" \
  "grep -q '### Skills required' '${EXECUTE_SKILL}'"
check "ship-execute falls back explicitly when skills_needed is missing" \
  "grep -qE 'missing.*skills_needed|skills_needed.*missing|fallback.*density' '${EXECUTE_SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed — skills_needed pipeline wired."
exit 0
