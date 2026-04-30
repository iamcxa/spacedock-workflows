#!/usr/bin/env bash
# test-codex-dispatch-evidence-guard.sh — 113.6 Codex/FO dispatch completion blocker contract
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-codex-dispatch-evidence-guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
SHIP_SKILL="${PLUGIN_ROOT}/skills/ship/SKILL.md"

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

echo "=== test-codex-dispatch-evidence-guard.sh ==="
echo ""

echo "Block 1: /ship dispatch prompt contains the named hard guard"
check "ship SKILL.md names Codex dispatch evidence guard" \
  "grep -q 'Codex dispatch evidence guard' '${SHIP_SKILL}'"
check "guard wording makes missing evidence a completion blocker" \
  "grep -q 'completion blocker' '${SHIP_SKILL}'"
check "guard applies to Codex/FO-dispatched workers" \
  "grep -qE 'Codex/FO-dispatched|FO-dispatched Codex' '${SHIP_SKILL}'"

echo "Block 2: shape/design/verify evidence blocks are all required"
check "shape requires Domain Registry Validation evidence when domain classification is relevant" \
  "awk '/Codex dispatch evidence guard/{in_block=1; next} in_block && /^## /{in_block=0} in_block && /shape/ && /Domain Registry Validation/{found=1} END{exit !found}' '${SHIP_SKILL}'"
check "design requires Schema Design Output evidence for schema-domain route" \
  "awk '/Codex dispatch evidence guard/{in_block=1; next} in_block && /^## /{in_block=0} in_block && /design/ && /## Schema Design Output/{found=1} END{exit !found}' '${SHIP_SKILL}'"
check "verify requires Intent Match Findings evidence for schema design/schema domain" \
  "awk '/Codex dispatch evidence guard/{in_block=1; next} in_block && /^## /{in_block=0} in_block && /verify/ && /## Intent Match Findings/{found=1} END{exit !found}' '${SHIP_SKILL}'"

echo "Block 3: the guard is embedded in the per-stage dispatch template"
check "per-stage dispatch tells workers not to report completion without guard evidence" \
  "awk '/Per-stage dispatch template/{in_template=1} in_template && /Codex dispatch evidence guard/{found=1} in_template && /^## Step 4/{in_template=0} END{exit !found}' '${SHIP_SKILL}'"

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
