#!/usr/bin/env bash
# Regression guard for the captain-invocable Science Officer (EM) thin skill.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SKILL="${ROOT}/plugins/ship-flow/skills/science-officer-em/SKILL.md"
AGENT="${ROOT}/plugins/ship-flow/agents/science-officer-em.md"
PROFILE="${ROOT}/plugins/ship-flow/_mods/science-officer-em.md"
WORKFLOW_PROFILE="${ROOT}/docs/ship-flow/_mods/science-officer-em.md"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Science Officer (EM) thin skill contract ==="

check "profile exists" "test -f '$PROFILE'"
check "skill exists" "test -f '$SKILL'"
check "skill has canonical frontmatter name" "grep -q '^name: science-officer-em$' '$SKILL'"
check "skill description is trigger-only" \
  "grep -q '^description: Use when' '$SKILL' && ! grep -Eiq '^description:.*(write|render|follow|output)' '$SKILL'"
check "skill is captain-invocable" "grep -q '^user-invocable: true$' '$SKILL'"
check "skill references standing profile" "grep -q 'plugins/ship-flow/_mods/science-officer-em.md' '$SKILL'"
check "skill defines inline versus isolated worker invocation mode selection" \
  "grep -q 'Invocation Mode Selection' '$SKILL' && grep -q 'Inline skill call' '$SKILL' && grep -q 'Isolated SO/EM worker' '$SKILL'"
check "skill routes mid-task judgment through isolated worker to avoid parent context pollution" \
  "grep -qi 'mid-task' '$SKILL' && grep -qi 'parent context' '$SKILL' && grep -qi 'minimal evidence packet' '$SKILL'"
check "skill keeps worker-spawn decision with parent or FO, not SO/EM" \
  "grep -qi 'parent/FO decides' '$SKILL' && grep -qi 'SO/EM never spawns itself' '$SKILL'"
check "skill supports conductor/general-prompt aliases" \
  "grep -q 'science-officer' '$SKILL' && grep -q '科學官' '$SKILL' && grep -q 'EM' '$SKILL'"
check "skill requires independent synthesis, not relay" \
  "grep -qi 'anti-relay' '$SKILL' && grep -qi 'independent synthesis' '$SKILL' && grep -qi 'status-only relay' '$SKILL'"
check "skill requires upward report shape fields" \
  "grep -q 'science_officer_em_upward_report' '$SKILL' && grep -q 'em_judgment' '$SKILL' && grep -q 'evidence_synthesis' '$SKILL' && grep -q 'risk_tradeoff_call' '$SKILL' && grep -q 'recommendation' '$SKILL' && grep -q 'route' '$SKILL' && grep -q 'confidence' '$SKILL' && grep -q 'fo_boundary' '$SKILL'"
check "skill includes route enum" \
  "grep -q 'proceed' '$SKILL' && grep -q 'narrow' '$SKILL' && grep -q 'return' '$SKILL' && grep -q 'block' '$SKILL' && grep -q 'costly_no' '$SKILL'"
check "skill preserves FO/EM boundary" \
  "grep -qi 'FO owns workflow' '$SKILL' && grep -qi 'EM owns engineering judgment' '$SKILL'"
check "skill routes AI review adjudication to EM inline replies" \
  "grep -q 'AI / external PR review adjudication' '$SKILL' && grep -q 'fixed' '$SKILL' && grep -q 'push-back: false positive' '$SKILL' && grep -q 'needs captain decision' '$SKILL'"
check "skill requires gh api evidence and AI gate re-trigger" \
  "grep -q 'gh api' '$SKILL' && grep -qi 'test command/result' '$SKILL' && grep -qi 're-trigger' '$SKILL' && grep -qi 'AI gate' '$SKILL'"
check "skill leaves AI thread resolution to the gate" \
  "! grep -qi 'resolve/dismiss' '$SKILL' && grep -qi 'gate adjudicates replies' '$SKILL'"
check "skill forbids author self-approval as review bypass" \
  "grep -qi 'author self-approval' '$SKILL' && grep -qi 'must not' '$SKILL'"
check "skill forbids replacing FO mechanics" \
  "grep -qi 'Do not advance stages' '$SKILL' && grep -qi 'Do not.*mutate.*frontmatter' '$SKILL' && grep -qi 'Do not.*own.*worktree' '$SKILL' && grep -qi 'Do not.*replace.*First Officer' '$SKILL'"
check "skill gives direct invocation examples" \
  "grep -q 'Use science-officer' '$SKILL' && grep -q '請科學官' '$SKILL'"
check "claude agent profile exists" "test -f '$AGENT'"
check "claude agent profile has canonical name" "grep -q '^name: science-officer-em$' '$AGENT'"
check "claude agent profile pins opus" "grep -q '^model: opus$' '$AGENT'"
check "claude agent profile requests xhigh reasoning" "grep -q '^reasoning: xhigh$' '$AGENT'"
check "claude agent profile delegates to standing profile" "grep -q 'plugins/ship-flow/_mods/science-officer-em.md' '$AGENT'"
check "claude agent profile invokes thin skill" "grep -q 'ship-flow:science-officer-em' '$AGENT'"
check "claude agent profile keeps FO boundary" \
  "grep -qi 'FO owns workflow' '$AGENT' && grep -qi 'EM owns engineering judgment' '$AGENT' && grep -qi 'Do not.*replace.*First Officer' '$AGENT'"
check "claude agent profile can run as isolated judgment worker" \
  "grep -qi 'isolated judgment worker' '$AGENT' && grep -qi 'minimal evidence packet' '$AGENT'"
check "claude agent profile uses upward report shape" \
  "grep -q 'science_officer_em_upward_report' '$AGENT' && grep -q 'route' '$AGENT' && grep -q 'confidence' '$AGENT'"
check "standing profiles pin opus and xhigh" \
  "grep -q '^- model: opus$' '$PROFILE' && grep -q '^- reasoning: xhigh$' '$PROFILE' && grep -q '^- model: opus$' '$WORKFLOW_PROFILE' && grep -q '^- reasoning: xhigh$' '$WORKFLOW_PROFILE'"
check "standing profiles point to thin skill" \
  "grep -q 'ship-flow:science-officer-em' '$PROFILE' && grep -q 'ship-flow:science-officer-em' '$WORKFLOW_PROFILE'"
check "ship-flow SO surfaces do not reference deprecated spacedock-workflow SO" \
  "! grep -R 'spacedock-workflow:science-officer' '$SKILL' '$AGENT' '$PROFILE' '$WORKFLOW_PROFILE'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
