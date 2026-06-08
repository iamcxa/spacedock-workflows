#!/usr/bin/env bash
# Regression guard for /ship direct dispatch mandatory EM charter wiring.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SHIP_SKILL="${ROOT}/plugins/ship-flow/skills/ship/SKILL.md"

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

line_no() {
  grep -n "$1" "$SHIP_SKILL" | head -1 | cut -d: -f1
}

echo "=== /ship Science Officer (EM) wiring ==="

check "helper is named in /ship" "grep -q 'build-stage-dispatch-prompt.sh' '$SHIP_SKILL'"
check "helper invocation is adopter-aware" \
  "grep -q 'CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/build-stage-dispatch-prompt.sh' '$SHIP_SKILL' && grep -q -- '--plugin-root \"\${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}\"' '$SHIP_SKILL'"
check "helper invocation is not dogfood-only" \
  "! grep -q 'bash plugins/ship-flow/lib/build-stage-dispatch-prompt.sh' '$SHIP_SKILL'"
check "EM charter section is required" "grep -q '### Science Officer (EM) Charter' '$SHIP_SKILL'"
check "missing profile blocks dispatch" "grep -q 'science-officer-em-profile-not-loaded' '$SHIP_SKILL'"
check "direct dispatch boundary is explicit" \
  "grep -qi 'direct FO-to-stage-worker dispatch' '$SHIP_SKILL' && grep -qi 'nested' '$SHIP_SKILL' && grep -qi 'stage-internal' '$SHIP_SKILL'"
check "helper runs before SendMessage template" \
  "helper_line=\$(line_no 'build-stage-dispatch-prompt.sh'); send_line=\$(line_no 'SendMessage(to: \"<teammate>\"'); test -n \"\$helper_line\" -a -n \"\$send_line\" -a \"\$helper_line\" -lt \"\$send_line\""
check "ship stops when helper fails" \
  "grep -qi 'stop before SendMessage' '$SHIP_SKILL' && grep -qi 'helper fails' '$SHIP_SKILL'"
check "ship routes high-risk judgment to isolated SO/EM worker when host supports it" \
  "grep -qi 'isolated SO/EM worker' '$SHIP_SKILL' && grep -qi 'host supports' '$SHIP_SKILL' && grep -qi 'inline fallback' '$SHIP_SKILL'"
check "ship names SO/EM routing triggers beyond AI review" \
  "grep -qi 'high-risk judgment' '$SHIP_SKILL' && grep -qi 'reviewer conflict' '$SHIP_SKILL' && grep -qi 'context pollution' '$SHIP_SKILL'"
check "Codex dispatch evidence guard preserved" "grep -q 'Codex dispatch evidence guard' '$SHIP_SKILL'"
check "post-create review feedback routes to SO/EM adjudication" \
  "grep -q 'science_officer_em_adjudicate_review_feedback' '$SHIP_SKILL' && grep -q 'science_officer_em_adjudicate_review_threads' '$SHIP_SKILL' && grep -q 'fixed' '$SHIP_SKILL' && grep -q 'push-back: false positive' '$SHIP_SKILL' && grep -q 'needs captain decision' '$SHIP_SKILL' && grep -q 'gh api' '$SHIP_SKILL' && grep -qi 're-triggers the AI reviewer gate' '$SHIP_SKILL' && grep -qi 'author self-approval' '$SHIP_SKILL' && ! grep -qi 'resolve/dismiss' '$SHIP_SKILL'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
