#!/usr/bin/env bash
# Output-shape checks for 130.2 stage-internal EM stewardship surfaces.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

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

require_contract() {
  local label="$1"
  local file="$2"
  local path="${ROOT}/${file}"

  check "${label}: names shared renderer" "grep -q 'render-science-officer-em-stewardship-contract.sh' '$path'"
  check "${label}: requires stewardship contract heading" "grep -q '### Science Officer (EM) Stewardship Contract' '$path'"
  check "${label}: carries five primitives" "perl -0ne 'exit(/results\\s*,\\s*guidelines\\s*,\\s*resources\\s*,\\s*accountability\\s*,\\s*consequences/i ? 0 : 1)' '$path'"
  check "${label}: preserves FO workflow boundary" "perl -0ne 'exit(/FO owns\\s+workflow clock,\\s*state,\\s*worktrees,\\s*dispatch mechanics,\\s*PR\\s+lifecycle,\\s*and stage\\s+advancement/i ? 0 : 1)' '$path'"
  check "${label}: preserves EM judgment boundary" "perl -0ne 'exit(/EM owns\\s+engineering\\s+judgment,\\s*delegation\\s+quality,\\s*worker\\s+stewardship\\s+quality,\\s*risk\\/scope challenge,\\s*and technical\\s+recommendations/i ? 0 : 1)' '$path'"
  check "${label}: prohibits EM mechanics ownership" "perl -0ne 'exit(/EM\\s+does not mutate entity state/i ? 0 : 1)' '$path'"
  check "${label}: requires output-shape evidence" "perl -0ne 'exit(/output-shape.*not\\s+worker\\s+self-attestation/is ? 0 : 1)' '$path'"
}

usage() {
  echo "Usage: $0 [--surface design-plan-execute|verify-review]" >&2
}

run_design_plan_execute_surface() {
  echo "=== Science Officer (EM) stage-internal surfaces: design/plan/execute ==="
  require_contract "ship-design worker dispatch" "plugins/ship-flow/skills/ship-design/SKILL.md"
  require_contract "ship-plan lens/research/review dispatch" "plugins/ship-flow/skills/ship-plan/SKILL.md"
  require_contract "ship-execute task/review dispatch" "plugins/ship-flow/skills/ship-execute/SKILL.md"
}

run_verify_review_surface() {
  echo "=== Science Officer (EM) stage-internal surfaces: verify/review ==="
  require_contract "ship-verify reviewer dispatch" "plugins/ship-flow/skills/ship-verify/SKILL.md"
  require_contract "verify-reviewer-panel fallback dispatch" "plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md"
  require_contract "ship-review canonical-doc patch dispatch" "plugins/ship-flow/skills/ship-review/SKILL.md"
  check "verify panel stays read-only" "grep -qi 'read-only' '${ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md' && grep -qi 'do not edit' '${ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md'"
  check "ship-review patch scope stays planner-owned" "grep -qi 'planner' '${ROOT}/plugins/ship-flow/skills/ship-review/SKILL.md' && grep -qi 'canonical-doc' '${ROOT}/plugins/ship-flow/skills/ship-review/SKILL.md'"
}

if [ "$#" -eq 0 ]; then
  run_design_plan_execute_surface
  run_verify_review_surface
elif [ "$#" -eq 2 ] && [ "$1" = "--surface" ]; then
  case "$2" in
    design-plan-execute)
      run_design_plan_execute_surface
      ;;
    verify-review)
      run_verify_review_surface
      ;;
    *)
      usage
      exit 2
      ;;
  esac
else
  usage
  exit 2
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
