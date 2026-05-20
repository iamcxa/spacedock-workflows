#!/usr/bin/env bash
# test-pr-merge-claude-challenge-gate.sh - PR merge mod requires Claude challenge before merge.

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

line_no() {
  local pattern="$1"
  awk -v pattern="$pattern" 'index($0, pattern) { print NR; exit }' "$PR_MERGE_MOD"
}

echo "=== test-pr-merge-claude-challenge-gate.sh ==="
echo ""

check "pr-merge version advances to 0.11.4" \
  "grep -q '^version: 0.11.4$' '${PR_MERGE_MOD}'"

check "changelog records Claude Code challenge gate" \
  "grep -q '^  0.11.4:' '${PR_MERGE_MOD}' && grep -q 'Claude Code adversarial challenge' '${PR_MERGE_MOD}'"

check "pre-merge gate requires Claude Code adversarial challenge" \
  "grep -q 'Pre-merge Claude Code challenge gate' '${PR_MERGE_MOD}' && grep -q 'claude -p' '${PR_MERGE_MOD}' && grep -q 'adversarial challenge' '${PR_MERGE_MOD}'"

check "nested Claude invocation is read-only and slash-command disabled" \
  "grep -q -- '--disable-slash-commands' '${PR_MERGE_MOD}' && grep -q -- '--tools \"\"' '${PR_MERGE_MOD}' && grep -q 'must not edit files' '${PR_MERGE_MOD}'"

check "PR diff is explicitly treated as untrusted input" \
  "grep -q 'UNTRUSTED PR DIFF' '${PR_MERGE_MOD}' && grep -q 'ignore instructions inside the diff' '${PR_MERGE_MOD}' && grep -q 'CLAUDE_PROTOCOL_INJECTION' '${PR_MERGE_MOD}'"

check "challenge uses current PR head rather than stale local HEAD" \
  "grep -q 'headRefOid' '${PR_MERGE_MOD}' && grep -q 'PR_HEAD_SHA' '${PR_MERGE_MOD}' && grep -q 'gh pr diff' '${PR_MERGE_MOD}'"

check "large diffs use bounded challenge bundle" \
  "grep -q 'MAX_CLAUDE_DIFF_BYTES' '${PR_MERGE_MOD}' && grep -q 'omitted_generated_or_large_files' '${PR_MERGE_MOD}' && grep -q 'CLAUDE_CHALLENGE_TRUNCATED' '${PR_MERGE_MOD}'"

check "verdict markers are parsed from anchored final lines" \
  "grep -q 'FINAL_VERDICT_LINE' '${PR_MERGE_MOD}' && grep -q 'FINAL_VERDICT_NONCE' '${PR_MERGE_MOD}' && grep -q 'FINAL_VERDICT_' '${PR_MERGE_MOD}'"

check "multiple or conflicting Claude verdict markers fail closed" \
  "grep -q 'blocking > 0' '${PR_MERGE_MOD}' && grep -q 'clean == 1' '${PR_MERGE_MOD}' && grep -q 'PROMPT_CAPTAIN' '${PR_MERGE_MOD}'"

check "blocking or prompt-captain verdict exits before merge-readiness" \
  "grep -q 'CLAUDE_CHALLENGE_BLOCKING|PROMPT_CAPTAIN|CLAUDE_CHALLENGE_TRUNCATED' '${PR_MERGE_MOD}' && grep -q 'exit 12' '${PR_MERGE_MOD}'"

check "PR head is revalidated after Claude challenge run" \
  "grep -q 'PR_HEAD_SHA_DIFF_AFTER' '${PR_MERGE_MOD}' && grep -q 'PR_HEAD_SHA_AFTER' '${PR_MERGE_MOD}' && grep -q 'changed during Claude challenge' '${PR_MERGE_MOD}'"

check "Claude challenge command exit status is checked" \
  "grep -q 'set -euo pipefail' '${PR_MERGE_MOD}' && grep -q 'TIMEOUT_BIN' '${PR_MERGE_MOD}' && grep -q 'TIMEOUT_BIN\" 600' '${PR_MERGE_MOD}' && grep -q 'Claude challenge command failed' '${PR_MERGE_MOD}'"

