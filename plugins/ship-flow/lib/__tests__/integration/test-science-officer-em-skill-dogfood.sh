#!/usr/bin/env bash
# integration/test-science-officer-em-skill-dogfood.sh
#
# Host artifacts needed:
#   docs/ship-flow/_mods/science-officer-em.md — adopted workflow SO mod
#
# Why not standalone: the adopted workflow mod only exists in the host project.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SKILL="${ROOT}/plugins/ship-flow/skills/science-officer-em/SKILL.md"
AGENT="${ROOT}/plugins/ship-flow/agents/science-officer-em.md"
PROFILE="${ROOT}/plugins/ship-flow/_mods/science-officer-em.md"
WORKFLOW_PROFILE="${ROOT}/docs/ship-flow/_mods/science-officer-em.md"

PASS=0; FAIL=0
check() {
  local desc="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "PASS: ${desc}"; PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"; FAIL=$((FAIL + 1))
  fi
}

echo "=== integration: science-officer-em-skill — workflow profile checks ==="
check "workflow standing profile pins opus and xhigh" \
  "grep -q '^- model: opus$' '$WORKFLOW_PROFILE' && grep -q '^- reasoning: xhigh$' '$WORKFLOW_PROFILE'"
check "workflow standing profile points to thin skill" \
  "grep -q 'ship-flow:science-officer-em' '$WORKFLOW_PROFILE'"
check "all SO surfaces do not reference deprecated spacedock-workflow SO" \
  "! grep -R 'spacedock-workflow:science-officer' '$SKILL' '$AGENT' '$PROFILE' '$WORKFLOW_PROFILE'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
