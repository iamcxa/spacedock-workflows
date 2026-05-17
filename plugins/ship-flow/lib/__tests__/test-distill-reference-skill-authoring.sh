#!/usr/bin/env bash
# test-distill-reference-skill-authoring.sh - authoring-quality checks for the distill-reference skill.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

SKILL="${REPO_ROOT}/plugins/ship-flow/skills/distill-reference/SKILL.md"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${desc}"
    FAIL=$((FAIL + 1))
    ERRORS+=("${desc}")
  fi
}

echo "=== test-distill-reference-skill-authoring.sh ==="
echo ""

echo "Block 1: searchable frontmatter"
check "skill name is hyphen-only and description starts with Use when" \
  "grep -q '^name: distill-reference$' '${SKILL}' && grep -q '^description: \"Use when ' '${SKILL}'"
check "frontmatter stays within ship-flow skill metadata fields" \
  "awk 'BEGIN{in_fm=0; ok=1} /^---$/{in_fm++; next} in_fm==1 && /^[A-Za-z_-]+:/{if (\$1 !~ /^(name:|description:|user-invocable:|argument-hint:)$/) ok=0} END{exit ok ? 0 : 1}' '${SKILL}'"
check "description focuses on trigger conditions, not workflow phase summary" \
  "! grep '^description:' '${SKILL}' | grep -Eq 'resolve source|build source map|compare axes|write report'"

echo "Block 2: scannable skill body"
check "skill has an explicit Overview section" \
  "grep -q '^## Overview$' '${SKILL}'"
check "skill has a Quick Reference table" \
  "grep -q '^## Quick Reference$' '${SKILL}' && grep -q '^| Need | Use |$' '${SKILL}'"
check "skill has a Common Mistakes section" \
  "grep -q '^## Common Mistakes$' '${SKILL}'"
check "skill avoids one-off session narrative" \
  "! grep -Eq 'In session|we found|we discovered|last time' '${SKILL}'"

echo "Block 3: reference-skill boundaries"
check "skill links supporting references instead of inlining heavy schemas" \
  "grep -q 'references/comparison-axes.md' '${SKILL}' && grep -q 'references/report-template.md' '${SKILL}' && grep -q 'references/candidate-capture.md' '${SKILL}'"
check "skill keeps GStack/GSD reference-only hermeticity explicit" \
  "grep -q 'reference-only' '${SKILL}' && grep -q 'MUST NOT.*gstack-\\*' '${SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
