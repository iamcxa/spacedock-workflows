#!/usr/bin/env bash
# test-copilot-bot-head-guard.sh - PR merge mod documents Copilot bot-head CI guardrail.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
PR_MERGE_MOD="${REPO_ROOT}/docs/ship-flow/_mods/pr-merge.md"

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

echo "=== test-copilot-bot-head-guard.sh ==="
echo ""

check "pr-merge mod warns Copilot bot commits can action_required Actions" \
  "grep -q 'copilot-swe-agent\\[bot\\]' '${PR_MERGE_MOD}' && grep -q 'action_required' '${PR_MERGE_MOD}' && grep -q 'empty jobs' '${PR_MERGE_MOD}'"

check "pr-merge mod requires human-authored re-author or explicit workflow approval" \
  "grep -q 're-author' '${PR_MERGE_MOD}' && grep -q 'human-authored' '${PR_MERGE_MOD}' && grep -q 'workflow approval' '${PR_MERGE_MOD}'"

check "pr-merge mod verifies current head checks after Copilot commits" \
  "grep -q 'gh run list --branch {branch} --commit {sha}' '${PR_MERGE_MOD}' && grep -q 'gh pr checks' '${PR_MERGE_MOD}' && grep -q 'current head' '${PR_MERGE_MOD}'"

check "pr-merge mod failure handling matches comment-first Copilot request path" \
  "grep -q 'If the Copilot comment request fails' '${PR_MERGE_MOD}' && grep -q 'Reviewer-id fallback applies only' '${PR_MERGE_MOD}' && ! grep -q 'Do NOT retry beyond the documented fallback ids' '${PR_MERGE_MOD}'"

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
