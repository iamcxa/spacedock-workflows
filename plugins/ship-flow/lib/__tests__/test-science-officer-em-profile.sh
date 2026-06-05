#!/usr/bin/env bash
# Regression guard for 130.1 Science Officer (EM) standing profile.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
PLUGIN_MOD="${ROOT}/plugins/ship-flow/_mods/science-officer-em.md"
WORKFLOW_MOD="${ROOT}/docs/ship-flow/_mods/science-officer-em.md"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Science Officer (EM) profile contract ==="

for mod in "$PLUGIN_MOD" "$WORKFLOW_MOD"; do
  rel="${mod#"${ROOT}"/}"
  check "${rel}: file exists" "test -f '$mod'"
  check "${rel}: name is science-officer-em" "grep -q '^name: science-officer-em$' '$mod'"
  check "${rel}: standing teammate" "grep -q '^standing: true$' '$mod'"
  check "${rel}: startup hook" "grep -q '^## Hook: startup$' '$mod' && grep -q 'name: science-officer-em' '$mod'"
  check "${rel}: Agent Prompt section" "grep -q '^## Agent Prompt$' '$mod'"
  check "${rel}: anti-relay criterion" "grep -qi 'anti-relay' '$mod' && grep -qi 'status-only relay' '$mod'"
  check "${rel}: costly no authority" "grep -qi 'costly no' '$mod' && grep -qi 'say no' '$mod'"
  check "${rel}: independent synthesis" "grep -qi 'independent synthesis' '$mod' && grep -qi 'FO state' '$mod'"
  check "${rel}: FO boundary" "grep -qi 'FO owns' '$mod' && grep -qi 'EM owns' '$mod'"
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
