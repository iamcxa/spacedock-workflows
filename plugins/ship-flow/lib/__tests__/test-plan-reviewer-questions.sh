#!/usr/bin/env bash
# test-plan-reviewer-questions.sh - plan-to-verify reviewer question handoff.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

README="${REPO_ROOT}/docs/ship-flow/README.md"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"

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

echo "=== test-plan-reviewer-questions.sh ==="
echo ""

VERIFY_STEP2_BLOCK="$(mktemp)"
trap 'rm -f "${VERIFY_STEP2_BLOCK}"' EXIT

awk '/^## Step 2 — Quality gate/{in_block=1} in_block && /^\*\*Per-surface commit count\*\*/{exit} in_block {print}' "${VERIFY_SKILL}" > "${VERIFY_STEP2_BLOCK}"

check "plan task schema exposes reviewer_questions derived from skills_needed" \
  "awk '/task_fields:/{in_block=1} in_block && /^    report:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'name: reviewer_questions' && awk '/task_fields:/{in_block=1} in_block && /^    report:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Derived from skills_needed' && awk '/task_fields:/{in_block=1} in_block && /^    report:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'domain lens'"

check "plan handoff schema exposes domain acceptance checklist for verify" \
  "awk '/name: domain_acceptance_checklist/{in_block=1} in_block && /^        - \\{ name: critical_assumptions/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Reviewer Question' && awk '/name: domain_acceptance_checklist/{in_block=1} in_block && /^        - \\{ name: critical_assumptions/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Verify Lens' && awk '/name: domain_acceptance_checklist/{in_block=1} in_block && /^        - \\{ name: critical_assumptions/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Evidence Required'"

check "verify review_lenses schema preserves reviewer question and evidence requirement" \
  "awk '/name: review_lenses/{in_block=1} in_block && /columns:/{print; exit}' '${SCHEMA}' | grep -q 'Reviewer Question' && awk '/name: review_lenses/{in_block=1} in_block && /columns:/{print; exit}' '${SCHEMA}' | grep -q 'Evidence Required'"

check "verify review_lenses accepts concrete domain lenses and affected path family" \
  "awk '/name: review_lenses/{in_block=1} in_block && /name: reviewer_output_matrix/{exit} in_block {print}' '${SCHEMA}' | grep -q 'concrete_lens' && awk '/name: review_lenses/{in_block=1} in_block && /name: reviewer_output_matrix/{exit} in_block {print}' '${SCHEMA}' | grep -q 'project-db' && awk '/name: review_lenses/{in_block=1} in_block && /name: reviewer_output_matrix/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Affected Path Family'"

check "domain acceptance checklist preserves affected path family" \
  "awk '/name: domain_acceptance_checklist/{in_block=1} in_block && /^        - \\{ name: critical_assumptions/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Affected Path Family' && awk '/^\\*\\*Emit\\*\\* `### Hand-off to Execute`/{in_emit=1; next} in_emit && /^<!-- \\/section:hand_off_to_execute -->/{exit} in_emit {print}' '${PLAN_SKILL}' | grep -q 'Affected Path Family'"

check "ship-plan requires reviewer_questions for domain and framework skills" \
  "awk '/^### Step 3 — Write plan/{in_block=1} in_block && /^### Step 3\\.5/{exit} in_block {print}' '${PLAN_SKILL}' | grep -q 'reviewer_questions' && awk '/^### Step 3 — Write plan/{in_block=1} in_block && /^### Step 3\\.5/{exit} in_block {print}' '${PLAN_SKILL}' | grep -q 'domain-specific acceptance checklist' && awk '/^### Step 3 — Write plan/{in_block=1} in_block && /^### Step 3\\.5/{exit} in_block {print}' '${PLAN_SKILL}' | grep -q 'skills_needed.*reviewer questions'"

check "ship-plan final handoff emit list includes domain acceptance checklist" \
  "awk '/^\\*\\*Emit\\*\\* `### Hand-off to Execute`/{in_emit=1; next} in_emit && /^<!-- \\/section:hand_off_to_execute -->/{exit} in_emit {print}' '${PLAN_SKILL}' | grep -q 'domain_acceptance_checklist'"

check "ship-verify consumes plan reviewer_questions into verify-check-manifest" \
  "grep -q 'reviewer_questions' '${VERIFY_STEP2_BLOCK}' && grep -q 'domain_acceptance_checklist' '${VERIFY_STEP2_BLOCK}' && grep -q 'verify-check-manifest' '${VERIFY_STEP2_BLOCK}'"

check "fallback reviewer panel consumes concrete reviewer questions" \
  "grep -q 'reviewer_questions' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md' && grep -q 'domain_acceptance_checklist' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md' && grep -q 'reviewer_question' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md' && grep -q 'affected_path_family' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md'"

check "representative project-db checklist row flows through verify lens and fallback output" \
  "awk '/name: domain_acceptance_checklist/{in_block=1} in_block && /^        - \\{ name: critical_assumptions/{exit} in_block {print}' '${SCHEMA}' | grep -q 'example_row:.*project-db.*apps/supabase/migrations' && awk '/name: review_lenses/{in_block=1} in_block && /name: reviewer_output_matrix/{exit} in_block {print}' '${SCHEMA}' | grep -q 'example_row:.*project-db.*apps/supabase/migrations' && grep -q 'For each domain_acceptance_checklist row, emit one reviewer_output_matrix item' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md'"

check "reviewer output matrix schema preserves handoff fields" \
  "awk '/name: reviewer_output_matrix/{in_block=1} in_block && /legacy_sections:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Reviewer Question' && awk '/name: reviewer_output_matrix/{in_block=1} in_block && /legacy_sections:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Affected Path Family' && awk '/name: reviewer_output_matrix/{in_block=1} in_block && /legacy_sections:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Required Skills' && awk '/name: reviewer_output_matrix/{in_block=1} in_block && /legacy_sections:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'Evidence Required'"

check "fallback reviewer output preserves required skills" \
  "awk '/^reviewer_output_matrix:/{in_block=1} in_block && /^Verifier owns final aggregation/{exit} in_block {print}' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md' | grep -q 'required_skills'"

check "verify schema reads plan handoff checklist input" \
  "awk '/^  verify:/{in_block=1} in_block && /^    output:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'domain_acceptance_checklist' && awk '/^  verify:/{in_block=1} in_block && /^    output:/{exit} in_block {print}' '${SCHEMA}' | grep -q 'reviewer_questions'"

check "fallback reviewer prompt snippet preserves required skills" \
  "awk '/^reviewer_question: <question from plan>/{in_block=1} in_block && /^$/{exit} in_block {print}' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md' | grep -q 'required_skills: <skills required by plan/checklist>'"

check "concrete prompts augment domain reviewers without replacing baseline lenses" \
  "awk '/When the input bundle includes .*reviewer_questions/{in_block=1} in_block && /^Concrete lens names/{exit} in_block {print}' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md' | grep -q 'augment domain-expert-reviewer lenses' && awk '/When the input bundle includes .*reviewer_questions/{in_block=1} in_block && /^Concrete lens names/{exit} in_block {print}' '${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md' | grep -q 'general-external-reviewer and silent-failure-reviewer still run their baseline questions'"

check "ship-verify materializes task reviewer questions that are not in checklist" \
  "grep -q 'task-level reviewer_questions that are not already represented' '${VERIFY_STEP2_BLOCK}' && grep -q 'framework-only prompts' '${VERIFY_STEP2_BLOCK}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
