#!/usr/bin/env bash
# Contract test for 130.2 stage-internal Science Officer (EM) stewardship.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RENDERER="${ROOT}/plugins/ship-flow/lib/render-science-officer-em-stewardship-contract.sh"

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

echo "=== Science Officer (EM) stewardship contract renderer ==="

check "renderer exists and is executable" "test -x '$RENDERER'"

# shellcheck disable=SC2034 # referenced inside eval-backed check commands.
contract="$("$RENDERER" 2>/dev/null || true)"

check "contract section heading emitted" "grep -q '^### Science Officer (EM) Stewardship Contract$' <<<\"\$contract\""
check "results primitive emitted" "grep -qi 'results' <<<\"\$contract\" && grep -qi 'artifact' <<<\"\$contract\" && grep -qi 'evidence' <<<\"\$contract\""
check "guidelines primitive emitted" "grep -qi 'guidelines' <<<\"\$contract\" && grep -qi 'boundaries' <<<\"\$contract\" && grep -qi 'quality' <<<\"\$contract\""
check "resources primitive emitted" "grep -qi 'resources' <<<\"\$contract\" && grep -qi 'source artifacts' <<<\"\$contract\" && grep -qi 'commands' <<<\"\$contract\""
check "accountability primitive emitted" "grep -qi 'accountability' <<<\"\$contract\" && grep -qi 'judged' <<<\"\$contract\" && grep -qi 'feedback' <<<\"\$contract\""
check "consequences primitive emitted" "grep -qi 'consequences' <<<\"\$contract\" && grep -qi 'return for rework' <<<\"\$contract\" && grep -qi 'block' <<<\"\$contract\""
check "five primitives appear in one compact sentence for docs grep" "grep -q 'results.*guidelines.*resources.*accountability.*consequences' <<<\"\$contract\""
check "FO/EM boundary emitted" "grep -q 'FO owns workflow clock, state, worktrees, dispatch mechanics, PR lifecycle, and stage advancement' <<<\"\$contract\" && grep -q 'EM owns engineering judgment, delegation quality, worker stewardship quality, risk/scope challenge, and technical recommendations' <<<\"\$contract\""
check "EM mechanics prohibition emitted" "! grep -qi 'EM owns.*dispatch' <<<\"\$contract\" && ! grep -qi 'EM owns.*worktree' <<<\"\$contract\" && grep -qi 'EM does not mutate entity state' <<<\"\$contract\""
check "output-shape evidence emitted instead of attestation" "grep -qi 'output-shape' <<<\"\$contract\" && grep -qi 'not worker self-attestation' <<<\"\$contract\""
check "130.2 and 130.3 boundary emitted" "grep -q '130.2' <<<\"\$contract\" && grep -q '130.3' <<<\"\$contract\" && grep -qi 'upward report schema' <<<\"\$contract\""

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
