#!/usr/bin/env bash
# test-parallel-stage-contract.sh - stage-internal parallelism contract.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
README="${REPO_ROOT}/docs/ship-flow/README.md"
TEMPLATE="${REPO_ROOT}/plugins/ship-flow/workflow-template.yaml"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
DESIGN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-design/SKILL.md"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
EXECUTE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-execute/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"

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

echo "=== test-parallel-stage-contract.sh ==="
echo ""

check "dogfood README defines stage-internal parallelism with serial stage chain" \
  "grep -q 'stage-internal parallelism' '${README}' && grep -q 'stage chain remains serial' '${README}' && grep -q 'single integrator' '${README}'"

check "dogfood README names concrete parallel artifacts without undefined manifests" \
  "grep -q 'design-dispatch-manifest' '${README}' && grep -q 'execute-dispatch-manifest' '${README}' && grep -q 'verify-check-manifest' '${README}' && ! grep -q 'shape-probe-manifest' '${README}'"

check "ship-capture helper mtime resolution is numeric on GNU and BSD stat" \
  "grep -q 'stat -c %Y' '${README}' && grep -q 'stat -f %m' '${README}' && ! grep -q 'stat -f %m.*|| stat -c %Y' '${README}'"

check "workflow template keeps concurrency numeric and declares semantic parallelism separately" \
  "grep -q 'parallelism: lanes' '${TEMPLATE}' && grep -q 'parallelism: dag' '${TEMPLATE}' && grep -q 'parallelism: checks' '${TEMPLATE}' && ! grep -qE 'concurrency: (probes|lanes|draft-lanes|dag|checks)' '${TEMPLATE}'"

check "entity schema exposes plan parallel metadata" \
  "grep -q 'parallel_group' '${SCHEMA}' && grep -q 'depends_on' '${SCHEMA}' && grep -q 'owned_paths' '${SCHEMA}' && grep -q 'integration_owner' '${SCHEMA}'"

check "entity schema requires serial parallel_group and table manifest" \
  "grep -q \"Required on every task. Use 'serial'\" '${SCHEMA}' && grep -A3 'name: plan_parallelization_manifest' '${SCHEMA}' | grep -q 'type: table'"

check "plan parallelization manifest uses canonical T task ids" \
  "grep -q 'task_id.*T{N}' '${PLAN_SKILL}' && grep -A5 'name: plan_parallelization_manifest' '${SCHEMA}' | grep -q 'Task ID'"

check "verify frontmatter description matches execute-only feedback contract" \
  "grep -q 'feedback-to: \"execute\"' '${TEMPLATE}' && grep -q 'Stage feedback returns to execute' '${TEMPLATE}' && ! grep -q 'Verify-stage captain UAT feedback routes to execute/design/plan/follow-up' '${TEMPLATE}'"

check "stage skills preserve integrator and manifest handoff requirements" \
  "grep -q 'execute-dispatch-manifest' '${PLAN_SKILL}' && grep -q 'integration_owner' '${PLAN_SKILL}' && grep -q 'execute-dispatch-manifest' '${EXECUTE_SKILL}' && grep -q 'verify-check-manifest' '${VERIFY_SKILL}'"

check "domain expert panel contract is wired through design plan and verify" \
  "grep -q 'domain expert panel' '${README}' && grep -q 'skills_needed' '${README}' && grep -q 'correct worktree' '${README}' && grep -q 'findings-only' '${README}' && grep -q 'domain-expert' '${DESIGN_SKILL}' && grep -q 'domain risk' '${DESIGN_SKILL}' && grep -q 'domain-specific acceptance checklist' '${PLAN_SKILL}' && grep -q 'skills_needed into reviewer questions' '${PLAN_SKILL}' && grep -q 'low-model domain reviewers' '${VERIFY_SKILL}' && grep -q 'repo path, branch, base/head, and changed files' '${VERIFY_SKILL}' && grep -q 'Critical/Important/Minor' '${VERIFY_SKILL}'"

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
