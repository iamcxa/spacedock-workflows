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

check "pr-merge mod requests Copilot review through the REST reviewer-request surface" \
  "grep -q \"reviewer-request API surface\" '${PR_MERGE_MOD}' && grep -q \"repos/{owner}/{repo}/pulls/{pr}/requested_reviewers\" '${PR_MERGE_MOD}' && grep -q \"reviewers\\[\\]=copilot-pull-request-reviewer\\[bot\\]\" '${PR_MERGE_MOD}'"

check "pr-merge mod documents gh @copilot reviewer path as an anti-pattern" \
  "grep -q \"Anti-pattern\" '${PR_MERGE_MOD}' && grep -q \"gh pr edit {pr} --add-reviewer @copilot\" '${PR_MERGE_MOD}' && grep -q \"@copilot.*--add-assignee\" '${PR_MERGE_MOD}'"

check "pr-merge mod verifies Copilot through REST requested reviewers or submitted reviews, not reviewRequests only" \
  "grep -q \"requested_reviewers\" '${PR_MERGE_MOD}' && grep -q \"reviews.author.login\" '${PR_MERGE_MOD}' && grep -q \"reviewRequests alone is not authoritative\" '${PR_MERGE_MOD}'"

check "pr-merge mod does not use comment-first Copilot review request" \
  "grep -q 'not via PR comment' '${PR_MERGE_MOD}' && grep -q 'manual fallback only' '${PR_MERGE_MOD}' && ! grep -q 'prefer a PR comment request' '${PR_MERGE_MOD}' && ! grep -q 'If the Copilot comment request fails' '${PR_MERGE_MOD}'"

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
