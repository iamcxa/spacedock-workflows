#!/usr/bin/env bash
# test-ship-unified-entry-routing.sh - /ship must route through shape/design before plan.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
SHIP_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship/SKILL.md"

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

line_no() {
  local pattern="$1"
  awk -v pat="$pattern" 'index($0, pat) { print NR; exit }' "$SHIP_SKILL"
}

check_order() {
  local desc="$1"
  local first="$2"
  local second="$3"
  local first_line second_line
  first_line="$(line_no "$first")"
  second_line="$(line_no "$second")"
  if [ -n "$first_line" ] && [ -n "$second_line" ] && [ "$first_line" -lt "$second_line" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

extract_section() {
  local start="$1"
  local end="$2"
  awk -v start="$start" -v end="$end" '
    index($0, start) { in_section=1 }
    in_section { print }
    in_section && end == "" { next }
    in_section && index($0, end) { exit }
  ' "$SHIP_SKILL"
}

echo "=== test-ship-unified-entry-routing.sh ==="
echo ""

ARTIFACTS="$(mktemp)"
STEP2="$(mktemp)"
STEP4="$(mktemp)"
INVARIANTS="$(mktemp)"
REFERENCES="$(mktemp)"
trap 'rm -f "$ARTIFACTS" "$STEP2" "$STEP4" "$INVARIANTS" "$REFERENCES"' EXIT

extract_section "**Pipeline artifacts**" "## When to use" > "$ARTIFACTS"
extract_section "## Step 2" "## Step 3" > "$STEP2"
extract_section "## Step 4" "## Step 5" > "$STEP4"
extract_section "## Invariants + red flags" "## References" > "$INVARIANTS"
extract_section "## References" "" > "$REFERENCES"

check "ship still loads first officer before classifying or resolving" \
  "grep -q 'before classifying' '${SHIP_SKILL}' && grep -q 'before resolving' '${SHIP_SKILL}' && grep -q 'spacedock:first-officer' '${SHIP_SKILL}'"

check "ship pins the exact fresh-dispatch stage-entry receipt" \
  "grep -Fqx -- '- fresh dispatch: \`dispatch: {slug-or-bounded-summary} entering {next_stage}\`' '${SHIP_SKILL}'"

check "ship pins the exact same-worker-reuse stage-entry receipt" \
  "grep -Fqx -- '- same-worker reuse: \`advance: {slug-or-bounded-summary} entering {next_stage}\`' '${SHIP_SKILL}'"

check "ship no longer describes a five-artifact plan-first pipeline" \
  "! grep -q 'Produce 5 per-stage .md artifacts' '${SHIP_SKILL}' && ! grep -q 'Create 5 top-level tasks' '${SHIP_SKILL}'"

check "artifact list includes shape, legacy spec, design, and plan" \
  "grep -q 'shape.md' '${ARTIFACTS}' && grep -q 'spec.md' '${ARTIFACTS}' && grep -q 'design.md' '${ARTIFACTS}' && grep -q 'plan.md' '${ARTIFACTS}'"

check "artifact list orders shape before design before plan" \
  "awk 'index(\$0, \"shape.md\") { shape=NR } index(\$0, \"design.md\") { design=NR } index(\$0, \"plan.md\") { plan=NR } END { exit !(shape && design && plan && shape < design && design < plan) }' '${ARTIFACTS}'"

check "good-enough raw requirements route through shape inline" \
  "grep -q 'Good-enough raw requirement' '${SHIP_SKILL}' && grep -q 'ship-flow:ship-shape inline' '${SHIP_SKILL}'"

check "ship does not tell concrete raw requirements to run shape first and exit" \
  "! grep -q 'run /shape first' '${SHIP_SKILL}'"

check "existing entities missing shape/spec route to shape before plan" \
  "grep -q 'neither.*shape.md.*nor legacy.*spec.md' '${SHIP_SKILL}' && grep -q 'shape before plan' '${SHIP_SKILL}'"

check "design or design trivial-pass is considered before plan" \
  "grep -q 'design trivial-pass' '${SHIP_SKILL}' && grep -q 'design before plan' '${SHIP_SKILL}'"

check "umbrella task order starts with shape and design before plan" \
  "awk 'index(\$0, \"shape\") && index(\$0, \"design\") && index(\$0, \"plan\") { found=1 } END { exit !found }' '${STEP2}'"

check "stage flow starts at shape, then design, then plan" \
  "grep -q '1\\. \\*\\*shape\\*\\*' '${STEP4}' && grep -q '2\\. \\*\\*design\\*\\*' '${STEP4}' && grep -q '3\\. \\*\\*plan\\*\\*' '${STEP4}'"

check "bottom invariants do not tell vague inputs to use a separate shape invocation" \
  "! grep -q 'Do NOT shape inline' '${INVARIANTS}' && ! grep -q 'user runs.*/shape.*explicitly' '${INVARIANTS}'"

check "bottom invariants no longer describe a five-stage pipeline" \
  "! grep -q '5 stages advance sequentially' '${INVARIANTS}'"

check "bottom references list shape and design as stage skills" \
  "grep -q 'Stage skills:.*ship-flow:ship-shape.*ship-flow:ship-design.*ship-flow:ship-plan' '${REFERENCES}'"

check "bottom references do not treat ship-shape as upstream-only" \
  "! grep -q 'Upstream shape skill' '${REFERENCES}'"

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

echo "All assertions passed"