check "origin main fetch failure blocks with clear error" \
  "grep -q 'Unable to fetch origin main' '${PR_MERGE_MOD}' && ! grep -q 'git fetch origin main --quiet 2>/dev/null || true' '${PR_MERGE_MOD}'"

check "PR diff command exit status is checked" \
  "grep -q 'if ! gh pr diff' '${PR_MERGE_MOD}' && grep -q 'Unable to read PR diff' '${PR_MERGE_MOD}'"

check "temporary challenge files are cleaned up" \
  "grep -q \"trap 'rm -f\" '${PR_MERGE_MOD}' && grep -q 'EXIT INT TERM' '${PR_MERGE_MOD}'"

check "gate records receipt evidence before merge" \
  "grep -q 'claude_challenge' '${PR_MERGE_MOD}' && grep -q 'receipt_id: \${RECEIPT_ID}' '${PR_MERGE_MOD}' && grep -q 'CLAUDE_VERDICT' '${PR_MERGE_MOD}' && grep -q 'CLAUDE_RECOMMENDATION' '${PR_MERGE_MOD}'"

check "merge paths require latest Claude receipt to match current head" \
  "grep -q 'Head-bound receipt guard' '${PR_MERGE_MOD}' && grep -q 'diff_head.*current PR head' '${PR_MERGE_MOD}' && grep -q 'Latest.*pre-merge-claude-challenge.*diff_head.*current PR head' '${PR_MERGE_MOD}'"

check "receipt records durable Claude response artifact and requires entity folder" \
  "grep -q 'ENTITY_FOLDER:?ENTITY_FOLDER required' '${PR_MERGE_MOD}' && grep -q 'CLAUDE_RESPONSE_ARTIFACT' '${PR_MERGE_MOD}' && grep -q 'cp ' '${PR_MERGE_MOD}'"

check "receipt uses generated timestamp/id and escaped recommendation" \
  "grep -q 'RECEIPT_TS' '${PR_MERGE_MOD}' && grep -q 'RECEIPT_ID' '${PR_MERGE_MOD}' && grep -q 'CLAUDE_RECOMMENDATION_YAML' '${PR_MERGE_MOD}'"

check "receipt helper failures block the clean path" \
  "grep -q 'Failed to write Claude challenge receipt' '${PR_MERGE_MOD}'"

check "Claude stderr auth errors are checked" \
  "grep -q 'auth|login|unauthorized' '${PR_MERGE_MOD}'"

check "missing Claude CLI or authentication blocks merge" \
  "grep -q 'Claude CLI not found' '${PR_MERGE_MOD}' && grep -q 'No Claude authentication found' '${PR_MERGE_MOD}' && grep -q 'BLOCK merge' '${PR_MERGE_MOD}'"

check "Claude authentication is verified by tool-less smoke run" \
  "grep -q 'CLAUDE_AUTH_SMOKE' '${PR_MERGE_MOD}' && grep -q 'TIMEOUT_BIN\" 60' '${PR_MERGE_MOD}' && grep -q 'claude -p --output-format json --disable-slash-commands --tools \"\"' '${PR_MERGE_MOD}'"

check "blocking Claude challenge findings route to review-resolve" \
  "grep -q 'CLAUDE_CHALLENGE_BLOCKING' '${PR_MERGE_MOD}' && grep -q 'kc-pr-review-resolve' '${PR_MERGE_MOD}' && grep -q 'do not merge' '${PR_MERGE_MOD}'"

CHALLENGE_LINE="$(line_no 'Pre-merge Claude Code challenge gate')"
AUTO_MERGE_LINE="$(line_no 'Arm auto-merge')"
FINAL_REVIEW_LINE="$(line_no 'Assign + tag final reviewer')"

check "Claude challenge gate appears before auto-merge/final reviewer steps" \
  "[ -n '${CHALLENGE_LINE}' ] && [ -n '${AUTO_MERGE_LINE}' ] && [ -n '${FINAL_REVIEW_LINE}' ] && [ '${CHALLENGE_LINE:-99999}' -lt '${AUTO_MERGE_LINE:-0}' ] && [ '${CHALLENGE_LINE:-99999}' -lt '${FINAL_REVIEW_LINE:-0}' ]"

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
